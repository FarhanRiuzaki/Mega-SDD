#!/usr/bin/env bash
# test-6c-writers-and-observer.sh — god-review stage 6, Batches 6A/6D writers + aux validators.
#   run-postflight-scan.sh  executes v1 rules against git truth: violation → fail artifact,
#                           directive → unverified vs attested, genuine fix → B1 heals.
#   run-full-suite.sh       runs the (injected) runner, pins a 40-hex head_sha, B2 covers;
#                           red runner → red artifact + exit 1.
#   EB-GATE-11 (B3)         escaped committed path → whitelist_violation; declared path PASS;
#                           test files sanctioned.
#   EB-VAL-4/10             cross-cutting: pack-schema regexes (miss→FAIL, registered→PASS),
#                           keyless concern → SKIP + not_evaluable (never PASS),
#                           all-yaml-fences union (base+project pack).
#   EB-VAL-6                ui-quality prunes wrapper dirs (backup/ …) — cheap source pin.
#   EB-HONEST-1             migrate-v1-rules: byte-identical units, log says detected (never
#                           migrated), --to=v1 rejected, non-tty aborts clean (no .tmp litter).
# Run: bash tests/god-review-s6/test-6c-writers-and-observer.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
RPF="${P}/scripts/run-postflight-scan.sh"
RFS="${P}/scripts/run-full-suite.sh"
VBA="${P}/scripts/validate-bolt-artifacts.sh"
VCC="${P}/scripts/validate-cross-cutting-registration.sh"
MIG="${P}/skills/execute-bolts/scripts/migrate-v1-rules.sh"
for f in "$RPF" "$RFS" "$VBA" "$VCC" "$MIG"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w6c)"
trap 'rm -rf "$WORK"' EXIT
jget() { python3 -c "import json,sys; d=json.load(open('$1')); print(d$2)"; }
gitc() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }

echo "── run-postflight-scan.sh ──"
F="$WORK/pf"; mkdir -p "$F/.mega-sdd/vaults/a/units"; git init -q "$F"
printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n  - path: app.php\n    operation: create\n---\n## Hard rules\n- DO NOT modify locked.php\n- file config/need.php MUST exist after bolt\n- MUST NOT log secrets\n' > "$F/.mega-sdd/vaults/a/units/U-001.md"
# baseline: the locked file + the unit pre-exist BEFORE the bolt (a bolt that
# committed locked.php itself would be a REAL DO_NOT_MODIFY violation)
echo l > "$F/locked.php"
gitc "$F" add -A >/dev/null; gitc "$F" commit -q -m "chore: baseline"
echo a > "$F/app.php"
gitc "$F" add app.php >/dev/null; gitc "$F" commit -q -m "feat(U-001): initial bolt"
OUT=$(bash "$RPF" --cwd="$F" --unit=U-001 --quiet 2>&1); RC=$?
ART="$F/.mega-sdd/vaults/a/bolts/U-001/postflight.json"
[ "$RC" = "1" ] && [ -f "$ART" ] && [ "$(jget "$ART" "['status']")" = "fail" ] \
  && ok "violations recorded: FILE_PRESENCE fail + directive unverified → status fail, exit 1" \
  || fail "postflight wrapper: rc=$RC status=$(jget "$ART" "['status']" 2>/dev/null)"
python3 -c "
import json; d=json.load(open('$ART'))
v={r['type']:r['verdict'] for r in d['rules']}
assert v.get('DO_NOT_MODIFY')=='pass', v
assert v.get('FILE_PRESENCE_RULE')=='fail', v
assert v.get('directive')=='directive_unverified', v
assert d.get('written_by')=='run-postflight-scan.sh'
import re; assert re.fullmatch(r'[0-9a-f]{40}', d['head_sha'])
print('  ✓ per-rule verdicts correct; artifact carries writer + pinned 40-hex head_sha')
" || fail "per-rule verdicts"
mkdir -p "$F/config"; echo n > "$F/config/need.php"
bash "$RPF" --cwd="$F" --unit=U-001 --attest-directives="panel reviewed 6c" --quiet >/dev/null 2>&1; RC=$?
[ "$RC" = "0" ] && [ "$(jget "$ART" "['status']")" = "pass" ] \
  && [ "$(jget "$F/.mega-sdd/.bolt-postflight-state.json" "['status']")" = "PASS" ] \
  && ok "genuine fix + attestation → pass artifact AND B1 gate state heals" \
  || fail "heal loop: rc=$RC"

echo "── run-full-suite.sh ──"
SHA=$(git -C "$F" rev-parse HEAD)
bash "$RFS" --cwd="$F" --runner=true --quiet >/dev/null 2>&1; RC=$?
BS="$F/.mega-sdd/vaults/a/bolts/_batch-suite.json"
[ "$RC" = "0" ] && [ "$(jget "$BS" "['status']")" = "green" ] && [ "$(jget "$BS" "['head_sha']")" = "$SHA" ] \
  && ok "green runner → green artifact pinned at HEAD" || fail "run-full-suite green path (rc=$RC)"
bash "$VBA" --cwd="$F" --batch-suite-gate --quiet || true
[ "$(jget "$F/.mega-sdd/.batch-suite-gate-state.json" "['status']")" = "PASS" ] && ok "wrapper artifact covers B2" || fail "B2 not covered by wrapper artifact"
bash "$RFS" --cwd="$F" --runner=false --quiet >/dev/null 2>&1; RC=$?
[ "$RC" = "1" ] && [ "$(jget "$BS" "['status']")" = "red" ] && ok "red runner → red artifact, exit 1" || fail "run-full-suite red path (rc=$RC)"
bash "$RFS" --cwd="$F" --runner=true --quiet >/dev/null 2>&1 || true   # leave green for B3 below

echo "── EB-GATE-11: B3 whitelist observer ──"
printf -- '---\nunit_id: U-002\ntask_type: create\ntarget_files:\n  - path: other.php\n    operation: create\n---\n' > "$F/.mega-sdd/vaults/a/units/U-002.md"
gitc "$F" add .mega-sdd >/dev/null; gitc "$F" commit -q -m "chore: add U-002 spec"
echo esc > "$F/escaped.php"
mkdir -p "$F/tests"; echo t > "$F/tests/U002Test.php"
gitc "$F" add escaped.php tests >/dev/null; gitc "$F" commit -q -m "feat(U-002): escapes whitelist"
bash "$VBA" --cwd="$F" --whitelist-scan --quiet || true
WL="$F/.mega-sdd/.bolt-whitelist-state.json"
python3 -c "
import json; d=json.load(open('$WL'))
assert d['status']=='FAIL', d['status']
esc={p for i in d['issues'] for p in i['escaped_files']}
assert 'escaped.php' in esc, esc
assert not any('tests/' in p for p in esc), 'test file not sanctioned: %s' % esc
assert not any(p.startswith('.mega-sdd/') for p in esc), esc
print('  ✓ escaped path flagged; test file + .mega-sdd artifacts sanctioned')
" || fail "whitelist observer FAIL path"
printf -- '---\nunit_id: U-002\ntask_type: create\ntarget_files:\n  - path: other.php\n    operation: create\n  - path: escaped.php\n    operation: create\n---\n' > "$F/.mega-sdd/vaults/a/units/U-002.md"
bash "$VBA" --cwd="$F" --whitelist-scan --quiet || true
[ "$(jget "$WL" "['status']")" = "PASS" ] && ok "declaring the path in target_files clears B3" || fail "B3 unclearable after declaration"

echo "── EB-VAL-4/10: cross-cutting pack-schema discovery ──"
C="$WORK/cc"; mkdir -p "$C/.mega-sdd/codebase" "$C/app/Models" "$C/database/migrations"
printf 'framework_pack: laravel\n' > "$C/.mega-sdd/codebase/starterkit-context.yaml"
cat > "$C/database/migrations/001_orders.php" <<'PHP'
<?php
Schema::create('orders', function ($t) { $t->unsignedBigInteger('branch_id'); });
PHP
cat > "$C/app/Models/Order.php" <<'PHP'
<?php
class Order extends Model { protected $table = 'orders'; }
PHP
OUT=$(bash "$VCC" --cwd="$C" 2>/dev/null || true)
printf '%s' "$OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['status']=='FAIL' and d['summary']['missing_registration_count']==1, d['summary']
print('  ✓ laravel model missing registration → FAIL (pack-declared regexes)')
" || fail "cross-cutting laravel FAIL path"
cat > "$C/app/Models/Order.php" <<'PHP'
<?php
class Order extends Model {
  protected $table = 'orders';
  protected static function booted() { static::addGlobalScope(new BranchScoped); }
}
PHP
OUT=$(bash "$VCC" --cwd="$C" 2>/dev/null || true)
printf '%s' "$OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['status']=='PASS', d['status']
print('  ✓ registered model → PASS')
" || fail "cross-cutting PASS path"
S="$WORK/slim"; mkdir -p "$S/.mega-sdd/codebase" "$S/src/Middleware" "$S/config"
printf 'framework_pack: slim\n' > "$S/.mega-sdd/codebase/starterkit-context.yaml"
printf '<?php // owner_id middleware\n' > "$S/src/Middleware/Jwt.php"; printf '<?php\n' > "$S/config/routes.php"
OUT=$(bash "$VCC" --cwd="$S" 2>/dev/null || true)
printf '%s' "$OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['status']=='SKIP' and d['summary']['concerns_not_evaluable']>=1, (d['status'], d['summary'])
print('  ✓ keyless concern → SKIP + not_evaluable (structural false-PASS closed)')
" || fail "cross-cutting slim honesty"
grep -q "def yaml_blocks" "$VCC" && grep -q "for body in yaml_blocks" "$VCC" \
  && ok "all-yaml-fences union in place (EB-VAL-10)" || fail "first-fence-only parser regressed"

echo "── EB-VAL-6 pin ──"
# non-shipping wrapper dirs ARE pruned; shipping-capable dirs (docs/samples/examples/
# fixtures) are NOT (S6 EB-VAL-9 fix: skipping them exempted real views from the gate).
grep -q '"backup"' "${P}/scripts/validate-ui-quality.sh" && grep -q '"_archive"' "${P}/scripts/validate-ui-quality.sh" \
  && ! grep -qE '"(docs|samples|examples|fixtures)"' "${P}/scripts/validate-ui-quality.sh" \
  && ok "ui-quality SKIP_DIRS prunes wrapper dirs but NOT shipping-capable docs/samples/examples/fixtures" \
  || fail "ui-quality SKIP_DIRS wrapper/shipping split wrong"

echo "── EB-HONEST-1: migrate-v1-rules honesty ──"
V="$WORK/vault"; mkdir -p "$V/units"
printf -- '---\nunit_id: U-001\n---\n## Hard rules\n- DO NOT modify a.php\n- app/**/*.php MUST follow PascalCase naming\n' > "$V/units/U-001.md"
SUM_BEFORE=$(shasum "$V/units/U-001.md" | cut -d' ' -f1)
OUT=$(bash "$MIG" "$V" --auto-confirm 2>&1); RC=$?
SUM_AFTER=$(shasum "$V/units/U-001.md" | cut -d' ' -f1)
[ "$RC" = "0" ] && [ "$SUM_BEFORE" = "$SUM_AFTER" ] && ok "detector modifies NO unit file" || fail "migrate script mutated a unit (rc=$RC)"
grep -q "detected (delegated to skill)" "$V/units/.migration-log.md" && ! grep -qE "^## U-001 — migrated" "$V/units/.migration-log.md" \
  && ok "log records detection, never fabricates 'migrated'" || fail "log fabricates migration"
grep -q "MUST follow" "$V/units/.migration-log.md" 2>/dev/null || grep -q "v1 rules: 2" "$V/units/.migration-log.md" \
  && ok "NAMING_RULE production detected (detector gap closed)" || fail "NAMING_RULE still invisible to detector"
OUT=$(bash "$MIG" "$V" --to=v1 2>&1); RC=$?
[ "$RC" = "1" ] && printf '%s' "$OUT" | grep -q "not implemented" && ok "--to=v1 rejected with an honest error" || fail "--to=v1 handling (rc=$RC)"
OUT=$(bash "$MIG" "$V" </dev/null 2>&1); RC=$?
[ "$RC" = "1" ] && [ ! -f "$V/units/.migration-log.md.tmp" ] && ok "non-tty aborts clean (no .tmp litter)" || fail "non-tty left litter or rc=$RC"

echo
[ "$FAILED" -eq 0 ] && { echo "test-6c-writers-and-observer: ALL PASS"; exit 0; } || { echo "test-6c-writers-and-observer: FAILURES"; exit 1; }
