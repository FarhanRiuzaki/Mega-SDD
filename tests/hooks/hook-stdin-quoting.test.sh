#!/usr/bin/env bash
# hook-stdin-quoting.test.sh
#
# Pins the 2026-07-29 `eval "$PARSE_OUTPUT"` fix across the four hooks that parse
# their stdin JSON in python and hand the result to `eval`: pre-tool-use,
# post-tool-use, stop.
#
# The defect: python printed a BARE `KEY=value` line and bash `eval` re-parsed it,
# so the value went through word-splitting, backslash removal, globbing and
# command substitution. Three live failure modes, all measured on bash 5:
#
#   KEY=/Users/me/My Docs/x.md    -> KEY UNSET (prefix-assignment + failed command)
#   KEY=C:\proj\.mega-sdd\x.md    -> KEY=C:proj.mega-sddx.md   (every \ eaten)
#   KEY=/tmp/$(touch ./PWNED)n.md -> KEY=/tmp/n.md  AND ./PWNED IS CREATED
#
# Impact before the fix: any path containing a space was silently dropped on EVERY
# platform; every Windows path was destroyed, which made CWD `C:proj`, PROJECT_ROOT
# garbage, and the whole PostToolUse validator tree inert on Windows; and a path
# carrying $(…) was executed by the hook.
#
# What this test pins:
#   A. ROUND-TRIP  — the exact producer snippet from each hook, fed a hostile
#      payload, survives `eval` byte-identically to the JSON input.
#   B. CONTROL     — the pre-fix producer (bare `KEY=value`) FAILS those same
#      cases, so a pass here is never vacuous.
#   C. NO EXECUTION— a $(…) in a path is not executed.
#   D. AGREEMENT   — on a Windows payload, PROJECT_ROOT (via eval'd CWD) and the
#      post-tool-use short-circuit's SC_ROOT (via raw-JSON parameter expansion)
#      resolve to the SAME root. Two independent paths to one value must not
#      diverge once both actually work.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
HOOKS="$ROOT/plugins/mega-sdd/hooks"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

# ── the hostile payloads ────────────────────────────────────────────────────
WIN_CWD='C:\proj'
WIN_FP='C:\proj\.mega-sdd\vaults\v1\units\U-001.md'
SPACE_FP='/Users/me/My Docs/unit spec.md'
SUBST_FP='/tmp/$(touch '"$TMP"'/PWNED)note.md'
QUOTE_DESC="review the panel's \"blind\" lenses
second line	tabbed \$HOME \`bt\` \$(id)"

mk_json() { # $1=cwd $2=file_path $3=description
  CWD_V="$1" FP_V="$2" DESC_V="$3" "$PY" -c '
import json, os
print(json.dumps({
    "session_id": "s-1",
    "cwd": os.environ["CWD_V"],
    "transcript_path": os.environ["CWD_V"] + "/t.jsonl",
    "hook_event_name": "PostToolUse",
    "tool_name": "Write",
    "tool_input": {"file_path": os.environ["FP_V"], "description": os.environ["DESC_V"]},
}))'
}

# ── the two producers: FIXED (shlex.quote) vs PRE-FIX (bare) ────────────────
# Both are written to FILES, not passed via `python3 -c` — the control producer is
# itself full of quotes, and nesting it inside shell quoting once made it a syntax
# error, which silently turned "control fails the case" into "control produced
# nothing". That is a vacuous pass, so the shape matters.
cat > "$TMP/prod_fixed.py" <<'PYEOF'
import json, shlex, sys
def emit(k, v): print(k + "=" + shlex.quote(str(v)))
d = json.loads(sys.stdin.read())
ti = d.get("tool_input", {})
emit("CWD", d.get("cwd", ""))
emit("FILE_PATH", ti.get("file_path", ""))
emit("AGENT_DESCRIPTION", ti.get("description", "")[:200])
PYEOF
cat > "$TMP/prod_prefix.py" <<'PYEOF'
# verbatim pre-fix shape: a BARE key=value line, handed straight to `eval`
import json, sys
d = json.loads(sys.stdin.read())
ti = d.get("tool_input", {})
print("CWD=" + d.get("cwd", ""))
print("FILE_PATH=" + ti.get("file_path", ""))
print("AGENT_DESCRIPTION=" + ti.get("description", "")[:200])
PYEOF
# Guard: a producer that ERRORS emits nothing, which would make every control
# assertion below pass for the wrong reason. Prove both parse and emit first.
for p in prod_fixed prod_prefix; do
  n=$(printf '%s' "$(mk_json /p /p/x.md d)" | "$PY" "$TMP/$p.py" 2>/dev/null | grep -c '^[A-Z_]*=' || true)
  if [ "${n:-0}" -ne 3 ]; then
    echo "FAIL (harness: $p.py emitted ${n:-0}/3 lines — every assertion below would be vacuous)"
    exit 1
  fi
done
prod_fixed()  { "$PY" "$TMP/prod_fixed.py"; }
prod_prefix() { "$PY" "$TMP/prod_prefix.py"; }

# Consume exactly the way the hooks do, then report one field.
consume() { # stdin=producer output, $1=var name
  bash -c 'set -uo pipefail
P=$(cat)
eval "$P" 2>/dev/null || true
eval "printf %s \"\${$1:-<UNSET>}\""' _ "$1"
}

echo "── A. ROUND-TRIP through eval (fixed producer) ──"
for case_name in windows space subst quotes; do
  case "$case_name" in
    windows) J=$(mk_json "$WIN_CWD" "$WIN_FP" "d");   FIELD=FILE_PATH;        WANT="$WIN_FP" ;;
    space)   J=$(mk_json "/p" "$SPACE_FP" "d");        FIELD=FILE_PATH;        WANT="$SPACE_FP" ;;
    subst)   J=$(mk_json "/p" "$SUBST_FP" "d");        FIELD=FILE_PATH;        WANT="$SUBST_FP" ;;
    quotes)  J=$(mk_json "/p" "/p/x.md" "$QUOTE_DESC"); FIELD=AGENT_DESCRIPTION; WANT="$QUOTE_DESC" ;;
  esac
  GOT=$(printf '%s' "$J" | prod_fixed | consume "$FIELD")
  if [ "$GOT" = "$WANT" ]; then pass "$case_name survives eval byte-identically"
  else fail "$case_name MANGLED: got [$GOT] want [$WANT]"; fi
done

echo "── B. CONTROL: the PRE-FIX producer must FAIL those same cases ──"
ctl_broken=0
for case_name in windows space quotes; do
  case "$case_name" in
    windows) J=$(mk_json "$WIN_CWD" "$WIN_FP" "d");   FIELD=FILE_PATH;        WANT="$WIN_FP" ;;
    space)   J=$(mk_json "/p" "$SPACE_FP" "d");        FIELD=FILE_PATH;        WANT="$SPACE_FP" ;;
    quotes)  J=$(mk_json "/p" "/p/x.md" "$QUOTE_DESC"); FIELD=AGENT_DESCRIPTION; WANT="$QUOTE_DESC" ;;
  esac
  GOT=$(printf '%s' "$J" | prod_prefix | consume "$FIELD")
  [ "$GOT" != "$WANT" ] && ctl_broken=$((ctl_broken + 1))
done
if [ "$ctl_broken" -eq 3 ]; then pass "control: pre-fix producer corrupts all 3 (defect reproduced; A is not vacuous)"
else fail "control: pre-fix producer corrupted only $ctl_broken/3 — A no longer pins a real defect"; fi

echo "── C. a \$(…) in a path is NOT executed ──"
rm -f "$TMP/PWNED"
printf '%s' "$(mk_json "/p" "$SUBST_FP" "d")" | prod_fixed | consume FILE_PATH >/dev/null
if [ ! -e "$TMP/PWNED" ]; then pass "fixed producer: command substitution inert"
else fail "fixed producer EXECUTED the substitution"; fi
# control — prove the sentinel actually fires, so the check above is meaningful
rm -f "$TMP/PWNED"
printf '%s' "$(mk_json "/p" "$SUBST_FP" "d")" | prod_prefix | consume FILE_PATH >/dev/null
if [ -e "$TMP/PWNED" ]; then pass "control: pre-fix producer DID execute it (sentinel live)"
else fail "control: sentinel never fires — C is vacuous"; fi

echo "── D. every hook's real producer is quoted (no bare KEY= left) ──"
for h in pre-tool-use post-tool-use stop; do
  f="$HOOKS/$h"
  [ -f "$f" ] || { fail "$h missing"; continue; }
  # A bare `print(f"KEY={...}")` / `print("KEY=%s" % ...)` inside the parse block is
  # the exact defect. shlex-quoted emission never matches these.
  bare=$(grep -cE 'print\((f"[A-Z_]+=\{|"[A-Z_]+=%s")' "$f" 2>/dev/null || true)
  if [ "${bare:-0}" -eq 0 ]; then pass "$h: no unquoted KEY= emission"
  else fail "$h: $bare unquoted KEY= emission(s) remain"; fi
  grep -q 'import shlex\|,shlex' "$f" || fail "$h: shlex not imported"
done

echo "── E. eval'd CWD and the raw-JSON short-circuit agree on a Windows payload ──"
# Both must resolve to the same project root. Before the fix they could not
# diverge only because the eval'd one was garbage; now that both work, a
# disagreement would silently split the hook's notion of "the project".
P="$TMP/proj"; mkdir -p "$P/.mega-sdd/vaults"
J=$(mk_json "$P" "$P/.mega-sdd/vaults/v1/units/U-001.md" "d")
BOTH=$(printf '%s' "$J" | bash -c '
set -uo pipefail
. "'"$ROOT"'/plugins/mega-sdd/scripts/_lib/resolve-project-root.sh"
STDIN_JSON=$(cat)
P=$(printf "%s" "$STDIN_JSON" | '"$PY"' -c "
import json, shlex, sys
d = json.loads(sys.stdin.read())
print(\"CWD=\" + shlex.quote(str(d.get(\"cwd\", \"\"))))
")
eval "$P"
# the post-tool-use short-circuit path: raw JSON, parameter expansion only
_sc="${STDIN_JSON#*\"cwd\"}"; _sc="${_sc#*\"}"; SC_CWD="${_sc%%\"*}"
printf "%s|%s" "$(resolve_project_root "$CWD")" "$(resolve_project_root "$SC_CWD")"
')
A="${BOTH%%|*}"; B="${BOTH##*|}"
if [ -n "$A" ] && [ "$A" = "$B" ]; then pass "PROJECT_ROOT == SC_ROOT ([$A])"
else fail "roots DIVERGED: eval-path=[$A] shortcircuit-path=[$B]"; fi

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
