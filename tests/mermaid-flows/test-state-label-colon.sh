#!/usr/bin/env bash
# test-state-label-colon.sh — Rule 7 (7.23.2, spec amendemen 2026-09-03 render-html-v2).
#
# Field failure (mcf-fincore KB): extracted stateDiagram-v2 blocks carried
# `guard:` prefixes + `file.cs:112-134` citations inside transition labels —
# mermaid's grammar rejects ANY second ':' there, and (ground-truthed against
# mermaid.parse()) double-quoting does NOT rescue it. Pins:
#   A  tokenizer: Rule 7 fires on a state transition label carrying a second ':'
#   B  tokenizer: colon-free guard/citation form passes; flowchart untouched
#   C  contract: Rule 7 documented in mermaid-emission-rules.md (+ the wrong
#      old "wrap in double-quotes" advice for state labels is corrected)
#   D  producer: PRD-kontrak template §3 carries the no-second-colon rail
#   E  renderer: the error panel hints the state-label-colon cause
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/plugins/mega-sdd/scripts/_lib"
ER="$ROOT/plugins/mega-sdd/references/mermaid-emission-rules.md"
PT="$ROOT/plugins/mega-sdd/skills/extract-intelligence/references/prd-kontrak-template.md"
T="$ROOT/plugins/mega-sdd/assets/render-html/template.html"
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

echo "── A/B: tokenizer Rule 7 ──"
OUT=$(python3 - "$LIB" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import mermaid_syntax as ms
F = ms.FENCE
bad = F + "mermaid\nstateDiagram-v2\n    NoRecord --> I: InsertBPKB (guard: not duplicate) / Repo.cs:112-134\n" + F
bad_semi = F + "mermaid\nstateDiagram-v2\n    A --> B: CaStatus='A'; PO generated\n" + F
quote_ok = F + "mermaid\nstateDiagram-v2\n    A --> B: Clik=\"Approve\" final\n" + F
good = F + "mermaid\nstateDiagram-v2\n    A --> B: submit (guard — form valid) / Repo.cs 112-134 · Clik='Approve'\n    note right of B\n        soft flag, see EC-1\n    end note\n" + F
flow = F + "mermaid\nflowchart TD\n  A[\"step 1: validate\"] --> B\n" + F
flow_inner_quote = F + "mermaid\nflowchart TD\n  J[\"resolve via GLLink(\"ClassId,TrxId\")\"] --> K\n" + F
def r7(txt):
    return [i for i in ms.check_mermaid_syntax(ms.extract_mermaid_blocks(txt), "t")
            if "Rule 7" in i["rule_violated"]]
print("bad", len(r7(bad)))
print("bad_semi", len(r7(bad_semi)))
print("quote_ok", len(r7(quote_ok)))
print("good", len(r7(good)))
print("flow", len(r7(flow)))
iq = [i for i in ms.check_mermaid_syntax(ms.extract_mermaid_blocks(flow_inner_quote), "t")
      if "INSIDE quoted" in i["rule_violated"]]
print("inner_quote", len(iq))
i = r7(bad)[0]
assert i["halt_type"] == "mermaid_syntax_invalid" and "note" in i["suggested_fix"], i
print("shape ok")
EOF
)
echo "$OUT" | grep -q "^bad 1$" && ok "A1 second ':' in a state transition label → Rule 7 issue" || bad "A1 tokenizer miss: $OUT"
echo "$OUT" | grep -q "^bad_semi 1$" && ok "A2 ';' in a state label (statement terminator) → Rule 7" || bad "A2 semicolon miss"
echo "$OUT" | grep -q "^quote_ok 0$" && ok "A3 '\"' in a state label is legal — NOT over-flagged (measured)" || bad "A3 quote over-flagged"
echo "$OUT" | grep -q "^good 0$" && ok "B1 dash/·/single-quote forms pass" || bad "B1 false positive"
echo "$OUT" | grep -q "^flow 0$" && ok "B2 flowchart edge labels untouched by Rule 7" || bad "B2 flowchart hit"
echo "$OUT" | grep -q "^inner_quote 1$" && ok "B2b Rule 3 quoted-variant: inner unescaped quote flagged" || bad "B2b inner-quote gap still open"
echo "$OUT" | grep -q "^shape ok$" && ok "B3 issue shape: halt_type + note suggestion" || bad "B3 issue shape wrong"

echo "── C: contract home ──"
grep -q "## Rule 7" "$ER" && grep -q "NOT rescue either" "$ER" && ok "C1 Rule 7 documented (quoting-does-not-help measured)" || bad "C1 Rule 7 missing"
grep -q "may NEVER contain another" "$ER" && ok "C2 Pattern B advisory corrected" || bad "C2 old wrong advice still stands"

echo "── D: producer template ──"
grep -q "never contain a second" "$PT" && grep -qF 'file.cs 112-134' "$PT" && ok "D1 PRD-kontrak §3 carries the rail" || bad "D1 producer rail missing"

echo "── E: renderer hint ──"
grep -q "label transisi stateDiagram tidak boleh mengandung" "$T" && ok "E1 error panel hints the cause" || bad "E1 hint missing"
grep -qF 'state: { useMaxWidth: false }' "$T" && ok "E2 useMaxWidth off for state (fit floor governs)" || bad "E2 state useMaxWidth still default"

echo; [ $err -eq 0 ] && { echo "test-state-label-colon: ALL PASS"; exit 0; } || { echo "test-state-label-colon: FAILED"; exit 1; }
