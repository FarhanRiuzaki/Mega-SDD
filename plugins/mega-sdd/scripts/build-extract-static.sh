#!/usr/bin/env bash
# build-extract-static.sh — deterministic builder for the extract-intelligence
# dispatch-static file (<kb-dir>/.dispatch-static.md).
#
# WHY THIS EXISTS (spec §5d, 2026-07-30-token-and-latency-optimization.md)
# -----------------------------------------------------------------------
# The extract-intelligence controller used to TYPE, as model output into every
# wave-subagent dispatch (~15 dispatches/run): the <STACK_IDIOM_ROWS> slice it
# computed from .scan-meta.json, and — for waves 2/3/4 — the <GLOSSARY_INDEX>
# it built by reading the 80–120 KB glossary. This script derives both
# deterministically and writes them ONCE as a file every wave subagent Reads
# first. The invariant extraction contract (deep disciplines, REPORT BACK)
# moved to agents/domain-extractor.md in the same tranche — this script carries
# ONLY the mechanical injections, never discipline prose.
#
# SINGLE-COPY RULE: the MASTER STACK IDIOM TABLE is NOT duplicated here. It is
# PARSED at run time from wave-dispatch-templates.md §Stack-idiom slicing, so
# editing the table there is sufficient and doc↔script drift is impossible.
# A table that fails to parse is a FAIL-CLOSED exit 2 (nothing renamed into
# place) — never a silently empty idioms section.
#
# Usage:
#   build-extract-static.sh --kb-dir=<kb-path> [--plugin-root=<path>]
#                           [--no-glossary] [--quiet]
#
# --no-glossary is the WAVE-0 form: skip the glossary index even when a
# glossary.md exists on disk. Wave 1 REBUILDS the glossary, so on a re-run
# into an existing KB the prior run's glossary must not leak in as a stale
# index that Wave-1 subagents (who WRITE the glossary) would be told to trust.
# Wave awareness stays with the CALLER; this script stays mechanical.
#
# stdout (suppressed by --quiet): one compact JSON object —
#   status, static_path, stacks[], stack_source, columns[], glossary_present,
#   glossary_terms, bytes
#
# Exit:
#   0  file written (temp-file + rename — the path either holds a complete
#      file or is untouched)
#   2  usage / IO / master-table parse failure. NOTHING was renamed into
#      place. NEVER dispatch a wave subagent without this file.
#
# SPAWN BUDGET: constant — this wrapper + the python interpreter (plus the
# resolve-python probe's own internals). No per-item fan-out anywhere; the
# script runs ~2x per extraction (Wave 0, then again after the Wave 1 gate).

set -uo pipefail

KB_DIR=""
PLUGIN_ROOT=""
QUIET=0
NO_GLOSSARY=0
for arg in "$@"; do
  case "$arg" in
    --kb-dir=*)      KB_DIR="${arg#*=}" ;;
    --plugin-root=*) PLUGIN_ROOT="${arg#*=}" ;;
    --no-glossary)   NO_GLOSSARY=1 ;;
    --quiet)         QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$KB_DIR" ] || [ ! -d "$KB_DIR" ]; then
  echo "ERROR: --kb-dir=<kb-path> required and must exist" >&2; exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# Interpreter probe. `command -v python3` is a FALSE POSITIVE on Windows (the
# WindowsApps App Execution Alias stub is on PATH, writes to stderr and exits
# 49). Fail CLOSED: print the canonical remedy, write nothing, exit 2.
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

# Plugin root — used only to locate wave-dispatch-templates.md. Skipped when
# the caller passes it (the documented invocation does). Fallback root is THIS
# script's own location (scripts/.. == the plugin root).
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

export MSDD_KB_DIR="$KB_DIR"
export MSDD_PLUGIN_ROOT="$PLUGIN_ROOT"
export MSDD_QUIET="$QUIET"
export MSDD_NO_GLOSSARY="$NO_GLOSSARY"

# NOT `exec`: a present-but-broken interpreter (the `py` launcher with no 3.x
# registered exits ~103; the WindowsApps stub exits 49 if the probe was skipped)
# would otherwise surface a raw launcher exit code with no remedy — the wrapper
# stays alive to map any non-contract rc onto the documented exit 2. The python
# body's own exits (0 ok, 2 die) pass through untouched.
# shellcheck disable=SC2086
$MEGA_SDD_PY - <<'PY'
import json, os, sys

kb_dir = os.path.abspath(os.environ["MSDD_KB_DIR"])
plugin_root = os.environ["MSDD_PLUGIN_ROOT"]
quiet = os.environ.get("MSDD_QUIET", "0") == "1"
no_glossary = os.environ.get("MSDD_NO_GLOSSARY", "0") == "1"

TEMPLATES = os.path.join(plugin_root, "skills", "extract-intelligence",
                         "references", "wave-dispatch-templates.md")

def die(msg):
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(2)

# ── 1. Parse the MASTER STACK IDIOM TABLE (single copy, in the templates ref) ──
try:
    with open(TEMPLATES, "r", encoding="utf-8", errors="replace") as f:
        tlines = f.read().splitlines()
except OSError as e:
    die("cannot read wave-dispatch-templates.md at %s (%s)" % (TEMPLATES, e))

# Anchor on the MASTER marker, not on a header shape: the emitted slice's own
# header ALSO begins `| Principle | ...` (it is this script's documented output
# format), so an illustrative slice example added earlier in the doc would
# otherwise hijack the locator and silently replace the master table.
marker_i = next((i for i, ln in enumerate(tlines)
                 if "MASTER STACK IDIOM TABLE" in ln), None)
if marker_i is None:
    die("MASTER STACK IDIOM TABLE marker not found in wave-dispatch-templates.md")
hdr_i = next((i for i in range(marker_i + 1, len(tlines))
              if tlines[i].strip().startswith("| Principle |")), None)
if hdr_i is None:
    die("master table header not found after the MASTER STACK IDIOM TABLE marker")
header = [c.strip() for c in tlines[hdr_i].strip().strip("|").split("|")]
rows = []
for ln in tlines[hdr_i + 2:]:
    if not ln.strip().startswith("|"):
        break
    rows.append([c.strip() for c in ln.strip().strip("|").split("|")])
# >=1 uniform rows, deliberately NOT a hard-coded row count: the shipped table's
# 9-row shape is pinned by tests (test-b1-wave-dispatch-diet.sh), where a change
# fails VISIBLY in CI — a magic number here would instead brick a user's Wave 0
# the day a legitimate tenth idiom row is added.
if len(rows) < 1 or any(len(r) != len(header) for r in rows):
    die("master STACK IDIOM TABLE parse failed (need >=1 uniform rows, got %d)" % len(rows))
ALL_COLUMNS = header[1:]  # PHP … Rust, master order

# ── 2. Detect stacks from .scan-meta.json (same quoted-token mechanism as ──
# ── kb-leak-scan.sh; alias convention per §Stack-idiom slicing rule 1)    ──
ALIAS_TO_COLUMN = {}
for aliases, col in [
    (["php"], "PHP"),
    (["javascript", "js", "node", "nodejs", "typescript", "ts"], "JS / TS"),
    (["python", "py"], "Python"),
    (["c#", "csharp", "cs", ".net", "dotnet", "vb", "vb.net", "vbnet"], "C# / .NET"),
    (["java", "kotlin"], "Java"),
    (["go", "golang"], "Go"),
    (["ruby", "rb"], "Ruby"),
    (["rust", "rs"], "Rust"),
]:
    for a in aliases:
        ALIAS_TO_COLUMN[a] = col

# The column TARGETS above are a hand-maintained copy of the doc's header
# spelling — the one axis the parse-the-doc design cannot make structural.
# Fail CLOSED on drift: a reworded doc header would otherwise make detection
# "succeed" into zero usable columns and silently fall back to the full table
# while stdout still claims a scan-meta detection.
_drift = sorted(set(ALIAS_TO_COLUMN.values()) - set(ALL_COLUMNS))
if _drift:
    die("column-name drift: script alias targets %s are not in the master header %s "
        "— update ALIAS_TO_COLUMN to match wave-dispatch-templates.md" % (_drift, ALL_COLUMNS))

meta_path = os.path.join(kb_dir, ".scan-meta.json")
detected, stack_source = [], ""
if os.path.isfile(meta_path):
    try:
        with open(meta_path, "r", encoding="utf-8", errors="replace") as f:
            blob = json.dumps(json.load(f)).lower()
        found = set()
        for alias, col in ALIAS_TO_COLUMN.items():
            if ('"' + alias + '"') in blob:
                found.add(col)
        if found:
            detected = [c for c in ALL_COLUMNS if c in found]  # master order
            stack_source = "scan-meta"
        else:
            stack_source = "fallback-all(unmapped)"
    except Exception:
        stack_source = "fallback-all(unreadable scan-meta)"
else:
    stack_source = "fallback-all(no scan-meta)"

columns = detected if detected else list(ALL_COLUMNS)

def sliced_table():
    keep = [0] + [header.index(c) for c in columns]
    out = ["| " + " | ".join(header[i] for i in keep) + " |",
           "|" + "|".join("---" for _ in keep) + "|"]
    for r in rows:
        out.append("| " + " | ".join(r[i] for i in keep) + " |")
    return "\n".join(out)

# ── 3. Glossary index (deterministic; section emitted only when ≥1 term) ──
gloss_path = os.path.join(kb_dir, "00-overview", "glossary.md")
gloss_present = os.path.isfile(gloss_path)
terms = []
if gloss_present and not no_glossary:
    try:
        with open(gloss_path, "r", encoding="utf-8", errors="replace") as f:
            glines = f.read().splitlines()
    except OSError as e:
        die("cannot read glossary.md (%s)" % e)
    # `## ` inside a ``` / ~~~ fence is NOT a heading — treating it as one
    # silently truncates the PREVIOUS term's line range, and those ranges are
    # what subagents spot-read with.
    heads, in_fence = [], False
    for i, ln in enumerate(glines):
        s = ln.lstrip()
        if s.startswith("```") or s.startswith("~~~"):
            in_fence = not in_fence
            continue
        if not in_fence and ln.startswith("## "):
            heads.append(i)
    for n, i in enumerate(heads):
        term = glines[i][3:].strip()
        end = (heads[n + 1] - 1) if n + 1 < len(heads) else len(glines) - 1
        short = ""
        for ln in glines[i + 1:end + 1]:
            s = ln.strip()
            if s and not s.startswith("#") and not s.startswith("```") and not s.startswith("~~~"):
                short = s
                break
        if len(short) > 80:
            cut = short[:80]
            sp = cut.rfind(" ")
            short = (cut[:sp] if sp > 0 else cut).rstrip() + "…"
        if not short:
            short = "(no definition)"
        terms.append((term, short, i + 1, end + 1))  # 1-based lines

# ── 4. Compose + atomic write ──
parts = [
    "# extract-intelligence dispatch-static — script-generated by build-extract-static.sh. Do not hand-edit.",
    "# Rebuild: bash <plugin-root>/scripts/build-extract-static.sh --kb-dir=%s" % kb_dir,
    "# stacks: %s   (source: %s)" % (", ".join(columns), stack_source),
    "",
    "## STACK IDIOMS",
    "",
    "(sliced to the detected legacy stack(s); disciplines + usage live in your agent body)",
    "",
    sliced_table(),
]
if terms:
    parts += [
        "",
        "## GLOSSARY INDEX",
        "",
        "glossary_index (term: short_def (L<start>-<end>)):",
    ]
    parts += ["- %s: %s (L%d-%d)" % t for t in terms]
content = "\n".join(parts) + "\n"

static_path = os.path.join(kb_dir, ".dispatch-static.md")
tmp = static_path + ".tmp.%d" % os.getpid()
try:
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp, static_path)
except Exception as e:  # UnicodeEncodeError is a ValueError — OSError alone would orphan the tmp
    try:
        os.unlink(tmp)
    except OSError:
        pass
    die("cannot write %s (%s)" % (static_path, e))

warnings = []
if gloss_present and not no_glossary and not terms:
    # glossary.md exists but yields zero `## <term>` headings. The Wave-1 gate is
    # the enforcement point; this names the state so the operator sees WHY the
    # GLOSSARY INDEX section is absent instead of a bare failing grep downstream.
    warnings.append("glossary_no_terms")

if not quiet:
    print(json.dumps({
        "status": "ok",
        "static_path": static_path,
        "stacks": columns,
        "stack_source": stack_source,
        "columns": len(columns),
        "glossary_present": gloss_present,
        "glossary_skipped": no_glossary,
        "glossary_terms": len(terms),
        "warnings": warnings,
        "bytes": len(content.encode("utf-8")),
    }))
PY
RC=$?
if [ "$RC" != "0" ] && [ "$RC" != "2" ]; then
  echo "ERROR: python interpreter failed (rc=$RC) before the builder could run" >&2
  if type mega_sdd_python_remedy >/dev/null 2>&1; then mega_sdd_python_remedy >&2; fi
  exit 2
fi
exit "$RC"
