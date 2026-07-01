#!/usr/bin/env bash
# test-vault-flows-mandate.sh — Inc-2 of the Mermaid-flows hard rule.
# Vault 04-flows.md: each F-<prefix>-NNN flow MUST be a Mermaid diagram, not a
# prose Steps list. validate-vault-flows.sh FAILs a prose-only flow, PASSes a
# Mermaid one, catches a header-less block (diagram-type reuse), and allows an
# explicit N/A entry.
#
# Run: bash tests/mermaid-flows/test-vault-flows-mandate.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
V="${ROOT}/plugins/mega-sdd/scripts/validate-vault-flows.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$V" ] || { fail "missing validator: $V"; exit 1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t vflows)"
trap 'rm -rf "$WORK"' EXIT
VDIR="$WORK/.mega-sdd/vaults/demo"; mkdir -p "$VDIR"
F="$VDIR/04-flows.md"
jget() { python3 -c "
import json,sys
try: print($2)
except Exception as e: print('ERR:'+str(e))
" <<< "$1" 2>/dev/null; }
run() { bash "$V" --cwd="$WORK" --file-path="$F" 2>/dev/null; }

# ── 1. BAD: prose numbered Steps, no mermaid -> FAIL vault_flow_not_mermaid ────
note '=== 1. prose Steps flow (no mermaid) -> FAIL (vault_flow_not_mermaid) ==='
printf '%s\n' '# 04 — Flows

### F-U-001: Apply for account

**Actor / Trigger**: user

**Steps**:
1. User opens the form
2. User submits details
3. System validates and persists

**Definition of Done**:
- [ ] account created

**Source**: PRD 3.1' > "$F"
R=$(run)
S=$(jget "$R" "json.load(sys.stdin)['status']")
H=$(jget "$R" "','.join(i.get('halt_type','') for i in json.load(sys.stdin)['issues'])")
FID=$(jget "$R" "json.load(sys.stdin)['issues'][0].get('flow_id')")
note "  status=$S halts=[$H] flow=$FID"
[ "$S" = "FAIL" ] && ok "prose-only flow FAILs" || fail "expected FAIL, got '$S'"
echo "$H" | grep -q "vault_flow_not_mermaid" && ok "emits vault_flow_not_mermaid" || fail "missing vault_flow_not_mermaid, got '[$H]'"
[ "$FID" = "F-U-001" ] && ok "attributed to F-U-001" || fail "expected F-U-001, got '$FID'"

# ── 2. GOOD: mermaid flowchart flow -> PASS ───────────────────────────────────
note ''
note '=== 2. mermaid flowchart flow -> PASS ==='
printf '%s\n' '# 04 — Flows

### F-U-001: Apply for account

**Actor / Trigger**: user

```mermaid
flowchart TD
    Open(["user opens form"]) --> Submit["user submits details"]
    Submit --> Validate{"valid?"}
    Validate -- "yes" --> Persist["persist account"]
    Validate -- "no" --> Reject(["show errors"])
```

**Definition of Done**:
- [ ] account created

**Source**: PRD 3.1' > "$F"
R=$(run); S=$(jget "$R" "json.load(sys.stdin)['status']")
C=$(jget "$R" "len(json.load(sys.stdin)['issues'])")
note "  status=$S issues=$C"
[ "$S" = "PASS" ] && ok "mermaid flow PASSes" || fail "expected PASS, got '$S'"
[ "$C" = "0" ] && ok "zero issues" || fail "expected 0 issues, got '$C'"

# ── 3. header-less mermaid in a flow -> FAIL (diagram-type reuse) ──────────────
note ''
note '=== 3. mermaid fence without diagram-type header -> FAIL (mermaid_no_diagram_type) ==='
printf '%s\n' '# 04 — Flows

### F-S-002: Recalculate interest

```mermaid
Start --> Recalc --> Done
```

**Source**: PRD 4.2' > "$F"
R=$(run); S=$(jget "$R" "json.load(sys.stdin)['status']")
H=$(jget "$R" "','.join(i.get('halt_type','') for i in json.load(sys.stdin)['issues'])")
note "  status=$S halts=[$H]"
[ "$S" = "FAIL" ] && ok "header-less flow FAILs" || fail "expected FAIL, got '$S'"
echo "$H" | grep -q "mermaid_no_diagram_type" && ok "reuses diagram-type check" || fail "expected mermaid_no_diagram_type, got '[$H]'"

# ── 4. explicit N/A flow entry (STANDALONE marker line) -> allowed (PASS) ─────
note ''
note '=== 4. explicit standalone N/A marker -> allowed (PASS) ==='
printf '%s\n' '# 04 — Flows

### F-X-009: Bulk import

**Flow**: N/A

Out of scope for v1; no wizard.

**Source**: PRD 9' > "$F"
R=$(run); S=$(jget "$R" "json.load(sys.stdin)['status']")
note "  status=$S"
[ "$S" = "PASS" ] && ok "standalone **Flow**: N/A entry does not FAIL" || fail "expected PASS on N/A entry, got '$S'"

# ── 5. REGRESSION (review M1+M2): prose-only LAST flow + trailing ## section ───
# The last flow body must STOP at `## Out of Scope`, not swallow it to EOF and
# trip the N/A escape on the section's "out of scope" text.
note ''
note '=== 5. prose-only last flow followed by ## Out of Scope -> FAIL (no bypass) ==='
printf '%s\n' '# 04 — Flows

### F-U-001: Apply
**Steps**:
1. open form
2. submit

## Out of Scope
- Bulk import — out of scope, N/A for v1

## Sources
- PRD 3.1' > "$F"
R=$(run); S=$(jget "$R" "json.load(sys.stdin)['status']")
H=$(jget "$R" "','.join(i.get('halt_type','') for i in json.load(sys.stdin)['issues'])")
FID=$(jget "$R" "json.load(sys.stdin)['issues'][0].get('flow_id') if json.load(sys.stdin)['issues'] else None")
note "  status=$S halts=[$H]"
[ "$S" = "FAIL" ] && ok "last flow still gated (trailing ## section does not create a bypass)" || fail "MANDATE BYPASS: last flow escaped, got '$S'"
echo "$H" | grep -q "vault_flow_not_mermaid" && ok "emits vault_flow_not_mermaid" || fail "expected vault_flow_not_mermaid, got '[$H]'"

# ── 6. empty ```mermaid``` fence -> FAIL (mermaid_empty_block), not a free PASS ─
note ''
note '=== 6. empty mermaid fence -> FAIL (mermaid_empty_block) ==='
printf '%s\n' '# 04 — Flows

### F-S-003: Empty

```mermaid
```

**Source**: PRD 5' > "$F"
R=$(run); S=$(jget "$R" "json.load(sys.stdin)['status']")
H=$(jget "$R" "','.join(i.get('halt_type','') for i in json.load(sys.stdin)['issues'])")
note "  status=$S halts=[$H]"
[ "$S" = "FAIL" ] && ok "empty fence FAILs" || fail "expected FAIL, got '$S'"
echo "$H" | grep -qE "mermaid_empty_block|vault_flow_not_mermaid" && ok "flags empty/absent diagram" || fail "expected empty-block flag, got '[$H]'"

note ''
[ "$FAILED" -eq 0 ] && note "vault-flow mandate: all assertions passed." || note "vault-flow mandate: FAILURES above."
exit $FAILED
