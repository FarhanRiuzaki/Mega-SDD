#!/usr/bin/env bash
# build-dispatch-prompt.sh — deterministic assembler for the bolt dispatch prompt.
#
# WHY THIS EXISTS
# ---------------
# The execute-bolts controller used to ASSEMBLE the ~9KB tiered dispatch prompt in
# the model's head (per skills/execute-bolts/references/context-enrichment.md
# Step 4.5 + starterkit-enrichment.md + bolt-dispatch-prompt.md) and then
# MATERIALIZE it TWICE: once as <vault>/bolts/U-XXX/dispatch-prompt.md, once
# re-typed verbatim into the Agent dispatch. Measured cost on a 40-unit run:
# ~179K output tokens and 25-75 min of serial generation. This script does the
# assembly deterministically so the model types NEITHER copy — it runs this,
# reads `inline_core` from the JSON, and pastes that (<=700 bytes) as the Agent
# prompt. The agent Reads the on-disk file for its full dispatch.
#
# WHAT IT EMITS
#   1. <vault>/bolts/U-XXX/dispatch-prompt.md   (the full tiered prompt; the
#      on-disk artifact is CONTRACTUAL — scripts/validate-dispatch-prompt.sh
#      globs exactly this path and goes dark if the file stops existing). The
#      artifact is written to a SIBLING temp file and os.replace()d in, so the
#      path either holds a COMPLETE prompt or is untouched — a failed run never
#      renames, and therefore never publishes a half-written file.
#      THE BUILDER NEVER DELETES THE TARGET. Deleting an existing, correct
#      artifact buys nothing that temp+rename does not already buy, and it is
#      what turned a stdout-encoding failure into a destroyed prompt (round-3
#      R-CRIT-B). Consequence, stated rather than hidden: after a failed run the
#      path may still hold THIS unit's PREVIOUS attempt. The exit code is the
#      discriminator — exits 2 and 4 both mean NEVER DISPATCH — and the prompt
#      carries its own unit id, so a cross-unit mix-up is not reachable.
#   2. one compact JSON object on stdout (suppressed by --quiet), carrying the
#      controller-consumed keys (context-enrichment.md §Builder contract):
#      status, halt, inline_core, prompt_path, total_bytes, file_bytes,
#      t1_bytes, t2_bytes, truncations[], warnings[], soft_halts[], and
#      `design_slice_path` on UI-bearing units.
#      `sections_omitted[]` is FORENSICS and is NOT on default stdout — it is
#      written into the prompt file's own `## Provenance — omissions` appendix
#      and re-added to stdout by --explain.
#   3. <vault>/lens-inputs/U-XXX/design-slice.md on UI-bearing units — the design
#      lens's rubric as a FILE, whose absolute path is `design_slice_path`. The
#      slice is ALSO injected into the dispatch prompt itself, unchanged; this
#      file exists so the LENS receives ~70 bytes of path instead of ~9.6 KB of
#      pasted text, which the controller was re-typing (an OUTPUT-channel cost)
#      on every UI bolt. `lens-inputs/` is a SIBLING of `bolts/` and holds only
#      controller-written lens inputs — never any implementer output — so the
#      blind-review rail (no lens may receive a path that reaches another lens's
#      verdict or the implementer's self-report) is not touched by it.
#
# Usage:
#   build-dispatch-prompt.sh --cwd=<project-root> --vault=<vault-path> --unit=U-XXX
#                            --plugin-root=<path> [--explain] [--quiet]
#
# Exit (context-enrichment.md §Builder contract §Exit codes — the controller
# branches on these, so they are a contract, not a convention):
#   0  prompt written (INCLUDING runs that recorded soft halts and continued)
#   1  halt `dispatch_prompt_too_large`, and ONLY that — the documented
#      three-way conjunction (context-enrichment.md §Halt path). stdout JSON
#      ALWAYS carries a populated `halt` object; the prompt IS still written,
#      deliberately, as the forensic evidence for the halt.
#   2  usage / IO / no interpreter. NOTHING was renamed into place, so this run
#      published no prompt. NEVER dispatch.
#   4  INTERNAL ERROR — any unhandled exception in the builder. stdout carries
#      {"status":"internal_error", "error":…, "traceback":…}. Again nothing was
#      renamed into place. NEVER dispatch. (4, not 3:
#      _lib/resolve-framework-pack.sh already uses 3 for "section absent =>
#      SKIP" in this same script family.)
#
# SPAWN BUDGET (Windows/CrowdStrike ~220ms per process spawn; per-item subprocess
# fan-out is the regression class this repo shipped fixes for twice — tree-sitter
# per-file v5.11.0, pack-lint per-line v4.60.0).
#
#   MEASURED, not asserted (PATH-shim exec log, 2026-07-31). Two `bash <helper>`
#   CALLS are hoisted here, but a CALL IS NOT A PROCESS: each helper forks its
#   own subshells and execs its own binaries, and those are what CrowdStrike
#   scans. The old header said "at most TWO subprocess spawns" and was wrong by
#   ~3x. For the invocation SKILL.md documents (--plugin-root PASSED, so
#   [spawn 1] never runs), exec'd binaries BEYOND the caller's own `bash`:
#     this script          : 1 dirname                              (SCRIPT_DIR)
#     [spawn 2] resolver   : 1 bash + 2 dirname + 1 python3
#     the interpreter      : 1 python3
#     ---------------------------------------------------------------
#     6 exec'd binaries + ~3 bash subshell forks  ≈ 9 process creations/bolt
#   WITHOUT --plugin-root, [spawn 1] resolve-plugin-root.sh adds 1 bash + its
#   internal `ls | grep | sort | tail` pipeline (4 binaries) + its own subshells
#   + the `cd ..` subshell here — roughly 6 more, ≈15 total. That is why
#   --plugin-root is REQUIRED of the controller (context-enrichment.md §Builder
#   contract), not a nicety: ≈1.3 s/bolt and ≈53 s over a 40-unit run at the
#   ~220 ms/spawn measured on a CrowdStrike-scanned Windows laptop.
#     [spawn 1] scripts/resolve-plugin-root.sh   — SKIPPED when --plugin-root is given
#     [spawn 2] scripts/_lib/resolve-framework-pack.sh --quiet  (NO --section:
#               one call returns the whole chain; the pack BODIES are then read
#               in-process. `--section` prints ONE section per invocation and the
#               builder needs >=3 of them — that would be per-section fan-out.)
#   The Python body itself contains ZERO subprocess/os.system/popen calls and the
#   count is CONSTANT w.r.t. target_files / depends_on / anchors / pack rules —
#   there is no per-item fan-out anywhere. Everything else — anchor freshness,
#   YAML, globbing, hashing — is in-process.
#   NOTE: check-anchor-freshness.sh is deliberately NOT spawned here; see the
#   ANCHOR FRESHNESS comment in the Python body.

set -uo pipefail

CWD=""
VAULT=""
UNIT=""
PLUGIN_ROOT=""
QUIET=0
EXPLAIN=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*)         CWD="${arg#*=}" ;;
    --vault=*)       VAULT="${arg#*=}" ;;
    --unit=*)        UNIT="${arg#*=}" ;;
    --plugin-root=*) PLUGIN_ROOT="${arg#*=}" ;;
    --explain)       EXPLAIN=1 ;;
    --quiet)         QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
# --explain and --quiet are NOT two settings of one verbosity dial
# (context-enrichment.md §stdout JSON): --explain ADDS the forensic keys back,
# --quiet removes stdout entirely (and with it `inline_core`, the only reason
# the controller runs this at all). Combining them is a usage error.
if [ "$QUIET" -eq 1 ] && [ "$EXPLAIN" -eq 1 ]; then
  echo "ERROR: --quiet and --explain are mutually exclusive (--quiet suppresses ALL stdout)" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# Resolve the project root FIRST — resolve_project_root can return a DIFFERENT
# directory than the one passed in (it walks up to the outermost SUBSTANTIVE
# .mega-sdd/), and every path below is built from the resolved value. Running
# from a sub-cwd without this mints nested .mega-sdd/<sub>/.mega-sdd/ paths.
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR"
  CWD=$(resolve_project_root "$CWD")
fi

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required and must exist" >&2; exit 2
fi
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  echo "ERROR: --vault=<vault-path> required and must exist" >&2; exit 2
fi
if [ -z "$UNIT" ]; then
  echo "ERROR: --unit=U-XXX required" >&2; exit 2
fi

# NOTHING BELOW EVER DELETES THE TARGET PROMPT — not this shell wrapper, not the
# Python body, not the internal-error handler. The publication guarantee comes
# from writing to a sibling temp file and os.replace()ing it into place: a run
# that fails anywhere never renames, so it never publishes. A pre-emptive delete
# added no guarantee and cost the artifact — on the documented Windows target a
# stdout-encoding failure destroyed a dispatch prompt that had already been
# written correctly (round-3 R-CRIT-B). What keeps a stale prompt out of a
# dispatch is the EXIT CODE: 2 and 4 both mean NEVER DISPATCH.

# Interpreter probe. `command -v python3` is a FALSE POSITIVE on Windows (the
# WindowsApps App Execution Alias stub is on PATH, writes to stderr and exits 49)
# — a builder that read "empty stdout" as "the prompt is legitimately empty"
# would write an empty dispatch-prompt.md and silently disarm the whole dispatch.
# Fail CLOSED: print the canonical remedy, write nothing, exit 2.
# $MEGA_SDD_PY MUST be expanded UNQUOTED — `py -3` is two words.
_RPY="${SCRIPT_DIR}/_lib/resolve-python.sh"
if [ -f "$_RPY" ]; then
  # shellcheck disable=SC1090
  . "$_RPY"
  if ! mega_sdd_python; then
    mega_sdd_python_remedy >&2
    echo >&2
    exit 2
  fi
else
  MEGA_SDD_PY="python3"
fi
export MEGA_SDD_PY

# [spawn 1] Plugin root. Skipped entirely when the caller already knows it.
# The fallback root is derived from THIS script's own location (scripts/.. ==
# the plugin root) — the canonical caller idiom.
if [ -z "$PLUGIN_ROOT" ]; then
  _FALLBACK_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd)"
  _RPR_PLUGIN="${SCRIPT_DIR}/resolve-plugin-root.sh"
  if [ -f "$_RPR_PLUGIN" ]; then
    PLUGIN_ROOT="$(bash "$_RPR_PLUGIN" "$_FALLBACK_ROOT" 2>/dev/null)" || PLUGIN_ROOT="$_FALLBACK_ROOT"
  else
    PLUGIN_ROOT="$_FALLBACK_ROOT"
  fi
  [ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$_FALLBACK_ROOT"
fi

# [spawn 2] Framework pack CHAIN (no --section — see the spawn-budget note).
# stdout is the contract; --quiet suppresses stderr diagnostics only, and a
# builder that merged 2>&1 would parse `# active pack: ...` as a pack basename.
#
# THE EXIT CODE IS DISCRIMINATED, NEVER SWALLOWED (context-enrichment.md
# §Builder contract, "Pack-resolver exit codes MUST be discriminated"). The old
# `|| PACK_CHAIN=""` collapsed THREE distinct outcomes into one empty chain:
#   0  -> chain resolved                       (use it)
#   3  -> documented SKIP, no pack applies     (legitimately packless project)
#   *  -> the chain is UNKNOWN, not empty      (broken resolver / stub python3)
# On the documented Windows target `python3` resolves to the WindowsApps App
# Execution Alias stub (exit 49) and the resolver dies there, so the swallow
# stripped the ENTIRE framework-pack contribution — `## Framework pack rules`
# AND the pack-derived `DO NOT WRITE:` anti-context — from every bolt dispatch
# at exit 0 with empty stderr, and the recorded omission reasons were textually
# identical to a packless project. `$MEGA_SDD_PY` is exported above so the
# resolver inherits the interpreter THIS script already resolved correctly
# instead of re-guessing `python3` off PATH — discriminating the exit code alone
# would only narrate the loss, not prevent it.
PACK_CHAIN=""
PACK_RC=0
_PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
if [ -f "$_PACK_RESOLVER" ]; then
  PACK_CHAIN="$(bash "$_PACK_RESOLVER" --cwd="$CWD" --quiet 2>/dev/null)"
  PACK_RC=$?
  if [ "$PACK_RC" -ne 0 ]; then
    PACK_CHAIN=""
  fi
else
  PACK_RC=127     # resolver itself missing — also NOT a packless project
fi

export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

MSDD_CWD="$CWD" MSDD_VAULT="$VAULT" MSDD_UNIT="$UNIT" \
MSDD_PLUGIN_ROOT="$PLUGIN_ROOT" MSDD_PACK_CHAIN="$PACK_CHAIN" MSDD_QUIET="$QUIET" \
MSDD_EXPLAIN="$EXPLAIN" MSDD_PACK_RC="$PACK_RC" MSDD_PY="$MEGA_SDD_PY" \
$MEGA_SDD_PY <<'PYEOF'
# -*- coding: utf-8 -*-
"""Deterministic bolt-dispatch-prompt assembler.

Reproduces, byte-for-byte where the references specify bytes:
  - the T1/T2/T3 template of skills/execute-bolts/references/bolt-dispatch-prompt.md
  - the budget dict + 9-row priority table + per-row truncation cascade of
    skills/execute-bolts/references/context-enrichment.md
  - the 7-step internal slice ladder of
    skills/execute-bolts/references/starterkit-enrichment.md §Slice truncation order

NO PyYAML. Not even a dual PyYAML-preferred/hand-rolled path: the T2 cascade is a
MOAT surface and a dual parser is TWO behaviors for ONE input. PyYAML coerces
where the hand-rolled parsers do not (flow maps, `8` vs `"8px"`, YAML-1.1 truthy
tokens, `#` inside quoted scalars) and the cascade's decisions are VALUE-dependent
(`libs -> top 10`, `ui_ux.idioms -> top 3`), so a PyYAML-present machine could
truncate differently from a PyYAML-absent one. Single hand-rolled path, always.
(PyYAML is also simply absent on this repo's reference interpreters — see
scripts/build-graph.sh:36.)
"""
import glob
import json
import os
import re
import sys
import traceback

CWD = os.environ["MSDD_CWD"]
VAULT = os.path.abspath(os.environ["MSDD_VAULT"])
UNIT_ID = os.environ["MSDD_UNIT"]
PLUGIN_ROOT = os.environ.get("MSDD_PLUGIN_ROOT", "")
PACK_CHAIN = [p for p in os.environ.get("MSDD_PACK_CHAIN", "").split() if p]
QUIET = os.environ.get("MSDD_QUIET", "0") == "1"
EXPLAIN = os.environ.get("MSDD_EXPLAIN", "0") == "1"
PACK_RC = int(os.environ.get("MSDD_PACK_RC", "0") or 0)
PY_USED = os.environ.get("MSDD_PY", "") or "python3"

# ── Canonical budget constants (context-enrichment.md §T2 budget tracker) ──────
# These four numbers are law and they do FOUR different jobs — conflating any two
# is the catastrophic bug here:
#   cap_t2     (10240) drives TRUNCATION       — the T2 budget tracker owns the cascade
#   cap_hard   (12288) drives the HALT check   — §Halt path's three-way conjunction
#   cap_target  (9216) drives NOTHING          — advisory
#   cap_t1     (12288) drives NOTHING but ONE WARNING — a REPORTING THRESHOLD, not
#              a budget: T1 is never truncated and the unit body is verbatim, so
#              no value of cap_t1 bounds T1. Amended 2026-07-31 from 123 measured
#              builder runs (context-enrichment.md ## AMENDMENT): T1 max 10 874 B,
#              and the builder's NON-BODY scaffolding alone floors at 2 385 B, so
#              the old 2048 was satisfiable only when pack content was MISSING —
#              it fired on 123/123 runs, pure noise. At 12288 it fires only above
#              ~6.8 KB of unit body, where it means what it should: a
#              generate-units atomicity smell, not a budget complaint.
# `cap_t1 + cap_t2 == cap_hard` is EXPLICITLY RETIRED as a constraint (it was an
# arithmetic coincidence). Do NOT re-derive one of these from another.
CAP_HARD = 12288
CAP_TARGET = 9216
CAP_T1 = 12288
CAP_T2 = 10240

SECTIONS_EMITTED = []
SECTIONS_OMITTED = []
SOFT_HALTS = []
WARNINGS = []
TRUNCATIONS = []

BOLT_DIR = os.path.join(VAULT, "bolts", UNIT_ID)
PROMPT_PATH = os.path.join(BOLT_DIR, "dispatch-prompt.md")
ABS_PROMPT = os.path.abspath(PROMPT_PATH)

# Set once the sibling temp file exists; cleaned up by the internal-error
# handler. THE TEMP FILE IS NOT THE ARTIFACT — removing it is not the destructive
# unlink this round removed, it is litter control on a directory that would
# otherwise accumulate `.dispatch-prompt.md.tmp-<pid>` per crash.
TMP_PATH = None


# ── THE STDOUT CHANNEL IS MADE ENCODING-PROOF BEFORE ANYTHING CAN WRITE TO IT ──
# On the documented Windows/Git-Bash target a REDIRECTED Python stdout falls back
# to the ANSI code page (cp1252), with errors='strict'. The report legitimately
# carries non-cp1252 characters — `→`/`≥` in a design slice, CJK/Cyrillic target
# paths, an em-dash in a unit title — so the final write raised UnicodeEncodeError
# on every UI-bearing bolt and on every unit with a non-Latin-1 path, and the
# exit-4 handler then deleted the prompt the builder had already written
# CORRECTLY (round-3 R-CRIT-B). Two independent fixes, either of which alone
# contains it:
#   (i)  every json.dumps() to stdout uses ensure_ascii=True — pure-ASCII output
#        cannot raise on ANY code page, including one this reconfigure cannot
#        reach. The FILE is unaffected: both open() calls carry
#        encoding="utf-8" and the write carries newline="\n".
#   (ii) the handler no longer deletes anything (see the header).
# The reconfigure below is the belt to those braces and is guarded: it is 3.7+,
# and it WINS over an inherited PYTHONIOENCODING (verified), which PYTHONUTF8
# does not.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass


# ── Exit 4: internal error, distinct from the exit-1 budget halt ──────────────
# Before this existed, ANY unhandled exception — an unimportable shared lib, a
# malformed unit, the section ladder's `assert len(rules) == len(levels) - 1` —
# exited 1 with zero stdout and no file written. The controller's exit-1 contract
# reads that as `dispatch_prompt_too_large`, looks for a `halt` object that is not
# there, and is told by the same contract to TRUST the file on disk as forensic
# evidence. sys.excepthook + os._exit is used rather than wrapping 2 000 lines in
# a try block: SystemExit is not routed through excepthook, so die()'s exit 2 and
# the halt's exit 1 are untouched.
#
# IT IS NOT DESTRUCTIVE. An exception here means THIS run published nothing (the
# rename never happened); it does not mean the artifact on disk must be
# destroyed. Exit 4 is "NEVER dispatch", and that contract — not an unlink — is
# what keeps a stale prompt out of an Agent dispatch.
def _fatal_internal(exc_type, exc, tb):
    payload = {
        "status": "internal_error",
        "unit": UNIT_ID,
        "error": "%s: %s" % (getattr(exc_type, "__name__", str(exc_type)), exc),
        "traceback": "".join(traceback.format_exception(exc_type, exc, tb)),
    }
    if TMP_PATH:
        try:
            os.unlink(TMP_PATH)
        except OSError:
            pass
    try:
        sys.stderr.write(payload["traceback"])
        sys.stderr.flush()
    except Exception:
        pass
    if not QUIET:
        try:
            sys.stdout.write(json.dumps(payload, ensure_ascii=True, indent=2) + "\n")
            sys.stdout.flush()
        except Exception:
            pass
    os._exit(4)


sys.excepthook = _fatal_internal

# SHARED LIBS ARE IMPORTED **AFTER** THE HANDLER IS INSTALLED — deliberately.
# An unimportable `vault_layouts` / `postflight_rules` (renamed, unreadable, a
# syntax error introduced upstream) is the textbook internal error, and importing
# them at the top of the module would raise before `sys.excepthook` existed:
# Python's default handler exits 1 with NO JSON, i.e. exactly the state the
# exit-4 contract exists to eliminate — a controller reading exit 1 as
# `dispatch_prompt_too_large`, looking for a `halt` object that is not there, and
# trusting whatever is on disk as this run's forensic evidence. Reproduced once;
# keep the import here.
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import postflight_rules            # noqa: E402  shared B1 Hard-rule lexer + sha256
import vault_layouts               # noqa: E402  every accepted vault layout


_OMIT_SEEN = set()


def omit(section, reason):
    """Record an omission ONCE. Deduped on (section, reason) because several
    renderers are called repeatedly by design: `_render_starterkit` runs once per
    rung of its 7-step ladder to MEASURE each candidate, so an absent
    `libs[].version` was being recorded seven times. The audit trail is a set of
    facts about the inputs, not a log of how many times the builder looked."""
    key = (section, reason)
    if key in _OMIT_SEEN:
        return
    _OMIT_SEEN.add(key)
    SECTIONS_OMITTED.append({"section": section, "reason": reason})


def die(msg, code=2):
    """Exit 2 — usage / IO. Callers are the INPUT-LOADING failures (unit not
    found / unreadable) plus the two WRITE-PATH failures at the end (mkdir and
    the temp-file write). The write path is deliberately 2 and not 4: it is an
    environment/IO condition the operator fixes and re-runs, not a builder
    defect. Nothing is unlinked: on every die() path the os.replace() has not
    run, so THIS run published nothing, and the temp file is removed by its own
    handler before die() is called. Everything else that can fail raises, and
    the excepthook turns it into exit 4."""
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(code)


def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except (OSError, TypeError):
        return None


def nslash(p):
    """Normalize a path for STRING comparison: backslashes -> forward slashes,
    leading './' stripped. Windows-authored units and git porcelain output both
    appear in this repo; every startswith() comparison below runs on this form."""
    if not p:
        return ""
    p = p.replace("\\", "/")
    while p.startswith("./"):
        p = p[2:]
    return p


# ══════════════════════════════════════════════════════════════════════════════
# THE ABSENT-VALUE RULE (invariant #5 at KEY level)
# ══════════════════════════════════════════════════════════════════════════════
# context-enrichment.md §The absent-value rule: "A key=value pair whose value is
# absent is DROPPED, with the reason recorded — never rendered as None, null,
# n/a, -, or an empty string. If EVERY value on a line is absent, the whole line
# is omitted."
#
# THIS IS ONE HELPER FOR THE WHOLE CLASS, deliberately. Every composed line in
# the prompt that reads a possibly-absent sub-key of a present dict routes
# through `present()` / `compose()`: the greenfield `Design system:` line, the
# starterkit `Auth:` / `Authz:` / `UI/UX:` / `Design tokens:` / `Design system:` /
# `Libs in scope:` lines, and the §patterns `location` / `naming` / `extension`
# fields. A `design_system` block carrying only `style` is LEGAL — nothing
# requires all four keys — and `Design system: style=modern · palette=None` is
# not a degraded line, it is a placeholder that SATISFIES the
# `design_system_not_injected` gate while handing the implementer `None` as its
# authoritative palette. A rendered None is worse than an omitted line.
#
# THE DETECTOR IS A SMOKE ALARM, NOT A CIRCUIT BREAKER, AND IT LOOKS AT PAIRS.
# Round 2 shipped a regex scan of the ASSEMBLED PROMPT that exited 4 (=> "never
# dispatch") whenever the value-position shapes appeared anywhere in it. That
# made a bolt permanently undispatchable on legal machine-generated input — a
# `.mega-sdd/codebase/reuse-index.yaml` entry reading "returns None, or the user
# record.", the commonest docstring phrase in two of the ecosystems this
# pipeline must serve — and the exemption mechanism (a whitelist of remembered
# verbatim sources) could only ever be under-populated. Round 3 narrows it to
# what it can actually judge: the pair-level check in compose() below, on the
# RENDERED VALUE ONLY, never on file text and never on an assembled line. A hit
# is a WARNING. It cannot fire on prose, and nothing it says can destroy an
# artifact or block a dispatch.

# Tokens from the absent-value rule ("never rendered as None, null, n/a, -, or
# an empty string"), matched WHOLE against a rendered value — never searched for
# inside one. Three deliberate exclusions, each a real value in these fields:
# lower-case `none` (CSS `text-transform: none`, `auth: none` = a REAL auth
# strategy), a bare `-`, and `""` (present() already maps empty to absent).
# What is left is the Python/JSON placeholder vocabulary proper.
_PLACEHOLDER_TOKENS = ("None", "null", "Null", "NULL", "nil",
                       "n/a", "N/A", "undefined")


def present(v):
    """The absent test, in ONE place. Returns the rendered string, or None when
    the value is ABSENT. Absent == the key is missing, the YAML value was null
    (`_yl_value` maps `null`/`~`/`` to None), or the string is empty/whitespace.
    An explicit `false` / `0` is a VALUE, not an absence."""
    if v is None:
        return None
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (list, tuple)):
        vals = [present(x) for x in v]
        vals = [x for x in vals if x is not None]
        return None if not vals else vals
    s = str(v).strip()
    return s or None


def compose(section, prefix, pairs, sep=", ", tail="", tail_needs=None):
    """`<prefix> k=v<sep>k=v<tail>` with every absent pair DROPPED.

    `pairs` is [(label, raw_value), ...]. Returns "" when every value is absent
    (the whole line is omitted) and records the omission either way, so the audit
    trail distinguishes "line shipped without palette" from "line not shipped".
    `tail` is appended only when `tail_needs` (a label) survived — a trailing
    clause that talks ABOUT a value must not outlive that value.
    """
    kept, missing, placeheld, kept_labels = [], [], [], set()
    for label, raw in pairs:
        v = present(raw)
        if v is None:
            missing.append(label)
            continue
        if isinstance(v, list):
            v = ", ".join(v)
        if v.strip() in _PLACEHOLDER_TOKENS:
            # THE PAIR IS OMITTED. The rendered VALUE is a placeholder token, not
            # a value. present() already maps Python None -> absent, so reaching
            # here means the SOURCE literally holds the token (a caller
            # pre-interpolated a None, or the file says `palette: "None"`).
            #
            # It used to WARN and then render anyway — producing exactly what the
            # module comment above calls "worse than an omitted line", in the
            # same builder that names the failure. Measured: a vault.json with
            # `design_system.palette: "None"` shipped
            # `Design system: … · palette=None · …`, which satisfies
            # validate-ui-quality.sh's `design_system_not_injected` check
            # VACUOUSLY while handing the implementer `None` as its authoritative
            # palette. Invariant #5 discriminates and it is not ambiguous here:
            # absent input is OMITTED with a recorded reason, never defaulted —
            # and a source that says "None" supplied no palette. Omitting it
            # makes the gate fire HONESTLY on a project that has no palette,
            # which is the outcome the gate exists for.
            #
            # The warning survives, because the SOURCE is still what to fix and
            # the operator must see it. It remains a smoke alarm: a WARNING plus
            # a recorded omission, never an exit code. No regex, no
            # assembled-text scan — this compares one rendered value and cannot
            # fire on prose that merely contains the word.
            placeheld.append("%s (source says %r)" % (label, v.strip()))
            WARNINGS.append("absent-value smoke alarm: `%s` on the `%s` line held the "
                            "placeholder token %r in its SOURCE (invariant #5, "
                            "context-enrichment.md §The absent-value rule) — the pair is "
                            "OMITTED, not rendered; the source, not the builder, is what to fix"
                            % (label, prefix.rstrip(": "), v.strip()))
            continue
        kept.append("%s=%s" % (label, v))
        kept_labels.add(label)
    if not kept:
        omit(section, "every value on the `%s` line is absent in the source — whole line "
                      "OMITTED per the absent-value rule (absent keys: %s; placeholder-valued "
                      "keys: %s)"
                      % (prefix.rstrip(": "), ", ".join(missing) or "n/a",
                         ", ".join(placeheld) or "n/a"))
        return ""
    if missing:
        omit("%s.absent_keys" % section,
             "absent in the source and DROPPED from the `%s` line, never rendered as None: %s"
             % (prefix.rstrip(": "), ", ".join(missing)))
    if placeheld:
        omit("%s.placeholder_keys" % section,
             "the SOURCE holds a placeholder token, which is not a value — DROPPED from the "
             "`%s` line rather than rendered (a rendered placeholder satisfies the injection "
             "gate vacuously and hands the implementer a fabricated authority): %s"
             % (prefix.rstrip(": "), ", ".join(placeheld)))
    out = "%s %s" % (prefix, sep.join(kept))
    if tail and (tail_needs is None or tail_needs in kept_labels):
        out += tail
    return out


# ══════════════════════════════════════════════════════════════════════════════
# GENERIC PARSERS — hand-rolled, zero spawns, zero external deps
# ══════════════════════════════════════════════════════════════════════════════

FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---", re.DOTALL)


def frontmatter(text):
    """Leading `---` fenced block. Copied from scripts/analyze-parallelism.sh."""
    m = FRONTMATTER_RE.match(text or "")
    return m.group(1) if m else ""


def fm_scalar(fm, key):
    """Top-level `key: value` scalar (value may be quoted). '' when absent.
    Copied verbatim from analyze-parallelism.sh so the builder and the shipped
    parsers can never disagree about what a scalar is."""
    m = re.search(r"(?m)^%s:[ \t]*(.*)$" % re.escape(key), fm)
    if not m:
        return ""
    v = m.group(1).strip()
    if v.startswith("#") or v == "":
        return ""
    v = v.split("  #", 1)[0].strip()
    return v.strip("'\"")


def fm_list(fm, key):
    """Frontmatter list in BOTH forms — inline `key: [a, b]` / `key: []` and
    block `key:\\n  - a`. Copied from analyze-parallelism.sh."""
    m = re.search(r"(?m)^%s:[ \t]*(.*)$" % re.escape(key), fm)
    if not m:
        return []
    inline = m.group(1).strip()
    if inline.startswith("["):
        inner = inline[1:inline.rfind("]")] if "]" in inline else inline[1:]
        return [x.strip().strip("'\"") for x in inner.split(",") if x.strip()]
    if inline and not inline.startswith("#"):
        return [inline.strip("'\"")]
    items = []
    after = fm[m.end():]
    for line in after.split("\n"):
        bm = re.match(r"^[ \t]+-[ \t]+(.+?)[ \t]*$", line)
        if bm:
            val = bm.group(1).strip()
            if val.startswith("#"):
                continue
            items.append(val.strip("'\""))
        elif line.strip() == "":
            continue
        else:
            break
    return items


def fm_maps(fm, key):
    """Block list-of-maps under `key:` -> [{k: v}, ...], preserving file order.

    NO existing helper returns paired fields: analyze-parallelism.sh target_paths()
    and validate-unit-spec.sh _collect_target_files() BOTH return flat path lists
    and DISCARD `operation:`. Two hard-won fixes are copied rather than re-derived:
      - `[ \\t]*` NOT `\\s*` after the key (validate-unit-spec.sh:684-686 records
        that `\\s*` swallowed the newline and silently dropped the FIRST item);
      - the block ends on `^[A-Za-z_]` (a next TOP-LEVEL key), :696.
    Also accepts the inline-flow item form `- { name: x, path: y }`.
    """
    m = re.search(r"(?m)^%s[ \t]*:[ \t]*(.*)$" % re.escape(key), fm)
    if not m:
        return []
    if m.group(1).strip().startswith("["):          # `key: []` / inline flow list
        vals = _yl_value(m.group(1).strip())
        return [v for v in vals if isinstance(v, dict)] if isinstance(vals, list) else []
    out = []
    cur = None
    for line in fm[m.end():].split("\n"):
        if not line.strip():
            continue
        if re.match(r"^[A-Za-z_]", line):
            break                                    # next top-level key
        im = re.match(r"^[ \t]*-[ \t]*(.*)$", line)
        if im:
            rest = im.group(1).strip()
            if rest.startswith("{"):
                v = _yl_value(rest)
                out.append(v if isinstance(v, dict) else {})
                cur = None
                continue
            cur = {}
            out.append(cur)
            km = re.match(r"^([^:\s][^:]*?)[ \t]*:[ \t]*(.*)$", rest)
            if km:
                cur[km.group(1).strip()] = _yl_value(km.group(2))
            continue
        if cur is not None:
            km = re.match(r"^[ \t]+([^:\s][^:]*?)[ \t]*:[ \t]*(.*)$", line)
            if km:
                cur[km.group(1).strip()] = _yl_value(km.group(2))
    return [d for d in out if d]


def md_section(text, wanted):
    """Body of the first `## <wanted>...` section, or None.

    Case-insensitive PREFIX match on `line[3:].strip().lower()`, terminating at
    the next `## ` or any `# ` — replicated EXACTLY from
    scripts/_lib/resolve-framework-pack.sh:213-238. Equality matching would
    silently drop every pack override section (`## Naming standards (overrides
    + additions)`), shipping a base pack's conventions to a project that
    overrode them. A whitespace-only section counts as ABSENT (:244).
    """
    if not text:
        return None
    wl = wanted.strip().lower()
    body, capturing = [], False
    for line in text.splitlines():
        if line.startswith("## "):
            header = line[3:].strip().lower()
            if not capturing and header.startswith(wl):
                capturing = True
                continue
            elif capturing:
                break
        elif line.startswith("# ") and capturing:
            break
        if capturing:
            body.append(line)
    if not capturing:
        return None
    b = "\n".join(body).strip("\n")
    return b if b.strip() else None


def md_table(text, first_header_cell):
    """Rows of a pipe table whose header row starts with `first_header_cell`.

    The design-intelligence tables are GENERATED by scripts/_lib/distill-ui-ux.py,
    which pre-sanitizes every cell (newlines -> spaces, literal `|` -> `/`), so a
    naive split('|') is safe and no escaping logic is needed.
    """
    rows, header = [], None
    for ln in (text or "").splitlines():
        s = ln.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip().strip("|").split("|")]
        if header is None:
            if cells and cells[0].lower() == first_header_cell.lower():
                header = cells
            continue
        if cells and set("".join(cells)) <= set("-: "):
            continue                                  # separator row
        rows.append(cells)
    return rows


# ── Minimal YAML reader (block + flow), indentation-RELATIVE ──────────────────
# Extracts ONLY the shapes the mega-sdd artifacts actually emit. It is NOT a
# general YAML parser and must never become one. Two lessons copied from
# scripts/validate-starterkit-conformance.sh: indentation is RELATIVE (S5
# GU-SKC-INDENT — a 4-space-locked parser returned ZERO patterns and silently
# SKIPped every check), and a present-but-unparsed block is FAIL-LOUD (S5R),
# never a silent empty.

def _yl_scalar(v):
    """build-graph.sh `_scalar()` verbatim: strip matched surrounding quotes
    FIRST, then strip an UNQUOTED trailing `#` comment. A quoted value keeps any
    '#' inside it — `colors: { primary: "#3b82f6" }` is exactly the value a
    naive comment-stripper destroys, turning the tokens line into a vacuous FAIL."""
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ('"', "'"):
        return v[1:-1]
    v = re.sub(r"\s+#.*$", "", v).strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ('"', "'"):
        return v[1:-1]
    return v


def _split_flow(s):
    """Split a flow-collection body on TOP-LEVEL commas, honoring quotes and
    nesting. reuse-index flow elements contain `:` and `@`
    (`methods: [ "hasRole(string|Role $role): bool   @88" ]`) and model names
    carry escaped backslashes — a naive split shreds them."""
    out, buf, depth, quote = [], [], 0, None
    for ch in s:
        if quote:
            buf.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            buf.append(ch)
            continue
        if ch in "[{":
            depth += 1
            buf.append(ch)
            continue
        if ch in "]}":
            depth -= 1
            buf.append(ch)
            continue
        if ch == "," and depth == 0:
            out.append("".join(buf))
            buf = []
            continue
        buf.append(ch)
    if buf:
        out.append("".join(buf))
    return [x for x in (y.strip() for y in out) if x]


def _yl_value(v):
    v = (v or "").strip()
    if v.startswith("[") and v.endswith("]"):
        return [_yl_value(x) for x in _split_flow(v[1:-1])]
    if v.startswith("{") and v.endswith("}"):
        d = {}
        for part in _split_flow(v[1:-1]):
            k, sep, val = part.partition(":")
            if sep:
                d[_yl_scalar(k)] = _yl_value(val)
        return d
    s = _yl_scalar(v)
    if s in ("null", "Null", "NULL", "~", ""):
        return None
    if s in ("true", "True"):
        return True
    if s in ("false", "False"):
        return False
    return s


def _yl_lines(text):
    out = []
    for raw in (text or "").splitlines():
        if not raw.strip():
            continue
        stripped = raw.lstrip(" \t")
        if stripped.startswith("#"):
            continue
        out.append((len(raw) - len(stripped), stripped))
    return out


def _yl_normalize(lines):
    """Re-indent a same-column `- ` run that follows a bare `key:` line by +2.
    `idioms:\\n- "a"` is legal YAML but breaks a purely indent-driven walk."""
    out = list(lines)
    for i in range(len(out)):
        ind, txt = out[i]
        if not re.match(r"^[^:\-\s][^:]*?[ \t]*:[ \t]*$", txt):
            continue
        j = i + 1
        if j >= len(out) or out[j][0] != ind:
            continue
        if not (out[j][1] == "-" or out[j][1].startswith("- ")):
            continue
        k = j
        while k < len(out):
            kind, ktxt = out[k]
            if kind > ind or (kind == ind and (ktxt == "-" or ktxt.startswith("- "))):
                out[k] = (kind + 2, ktxt)
                k += 1
            else:
                break
    return out


def _yl_block(lines):
    if not lines:
        return None
    base = min(l[0] for l in lines)
    tops = [i for i, l in enumerate(lines) if l[0] == base]
    first = lines[tops[0]][1]
    if first == "-" or first.startswith("- "):
        seq = []
        for n, start in enumerate(tops):
            end = tops[n + 1] if n + 1 < len(tops) else len(lines)
            raw = lines[start][1]
            after = raw[1:]
            rest = after.strip()
            off = 1 + (len(after) - len(after.lstrip(" \t")))
            sub = lines[start + 1:end]
            if rest == "":
                seq.append(_yl_block(sub) if sub else None)
            elif (rest.startswith("[") and rest.endswith("]")) or \
                 (rest.startswith("{") and rest.endswith("}")):
                seq.append(_yl_value(rest))
            elif re.match(r"^[^:\s][^:]*?[ \t]*:([ \t]|$)", rest):
                virt = [(base + off, rest)] + list(sub)
                seq.append(_yl_block(_yl_normalize(virt)))
            else:
                seq.append(_yl_value(rest))
        return seq
    d = {}
    for n, start in enumerate(tops):
        end = tops[n + 1] if n + 1 < len(tops) else len(lines)
        m = re.match(r"^([^:\s][^:]*?)[ \t]*:[ \t]*(.*)$", lines[start][1])
        if not m:
            continue
        key, val = _yl_scalar(m.group(1)), m.group(2).strip()
        sub = lines[start + 1:end]
        if val == "" or val.startswith("#"):
            d[key] = _yl_block(sub) if sub else None
        else:
            d[key] = _yl_value(val)
    return d


def yaml_lite(text):
    """Parse a mega-sdd YAML artifact. Returns dict/list/None."""
    lines = _yl_normalize(_yl_lines(text))
    return _yl_block(lines)


# ── Recursive glob matcher ────────────────────────────────────────────────────
# REUSED VERBATIM from scripts/validate-dispatch-prompt.sh:119-157 (itself cloned
# into validate-ui-quality.sh + validate-flow-coverage.sh). Using a DIFFERENT
# matcher would change which pack rules land in T2, which changes the truncation
# cascade's input set — and the cascade is a moat surface that must be reproduced
# exactly. Python fnmatch mishandles `**`.
def _glob_to_regex(pat):
    i, n, out = 0, len(pat), ["(?s:"]
    while i < n:
        c = pat[i]
        if c == "*":
            if pat[i:i + 3] == "**/":
                out.append("(?:.*/)?")
                i += 3
                continue
            if pat[i:i + 2] == "**":
                out.append(".*")
                i += 2
                continue
            out.append("[^/]*")
            i += 1
            continue
        if c == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(c))
        i += 1
    out.append(r")\Z")
    return re.compile("".join(out))


_GLOB_CACHE = {}


def glob_match(path, pattern):
    if not pattern:
        return False
    rx = _GLOB_CACHE.get(pattern)
    if rx is None:
        rx = _glob_to_regex(pattern)
        _GLOB_CACHE[pattern] = rx
    if rx.match(path):
        return True
    return rx.match(path.split("/", 1)[-1]) is not None if "/" in path else False


# ══════════════════════════════════════════════════════════════════════════════
# INPUT LOADING
# ══════════════════════════════════════════════════════════════════════════════

# ── Unit file ─────────────────────────────────────────────────────────────────
# `--vault` is EXPLICIT, so the vault-local shapes are tried FIRST:
# vault_layouts.find_unit_file() searches ALL layouts and on a multi-vault project
# would happily hand back a unit from the WRONG vault. It stays as the fallback
# for unusual layouts.
UNIT_PATH = None
for cand in (os.path.join(VAULT, "units", UNIT_ID + ".md"),
             os.path.join(VAULT, "units", UNIT_ID, "unit.md")):
    if os.path.isfile(cand):
        UNIT_PATH = cand
        break
if UNIT_PATH is None:
    UNIT_PATH = vault_layouts.find_unit_file(CWD, UNIT_ID)
if UNIT_PATH is None:
    die("unit %s not found under %s (nor any vault layout under %s)" % (UNIT_ID, VAULT, CWD))

UNIT_TEXT = read_text(UNIT_PATH)
if UNIT_TEXT is None:
    die("cannot read unit file: %s" % UNIT_PATH)
FM = frontmatter(UNIT_TEXT)

unit_id = fm_scalar(FM, "id") or UNIT_ID
unit_title = fm_scalar(FM, "title")
unit_task_type = fm_scalar(FM, "task_type") or "create"
unit_scope = fm_scalar(FM, "scope")
unit_scope_name = fm_scalar(FM, "scope_name")
unit_module = fm_scalar(FM, "module")
unit_risk = fm_scalar(FM, "risk")
unit_status = fm_scalar(FM, "status")
depends_on = fm_list(FM, "depends_on")
binding_refs = fm_list(FM, "binding_refs")
starterkit_relevance = [f for f in fm_list(FM, "starterkit_relevance")
                        if f in ("auth", "authz", "ui_ux", "libs")]
reuse_candidates = fm_maps(FM, "reuse_candidates")
properties = fm_maps(FM, "properties")

# target_files: (path, operation) pairs. Frontmatter is the primary carrier; the
# `## Target files` BODY block is a SECOND carrier unit-schema.md never mentions
# but validate-unit-spec.sh:678-681 accepts ("TF units carry paths ONLY in the
# body block ... so reading frontmatter alone misses them"). A frontmatter-only
# reader silently produces an EMPTY whitelist for those units.
def _expand_braces(p):
    """Expand a single {a,b} brace group. Copied from validate-unit-spec.sh:666-675
    so the builder's whitelist and the unit validator's path set agree exactly —
    an unexpanded `views/{show,edit}.blade.php` is not a real path and would ship
    a bogus entry in the inline_core whitelist."""
    m = re.search(r"\{([^{}]*)\}", p)
    if not m:
        return [p]
    pre, post = p[:m.start()], p[m.end():]
    out = []
    for opt in m.group(1).split(","):
        out.extend(_expand_braces(pre + opt.strip() + post))
    return out


target_files = []
for e in fm_maps(FM, "target_files"):
    p = nslash(str(e.get("path") or "").strip())
    if p:
        for xp in _expand_braces(p):
            target_files.append({"path": xp, "operation": str(e.get("operation") or "").strip()})
if not target_files:
    body_tf = re.search(r"(?ims)^##[ \t]+Target[ \t]+files\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", UNIT_TEXT)
    if body_tf:
        for ln in body_tf.group(1).splitlines():
            s = ln.strip()
            if not s or s.startswith("```") or s.startswith("<"):
                continue
            s = re.sub(r"^[-*+][ \t]*", "", s)
            om = re.search(r"\((edit|new|modify|create|delete)\)\s*$", s, re.IGNORECASE)
            op = {"edit": "modify", "new": "create"}.get(
                (om.group(1).lower() if om else ""), (om.group(1).lower() if om else ""))
            s = re.sub(r"\s*\((?:edit|new|modify|create|delete)\)\s*$", "", s, flags=re.IGNORECASE)
            s = s.strip().strip("`").strip()
            if s and not s.endswith(":"):
                for xp in _expand_braces(nslash(s)):
                    target_files.append({"path": xp, "operation": op})
TARGET_PATHS = [t["path"] for t in target_files]

# acceptance_test entries: the SAME region extraction validate-unit-spec.sh:198 /
# run-acceptance-tests.sh:122-124 use (the house contract). Note the validator
# also accepts a BODY `acceptance_test:` block, so we search the whole file.
acceptance_tests = []
_at = re.search(r"^acceptance_test\s*:\s*(.*?)(?=^\S|\Z)", UNIT_TEXT, re.DOTALL | re.MULTILINE)

# `_authored_by` is pulled with a STANDALONE regex BEFORE any structured parse.
# decomposition-rails.md:159-170 documents it as a mapping key SIBLING of a block
# sequence under the SAME `acceptance_test:` key — that is structurally INVALID
# YAML, and a structured load would throw on the WHOLE frontmatter, on exactly
# the units that need the NOTE.
#
# REGION PARITY (context-enrichment.md §Acceptance-test provenance NOTE): it is
# read from THE SAME REGION as the `acceptance_test` block it belongs to, never
# from the frontmatter while the block itself is found whole-file. The old
# asymmetry (`_ab` over FM, `_at` over UNIT_TEXT) made a BODY-authored
# `_authored_by: adversarial-reviewed (+2 gaps merged)` read as ABSENT — and
# absent is one of the conditions that FIRES the weak-provenance NOTE. The same
# prompt then showed the real strong value in the verbatim unit body three
# sections above while asserting it was missing, and instructed the subagent to
# cap confidence at MEDIUM on exactly the units generate-units spent adversarial
# review on. Absent WITHIN the block = genuinely absent.
_ab = re.search(r"(?m)^\s*_authored_by\s*:\s*(.+)$", _at.group(0) if _at else "")
authored_by = _yl_scalar(_ab.group(1)) if _ab else None

if _at:
    cur = None
    for line in _at.group(1).splitlines():
        if not line.strip() or line.strip().startswith("#"):
            continue
        im = re.match(r"^[ \t]*-[ \t]*(.*)$", line)
        if im:
            cur = {}
            acceptance_tests.append(cur)
            rest = im.group(1).strip()
            km = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)[ \t]*:[ \t]*(.*)$", rest)
            if km:
                cur[km.group(1)] = _yl_scalar(km.group(2))
            continue
        km = re.match(r"^[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*:[ \t]*(.*)$", line)
        if km and cur is not None:
            cur[km.group(1)] = _yl_scalar(km.group(2))
    acceptance_tests = [a for a in acceptance_tests if a]

# Hard rules: REUSE the SHARED B1 engine. A second lexer in the dispatch builder
# would list a different `hard_rules_active` set than the gate enforces — the
# exact fork postflight_rules.py:1-19 exists to prevent.
HARD_RULE_LINES, HARD_RULE_V2 = postflight_rules.extract_hard_rules(UNIT_TEXT)

# ── vault.json ────────────────────────────────────────────────────────────────
VAULT_JSON_PATH = os.path.join(VAULT, "vault.json")
vault_json = {}
_vj = read_text(VAULT_JSON_PATH)
if _vj is not None:
    try:
        vault_json = json.loads(_vj) or {}
    except ValueError:
        WARNINGS.append("vault.json is not valid JSON — vault_sha256/design_system omitted")
        vault_json = {}
# "vault sha256" == sha256 of the vault.json FILE BYTES (build-citation-map.sh:301,
# shared-snapshot-schema.md:54, detect-drift/auto-and-chain.md:125). NOT prd_sha256,
# NOT constitution_hash. Reuses postflight_rules.sha256_of — in-process, 0 spawns.
vault_sha256 = postflight_rules.sha256_of(VAULT_JSON_PATH) if os.path.isfile(VAULT_JSON_PATH) else None
if vault_sha256 is None:
    omit("provenance.vault_sha256", "vault.json absent or unreadable at %s — value OMITTED, never placeholder-filled" % VAULT_JSON_PATH)

design_system = vault_json.get("design_system") if isinstance(vault_json.get("design_system"), dict) else None
scope_meta = vault_json.get("scope_metadata") if isinstance(vault_json.get("scope_metadata"), dict) else {}
# scope_id/scope_name MUST be sourced verbatim, never inferred (unit-schema.md:326).
scope_id = unit_scope or str(scope_meta.get("id") or "")
scope_name = unit_scope_name or str(scope_meta.get("name") or "")

# ── Framework packs (bodies read IN-PROCESS from the resolver's chain) ────────
PACK_DIR = os.path.join(PLUGIN_ROOT, "references", "framework-conventions")
PACK_BODIES = []                     # [(basename, text)] most-specific-first

# PACK CHAIN UNRESOLVED != PACKLESS PROJECT (context-enrichment.md §Builder
# contract, "Pack-resolver exit codes MUST be discriminated"). exit 0 = chain,
# exit 3 = documented SKIP, ANYTHING ELSE = the chain is UNKNOWN. The Windows
# App-Execution-Alias state (resolver exits 49) used to land here as an empty
# chain at exit 0, silently stripping `## Framework pack rules` AND the
# pack-derived `DO NOT WRITE:` anti-context from every bolt — with omission
# reasons textually identical to a project that genuinely has no pack, so the
# audit trail concealed the loss instead of exposing it.
PACK_UNRESOLVED = PACK_RC not in (0, 3)
PACK_UNRESOLVED_NOTE = ("framework pack chain UNRESOLVED (resolver exit %d, interpreter %s) "
                        "— this is NOT a packless project" % (PACK_RC, PY_USED))
if PACK_UNRESOLVED:
    WARNINGS.append(PACK_UNRESOLVED_NOTE + ". The dispatch ships WITHOUT pack rules and "
                    "without the pack-derived DO NOT WRITE anti-context; this is a recorded "
                    "degradation, not an absent input. On Windows exit 49 is the App "
                    "Execution Alias stub — see scripts/_lib/resolve-python.sh.")
    omit("framework_pack.chain", PACK_UNRESOLVED_NOTE)

for name in PACK_CHAIN:
    t = read_text(os.path.join(PACK_DIR, name))
    if t is not None:
        PACK_BODIES.append((name, t))
if PACK_CHAIN and not PACK_BODIES:
    # A resolved chain whose files cannot be read is a BUILDER error (bad
    # plugin-root), not a legitimately packless project — the two must not look
    # identical. Surfaced, not silently degraded to "no rules".
    WARNINGS.append("framework pack chain resolved (%s) but no pack file readable under %s"
                    % (" ".join(PACK_CHAIN), PACK_DIR))
ACTIVE_PACK = PACK_CHAIN[0] if PACK_CHAIN else ""


def _chain_desc():
    """How the pack chain is DESCRIBED in every omission reason and header. The
    three states must never read alike: resolved / legitimately packless /
    unresolved-and-therefore-unknown."""
    if PACK_CHAIN:
        return " ".join(PACK_CHAIN)
    if PACK_UNRESOLVED:
        return "UNRESOLVED (resolver exit %d, interpreter %s) — NOT a packless project" % (PACK_RC, PY_USED)
    return "none resolved (resolver exit 3 — documented SKIP: no pack applies to this project)"


ACTIVE_PACK_LABEL = ACTIVE_PACK or (
    "(pack chain UNRESOLVED — resolver exit %d; NOT a packless project)" % PACK_RC
    if PACK_UNRESOLVED else "(no pack resolved)")


def pack_section(wanted):
    """Concatenated `## <wanted>` bodies, most-specific-first, as
    [(pack, body)] — the in-process equivalent of one `--section` spawn."""
    out = []
    for name, text in PACK_BODIES:
        sec = md_section(text, wanted)
        if sec:
            out.append((name, sec))
    return out


# ── ui_bearing ────────────────────────────────────────────────────────────────
# context-enrichment.md:125-130 AS WRITTEN: pack `view_glob` match OR the
# universal frontend shapes. Only 3 of 27 packs declare a view_glob, so
# narrowing this to the pack glob alone would make every UI unit on 23/27 stacks
# non-ui_bearing and silently kill the design slice — the exact greenfield
# regression the slice was built to close.
UNIVERSAL_UI_GLOBS = [
    "*.blade.php", "*.html.erb", "*.twig", "*.jsx", "*.tsx", "*.vue", "*.svelte",
    "*.html", "*.css", "*.scss", "*.less", "*.cshtml", "*.razor",
    "components/**", "pages/**", "views/**", "templates/**", "Views/**",
    "**/components/**", "**/views/**", "**/templates/**",
]
view_glob = ""
for _pack, _sec in pack_section("UI quality signatures"):
    m = re.search(r"^\s*view_glob\s*:\s*(.+)$", _sec, re.MULTILINE)
    if m:                                            # FIRST hit wins (most-specific pack)
        v = m.group(1).strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
            v = v[1:-1]
        view_glob = v
        break

ui_bearing = False
ui_bearing_why = ""
for p in TARGET_PATHS:
    base = p.rsplit("/", 1)[-1]
    if view_glob and (glob_match(p, view_glob) or glob_match(base, view_glob)):
        ui_bearing, ui_bearing_why = True, "pack view_glob %s matched %s" % (view_glob, p)
        break
    for g in UNIVERSAL_UI_GLOBS:
        if glob_match(p, g) or glob_match(base, g):
            ui_bearing, ui_bearing_why = True, "universal frontend shape %s matched %s" % (g, p)
            break
    if ui_bearing:
        break


# ══════════════════════════════════════════════════════════════════════════════
# ANCHOR FRESHNESS (assembly-time, IN-PROCESS, non-halting)
# ══════════════════════════════════════════════════════════════════════════════
# We do NOT spawn scripts/check-anchor-freshness.sh, for two structural reasons:
#  (1) THE REPLACEMENT IS PER-ANCHOR. context-enrichment.md:79 substitutes
#      `ANCHOR STALE (verify before use)` for the label of an INDIVIDUAL entry.
#      The script exposes only a UNIT-level exit code; its per-anchor detail is
#      Indonesian human prose on stderr. An exit code cannot drive a per-entry
#      label, and parsing that stderr would be a fragile contract.
#  (2) COST + SCOPE. The script costs ~5 spawns/unit (bash, python3, rev-parse,
#      ls-files, and the `git log -300` inside walk_unit_commits), and it is
#      STRICTER than this contract needs: :79 asks "path exists", the script asks
#      GIT-TRACKED, and walk_unit_commits exists ONLY to pick HALT vs ADVISORY.
#      The builder stamps a LABEL and never halts, so it needs neither.
# The two regexes and the `<`-skip rule below are copied VERBATIM from
# check-anchor-freshness.sh:94/100/103-104 so the two probes can never disagree
# about what an anchor IS. execute-bolts Step 3.7 keeps invoking the SCRIPT and
# keeps owning the `anchor_missing` halt — these are two distinct contracts.
# NOT hoistable to one batch-start pass: "never a bind-era HIGH re-stamped
# mid-batch" (:79) means the probe must reflect the tree at THIS bolt's assembly.
ANCHOR_TOKEN_RE = re.compile(
    r"(?<![\w:/])((?:[\w.\-]+/)*[\w.\-]+\.[A-Za-z][\w]{0,7}):(\d+)(?:-\d+)?\b")

anchors = []          # [(path, line)]
_am = re.search(r"(?ims)^##[ \t]+Anchors\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", UNIT_TEXT)
if _am:
    for ln in _am.group(1).splitlines():
        if ln.strip().startswith("<"):
            continue                                  # template placeholder
        for tok in ANCHOR_TOKEN_RE.finditer(ln):
            anchors.append((tok.group(1), int(tok.group(2))))

anchor_rows = []      # [(path, line, stale_bool)]
for apath, aline in anchors:
    p = apath[2:] if apath.startswith("./") else apath
    full = os.path.join(CWD, p.replace("/", os.sep))
    stale = True
    if os.path.isfile(full):
        txt = read_text(full)
        if txt is not None:
            n = len(txt.splitlines())
            stale = not (1 <= aline <= n)
    anchor_rows.append((p, aline, stale))
anchors_fresh = sum(1 for _, _, s in anchor_rows if not s)
# NOTE: context-enrichment.md:79 also asks "when the binding recorded an
# excerpt/sha, the region still matches". That clause has NO INPUT TO READ —
# binding.md's State Map Anchor cell and binding.json's `anchor` field are
# free-text strings with no excerpt and no sha anywhere in the schema. We
# implement the existence + line-range half and stay SILENT about excerpts
# rather than manufacturing a comparison.


# ══════════════════════════════════════════════════════════════════════════════
# TIER 1
# ══════════════════════════════════════════════════════════════════════════════

PLUGIN_VERSION = ""
_pj = read_text(os.path.join(PLUGIN_ROOT, ".claude-plugin", "plugin.json"))
# NOTE: bolt-dispatch-prompt.md:51-53 says the version lives in `plugin.json`
# "under the resolved plugin root". It does not — the only plugin.json in the
# tree is at <root>/.claude-plugin/plugin.json. Reported, not silently patched.
if _pj:
    try:
        PLUGIN_VERSION = str(json.loads(_pj).get("version") or "")
    except ValueError:
        PLUGIN_VERSION = ""

t1 = []
t1.append("═══════════════════════════════════════════")
t1.append("BOLT SUBAGENT DISPATCH — %s" % unit_id)
t1.append("═══════════════════════════════════════════")
t1.append("mega-sdd-trace:execute-bolts:%s" % unit_id)
t1.append("")
t1.append('UNIT: %s "%s"' % (unit_id, unit_title))
# scope_id/scope_name are NEVER inferred. With no scope the SCOPE: parenthetical
# is omitted rather than invented, and the framework token gets its own line.
if scope_id:
    t1.append("SCOPE: %s%s — framework: %s" % (
        scope_id, (" (%s)" % scope_name) if scope_name else "", ACTIVE_PACK_LABEL))
else:
    t1.append("FRAMEWORK: %s" % ACTIVE_PACK_LABEL)
t1.append("")
t1.append("═══════════════════════════════════════════")
t1.append("TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)")
t1.append("═══════════════════════════════════════════")
t1.append("")
t1.append("## Unit body (verbatim)")
t1.append(UNIT_TEXT.rstrip("\n"))
t1.append("")
t1.append("## Contracts (agent-carried)")
t1.append("")
# A WRONG version is worse than an absent one — the line's forensic purpose is
# "resolve the exact contract text by name + version".
t1.append("Halt / self-report / rollback / provenance / atomic contracts: carried by "
          "your system prompt (agents/bolt-implementer.md%s)"
          % (", mega-sdd v%s" % PLUGIN_VERSION if PLUGIN_VERSION else ""))
if not PLUGIN_VERSION:
    omit("contracts.plugin_version",
         "plugin.json unreadable under %s — line emitted WITHOUT a version rather than inventing one" % PLUGIN_ROOT)
t1.append("")
t1.append("## Provenance values (per-dispatch)")
t1.append("")
t1.append("The VALUES the agent fills into the agent-carried trailer shape (its system")
t1.append("prompt §Provenance trailer) in every modified file:")
t1.append("")
t1.append("```")
t1.append("Provenance values:")
t1.append("  unit_id: %s" % unit_id)
if vault_sha256:
    t1.append("  vault_sha256: %s" % vault_sha256)
PROV_CLAIM_SLOT = len(t1)            # claims are filled in after binding.md loads
t1.append(None)                      # placeholder, replaced below
if anchor_rows:
    t1.append("  anchors_consulted:")
    for p, ln, stale in anchor_rows:
        t1.append("    - %s:%d%s" % (p, ln, "  ANCHOR STALE (verify before use)" if stale else ""))
    # halts-and-handoff.md:90-95 — never print a verified count no check produced.
    # The line MUST STATE WHAT WAS PROBED (context-enrichment.md §Anchor
    # freshness): the residual gap is real — an anchor whose file content was
    # rewritten IN PLACE at the same line still passes — and closing it needs a
    # bind-time excerpt/sha field that no binding schema records. Naming the
    # probe's scope is the honest alternative to either a bare count (which
    # over-claims) or a comparison invented against an input that does not exist.
    t1.append("  anchors_verified: %d/%d (path + line-range only — content drift NOT checked)"
              % (anchors_fresh, len(anchor_rows)))
else:
    t1.append("  anchors_consulted: (none)")
if HARD_RULE_LINES:
    # The unit's Hard rules carry NO ids (they are mechanical productions), so the
    # template's "<list of rule IDs>" is satisfied with the VERBATIM rule text —
    # synthesizing ids here would fork from the B1 engine's own identity model.
    t1.append("  hard_rules_active:")
    for r in HARD_RULE_LINES:
        t1.append("    - %s" % r)
else:
    t1.append("  hard_rules_active: (none)")
if HARD_RULE_V2:
    t1.append("  hard_rules_v2_ast_rules: %d ast-grep rule block(s) in ## Hard rules" % len(HARD_RULE_V2))
t1.append("```")

# ── Acceptance-test provenance NOTE ──────────────────────────────────────────
# FIRES when `_authored_by` starts with `same-pass` OR `adversarial-review-failed`,
# AND when the field is ABSENT ENTIRELY (legacy units default to same-pass —
# bolt-dispatch-prompt.md:100, explicit). This is the one place where absence is
# NOT omission, and getting it inverted is the classic bug here.
_ab_val = (authored_by or "").strip()
note_fires = (_ab_val == "" or _ab_val.startswith("same-pass")
              or _ab_val.startswith("adversarial-review-failed"))
if note_fires:
    shown = _ab_val if _ab_val else "absent — legacy unit, treated as same-pass"
    t1.append("")
    t1.append("## Acceptance-test provenance NOTE")
    t1.append("")
    t1.append("> NOTE: This unit's `acceptance_test` has weak blind-spot coverage")
    t1.append("> (_authored_by: %s). The test was authored by the same LLM pass that" % shown)
    t1.append("> wrote the unit body — the test may inherit the same blind spots as the spec")
    t1.append("> and fail to catch behavioral bugs your implementation introduces.")
    t1.append(">")
    t1.append("> If your implementation passes this test but feels under-validated:")
    t1.append(">   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`")
    t1.append(">     explaining what you suspect the test might miss")
    t1.append(">   - Propose 1-2 additional assertions you'd add to strengthen coverage")
    t1.append(">   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested")
    SECTIONS_EMITTED.append("t1.acceptance_test_note")
else:
    omit("t1.acceptance_test_note",
         "_authored_by=%s has strong provenance — NOTE omitted per bolt-dispatch-prompt.md:96-97" % _ab_val)

# ── Reuse index T1 line (UNCONDITIONAL — even when the index does not exist) ──
t1.append("")
t1.append("Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup")
t1.append("surface (Iron Rule 4): scan the FULL index with Read/Grep before writing any")
t1.append("new capability; reuse_candidates below is only a hint.")
if reuse_candidates:
    t1.append("")
    t1.append("## Reuse candidates (fast-path hint — NOT the boundary)")
    for rc in reuse_candidates:
        nm = str(rc.get("name") or "").strip()
        pth = str(rc.get("path") or "").strip()
        sig = str(rc.get("signature") or "").strip()
        pur = str(rc.get("purpose") or "").strip()
        bits = [b for b in ("`%s`" % sig if sig else "", pur) if b]
        t1.append("- %s%s%s" % (nm, " (%s)" % pth if pth else "",
                                (" — " + " — ".join(bits)) if bits else ""))
    SECTIONS_EMITTED.append("t1.reuse_candidates")

# ── Anti-context block ───────────────────────────────────────────────────────
# "populated from actual data sources ... NEVER invented" (:253). Each line is
# emitted ONLY when a real source produced it; an absent source drops the LINE.
anti = []
# ── DO NOT MODIFY — a LABELLED UNION of TWO sources, never one substituted ────
# bolt-dispatch-prompt.md §Anti-context specifies TWO contributors and requires
# EVERY entry to carry the source it came from:
#   (a) the `[LOCKED]` entries of <kb>/99-rebuild-architecture/data-mutation-policy.md
#   (b) the unit's own `## Hard rules` DO NOT / MUST NOT / NEVER modify lines
# The builder previously read (b) ALONE and labelled it as the whole line, while
# both spec files said the block is populated from data-mutation-policy.md — an
# undisclosed source SUBSTITUTION, which is the subtlest invariant-#5 breach
# (the citation is real, the assertion is not). Failure it produced: a
# legacy-rebuild project whose KB marks `LegacyLedger` [LOCKED] there, on a unit
# whose generated Hard rules do not restate it, ships a bolt that modifies the
# locked file. Either source absent contributes nothing and is RECORDED; both
# absent omits the line.
_locked_entries = []                                 # [(path, source-label)]

# (a) data-mutation-policy.md — a real artifact: extract-intelligence Wave 5
# writes it, generate-intent reads it, validate-kb-reengineering.sh halt-enforces
# it. KB root candidates mirror scripts/build-advisor-bundle.sh.
DMP_PATH = None
for _kb in (".mega-sdd/knowledge-base", "docs/knowledge-base", "old-reference/knowledge-base"):
    _cand = os.path.join(CWD, _kb.replace("/", os.sep), "99-rebuild-architecture",
                         "data-mutation-policy.md")
    if os.path.isfile(_cand):
        DMP_PATH = _cand
        break
if DMP_PATH:
    _dmp = read_text(DMP_PATH) or ""
    _seen_locked = set()

    def _dmp_rows(section_name):
        """Data rows of the pipe table inside ONE named section.

        THE HEADER IS DROPPED STRUCTURALLY — it is the FIRST pipe row, and it is
        a header only because the SECOND pipe row is the `|---|` alignment row.
        The previous version dropped it by a hardcoded name allowlist ("entity",
        "entity.field"), so a project whose table reads `| Field | Tier | Policy |`
        shipped the header cell `Field` as a `DO NOT MODIFY:` path, cited to a
        real KB file and section: a fabricated LOCKED entry wearing a true
        citation, which is invariant #5's exact failure shape. No validator pins
        the header wording (the KB is an LLM-generated artifact), so the wording
        could never be the discriminator.

        THE DELIMITER TEST IS POSITIONAL, and that is the round-4 fix. The
        predecessor treated ANY row whose cells hold only dashes/colons/spaces as
        a delimiter and discarded the row above it as a header. A real `[LOCKED]`
        entry sitting directly above a filler row (`| - | - | - | - |`, a legal
        way to write an empty row) was therefore dropped from `DO NOT MODIFY:` —
        SILENTLY, because unlike the no-delimiter case nothing was recorded.
        Reproduced on a two-entry policy table: the first entry vanished and
        `sections_omitted` was empty. Dropping a LOCKED entry silently is the
        same invariant-#5 class as inventing one — one direction fabricates a
        rule, the other fabricates its absence, and the anti-context block the
        implementer treats as BINDING is wrong either way.

        In markdown an alignment row is the SECOND row of ITS OWN table, never
        any later one — so the test is per-table `[1]` and nothing else. The
        artifact's schema promises ONE TABLE PER SECTION
        (extract-intelligence/references/knowledge-base-schema.md
        §`data-mutation-policy.md` template: `## Entity-level summary`,
        `## Per-locked-field policy` and `## Discardable artifacts` each carry
        exactly one) — but that is a PROMPT-LEVEL guarantee about an LLM-written
        file and nothing enforces it, so we do not lean on it. Rows are grouped
        into contiguous pipe BLOCKS first: in markdown a table ends at the first
        blank or non-pipe line, so each block is exactly one table and gets its
        own header/alignment pair skipped. Flattening the section into one row
        list instead would put a second table's header at a data index and emit
        that header cell as a locked path — a real citation on an invented rule.

        NO ALIGNMENT ROW, NO TABLE. A pipe block whose second row is not a
        `|---|` delimiter is not a markdown table and its first row cannot be
        distinguished from data, so NOTHING is emitted and the absence is
        recorded — fail closed, never guess which row was the header. A
        dash-only row ANYWHERE ELSE is filler, not structure: it is dropped
        (its first cell is not a path) and the drop is RECORDED. Template
        placeholders (`<entity.field>`, `...`) are still dropped, structurally:
        they are literal template residue, not a name allowlist.
        """
        body = md_section(_dmp, section_name)
        # Group into CONTIGUOUS pipe blocks — a markdown table ends at the first
        # blank/non-pipe line, so one block == one table.
        blocks = []                                       # [[(cells, is_separator), ...], ...]
        _cur = []
        for _ln in (body or "").splitlines():
            _s = _ln.strip()
            if not _s.startswith("|"):
                if _cur:
                    blocks.append(_cur)
                    _cur = []
                continue
            _cells = [c.strip() for c in _s.strip("|").split("|")]
            if not _cells or not _cells[0]:
                continue
            _cur.append((_cells, set("".join(_cells)) <= set("-: ")))
        if _cur:
            blocks.append(_cur)
        _omit_key = ("t1.anti_context.do_not_modify.data_mutation_policy.%s"
                     % section_name.replace(" ", "_"))
        # A block is a real table iff its SECOND row is a `|---|` delimiter — then
        # its header is identified structurally and its data rows are safe to read.
        # EVERY such block is read, not just the first: the schema promises one
        # table per section, but it is a prompt-level promise about an LLM-written
        # file, and dropping a valid extra block would silently UNDER-lock (a bolt
        # then modifies a genuinely [LOCKED] path) — the mirror of the fabrication
        # this grouping exists to prevent. A block that FAILS the delimiter test is
        # not a table, its header cannot be told from data, and it is skipped WHOLE
        # and recorded — fail closed, never guess which row was the header.
        tables = []
        for _bi, _blk in enumerate(blocks):
            if len(_blk) >= 2 and _blk[1][1]:
                tables.append(_blk)
            else:
                omit(_omit_key + ".non_table_block",
                     "`## %s` in %s carries a pipe block (block %d of %d) whose SECOND row is not a "
                     "`|---|` delimiter — it is not a markdown table, its header row cannot be "
                     "identified structurally, and it is skipped WHOLE rather than risk emitting a "
                     "header cell as a locked path" % (section_name, DMP_PATH, _bi + 1, len(blocks)))
        if len(tables) > 1:
            omit(_omit_key + ".extra_table_block",
                 "`## %s` in %s carries %d markdown tables (the schema promises ONE per section). "
                 "ALL of them are read — each has its own header/alignment pair, so no header cell "
                 "can ship as a locked path — but split them into their own `##` sections so the "
                 "citation names which table an entry came from"
                 % (section_name, DMP_PATH, len(tables)))
        if not tables:
            if blocks:
                omit(_omit_key,
                     "`## %s` in %s has pipe rows but no block whose SECOND row is a `|---|` "
                     "delimiter, so it is not a markdown table and its header row cannot be "
                     "identified structurally — the whole table is skipped rather than risk "
                     "emitting a header cell as a locked path" % (section_name, DMP_PATH))
            return []
        out = []
        for _tbl in tables:
          for _i, (_cells, _is_sep) in enumerate(_tbl):
            if _i == 0:
                continue                                  # the header (row 1 of THIS table)
            if _i == 1:
                continue                                  # the alignment row (row 2, always)
            if _is_sep:
                # Within ONE table block, a dash-only row below the alignment row is
                # filler — markdown has no second delimiter row inside a table, and a
                # genuine second TABLE would have ended this block at its blank line
                # and been handled above. It carries no path, so it contributes
                # nothing; the drop is RECORDED, because the row above it used to be
                # eaten here, and the rows around it are UNAFFECTED.
                omit(_omit_key + ".filler_row",
                     "`## %s` in %s carries a dash-only filler row at table row %d — it holds no "
                     "entry and is dropped; the rows around it are UNAFFECTED (only row 2 of a "
                     "block is an alignment row)" % (section_name, DMP_PATH, _i + 1))
                continue
            _first = _cells[0].strip("`").strip()
            if _first.startswith("<") or _first in ("...", "…"):
                omit(_omit_key + ".template_row",
                     "`## %s` in %s carries an unfilled template placeholder row (first cell "
                     "%r) — dropped as literal template residue, never emitted as a locked path"
                     % (section_name, DMP_PATH, _first))
                continue                                  # unfilled template placeholder
            out.append((_first, _cells))
        return out

    # THE TWO TABLES ARE READ DIFFERENTLY, and this is the whole point
    # (knowledge-base-schema.md §data-mutation-policy.md template):
    #
    #   ## Per-locked-field policy
    #     | customers.nip | cifmast.cifNip | BI Reg 23/2/2021 §4 | ... |
    #     -> the SECTION is the locked marker. NO row carries the token `LOCKED`.
    #        A token scan drops every one of them — i.e. drops the authoritative
    #        per-field locked list, which is exactly F9's failure scenario
    #        surviving its own fix.
    #
    #   ## Entity-level summary
    #     | transactions | 8 | 6 | 0 | LOCKED (audit trail compliance) | No ... |
    #     -> the OVERALL TIER cell is the marker, and it must be read there, not
    #        anywhere in the row: `customers` reads `INTENT (mixed; 3 locked
    #        fields)` and is NOT locked. (Case matters — the tier vocabulary is
    #        upper-case `[LOCKED]/[INTENT]/[ARTIFACT]`; "3 locked fields" is prose.)
    #
    #   ## Discardable artifacts -> never contributes. Nothing is inferred from
    #        INTENT/ARTIFACT, in either direction.
    for _ent, _cells in _dmp_rows("Per-locked-field policy"):
        if _ent in _seen_locked:
            continue
        _seen_locked.add(_ent)
        _locked_entries.append((_ent, "data-mutation-policy.md §Per-locked-field policy"))
    _ent_short_arity = 0
    for _ent, _cells in _dmp_rows("Entity-level summary"):
        # Overall tier is column 5 in the template and is read THERE, never
        # anywhere else in the row — a whole-row scan is what mis-reads
        # `INTENT (mixed; 3 locked fields)` as locked. There is NO fallback for a
        # table of different arity: any other column is a guess about which
        # column carries the tier, and a guess here mints a locked path. Such a
        # row contributes nothing and the absence is RECORDED below.
        _tier = _cells[4] if len(_cells) >= 5 else ""
        if len(_cells) < 5:
            _ent_short_arity += 1
        if not re.match(r"^\s*\[?LOCKED\b", _tier):
            continue
        if _ent in _seen_locked:
            continue
        _seen_locked.add(_ent)
        _locked_entries.append((_ent, "data-mutation-policy.md §Entity-level summary (tier: %s)"
                                % _tier))
    if _ent_short_arity:
        omit("t1.anti_context.do_not_modify.data_mutation_policy.entity_summary_arity",
             "%d data row(s) of `## Entity-level summary` in %s carry fewer than 5 columns, so "
             "the overall-tier cell (column 5 in the KB template) is ABSENT — those rows "
             "contribute nothing and no other column is read in its place"
             % (_ent_short_arity, DMP_PATH))
    if not _locked_entries:
        omit("t1.anti_context.do_not_modify.data_mutation_policy",
             "data-mutation-policy.md found at %s but declares no [LOCKED] row — contributes "
             "nothing to DO NOT MODIFY (absent input, never padded)" % DMP_PATH)
else:
    omit("t1.anti_context.do_not_modify.data_mutation_policy",
         "no <kb>/99-rebuild-architecture/data-mutation-policy.md under %s (searched "
         ".mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes "
         "nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it" % CWD)

# (b) the unit's own `## Hard rules`, lexed by the shared B1 engine (never a
# second lexer).
for r in HARD_RULE_LINES:
    m = re.match(r"^(?:DO NOT|MUST NOT|NEVER)\s+modify\s+(.+?)\s*$", r, re.IGNORECASE)
    if m:
        obj = m.group(1).strip().strip("`")
        if "." in obj or "/" in obj:                 # path-shaped => mechanical
            _locked_entries.append((obj, "%s `## Hard rules`" % os.path.basename(UNIT_PATH)))
if _locked_entries:
    anti.append("DO NOT MODIFY:")
    for _obj, _src in _locked_entries:
        anti.append("  - %s  (source: %s)" % (_obj, _src))
else:
    omit("t1.anti_context.do_not_modify",
         "neither source produced an entry (data-mutation-policy.md [LOCKED] rows nor the "
         "unit's `## Hard rules` DO NOT/MUST NOT/NEVER modify lines) — line omitted")
# DO NOT REPLICATE: KB anti-patterns — see the kb_anti_patterns omission below.
# DO NOT WRITE: framework pack `## Forbidden patterns` (present in only 8/27 packs).
_forbidden = pack_section("Forbidden patterns")
if _forbidden:
    fb = []
    for pname, body in _forbidden:
        for ln in body.splitlines():
            s = ln.strip()
            if s.startswith("- ") or s.startswith("* "):
                fb.append("%s  (from %s §Forbidden patterns)" % (s[2:].strip(), pname))
    if fb:
        anti.append("DO NOT WRITE:")
        for f in fb:
            anti.append("  - %s" % f)
elif PACK_UNRESOLVED:
    # MUST NOT read like the benign state. A pack chain that could not be
    # resolved has an UNKNOWN forbidden-pattern set, not an empty one.
    omit("t1.anti_context.do_not_write",
         "%s — the pack `## Forbidden patterns` set is UNKNOWN, not empty; the DO NOT WRITE "
         "line is missing because the resolver failed, not because the packs are silent"
         % PACK_UNRESOLVED_NOTE)
else:
    omit("t1.anti_context.do_not_write",
         "no `## Forbidden patterns` section in the resolved pack chain (%s) — line omitted, "
         "never padded" % _chain_desc())
_commit_if = []
if acceptance_tests:
    _commit_if.append("any `acceptance_test` command in this unit fails")
if HARD_RULE_LINES:
    _commit_if.append("any `## Hard rules` line above is violated")
_commit_if.append("a modified file is missing its provenance trailer")
anti.append("DO NOT COMMIT IF: %s" % "; ".join(_commit_if))
if anti:
    t1.append("")
    t1.append("## Anti-context (negative space = freedom + protection)")
    t1.append("")
    t1.extend(anti)
    SECTIONS_EMITTED.append("t1.anti_context")


# ══════════════════════════════════════════════════════════════════════════════
# T2 SECTION MODEL + CASCADE
# ══════════════════════════════════════════════════════════════════════════════

class Section(object):
    """A T2 section with a PRE-COMPUTED truncation ladder.

    `levels[0]` is full fidelity; `levels[-1]` is the DROP FLOOR (which may be ""
    for sections whose floor is "drop section", or a surviving hint line for the
    sections the table says are never fully dropped). `rules[i]` names the rule
    applied when stepping from level i to level i+1 — it is the string logged to
    `running_budget.warnings`, so it must read like the table's cascade cell.
    """
    __slots__ = ("key", "priority", "levels", "rules", "level")

    def __init__(self, key, priority, levels, rules):
        assert len(rules) == len(levels) - 1, "ladder/rule mismatch for %s" % key
        self.key = key
        self.priority = priority
        self.levels = levels
        self.rules = rules
        self.level = 0

    def text(self):
        return self.levels[self.level]

    def at_floor(self):
        return self.level >= len(self.levels) - 1

    def step(self):
        rule = self.rules[self.level]
        before = len(self.levels[self.level].encode("utf-8"))
        self.level += 1
        after = len(self.levels[self.level].encode("utf-8"))
        return {"section": self.key, "rule_applied": rule, "bytes_saved": before - after}


SECTIONS = {}


def add_section(key, priority, levels, rules):
    if not levels or not levels[0].strip():
        return None
    s = Section(key, priority, levels, rules)
    SECTIONS[key] = s
    SECTIONS_EMITTED.append(key)
    return s


# ── Priority 6 — depends_on chain ─────────────────────────────────────────────
# THERE IS NO 1-LINE-SUMMARY FIELD on bolt-report.md. The frontmatter has no
# `summary:`/`headline:` key, `## Summary` is specified as "one paragraph"
# (superpowers-bridge.md:139-140), and `certain_decisions[]` holds full sentences.
# So context-enrichment.md:73 asks for something a deterministic script cannot
# produce. What follows is a MECHANICAL derivation with a citation, never a
# paraphrase and never a paragraph-squeezer.
def _report_frontmatter(text):
    m = re.match(r"\A---\n(.*?)\n---\n?", text or "", re.DOTALL)
    return m.group(1) if m else ""


def _self_report(text):
    """`bolt_self_report:` sits in the BODY (bottom of file), not the
    frontmatter. Scan from its line to the next column-0 non-indented line."""
    lines = (text or "").splitlines()
    for i, ln in enumerate(lines):
        if ln.strip().startswith("bolt_self_report:"):
            blk = []
            for j in range(i + 1, len(lines)):
                if lines[j].strip() and not lines[j][:1] in (" ", "\t"):
                    break
                blk.append(lines[j])
            return "\n".join(blk)
    return ""


upstreams = []
for dep in depends_on:
    dep = dep.strip()
    if not dep:
        continue
    rp = os.path.join(VAULT, "bolts", dep, "bolt-report.md")
    if not os.path.isfile(rp):
        rp = vault_layouts.find_bolt_artifact(CWD, dep, "bolt-report.md")
    rtext = read_text(rp) if rp else None
    up_title = ""
    upath = os.path.join(VAULT, "units", dep + ".md")
    if not os.path.isfile(upath):
        upath = vault_layouts.find_unit_file(CWD, dep)
    if upath:
        up_title = fm_scalar(frontmatter(read_text(upath) or ""), "title")
    if rtext is None:
        omit("depends_on.%s" % dep, "no bolt-report.md for upstream %s — entry OMITTED (no commit sha from any source)" % dep)
        continue
    rfm = _report_frontmatter(rtext)
    commits = fm_list(rfm, "commits")
    status = fm_scalar(rfm, "status")
    attempted = fm_scalar(rfm, "attempted_at")
    sr = _self_report(rtext)
    conf = ""
    cm = re.search(r"(?m)^\s*confidence\s*:\s*([0-9.]+)\s*$", sr)
    if cm:
        conf = cm.group(1)
    retries = fm_scalar(rfm, "retries")
    first_certain = ""
    cd = re.search(r"(?ms)^\s*certain_decisions\s*:\s*\n(.*?)(?=^\s{0,2}[A-Za-z_]+\s*:|\Z)", sr)
    if cd:
        fm_item = re.search(r"^\s*-\s*(.+?)\s*$", cd.group(1), re.MULTILINE)
        if fm_item:
            first_certain = _yl_scalar(fm_item.group(1))
    upstreams.append({
        "id": dep, "title": up_title, "sha": (commits[0] if commits else ""),
        "status": status, "attempted_at": attempted, "confidence": conf,
        "retries": retries, "certain": first_certain,
        "has_self_report": bool(sr), "report_path": rp,
    })

# `attempted_at` is the ONLY recency key in the bolt-report schema. Directory
# mtime is NOT usable — bolt dirs are rewritten by later artifacts (postflight.json,
# acceptance.json). Ties break on unit id so the output is byte-stable across runs.
upstreams.sort(key=lambda u: (u["attempted_at"] or "", u["id"]), reverse=True)


def _upstream_line(u):
    """`- U-XXX "title" → committed at <sha>` + an UNCONDITIONAL `└─ [<status>]`.

    THE STATUS MARKER IS NEVER CONDITIONAL ON A SELF-REPORT (context-enrichment.md
    §TIER 2, bolt-dispatch-prompt.md §Upstream bolts). `status` comes from the
    report FRONTMATTER and is available either way — and a bolt that HALTED is
    precisely the bolt that never wrote a `bolt_self_report:` block, so a
    derivation that returned early when the block was missing dropped `[…]`
    exactly for the upstreams that most need it. The downstream implementer then
    read a bare committed line byte-identical in shape to a clean success and
    built on a halted dependency. Status FIRST, self-report detail after.

    Absent sub-values render `n/a`, NEVER a number. `retries` in particular: a
    report with no `retries:` key has not said "zero retries" — an older report
    schema or a writer that omits the key is not evidence of a settled upstream,
    and this line is cited to a real file so a defaulted value reads as sourced.
    """
    out = ['- U-%s "%s" → committed at %s' % (
        u["id"].replace("U-", ""), u["title"], u["sha"] or "(no commit recorded)")]
    st = u["status"] or "unknown"
    conf = present(u["confidence"])
    retries = present(u["retries"])
    if u["has_self_report"] and u["certain"]:
        body = u["certain"]
        if len(body) > 160:
            body = body[:160] + "…(truncated)"
        out.append("  └─ [%s] %s — src: %s" % (st, body, u["report_path"]))
    else:
        detail = "confidence %s · %s" % (
            conf if conf else "n/a",
            ("%s retries" % retries) if retries else "retries n/a")
        if not u["has_self_report"]:
            # Recorded, not papered over: a report with no bolt_self_report block
            # violates the self_assessment_missing rail. The dispatch builder is
            # not the place to fix that — but it IS the place to say so, rather
            # than let the omission read as a quiet success.
            detail += " · no bolt_self_report block in that report"
        out.append("  └─ [%s] %s — src: %s" % (st, detail, u["report_path"]))
    return "\n".join(out)


def _render_upstreams(n):
    if not upstreams:
        return ""
    head = "## Upstream bolts (depends_on chain — 1-line summary each)\n\n"
    keep = upstreams[:n]
    body = "\n".join(_upstream_line(u) for u in keep)
    if len(keep) < len(upstreams):
        body += "\n(+%d more upstream bolt-report(s) — Tier 3: read <vault>/bolts/U-XXX/bolt-report.md)" % (
            len(upstreams) - len(keep))
    return head + body


if upstreams:
    # Cascade cell: "N most-recently-touched files only"; drop floor "keep at
    # least 1 upstream". The table names no N, so the ladder is pinned here:
    # all -> 3 -> 1, and 1 is the FLOOR (this section is never fully dropped).
    _lv = [_render_upstreams(len(upstreams))]
    _rl = []
    if len(upstreams) > 3:
        _lv.append(_render_upstreams(3))
        _rl.append("keep 3 most-recent upstreams (by attempted_at desc)")
    if len(upstreams) > 1:
        _lv.append(_render_upstreams(1))
        _rl.append("keep 1 most-recent upstream (drop floor)")
    add_section("depends_on_summaries", 6, _lv, _rl)
elif depends_on:
    omit("depends_on_summaries", "every upstream in depends_on lacks a readable bolt-report.md")
else:
    omit("depends_on_summaries", "unit has no depends_on entries")


# ── Priority 7 — framework pack rules ────────────────────────────────────────
def _pack_globs(raw):
    """path_glob -> [glob, ...]. 4 of 175 records use ` + ` compound globs, and
    one carries a trailing parenthetical comment that is NOT part of the glob.
    A value starting with `<` is a PLACEHOLDER sentinel (_universal.md:74/80/86)
    and matches nothing — skip the record entirely rather than let a sentinel
    rule be promoted as "the top 1"."""
    out = []
    for tok in (raw or "").split(" + "):
        tok = re.sub(r"\s*\([^)]*\)\s*$", "", tok).strip()
        if not tok or tok.startswith("<"):
            continue
        out.append(nslash(tok))
    return out


pack_rules = []
_claimed_globs = set()
_type_ordinal = {}
for pname, body in PACK_BODIES:
    sec = md_section(body, "Hard Rules emitted")
    if not sec:
        continue
    cur = None
    for ln in sec.splitlines():
        if ln.strip().startswith("```"):
            continue
        hm = re.match(r"^HARD_RULE:\s*(.*)$", ln)
        if hm:
            cur = {"pack": pname, "text": hm.group(1).strip(), "keys": {}}
            pack_rules.append(cur)
            continue
        if cur is None:
            continue
        km = re.match(r"^[ \t]+([a-z_]+)\s*:\s*(.*)$", ln)
        if km:
            cur["keys"][km.group(1)] = km.group(2).strip()
        elif ln.strip() and not ln[:1] in (" ", "\t"):
            cur = None

matched_rules = []
for r in pack_rules:
    raw_glob = r["keys"].get("path_glob")
    if not raw_glob:
        continue                                     # tolerate a record without one
    # Chain overlay: child rules override parent on path_glob conflict
    # (hard-rules-and-packs.md:12) — packs are walked most-specific-first, so the
    # first claimant of a glob string wins and later (more generic) ones drop.
    if raw_glob in _claimed_globs:
        continue
    globs = _pack_globs(raw_glob)
    if not globs:
        continue
    hit = None
    for g in globs:
        for tp in TARGET_PATHS:
            if glob_match(tp, g):
                hit = (g, tp)
                break
        if hit:
            break
    if not hit:
        continue
    _claimed_globs.add(raw_glob)
    rtype = (r["keys"].get("rule_type") or "CUSTOM").strip()
    slug = re.sub(r"[^a-z0-9]+", "-", rtype.lower()).strip("-") or "custom"
    _type_ordinal[slug] = _type_ordinal.get(slug, 0) + 1
    # Pack rules have NO `id:` key in ANY of the 175 records across 27 packs.
    # The id is SYNTHESIZED deterministically (validation-passes.md:73-75 is the
    # precedent) so the same input yields the same id across runs.
    r["id"] = "framework-pack-%s-%03d" % (slug, _type_ordinal[slug])
    r["matched"] = hit
    matched_rules.append(r)
# ORDERING: the contract never says what "top" orders by (unlike priority 3,
# which says "by target_files overlap"). Packs supply no rank, no id and no
# severity on most rules. The only ordering the FILES supply is chain order
# (most-specific pack first) then in-file record order — which is exactly the
# order `matched_rules` was built in. Pinned here and stated in the provenance.


def _render_pack_rules(n):
    if not matched_rules:
        return ""
    head = "## Framework pack rules (filtered by your target_files glob match)\n\n"
    body = []
    for r in matched_rules[:n]:
        g, tp = r["matched"]
        body.append("- %s (from %s §Hard Rules emitted; matched glob `%s` against `%s`)"
                    % (r["id"], r["pack"], g, tp))
        body.append("  └─ %s" % r["text"])
        for k in ("rule_type", "pattern", "forbidden_pattern", "required_pattern",
                  "forbidden_patterns", "case_style", "forbidden_calls", "rationale"):
            if k in r["keys"]:
                body.append("     %s: %s" % (k, r["keys"][k]))
    if len(matched_rules) > n:
        body.append("(+%d more matching pack rule(s) — Tier 3: read the full pack)"
                    % (len(matched_rules) - n))
    return head + "\n".join(body)


if matched_rules:
    _lv = [_render_pack_rules(len(matched_rules))]
    _rl = []
    for cap in (5, 3, 1):
        if len(matched_rules) > cap and len(_lv[-1]) > len(_render_pack_rules(cap)):
            _lv.append(_render_pack_rules(cap))
            _rl.append("top %d rules (chain order, then in-file order)%s"
                       % (cap, " — drop floor: keep top 1 always" if cap == 1 else ""))
    add_section("framework_pack_rules", 7, _lv, _rl)
else:
    # The priority-7 drop floor ("keep top 1 always") is VACUOUS on an EMPTY set.
    # On a `_universal`-only project all three universal HARD_RULEs carry
    # placeholder `<...>` globs, so the filtered set is legitimately empty. The
    # builder must NOT invent a rule to satisfy the floor.
    if PACK_UNRESOLVED:
        omit("framework_pack_rules",
             "%s — no rules could be filtered because the CHAIN is unknown, not because "
             "no rule matched. The dispatch ships without pack governance; this is a "
             "recorded degradation." % PACK_UNRESOLVED_NOTE)
    else:
        omit("framework_pack_rules",
             "no pack rule path_glob matched this unit's target_files (chain: %s) — "
             "the 'keep top 1' floor is vacuous on an empty set, no rule invented"
             % _chain_desc())


# ── Priority 9 — constitution clauses (NEVER truncated) ──────────────────────
# SELECTOR: the three-way intersection of context-enrichment.md §TIER 2
# (amended + narrowed 2026-07-31). The pre-2b prose ("ONLY clauses referenced in
# this unit's vault_source sections") is unimplementable — `vault_source` is a
# scalar and nothing keys a clause to a vault section — and cannot be restored.
# But a bare `\b[A-F]-\d{3}\b` scan of the whole unit file is TOO WIDE, and its
# false positives land in priority 9: the one section that is NEVER truncated and
# the one that can force `dispatch_prompt_too_large`. A clause id sitting inside
# a code sample could push a dispatch over the cap that would otherwise ship.
#   (1) the id appears in the unit OUTSIDE fenced code blocks and inline code
#       spans — a clause id inside a code sample is a sample, not a reference;
#   (2) the id RESOLVES to a real clause block in the constitution (which the
#       builder is already parsing to emit bodies, so this costs nothing) —
#       this kills the whole "[clause not found]" marker class;
#   (3) the `[A-F]-\d{3}` shape also matches binding CLAIM ids. An id in
#       `binding_refs` that does not resolve under (2) is a claim, recorded as
#       such rather than marked missing.
# THIS DOES NOT WEAKEN validate-constitution-propagation.sh: that validator runs
# binding -> units (does every clause the BINDING cites survive into some unit?)
# and never reads a dispatch prompt. Narrowing the builder's selector cannot open
# a gate, because no gate reads it.
CLAUSE_ID_RE = re.compile(r"\b([A-F]-\d{3})\b")
FENCE_RE = re.compile(r"(?ms)^[ \t]*(```|~~~).*?^[ \t]*\1[ \t]*$")
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")


def _prose_only(text):
    """Unit text with fenced code blocks and inline code spans blanked out.
    Newlines are preserved so nothing downstream shifts; only the CONTENT of
    code regions is removed."""
    def _blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))
    return INLINE_CODE_RE.sub(_blank, FENCE_RE.sub(_blank, text or ""))
CLAUSE_ANCHOR_RE = re.compile(r"^\s*(?:[-*>|]+\s*|#{1,6}\s*)?(?:\*\*|__|\*|_)?\s*([A-F]-\d{3})\b")
RETIRED_RE = re.compile(r"\((?:dropped|retired|superseded)\b", re.IGNORECASE)

CONST_PATH = os.path.join(VAULT, "constitution.md")
const_text = read_text(CONST_PATH)
clause_lines = []
if const_text:
    blocks, cur_id, cur_buf = [], None, []
    for ln in const_text.splitlines():
        if ln.startswith("#"):
            if cur_id:
                blocks.append((cur_id, "\n".join(cur_buf)))
            cur_id, cur_buf = None, []
            continue
        am = CLAUSE_ANCHOR_RE.match(ln)
        if am:
            if cur_id:
                blocks.append((cur_id, "\n".join(cur_buf)))
            cur_id, cur_buf = am.group(1), [ln]
            continue
        if cur_id:
            cur_buf.append(ln)
    if cur_id:
        blocks.append((cur_id, "\n".join(cur_buf)))
    # (1) prose/frontmatter/binding_refs/Hard-rules references ONLY — code
    #     fences and inline spans are excluded before the scan.
    UNIT_PROSE = _prose_only(UNIT_TEXT)
    cited = set(CLAUSE_ID_RE.findall(UNIT_PROSE))
    _in_code_only = set(CLAUSE_ID_RE.findall(UNIT_TEXT)) - cited
    for _cid in sorted(_in_code_only):
        omit("constitution.%s" % _cid,
             "id appears ONLY inside a fenced code block or inline code span in %s — a clause "
             "id in a code sample is a sample, not a reference by the unit (selector term 1); "
             "excluded from the NEVER-truncatable priority-9 section"
             % os.path.basename(UNIT_PATH))
    seen = set()
    for cid, block in blocks:                        # constitution FILE order
        if cid not in cited or cid in seen:
            continue
        seen.add(cid)
        head_line = block.splitlines()[0] if block.splitlines() else ""
        # Retired-clause exemption is MANDATORY: constitution_clauses is the ONE
        # section that may never be truncated, and :67 makes it the section that
        # can force `dispatch_prompt_too_large`. Injecting dead clauses is the
        # direct path to a spurious chain-stopping halt.
        rm = re.match(r"^\s*-\s*([A-F]-\d{3}):\s*(.*)", head_line)
        if rm and RETIRED_RE.search(rm.group(2)):
            omit("constitution.%s" % cid, "clause retired/dropped/superseded in constitution.md")
            continue
        txt = re.sub(r"^\s*(?:[-*>|]+\s*|#{1,6}\s*)?(?:\*\*|__|\*|_)?\s*%s\b\W*" % cid, "", block)
        txt = " ".join(txt.split())
        clause_lines.append("- §%s: %s" % (cid, txt))
    # (2)+(3) NO "[clause not found]" MARKER IS EVER MINTED. Term (2) makes
    # resolution part of the selector, so an id that does not resolve is simply
    # not selected — which eliminates the whole marker class that used to be
    # minted from ids that are not clauses at all. Term (3) is why: the
    # `[A-F]-\d{3}` shape also matches BINDING CLAIM ids (`C-001` is both a legal
    # clause id and a legal claim id), so an id the unit declares in
    # `binding_refs` is a claim reference. Both cases are RECORDED, with reasons
    # that read differently, rather than shipped as a gap marker in the one
    # section that can force a chain-stopping halt.
    _refset = {r.strip() for r in binding_refs}
    for cid in sorted(cited - seen):
        if cid in _refset:
            omit("constitution.%s" % cid,
                 "id appears in binding_refs and resolves to NO clause block in constitution.md "
                 "— read as a binding CLAIM ref, not a clause citation (selector term 3); no "
                 "'clause not found' marker minted")
        else:
            omit("constitution.%s" % cid,
                 "id is cited in %s but resolves to no clause block in constitution.md "
                 "(selector term 2) — not a clause; omitted rather than marked missing, and "
                 "never invented" % os.path.basename(UNIT_PATH))
if clause_lines:
    add_section("constitution_clauses", 9,
                ["## Constitution clauses (cited in this unit, resolved in the constitution §C)\n\n"
                 + "\n".join(clause_lines)
                 + "\n\n(selector: `\\b[A-F]-\\d{3}\\b` cited in %s OUTSIDE code fences/spans, "
                   "AND resolving to a real clause block in constitution.md; binding claim ids "
                   "and retired clauses excluded)"
                 % os.path.basename(UNIT_PATH)],
                [])
elif not const_text:
    omit("constitution_clauses", "no constitution.md in %s (absence IS the --no-constitution opt-out)" % VAULT)
else:
    omit("constitution_clauses", "unit cites no [A-F]-NNN clause id")


# ── Priority 4 — KB anti-patterns ────────────────────────────────────────────
# "domain tags" IS A PHANTOM FIELD. It appears at context-enrichment.md:76 and
# bolt-dispatch-prompt.md:20/143/145 and NOWHERE else — not in unit-schema.md,
# not in any validator, not in any writer. Units carry no `domain`/`domain_tags`
# key. Populating this section from a substitute key (`module:`, `vault_source`)
# would be a FABRICATED T2 inclusion, violating both the inclusion-cites-its-
# source rail (:186) and moat invariant #5. The section is OMITTED — and that is
# the CORRECT default today, not a temporary shortcut.
omit("kb_anti_patterns",
     "the join key 'domain tags' (context-enrichment.md:76) is a phantom field — no unit "
     "schema, validator or writer defines it; substituting module:/vault_source would be a "
     "fabricated inclusion. Section omitted until the spec designates a join key.")


# ── Priority 2 — historical memory (outcomes.md + bolt-outcomes.json + instincts) ──
memory_lines = []
# Canonical path first, then the READ-SIDE legacy alias (memory-schema.md:85).
for mp in (os.path.join(CWD, ".mega-sdd", "memory", "outcomes.md"),
           os.path.join(CWD, ".mega-sdd-memory", "outcomes.md")):
    otext = read_text(mp)
    if otext is None:
        continue
    runs = re.split(r"(?m)^(?=## Run #)", otext)
    runs = [r for r in runs if r.strip().startswith("## Run #")]
    # THE FILTER IS APPLIED, not decorated. context-enrichment.md §TIER 2:
    # "filter outcomes.md for bolts touching similar files OR pattern — last 5
    # only". The builder used to emit EVERY run under the header "last 5 relevant
    # patterns", using the needle test only to decorate the provenance string
    # (`matched X` vs `recency-only`). The word *relevant* in that header is a
    # CLAIM, and on a tight unit an unfiltered slice consumed the priority-2
    # budget a section with a real join would have used. outcomes.md is a
    # RUN-level log with no target_files field, so the join key available is a
    # substring test on the unit id and on each target-file basename — that is
    # the honest reading of "touching similar files OR pattern", and a run that
    # matches NOTHING is not relevant to this unit and is dropped, not
    # relabelled. Zero matches omits the section (an absent input, recorded).
    needles = [unit_id] + [p.rsplit("/", 1)[-1] for p in TARGET_PATHS]
    needles = [n for n in needles if n]
    _mem_seen, _mem_dropped = 0, 0
    for r in reversed(runs):                          # most-recent-first
        hit = next((n for n in needles if n in r), None)
        if hit is None:
            _mem_dropped += 1
            continue
        _mem_seen += 1
        head = re.sub(r"^#+\s*", "", r.splitlines()[0].strip())
        detail = "; ".join(l.strip("- ").strip() for l in r.splitlines()[1:]
                           if l.strip().startswith("-"))
        if len(detail) > 220:
            detail = detail[:220] + "…"
        memory_lines.append("Pattern: %s → %s  (src: %s; matched `%s`)"
                            % (head, detail or "(no bullets)", mp, hit))
    if _mem_dropped:
        omit("historical_memory.unmatched_runs",
             "%d run(s) in %s matched neither %s nor any target-file basename — dropped by the "
             "relevance filter rather than emitted under a header that claims relevance"
             % (_mem_dropped, mp, unit_id))
    break

bo_path = os.path.join(VAULT, ".memory", "bolt-outcomes.json")
bo_text = read_text(bo_path)
if bo_text:
    try:
        bo = json.loads(bo_text) or {}
        for b in (bo.get("bolts") or []):
            if not isinstance(b, dict):
                continue
            if b.get("unit_id") != unit_id and (not unit_module or b.get("module") != unit_module):
                continue
            bits = [x for x in (b.get("status"), b.get("halt_reason"),
                                b.get("failure_reflection")) if x]
            if not bits:
                continue
            memory_lines.append("Pattern: prior bolt %s [%s] → %s  (src: %s)"
                                % (b.get("unit_id"), b.get("task_type") or "?",
                                   " · ".join(str(x) for x in bits), bo_path))
    except ValueError:
        # Memory is advisory context, never a gate — parse failures are silent
        # by design (instincts.md:60). No halt, no synthesized history.
        WARNINGS.append("bolt-outcomes.json unparseable — memory half skipped silently")

instinct_lines = []
for scope, root in (("project", os.path.join(CWD, ".mega-sdd", "memory", "instincts")),
                    ("global", os.path.join(os.path.expanduser("~"), ".mega-sdd", "memory", "instincts"))):
    for f in sorted(glob.glob(os.path.join(root, "*.yaml"))):
        t = read_text(f)
        if not t:
            continue
        d = {}
        for ln in t.splitlines():
            km = re.match(r"^(id|trigger|action|confidence|domain|scope|status)\s*:\s*(.*)$", ln)
            if km:
                d[km.group(1)] = _yl_scalar(km.group(2))
        if d.get("status") != "active":
            continue
        try:
            conf = float(d.get("confidence", ""))
        except (TypeError, ValueError):
            continue                                 # never default a confidence
        if conf < 0.7:
            continue
        dom = (d.get("domain") or "").strip()
        if dom == "ui" and not ui_bearing:
            continue
        if dom == "security" and unit_risk not in ("high", "critical"):
            continue
        if dom not in ("ui", "security", "conventions", "testing", "general", "workflow"):
            continue
        if not d.get("trigger") or not d.get("action"):
            continue
        instinct_lines.append((conf, 0 if scope == "project" else 1,
                               "- Instinct [%s · conf %s] when %s → %s (source: memory/instincts/%s.yaml)"
                               % (dom, d.get("confidence"), d["trigger"], d["action"], d.get("id") or "?")))
instinct_lines.sort(key=lambda x: (-x[0], x[1], x[2]))
INSTINCT_CAP = 6                                     # mirrors the sibling SessionStart cap


def _render_memory(n):
    parts = []
    keep_mem = memory_lines[:n]
    keep_ins = [x[2] for x in instinct_lines[:min(n, INSTINCT_CAP)]]
    if not keep_mem and not keep_ins:
        return ""
    parts.append("## Historical memory (last %d relevant patterns)\n" % n)
    parts.extend(keep_mem)
    if keep_ins:
        parts.append("")
        parts.extend(keep_ins)
        parts.append("(instincts are ADVISORY — a Hard rule, the spec, or the user always wins)")
    return "\n".join(parts)


if memory_lines or instinct_lines:
    _lv, _rl = [_render_memory(5)], []
    for n, label in ((3, "last 3"), (1, "last 1")):
        cand = _render_memory(n)
        if len(cand) < len(_lv[-1]):
            _lv.append(cand)
            _rl.append("%s only" % label)
    _lv.append("")
    _rl.append("drop section (drop floor)")
    add_section("historical_memory", 2, _lv, _rl)
else:
    omit("historical_memory",
         "no outcomes.md run passed the relevance filter (unit id / target-file basename "
         "overlap), no matching bolt-outcomes.json entry and no eligible instinct. Memory "
         "files are gitignored-by-default post-run artifacts, so absent is the normal state; "
         "an unfiltered dump under a header that says 'relevant' is not the alternative.")


# ── Priority 3 — reuse slice ─────────────────────────────────────────────────
REUSE_PATH = os.path.join(CWD, ".mega-sdd", "codebase", "reuse-index.yaml")
reuse_entries = []
reuse_truncated_src = False
_rt = read_text(REUSE_PATH)
if _rt is not None:
    ri = yaml_lite(_rt)
    if isinstance(ri, dict):
        trunc = ri.get("truncated") if isinstance(ri.get("truncated"), dict) else {}
        reuse_truncated_src = any(bool(v) for v in trunc.values())
        # The file is NOT a flat entries[] and has NO `summary` field. Four
        # heterogeneous category lists; only `helpers` has `name`. name/summary
        # are mapped per category and never invented.
        cat_key = [("helpers", "name", "purpose"), ("model_api", "model", None),
                   ("services", "class", "purpose"), ("commands", "signature", "purpose")]
        cand_names = {str(rc.get("name") or "").strip() for rc in reuse_candidates}
        cand_names.discard("")
        for ci, (cat, namefield, sumfield) in enumerate(cat_key):
            lst = ri.get(cat)
            if not isinstance(lst, list):
                continue
            for e in lst:
                if not isinstance(e, dict):
                    continue
                if not e.get("_source"):
                    continue                          # producer drops these; so do we
                epath = nslash(str(e.get("path") or ""))
                name = str(e.get(namefield) or "").strip()
                # "path overlaps target_files" is undefined in context-enrichment.md;
                # the sibling contract for the SAME index (starterkit-derivation.md:171)
                # defines it as a PREFIX overlap. That is the tiebreaker used here.
                overlap, why = 0, ""
                for tp in TARGET_PATHS:
                    if epath and (epath == tp or epath.startswith(tp.rstrip("/") + "/")
                                  or tp.startswith(epath.rstrip("/") + "/")):
                        overlap += 1
                        why = why or ("path overlap with %s" % tp)
                if not overlap and name and name in cand_names:
                    why = "name in unit.reuse_candidates"
                if not overlap and not why:
                    continue
                summary = ""
                if sumfield:
                    summary = str(e.get(sumfield) or "").strip()
                if not summary:
                    for alt in ("signature", "entrypoints", "methods", "scopes"):
                        v = e.get(alt)
                        if isinstance(v, list) and v:
                            summary = str(v[0])
                            break
                        if isinstance(v, str) and v:
                            summary = v
                            break
                reuse_entries.append({
                    "name": name or epath, "path": epath, "summary": summary,
                    "overlap": overlap, "cat": ci, "why": why,
                    "src": str(e.get("_source")),
                })
        # Sort by overlap DESC then category order then path — near-degenerate
        # under prefix matching, so the tiebreaks are what make it deterministic.
        reuse_entries.sort(key=lambda e: (-e["overlap"], e["cat"], e["path"], e["name"]))


def _render_reuse(n):
    if not reuse_entries:
        return ""
    head = "### Reuse index (filtered slice)\n\n"
    body = []
    for e in reuse_entries[:n]:
        body.append("- %s (%s) — %s  [included: %s; src %s]"
                    % (e["name"], e["path"], e["summary"] or "(no purpose recorded)",
                       e["why"], e["src"]))
    left = len(reuse_entries) - min(n, len(reuse_entries))
    if left > 0 or reuse_truncated_src:
        body.append("+%d more — read reuse-index.yaml directly" % left)
    return head + "\n".join(body)


REUSE_FLOOR = ("### Reuse index (filtered slice)\n\n+%d more — read reuse-index.yaml directly"
               % max(len(reuse_entries) - 0, 0))
if reuse_entries:
    _lv, _rl = [_render_reuse(len(reuse_entries))], []
    for cap in (5, 3, 1):
        cand = _render_reuse(cap)
        if len(cand) < len(_lv[-1]):
            _lv.append(cand)
            _rl.append("top %d entries by target_files overlap" % cap)
    # DROP FLOOR: this section is NEVER fully dropped — at minimum ONE hint line
    # survives (context-enrichment.md:57).
    if len(_lv[-1]) > len(REUSE_FLOOR):
        _lv.append(REUSE_FLOOR)
        _rl.append("hint line only — never fully dropped (drop floor)")
    add_section("reuse_slice", 3, _lv, _rl)
elif _rt is None:
    omit("reuse_slice", "reuse-index.yaml absent at %s (the UNCONDITIONAL T1 path line still ships)" % REUSE_PATH)
else:
    omit("reuse_slice", "no reuse-index entry overlaps target_files or reuse_candidates")


# ── Priority 8a — starterkit slice (own 7-step internal ladder) ──────────────
SK_PATH = os.path.join(CWD, ".mega-sdd", "codebase", "starterkit-context.yaml")
sk = None
sk_text = read_text(SK_PATH)
if sk_text is not None:
    parsed = yaml_lite(sk_text)
    if isinstance(parsed, dict) and len(parsed) == 1 and "starterkit_context" in parsed:
        parsed = parsed["starterkit_context"]        # the wrapper key is OPTIONAL
    if not isinstance(parsed, dict) or not parsed:
        SOFT_HALTS.append({"halt": "deep_scan_cache_corrupt",
                           "detail": "starterkit-context.yaml at %s present but unparseable" % SK_PATH})
    elif re.search(r"(?m)^\s*patterns\s*:", sk_text) and not isinstance(parsed.get("patterns"), dict):
        # FAIL-LOUD (validate-starterkit-conformance.sh S5R): a block that is
        # PRESENT but parsed to zero is an ERROR, never a silent SKIP.
        SOFT_HALTS.append({"halt": "deep_scan_cache_corrupt",
                           "detail": "starterkit-context.yaml `patterns:` block present but parsed empty"})
    else:
        sk = parsed
        # NEVER branch on schema_version — presence-driven only; every field is
        # optional in the wild (3.0 files with zero slices exist in-tree).

PATTERN_CATEGORIES = ["controller", "data_model", "request_validator", "business_logic",
                      "test", "schema_migration", "route", "component", "view"]
# `component` BEFORE `view` is DELIBERATE (starterkit-enrichment.md:79-80): the
# more-specific resources/views/components/ prefix must location-match first.

sk_lines_auth = sk_lines_authz = None
sk_ui = None
sk_libs = []
sk_patterns = {}
sk_examples = {}
sk_design_system = None
if sk is not None and starterkit_relevance:
    # Every composed line below goes through compose() — the absent-value rule
    # (starterkit-enrichment.md §Starterkit slice: inject). A missing sub-key of
    # a PRESENT dict is an absent input and gets the same treatment as an absent
    # file: drop the pair, record it, and drop the whole line if nothing survives.
    if "auth" in starterkit_relevance and isinstance(sk.get("auth"), dict):
        a = sk["auth"]
        sk_lines_auth = compose("starterkit.auth", "Auth:",
                                [("lib", a.get("lib")),
                                 ("mechanism", a.get("mechanism")),
                                 ("user_model", a.get("user_model"))]) or None
    if "authz" in starterkit_relevance and isinstance(sk.get("authz"), dict):
        z = sk["authz"]
        decls = z.get("declarations") if isinstance(z.get("declarations"), list) else []
        names = ", ".join(str(d.get("name")) for d in decls
                          if isinstance(d, dict) and present(d.get("name")))
        sk_lines_authz = compose("starterkit.authz", "Authz:",
                                 [("lib", z.get("lib")),
                                  ("mechanism", z.get("mechanism")),
                                  ("declarations", names)]) or None
    if "ui_ux" in starterkit_relevance and isinstance(sk.get("ui_ux"), dict):
        sk_ui = sk["ui_ux"]
        if design_system:
            # Starterkit path: inject style/palette/typography/a11y_level/source,
            # EXCLUDE provenance (audit-only). Note `source` IS injected here and
            # is NOT on the greenfield path — the two paths genuinely differ.
            sk_design_system = design_system
    if "libs" in starterkit_relevance and isinstance(sk.get("libs"), list):
        for lb in sk["libs"]:
            if not isinstance(lb, dict):
                continue
            hints = lb.get("usage_hint")
            hints = hints if isinstance(hints, list) else ([hints] if hints else [])
            score = 0
            for h in hints:
                hn = nslash(str(h))
                for tp in TARGET_PATHS:
                    if tp == hn or tp.startswith(hn.rstrip("/") + "/") or hn.startswith(tp.rstrip("/") + "/"):
                        score += 1
            if score:
                sk_libs.append((score, lb, hints))
        sk_libs.sort(key=lambda x: (-x[0], str(x[1].get("name") or "")))

if sk is not None and isinstance(sk.get("patterns"), dict) and TARGET_PATHS:
    for cat in PATTERN_CATEGORIES:
        pat = sk["patterns"].get(cat)
        if not isinstance(pat, dict):
            continue
        loc = pat.get("location")
        for tp in TARGET_PATHS:
            if loc:
                # REPRODUCED AS WRITTEN: `location.rstrip("/") + "/"` then
                # startswith. When `location` is a SINGLE FILE (schema-legal, e.g.
                # `route: {location: routes/api.php}`) this can never fire. That is
                # a latent defect in the prose contract; the cascade is a declared
                # MOAT surface, so it is reproduced exactly and reported, NOT fixed.
                if tp.startswith(nslash(str(loc)).rstrip("/") + "/"):
                    sk_patterns[cat] = pat
                    break
            elif pat.get("naming"):
                nm = str(pat["naming"])
                ext = str(pat.get("extension") or "")
                rx = nm.replace("{Model}", r"[A-Z]\w+").replace("{model}", r"[a-z_]+")
                rx = rx.replace("<ext>", re.escape(ext))
                try:
                    creg = re.compile(rx + "$")
                except re.error:
                    break                             # log + skip the naming fallback
                if creg.search(tp.rsplit("/", 1)[-1]):
                    sk_patterns[cat] = pat
                    break

for cat in ("controller", "view", "component"):       # exemplar scope is EXACTLY these 3
    pat = sk_patterns.get(cat)
    if not isinstance(pat, dict):
        continue
    srcs = pat.get("_source")
    srcs = srcs if isinstance(srcs, list) else ([srcs] if srcs else [])
    if not srcs:
        continue
    # `_source[0]` IS the faithful MECHANICAL implementation of "pick the FIRST
    # entry whose file lints clean". `exemplar_selection` exists ONLY at CATEGORY
    # level, never per-entry, so the linter-clean information lives entirely in
    # the ORDERING scan-codebase already applied (deep-scan-dispatch.md:152-156,
    # "# ORDERED best-first"). Tagged => [0] IS the linter-clean pick; untagged
    # => the prose's own fallback is also `source_list[0]`. Same answer both ways.
    # There is NO `_source[1]` fallback: the contract computes chosen_source ONCE.
    chosen = str(srcs[0]).split(":")[0]
    full = os.path.join(CWD, chosen.replace("/", os.sep))
    if not os.path.isfile(full):
        WARNINGS.append("starterkit.%s._source not found on disk: %s" % (cat, full))
        continue
    content = read_text(full) or ""
    truncated = False
    if len(content.encode("utf-8")) >= 3072:
        content = "\n".join(content.splitlines()[:100]) + \
                  "\n# ... (truncated at 100 lines — see full file via Read tool)"
        truncated = True
    sk_examples[cat] = {"path": chosen, "content": content, "truncated": truncated}

UI_HEURISTICS = read_text(os.path.join(PLUGIN_ROOT, "references", "ui-design-heuristics.md")) or ""


# The design slice on the STARTERKIT branch is exactly the three design lines
# of `### Starterkit context`, in this order, whichever survived the
# absent-value rule (starterkit-enrichment.md §inject, extraction boundary
# pinned): `UI/UX:` then `Design tokens:` then `Design system:`. Nothing else
# travels — `Auth:` / `Authz:` / `Libs in scope:` / §patterns / the code exemplar
# are not a design rubric, and a lens judging UI quality against an auth line is
# judging against a contract nobody wrote. Captured PER RUNG as the text is
# emitted, so the lens receives the rung that actually SHIPPED, byte-identical.
SK_DESIGN_LINES_BY_TEXT = {}


def _render_starterkit(libs_cap, ex_lines, idioms_cap, tokens_mode, drop_examples):
    """tokens_mode: 'full' | 'compact' | 'drop'."""
    out = ["### Starterkit context (relevant to this unit)", ""]
    design_lines = []
    any_body = False
    if sk_lines_auth:
        out.append(sk_lines_auth)
        any_body = True
    if sk_lines_authz:
        out.append(sk_lines_authz)
        any_body = True
    if sk_ui:
        idi = sk_ui.get("idioms")
        idi = [str(x) for x in idi] if isinstance(idi, list) else ([str(idi)] if idi else [])
        idi = [x for x in idi if present(x)]
        _uiux = compose("starterkit.ui_ux", "UI/UX:",
                        [("extends", sk_ui.get("layout_extends")),
                         ("notification", sk_ui.get("notification_lib")),
                         ("idioms", ("[%s]" % "; ".join(idi[:idioms_cap])) if idi else None)])
        if _uiux:
            out.append(_uiux)
            design_lines.append(_uiux)
            any_body = True
        dt = sk_ui.get("design_tokens") if isinstance(sk_ui.get("design_tokens"), dict) else None
        if dt and tokens_mode != "drop":
            colors = dt.get("colors") if isinstance(dt.get("colors"), dict) else {}
            colors = {k: present(v) for k, v in colors.items()}
            colors = {k: v for k, v in colors.items() if v is not None}
            fonts = dt.get("fonts")
            fonts = [str(x) for x in fonts] if isinstance(fonts, list) else ([str(fonts)] if fonts else [])
            fonts = [x for x in fonts if present(x)]
            cmap = ("{" + ", ".join("%s:%s" % (k, v) for k, v in colors.items()) + "}") if colors else None
            if tokens_mode == "full":
                spacing = dt.get("spacing")
            else:
                # COMPACT (ladder step 4): keep colors + fonts, reduce `spacing`
                # detail to a scale name. The `Design tokens:` LINE survives as
                # long as ANY token survives — validate-dispatch-prompt.sh must
                # still see it. An ABSENT spacing stays absent: "default" would
                # be an invented scale, which is the placeholder-fill the
                # absent-value rule forbids.
                sp_raw = dt.get("spacing")
                spacing = (re.split(r"[,;]", sp_raw.strip())[0].split()[0]
                           if isinstance(sp_raw, str) and sp_raw.strip() else None)
            _tok = compose("starterkit.design_tokens", "Design tokens:",
                           [("colors", cmap), ("spacing", spacing),
                            ("fonts", ("[%s]" % ", ".join(fonts)) if fonts else None)],
                           sep="; ")
            if _tok:
                out.append(_tok)
                design_lines.append(_tok)
                any_body = True
        if sk_design_system:
            # Template shape (starterkit-enrichment.md §inject):
            #   Design system: <style>/<palette> (type <typography>, a11y <a11y>, source <source>)
            # composed PIECEWISE so an absent sub-key drops only its own piece.
            # The trailing "When source=scanned-template …" sentence is emitted
            # ONLY when `source` survived: a line whose source= is absent cannot
            # also assert what happens when source has a particular value.
            d = sk_design_system
            head_bits = [x for x in (present(d.get("style")), present(d.get("palette")))
                         if x is not None]
            paren_bits = []
            for _lbl, _v in (("type", d.get("typography")), ("a11y", d.get("a11y_level")),
                             ("source", d.get("source"))):
                _pv = present(_v)
                if _pv is not None:
                    paren_bits.append("%s %s" % (_lbl, _pv))
            _absent = [k for k, v in (("style", d.get("style")), ("palette", d.get("palette")),
                                      ("typography", d.get("typography")),
                                      ("a11y_level", d.get("a11y_level")),
                                      ("source", d.get("source")))
                       if present(v) is None]
            if not head_bits and not paren_bits:
                omit("starterkit.design_system",
                     "every value of vault.json design_system is absent — the whole "
                     "`Design system:` line is OMITTED (never `None`)")
            else:
                _ds = "Design system: %s%s — render on this style; see injected "\
                      "style-principles + ux-rules." % (
                          "/".join(head_bits) if head_bits else "",
                          (" (%s)" % ", ".join(paren_bits)) if paren_bits else "")
                if present(d.get("source")) is not None:
                    _ds += (" When source=scanned-template, the starterkit tokens above "
                            "are authoritative.")
                out.append(_ds)
                design_lines.append(_ds)
                any_body = True
                if _absent:
                    omit("starterkit.design_system.absent_keys",
                         "absent in vault.json design_system and DROPPED from the "
                         "`Design system:` line, never rendered as None: %s" % ", ".join(_absent))
    if sk_libs:
        _lib_bits = []
        for _score, lb, hints in sk_libs[:libs_cap]:
            nm = present(lb.get("name"))
            if nm is None:
                omit("starterkit.libs.unnamed",
                     "a `libs` entry carries no name — the entry is dropped, never emitted "
                     "as `None@<version>`")
                continue
            ver = present(lb.get("version"))
            used = [str(h) for h in hints if present(h)]
            _lib_bits.append("%s%s%s" % (nm, "@%s" % ver if ver else "",
                                         " (used in: %s)" % ", ".join(used) if used else ""))
            if ver is None:
                omit("starterkit.libs.%s.version" % nm,
                     "no version recorded for `%s` in starterkit-context.yaml — the `@<version>` "
                     "suffix is DROPPED rather than naming a version nobody recorded" % nm)
        if _lib_bits:
            out.append("Libs in scope: %s" % "; ".join(_lib_bits))
            any_body = True
    if sk_patterns:
        _pat_out = []
        for cat in PATTERN_CATEGORIES:
            pat = sk_patterns.get(cat)
            if not isinstance(pat, dict):
                continue
            # §patterns fields obey the SAME absent-value rule as the composed
            # lines above (starterkit-enrichment.md §inject names location /
            # naming / extension explicitly). A `naming: None` line is not a
            # weaker convention, it is an invented one.
            fields = []
            _missing = []
            for _lbl, _pad, _v in (("location", "  ", pat.get("location")),
                                   ("naming", "    ", pat.get("naming")),
                                   ("extension", " ", pat.get("extension"))):
                _pv = present(_v)
                if _pv is None:
                    _missing.append(_lbl)
                    continue
                # Column alignment is the template's (starterkit-enrichment.md
                # §inject) — `location:` +2, `naming:` +4, `extension:` +1.
                fields.append("    %s:%s%s" % (_lbl, _pad, _pv))
            ex = pat.get("extras")
            if isinstance(ex, dict) and ex:
                _exb = ["%s: %s" % (k, present(v)) for k, v in ex.items() if present(v) is not None]
                if _exb:
                    fields.append("    extras:    {%s}" % ", ".join(_exb))
            srcs = pat.get("_source")
            srcs = srcs if isinstance(srcs, list) else ([srcs] if srcs else [])
            srcs = [s for s in srcs if present(s)]
            if srcs:
                fields.append("    _source:   %s" % srcs[0])   # single citation — anti-halu
            if _missing:
                omit("starterkit.patterns.%s.absent_keys" % cat,
                     "absent in starterkit-context.yaml and DROPPED from the §patterns block, "
                     "never rendered as None: %s" % ", ".join(_missing))
            if not fields:
                omit("starterkit.patterns.%s" % cat,
                     "every field of the `%s` pattern is absent — category omitted entirely" % cat)
                continue
            _pat_out.append("- %s:" % cat)
            _pat_out.extend(fields)
        if _pat_out:
            out.append("")
            out.append("### Starterkit code patterns (follow these conventions)")
            out.append("")
            out.extend(_pat_out)
            any_body = True
    if sk_examples and not drop_examples:
        out.append("")
        out.append("### Reference code example (from starterkit)")
        for cat in ("controller", "view", "component"):
            ex = sk_examples.get(cat)
            if not ex:
                continue
            content = ex["content"]
            marked = ex["truncated"]
            if ex_lines is not None:
                lines = content.splitlines()
                if len(lines) > ex_lines:
                    content = "\n".join(lines[:ex_lines]) + \
                              "\n# ... (truncated at %d lines — see full file via Read tool)" % ex_lines
                    marked = True
            out.append("")
            out.append("Pattern: %s" % cat)
            out.append("File:    %s" % ex["path"])
            if marked:
                out.append("(truncated — full file available via Read tool)")
            out.append("")
            out.append(("```%s" % ex["path"].rsplit(".", 1)[-1]) if "." in ex["path"] else "```")
            out.append(content)
            out.append("```")
            out.append("")
            out.append("Follow this style for new %s files. Do not deviate from the conventions "
                       "shown above unless the unit explicitly requires it." % cat)
        any_body = True
    # The `### UI design quality heuristics` inject (starterkit-enrichment.md:238-247)
    # has NO rung in the 7-step §Slice truncation order — so it is NOT dropped by
    # any rung, including the code_examples rung. Bundling it into one would have
    # invented an 8th step in a moat surface. Its ~4.8KB is un-budgeted by the
    # contract; flagged as a spec-amendment item rather than fixed here.
    if "ui_ux" in starterkit_relevance and UI_HEURISTICS:
        out.append("")
        out.append("### UI design quality heuristics")
        out.append("")
        out.append(UI_HEURISTICS.strip())
        any_body = True
    rendered = "\n".join(out) if any_body else ""
    SK_DESIGN_LINES_BY_TEXT[rendered] = list(design_lines)
    return rendered


if sk is not None and (sk_lines_auth or sk_lines_authz or sk_ui or sk_libs or sk_patterns):
    # The slice's OWN 7-step ladder (starterkit-enrichment.md §Slice truncation
    # order), nested INSIDE the outer priority-8 row. design_tokens is
    # MID-priority: compacted only AFTER libs + idioms and BEFORE code_examples,
    # and NEVER first-dropped. Step 7 of that ladder ("emit halt") is delegated
    # to the ONE global halt check — it is the same halt, and duplicating it
    # here would let the slice halt outside the documented three-way conjunction.
    _lv = [_render_starterkit(None, None, 99, "full", False)]
    _rl = []
    _ladder = [
        (dict(libs_cap=10, ex_lines=None, idioms_cap=99, tokens_mode="full", drop_examples=False),
         "libs -> top 10 by target_files overlap"),
        (dict(libs_cap=10, ex_lines=50, idioms_cap=99, tokens_mode="full", drop_examples=False),
         "code_examples -> first 50 lines"),
        (dict(libs_cap=10, ex_lines=50, idioms_cap=3, tokens_mode="full", drop_examples=False),
         "ui_ux.idioms -> top 3"),
        (dict(libs_cap=10, ex_lines=50, idioms_cap=3, tokens_mode="compact", drop_examples=False),
         "design_tokens compacted (keep colors+fonts; spacing -> scale name)"),
        (dict(libs_cap=10, ex_lines=50, idioms_cap=3, tokens_mode="compact", drop_examples=True),
         "drop code_examples (patterns metadata preserved)"),
        (dict(libs_cap=10, ex_lines=50, idioms_cap=3, tokens_mode="drop", drop_examples=True),
         "drop the remaining design_tokens line (drop floor)"),
    ]
    for kw, label in _ladder:
        cand = _render_starterkit(**kw)
        if len(cand) < len(_lv[-1]):
            _lv.append(cand)
            _rl.append(label)
    add_section("starterkit_slice", 8, _lv, _rl)
elif sk_text is None:
    omit("starterkit_slice", "no starterkit-context.yaml at %s — the Map §6 fallback applies instead" % SK_PATH)
elif not starterkit_relevance:
    omit("starterkit_slice", "unit.starterkit_relevance missing or empty — build+inject skipped")
else:
    omit("starterkit_slice", "starterkit-context.yaml carries none of the relevant slices")


# ── Priority 8b — Map §6 fallback (fires EXACTLY when starterkit-context.yaml is ABSENT) ──
if sk_text is None:
    cm_text = read_text(os.path.join(CWD, ".mega-sdd", "codebase", "codebase-map.md"))
    m6 = re.search(r"(?ms)^##[ \t]*6\.?[ \t]+Pattern signatures\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)",
                   cm_text or "")
    if m6:
        rows = [l.strip() for l in m6.group(1).splitlines() if re.match(r"^\s*-\s", l)]
        rows = [re.sub(r"^-\s*", "", r) for r in rows]
        if rows:
            add_section("map_patterns", 8,
                        ["Codebase patterns: %s  (source: .mega-sdd/codebase/codebase-map.md "
                         "§6 Pattern signatures, rows verbatim — informational, never a gate)"
                         % "; ".join(rows)], [])
        else:
            omit("map_patterns", "codebase-map.md §6 present but carries zero rows")
    else:
        omit("map_patterns", "no codebase-map.md §6 Pattern signatures")


# ── Priority 8c — design slice (greenfield pipe; MUTUALLY EXCLUSIVE w/ starterkit ui_ux) ──
DI = os.path.join(PLUGIN_ROOT, "references", "design-intelligence")
design_levels, design_rules = [], []
if not ui_bearing:
    omit("design_slice", "unit is not ui_bearing (no target_files path matched the pack "
                         "view_glob or any universal frontend shape)")
elif sk_ui is not None:
    # The scanned template is AUTHORITATIVE; emitting both would give the bolt two
    # competing token sources — the exact failure the precedence stack prevents.
    omit("design_slice", "starterkit ui_ux slice already built — template is AUTHORITATIVE")
else:
    head = "## Design system (UI-bearing unit — per context-enrichment.md §Design slice)\n\n"
    sys_line = ""
    style_rows = []
    if design_system:
        # Greenfield path injects style/palette/typography/a11y_level and EXCLUDES
        # BOTH provenance and source (context-enrichment.md §Design slice). The
        # marker is spelled `Design system:` (not the template's older
        # `Design system (vault):`) so the live advisory gate keeps matching:
        # validate-dispatch-prompt.sh's DESIGN_SYSTEM_RE is `^\s*Design system\s*:`.
        #
        # ABSENT VALUES ARE DROPPED, NOT RENDERED. A design_system block carrying
        # only `style` is legal, and `palette=None` is not a degraded palette —
        # the anti-halu rail immediately below this line tells the implementer
        # "the palette/typography lines are the SOURCE for your tokens", so a
        # rendered None leaves it two choices, invent one or ship untokened
        # output, while validate-ui-quality.sh sees the marker and reports
        # `design_system_not_injected` CLEAN. A placeholder that satisfies a gate
        # is worse than an omitted line.
        sys_line = compose(
            "design_slice.system", "Design system:",
            [("style", design_system.get("style")),
             ("palette", design_system.get("palette")),
             ("typography", design_system.get("typography")),
             ("a11y", design_system.get("a11y_level"))],
            sep=" · ",
            tail=" — source: vault.json design_system (provenance excluded, audit-only)")
        sp = read_text(os.path.join(DI, "style-principles.md"))
        rows = md_table(sp, "Style") if sp else []
        style_val = str(design_system.get("style") or "")
        tokens = [t.strip() for t in re.split(r"\s\+\s|,", style_val) if t.strip()]
        for tok in tokens:
            hit = None
            for r in rows:
                if len(r) >= 4 and r[0].strip().lower() == tok.lower():
                    hit = (r, "exact")
                    break
            if hit is None:
                cands = [r for r in rows if len(r) >= 4 and
                         (r[0].strip().lower().startswith(tok.lower())
                          or tok.lower().startswith(r[0].strip().lower()))]
                if cands:
                    hit = (cands[0], "prefix match, first in file order (%d candidate(s))" % len(cands))
            if hit is None:
                omit("design_slice.style[%s]" % tok,
                     "style token matches no style-principles.md row — omitted, never substituted")
                continue
            r, how = hit
            # USE style-principles.md's OWN COLUMN NAMES. Its header is
            # `| Style | Best For | Avoid For | CSS Keywords |` — there is NO
            # traits column and NO anti-patterns column. The retired
            # `Style traits:` / `Style anti-patterns:` lines relabelled a
            # PRODUCT-SUITABILITY list as a DESIGN-DEFECT list while citing the
            # file by section, telling the implementer that a style's
            # "anti-patterns" are "creative portfolios, entertainment, playful
            # brands" (product categories) and its "traits" are "enterprise apps,
            # dashboards". The source was real and the assertion was invented —
            # invariant #5 in its subtlest form, and undetectable downstream
            # because the design-reviewer lens judges against THIS SAME slice, so
            # implementer and reviewer would share a contract style-principles.md
            # does not state. Remapping to another column is not the fix: the
            # columns do not exist. Want a traits vocabulary? Add the columns to
            # the generator's source; never rename another file's columns.
            _best, _avoid = present(r[1]), present(r[2])
            _css = present(r[3])
            _bits = []
            if _best is not None:
                _bits.append("best for: %s" % _best)
            if _avoid is not None:
                _bits.append("avoid for: %s" % _avoid)
            if _bits:
                style_rows.append("Style: %s — %s" % (r[0], " · ".join(_bits)))
            if _css is not None:
                style_rows.append("Style CSS keywords: %s" % _css)
            if _bits or _css is not None:
                style_rows.append("   (style-principles.md §%s — %s)" % (r[0], how))
            else:
                omit("design_slice.style[%s]" % tok,
                     "style-principles.md row §%s carries no Best For / Avoid For / CSS Keywords "
                     "value — row omitted rather than emitted empty" % r[0])
    else:
        # EMIT THE VALUE, NOT THE ASSIGNMENT (context-enrichment.md §Design
        # slice). The pseudocode in the spec reads `design_slice.note = "…"`; the
        # NOTE is the quoted sentence, not the statement. Leaking the assignment
        # made the ONE line that tells the subagent to raise an OQ read as an
        # internal variable name.
        sys_line = ("No design_system in this vault — raise it as an OQ at chain end; do not "
                    "invent a palette or a type pairing.")
        omit("design_slice.system",
             "vault.json carries no design_system — the raise-an-OQ note is emitted in its "
             "place, and no palette/typography/a11y value is defaulted")

    ux = read_text(os.path.join(DI, "ux-rules.md"))
    ux_rows_all, ux_rows_high = [], []
    for r in (md_table(ux, "Category") if ux else []):
        if len(r) < 5 or r[0] not in ("Accessibility", "Forms", "Feedback"):
            continue
        line = "%s/%s: DO %s; DON'T %s [%s]" % (r[0], r[1], r[2], r[3], r[4])
        ux_rows_all.append(line)
        if r[4].strip().lower() == "high":
            ux_rows_high.append(line)

    mb = read_text(os.path.join(DI, "modern-baseline.md")) or ""
    mb_nn = md_section(mb, "Non-negotiables") or ""
    mb_cm = md_section(mb, "Ceiling moves") or ""
    mb_ak = md_section(mb, "Anti-kuno tells") or ""
    if not (mb_nn and mb_cm and mb_ak):
        WARNINGS.append("modern-baseline.md section(s) missing under %s — the design slice "
                        "ships without a complete FLOOR (never reconstructed from model knowledge)" % DI)

    def _leads(section_text):
        """Bolded lead clauses of the numbered items — pure EXTRACTION (each
        emitted string is a byte-for-byte substring of the file), never a
        re-wording. Counts are read at runtime; the file is hand-authored."""
        return [m.group(1) for m in re.finditer(r"^\s*\d+\.\s+\*\*(.+?)\*\*",
                                                section_text, re.MULTILINE)]

    def _design(level):
        p = [head, sys_line]
        p.extend(style_rows)
        if level <= 0 and ux_rows_all:
            p.append("UX floor: (ux-rules.md — Accessibility/Forms/Feedback rows)")
            p.extend("  - " + x for x in ux_rows_all)
        elif level == 1 and ux_rows_high:
            p.append("UX floor: (ux-rules.md — Accessibility/Forms/Feedback rows, Severity: High)")
            p.extend("  - " + x for x in ux_rows_high)
        if level <= 0:
            if mb_nn:
                p.append("Modern baseline (non-negotiables — the FLOOR):")
                p.append(mb_nn)
            if mb_cm:
                p.append("Ceiling moves (clear the floor, then DO these — a floor-only view is \"basic/generic\"):")
                p.append(mb_cm)
        elif level <= 2:
            if mb_nn:
                p.append("Modern baseline (non-negotiables — the FLOOR):")
                p.extend("  - " + x for x in _leads(mb_nn))
            if mb_cm:
                p.append("Ceiling moves (clear the floor, then DO these — a floor-only view is \"basic/generic\"):")
                p.extend("  - " + x for x in _leads(mb_cm))
        if level <= 2 and mb_ak:
            p.append("Anti-kuno tells (a match in your output = defect):")
            p.append(mb_ak)
        return "\n".join(x for x in p if x)

    design_levels = [_design(0)]
    for lv, label in ((1, "modern-baseline -> bolded lead clauses verbatim; ux-rules -> Severity: High rows"),
                      (2, "drop the ux-rules rows"),
                      (3, "design_system line + style rows only (drop floor — never fully dropped)")):
        cand = _design(lv)
        if len(cand) < len(design_levels[-1]):
            design_levels.append(cand)
            design_rules.append(label)
    add_section("design_slice", 8, design_levels, design_rules)


# ── Priority 5 — confidence labels per claim ─────────────────────────────────
BINDING_PATH = os.path.join(VAULT, "binding.md")
binding_text = read_text(BINDING_PATH)
claim_rows = []
if binding_text and binding_refs:
    import binding_md                                 # noqa: E402  in-process, 0 spawns
    errs = []
    # full=True is REQUIRED — without it parse_state_map returns only
    # id/verdict/state and the anchor_cell/confidence/field_diff cells (which ARE
    # the confidence label and its citation) are never populated.
    state = binding_md.parse_state_map(binding_text, errs, full=True)
    # `parse_confirmed_sources()` DISCARDS fields 3 and 4 of the pipe list, so it
    # cannot give claim TEXT. Rather than fork the grammar, we reuse its region
    # idiom locally and split the SAME line into 4 fields. (Recommendation for a
    # follow-up: hoist this as a sibling function INSIDE binding_md.py.)
    confirmed_text = {}
    cm = re.search(r"(?ms)^##\s+Confirmed Claims\b[^\n]*\n(.*?)(?=^##\s|\Z)", binding_text)
    if cm:
        for ln in cm.group(1).splitlines():
            lm = re.match(r"^-\s*(\S+)\s*\|(.*)$", ln.strip())
            if lm:
                fields = [f.strip() for f in lm.group(2).split("|")]
                if len(fields) >= 3:
                    confirmed_text[lm.group(1)] = fields[2]
    conflict_text = {}
    for blk in re.split(r"(?m)^(?=###\s)", binding_text):
        if not re.match(r"^###\s*(?:✅\s*)?CONFLICT", blk):
            continue
        cid = re.search(r"(?m)^-\s*\*\*Claim\*\*\s*:\s*(C-[A-Za-z0-9_-]+)", blk)
        vcl = re.search(r"(?m)^-\s*\*\*Vault claim\*\*\s*:\s*(.+)$", blk)
        if cid and vcl:
            conflict_text[cid.group(1)] = vcl.group(1).strip()
    oq_text = {}
    om_ = re.search(r"(?ms)^##\s+Open Questions\b[^\n]*\n(.*?)(?=^##\s|\Z)", binding_text)
    if om_:
        for ln in om_.group(1).splitlines():
            if not ln.strip().startswith("|"):
                continue
            cells = [c.strip() for c in ln.strip().strip("|").split("|")]
            if len(cells) >= 2 and re.match(r"^OQ-", cells[0]):
                oq_text[cells[0]] = cells[1]
    # binding_refs MIXES NAMESPACES (C-* and OQ-*); joining it straight against
    # State Map claim ids silently drops every OQ-* entry.
    for ref in binding_refs:
        ref = ref.strip()
        if not ref:
            continue
        if ref.startswith("OQ-"):
            # `OQ` is in the enum (HIGH | MEDIUM | LOW | OQ, identical in
            # context-enrichment.md and bolt-dispatch-prompt.md). An open question
            # carries no confidence at all; rendering it LOW would assert a
            # low-confidence ANSWER where there is no answer.
            if ref in oq_text:
                claim_rows.append(("OQ", oq_text[ref],
                                   "binding.md `## Open Questions` row %s" % ref, ref))
            else:
                omit("confidence_labels.%s" % ref, "no `## Open Questions` row for %s" % ref)
            continue
        row = state.get(ref) if isinstance(state, dict) else None
        if not row:
            omit("confidence_labels.%s" % ref,
                 "no Implementation State Map row for %s — no source to cite, label omitted" % ref)
            continue
        verdict = (row.get("verdict") or "").upper()
        text = confirmed_text.get(ref) or conflict_text.get(ref) or ""
        # TAXONOMY (context-enrichment.md §Confidence labels, decided 2026-07-31):
        # the label is the EVIDENCE-QUALITY axis and it reads the BINDING'S
        # RECORDED VALUE FIRST — the State Map `Confidence` cell, high/medium/low
        # -> HIGH/MEDIUM/LOW. Only when NO cell was recorded does the source-keyed
        # rule apply (binding-sourced -> HIGH, KB inference -> MEDIUM, heuristic
        # -> LOW); every row here is binding-sourced, so the fallback is HIGH and
        # it SAYS SO on the source line. The cell wins because a row the binder
        # explicitly marked `low` stamped HIGH by a category rule manufactures
        # certainty the cited source contradicts — invariant #5 on the exact label
        # the implementer uses to decide how hard to verify. The source axis is
        # not lost: it is on the `└─ Source:` line of the same entry.
        conf = (row.get("confidence") or "").lower()
        label = {"high": "HIGH", "medium": "MEDIUM", "low": "LOW"}.get(conf)
        src = "binding.md `## Implementation State Map` row %s (anchor: %s)" % (
            ref, row.get("anchor_cell") or "n/a")
        if not label:
            label = "HIGH"
            src += " — no Confidence cell recorded; label from the source-keyed fallback " \
                   "(binding-sourced → HIGH), never synthesized from grounding_confidence"
        if not text:
            omit("confidence_labels.%s" % ref,
                 "verdict %s carries no claim text in binding.md — label omitted rather than uncited" % verdict)
            continue
        claim_rows.append((label, text, src, ref))


def _render_claims(mode):
    if not claim_rows:
        return ""
    head = "## Confidence labels per claim\n\n"
    if mode == "full":
        return head + "\n".join("- [%s] %s\n  └─ Source: %s" % (lbl, txt, src)
                                for lbl, txt, src, _ref in claim_rows)
    counts = {}
    for lbl, _, _, _ in claim_rows:
        counts[lbl] = counts.get(lbl, 0) + 1
    agg = " / ".join("%s×%d" % (k, counts[k]) for k in sorted(counts))
    return head + agg + "\n  └─ Source: binding.md `## Implementation State Map` (aggregate)"


if claim_rows:
    add_section("confidence_labels", 5,
                [_render_claims("full"), _render_claims("agg"), ""],
                ["per-claim -> aggregate (HIGH×N / MEDIUM×N / LOW×N)", "drop section (drop floor)"])
elif not binding_refs:
    omit("confidence_labels", "unit has no binding_refs (greenfield / standalone generate-units)")
elif not binding_text:
    omit("confidence_labels", "no binding.md in %s" % VAULT)
else:
    omit("confidence_labels", "no binding_refs entry resolved to a citable claim")


# ── Priority 1 — validation hints ────────────────────────────────────────────
def _render_hints(with_expectations):
    if not acceptance_tests and not properties:
        return ""
    out = ["## Validation hints (specific, not vague)", ""]
    cmds = [a for a in acceptance_tests if a.get("command")]
    if cmds:
        out.append("After implementation, run:")
        for a in cmds:
            out.append("```bash")
            out.append(str(a["command"]))
            out.append("```")
            if with_expectations:
                if a.get("expects"):
                    out.append("Expected output pattern: %s" % a["expects"])
                if a.get("desc") or a.get("description"):
                    out.append("On fail: %s" % (a.get("desc") or a.get("description")))
    manual = [a for a in acceptance_tests if not a.get("command")]
    if manual and with_expectations:
        for a in manual:
            out.append("- [%s] %s" % (a.get("type") or a.get("kind") or "manual",
                                      a.get("desc") or a.get("description") or a.get("expects") or ""))
    if with_expectations and properties:
        pbt = []
        for p in properties:
            # A property with an empty/absent `cites:` is an INVENTED invariant —
            # dropped, never emitted (validation-passes.md:164 no-fabrication rail).
            if not str(p.get("cites") or "").strip():
                continue
            pbt.append("- %s [%s]: %s  (cites: %s)"
                       % (p.get("id") or "PROP-?", p.get("severity") or "error",
                          p.get("invariant") or p.get("description") or "", p["cites"]))
        if pbt:
            out.append("")
            out.append("Property invariants to hold (PBT):")
            out.extend(pbt)
    return "\n".join(out) if len(out) > 2 else ""


if _render_hints(True):
    _lv = [_render_hints(True)]
    _rl = []
    cand = _render_hints(False)
    if len(cand) < len(_lv[-1]):
        _lv.append(cand)
        _rl.append("drop expected-output patterns; keep test commands only")
    _lv.append("")
    _rl.append("drop section entirely (drop floor)")
    add_section("validation_hints", 1, _lv, _rl)
else:
    omit("validation_hints", "unit carries no acceptance_test command and no cited properties")
# NOTE: the template's "Also run static analysis (if framework pack specifies)"
# slot is NOT filled: no pack declares a machine-readable static-analysis command
# (`## Testing conventions` is prose), and extracting one would be fabrication.


# ══════════════════════════════════════════════════════════════════════════════
# THE CASCADE
# ══════════════════════════════════════════════════════════════════════════════
# REALIZATION CHOICE (the prose describes it three ways — streaming "before
# loading the next section", table-driven "truncate the top of the list first",
# and "load HIGH-priority first"): build every section at FULL fidelity, then
# walk priorities 1 -> 8 stepping ONE ladder rung at a time, re-measuring after
# each rung, stopping as soon as consumed_t2 <= cap_t2. It is the only
# realization reproducible from the table alone, and determinism is the moat
# property here — two builders must produce identical bytes from identical input.

# EMIT ORDER is the TEMPLATE's order, which is NOT the priority order.
EMIT_ORDER = ["depends_on_summaries", "framework_pack_rules", "constitution_clauses",
              "kb_anti_patterns", "historical_memory", "reuse_slice", "map_patterns",
              "starterkit_slice", "design_slice", "confidence_labels", "validation_hints"]
# Tier 8 carries THREE rows and the table now enumerates all three
# (context-enrichment.md, amended 2026-07-31): 8a `starterkit_slice`, 8b
# `map_patterns`, 8c `design_slice`. The order below IS that pinned order. 8b has
# a single level and zero rungs, so a cascade pass over it is a no-op BY
# CONTRACT, not by accident — it is kept because it is the only pattern source a
# regex-tier scan produces.
CASCADE_ORDER = sorted(
    SECTIONS.values(),
    key=lambda s: (s.priority,
                   {"starterkit_slice": 0, "map_patterns": 1, "design_slice": 2}.get(s.key, 0),
                   s.key))


def t2_text():
    parts = []
    for k in EMIT_ORDER:
        s = SECTIONS.get(k)
        if s is None:
            continue
        t = s.text()
        if t.strip():
            parts.append(t)
    return "\n\n".join(parts)


def blen(s):
    return len(s.encode("utf-8"))


# Fill the claims slot in the Provenance values block (needs binding.md, loaded above).
# THE CLAIM ID, NOT THE CONFIDENCE LABEL. bolt-dispatch-prompt.md §Provenance
# values specifies `claims: C-NNN "<claim text>"`, one line per implemented
# claim, and this block is the ONLY sanctioned source for the agent's mandated
# trailer `Implements claim: C-NNN "<claim text>"`. Emitting `- HIGH "notes"`
# left the agent two options — omit the id, or back-derive one from
# `binding_refs` — and the second is exactly the fabrication this block exists to
# prevent. Post-flight only checks a trailer is PRESENT, so a malformed-but-
# present trailer passed every gate. The id was resolved and then discarded when
# the tuple was built; it is carried through now. The confidence LABEL lives in
# the T2 `confidence_labels` section, which is where it already is.
# `OQ-*` rows are excluded: an open question is not an implemented claim.
if claim_rows:
    claim_block = "\n".join('    - %s "%s"' % (ref, txt.replace('"', "'"))
                            for _lbl, txt, _src, ref in claim_rows if _lbl != "OQ")
    t1[PROV_CLAIM_SLOT] = "  claims:\n" + claim_block if claim_block else "  claims: (none cited)"
else:
    t1[PROV_CLAIM_SLOT] = "  claims: (none cited)"
t1_text = "\n".join(x for x in t1 if x is not None)

consumed_t1 = blen(t1_text)
if consumed_t1 > CAP_T1:
    # A REPORTING THRESHOLD, not a budget — and at 12288 what it now reports is a
    # generate-units ATOMICITY SMELL (a unit too big to be one PR-sized bolt),
    # not a budget complaint. At the old 2048 it fired on 123/123 measured runs.
    WARNINGS.append("T1 exceeded its %d-byte reporting threshold (actual=%d) — T1 is NEVER "
                    "truncated (the unit body is verbatim and non-negotiable); this is a unit "
                    "ATOMICITY signal for generate-units, not a budget failure"
                    % (CAP_T1, consumed_t1))

# TRUNCATION TRIGGER — cap_t2 (10240) ONLY. See the constants block: the four
# numbers do four different jobs and conflating any two is the catastrophic bug
# here. Adding `total > cap_hard` as a SECOND truncation trigger was considered
# and REJECTED: the table + tracker key the cascade on the T2 budget alone, and
# a T1-sensitive trigger would drive every unit's T2 to its floor on any run with
# a fat unit body. That is a re-derivation of a MOAT surface, not a reproduction
# of it. (`cap_t1 + cap_t2 == cap_hard` was an arithmetic coincidence and is
# EXPLICITLY RETIRED — do not reason from it.)
while blen(t2_text()) > CAP_T2:
    stepped = False
    for s in CASCADE_ORDER:
        if s.priority >= 9:                          # constitution_clauses: NEVER truncate
            continue
        if s.at_floor():
            continue
        TRUNCATIONS.append(s.step())
        stepped = True
        break                                        # re-measure after EVERY rung
    if not stepped:
        break                                        # all priorities 1-8 at their drop floor

consumed_t2 = blen(t2_text())
all_1_to_8_at_floor = all(s.at_floor() for s in CASCADE_ORDER if s.priority < 9)

# A section whose ladder bottomed out at "" was BUILT but is not IN the prompt —
# report it honestly as omitted-by-truncation, not as emitted.
for _s in CASCADE_ORDER:
    if not _s.text().strip() and _s.key in SECTIONS_EMITTED:
        SECTIONS_EMITTED.remove(_s.key)
        omit(_s.key, "truncated to its drop floor (section dropped) by the T2 cascade")

# SOFT budget: consumed_t2 > cap_t2 while total < cap_hard is WARN-ONLY and the
# bolt PROCEEDS. A builder that halted here would have strengthened a gate into a
# chain-killer — as much a spec violation as weakening one.
if consumed_t2 > CAP_T2:
    WARNINGS.append("T2 exceeded soft cap: target=%d, actual=%d — truncation applied"
                    % (CAP_T2, consumed_t2))

# ── T2 budget tracker (injected INTO the prompt, informational) ───────────────
# THE TRACKER MUST NOT UNDERSTATE THE FILE IT SITS IN. `total` is the T1+T2
# budget the cascade and the halt reason about; the file also carries four blocks
# that were never in that budget — the TIER 2 banner, this tracker, the TIER 3
# pointer list and the PROVENANCE appendix. The title banner and the TIER 1
# banner are NOT among them: `t1` is where both are appended, so they are already
# inside `consumed_t1` (assemble() joins t1_text FIRST, and t1_text is what
# consumed_t1 measures). Naming "the tier banners" here overstated the gap and
# made the enumeration fail to sum. Reporting only `total` to a
# subagent that was just told to read the file IN FULL, and to reason about
# truncation off this block, was a 24–59 % self-reporting gap. Both numbers are
# now stated here, and both are on stdout (`total_bytes` / `file_bytes`).
#
# `%-8d` pads to a CONSTANT 8 columns for any value < 10^8, which makes the
# two-pass fixed point below EXACT in one step rather than an iteration: the
# second render is byte-identical in LENGTH to the first, so the number it
# carries is the number the file actually has.
def render_tracker(file_total):
    tracker = ["═══════════════════════════════════════════",
               "T2 BUDGET TRACKER (informational)",
               "═══════════════════════════════════════════", "", "```",
               "### T2 budget tracker",
               "consumed_t1: %d bytes (cap %d)" % (consumed_t1, CAP_T1),
               "consumed_t2: %d bytes (cap %d, hard %d)" % (consumed_t2, CAP_T2, CAP_HARD),
               "total: %d bytes  # T1 + T2 ONLY — the budgeted, truncatable content"
               % (consumed_t1 + consumed_t2),
               "file_total: %-8d bytes  # THIS WHOLE FILE. The difference from `total` is"
               % file_total,
               "                            # exactly four blocks plus the blank lines joining",
               "                            # them: the TIER 2 banner, this tracker block, the",
               "                            # TIER 3 pointer list and the PROVENANCE appendix.",
               "                            # The title banner and the TIER 1 banner are NOT in",
               "                            # that gap — they are already inside consumed_t1.",
               "                            # None of the four is budgeted and none is ever",
               "                            # truncated. Reason about truncation from the list",
               "                            # below, not from either number.",
               "truncations_applied:"]
    if TRUNCATIONS:
        for w in TRUNCATIONS:
            tracker.append("  - %s: %s (saved %d bytes)"
                           % (w["section"], w["rule_applied"], w["bytes_saved"]))
    else:
        tracker.append("  - (none)")
    tracker += ["instruction_to_subagent:",
                "  If your self-assessment references information that came from a truncated",
                "  section (listed above), mark its confidence as MEDIUM (not HIGH) and note",
                "  the truncation explicitly in your bolt-report.md self-assessment section.",
                "  Truncation is NOT a failure — it's transparency.", "```"]
    return "\n".join(tracker)

t3_text = "\n".join([
    "═══════════════════════════════════════════",
    "TIER 3 — Reference-on-demand (NOT embedded; use Read tool)",
    "═══════════════════════════════════════════", "",
    "- Full upstream bolt-reports: `%s/bolts/U-XXX/bolt-report.md`" % VAULT,
    "- Full constitution: `%s/constitution.md`" % VAULT,
    "- Full KB domain files: `.mega-sdd/knowledge-base/10-domains/`",
    "- Full memory tables: `%s/.mega-sdd/memory/`" % CWD,
    "- Full framework pack: `%s/references/framework-conventions/<pack>.md`" % PLUGIN_ROOT,
])

t2_header = "\n".join(["═══════════════════════════════════════════",
                       "TIER 2 — Conditional context (target ≤10KB total)",
                       "═══════════════════════════════════════════"])

total_bytes = consumed_t1 + consumed_t2

# ══════════════════════════════════════════════════════════════════════════════
# The design lens's rubric — written to a NEUTRAL LENS-INPUT FILE, path on stdout
# ══════════════════════════════════════════════════════════════════════════════
# THE RAIL, STATED AS ITS PURPOSE: no lens may receive a path that reaches
# ANOTHER LENS'S VERDICT or the IMPLEMENTER'S SELF-REPORT. That is why
# <vault>/bolts/U-XXX/ is off limits to a lens prompt — it holds bolt-report.md,
# and on a --resume/retry it already holds the prior attempt's `## Review panel`
# verdicts and `bolt_self_report`; a lens with Read/Grep is one Glob of the
# parent directory away from all of it.
#
# `<vault>/lens-inputs/U-XXX/` is a SIBLING of bolts/ that holds ONLY
# controller-written lens inputs and never any implementer output, so a path into
# it breaches no part of that rail. Handing the lens THAT PATH (~70 B) instead of
# the slice text is a COST fix, measured: as pasted text the slice was billed
# TWICE per greenfield UI bolt — once as builder stdout (input) and again as the
# controller's verbatim re-typing into the lens prompt (OUTPUT), which is the
# expensive channel. The slice is STILL injected into the dispatch prompt itself,
# unchanged; only the LENS's copy moved.
#
# It is read from `s.text()` AFTER the cascade has run — the rung that actually
# SHIPPED — not from levels[0] and never by re-extracting from PROMPT with a
# regex. Implementer and reviewer must hold the byte-identical contract; two
# renderings are two contracts.
#
# `ui_bearing` GATES THE WHOLE BLOCK, and that gate is the fix to a live defect.
# The lens input exists for ONE consumer: the `design-reviewer` lens, which
# review-panel.md §Tier selection joins to the panel "whenever the unit is
# UI-bearing". A unit that is not ui_bearing never gets that lens, so a rubric
# written for it is a file no reader will ever be handed.
#
# The write used to be gated on the slice TEXT alone, and on the starterkit
# branch that text exists for ANY unit whose frontmatter carries
# `starterkit_relevance: [ui_ux]` — including one whose only target_file is
# `app/Services/Settlement.php`. Reproduced: that unit received a
# `design_slice_path` and a written lens-input file. The design_slice SECTION was
# already gated on `ui_bearing` (priority 8c); the two gates disagreed, and the
# looser one decided what got written to disk. They are now the SAME gate, which
# is what makes review-panel.md's "pure-backend units never pay for it" true.
#
# NOT in scope, and deliberately: the starterkit_slice SECTION still injects its
# UI/design lines into the prompt for such a unit. That is the unit's own
# declared `starterkit_relevance` being honoured, it is not a lens input, and
# nothing here claims otherwise.
design_slice_text = None
if not ui_bearing:
    omit("design_slice_path",
         "unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file "
         "is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a "
         "cost, not a contribution)")
else:
    _ds_sec = SECTIONS.get("design_slice")
    if _ds_sec is not None and _ds_sec.text().strip():
        design_slice_text = _ds_sec.text()                   # greenfield branch
    elif sk_ui is not None:
        # Starterkit branch: the extraction boundary is pinned by
        # starterkit-enrichment.md §inject — EXACTLY the `UI/UX:` / `Design tokens:`
        # / `Design system:` lines that survived the absent-value rule at the
        # surviving rung, in that order. Nothing else travels: Auth / Authz / libs /
        # §patterns / the code exemplar are not a design rubric.
        _sk_sec = SECTIONS.get("starterkit_slice")
        _dl = SK_DESIGN_LINES_BY_TEXT.get(_sk_sec.text(), []) if _sk_sec is not None else []
        if _dl:
            design_slice_text = "\n".join(_dl)
if design_slice_text is None and ui_bearing:
    # ABSENT KEY, never "". The controller then tells the lens it has no rubric
    # rather than substituting a different section.
    omit("design_slice_path",
         "UI-bearing unit but every design input is absent — the design lens is dispatched "
         "with NO rubric and told so; a different section is never substituted")

# ── Write the lens input; its ABSOLUTE path is the stdout key ─────────────────
# THIS WRITE CAN NEVER FAIL THE BUILD. A dispatch prompt that assembled correctly
# must not become undispatchable because a LENS input could not be written: the
# failure is recorded in warnings[] + the provenance appendix, the key is simply
# absent (the controller then tells the lens it has no rubric — the same path as
# a genuinely absent rubric), and the exit code is untouched. Same temp-file +
# os.replace() discipline as the prompt, for the same reason: a reader either
# sees a complete rubric or sees nothing.
DESIGN_SLICE_DIR = os.path.join(VAULT, "lens-inputs", UNIT_ID)
DESIGN_SLICE_PATH = os.path.abspath(os.path.join(DESIGN_SLICE_DIR, "design-slice.md"))
design_slice_path = None
if design_slice_text:
    _ds_tmp = os.path.join(DESIGN_SLICE_DIR, ".design-slice.md.tmp-%d" % os.getpid())
    try:
        os.makedirs(DESIGN_SLICE_DIR, exist_ok=True)
        with open(_ds_tmp, "w", encoding="utf-8", newline="\n") as f:
            f.write(design_slice_text + "\n")
        os.replace(_ds_tmp, DESIGN_SLICE_PATH)
        design_slice_path = DESIGN_SLICE_PATH
    except OSError as e:
        try:
            os.unlink(_ds_tmp)
        except OSError:
            pass
        WARNINGS.append("could not write the design-lens input %s (%s) — `design_slice_path` is "
                        "ABSENT and the design lens must be told it has no rubric; the slice is "
                        "still present in the dispatch prompt itself"
                        % (DESIGN_SLICE_PATH, e))
        omit("design_slice_path",
             "the lens-input file could not be written (%s) — the path key is omitted rather "
             "than pointing at a file that does not exist" % e)

# ── Provenance appendix — the omission audit trail, IN THE FILE ───────────────
# context-enrichment.md §stdout JSON: `sections_omitted[]` is forensics the
# controller never reads (41–63 % of the old JSON), so it moves OFF default
# stdout — but nothing is deleted, only the channel changes. Its home is the
# prompt file's own provenance section, where the human auditor and
# validate-dispatch-prompt.sh can both see it.
#
# ⚠ ACCOUNTING: this block is appended AFTER Tier 3 and is EXCLUDED from
# consumed_t1 / consumed_t2 / total_bytes — exactly like the `### T2 budget
# tracker` and the Tier-3 pointer list already are. `total` describes the two
# budgeted tiers the cascade and the halt reason about; the on-disk file is
# larger than `total` by those three blocks. The gap is no longer merely stated
# in a comment a reviewer has to find: the tracker inside the prompt now carries
# `file_total` and enumerates exactly what the difference is, and stdout carries
# `file_bytes` beside `total_bytes`.
prov_lines = ["═══════════════════════════════════════════",
              "PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)",
              "═══════════════════════════════════════════", "",
              "Every absent or unresolvable input is recorded here rather than invented "
              "(invariant #5).", ""]
if SECTIONS_OMITTED:
    for _o in SECTIONS_OMITTED:
        prov_lines.append("- %s: %s" % (_o["section"], _o["reason"]))
else:
    prov_lines.append("- (none — every specified input resolved)")
prov_text = "\n".join(prov_lines)


def assemble(tracker_text):
    return "\n\n".join([t1_text, t2_header, t2_text(),
                        tracker_text, t3_text, prov_text]) + "\n"


# THE FIXED POINT, in exactly two passes. Pass 1 measures the file with a
# placeholder; pass 2 re-renders with the measured value, at the SAME width
# (`%-8d`), so the file it describes is the file it is in. If the widths ever
# disagreed (a prompt ≥ 100 MB — not reachable under cap_hard, but asserted
# rather than assumed) the number would be wrong, so that case reports the
# measured floor and says so instead of shipping a false figure.
PROMPT = assemble(render_tracker(0))
file_bytes = blen(PROMPT)
PROMPT = assemble(render_tracker(file_bytes))
if blen(PROMPT) != file_bytes:
    file_bytes = blen(PROMPT)
    WARNINGS.append("the in-prompt `file_total` is a LOWER BOUND on this run: the byte count "
                    "did not fit the fixed-width field, so the tracker's figure is smaller than "
                    "the %d bytes the file actually holds (stdout `file_bytes` is exact)"
                    % file_bytes)

# ── The halt, written as ONE explicit three-term conjunction ─────────────────
# context-enrichment.md:67 — fires ONLY when ALL of:
#   (a) priorities 1-8 are already at their drop floor,
#   (b) total still exceeds cap_hard, AND
#   (c) constitution_clauses alone is non-truncatable.
# Term (c) is read as "a non-empty constitution_clauses section exists" — the
# prose's own gloss is "a unit references too many constitution clauses for one
# bolt". When (a) and (b) hold but there is NO constitution section, the
# conjunction is NOT satisfied: we WARN and proceed rather than invent a halt.
_const = SECTIONS.get("constitution_clauses")
constitution_nontruncatable = bool(_const and _const.text().strip())
halt = None
if all_1_to_8_at_floor and total_bytes > CAP_HARD and constitution_nontruncatable:
    # `warnings` here IS running_budget.warnings — the truncation-event list the
    # halt payload is specified to carry (context-enrichment.md:167). Free-text
    # log lines live in the top-level `warnings` key of the JSON, not in here.
    #
    # `truncation_exhausted` is DERIVED from term (a), never asserted as a
    # literal. What it means is "the cascade has no rung left to spend", which is
    # exactly what `all_1_to_8_at_floor` measures — and that predicate is
    # VACUOUSLY TRUE when the unit has no priority-1..8 section at all
    # (add_section returns early on an empty level, so absent sections never
    # enter CASCADE_ORDER). So this field being true does NOT imply that any
    # rung was spent; `warnings` below is the authoritative list and it is
    # legitimately EMPTY on such a run. Stated plainly because the literal it
    # replaces read as a claim about spent truncations that the same payload
    # contradicted.
    halt = {"halt": "dispatch_prompt_too_large", "cap_hard": CAP_HARD, "total": total_bytes,
            "t1_bytes": consumed_t1, "t2_bytes": consumed_t2,
            "warnings": TRUNCATIONS,
            "truncation_exhausted": all_1_to_8_at_floor}
elif total_bytes > CAP_HARD:
    WARNINGS.append("total %d exceeds cap_hard %d but the documented three-way halt conjunction "
                    "is NOT satisfied (all_1_8_at_floor=%s, constitution_nontruncatable=%s) — "
                    "proceeding rather than inventing a halt"
                    % (total_bytes, CAP_HARD, all_1_to_8_at_floor, constitution_nontruncatable))


# ══════════════════════════════════════════════════════════════════════════════
# WRITE the on-disk artifact
# ══════════════════════════════════════════════════════════════════════════════
# The FILE is contractual: scripts/validate-dispatch-prompt.sh GLOBS exactly
# `<vault>/bolts/*/dispatch-prompt.md` and has no other input. 2b removes the
# MODEL's two copies, never the file — if the file disappeared the advisory gate
# would SKIP on "no emitted bolts/**/dispatch-prompt.md found" and silently go
# dark, which looks identical to a passing suite.
#
# VALIDATOR DISPATCH IS A HOOK, NOT A CALLER OBLIGATION. `hooks/post-tool-use`
# fires validate-dispatch-prompt.sh deterministically on the Bash call that runs
# this builder, exactly as it fires on a `Write|Edit` of an emitted prompt — the
# Bash-leg twin of the pre-builder cadence, per bolt, with zero model
# cooperation. The controller has no wiring step here and must not be given one:
# a prose obligation that duplicates a hook rots, and plugins/mega-sdd/CLAUDE.md's
# *gates > rules > hooks* runs ONE WAY ONLY.
#
# TEMP FILE + ATOMIC RENAME, AND THAT ALONE. The artifact is written to a SIBLING
# temp file in the same directory and os.replace()d into place; same directory
# keeps the rename atomic on Windows too. That is the WHOLE guarantee: the path
# either holds a COMPLETE prompt or is untouched, and a run that fails anywhere
# above simply never renames. The builder deliberately does NOT delete the target
# first — see the header. Deleting bought nothing this rename does not already
# buy, and it is what turned a stdout-encoding failure into a destroyed prompt.
try:
    os.makedirs(BOLT_DIR, exist_ok=True)             # idempotent — Step 0 made it, never assume
except OSError as e:
    die("cannot create %s: %s" % (BOLT_DIR, e))
TMP_PATH = os.path.join(BOLT_DIR, ".dispatch-prompt.md.tmp-%d" % os.getpid())
try:
    with open(TMP_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(PROMPT)
    os.replace(TMP_PATH, PROMPT_PATH)
    TMP_PATH = None                                  # renamed away; nothing left to clean
except OSError as e:
    try:
        os.unlink(TMP_PATH)
    except OSError:
        pass
    TMP_PATH = None
    die("cannot write %s: %s" % (PROMPT_PATH, e))


# ══════════════════════════════════════════════════════════════════════════════
# inline_core — THE POINT OF THIS TRANCHE (<= 700 bytes, hard-asserted)
# ══════════════════════════════════════════════════════════════════════════════
INLINE_CAP = 700                     # ABS_PROMPT is resolved with PROMPT_PATH, at the top


def _core(title, whitelist_mode):
    """whitelist_mode: 'full' | 'count' | 'none'."""
    lines = [
        "mega-sdd-trace:execute-bolts:%s" % unit_id,
        'UNIT: %s "%s"' % (unit_id, title),
        "READ FIRST, IN FULL: %s" % ABS_PROMPT,
        "That file is your COMPLETE dispatch — read it before any other action.",
    ]
    if whitelist_mode == "full" and TARGET_PATHS:
        lines.append("TARGET FILES (whitelist): %s" % ", ".join(TARGET_PATHS))
    elif whitelist_mode == "count" and TARGET_PATHS:
        lines.append("TARGET FILES (whitelist): %d file(s) — full list in the unit "
                     "frontmatter `target_files:` inside that file." % len(TARGET_PATHS))
    lines.append("Anti-context DO-NOTs and the Provenance values block are in that file and are BINDING.")
    return "\n".join(lines)


short_title = (unit_title[:40] + "…") if len(unit_title) > 41 else unit_title
inline_core = _core(unit_title, "full")
inline_degraded = []
if len(inline_core.encode("utf-8")) > INLINE_CAP:
    inline_core = _core(unit_title, "count")
    inline_degraded.append("whitelist -> count + pointer")
if len(inline_core.encode("utf-8")) > INLINE_CAP:
    inline_core = _core(short_title, "count")
    inline_degraded.append("title truncated to 40 chars")
if len(inline_core.encode("utf-8")) > INLINE_CAP:
    inline_core = _core(short_title, "none")
    inline_degraded.append("whitelist dropped entirely")
if len(inline_core.encode("utf-8")) > INLINE_CAP:
    # The irreducible minimum is the trace tag + the read directive; both are
    # mandatory and are NEVER dropped. Over-budget here means an extreme absolute
    # path — recorded honestly rather than silently truncated.
    WARNINGS.append("inline_core is %d bytes (> %d) after full degradation — the trace tag and "
                    "the read directive are mandatory and were never dropped"
                    % (len(inline_core.encode("utf-8")), INLINE_CAP))
else:
    assert len(inline_core.encode("utf-8")) <= INLINE_CAP

# The implementer's escape hatch (agents/bolt-implementer.md Rule 0) is a
# byte-exact marker: "the prompt contains a `## Unit body (verbatim)` section;
# anything else is a pointer, and a pointer means Read." The unit TITLE is
# author-controlled and lands inside inline_core, so a unit titled after that
# marker can put the literal into the pointer itself. It can only ever land
# MID-LINE here (fm_scalar reads one line, and the title sits after `UNIT: `),
# so the durable fix is a LINE-START test on the agent side; this is the smoke
# alarm for the case where that has not landed yet. Never mutates the title —
# rewriting an author's text to defend a marker is the wrong direction.
if "## Unit body (verbatim)" in inline_core:
    WARNINGS.append("the unit TITLE contains the literal `## Unit body (verbatim)`, which is "
                    "the bolt-implementer's byte-exact 'this prompt is fully inlined' marker — "
                    "it now appears inside the 700-byte POINTER. The marker is only ever valid "
                    "at LINE START; rename the unit or the implementer may skip the mandatory "
                    "Read of %s" % ABS_PROMPT)


# ══════════════════════════════════════════════════════════════════════════════
# JSON report — PRINT WHAT THE CONTROLLER CONSUMES
# ══════════════════════════════════════════════════════════════════════════════
# stdout is a MEASURED INPUT CHANNEL: `--quiet` is forbidden for the controller
# (stdout is the sole carrier of `inline_core`), so this object lands as a tool
# result on EVERY bolt, and every byte here is re-billed as resident context on
# every subsequent controller turn. Two things were removed from it for that
# reason: `sections_omitted[]` (forensics the controller never reads) and the
# design slice's TEXT, which is now a ~70-byte path to a lens-input file. Exact
# post-change sizes are measured, not asserted, and published with the tranche.
#
# ENCODING: ensure_ascii=True is not cosmetic. A redirected Python stdout on the
# documented Windows/Git-Bash target falls back to the ANSI code page with
# errors='strict', and this object legitimately carries `→`/`≥`/CJK paths/
# em-dashes. Pure-ASCII output cannot raise on any code page. Consumers MUST
# parse this as JSON (a `\uXXXX` escape is the same string once parsed) — a
# grep for a non-ASCII substring of raw stdout is not a supported read.
#
# `sections_omitted[]` is NOT DELETED — only the default CHANNEL changes. It is
# written into the prompt file's own `PROVENANCE — omissions` appendix, where the
# auditor and validate-dispatch-prompt.sh can both see it, and `--explain` adds it
# back to stdout for a human debugging one bolt. --explain ADDS; --quiet REMOVES
# EVERYTHING. They are not two settings of one dial (context-enrichment.md
# §stdout JSON) and the wrapper rejects the combination.
report = {
    "status": "halt" if halt else ("ok_with_soft_halts" if SOFT_HALTS else "ok"),
    "unit": unit_id,
    "prompt_path": ABS_PROMPT,
    "t1_bytes": consumed_t1,
    "t2_bytes": consumed_t2,
    # `total_bytes` is T1+T2 — the BUDGETED tiers, the ones the cascade truncates
    # and the halt reasons about. `file_bytes` is the whole dispatch-prompt.md as
    # written. They differ by exactly four blocks plus the newlines joining them:
    # the TIER 2 banner, the tracker block, the TIER 3 pointer list and the
    # PROVENANCE appendix. (NOT the title or TIER 1 banners — both are appended
    # into `t1` and are already inside `total_bytes`.) The prompt's own tracker
    # states the same two numbers and the same enumeration. Neither is derived
    # from the other and neither may be renamed into the other.
    "total_bytes": total_bytes,
    "file_bytes": file_bytes,
    "truncations": TRUNCATIONS,
    "soft_halts": SOFT_HALTS,
    "warnings": WARNINGS,
    "halt": halt,
    "inline_core": inline_core,
}
# Omitted ENTIRELY (absent key, never "" and never a path to a file that was not
# written) when the unit is not UI-bearing, every design input was absent, or the
# lens-input write failed — the controller then dispatches the design lens with
# no rubric and SAYS so, rather than substituting a different section.
if design_slice_path:
    report["design_slice_path"] = design_slice_path
if EXPLAIN:
    report["caps"] = {"cap_hard": CAP_HARD, "cap_target": CAP_TARGET,
                      "cap_t1": CAP_T1, "cap_t2": CAP_T2}
    report["sections_emitted"] = SECTIONS_EMITTED
    report["sections_omitted"] = SECTIONS_OMITTED
    report["inline_core_bytes"] = len(inline_core.encode("utf-8"))
    report["inline_core_degraded"] = inline_degraded
    report["pack_chain"] = PACK_CHAIN
    report["pack_resolver_exit"] = PACK_RC
    report["interpreter"] = PY_USED
if not QUIET:
    sys.stdout.write(json.dumps(report, ensure_ascii=True, indent=2) + "\n")
sys.exit(1 if halt else 0)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
