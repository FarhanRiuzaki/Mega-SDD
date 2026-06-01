#!/usr/bin/env bash
# resolve-framework-pack.sh — shared framework-pack resolver (Task 0, code-delivery sharpening).
#
# WHY: the code-delivery validators (flow-coverage, sibling-consistency,
# cross-cutting-registration, ui-quality, dispatch-prompt, …) MUST stay
# tech-stack-agnostic. They read ALL stack-specific signatures from the active
# framework-convention pack rather than hardcoding Laravel (.blade.php, @section,
# Str::title, …). This helper is the single chokepoint that:
#   1. determines the active pack name for a project,
#   2. follows the pack `extends:` chain, and
#   3. (optionally) emits a named `## <section>` body merged across the chain.
# Adding a new stack = adding a pack file; never editing a validator.
#
# This is a RESOLVER, not a validator: it prints to stdout and sets an exit
# code. It writes NO state file and has NO PASS/FAIL status semantics — those
# belong to the downstream validators that CONSUME this helper.
#
# Usage:
#   resolve-framework-pack.sh --cwd=<project-root> [--section=<name>] [--quiet]
#
# Behavior:
#   (no --section) prints the resolved pack chain, basenames WITH .md, space-
#       separated, single line, MOST-SPECIFIC FIRST. e.g.:
#           laravel-base-26.md laravel.md _universal.md
#   (--section=<name>) prints the body of each pack's matching `## <name>...`
#       section, concatenated MOST-SPECIFIC-FIRST (callers parsing structured
#       keys apply first-occurrence-wins, so the most-specific pack wins on
#       conflict). Section-header match is case-insensitive prefix match after
#       stripping the leading "## " — so `--section=naming` matches both
#       `## Naming standards` and `## Naming standards (overrides + additions)`.
#   --quiet suppresses stderr diagnostics only (stdout is the contract).
#
# Pack-name resolution order:
#   1. <root>/.mega-sdd/codebase/starterkit-context.yaml key `framework_pack:`
#      (tolerates indentation under `starterkit_context:`; strips a trailing .md)
#   2. <root>/.mega-sdd/codebase/codebase-map.md frontmatter `framework:`
#      (scalar value, OR nested block whose `name:` is used)
#   3. fallback: _universal
#   If the named pack file does not exist under the pack root, fall back to
#   _universal.md (graceful — never error on an unknown stack name).
#
# Exit codes:
#   0  success (chain printed, or section found + printed)
#   2  bad/unknown argument (strict parse)
#   3  no pack resolvable at all (no _universal.md present) OR --section absent
#      in every pack of the chain. Callers treat exit 3 as SKIP.

set -uo pipefail

CWD=""
SECTION=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --section=*) SECTION="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required and must exist" >&2
  exit 2
fi

# Resolve project root via the sibling helper in this same _lib/ dir.
# NOTE: this script lives in scripts/_lib/, so the sibling is "<dir>/resolve-project-root.sh"
# — NOT "<dir>/_lib/resolve-project-root.sh" (that path applies to scripts in scripts/).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

# Pack root is RELATIVE TO THE PLUGIN, not the project: scripts/_lib/ -> ../../references/framework-conventions
PACK_ROOT="$(cd "$(dirname "$0")/../../references/framework-conventions" 2>/dev/null && pwd)"
if [ -z "$PACK_ROOT" ] || [ ! -d "$PACK_ROOT" ]; then
  [ "$QUIET" -eq 0 ] && echo "ERROR: pack root not found (expected scripts/_lib/../../references/framework-conventions)" >&2
  exit 3
fi

CWD="$CWD" SECTION="$SECTION" QUIET="$QUIET" PACK_ROOT="$PACK_ROOT" python3 <<'PYEOF'
import os
import re
import sys

cwd = os.environ["CWD"]
section = os.environ.get("SECTION", "")
quiet = os.environ.get("QUIET", "0") == "1"
pack_root = os.environ["PACK_ROOT"]


def warn(msg):
    if not quiet:
        print(msg, file=sys.stderr)


def strip_md(name):
    name = name.strip().strip('"').strip("'")
    if name.endswith(".md"):
        name = name[:-3]
    # tolerate values like "framework-conventions/laravel-base-26.md"
    name = os.path.basename(name)
    return name


def read_text(path):
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return None


# --- Step 1: determine active pack name ---
def detect_pack_name():
    codebase_dir = os.path.join(cwd, ".mega-sdd", "codebase")

    # 1. starterkit-context.yaml key `framework_pack:` (possibly indented)
    sk = os.path.join(codebase_dir, "starterkit-context.yaml")
    txt = read_text(sk)
    if txt:
        m = re.search(r"^\s*framework_pack:\s*(.+?)\s*$", txt, re.MULTILINE)
        if m and m.group(1).strip() not in ("", "null", "~"):
            return strip_md(m.group(1)), f"starterkit-context.yaml framework_pack"

    # 2. codebase-map.md frontmatter `framework:` — scalar OR nested `name:`
    cmap = os.path.join(codebase_dir, "codebase-map.md")
    txt = read_text(cmap)
    if txt:
        # scalar form: `framework: laravel`
        # Use [^\S\n]* (horizontal whitespace) so a trailing newline after the
        # key does NOT let the match cross into the next line and capture a
        # nested `name:` mapping (which would mis-resolve the pack).
        m = re.search(r"^framework:[^\S\n]*([^\s].*?)[^\S\n]*$", txt, re.MULTILINE)
        if m and m.group(1).strip() not in ("", "null", "~"):
            return strip_md(m.group(1)), "codebase-map.md framework: (scalar)"
        # nested-block form:
        #   framework:
        #     name: laravel-base-26
        m = re.search(r"^framework:[^\S\n]*\n(?:[^\S\n]+\S.*\n)*?[^\S\n]+name:[^\S\n]*(.+?)[^\S\n]*$",
                      txt, re.MULTILINE)
        if m and m.group(1).strip() not in ("", "null", "~"):
            return strip_md(m.group(1)), "codebase-map.md framework: (nested name)"

    # 3. fallback
    return "_universal", "fallback (no manifest)"


pack_name, source = detect_pack_name()
warn(f"# active pack: {pack_name} (via {source})")


# --- Step 2: resolve extends chain, most-specific-first ---
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---", re.DOTALL)
EXTENDS_RE = re.compile(r"^extends:\s*(.+?)\s*$", re.MULTILINE)


def pack_path(name):
    return os.path.join(pack_root, f"{name}.md")


def parse_extends(name):
    path = pack_path(name)
    txt = read_text(path)
    if txt is None:
        return None
    fm = FRONTMATTER_RE.match(txt)
    if not fm:
        return None
    m = EXTENDS_RE.search(fm.group(1))
    if not m:
        return None
    val = m.group(1).strip().strip('"').strip("'")
    if val in ("", "null", "~", "none"):
        return None
    return strip_md(val)


# If the named pack file is missing, gracefully fall back to _universal.
if not os.path.isfile(pack_path(pack_name)):
    warn(f"# pack file {pack_name}.md not found — falling back to _universal")
    pack_name = "_universal"

if not os.path.isfile(pack_path(pack_name)):
    # not even _universal.md exists — nothing resolvable
    warn("# no resolvable pack (even _universal.md is missing)")
    sys.exit(3)

chain = []
seen = set()
cur = pack_name
while cur and cur not in seen:
    if not os.path.isfile(pack_path(cur)):
        warn(f"# extends target {cur}.md not found — stopping chain walk")
        break
    seen.add(cur)
    chain.append(cur)
    cur = parse_extends(cur)

if not chain:
    sys.exit(3)

# --- No --section: print the chain (basenames with .md, most-specific-first) ---
if not section:
    print(" ".join(f"{n}.md" for n in chain))
    sys.exit(0)


# --- With --section: emit merged section bodies, most-specific-first ---
def extract_section(name, wanted):
    """Return the body text of the first '## <wanted>...' section, or None.
    Case-insensitive prefix match after stripping '## '."""
    txt = read_text(pack_path(name))
    if txt is None:
        return None
    wanted_l = wanted.strip().lower()
    lines = txt.splitlines()
    body = []
    capturing = False
    for line in lines:
        if line.startswith("## "):
            header = line[3:].strip().lower()
            if not capturing and header.startswith(wanted_l):
                capturing = True
                continue
            elif capturing:
                # next ## header ends the section
                break
        elif line.startswith("# ") and capturing:
            break
        if capturing:
            body.append(line)
    if not capturing:
        return None
    return "\n".join(body).strip("\n")


emitted = []
for name in chain:
    sec = extract_section(name, section)
    if sec is not None and sec.strip():
        emitted.append((name, sec))

if not emitted:
    warn(f"# section '{section}' not declared in any pack of the chain — SKIP")
    sys.exit(3)

out_blocks = []
for name, sec in emitted:
    out_blocks.append(f"# --- from {name}.md ---\n{sec}")
print("\n\n".join(out_blocks))
sys.exit(0)
PYEOF

exit $?
