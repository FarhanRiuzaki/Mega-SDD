#!/usr/bin/env bash
# test-6e-fixrev-regressions.sh — TDD pins for the two High fail-open regressions the
# stage-6 fix-review CONFIRMED in validate-bolt-artifacts.sh (both fail open on INNOCENT,
# non-malicious input — a monorepo subproject and a repo with an `io-bound/` code dir).
#
#   EB-FIXREV-1  monorepo pathspec: a bolt committed in a git SUBPROJECT (non-empty
#                `rev-parse --show-prefix`) MUST be detected by the log-walk gates.
#                The buggy `git -C <sub> log -- <root-rel PREFIX>` scoped to <PREFIX>/<PREFIX>
#                and matched nothing → B1/B2/B3/orphan all fail-open (dormant PASS).
#   EB-FIXREV-2  `-bound/` over-exclusion: a bolt whose code lives under a real source dir
#                named `*-bound/` (io-bound, data-bound…) MUST count as code. The blanket
#                `(?:^|/)[^/]+-bound/` regex treated it as a legacy vault artifact → B2
#                dormant + B3 sanctions a scope-escape there.
#
# These assert DESIRED behavior; they FAIL against the buggy tree and PASS after the fix.
# Run: bash tests/god-review-s6/test-6e-fixrev-regressions.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VBA="${ROOT}/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
[ -f "$VBA" ] || { echo "missing $VBA"; exit 1; }

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t gate6e)"
trap 'rm -rf "$WORK"' EXIT
gitc() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
jget() { python3 -c "import json,sys; d=json.load(open('$1')); print(d$2)" 2>/dev/null; }

echo "── EB-FIXREV-1: monorepo subproject bolt IS detected (non-empty prefix) ──"
# repo root = M1 ; substantive subproject = M1/svc (its own .mega-sdd) → resolve keeps
# CWD=svc, so rev-parse --show-prefix = 'svc/'. A bolt commit touches svc/app.py.
M1="$WORK/mono"
mkdir -p "$M1/svc/.mega-sdd/vaults/v1/units" "$M1/svc/.mega-sdd/vaults/v1/bolts"
gitc "$M1" init -q . >/dev/null 2>&1 || git -C "$M1" init -q .
printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n  - path: app.py\n    operation: create\n---\n## Hard rules\n- DO NOT modify locked.py\n' > "$M1/svc/.mega-sdd/vaults/v1/units/U-001.md"
echo "print('app')" > "$M1/svc/app.py"
gitc "$M1" add -A >/dev/null
gitc "$M1" commit -q -m "feat(U-001): add app" -m "Unit: U-001"
# diagnostic: what does the pathspec walk actually see from the subproject?
PREFIX_SEEN=$(cd "$M1/svc" && git rev-parse --show-prefix)
echo "    (diagnostic) show-prefix from svc = '${PREFIX_SEEN}'"
bash "$VBA" --cwd="$M1/svc" --batch-suite-gate --quiet || true
ST=$(jget "$M1/svc/.mega-sdd/.batch-suite-gate-state.json" "['status']")
NB=$(jget "$M1/svc/.mega-sdd/.batch-suite-gate-state.json" ".get('newest_bolt_commit')")
echo "    (diagnostic) batch-suite-gate: status=$ST newest_bolt_commit=$NB"
if [ -n "$NB" ] && [ "$NB" != "None" ] && [ "$NB" != "null" ]; then
  ok "monorepo bolt detected by batch-suite-gate (newest_bolt_commit set)"
else
  fail "monorepo bolt INVISIBLE — batch-suite-gate fail-open (newest_bolt_commit=$NB, status=$ST)"
fi
# orphan-scan must also see the bolt commit (it walks the same log)
bash "$VBA" --cwd="$M1/svc" --orphan-scan --quiet || true
SEEN=$(jget "$M1/svc/.mega-sdd/.bolt-orphans-state.json" ".get('bolt_commits_seen')")
echo "    (diagnostic) orphan-scan: bolt_commits_seen=$SEEN"
if [ -n "$SEEN" ] && [ "$SEEN" != "0" ] && [ "$SEEN" != "None" ]; then
  ok "monorepo bolt commit visible to orphan-scan (bolt_commits_seen=$SEEN)"
else
  fail "monorepo bolt commit INVISIBLE to orphan-scan (bolt_commits_seen=$SEEN) — log-walk fail-open"
fi

echo "── EB-FIXREV-2: code under a real *-bound/ source dir counts as code ──"
# repo at root (empty prefix), bolt's only code lives under src/io-bound/ — a legitimate
# source dir (io-bound), NOT a legacy vault `<vault>-bound/` tree.
B2="$WORK/bound"
mkdir -p "$B2/.mega-sdd/vaults/v1/units" "$B2/.mega-sdd/vaults/v1/bolts" "$B2/src/io-bound"
git -C "$B2" init -q .
printf -- '---\nunit_id: U-002\ntask_type: create\ntarget_files:\n  - path: src/io-bound/worker.py\n    operation: create\n---\n' > "$B2/.mega-sdd/vaults/v1/units/U-002.md"
echo "def work(): pass" > "$B2/src/io-bound/worker.py"
gitc "$B2" add -A >/dev/null
gitc "$B2" commit -q -m "feat(U-002): io worker" -m "Unit: U-002"
bash "$VBA" --cwd="$B2" --batch-suite-gate --quiet || true
ST2=$(jget "$B2/.mega-sdd/.batch-suite-gate-state.json" "['status']")
NB2=$(jget "$B2/.mega-sdd/.batch-suite-gate-state.json" ".get('newest_bolt_commit')")
echo "    (diagnostic) batch-suite-gate: status=$ST2 newest_bolt_commit=$NB2"
if [ -n "$NB2" ] && [ "$NB2" != "None" ] && [ "$NB2" != "null" ]; then
  ok "bolt with code under src/io-bound/ is code-bearing (batch-suite-gate active)"
else
  fail "src/io-bound/ wrongly excluded as vault artifact — B2 fail-open (newest_bolt_commit=$NB2)"
fi
# B3: an escape into a DIFFERENT io-bound path outside target_files must be flagged
echo "def leak(): pass" > "$B2/src/io-bound/leak.py"
gitc "$B2" add src/io-bound/leak.py >/dev/null
gitc "$B2" commit -q -m "feat(U-002): sneak leak" -m "Unit: U-002"
bash "$VBA" --cwd="$B2" --whitelist-scan --quiet || true
WST=$(jget "$B2/.mega-sdd/.bolt-whitelist-state.json" "['status']")
echo "    (diagnostic) whitelist-scan: status=$WST"
# leak.py is NOT in U-002 target_files (only worker.py) and io-bound is not sanctioned →
# a correct B3 flags it. (Pre-fix, io-bound is 'sanctioned' by the -bound regex → PASS.)
if [ "$WST" = "FAIL" ]; then
  ok "B3 flags the scope-escape into src/io-bound/leak.py"
else
  fail "B3 sanctioned a scope-escape under src/io-bound/ (status=$WST) — over-exclusion"
fi

RPF="${ROOT}/plugins/mega-sdd/scripts/run-postflight-scan.sh"
rverdict() { python3 -c "import json,sys;d=json.load(open('$1'));print({r['type']:r['verdict'] for r in d['rules']}.get('$2','MISSING'))"; }
rev() { python3 -c "import json,sys;d=json.load(open('$1'));print([r['evidence'] for r in d['rules'] if r['type']=='$2'][0] if any(r['type']=='$2' for r in d['rules']) else 'MISSING')"; }

echo "── EB-FIXREV-3: SIGNATURE_RULE locates a real function (POSIX [[:space:]], not \\s) ──"
S3="$WORK/sig"; mkdir -p "$S3/.mega-sdd/vaults/a/units" "$S3/src"; git init -q "$S3"
printf -- '---\nunit_id: U-003\ntask_type: create\ntarget_files:\n  - path: src/pay.php\n    operation: create\n---\n## Hard rules\n- function handlePayment MUST preserve signature: function handlePayment($order, $amount)\n' > "$S3/.mega-sdd/vaults/a/units/U-003.md"
printf '<?php\nfunction handlePayment($order, $amount) {\n  return true;\n}\n' > "$S3/src/pay.php"
gitc "$S3" add -A >/dev/null; gitc "$S3" commit -q -m "feat(U-003): pay" -m "Unit: U-003"
bash "$RPF" --cwd="$S3" --unit=U-003 --quiet >/dev/null 2>&1 || true
SART="$S3/.mega-sdd/vaults/a/bolts/U-003/postflight.json"
SIGEV=$(rev "$SART" SIGNATURE_RULE 2>/dev/null)
echo "    (diagnostic) SIGNATURE evidence: $SIGEV"
case "$SIGEV" in
  *"not found in tracked source"*) fail "SIGNATURE_RULE false FAIL — [[:space:]] grep did not locate the function" ;;
  MISSING) fail "SIGNATURE_RULE not evaluated" ;;
  *".mega-sdd/"*|*"U-003.md"*) fail "SIGNATURE_RULE self-matched the unit spec, not real source: $SIGEV" ;;
  *"src/pay.php"*) ok "SIGNATURE_RULE located handlePayment in real source (BSD-grep-safe, spec excluded)" ;;
  *) ok "SIGNATURE_RULE located handlePayment (BSD-grep-safe)" ;;
esac

echo "── EB-FIXREV-4: NAMING_RULE double-extension stem (split first dot) ──"
S4="$WORK/name"; mkdir -p "$S4/.mega-sdd/vaults/a/units" "$S4/app/views"; git init -q "$S4"
printf -- '---\nunit_id: U-004\ntask_type: create\ntarget_files:\n  - path: app/views/user-profile.blade.php\n    operation: create\n---\n## Hard rules\n- app/views/**/*.blade.php MUST follow kebab-case naming\n' > "$S4/.mega-sdd/vaults/a/units/U-004.md"
echo "<x>" > "$S4/app/views/user-profile.blade.php"
gitc "$S4" add -A >/dev/null; gitc "$S4" commit -q -m "feat(U-004): view" -m "Unit: U-004"
bash "$RPF" --cwd="$S4" --unit=U-004 --quiet >/dev/null 2>&1 || true
NART="$S4/.mega-sdd/vaults/a/bolts/U-004/postflight.json"
NV=$(rverdict "$NART" NAMING_RULE 2>/dev/null)
echo "    (diagnostic) NAMING verdict: $NV  ($(rev "$NART" NAMING_RULE 2>/dev/null))"
[ "$NV" = "pass" ] && ok "kebab file user-profile.blade.php passes (stem 'user-profile', not 'user-profile.blade')" \
  || fail "NAMING_RULE false FAIL on a correctly-named double-extension file (verdict=$NV)"

echo "── EB-FIXREV-6: DO_NOT_ADD_DEPS on a ROOT commit is not fail-open ──"
S6="$WORK/deps"; mkdir -p "$S6/.mega-sdd/vaults/a/units"; git init -q "$S6"
printf -- '---\nunit_id: U-006\ntask_type: create\ntarget_files:\n  - path: package.json\n    operation: create\n---\n## Hard rules\n- DO NOT add new package.json dependencies\n' > "$S6/.mega-sdd/vaults/a/units/U-006.md"
printf '{\n  "dependencies": { "left-pad": "1.0.0" }\n}\n' > "$S6/package.json"
# the U-006 bolt IS the root commit (no parent) — the exact fail-open case
gitc "$S6" add -A >/dev/null; gitc "$S6" commit -q -m "feat(U-006): init deps" -m "Unit: U-006"
bash "$RPF" --cwd="$S6" --unit=U-006 --quiet >/dev/null 2>&1 || true
DART="$S6/.mega-sdd/vaults/a/bolts/U-006/postflight.json"
DV=$(rverdict "$DART" DO_NOT_ADD_DEPS 2>/dev/null)
echo "    (diagnostic) DO_NOT_ADD_DEPS verdict: $DV  ($(rev "$DART" DO_NOT_ADD_DEPS 2>/dev/null))"
[ "$DV" = "fail" ] && ok "root-commit manifest adding left-pad is flagged (diff vs empty tree)" \
  || fail "DO_NOT_ADD_DEPS false PASS on a root commit (verdict=$DV) — fail-open"

PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
drive() { HOOK="$PRE" FIX="$1" TOOL="$2" TI="$3" python3 -c '
import json, os, subprocess
p={"cwd":os.environ["FIX"],"tool_name":os.environ["TOOL"],"tool_input":json.loads(os.environ["TI"]),"session_id":"s6e"}
r=subprocess.run(["bash",os.environ["HOOK"]],input=json.dumps(p),capture_output=True,text=True,timeout=180)
print(r.stdout,end="")'; }

echo "── EB-FIXREV-7: evidence-artifact guard is vault-anchored (user bolts/ not false-blocked) ──"
H="$WORK/hookfix"; mkdir -p "$H/.mega-sdd/vaults/app/bolts" "$H/bolts"; git init -q "$H"
OUT=$(drive "$H" "Write" "{\"file_path\":\"$H/.mega-sdd/vaults/app/bolts/_batch-suite.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && ok "mega-sdd vault evidence artifact still denied" || fail "vault evidence artifact NOT denied (guard too loose): $(printf '%s' "$OUT"|head -c120)"
OUT=$(drive "$H" "Write" "{\"file_path\":\"$H/bolts/_batch-suite.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && fail "user's OWN top-level bolts/_batch-suite.json false-blocked (guard not anchored)" || ok "user's own top-level bolts/_batch-suite.json is allowed (anchored to vault)"

echo "── EB-FIXREV-4b: open(os.path.join(...protected...),'w') caught (nested paren) ──"
mkdir -p "$H/.mega-sdd"
OUT=$(drive "$H" "Bash" "{\"command\":\"python3 -c 'import os,json; json.dump({}, open(os.path.join(\\\".mega-sdd\\\", \\\".bolt-postflight-state.json\\\"), \\\"w\\\"))'\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "open(os.path.join(...),'w') on protected state denied" || fail "os.path.join open-for-write slipped the verb net"

echo
[ "$FAILED" -eq 0 ] && { echo "test-6e-fixrev-regressions: ALL PASS"; exit 0; } || { echo "test-6e-fixrev-regressions: FAILURES (expected RED pre-fix)"; exit 1; }
