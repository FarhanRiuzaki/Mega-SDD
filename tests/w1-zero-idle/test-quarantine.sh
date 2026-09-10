#!/usr/bin/env bash
# v8 P1.e part 2 (spec 2026-09-10 App. F6c/d): write-unit-quarantine.sh + status
# quarantined via compute-unit-staleness.sh + execute-bolts 3.10 + one-screen halt
# section + --lite flag registered at the front door.
# Run: bash tests/w1-zero-idle/test-quarantine.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/bolts/U-001" "$V/units" "$T/src"
( cd "$T" && git init -q . && printf 'a\n' > src/a.ts && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
H="$(cd "$T" && shasum -a 256 src/a.ts | cut -c1-64)"
printf -- '---\nunit: U-001\nstatus: completed\ntarget_hashes:\n  src/a.ts: %s\n---\n# r\n' "$H" > "$V/bolts/U-001/bolt-report.md"
printf 'halt:\n  type: acceptance_red\n  unit: U-002\n' > "$T/halt.yaml"

OUT="$(bash "$S/write-unit-quarantine.sh" --cwd="$T" --vault="$V" --unit=U-002 --halt=acceptance_red --reason="acceptance red after 3 retries" --envelope="$T/halt.yaml" --dependents=U-003,U-004 2>&1)"; RC=$?
[ $RC -eq 0 ] && python3 -c "
import json,sys;d=json.load(open('$V/bolts/U-002/quarantine.json'))
assert d['schema']=='unit-quarantine/1' and d['halt_type']=='acceptance_red' and d['dependents_skipped']==['U-003','U-004'] and 'acceptance_red' in d['envelope']
q=d['question']; assert 'dikarantina' in q['text'] and 'acceptance_red' in q['text'] and q['source'].startswith('bolts/U-002/') and [o['id'] for o in q['options']]==['RETRY','MANUAL','DROP'] and all(o['keterangan'] for o in q['options'])" \
  && pass "a: quarantine.json written with halt, reason, dependents, envelope, the ONE question WITH keterangan (text + source + per-option, Indonesian)" || fail "a: quarantine write wrong (rc=$RC: $OUT)"
bash "$S/write-unit-quarantine.sh" --cwd="$T" --vault="$V" --unit=U-005 --halt=x >/dev/null 2>&1; [ $? -eq 2 ] && pass "a2: missing --reason → exit 2" || fail "a2: usage exit wrong"

OUT="$(cd "$T" && bash "$S/compute-unit-staleness.sh" --project="$T" --vault="$V" 2>/dev/null)"; RC=$?
python3 - "$OUT" <<'EOF' && pass "b: staleness — U-001 implemented (hash match), U-002 quarantined (no bolt-report yet) with halt + dependents" || fail "b: staleness statuses wrong ($OUT)"
import json, sys
d = json.loads(sys.argv[1]); by = {u["unit"]: u for u in d["units"]}
assert by["U-001"]["status"] == "implemented", by["U-001"]
assert by["U-002"]["status"] == "quarantined" and by["U-002"]["halt_type"] == "acceptance_red" and by["U-002"]["dependents_skipped"] == ["U-003", "U-004"], by["U-002"]
assert d["counts"].get("quarantined") == 1
EOF
# c: quarantine outranks a bolt-report (halt after a commit)
cp "$V/bolts/U-001/bolt-report.md" "$V/bolts/U-002/bolt-report.md"
OUT="$(cd "$T" && bash "$S/compute-unit-staleness.sh" --project="$T" --vault="$V" 2>/dev/null)"
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert {u['unit']:u['status'] for u in d['units']}['U-002']=='quarantined'" && pass "c: quarantine outranks implemented/stale for a unit that also has a bolt-report" || fail "c: precedence wrong"
# d: release
bash "$S/write-unit-quarantine.sh" --cwd="$T" --vault="$V" --unit=U-002 --release --by=user >/dev/null 2>&1 && [ ! -f "$V/bolts/U-002/quarantine.json" ] && ls "$V/bolts/U-002/" | grep -q 'quarantine.released' \
  && pass "d: --release --by=user removes the record and keeps a stamped trace" || fail "d: release failed"
# e: prose wiring
grep -q '3.10. \*\*Quarantine instead of parking' "$P/skills/execute-bolts/SKILL.md" && grep -q 'Karantina' "$P/skills/execute-bolts/SKILL.md" \
  && pass "e1: execute-bolts 3.10 routes DEFER-class halts to quarantine + _summary Karantina table" || fail "e1: 3.10 missing"
grep -q '^## One-screen halt' "$P/skills/execute-bolts/references/propose-and-confirm-prompt.md" && pass "e2: one-screen halt contract present (apa berhenti · satu pertanyaan · opsi)" || fail "e2: template section missing"
grep -q '^- `--lite`' "$P/commands/mega-sdd.md" && pass "e3: --lite registered at the front door as opt-in" || fail "e3: --lite flag missing"
grep -q 'quarantine.json' "$S/compute-unit-staleness.sh" && pass "e4: staleness reader names the quarantine file" || fail "e4: reader missing"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
