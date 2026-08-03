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
# code. It writes NO STATE file and has NO PASS/FAIL status semantics — those
# belong to the downstream validators that CONSUME this helper. It DOES maintain
# a derived, discardable stdout cache under <root>/.mega-sdd/.cache/pack-resolver/
# (only when .mega-sdd/ already exists — never minted); deleting it costs one
# cold resolve.
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
#   2  bad/unknown argument (strict parse), or NO USABLE PYTHON INTERPRETER
#      (Windows App-Execution-Alias stub). Non-zero-and-not-3 means the chain is
#      UNKNOWN, never "this project has no pack" — callers MUST distinguish.
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

# ─── Derived cache — ZERO-EXEC hit path (spec §4a-i, tranche 4) ───────────────
# Four gate-firing validators call this resolver per PreToolUse firing; the
# answer changes only when starterkit-context.yaml / codebase-map.md / the pack
# files change. The cache is DERIVED and DISCARDABLE (deleting it costs one
# cold resolve) — it is NOT a state file; stdout on a hit is byte-identical to
# a cold run (the cache stores the cold run's exact stdout + exit code).
#
# Validity is decided with BUILTINS only (bash-3.2-safe): a hit spawns ZERO
# pythons and no child beyond the prologue's two dirname subshells above.
#   - input-file EXISTENCE parity ([ -f ]) for both project inputs — `-nt` alone
#     is true when the reference file is MISSING, so a deleted input would
#     wrongly validate a stale cache without this;
#   - [ cache -nt input ] for both project inputs, EVERY pack file in the
#     cached chain, and the pack ROOT dir (a newly added more-specific pack
#     bumps the dir mtime).
# Any doubt (unreadable cache, meta mismatch, unexpected format) falls through
# to the cold path below, which rewrites the cache on success.
# GRANULARITY, stated: bash `-nt` compares whole seconds on some platforms, so a
# cache written in the SAME wall-clock second as its input does not validate and
# the next call re-resolves cold. That is the SAFE direction (a wasted resolve,
# never a stale answer) and self-heals one second later — do not "fix" it by
# accepting equal mtimes, which would serve stale output when an input is
# modified in the same second AFTER the cache write.
_SK_FILE="${CWD}/.mega-sdd/codebase/starterkit-context.yaml"
_CM_FILE="${CWD}/.mega-sdd/codebase/codebase-map.md"
_ST_FILE="${CWD}/.mega-sdd/state.json"
_SK_F=0; [ -f "$_SK_FILE" ] && _SK_F=1
_CM_F=0; [ -f "$_CM_FILE" ] && _CM_F=1
_ST_F=0; [ -f "$_ST_FILE" ] && _ST_F=1
_SEC_KEY="${SECTION:-_chain}"
_SEC_KEY_SAFE=""
while [ -n "$_SEC_KEY" ]; do
  _C="${_SEC_KEY%"${_SEC_KEY#?}"}"; _SEC_KEY="${_SEC_KEY#?}"
  case "$_C" in
    [A-Za-z0-9._-]) _SEC_KEY_SAFE="${_SEC_KEY_SAFE}${_C}" ;;
    *) _SEC_KEY_SAFE="${_SEC_KEY_SAFE}-" ;;
  esac
done
# F6 (round-1): cache ONLY when .mega-sdd/ already exists — the writer must
# never mint a phantom project root (EB-GATE-6 doctrine); empty cache path
# disables both the hit read below and the python writer.
_CACHE_FILE=""
if [ -d "${CWD}/.mega-sdd" ]; then
  _CACHE_DIR="${CWD}/.mega-sdd/.cache/pack-resolver"
  _CACHE_FILE="${_CACHE_DIR}/${_SEC_KEY_SAFE:-_chain}.out"
fi
if [ -n "$_CACHE_FILE" ] && [ -f "$_CACHE_FILE" ]; then
  _META=""
  IFS= read -r _META < "$_CACHE_FILE" 2>/dev/null || _META=""
  _META="${_META%$'\r'}"   # a CRLF-written meta (Windows python) must not poison the parse
  case "$_META" in
    "# packres-v2 rc="*" sk=${_SK_F} cm=${_CM_F} st=${_ST_F} chain="*)
      _RC_PART="${_META#\# packres-v2 rc=}"; _RC="${_RC_PART%% *}"
      _CHAIN_PART="${_META#* chain=}"
      _VALID=1
      # a resolver-CODE change must bust the cache too (F5): $0 is an input
      [ "$_CACHE_FILE" -nt "$0" ] || _VALID=0
      [ "$_CACHE_FILE" -nt "$PACK_ROOT" ] || _VALID=0
      if [ "$_SK_F" = "1" ] && ! [ "$_CACHE_FILE" -nt "$_SK_FILE" ]; then _VALID=0; fi
      if [ "$_CM_F" = "1" ] && ! [ "$_CACHE_FILE" -nt "$_CM_FILE" ]; then _VALID=0; fi
      if [ "$_ST_F" = "1" ] && ! [ "$_CACHE_FILE" -nt "$_ST_FILE" ]; then _VALID=0; fi
      if [ "$_VALID" = "1" ] && [ -n "$_CHAIN_PART" ]; then
        for _PK in $_CHAIN_PART; do
          _PK_PATH="${PACK_ROOT}/${_PK}"
          if [ ! -f "$_PK_PATH" ] || ! [ "$_CACHE_FILE" -nt "$_PK_PATH" ]; then _VALID=0; break; fi
        done
      fi
      case "$_RC" in 0|3) ;; *) _VALID=0 ;; esac
      if [ "$_VALID" = "1" ]; then
        _FIRST=1
        while IFS= read -r _LINE || [ -n "$_LINE" ]; do
          if [ "$_FIRST" = "1" ]; then _FIRST=0; continue; fi
          printf '%s\n' "$_LINE"
        done < "$_CACHE_FILE"
        exit "$_RC"
      fi
      ;;
  esac
fi

# Interpreter. Bare `python3` is a documented FALSE POSITIVE on Windows: the
# WindowsApps App Execution Alias stub sits on the default PATH, prints to
# stderr and exits 49. A caller that swallows a non-zero exit here loses the
# WHOLE framework-pack contribution of every dispatch at exit 0 — reproduced at
# 8733 -> 5412 bytes — so this resolver must not be the weak link.
# An interpreter already resolved by the CALLER wins (build-dispatch-prompt.sh
# exports MEGA_SDD_PY); otherwise resolve it here via the shared helper.
# $MEGA_SDD_PY MUST be expanded UNQUOTED — `py -3` is two words.
if [ -z "${MEGA_SDD_PY:-}" ]; then
  _RPY_FP="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/resolve-python.sh"
  if [ -f "$_RPY_FP" ]; then
    # shellcheck disable=SC1090
    . "$_RPY_FP"
    if ! mega_sdd_python; then
      [ "$QUIET" -eq 0 ] && mega_sdd_python_remedy >&2
      exit 2
    fi
  else
    MEGA_SDD_PY="python3"
  fi
fi

CWD="$CWD" SECTION="$SECTION" QUIET="$QUIET" PACK_ROOT="$PACK_ROOT" \
PACKRES_CACHE="$_CACHE_FILE" PACKRES_SK="$_SK_F" PACKRES_CM="$_CM_F" PACKRES_ST="$_ST_F" $MEGA_SDD_PY <<'PYEOF'
import os
import re
import sys

cwd = os.environ["CWD"]
section = os.environ.get("SECTION", "")
quiet = os.environ.get("QUIET", "0") == "1"
pack_root = os.environ["PACK_ROOT"]

chain = []  # populated below; the cache writer reads it for the meta line


def warn(msg):
    if not quiet:
        print(msg, file=sys.stderr)


def finish(rc, body):
    """Print the contract stdout, write the derived cache (spec §4a-i), exit rc.
    The cache stores this EXACT stdout + rc; the bash hit path replays it with
    zero execs. A cache-write failure is silent — the cold path IS the contract."""
    cache = os.environ.get("PACKRES_CACHE", "")
    if cache:
        try:
            os.makedirs(os.path.dirname(cache), exist_ok=True)
            meta = "# packres-v2 rc=%d sk=%s cm=%s st=%s chain=%s" % (
                rc, os.environ.get("PACKRES_SK", "0"), os.environ.get("PACKRES_CM", "0"),
                os.environ.get("PACKRES_ST", "0"),
                " ".join("%s.md" % n for n in chain))
            tmp = cache + ".tmp"
            with open(tmp, "w", newline="\n") as f:
                f.write(meta + "\n")
                if body:
                    f.write(body if body.endswith("\n") else body + "\n")
            os.replace(tmp, cache)
        except Exception:
            pass
    if body:
        sys.stdout.write(body if body.endswith("\n") else body + "\n")
    sys.exit(rc)


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

    # 3. state.json derived.framework_pack — the P2 GROUND matcher's output
    # (ONE matcher, in _lib/state_probes.py; never a second sniff here).
    # Deliberately BELOW the scan artifacts: when scan ran, its deep-scan
    # verified detection wins; express-born projects have neither and land here.
    st = os.path.join(cwd, ".mega-sdd", "state.json")
    txt = read_text(st)
    if txt:
        m = re.search(r'"framework_pack"\s*:\s*"([A-Za-z0-9._-]+)"', txt)
        if m and m.group(1) not in ("", "_universal"):
            return m.group(1), "state.json derived.framework_pack (GROUND matcher)"

    # 4. fallback
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
    finish(3, "")

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
    finish(3, "")

# --- No --section: print the chain (basenames with .md, most-specific-first) ---
if not section:
    finish(0, " ".join(f"{n}.md" for n in chain))


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
    finish(3, "")

out_blocks = []
for name, sec in emitted:
    out_blocks.append(f"# --- from {name}.md ---\n{sec}")
finish(0, "\n\n".join(out_blocks))
PYEOF

exit $?
