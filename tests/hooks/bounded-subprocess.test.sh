#!/usr/bin/env bash
# bounded-subprocess.test.sh
#
# One invariant: **no `subprocess.run` in a hook-reachable library may be
# unbounded.**
#
# Why this is a moat concern and not a tidiness one. `scripts/_lib/` is imported by
# the validators that hooks invoke, and `postflight_rules.py` in particular is
# RECOMPUTED at the execute-bolts gate — inside the BLOCKING PreToolUse hook. Its
# `ast-grep scan` is repo-wide. An unbounded child process there is the same failure
# shape as the 2026-07-28 Windows hang that started this whole line of work: work
# with no ceiling in a path Claude Code waits on. The 2026-07-30 install-deps
# regression was the same mistake in a different file — exec probes shipped with no
# timeout, which stalled an audit on a corporate laptop.
#
# The repo already had the right pattern (`state_probes.py` used `timeout=`); it
# simply was not applied consistently, which is exactly the kind of drift a
# mechanical check catches and prose does not.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/../../plugins/mega-sdd/scripts/_lib"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

echo "── every subprocess.run in scripts/_lib must carry timeout= ──"
"$PY" - "$LIB" <<'PYEOF'
import ast, glob, os, sys

lib = sys.argv[1]
unbounded = []
total = 0
for path in sorted(glob.glob(os.path.join(lib, "*.py"))):
    tree = ast.parse(open(path, encoding="utf-8").read(), filename=path)
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        # match subprocess.run / subprocess.Popen / subprocess.check_output
        if not (isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name)
                and f.value.id == "subprocess"
                and f.attr in ("run", "Popen", "check_output", "call", "check_call")):
            continue
        total += 1
        if not any(k.arg == "timeout" for k in node.keywords):
            unbounded.append("%s:%d  subprocess.%s(...)" % (os.path.basename(path), node.lineno, f.attr))

print("  inspected %d subprocess call(s) across scripts/_lib/" % total)
if total == 0:
    print("  NOTHING INSPECTED — the AST matcher found no calls; this check is vacuous.")
    sys.exit(2)
if unbounded:
    for u in unbounded:
        print("  UNBOUNDED: %s" % u)
    sys.exit(1)
sys.exit(0)
PYEOF
st=$?
case "$st" in
  0) pass "all subprocess calls in scripts/_lib are bounded" ;;
  2) fail "matcher found zero calls — the check is vacuous, not green" ;;
  *) fail "unbounded subprocess call(s) in a hook-reachable library" ;;
esac

echo "── CONTROL: the matcher actually catches an unbounded call ──"
# Without this, a broken matcher would report green forever.
mkdir -p "$TMP/lib"
cat > "$TMP/lib/fake_mod.py" <<'PYEOF'
import subprocess
def bounded(cwd):
    return subprocess.run(["git", "status"], capture_output=True, timeout=5)
def unbounded(cwd):
    return subprocess.run(["ast-grep", "scan", cwd], capture_output=True)
PYEOF
out=$("$PY" - "$TMP/lib" <<'PYEOF'
import ast, glob, os, sys
lib = sys.argv[1]
bad = []
for path in sorted(glob.glob(os.path.join(lib, "*.py"))):
    tree = ast.parse(open(path, encoding="utf-8").read(), filename=path)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) \
           and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess" \
           and node.func.attr in ("run", "Popen", "check_output", "call", "check_call") \
           and not any(k.arg == "timeout" for k in node.keywords):
            bad.append("%s:%d" % (os.path.basename(path), node.lineno))
print(len(bad))
PYEOF
)
if [ "$out" = "1" ]; then
  pass "control: matcher flags exactly the 1 unbounded call and ignores the bounded one"
else
  fail "control: matcher reported $out unbounded (want 1) — the green above is not trustworthy"
fi

echo "── the gate-path timeout fails CLOSED, never open ──"
# A Hard-rule check that did not finish has not been shown to hold. If a timeout
# were treated as `pass`, running out of time would launder a violation past a
# blocking gate.
PF="$LIB/postflight_rules.py"
if grep -q 'TimeoutExpired' "$PF"; then
  blk=$(grep -A6 'except subprocess.TimeoutExpired' "$PF" | head -8)
  if printf '%s' "$blk" | grep -q '"verdict": "fail"'; then
    pass "ast-grep timeout yields verdict=fail (fail-closed)"
  else
    fail "ast-grep timeout does not yield verdict=fail — a timeout could pass the gate"
  fi
else
  fail "postflight_rules.py does not handle TimeoutExpired at all"
fi

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
