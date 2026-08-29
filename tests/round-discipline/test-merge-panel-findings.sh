#!/usr/bin/env bash
# merge-panel-findings.sh — the ledger writer (spec 2026-08-29 Fase 1).
#
# The defect being closed, measured: on HOST-AS400 U-001 the completed panel
# returned 2 critical + 7 important + 4 minor and ALL THIRTEEN were stamped
# `status: open`, though review-panel.md §Attempt rounds says Important/Minor
# enter as `advisory` — "recorded, surfaced, never gating". The fix round then
# carried 13 findings instead of 2. The mapping was prose; prose enforces
# nothing. This script is the mechanism, and section A is its proof.
set -u
err=0
ok()  { echo "  ok: $*"; }
bad() { echo "  FAIL: $*"; err=1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SH="$ROOT/plugins/mega-sdd/scripts/merge-panel-findings.sh"
[ -f "$SH" ] || { echo "FATAL: $SH missing"; exit 1; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/vault" "$WORK/in"
J="$WORK/vault/bolts/U-001/findings.json"

q() { python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
print(eval(sys.argv[2], {'d': d, 'F': d['findings']}))
" "$J" "$2"; }

echo "── A: the severity→status mapping (the whole point) ──"
cat > "$WORK/in/security.txt" <<'EOF'
FINDINGS:
critical | packages/contract/openapi.yaml:412 | Host authorization rejection has no response shape | B-004 unmapped
important | packages/contract/openapi.yaml:900 | Error envelope omits field binding | A-002
minor | packages/contract/openapi.yaml:33 | Description wording inconsistent | nit
SUMMARY: one blocking gap.
EOF
cat > "$WORK/in/quality.txt" <<'EOF'
FINDINGS:
critical | apps/api/test/contract/openapi-coverage.test.ts:12 | Hard rules C-001 and C-005 have zero automated checks | semantic gate
important | packages/contract/openapi.yaml:1721 | nextCursor camelCase among snake_case keys | 36/37
minor | packages/contract/README.md:8 | Heading level skips | nit
EOF
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=abc1234 --round=1 --spec-verdict=pass \
  --lens=security:"$WORK/in/security.txt" --lens=quality:"$WORK/in/quality.txt" >"$WORK/out1.json" 2>"$WORK/err1"
[ -s "$J" ] || { echo "FATAL: ledger not written"; cat "$WORK/err1"; exit 1; }
[ "$(q x 'len([f for f in F if f["status"]=="open"])')" = "2" ] && ok "A1 both Criticals are open" || bad "A1 open count != 2"
[ "$(q x 'len([f for f in F if f["status"]=="advisory"])')" = "4" ] && ok "A2 Important+Minor are advisory" || bad "A2 advisory count != 4"
[ "$(q x 'sorted({f["status"] for f in F if f["severity"] in ("Important","Minor")})')" = "['advisory']" ] \
  && ok "A3 no Important/Minor is ever open" || bad "A3 an Important/Minor was stamped open — the field defect"
[ "$(python3 -c "import json;print(json.load(open('$WORK/out1.json'))['gate'])")" = "re-dispatch" ] \
  && ok "A4 gate verdict = re-dispatch (Criticals present)" || bad "A4 wrong gate verdict"

echo "── B: evidence-or-drop ──"
rm -rf "$WORK/vault/bolts"; mkdir -p "$WORK/vault"
cat > "$WORK/in/nolines.txt" <<'EOF'
FINDINGS:
critical | packages/contract/openapi.yaml | Anchorless claim | no line number
critical | | Totally anchorless | nothing
important | src/a.ts:9 | Real one | has an anchor
EOF
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=abc1234 --round=1 \
  --lens=security:"$WORK/in/nolines.txt" >"$WORK/out2.json" 2>/dev/null
[ "$(q x 'len(F)')" = "1" ] && ok "B1 anchorless rows dropped" || bad "B1 an anchorless finding survived"
[ "$(python3 -c "import json;print(json.load(open('$WORK/out2.json'))['dropped_no_evidence'])")" = "2" ] \
  && ok "B2 dropped count reported" || bad "B2 dropped count wrong"
[ "$(python3 -c "import json;print(json.load(open('$WORK/out2.json'))['gate'])")" = "clear" ] \
  && ok "B3 dropped Criticals do not gate (they are not findings)" || bad "B3 a dropped row still gated"

echo "── C: dedup across lenses + consensus + max severity ──"
rm -rf "$WORK/vault/bolts"; mkdir -p "$WORK/vault"
cat > "$WORK/in/l1.txt" <<'EOF'
FINDINGS:
minor | src/pay.ts:40 | Fails open on missing income | seen by one
EOF
cat > "$WORK/in/l2.txt" <<'EOF'
FINDINGS:
critical | src/pay.ts:42 | Fails open on missing income | seen by two
EOF
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=abc1234 --round=1 \
  --lens=security:"$WORK/in/l2.txt" --lens=quality:"$WORK/in/l1.txt" >/dev/null 2>&1
[ "$(q x 'len(F)')" = "1" ] && ok "C1 same issue within 3 lines merged to one entry" || bad "C1 dedup failed (got $(q x 'len(F)'))"
[ "$(q x 'F[0]["severity"]')" = "Critical" ] && ok "C2 kept the MAX severity" || bad "C2 severity not maximised"
[ "$(q x 'F[0]["confidence"]')" = "high" ] && ok "C3 two reporters → confidence high" || bad "C3 consensus not marked"
[ "$(q x 'sorted(F[0]["lenses"])')" = "['quality', 'security']" ] && ok "C4 every reporting lens recorded" || bad "C4 lenses[] incomplete"

echo "── D: spec-fail gates its own findings ──"
rm -rf "$WORK/vault/bolts"; mkdir -p "$WORK/vault"
cat > "$WORK/in/spec.txt" <<'EOF'
FINDINGS:
important | src/a.ts:5 | Step 7 not implemented | requirement missing
VERDICT: fail
EOF
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=abc1234 --round=1 --spec-verdict=fail \
  --lens=spec:"$WORK/in/spec.txt" >"$WORK/out4.json" 2>/dev/null
[ "$(q x 'F[0]["status"]')" = "open" ] \
  && ok "D1 an Important behind a spec-FAIL is open (the documented exception)" \
  || bad "D1 spec-fail finding not gating"
[ "$(python3 -c "import json;print(json.load(open('$WORK/out4.json'))['gate'])")" = "re-dispatch" ] \
  && ok "D2 spec-fail forces re-dispatch even with no Critical" || bad "D2 spec-fail did not gate"

echo "── E: id stability + evidence-gated resolution ──"
rm -rf "$WORK/vault/bolts"; mkdir -p "$WORK/vault"
cat > "$WORK/in/r1.txt" <<'EOF'
FINDINGS:
critical | src/pay.ts:42 | Fails open on missing income | round one
important | src/pay.ts:99 | Naming drift | round one
EOF
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=aaa1111 --round=1 --spec-verdict=pass \
  --lens=security:"$WORK/in/r1.txt" >/dev/null 2>&1
ID1=$(q x 'F[0]["id"]')
cat > "$WORK/in/v1.txt" <<'EOF'
RESOLUTIONS:
F-1 | src/pay.ts:44 | resolved | guard added
NEW-FINDINGS:
minor | src/pay.ts:70 | Comment stale | delta review
EOF
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=bbb2222 --round=2 \
  --spec-verdict=pass --verifier="$WORK/in/v1.txt" >"$WORK/out5.json" 2>/dev/null
[ "$(q x 'F[0]["id"]')" = "$ID1" ] && ok "E1 ids stable across rounds" || bad "E1 id renumbered between rounds"
[ "$(q x 'F[0]["status"]')" = "resolved" ] && ok "E2 evidence-backed resolution closes the finding" || bad "E2 resolution not applied"
[ "$(q x 'F[0]["resolution"]["evidence"]')" = "src/pay.ts:44" ] && ok "E3 resolution records new-head evidence" || bad "E3 evidence not recorded"
[ "$(q x 'len(F)')" = "3" ] && ok "E4 verifier NEW-FINDINGS appended, not replacing" || bad "E4 ledger lost or duplicated entries"
[ "$(python3 -c "import json;print(json.load(open('$WORK/out5.json'))['gate'])")" = "clear" ] \
  && ok "E5 round closes when the only Critical is resolved" || bad "E5 round did not close"

echo "── F: a resolution WITHOUT evidence does not close ──"
rm -rf "$WORK/vault/bolts"; mkdir -p "$WORK/vault"
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=aaa1111 --round=1 --spec-verdict=pass \
  --lens=security:"$WORK/in/r1.txt" >/dev/null 2>&1
cat > "$WORK/in/v2.txt" <<'EOF'
RESOLUTIONS:
F-1 | trust me | resolved | no anchor
EOF
bash "$SH" --vault="$WORK/vault" --unit=U-001 --head=bbb2222 --round=2 \
  --spec-verdict=pass --verifier="$WORK/in/v2.txt" >"$WORK/out6.json" 2>/dev/null
[ "$(q x 'F[0]["status"]')" = "open" ] \
  && ok "F1 unevidenced 'resolved' claim leaves the finding open" \
  || bad "F1 a finding closed on an unevidenced claim — evidence-gated resolution broken"
[ "$(python3 -c "import json;print(json.load(open('$WORK/out6.json'))['gate'])")" = "re-dispatch" ] \
  && ok "F2 gate still demands another round" || bad "F2 gate cleared without evidence"

echo "── G: schema is the documented one ──"
python3 -c "
import json,sys
d=json.load(open('$J'))
for k in ('schema','unit','attempt','findings'):
    assert k in d, 'missing top-level key: '+k
assert d['schema']==1
for f in d['findings']:
    for k in ('id','lens','severity','file','line','title','detail','status','resolution'):
        assert k in f, 'finding missing key: '+k
print('  ok: G1 ledger matches review-panel.md schema (schema/unit/attempt/findings + per-finding keys)')
" || err=1

echo "── H: wired — an unused writer changes nothing ──"
RP="$ROOT/plugins/mega-sdd/skills/execute-bolts/references/review-panel.md"
EB="$ROOT/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
grep -q 'merge-panel-findings.sh' "$RP" && ok "H1 review-panel names the writer" || bad "H1 review-panel does not route to the script"
grep -q 'merge-panel-findings.sh' "$EB" && ok "H2 SKILL step 4 names the writer" || bad "H2 per-unit flow does not name the script"
grep -qi 'Do not hand-write this file' "$RP" && ok "H3 hand-writing the ledger forbidden" || bad "H3 nothing forbids hand-writing the ledger"
grep -qi 'controller-written (Write tool)' "$RP" \
  && bad "H4 REGRESSION: review-panel is back to controller-written ledger prose" \
  || ok "H4 controller-written ledger prose is gone"
bash -n "$SH" && ok "H5 writer shell syntax ok" || bad "H5 writer syntax error"

echo "──────────────────────────────"
[ $err -eq 0 ] && echo "round-discipline: ALL PASS" || echo "round-discipline: FAILED"
exit $err
