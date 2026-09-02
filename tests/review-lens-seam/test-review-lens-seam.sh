#!/usr/bin/env bash
# test-review-lens-seam.sh — 7.21.3 (spec 2026-09-02-review-lens-polish.md).
#
# Owner challenged the 3-layer code-taste stack ("berlebihan ga?"); the decision
# on record is KEEP 3 (funnel, cheapest-first — research 2026-09-02) and polish
# the SEAMS instead. Pins:
#   A  quality lens owns FORM, never reports scope (one defect, one owner)
#   B  spec lens owns SCOPE, never reports form
#   C  Knuth symmetry: speculative optimization → yagni: finding
#   D  the keep-3-layers decision + its measured evidence stays on record
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CQ="$ROOT/plugins/mega-sdd/agents/code-quality-reviewer.md"
SP="$ROOT/plugins/mega-sdd/agents/spec-reviewer.md"
RD="$ROOT/research/2026-09-02-code-taste-standards-audit.md"
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

echo "── A: quality lens seam (FORM) ──"
grep -q "you own FORM, not scope" "$CQ" && ok "A1 form ownership declared" || bad "A1 form seam missing"
grep -q "one defect, one owner" "$CQ" && ok "A2 single-owner rule" || bad "A2 single-owner rule missing"
grep -q "is the spec lens's finding, not yours" "$CQ" && ok "A3 scope explicitly routed away" || bad "A3 scope routing missing"

echo "── B: spec lens seam (SCOPE) ──"
grep -q "you own SCOPE, not form" "$SP" && ok "B1 scope ownership declared" || bad "B1 scope seam missing"
grep -q "is the code-quality lens's finding, not yours" "$SP" && ok "B2 form explicitly routed away" || bad "B2 form routing missing"

echo "── C: Knuth symmetry ──"
grep -q "The symmetric failure is ALSO a finding" "$CQ" && ok "C1 speculative-optimization side present" || bad "C1 symmetry line missing"
grep -q "no obvious N+1s" "$CQ" && ok "C2 the obvious-waste side survived" || bad "C2 N+1 side lost"
grep -q "speculative tuning gets deleted" "$CQ" && grep -qE 'tag it .?yagni:' "$CQ" \
  && ok "C3 fix route = yagni: tag" || bad "C3 yagni routing missing"

echo "── D: the 3-layer decision stays on record ──"
grep -q "DIPERTAHANKAN 3, on the record" "$RD" && ok "D1 keep decision recorded" || bad "D1 decision missing"
grep -q "prose-halt di-bulldoze model di 1/4 run" "$RD" && ok "D2 measured evidence cited (rules alone leak)" || bad "D2 evidence missing"
grep -q "Tanpa lapisan/surface baru" "$RD" && ok "D3 no-new-layer rail recorded" || bad "D3 no-new-layer rail missing"

echo; [ $err -eq 0 ] && { echo "test-review-lens-seam: ALL PASS"; exit 0; } || { echo "test-review-lens-seam: FAILED"; exit 1; }
