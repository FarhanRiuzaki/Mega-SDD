#!/usr/bin/env bash
# test-advisor-wired.sh — 7.14.0 architecture advisor (spec 2026-08-31-architecture-advisor.md).
#
# Minimal-form contract: ONE plugin-root reference + two-sentence wiring, no new
# skill, no gate/hook change. Pins:
#   A  the reference exists, carries a ToC (>100 lines), and its rails are
#      load-bearing: proposal-first (advisor never decides), citation duty
#      (KB or census answer), human-only census via AskUserQuestion+keterangan,
#      Mermaid-mandatory topology, unanswered census -> deferred OQ
#   B  the ADR template splits accepted/proposed and carries an [INTENT] claims
#      block for vault consumption
#   C  extract-intelligence OFFERS the consultation at hand-off (never auto)
#      and routes to the ref (one-level rule)
#   D  generate-intent consumes decisions/ADR-*.md accepted-only (SKILL + the
#      kb-submode procedure both say so; proposed -> OQ, never a decision)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
REF="$P/references/architecture-advisor.md"
EX="$P/skills/extract-intelligence/SKILL.md"
GI="$P/skills/generate-intent/SKILL.md"
KS="$P/skills/generate-intent/references/kb-submode.md"
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

echo "── A: the reference + its rails ──"
[ -f "$REF" ] && ok "A1 reference exists" || { bad "A1 reference missing"; echo "test-advisor-wired: FAILED"; exit 1; }
grep -q "^## Contents" "$REF" && ok "A2 ToC present (>100-line ref rule)" || bad "A2 no ## Contents"
grep -q "the advisor proposes, the human decides" "$REF" && ok "A3 proposal-first rail is the first thing stated" || bad "A3 proposal-first rail missing"
grep -q "NEVER auto-writes an accepted ADR" "$REF" && ok "A4 advisor cannot self-accept a decision" || bad "A4 self-accept prohibition missing"
grep -q "MUST cite either a KB artifact" "$REF" && ok "A5 citation duty (KB or census answer) stated" || bad "A5 citation duty missing"
grep -q "AskUserQuestion" "$REF" && grep -q "keterangan per option" "$REF" && ok "A6 census is human-only with keterangan (OQ-keterangan contract)" || bad "A6 census keterangan contract missing"
grep -qF "Mermaid diagram** (mandatory" "$REF" && ok "A7 topology diagrams are Mermaid-mandatory" || bad "A7 Mermaid mandate missing"
grep -qi "deferred" "$REF" && ok "A8 unanswered census -> deferred OQ, never assumed" || bad "A8 deferred-OQ rule missing"

echo "── B: the ADR template ──"
grep -q "Status: accepted | proposed" "$REF" && ok "B1 template splits accepted/proposed" || bad "B1 status split missing"
grep -q "## Claims (\[INTENT\]" "$REF" && ok "B2 [INTENT] claims block for generate-intent --kb" || bad "B2 claims block missing"
grep -q "## Options considered" "$REF" && ok "B3 rejected options are recorded with reasons" || bad "B3 options-considered section missing"

echo "── C: extract-intelligence wiring ──"
grep -q "plugins/mega-sdd/references/architecture-advisor.md" "$EX" && ok "C1 SKILL routes to the ref (one-level rule)" || bad "C1 no route from extract-intelligence SKILL"
grep -q "an OFFER, never auto" "$EX" && ok "C2 the consultation is an offer, never auto" || bad "C2 offer-not-auto rail missing"

echo "── D: generate-intent consumption ──"
grep -q "decisions/ADR-\*.md" "$GI" && grep -q "Status: accepted" "$GI" && ok "D1 SKILL names accepted-ADR consumption" || bad "D1 SKILL consumption line missing"
grep -q "plugins/mega-sdd/references/architecture-advisor.md" "$GI" && ok "D2 SKILL routes to the ref (kb-submode's sibling pointer is legal)" || bad "D2 SKILL route missing — sibling pointer would be the only route"
grep -q "decisions/ADR-\*.md" "$KS" && grep -q "NEVER consumed as a decision" "$KS" && ok "D3 kb-submode: accepted consumed, proposed -> OQ" || bad "D3 kb-submode item missing/incomplete"

echo; [ $err -eq 0 ] && { echo "test-advisor-wired: ALL PASS"; exit 0; } || { echo "test-advisor-wired: FAILED"; exit 1; }
