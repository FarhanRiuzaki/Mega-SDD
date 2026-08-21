#!/usr/bin/env bash
# test-mermaid-flow-hook-fire.sh — pins the PostToolUse WIRING for the Mermaid-flows
# gates, not just the validator bodies. A typo'd/non-matching case-glob would make a
# validator silently never fire while every other suite stays green (invisible
# no-fire). This synthesizes real PostToolUse Write events and asserts the
# corresponding state file is written with the expected status.
#
# Run: bash tests/hooks/test-mermaid-flow-hook-fire.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
HOOK="${ROOT}/plugins/mega-sdd/hooks/post-tool-use"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$HOOK" ] || { fail "missing hook: $HOOK"; exit 1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t mflowhook)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.mega-sdd/memory"   # so telemetry append doesn't noise
# v7: arm the chain (spec 2026-08-21 §3.1) — the fan-out below is chain-scoped;
# this test pins VALIDATOR/telemetry behavior, so the fixture session is armed.
printf '{"session_id": "no-session", "chain_engaged": true, "entries": {}}' > "$WORK/.mega-sdd/.gateguard-state.json"

fire() {  # $1 = file path written
  python3 -c "import json,sys; print(json.dumps({'cwd':sys.argv[1],'tool_name':'Write','tool_input':{'file_path':sys.argv[2]}}))" "$WORK" "$1" \
    | bash "$HOOK" >/dev/null 2>&1 || true
}
statusof() { python3 -c "
import json,sys
try: print(json.load(open(sys.argv[1])).get('status'))
except Exception as e: print('NO-STATE')
" "$1" 2>/dev/null; }

# ── 1. vault 04-flows.md write -> validate-vault-flows fires -> state written ──
note '=== 1. Write 04-flows.md (prose flow) -> .vault-flows-state.json = FAIL ==='
VD="$WORK/.mega-sdd/vaults/demo"; mkdir -p "$VD"
FP="$VD/04-flows.md"
printf '%s\n' '# 04 — Flows
### F-U-001: Apply
**Steps**:
1. open form
2. submit' > "$FP"
rm -f "$WORK/.mega-sdd/.vault-flows-state.json"
fire "$FP"
VS=$(statusof "$WORK/.mega-sdd/.vault-flows-state.json")
note "  .vault-flows-state.json status=$VS"
[ "$VS" = "FAIL" ] && ok "validate-vault-flows FIRED on 04-flows.md write (glob wired)" || fail "vault-flows validator did NOT fire (status='$VS') — glob broken"

# ── 2. KB domain write -> validate-kb-flows fires -> state written ─────────────
note ''
note '=== 2. Write KB 10-domains/*.md (non-mermaid §8) -> .kb-flows-state.json = FAIL ==='
KD="$WORK/.mega-sdd/knowledge-base/10-domains"; mkdir -p "$KD"
KP="$KD/order.md"
printf '%s\n' '---
domain: order
classification: workflow
---
# 1. Purpose
p

## 3. Flow (Input to Output)

```mermaid
flowchart TD
    A["a"] --> B["b"]
```

## 8. State Machine

Draft --> Submitted --> Approved

## 11. Source References
- a.rb:1' > "$KP"
rm -f "$WORK/.mega-sdd/.kb-flows-state.json"
fire "$KP"
KS=$(statusof "$WORK/.mega-sdd/.kb-flows-state.json")
note "  .kb-flows-state.json status=$KS"
[ "$KS" = "FAIL" ] && ok "validate-kb-flows FIRED on KB domain write (glob wired)" || fail "kb-flows validator did NOT fire (status='$KS') — glob broken"

note ''
[ "$FAILED" -eq 0 ] && note "hook-fire wiring: all assertions passed." || note "hook-fire wiring: FAILURES above."
exit $FAILED
