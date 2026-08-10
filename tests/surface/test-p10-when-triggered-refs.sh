#!/usr/bin/env bash
# Audit Phase 2a — WHEN-triggered reference loading (spec 2026-08-10-audit-phase2-when-triggered-refs.md).
# Pins: every targeted pointer carries its deterministic load condition; the inline
# skeletons are declared authoritative; moat-commanded reads stay UNCONDITIONAL.
# Run: bash tests/surface/test-p10-when-triggered-refs.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

OF="$P/skills/orchestrate-flow/SKILL.md"
GI="$P/skills/generate-intent/SKILL.md"
GU="$P/skills/generate-units/SKILL.md"

# ── D1 — orchestrate-flow ──
if ! grep -q 'Iter classifier EP' "$OF" && grep -q 'PARKED' "$P/skills/orchestrate-flow/references/chain-execution.md"; then
  pass "D1: EP1/EP2 gone from the SKILL body; chain-execution keeps the PARKED note"
else fail "D1: dead iter-classifier steps survive in the SKILL (or PARKED note lost)"; fi
grep -qF 'ONLY when an overlay applies' "$OF" \
  && grep -qF 'IS the default chain' "$OF" \
  && pass "D1b: Step 4 declares the engine authoritative; routing-rules is overlay-only" \
  || fail "D1b: Step-4 overlay condition missing"
grep -qF 'ONLY the §sections of skills actually in the proposed chain' "$OF" \
  && grep -qF '§Cold-halt anticipation checks whenever `execute-bolts` is chained' "$OF" \
  && pass "D1c: predictive-checks read is chain-scoped (+Cold-halt carve-out, round fold)" \
  || fail "D1c: predictive-checks condition or Cold-halt carve-out missing"
grep -qF 'b.iv conditional-field check' "$OF" \
  && grep -qF 'or for §Resume mechanics' "$OF" \
  && pass "D1d: handoff-contract WHEN carries the b.iv + resume carve-outs (round fold)" \
  || fail "D1d: handoff-contract condition missing its carve-outs"
grep -qF 'Open ONLY on a Step-4 overlay' "$OF" \
  && pass "D1e: §Specialist entry for routing-rules carries its WHEN annotation" \
  || fail "D1e: specialist-list WHEN annotation missing"
grep -qF 'gating is flag-driven' "$OF" \
  && pass "D1f: Plan/Act gating honest about the PARKED classifier" \
  || fail "D1f: Plan/Act still keyed on the parked classifier"

# ── D2 — generate-intent ──
grep -qF '§schema + §OQ-conventions' "$GI" \
  && grep -qF '§Starterkit-binding ONLY under `--scan`' "$GI" \
  && pass "D2: vault-contract read is section-named with conditional sections" \
  || fail "D2: vault-contract still commanded whole"
grep -qF 'ONLY when a Step-2 `HAS_*` flag is set' "$GI" \
  && pass "D2b: generation-guide design-system read is flag-conditioned (output-mode reads the active column — M6)" \
  || fail "D2b: generation-guide conditions missing"
grep -qF 'ONLY the template for the file currently being drafted' "$GI" \
  && grep -qF 'has NO template' "$GI" \
  && ! grep -qF 'scaffolds for each of the 7 files + `vault.json`' "$GI" \
  && pass "D2c: per-file template reads + phantom vault.json scaffold claim gone" \
  || fail "D2c: template roster still wrong or unconditional"
grep -qF 'oq_recommend_citation_invalid' "$GI" \
  && pass "D2d: halt roster carries oq_recommend_citation_invalid" \
  || fail "D2d: halt roster still missing the validator-fired type"

# ── D3 — generate-units ──
grep -qF 'the inline skeleton is authoritative for the unambiguous path' "$GU" \
  && pass "D3: loading contract flipped (inline skeleton authoritative)" \
  || fail "D3: contract sentence missing"
grep -qF 'ONLY when a probe is missing/stale/contradictory' "$GU" \
  && grep -qF 'ONLY when a pass fires' "$GU" \
  && grep -qF 'whenever auto-deriving `.auto`' "$GU" \
  && grep -qF 'ONLY when the State Map carries' "$GU" \
  && grep -qF 'inline Step-2.5 rules' "$GU" \
  && pass "D3b: defensive/validation/modules/task-typing reads carry their (round-folded) conditions" \
  || fail "D3b: a generate-units WHEN condition is missing"
grep -qF '(h) PBT properties citation check' "$GU" \
  && pass "D3d: 12.5.h no-fabrication rail restored to the authoritative inline list (round fold)" \
  || fail "D3d: 12.5.h missing from the inline list"
grep -qF 'stay unconditional — they are the authoring contract' "$GU" \
  && pass "D3c: unit-schema + template declared UNCONDITIONAL (moat read preserved)" \
  || fail "D3c: unconditional declaration for the authoring contract missing"

# ── D4 — resolve-oq ──
grep -qF 'Open per-OQ at slot-`[1]` build time' "$P/skills/resolve-oq/SKILL.md" \
  && grep -qF 'never pre-load it for the whole walk' "$P/skills/resolve-oq/SKILL.md" \
  && pass "D4: recommendation-context is per-OQ at build time (round-widened — walk canon preserved)" \
  || fail "D4: recommendation-context condition missing"
grep -qF 'load it before running the walk' "$P/skills/resolve-oq/SKILL.md" \
  && pass "D4b: interactive-walk stays commanded (it IS the walk)" \
  || fail "D4b: the walk read was wrongly conditionalized"

# ── D5 — scan sync hop ──
grep -qF 'read §Incremental mode plus ONLY the full-scan steps it names' "$P/skills/scan-codebase/SKILL.md" \
  && pass "D5: sync hop reads §Incremental mode + only its named dependency steps (round fold)" \
  || fail "D5: sync-hop scoped read missing"
grep -q '^## Incremental mode' "$P/skills/scan-codebase/references/scan-procedure.md" \
  && [ ! -f "$P/skills/scan-codebase/references/incremental-sync.md" ] \
  && pass "D5b: §Incremental mode stays at its original location (no file split)" \
  || fail "D5b: section moved or a split file appeared (spec says no split)"

# ── D6 — extract wave split ──
grep -qF 'read AT Wave 5, not before' "$P/skills/extract-intelligence/SKILL.md" \
  && grep -qF '§ERD Quality Rails' "$P/skills/extract-intelligence/SKILL.md" \
  && pass "D6: kb-schema read split by wave (file unchanged)" \
  || fail "D6: wave-split read instruction missing"

# ── Moat reads stay unconditional ──
grep -qF 'per `references/unit-schema.md`' "$GU" \
  && pass "M1: unit-schema still commanded at the 12.5 render pass" \
  || fail "M1: unit-schema command lost"
grep -qF 'replaced by `references/express-bind.md`' "$P/skills/bind-codebase/SKILL.md" \
  && pass "M2: express-bind procedure still commanded under --express" \
  || fail "M2: express-bind command lost"
grep -qF 'READ FIRST: <kb-dir>/.dispatch-static.md' "$P/skills/extract-intelligence/references/wave-dispatch-templates.md" \
  && pass "M3: dispatch-static READ-FIRST untouched" \
  || fail "M3: dispatch-static read weakened"
if ! grep -q 'regardless of classifier' "$P/commands/mega-sdd.md" \
   && grep -qF 'the automatic iter classifier is PARKED' "$P/commands/mega-sdd.md"; then
  pass "M4: front-door flag texts stop claiming the parked classifier runs (round fold)"
else fail "M4: front door still sells the classifier as live"; fi
n_ocv=$(grep -c 'oq_recommend_citation_invalid' "$GI")
[ "$n_ocv" -ge 2 ] \
  && pass "M5: both generate-intent halt rosters carry oq_recommend_citation_invalid (round fold)" \
  || fail "M5: twin halt rosters disagree (count: $n_ocv)"
grep -qF '§Readability standards (mandatory for all 7 files)' "$GI" \
  && grep -qF "the ACTIVE mode's column" "$GI" \
  && pass "M6: generation-guide core includes the mandatory sections + active-mode column (round fold)" \
  || fail "M6: generation-guide core still orphans a mandatory section"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
