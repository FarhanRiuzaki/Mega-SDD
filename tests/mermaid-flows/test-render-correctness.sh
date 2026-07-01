#!/usr/bin/env bash
# test-render-correctness.sh — Mermaid must actually RENDER, not just pass Rule 1-3.
# (docs/superpowers/specs/2026-07-01-mermaid-flows-hard-rule.md §render-correctness)
#
# Part A (always, zero-dep): the heuristic requires a diagram-type declaration —
#   a header-less mermaid fence (edge fragment / placeholder) FAILs the KB gate
#   with mermaid_no_diagram_type; a properly-declared block passes.
# Part B (opt-in, availability-aware): verify-mermaid.sh runs the REAL mermaid
#   grammar and FAILs non-rendering blocks. If node+mermaid are absent it SKIPs
#   cleanly — the test asserts FAIL-with-errors when the parser runs, else SKIP.
#
# Run: bash tests/mermaid-flows/test-render-correctness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
KBVAL="${ROOT}/plugins/mega-sdd/scripts/validate-kb-flows.sh"
VERIFY="${ROOT}/plugins/mega-sdd/scripts/verify-mermaid.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

for f in "$KBVAL" "$VERIFY"; do [ -f "$f" ] || { fail "missing: $f"; exit 1; }; done

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t mrender)"
trap 'rm -rf "$WORK"' EXIT
KB="$WORK/.mega-sdd/knowledge-base/10-domains"; mkdir -p "$KB"

jget() { python3 -c "
import json,sys
try: print($2)
except Exception as e: print('ERR:'+str(e))
" <<< "$1" 2>/dev/null; }

# ── Part A: heuristic diagram-type requirement (zero-dep) ──────────────────────
note '=== A. heuristic: header-less mermaid fence -> FAIL (mermaid_no_diagram_type) ==='
HL="$KB/headerless.md"
printf '%s\n' '---
domain: x
classification: workflow
---
# 1. Purpose
p

## 3. Flow (Input to Output)

```mermaid
Vault -->|"has OQs?"| Gate{has OQs?}
Gate -->|yes| RO[resolve]
```

## 11. Source References
- a.rb:1' > "$HL"
R=$(bash "$KBVAL" --cwd="$WORK" --file-path="$HL" 2>/dev/null)
A_STATUS=$(jget "$R" "json.load(sys.stdin)['status']")
A_HALT=$(jget "$R" "','.join(i.get('halt_type','') for i in json.load(sys.stdin)['issues'])")
note "  status=$A_STATUS halts=[$A_HALT]"
[ "$A_STATUS" = "FAIL" ] && ok "header-less block FAILs" || fail "expected FAIL, got '$A_STATUS'"
echo "$A_HALT" | grep -q "mermaid_no_diagram_type" && ok "emits mermaid_no_diagram_type" || fail "missing mermaid_no_diagram_type, got '[$A_HALT]'"

note ''
note '=== A2. properly-declared flowchart -> PASS (no diagram-type issue) ==='
OKF="$KB/declared.md"
printf '%s\n' '---
domain: x
classification: workflow
---
# 1. Purpose
p

## 3. Flow (Input to Output)

```mermaid
flowchart TD
    Vault["vault"] -->|"has OQs?"| Gate{"has OQs?"}
    Gate -->|"yes"| RO["resolve"]
```

## 11. Source References
- a.rb:1' > "$OKF"
R2=$(bash "$KBVAL" --cwd="$WORK" --file-path="$OKF" 2>/dev/null)
A2_STATUS=$(jget "$R2" "json.load(sys.stdin)['status']")
A2_DT=$(jget "$R2" "sum(1 for i in json.load(sys.stdin)['issues'] if i.get('halt_type')=='mermaid_no_diagram_type')")
note "  status=$A2_STATUS diagram_type_issues=$A2_DT"
[ "$A2_STATUS" = "PASS" ] && ok "declared flowchart PASSes" || fail "expected PASS, got '$A2_STATUS'"
[ "$A2_DT" = "0" ] && ok "no diagram-type issue on a declared block" || fail "false positive: $A2_DT diagram-type issues"

# ── Part B: opt-in real-parser ground truth (availability-aware) ───────────────
note ''
note '=== B. verify-mermaid.sh real-parser check (SKIP-safe if node/mermaid absent) ==='
BAD="$WORK/bad.md"
printf '%s\n' '# doc
```mermaid
Vault -->|"x"| Gate{y}
```
```mermaid
flowchart TD
  start --> end
  end --> done
```' > "$BAD"
RB=$(bash "$VERIFY" --cwd="$WORK" --file-path="$BAD" 2>/dev/null)
B_STATUS=$(jget "$RB" "json.load(sys.stdin)['status']")
note "  status=$B_STATUS"
if [ "$B_STATUS" = "SKIP" ]; then
  ok "parser not available in this env -> clean SKIP (heuristic still guards)"
elif [ "$B_STATUS" = "FAIL" ]; then
  B_ERRS=$(jget "$RB" "len(json.load(sys.stdin)['grammar_errors'])")
  note "  grammar_errors=$B_ERRS"
  [ "${B_ERRS:-0}" -ge 1 ] 2>/dev/null && ok "real parser flagged >=1 non-rendering block" || fail "FAIL but no grammar_errors recorded"
  # a genuinely-good file must PASS
  GOODF="$WORK/good.md"
  printf '%s\n' '```mermaid
flowchart TD
  A["a"] --> B["b"]
```' > "$GOODF"
  RG=$(bash "$VERIFY" --cwd="$WORK" --file-path="$GOODF" 2>/dev/null)
  G_STATUS=$(jget "$RG" "json.load(sys.stdin)['status']")
  [ "$G_STATUS" = "PASS" ] && ok "renderable file PASSes the real parser" || fail "good file expected PASS, got '$G_STATUS'"
else
  fail "unexpected verify-mermaid status '$B_STATUS'"
fi

note ''
[ "$FAILED" -eq 0 ] && note "render-correctness: all assertions passed." || note "render-correctness: FAILURES above."
exit $FAILED
