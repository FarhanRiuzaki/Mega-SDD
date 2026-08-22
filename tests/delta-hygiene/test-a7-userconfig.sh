#!/usr/bin/env bash
# test-a7-userconfig.sh — pins spec 2026-08-17-a7-userconfig.md. Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

"$PY" - "$P/.claude-plugin/plugin.json" <<'PYEOF'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get('displayName')=='Mega-SDD', d.get('displayName')
uc=d['userConfig']['telemetry']
assert uc['type']=='boolean' and uc['default'] is True and uc.get('title'), uc
print('manifest ok')
PYEOF
[ $? -eq 0 ] && ok "a1 displayName + userConfig.telemetry (typed, titled, default-on)" || fail "a1 manifest shape"

for H in hooks/post-tool-use hooks/session-start; do
  grep -q 'CLAUDE_PLUGIN_OPTION_TELEMETRY' "$P/$H" && ok "a2 $H reads the userConfig env" || fail "a2 $H env missing"
done
# v7 Fase 2: the C1 self-resolve telemetry site moved to scripts/ground.sh —
# session-start keeps ONE site (the diagnostic layer), ground.sh carries the other.
N=$(grep -c 'CLAUDE_PLUGIN_OPTION_TELEMETRY' "$P/hooks/session-start")
[ "$N" -ge 1 ] && ok "a3 session-start diagnostic telemetry site ($N)" || fail "a3 only $N site(s)"
grep -q 'CLAUDE_PLUGIN_OPTION_TELEMETRY' "$P/scripts/ground.sh" \
  && ok "a3b ground.sh carries the moved C1-guard telemetry site" || fail "a3b ground.sh env missing"
# precedence shape: env consulted only in the elif (project line absent)
grep -F '&& grep -qE "^\s*telemetry:" "$CONFIG_FILE"' "$P/hooks/post-tool-use" >/dev/null \
  && ok "a4 project telemetry line always wins (presence-gated)" || fail "a4 precedence shape missing"

echo
echo "a7-userconfig: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
