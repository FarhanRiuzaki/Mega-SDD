#!/usr/bin/env bash
# test-resolve-oq-kb.sh — 7.21.0 (spec 2026-09-02-kb-oq-resolution-and-human-language.md).
#
# Field bug: "hasil generate KB ga bisa di-resolve-oq" — the designed KB→vault
# hop was a dead end at KB stage. Ships: resolve-oq KB mode (walk PRD-kontrak §6
# right after extract) + the human-first OQ language contract (team: "bahasa OQ
# seperti alien"). Pins:
#   A  resolve-oq KB mode: 4-path detection, §6 walk, no-derive, marker formats,
#      the claim-stays-[OPEN] honesty rail, vault-wins precedence
#   B  reachability: KB triggers in the always-loaded description
#   C  kb-submode routing: resolved §6 → vault OQ born pre-resolved
#   D  extract hand-off offers answering now (offer only, never auto-invoke)
#   E  output-language §OQ authoring: human-first contract + the ❌/✅ pair
#   F  authoring surfaces point at the ONE contract home (no restatement)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RO="$ROOT/plugins/mega-sdd/skills/resolve-oq/SKILL.md"
KS="$ROOT/plugins/mega-sdd/skills/generate-intent/references/kb-submode.md"
EX="$ROOT/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
OL="$ROOT/plugins/mega-sdd/references/output-language.md"
PT="$ROOT/plugins/mega-sdd/skills/extract-intelligence/references/prd-kontrak-template.md"
VC="$ROOT/plugins/mega-sdd/skills/generate-intent/references/vault-core.md"
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

echo "── A: resolve-oq KB mode ──"
grep -q "## KB mode" "$RO" && ok "A1 KB mode section exists" || bad "A1 section missing"
grep -q ".mega-sdd/knowledge-base/README.md" "$RO" && grep -q "old-reference/knowledge-base/" "$RO" \
  && ok "A2 detection follows the kb-submode 4-path priority" || bad "A2 detection paths missing"
grep -q "## 6. Open Questions" "$RO" && grep -qF 'modules/*.prd.md' "$RO" && ok "A3 walk source = §6 per module PRD" || bad "A3 §6 walk missing"
grep -q "NO derive-vault-json run" "$RO" && ok "A4 no-derive rule explicit (KB has no vault.json)" || bad "A4 no-derive rule missing"
grep -qF '[x] → Resolved (stakeholder, <YYYY-MM-DD>): <answer>' "$RO" && ok "A5 resolve marker carries stakeholder provenance" || bad "A5 provenance marker missing"
grep -q "STAYS \`\[OPEN\]\`" "$RO" && grep -q "NEVER flip a claim" "$RO" \
  && ok "A6 honesty rail: claim rows never flip off a stakeholder answer" || bad "A6 honesty rail missing"
grep -q "A vault always wins when both exist" "$RO" && ok "A7 vault-wins precedence" || bad "A7 precedence missing"
grep -q "## Resolution rounds" "$RO" && ok "A8 round recorded in KB README" || bad "A8 round record missing"

echo "── B: reachability ──"
desc=$(sed -n '/^description:/p' "$RO")
echo "$desc" | grep -q "jawab OQ hasil extract" && echo "$desc" | grep -q "resolve oq kb" \
  && ok "B1 KB triggers live in the always-loaded description" || bad "B1 KB triggers missing"

echo "── C: kb-submode routing ──"
grep -q "Vault OQ born PRE-RESOLVED" "$KS" && ok "C1 resolved §6 → pre-resolved vault OQ row" || bad "C1 routing row missing"
grep -qF 'a §6 `[~]` carries over as out-of-scope' "$KS" && ok "C2 out-of-scope carry" || bad "C2 OOS carry missing"

echo "── D: extract hand-off offer ──"
grep -q "Mau jawab OQ-nya sekarang" "$EX" && ok "D1 hand-off offers KB-mode resolution" || bad "D1 offer missing"
grep -q "offer only, never auto-invoke" "$EX" && ok "D2 offer never auto-invokes" || bad "D2 auto-invoke guard missing"

echo "── E: human-first OQ contract ──"
grep -q "## OQ authoring — human-first" "$OL" && ok "E1 contract section exists" || bad "E1 section missing"
grep -q "TANPA buka kode" "$OL" && grep -q "TIDAK BOLEH jadi subjek kalimat" "$OL" \
  && ok "E2 answerable-without-code + jargon-not-subject rules" || bad "E2 core rules missing"
grep -q "grace_period NULL fallback semantics" "$OL" && grep -q "denda mulai dihitung dari hari ke berapa" "$OL" \
  && ok "E3 the ❌/✅ pair is pinned" || bad "E3 example pair missing"
grep -q "Tier-1 (English verbatim, tak berubah)" "$OL" && ok "E4 Tier-1 tokens untouched" || bad "E4 Tier-1 carve-out missing"

echo "── F: single contract home, pointers only ──"
grep -q "output-language.md §OQ authoring" "$PT" && ok "F1 template §6 points at the contract" || bad "F1 template pointer missing"
grep -q "output-language.md §OQ authoring" "$VC" && grep -q "do not restate it here" "$VC" \
  && ok "F2 vault-core points, does not restate" || bad "F2 vault-core pointer missing"

echo "── G: human framing at the walk DISPLAY layer (7.21.1 amendment) ──"
IW="$ROOT/plugins/mega-sdd/skills/resolve-oq/references/interactive-walk.md"
RC="$ROOT/plugins/mega-sdd/skills/resolve-oq/references/recommendation-context.md"
grep -q "Konteks: {1–2 kalimat" "$IW" && grep -q "Maksudnya: {apa yang SEBENARNYA diminta" "$IW" \
  && ok "G1 Step 2a opens with Konteks + Maksudnya" || bad "G1 framing lines missing"
grep -q "detail teknis" "$IW" && grep -q "Teks asli: {full question text verbatim" "$IW" \
  && ok "G2 technical block demoted, stored text quoted verbatim" || bad "G2 technical demotion missing"
grep -q "Translate, never rewrite" "$IW" && ok "G3 display translates, artifact never silently rewritten" || bad "G3 translate-not-rewrite rule missing"
grep -q "No invented facts" "$IW" && grep -q "belum ketahuan dari kode" "$IW" \
  && ok "G4 framing bound by the no-invention rail" || bad "G4 no-invention framing rule missing"
grep -q "Meaning-first narration (7.21.1)" "$RC" && grep -q "never a bare citation dump" "$RC" \
  && ok "G5 probe/rationale narration is meaning-first" || bad "G5 meaning-first invariant missing"
grep -q "Verbatim is necessary but NOT sufficient (7.21.1)" "$OL" \
  && ok "G6 keterangan contract rule 1 extended" || bad "G6 keterangan extension missing"
grep -q "human-framed first (7.21.1)" "$RO" && ok "G7 SKILL Step 2 routes the framing" || bad "G7 SKILL routing missing"
grep -q "never truncated/garbled labels" "$IW" && ok "G8 full option labels pinned" || bad "G8 label rule missing"

echo; [ $err -eq 0 ] && { echo "test-resolve-oq-kb: ALL PASS"; exit 0; } || { echo "test-resolve-oq-kb: FAILED"; exit 1; }
