#!/usr/bin/env bash
# test-kb-sec8-gate.sh — Inc-1 of the Mermaid-flows hard rule
# (docs/superpowers/specs/2026-07-01-mermaid-flows-hard-rule.md; subsumes god-review L7).
#
# PROVES: the kb flows surface (validate-kb.sh) §8 State Machine treats a non-N/A §8 with raw
# transition arrows but NO ```mermaid fence as a FAIL (kb_flow_not_mermaid) —
# mirroring the §3 Flow branch — instead of the old silent PASS ("consider
# mermaid fence for consistency"). N/A §8 still SKIPs; fenced §8 still PASSes.
#
# Run: bash tests/mermaid-flows/test-kb-sec8-gate.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VALIDATOR="${ROOT}/plugins/mega-sdd/scripts/validate-kb.sh"
VFLAGS="--surface=flows"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

[ -f "$VALIDATOR" ] || { fail "missing validator: $VALIDATOR"; exit 1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t kbsec8)"
trap 'rm -rf "$WORK"' EXIT
KB="$WORK/.mega-sdd/knowledge-base/10-domains"
mkdir -p "$KB"

jget() { python3 -c "
import json,sys
try:
    d=json.load(open('$1'))
    print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

# A valid §3 flow reused by every fixture so §3 never confounds the §8 verdict.
SEC3='## 3. Flow (Input \xe2\x86\x92 Process \xe2\x86\x92 Output)

```mermaid
flowchart TD
    Start(["Order received"]) --> Validate{"Valid?"}
    Validate -- "yes" --> Persist["Save order"]
    Validate -- "no" --> Reject(["Reject"])
```'

fixture() {  # $1=file  $2=sec8-body
  printf '%b\n' "---
domain: order-lifecycle
classification: workflow
confidence: VERIFIED
---

# 1. Purpose
Test fixture for the §8 Mermaid gate.

$SEC3

## 8. State Machine

$2

## 11. Source References
- app/order.rb:10" > "$1"
}

run() { bash "$VALIDATOR" $VFLAGS --cwd="$WORK" --file-path="$1" --quiet >/dev/null 2>&1; }
STATE="$WORK/.mega-sdd/.kb-flows-state.json"

# ── 1. BAD: §8 raw ASCII transitions, no mermaid fence → must FAIL ─────────────
note '=== 1. sec8 raw transitions, NO mermaid fence -> FAIL (kb_flow_not_mermaid) ==='
BAD="$KB/sec8-ascii.md"
fixture "$BAD" 'Draft --> Submitted --> Approved
Submitted --> Rejected
Approved --> Shipped'
run "$BAD"
B_STATUS=$(jget "$STATE" "d.get('status')")
B_SEC8=$(jget "$STATE" "next((c['status'] for c in d['checks'] if c['check']=='sec8_state_machine_fence'),'NONE')")
B_HALT=$(jget "$STATE" "','.join(i.get('halt_type','') for i in d.get('issues',[]) if i.get('section')=='8')")
note "  bad: status=$B_STATUS sec8=$B_SEC8 issues8=[$B_HALT]"
[ "$B_STATUS" = "FAIL" ] && ok "overall FAIL on non-mermaid §8" || fail "expected overall FAIL, got '$B_STATUS'"
[ "$B_SEC8" = "FAIL" ] && ok "sec8_state_machine_fence = FAIL" || fail "expected sec8 check FAIL, got '$B_SEC8'"
echo "$B_HALT" | grep -q "kb_flow_not_mermaid" && ok "emits kb_flow_not_mermaid on §8" || fail "expected kb_flow_not_mermaid issue on §8, got '[$B_HALT]'"

# ── 2. GOOD: §8 as a mermaid stateDiagram → must PASS ─────────────────────────
note ""
note '=== 2. sec8 as mermaid stateDiagram fence -> PASS ==='
GOOD="$KB/sec8-mermaid.md"
fixture "$GOOD" '```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Submitted: "user submits"
    Submitted --> Approved: "approver approves"
    Submitted --> Rejected: "approver rejects"
    Approved --> [*]
```'
run "$GOOD"
G_STATUS=$(jget "$STATE" "d.get('status')")
G_SEC8=$(jget "$STATE" "next((c['status'] for c in d['checks'] if c['check']=='sec8_state_machine_fence'),'NONE')")
note "  good: status=$G_STATUS sec8=$G_SEC8"
[ "$G_STATUS" = "PASS" ] && ok "overall PASS on fenced §8" || fail "expected PASS, got '$G_STATUS'"
[ "$G_SEC8" = "PASS" ] && ok "sec8 check PASS" || fail "expected sec8 PASS, got '$G_SEC8'"

# ── 3. N/A: §8 marked N/A → must SKIP (no regression) ─────────────────────────
note ""
note '=== 3. sec8 marked N/A -> SKIP (no regression) ==='
NA="$KB/sec8-na.md"
fixture "$NA" 'N/A — not a workflow (stateless CRUD).'
run "$NA"
NA_STATUS=$(jget "$STATE" "d.get('status')")
NA_SEC8=$(jget "$STATE" "next((c['status'] for c in d['checks'] if c['check']=='sec8_state_machine_fence'),'NONE')")
note "  na: status=$NA_STATUS sec8=$NA_SEC8"
[ "$NA_STATUS" = "PASS" ] && ok "N/A does not FAIL (status PASS)" || fail "expected PASS on N/A, got '$NA_STATUS'"
[ "$NA_SEC8" = "SKIP" ] && ok "sec8 check SKIP on N/A" || fail "expected sec8 SKIP, got '$NA_SEC8'"

note ""
[ "$FAILED" -eq 0 ] && note "ALL §8 Mermaid-gate assertions passed." || note "SOME assertions FAILED (see \xe2\x9c\x97 above)."
exit $FAILED
