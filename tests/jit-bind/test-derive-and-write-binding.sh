#!/usr/bin/env bash
# v8 P1.b (spec 2026-09-10 Appendix F2/F3): derive-unit-claims.sh (wave claim set from
# the unit files only) + write-unit-binding.sh (SOLE writer of bolts/U-XXX/binding.json,
# fail-closed verdicts, refusal of CONFIRMED-by-absence, resolve write-back) + the
# evidence-deny regex in hooks/pre-tool-use now naming binding.json at every site.
# Run: bash tests/jit-bind/test-derive-and-write-binding.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/plugins/mega-sdd/scripts"; HOOK="$ROOT/plugins/mega-sdd/hooks/pre-tool-use"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units" "$T/app/Models" "$T/routes"
( cd "$T" && git init -q . && printf '<?php\nclass Nasabah {}\n' > app/Models/Nasabah.php && printf 'x\n' > routes/web.php \
  && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
cat > "$V/units/U-001.md" <<'MD'
---
id: U-001
title: create-only greenfield
task_type: create
vault_source: flows.md#F-U-001
target_files:
  - path: app/Http/NewController.php
    operation: create
acceptance_test:
  - type: test
    command: x
    expects: ""
---
# u
MD
cat > "$V/units/U-002.md" <<'MD'
---
id: U-002
title: brownfield
task_type: extend
vault_source: model.md#nasabah
target_files:
  - path: app/Models/Nasabah.php
    operation: modify
  - path: routes/web.php
    operation: create
existing_interfaces:
  - file: app/Models/Nasabah.php
    symbol: Nasabah
acceptance_test:
  - type: test
    command: x
    expects: ""
---
# u

## Anchors
- app/Models/Nasabah.php:2 — class

## Claims
- C-U002-01 "audit log migration exists" — expect: database/migrations — must-exist
- C-U002-02 "no register page" — expect: app/register.php — must-not-exist
- C-U002-03 "JWT carries a single role" — expect: jwt role claim shape
MD

# ── a: derive — counts by kind; greenfield unit contributes fs claims only ──
OUT="$(bash "$S/derive-unit-claims.sh" --cwd="$T" --vault="$V" --units=U-001,U-002 2>&1)"; RC=$?
W="$(ls -d "$V"/bolts/_wave-*/claims.json 2>/dev/null | head -1)"
python3 - "$OUT" "$W" "$RC" <<'EOF' && pass "a: wave claims.json — 6 fs / 1 symbol / 1 text; U-001 = fs only (0 model tokens); ids + sources stamped" || fail "a: derive output wrong ($OUT)"
import json, sys
out = json.loads(sys.argv[1].strip().splitlines()[-1])["jit_bind"]; w = json.load(open(sys.argv[2])); rc = int(sys.argv[3])
assert rc == 0 and out["units"] == 2 and (out["fs_claims"], out["symbol_claims"], out["text_claims"]) == (6, 1, 1), out
u1 = [c for c in w["claims"] if c["unit"] == "U-001"]
assert len(u1) == 1 and u1[0]["kind"] == "fs_must_not_exist" and u1[0]["expect"] == "app/Http/NewController.php", u1
kinds = {c["id"]: c["kind"] for c in w["claims"] if c["unit"] == "U-002"}
assert kinds["C-U002-01"] == "fs_must_exist" and kinds["C-U002-02"] == "fs_must_not_exist" and kinds["C-U002-03"] == "text", kinds
assert any(c["kind"] == "symbol" and c["expect"] == "app/Models/Nasabah.php:Nasabah" for c in w["claims"]), w["claims"]
assert w["schema"] == "unit-claims/1" and all(":" in c["source"] for c in w["claims"])
EOF
bash "$S/derive-unit-claims.sh" --cwd="$T" --vault="$V" --units=U-404 >/dev/null 2>&1; [ $? -eq 2 ] && pass "a2: unknown unit → exit 2, nothing guessed" || fail "a2: expected exit 2"

# ── b: write — fail-closed verdicts per kind ──
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-001 --claims="$W" >/dev/null 2>&1 || fail "b0: U-001 write failed"
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --claims="$W" >/dev/null 2>&1 || fail "b0: U-002 write failed"
python3 - "$V" <<'EOF' && pass "b: fs present/absent → CONFIRMED/CONFLICT with states; create-over-existing = CONFLICT; symbol w/o index = OQ; text = OQ pending ladder; U-001 all CONFIRMED/NEW" || fail "b: verdicts wrong"
import json, sys, os
V = sys.argv[1]
d2 = json.load(open(os.path.join(V, "bolts/U-002/binding.json"))); by = {c["id"]: c for c in d2["claims"]}
assert d2["schema"] == "unit-binding/1" and d2["unit"] == "U-002" and d2["generated_by"].startswith("write-unit-binding.sh")
assert by["C-U002-01"]["verdict"] == "CONFLICT" and by["C-U002-01"]["state"] == "MISSING"
assert by["C-U002-02"]["verdict"] == "CONFIRMED" and by["C-U002-02"]["state"] == "NEW"
assert by["C-U002-03"]["verdict"] == "OQ" and "ladder" in by["C-U002-03"]["evidence"]
routes = [c for c in d2["claims"] if c["expect"] == "routes/web.php"][0]
assert routes["verdict"] == "CONFLICT" and routes["state"] == "ALREADY_EXISTS"
sym = [c for c in d2["claims"] if c["kind"] == "symbol"][0]; assert sym["verdict"] == "OQ" and "symbol-index" in sym["evidence"]
assert d2["summary"]["CONFLICT"] == 2 and d2["summary"]["OQ"] == 2
d1 = json.load(open(os.path.join(V, "bolts/U-001/binding.json")))
assert d1["summary"] == {"CONFIRMED": 1, "CONFLICT": 0, "OQ": 0}, d1["summary"]
EOF

# ── c: refusals — CONFIRMED text claim without anchor; illegal enum; resolve on non-CONFLICT ──
echo '{"C-U002-03":{"verdict":"CONFIRMED"}}' > "$T/v1.json"
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --claims="$W" --verdicts="$T/v1.json" >/dev/null 2>&1; [ $? -eq 3 ] && pass "c1: CONFIRMED text claim without anchor → REFUSED (exit 3, never CONFIRMED-by-absence)" || fail "c1: refusal missing"
echo '{"C-U002-03":{"verdict":"MAYBE"}}' > "$T/v2.json"
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --claims="$W" --verdicts="$T/v2.json" >/dev/null 2>&1; [ $? -eq 3 ] && pass "c2: verdict outside enum → REFUSED" || fail "c2: enum not enforced"
echo '{"C-U002-03":{"verdict":"CONFIRMED","anchor":"app/Auth/Jwt.php:40","confidence":"high","evidence":"read: single role claim"}}' > "$T/v3.json"
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --claims="$W" --verdicts="$T/v3.json" >/dev/null 2>&1 \
  && python3 -c "import json,sys;d=json.load(open('$V/bolts/U-002/binding.json'));c=[x for x in d['claims'] if x['id']=='C-U002-03'][0];assert c['verdict']=='CONFIRMED' and c['anchor']=='app/Auth/Jwt.php:40'" \
  && pass "c3: anchored model verdict for a text claim is recorded" || fail "c3: anchored verdict not recorded"
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --resolve=C-U002-02=KEEP_CODE --by=user >/dev/null 2>&1; [ $? -eq 3 ] && pass "c4: resolve on a non-CONFLICT claim → REFUSED" || fail "c4: resolve accepted on non-CONFLICT"
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --resolve=C-U002-01=KEEP_VAULT --by=user >/dev/null 2>&1 \
  && python3 -c "import json;d=json.load(open('$V/bolts/U-002/binding.json'));c=[x for x in d['claims'] if x['id']=='C-U002-01'][0];assert c['resolution']['action']=='KEEP_VAULT' and c['resolution']['by']=='user'" \
  && pass "c5: --resolve records {action, by, at} on the CONFLICT claim (resolve-oq write-back path)" || fail "c5: resolution not recorded"

# ── d: mutation — creating the missing migration flips C-U002-01 to CONFIRMED on rewrite ──
mkdir -p "$T/database/migrations"
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --claims="$W" >/dev/null 2>&1
python3 -c "import json;d=json.load(open('$V/bolts/U-002/binding.json'));c=[x for x in d['claims'] if x['id']=='C-U002-01'][0];assert c['verdict']=='CONFIRMED', c" \
  && pass "d: mutation — fs change flips the verdict on recompute (no cached truth)" || fail "d: verdict did not follow the filesystem"

# ── e: hook evidence-deny names binding.json at every site (Bash-tamper ×2, Write/Edit ×2, bash PROTECTED) ──
n=$(grep -c 'review-tier|binding)\\.json' "$HOOK"); m=$(grep -c "review-tier|binding)\\\\.json'" "$HOOK")
[ "$n" -ge 4 ] && pass "e1: python-form evidence-deny regex carries |binding at $n site(s)" || fail "e1: python-form sites=$n (<4)"
grep -q 'findings|review-tier|binding)\\.json' "$HOOK" && pass "e2: bash PROTECTED alternation carries binding" || fail "e2: bash PROTECTED missing binding"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
