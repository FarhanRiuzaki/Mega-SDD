#!/usr/bin/env bash
# test-a1-a4.sh — pins spec 2026-08-17-delta-hygiene-a1-a4.md (v6.16.0).
# Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

echo "── A1: CI validates the plugin manifests, version-pinned, plain mode ──"
CI="$ROOT/.github/workflows/tests.yml"
grep -q 'claude plugin validate plugins/mega-sdd' "$CI" && ok "a1a validate step present" || fail "a1a step missing"
grep -q '@anthropic-ai/claude-code@2\.1\.' "$CI" && ok "a1b CLI install version-pinned" || fail "a1b pin missing"
grep -q 'claude plugin validate --strict' "$CI" && fail "a1c --strict crept in (baseline warning would fail CI)" || ok "a1c plain mode (strict rejected on record)"

echo "── A2: no BARE TodoWrite left in vendored (sync backstop) ──"
BARE=$(grep -rn 'TodoWrite' "$P/skills/_vendored/" | grep -v 'legacy TodoWrite where available' || true)
[ -z "$BARE" ] && ok "a2a zero bare TodoWrite sites" || fail "a2a bare TodoWrite reintroduced: $BARE"
grep -rq 'TaskCreate/TaskUpdate' "$P/skills/_vendored/" && ok "a2b current task tools named" || fail "a2b replacement phrase missing"

echo "── A3: statusMessage on sync hooks, absent on async ──"
"$PY" - "$P/hooks/hooks.json" <<'PYEOF'
import json,sys
d=json.load(open(sys.argv[1]))
sync_msgs=0; async_msgs=0
for ev,ms in d['hooks'].items():
    for m in ms:
        for h in m['hooks']:
            if h.get('async'): async_msgs += 1 if 'statusMessage' in h else 0
            else: sync_msgs += 1 if 'statusMessage' in h else 0
assert sync_msgs >= 3, f"sync hooks with statusMessage: {sync_msgs}"  # v7.3.0: 3 sync events remain (SessionStart, PreToolUse, UserPromptExpansion)
assert async_msgs == 0, f"async hooks must not carry statusMessage: {async_msgs}"
print(f"sync={sync_msgs} async=0")
PYEOF
[ $? -eq 0 ] && ok "a3 statusMessage placement correct + JSON valid" || fail "a3 statusMessage wrong"

echo "── A4: maxTurns on all 9 plugin agents with spec values ──"
"$PY" - "$P/agents" <<'PYEOF'
import re,sys,os
CAPS={'bolt-implementer':80,'domain-extractor':60,'resolution-verifier':30,'spec-reviewer':25,'code-quality-reviewer':25,'security-reviewer':25,'standards-reviewer':25,'design-reviewer':25,'phase-advisor':25}
for name,cap in CAPS.items():
    t=open(os.path.join(sys.argv[1],name+'.md')).read()
    m=re.search(r'^maxTurns: (\d+)$', t, re.M)
    assert m, f"{name}: maxTurns missing"
    assert int(m.group(1))==cap, f"{name}: {m.group(1)} != {cap}"
print("9 agents capped per spec")
PYEOF
[ $? -eq 0 ] && ok "a4 maxTurns caps match spec" || fail "a4 caps wrong/missing"

echo
echo "delta-hygiene a1-a4: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
