#!/usr/bin/env bash
# validate-dispatch-prompt.sh — code-delivery sharpening, Task F (enrichment durability).
#
# Per docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md §3 Slice F
# and plan docs/superpowers/plans/2026-06-01-sharpen-code-delivery-uiux.md §Task F.
#
# UI dispatch-prompt enrichment gate. Makes the execute-bolts UI enrichment
# NON-NO-OP-ABLE: asserts that a ui_ux unit's emitted bolt dispatch prompt
# (<vault>/bolts/U-XXX/dispatch-prompt.md) ACTUALLY carries (a) injected design
# tokens and (b) a view/component code exemplar — not just the controller-only
# skeleton. The enrichment lives in skill prose (execute-bolts T2 slice builder);
# this deterministic validator is what makes that prose durable (prose-only
# wire-ups historically no-op'd 4x — see plugins/mega-sdd/CLAUDE.md Fork A).
#
# TECH-AGNOSTIC: this validator hardcodes NO stack signature (no .blade/@section/
# Laravel literals in logic — comments only). The ONE stack-specific question
# ("is the cited exemplar a renderable VIEW path for this stack?") is answered by
# the active framework-convention pack via resolve-framework-pack.sh:
#   - `## UI quality signatures` (view_glob) — REQUIRED for the exemplar check;
#       absent => SKIP (graceful, never errors). REUSED from Task E (slice E): the
#       same pack section already means exactly "what a renderable view path looks
#       like in this stack", so no new pack section is minted.
# The "ui_ux" in-scope signal + the design-token KEYS (colors/spacing/fonts) are
# mega-sdd vault/starterkit FORMAT vocabulary (not a stack signature — every stack's
# pack uses the same `ui_ux` slice + `design_tokens.{colors,spacing,fonts}` schema
# field names per references/starterkit-context-schema.md §ui_ux block), so they
# live in the validator core, exactly as the archetype keeps the F-U-/F-S- flow
# taxonomy + module/flow/maker ceremony nouns in its core. Adding a stack = adding a
# pack; never editing this validator. Laravel is only the example + fixture.
#
# ORTHOGONALITY (load-bearing — avoids the vacuous-pass trap): the IN-SCOPE signal
# (does this prompt's verbatim unit body declare `starterkit_relevance: [... ui_ux ...]`?)
# is computed INDEPENDENTLY of the VERDICT signal (does the prompt carry the
# `Design tokens:` line + a view/component exemplar?). A bad/ prompt that lacks both
# tokens AND exemplar is still classified ui_ux and FAILs — it does NOT fall out of
# scope and SKIP.
#
# WHAT IT CHECKS (operating on the emitted dispatch prompts under --cwd):
#   For every <vault>/bolts/U-XXX/dispatch-prompt.md whose verbatim unit body declares
#   ui_ux starterkit_relevance:
#     1. tokens_not_injected: the prompt is MISSING an injected `Design tokens:` line.
#     2. exemplar_missing: the prompt carries NO `Reference code example` whose cited
#        `File:`/`Pattern:` is a VIEW/COMPONENT exemplar — i.e. no cited code-example
#        File path matches the pack view_glob (a controller-only example does not count).
#   Each finding => issues[{unit, prompt, issue, message}].
#
# Usage:
#   validate-dispatch-prompt.sh --cwd=<project-root> [--file-path=<path>] [--quiet]
#   (--file-path accepted for single-file dispatch parity (analyze/certify); the scan is project-wide /
#    current-truth like the sibling gates; it is advisory context only.)
#
# Output:
#   stdout: JSON report (suppressed with --quiet)
#   side-effect: OVERWRITE-writes <cwd>/.mega-sdd/.dispatch-prompt-state.json (current truth)
#   exit 0 = PASS or SKIP; exit 1 = FAIL; exit 2 = error

set -uo pipefail

CWD=""
QUIET=0
FILE_PATH=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# Resolve project root (walk UP to outermost .mega-sdd/ parent).
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR_HELPER="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required and must exist" >&2
  exit 2
fi

STATE_FILE="${CWD}/.mega-sdd/.dispatch-prompt-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || {
  echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2;
}

# Interpreter probe BEFORE anything else runs. Bare `python3` is a documented
# FALSE POSITIVE on Windows (WindowsApps App Execution Alias stub — stderr
# message, exit 49), and this validator is dispatched by analyze FULL (run-analyze.sh V16;
# the per-builder PostToolUse leg died №C v7.5.0). A bare `python3` here means
# the dispatcher runs faithfully into a script that exits 49, writes NO state file,
# and leaves .dispatch-prompt-state.json frozen at last-run truth — a dark gate
# indistinguishable from a passing one, on exactly the machine class where the
# builder's own pack loss would need catching.
# $MEGA_SDD_PY MUST be expanded UNQUOTED — `py -3` is two words.
_RPY_VDP="${SCRIPT_DIR}/_lib/resolve-python.sh"
if [ -f "$_RPY_VDP" ]; then
  # shellcheck disable=SC1090
  . "$_RPY_VDP"
  if ! mega_sdd_python; then
    [ "$QUIET" -eq 0 ] && { mega_sdd_python_remedy >&2; echo >&2; }
    exit 2
  fi
else
  MEGA_SDD_PY="python3"
fi
export MEGA_SDD_PY

# Pull the pack section via the shared resolver (tech-agnostic chokepoint).
# Exit 3 from the resolver = section absent in every pack of the chain (=> SKIP).
PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
UI_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  UI_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="UI quality signatures" --quiet 2>/dev/null) || UI_SECTION=""
fi

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" FILE_PATH="$FILE_PATH" \
UI_SECTION="$UI_SECTION" \
$MEGA_SDD_PY <<'PYEOF'
import json
import os
import re
import sys
import glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ui_section = os.environ.get("UI_SECTION", "")

ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


# ── Recursive glob matcher (pack view_glob uses `**` for any-depth) ───────────
# (cloned from validate-ui-quality.sh / validate-flow-coverage.sh — Python fnmatch
# mishandles `**`.) Used to test a cited exemplar File: path against the pack view_glob.
def _glob_to_regex(pat):
    i = 0
    out = ["(?s:"]
    n = len(pat)
    while i < n:
        c = pat[i]
        if c == "*":
            if pat[i:i + 3] == "**/":
                out.append("(?:.*/)?")   # ** + slash => any depth incl. zero
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
    rx = _GLOB_CACHE.get(pattern)
    if rx is None:
        rx = _glob_to_regex(pattern)
        _GLOB_CACHE[pattern] = rx
    if rx.match(path):
        return True
    # also try suffix match (a cited path may carry leading dirs the glob omits)
    return rx.match(path.split("/", 1)[-1]) is not None if "/" in path else False


def write_and_exit(report, code):
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP",
        "validator": "dispatch-prompt",
        "ts": ts,
        "reason": reason,
        "prompts_checked": 0,
        "issues": [],
        "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


# ── Graceful SKIPs ───────────────────────────────────────────────────────────
vault_root = os.path.join(cwd, ".mega-sdd", "vaults")
if not os.path.isdir(vault_root):
    skip("no_vault (.mega-sdd/vaults/ absent)")


# ── Extract the pack view_glob (REUSED from `## UI quality signatures`, Task E) ─
# We only need ONE scalar (view_glob) from that section — the smallest possible
# coupling. Absent section / absent view_glob => the exemplar check can't be
# stack-specific => SKIP (graceful). Lists in the section (scaffold_tells etc.) are
# irrelevant here and ignored.
def first_view_glob(text):
    if not text or not text.strip():
        return ""
    # most-specific pack is emitted first; first occurrence wins.
    m = re.search(r"^\s*view_glob\s*:\s*(.+)$", text, re.MULTILINE)
    if not m:
        return ""
    v = m.group(1).strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        v = v[1:-1]
    return v.strip()


view_glob = first_view_glob(ui_section)
if not view_glob:
    skip("pack declares no '## UI quality signatures' view_glob (cannot determine what a view exemplar looks like in this stack)")


# ── Locate emitted dispatch prompts (TARGETED glob — NOT os.walk) ─────────────
# CRITICAL: dispatch-prompt.md lives INSIDE .mega-sdd/, which the sibling ui-quality
# tree-walk deliberately SKIPs. So we glob the canonical bolt path directly. Support
# both <vault>/bolts/ and <vault>-bound/bolts/ layouts.
prompt_paths = sorted(set(
    glob.glob(os.path.join(vault_root, "*", "bolts", "*", "dispatch-prompt.md")) +
    glob.glob(os.path.join(vault_root, "*-bound", "bolts", "*", "dispatch-prompt.md"))
))
if not prompt_paths:
    skip("no emitted bolts/**/dispatch-prompt.md found under .mega-sdd/vaults/")


# ── In-scope detection: a UI prompt is one whose verbatim unit body declares ──
# `starterkit_relevance: [... ui_ux ...]`. This is mega-sdd FORMAT vocabulary (the
# slice taxonomy generate-units writes — references/starterkit-context-schema.md +
# generate-units Step 7.7.e), NOT a stack signature. INDEPENDENT of the verdict
# markers below (so a token/exemplar-less prompt still counts as ui_ux and FAILs).
UI_RELEVANCE_RE = re.compile(
    r"starterkit_relevance\s*:\s*\[[^\]]*\bui_ux\b[^\]]*\]"
    r"|starterkit_relevance\s*:\s*(?:\n\s*-\s*\w+)*\n\s*-\s*ui_ux\b",
    re.IGNORECASE,
)
# Fallback in-scope signal: the injected `UI/UX:` slice line (execute-bolts
# Step 4.5.b-starterkit.inject only emits it when the ui_ux slice is present).
UI_SLICE_LINE_RE = re.compile(r"^\s*UI/UX\s*:", re.MULTILINE | re.IGNORECASE)

# ── Verdict markers (the enrichment execute-bolts MUST inject) ────────────────
# (1) injected design tokens — a `Design tokens:` line. The token keys
#     colors/spacing/fonts are schema field names; the LINE LABEL is the durable
#     contract the execute-bolts T2 slice builder emits (un-excluded design_tokens).
DESIGN_TOKENS_RE = re.compile(r"^\s*Design tokens\s*:(.*)$", re.MULTILINE | re.IGNORECASE)
# ADV-07b: a `Design tokens:` LABEL alone (or a placeholder value) is a vacuous pass. Require
# REAL token content within the label value + the few following lines: a hex color, a CSS unit,
# or a colors/spacing/fonts/palette key with a value.
TOKEN_CONTENT_RE = re.compile(
    r"#[0-9a-fA-F]{3,8}\b|\b\d+(?:\.\d+)?(?:px|rem|em)\b|\b(colors?|spacing|fonts?|palette|radius|shadow)\b\s*[:=]",
    re.IGNORECASE)

# (1b) injected design system — a `Design system:` line carrying a chosen style/palette.
#      Like `Design tokens:`, this is mega-sdd FORMAT vocabulary (the vault `design_system`
#      block, surfaced by execute-bolts Step 4.5), NOT a stack signature.
DESIGN_SYSTEM_RE = re.compile(r"^\s*Design system\s*:(.*)$", re.MULTILINE | re.IGNORECASE)
# ADV-07b parity: a real style/palette token (>=3 alnum chars starting with a letter), and NOT a
# placeholder — so `Design system: TODO`/`none`/`tbd` is a vacuous pass and is rejected, exactly
# like the sibling `Design tokens:` content guard.
DESIGN_SYSTEM_CONTENT_RE = re.compile(r"[A-Za-z][A-Za-z0-9]{2,}")
DESIGN_SYSTEM_PLACEHOLDER_RE = re.compile(r"\b(tbd|tba|tbc|todo|none|n/?a|pending|placeholder)\b", re.IGNORECASE)

# (2) a view/component exemplar — a `Pattern: view|component` code-example header
#     AND/OR a cited `File:` path matching the pack view_glob. We accept EITHER the
#     explicit category label OR a view-glob-matching cited file (robust to label
#     wording drift, while staying stack-agnostic via the pack view_glob).
PATTERN_LINE_RE = re.compile(r"^\s*Pattern\s*:\s*(view|component)\b", re.MULTILINE | re.IGNORECASE)
FILE_LINE_RE = re.compile(r"^\s*File\s*:\s*(\S+)", re.MULTILINE)


def is_ui_prompt(text):
    return bool(UI_RELEVANCE_RE.search(text) or UI_SLICE_LINE_RE.search(text))


def has_design_tokens(text):
    m = DESIGN_TOKENS_RE.search(text)
    if not m:
        return False
    # ADV-07b: require REAL token content (in the label value OR the next few lines), not a
    # bare label / placeholder like `Design tokens: TODO none captured yet`.
    window = m.group(1) + "\n" + text[m.end():m.end() + 400]
    return bool(TOKEN_CONTENT_RE.search(window))


def has_design_system(text):
    m = DESIGN_SYSTEM_RE.search(text)
    if not m:
        return False
    val = m.group(1).strip()
    # ADV-07b parity: reject empty / placeholder values; require a real style/palette token.
    if not val or DESIGN_SYSTEM_PLACEHOLDER_RE.search(val):
        return False
    return bool(DESIGN_SYSTEM_CONTENT_RE.search(val))


def has_view_exemplar(text):
    # ADV-07b: a bare `Pattern: view` label is NOT sufficient (it passed vacuously). Require a
    # cited code-example `File:` whose path matches the pack view_glob — a real view/component
    # exemplar, stack-agnostic via the pack glob. (The Pattern label alone, with a controller-only
    # File: or no File:, no longer satisfies the check.)
    for m in FILE_LINE_RE.finditer(text):
        cited = m.group(1).strip()
        if glob_match(cited, view_glob):
            return True
    return False


# ── Scan each emitted prompt ──────────────────────────────────────────────────
issues = []
prompts_checked = 0
for pp in prompt_paths:
    try:
        with open(pp, errors="replace") as f:
            text = f.read()
    except Exception:
        continue
    if not is_ui_prompt(text):
        continue  # not a ui_ux unit's prompt — out of scope for this gate
    prompts_checked += 1
    rel = os.path.relpath(pp, cwd)
    # unit id from the bolts/U-XXX/ dir name
    unit = os.path.basename(os.path.dirname(pp))

    if not has_design_tokens(text):
        issues.append({
            "unit": unit,
            "prompt": rel,
            "issue": "tokens_not_injected",
            "message": (
                "A ui_ux unit's dispatch prompt carries no injected design tokens "
                "(no `Design tokens:` line). execute-bolts Step 4.5.b-starterkit.build "
                "must INCLUDE design_tokens (colors/spacing/fonts) in the ui_ux T2 slice "
                "(mid-priority in the truncation cascade — not first-dropped)."
            ),
        })

    if not has_design_system(text):
        issues.append({
            "unit": unit,
            "prompt": rel,
            "issue": "design_system_not_injected",
            "message": (
                "A ui_ux unit's dispatch prompt carries no chosen design system "
                "(no `Design system:` line). execute-bolts Step 4.5 must inject the vault "
                "`design_system` (style/palette) for ui_ux units when the vault resolved a "
                "Design-Source recommendation; the bolt must render per the chosen style, "
                "not a generic look."
            ),
        })

    if not has_view_exemplar(text):
        issues.append({
            "unit": unit,
            "prompt": rel,
            "issue": "exemplar_missing",
            "message": (
                "A ui_ux unit's dispatch prompt carries no view/component code exemplar "
                f"(no `Pattern: view|component` header and no cited `File:` matching the "
                f"pack view_glob `{view_glob}`). The Iter-76 code-slice must extend beyond "
                "controller-only to a view/component category, selecting a linter-clean "
                "exemplar (NOT [0]), so the bolt subagent has a concrete view to follow."
            ),
        })


# ── If no ui_ux prompt was found at all => SKIP (gate does not apply here) ────
if prompts_checked == 0:
    skip("no ui_ux-relevance dispatch prompt found (no prompt declares starterkit_relevance ui_ux)")


# ── Verdict ──────────────────────────────────────────────────────────────────
status = "FAIL" if issues else "PASS"
tokens_n = sum(1 for i in issues if i["issue"] == "tokens_not_injected")
design_system_n = sum(1 for i in issues if i["issue"] == "design_system_not_injected")
exemplar_n = sum(1 for i in issues if i["issue"] == "exemplar_missing")
report = {
    "status": status,
    "validator": "dispatch-prompt",
    "ts": ts,
    "view_glob": view_glob,
    "prompts_checked": prompts_checked,
    "summary": {
        "ui_prompts_checked": prompts_checked,
        "tokens_not_injected": tokens_n,
        "design_system_not_injected": design_system_n,
        "exemplar_missing": exemplar_n,
    },
    "issues": issues,
    "next_action": (
        "Re-emit the flagged ui_ux unit's bolt dispatch prompt with the UI enrichment: "
        "(a) include design_tokens (colors/spacing/fonts) in the ui_ux T2 slice, "
        "(b) inject a view/component code exemplar (linter-clean, not [0]) via the "
        "extended Iter-76 code-slice, and (c) include a `Design system:` line (the vault "
        "design_system style/palette) when the vault resolved one. Then re-run execute-bolts "
        "(then re-run analyze — this validator is advisory and re-runs there)."
    ) if status == "FAIL" else "No action — every ui_ux dispatch prompt carries injected design tokens, a design system, and a view exemplar.",
}

write_and_exit(report, 0 if status == "PASS" else 1)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
