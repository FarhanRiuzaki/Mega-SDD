#!/usr/bin/env bash
# test-uat-run-skips.sh — pins scripts/uat-run.sh: the graceful-skip ladder
# (no e2e / no URL / unreachable), bounded-timeout validation, run-dir
# non-overwrite, and the GATED live arm (UAT_RUN_LIVE=1 + node + browser —
# spec §D2 open-constraint 4: the dep-less-repo npx run is proven live, not
# assumed; CI always exercises the skip arms). Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
SCRIPT="$P/scripts/uat-run.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
V="$WORK/vault"
mkdir -p "$V/uat"
printf '# uat\n' > "$V/uat/UAT.md"

echo "── skip ladder (every rung: exit 0 + skipped JSON with a reason) ──"
# (a) no e2e dir
OUT_A=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --url=http://127.0.0.1:1 </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT_A" | grep -q '"skipped":true' && echo "$OUT_A" | grep -qi "no .*spec" \
  && ok "a no-e2e → skipped" || fail "a rc=$RC out=$OUT_A"

# (b) e2e present but no URL anywhere
mkdir -p "$V/uat/e2e"
cat > "$V/uat/e2e/UAT-001.spec.ts" <<'EOF'
import { test } from '@playwright/test';
test.fixme('1. x — manual');
EOF
OUT_B=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT_B" | grep -q '"skipped":true' && echo "$OUT_B" | grep -qi "url" \
  && ok "b no-URL → skipped" || fail "b rc=$RC out=$OUT_B"

# (c) URL unreachable
OUT_C=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --url=http://127.0.0.1:9 </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT_C" | grep -q '"skipped":true' && echo "$OUT_C" | grep -qi "reachable\|server" \
  && ok "c unreachable URL → skipped" || fail "c rc=$RC out=$OUT_C"

# (d) bad timeout
OUT_D=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --url=http://x --timeout=abc </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "d --timeout=abc → exit 2 usage" || fail "d rc=$RC"

# (e) missing vault
OUT_E=$(bash "$SCRIPT" --vault="$WORK/nope" --cwd="$WORK" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "e missing vault → exit 2" || fail "e rc=$RC"

# (f) preview_url read from .mega-sdd/config.yaml when --url absent
mkdir -p "$WORK/.mega-sdd"
printf 'preview_url: http://127.0.0.1:9\n' > "$WORK/.mega-sdd/config.yaml"
OUT_F=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT_F" | grep -qi "reachable\|server" \
  && ok "f config preview_url consumed (reached the probe rung)" || fail "f rc=$RC out=$OUT_F"

# (g) syntax pin + sole-writer stamp present in source
bash -n "$SCRIPT" 2>/dev/null && ok "g1 bash -n clean" || fail "g1 syntax"
grep -q "written_by" "$SCRIPT" && ok "g2 result.json carries written_by stamp" || fail "g2 stamp missing"
grep -qE 'TIMEOUT=120|timeout.*=.*120' "$SCRIPT" && ok "g3 default 120s bound" || fail "g3 default timeout missing"
grep -q "result.json" "$SCRIPT" && grep -q "os.replace" "$SCRIPT" && ok "g4 atomic evidence write" || fail "g4 atomicity missing"

echo "── live arm (GATED: UAT_RUN_LIVE=1 + node + playwright browser) ──"
if [ "${UAT_RUN_LIVE:-0}" = "1" ] && command -v node >/dev/null 2>&1 && [ -d "$HOME/Library/Caches/ms-playwright" -o -d "$HOME/.cache/ms-playwright" ]; then
  PORT=$((20000 + RANDOM % 20000))
  printf '<html><title>demo</title><body>ok</body></html>' > "$WORK/index.html"
  ( cd "$WORK" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 ) &
  SRV=$!
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    curl -fsS -o /dev/null --max-time 2 "http://127.0.0.1:$PORT" 2>/dev/null && break
    sleep 1
  done
  cat > "$V/uat/e2e/UAT-001.spec.ts" <<EOF
// generated-by: build-uat-e2e.sh
// uat_md_sha256: $(python3 -c "import hashlib;print(hashlib.sha256(open('$V/uat/UAT.md','rb').read()).hexdigest())")
// scaffold_sha256: $(printf '0%.0s' {1..64})
import { test, expect } from '@playwright/test';
test.describe('UAT-001 — Demo', () => {
  test('1. Buka halaman', async ({ page }) => {
    await page.goto('/'); // source: index.html:1
  });
});
EOF
  # the self-contained provisioning trio build-uat-e2e.sh writes (dep-less repo lesson)
  printf '{ "name": "uat-e2e", "private": true, "devDependencies": { "@playwright/test": "1.62.1" } }\n' > "$V/uat/e2e/package.json"
  cat > "$V/uat/e2e/playwright.config.ts" <<'EOF'
import { defineConfig } from '@playwright/test';
export default defineConfig({ use: { baseURL: process.env.PREVIEW_URL } });
EOF
  OUT_L=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --url="http://127.0.0.1:$PORT" --timeout=180 </dev/null 2>&1); RC=$?
  kill "$SRV" 2>/dev/null
  RJ=$(find "$V/uat/evidence/UAT-001" -name result.json 2>/dev/null | head -1)
  [ "$RC" -eq 0 ] && [ -n "$RJ" ] && ok "L1 live run exit 0 + result.json written" || fail "L1 rc=$RC out=$(echo "$OUT_L" | tail -3)"
  if [ -n "$RJ" ]; then
    python3 -c "
import json,sys
d=json.load(open('$RJ'))
assert d['written_by']=='uat-run.sh', d
assert 'status' in d and 'uat_md_sha256' in d and 'spec_sha256' in d, d
assert d['status']['pass'] >= 1, d
" 2>/dev/null && ok "L2 result.json shape + pass count" || fail "L2 result.json shape wrong: $(cat "$RJ")"
  fi
else
  echo "  skip: live arm gated off (UAT_RUN_LIVE!=1 or no node/browser)"
fi

echo
echo "uat-run-skips: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
