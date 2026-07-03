#!/usr/bin/env bash
# test-6b-validator-correctness.sh — god-review stage 6, Batch 6B.
#   EB-GATE-2  commit identity: canonical feat(U-X): scope, Unit: trailer, legacy (bolt): —
#              all three activate the gates (the doc-format commit was previously invisible).
#   EB-VAL-1   symbolic head_sha ("HEAD") rejected; pinned 40-hex covers; stale detected.
#   EB-VAL-2   legacy *-bound layout: B1 obligation detected; legacy _batch-suite.json clears B2.
#   EB-VAL-3   factory-ledger: string attempt → FAIL CLOSED (phase_stuck), no crash-open;
#              no .mega-sdd → SKIP without minting a phantom root.
#   EB-VAL-5   monorepo: sibling project's bolt commits never activate THIS project's gates;
#              a state-only commit does not invalidate a pinned green suite.
#   EB-VAL-8   HTML-comment-only ## Hard rules → NO B1 obligation.
#   EB-GATE-8  retroactive unit edit cannot erase a recorded B1 obligation (git show).
#   PARITY     vault_layouts.unit_files ≡ validate-unit-spec discover_units on a
#              multi-layout fixture (the shared-helper no-drift pin).
# Run: bash tests/god-review-s6/test-6b-validator-correctness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VBA="${ROOT}/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
VFL="${ROOT}/plugins/mega-sdd/scripts/validate-factory-ledger.sh"
VUS="${ROOT}/plugins/mega-sdd/scripts/validate-unit-spec.sh"
LIB="${ROOT}/plugins/mega-sdd/scripts/_lib"
for f in "$VBA" "$VFL" "$VUS" "$LIB/vault_layouts.py"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t val6b)"
trap 'rm -rf "$WORK"' EXIT

jget() { python3 -c "import json,sys; d=json.load(open('$1')); print(d$2)"; }
gitc() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }

echo "── EB-GATE-2: commit identity ──"
F="$WORK/id"; mkdir -p "$F/.mega-sdd/vaults/a/units" "$F/.mega-sdd/vaults/a/bolts"
git init -q "$F"
printf -- '---\nunit_id: U-001\ntask_type: create\n---\n## Hard rules\n- DO NOT modify x.php\n' > "$F/.mega-sdd/vaults/a/units/U-001.md"
printf -- '---\nunit_id: U-002\ntask_type: create\n---\n## Hard rules\n- DO NOT modify y.php\n' > "$F/.mega-sdd/vaults/a/units/U-002.md"
printf -- '---\nunit_id: U-003\ntask_type: create\n---\n## Hard rules\n- DO NOT modify z.php\n' > "$F/.mega-sdd/vaults/a/units/U-003.md"
echo a > "$F/a.php"; gitc "$F" add -A >/dev/null; gitc "$F" commit -q -m "feat(U-001): canonical scope"
echo b > "$F/b.php"; gitc "$F" add -A >/dev/null; gitc "$F" commit -q -m "chore: something" -m "Unit: U-002"
echo c > "$F/c.php"; gitc "$F" add -A >/dev/null; gitc "$F" commit -q -m "add stuff (bolt): U-003"
bash "$VBA" --cwd="$F" --postflight-scan --quiet || true
SEEN=$(jget "$F/.mega-sdd/.bolt-postflight-state.json" "['bolt_commits_seen']")
N=$(jget "$F/.mega-sdd/.bolt-postflight-state.json" "['issues_count']")
[ "$SEEN" = "3" ] && [ "$N" = "3" ] && ok "all 3 identity channels recognized (scope, trailer, legacy) — 3 B1 obligations" \
  || fail "identity channels: seen=$SEEN issues=$N (want 3/3)"

echo "── EB-VAL-1: head_sha discipline ──"
printf '{"status":"green","head_sha":"HEAD"}' > "$F/.mega-sdd/vaults/a/bolts/_batch-suite.json"
bash "$VBA" --cwd="$F" --batch-suite-gate --quiet || true
ST=$(jget "$F/.mega-sdd/.batch-suite-gate-state.json" "['status']")
[ "$ST" = "FAIL" ] && ok "symbolic head_sha rejected (FAIL)" || fail "symbolic head_sha accepted"
SHA=$(git -C "$F" rev-parse HEAD)
printf '{"status":"green","head_sha":"%s"}' "$SHA" > "$F/.mega-sdd/vaults/a/bolts/_batch-suite.json"
bash "$VBA" --cwd="$F" --batch-suite-gate --quiet || true
ST=$(jget "$F/.mega-sdd/.batch-suite-gate-state.json" "['status']")
[ "$ST" = "PASS" ] && ok "pinned 40-hex sha covers (PASS)" || fail "pinned sha did not cover"
echo d > "$F/d.php"; gitc "$F" add -A >/dev/null; gitc "$F" commit -q -m "hotfix out of band"
bash "$VBA" --cwd="$F" --batch-suite-gate --quiet || true
ST=$(jget "$F/.mega-sdd/.batch-suite-gate-state.json" "['status']")
OOB=$(jget "$F/.mega-sdd/.batch-suite-gate-state.json" ".get('out_of_band')")
[ "$ST" = "FAIL" ] && [ "$OOB" = "True" ] && ok "out-of-band code commit trips staleness" || fail "stale/out-of-band not detected ($ST/$OOB)"

echo "── EB-VAL-2: legacy *-bound layout ──"
L="$WORK/legacy"; mkdir -p "$L/.mega-sdd" "$L/app-bound/units" "$L/app-bound/bolts"
git init -q "$L"
printf -- '---\nunit_id: U-009\ntask_type: create\n---\n## Hard rules\n- DO NOT modify q.php\n' > "$L/app-bound/units/U-009.md"
echo code > "$L/m.py"; gitc "$L" add -A >/dev/null; gitc "$L" commit -q -m "feat(U-009): legacy bolt"
bash "$VBA" --cwd="$L" --postflight-scan --quiet || true
ST=$(jget "$L/.mega-sdd/.bolt-postflight-state.json" "['status']")
[ "$ST" = "FAIL" ] && ok "legacy-layout unit's B1 obligation detected" || fail "legacy layout invisible to B1"
LSHA=$(git -C "$L" rev-parse HEAD)
printf '{"status":"green","head_sha":"%s"}' "$LSHA" > "$L/app-bound/bolts/_batch-suite.json"
bash "$VBA" --cwd="$L" --batch-suite-gate --quiet || true
ST=$(jget "$L/.mega-sdd/.batch-suite-gate-state.json" "['status']")
[ "$ST" = "PASS" ] && ok "legacy-path _batch-suite.json clears B2" || fail "legacy _batch-suite.json ignored (unclearable FAIL)"

echo "── EB-VAL-3: factory-ledger fail-closed ──"
FL="$WORK/fl"; mkdir -p "$FL/.mega-sdd"
printf '[{"phase":"units","attempt":"1","status":"unresolved","emitted_at":"x"},{"phase":"units","attempt":"3","status":"unresolved","emitted_at":"x"}]' > "$FL/.mega-sdd/factory-ledger.json"
bash "$VFL" --cwd="$FL" --quiet || true
ST=$(jget "$FL/.mega-sdd/.factory-ledger-state.json" "['status']"); HT=$(jget "$FL/.mega-sdd/.factory-ledger-state.json" "['halt_type']")
[ "$ST" = "FAIL" ] && [ "$HT" = "phase_stuck" ] && ok "string attempt coerced → FAIL CLOSED (phase_stuck)" || fail "string attempt: $ST/$HT"
NR="$WORK/noroot"; mkdir -p "$NR"
bash "$VFL" --cwd="$NR" --quiet; RC=$?
[ "$RC" = "0" ] && [ ! -d "$NR/.mega-sdd" ] && ok "no-root SKIP mints no phantom .mega-sdd/" || fail "phantom root minted or rc=$RC"

echo "── EB-VAL-5: monorepo scoping ──"
M="$WORK/mono"; mkdir -p "$M/proj/.mega-sdd/vaults/a/units" "$M/proj/.mega-sdd/vaults/a/bolts" "$M/sibling"
git init -q "$M"
printf -- '---\nunit_id: U-777\ntask_type: create\n---\n## Hard rules\n- DO NOT modify w.php\n' > "$M/proj/.mega-sdd/vaults/a/units/U-777.md"
echo s > "$M/sibling/code.go"; gitc "$M" add -A >/dev/null
gitc "$M" commit -q -m "feat(U-999): SIBLING project's bolt"   # touches sibling + proj unit files
# sibling-only bolt commit (touches nothing under proj/):
echo s2 > "$M/sibling/more.go"; gitc "$M" add sibling >/dev/null; gitc "$M" commit -q -m "feat(U-888): sibling only"
bash "$VBA" --cwd="$M/proj" --orphan-scan --quiet || true
python3 - "$M/proj/.mega-sdd/.bolt-orphans-state.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
units = {i["unit_id"] for i in d["issues"]}
assert "U-888" not in units, "sibling-only bolt activated this project's gate: %s" % units
print("  ✓ sibling-only bolt commit invisible to this project (prefix pathspec)")
PYEOF
[ $? -eq 0 ] || fail "monorepo prefix scoping"
# state-only commit must not invalidate a pinned green suite
MSHA=$(git -C "$M" rev-parse HEAD)
printf '{"status":"green","head_sha":"%s"}' "$MSHA" > "$M/proj/.mega-sdd/vaults/a/bolts/_batch-suite.json"
gitc "$M" add proj/.mega-sdd >/dev/null; gitc "$M" commit -q -m "chore: record suite state"
bash "$VBA" --cwd="$M/proj" --batch-suite-gate --quiet || true
ST=$(jget "$M/proj/.mega-sdd/.batch-suite-gate-state.json" "['status']")
[ "$ST" = "PASS" ] && ok "state-only commit does not invalidate the pinned green suite" || fail "false B2 FAIL on state-only commit"

echo "── EB-VAL-8 + EB-GATE-8 ──"
H="$WORK/h8"; mkdir -p "$H/.mega-sdd/vaults/a/units" ; git init -q "$H"
printf -- '---\nunit_id: U-100\ntask_type: create\n---\n## Hard rules\n<!-- placeholder: add rules here -->\n' > "$H/.mega-sdd/vaults/a/units/U-100.md"
echo x > "$H/x.rb"; gitc "$H" add -A >/dev/null; gitc "$H" commit -q -m "feat(U-100): no real rules"
bash "$VBA" --cwd="$H" --postflight-scan --quiet || true
ST=$(jget "$H/.mega-sdd/.bolt-postflight-state.json" "['status']")
[ "$ST" = "PASS" ] && ok "HTML-comment-only Hard rules → no B1 obligation" || fail "comment counted as a rule (false B1 FAIL)"
# retro-edit stickiness: real rule at commit, blanked afterwards
printf -- '---\nunit_id: U-100\ntask_type: create\n---\n## Hard rules\n- DO NOT modify x.rb\n' > "$H/.mega-sdd/vaults/a/units/U-100.md"
gitc "$H" add -A >/dev/null; gitc "$H" commit -q -m "feat(U-100): with a rule now"
printf -- '---\nunit_id: U-100\ntask_type: verify\n---\n## Hard rules\nNone.\n' > "$H/.mega-sdd/vaults/a/units/U-100.md"
bash "$VBA" --cwd="$H" --postflight-scan --quiet || true
ST=$(jget "$H/.mega-sdd/.bolt-postflight-state.json" "['status']")
[ "$ST" = "FAIL" ] && ok "retro-edit (blank rules + flip to verify) cannot erase the obligation" || fail "retroactive unit edit erased B1"

echo "── PARITY: vault_layouts ≡ discover_units ──"
PARITY="$WORK/parity"; mkdir -p "$PARITY"
python3 - "$ROOT" "$PARITY" <<'PYEOF'
import os, subprocess, sys
root, fix = sys.argv[1], os.path.realpath(sys.argv[2])
layouts = [
    ".mega-sdd/vaults/v1/units/U-001.md",
    ".mega-sdd/vaults/v1/units/U-002/unit.md",
    "docs/mega-sdd/vaults/v2/units/U-003.md",
    "app-bound/units/U-004.md",
    "sub/x-bound/units/U-005/unit.md",
    "docs/mega-sdd/vaults/y-bound/units/U-006.md",
]
for rel in layouts:
    p = os.path.join(fix, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write("---\nunit_id: X\n---\n")
sys.path.insert(0, os.path.join(root, "plugins/mega-sdd/scripts/_lib"))
import vault_layouts
mine = set(vault_layouts.unit_files(fix))
# extract discover_units results by running validate-unit-spec project-wide and reading checked_files
subprocess.run(["bash", os.path.join(root, "plugins/mega-sdd/scripts/validate-unit-spec.sh"),
                "--cwd=" + fix, "--quiet"], capture_output=True)
import json
d = json.load(open(os.path.join(fix, ".mega-sdd", ".unit-spec-state.json")))
theirs = {os.path.realpath(os.path.join(fix, p)) for p in d["checked_files"]}
assert mine == theirs, "DRIFT: helper=%s validator=%s" % (sorted(mine - theirs), sorted(theirs - mine))
assert len(mine) == len(layouts), "coverage gap: %d/%d" % (len(mine), len(layouts))
print("  ✓ vault_layouts.unit_files ≡ discover_units on all %d layouts" % len(layouts))
PYEOF
[ $? -eq 0 ] || fail "layout parity pin"

echo
[ "$FAILED" -eq 0 ] && { echo "test-6b-validator-correctness: ALL PASS"; exit 0; } || { echo "test-6b-validator-correctness: FAILURES"; exit 1; }
