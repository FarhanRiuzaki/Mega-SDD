#!/usr/bin/env bash
# Audit Phase 2a — WHEN-triggered reference loading (spec: commit de412367).
# Pins: every targeted pointer carries its deterministic load condition; the inline
# skeletons are declared authoritative; moat-commanded reads stay UNCONDITIONAL.
# 9.0 (P1): generate-intent / generate-units / scan-codebase / bind-codebase were removed
# (spec 2026-09-27-v9-simplification-design.md §2/§3). Their surviving WHEN-conditions moved
# with their contracts: the unit walk -> skills/plan/references/unit-procedure.md, the vault
# drafting core -> references/vault-core.md (read by plan SKILL per section), the content rules
# -> skills/plan/references/context-authoring.md, the E3 bind ladder ->
# skills/execute-bolts/references/jit-bind-and-quarantine.md. Pins on the removed skills'
# own flags/files (--scan starterkit overlay, the generation-guide design-system read gate,
# the layout-2 per-file template roster, the Step-0.5 map/binding probe, the scan-codebase
# §Incremental-mode sync hop) are retired with them.
# Run: bash tests/surface/test-p10-when-triggered-refs.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

OF="$P/skills/orchestrate-flow/SKILL.md"
PL="$P/skills/plan/SKILL.md"
UP="$P/skills/plan/references/unit-procedure.md"
CA="$P/skills/plan/references/context-authoring.md"
EB="$P/skills/execute-bolts/SKILL.md"

# ── D1 — orchestrate-flow ──
if ! grep -q 'Iter classifier EP' "$OF" && grep -q 'REMOVED (v7 Fase 2)' "$P/skills/orchestrate-flow/references/chain-execution.md"; then
  pass "D1: EP1/EP2 gone from the SKILL body; chain-execution records the v7 removal"
else fail "D1: dead iter-classifier steps survive in the SKILL (or removal note lost)"; fi
grep -qF 'ONLY when an overlay applies' "$OF" \
  && grep -qF 'IS the default chain' "$OF" \
  && pass "D1b: Step 4 declares the engine authoritative; routing-rules is overlay-only" \
  || fail "D1b: Step-4 overlay condition missing"
grep -qF 'validate-preflight.sh --predictive' "$OF" \
  && grep -qF 'never to hand-run the loop' "$OF" \
  && grep -qF '§Cold-halt anticipation set whenever `execute-bolts` is chained' "$OF" \
  && pass "D1c: predictive preflight is script-run (2b S1 wiring; catalog = maintainer source of truth)" \
  || fail "D1c: predictive-preflight script wiring missing"
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

# ── D2 — plan (generate-intent's successor for PRD/KB -> vault) ──
# Retired: the vault-contract.md `§Starterkit-binding ONLY under --scan` overlay (starterkit
# authoring dropped from plan, spec §7 #1; --scan left with scan-codebase).
n_vc=$(grep -o 'vault-core\.md' "$PL" | wc -l | tr -d ' ')
n_vc_sec=$(grep -oE 'vault-core\.md`? \(?§' "$PL" | wc -l | tr -d ' ')
grep -qF '`plugins/mega-sdd/references/vault-core.md §OQ-conventions`' "$PL" \
  && grep -qF '`vault-core.md §constitution`' "$PL" \
  && [ "$n_vc" -ge 1 ] && [ "$n_vc" = "$n_vc_sec" ] \
  && pass "D2: vault-core read is section-named at every plan pointer ($n_vc_sec/$n_vc)" \
  || fail "D2: vault-core commanded whole somewhere in plan SKILL (sectioned $n_vc_sec of $n_vc)"
# D2b retired: the generation-guide design-system read gate (`ONLY when a Step-2 HAS_* flag is
# set`) conditioned a file that no longer exists; its successor context-authoring.md is read
# whole at Step 3 and keeps the design rules source-gated on the HAS_* flags inside.
grep -qF 'the layout-3 template (read before Step 3)' "$PL" \
  && grep -qF 'never hand-write `vault.json`' "$PL" \
  && ! ls "$P/skills/plan/references/templates/" | grep -q 'vault\.json' \
  && pass "D2c: template read keyed to the step drafting that file; vault.json has NO template (script-derived)" \
  || fail "D2c: template read unconditional, or a phantom vault.json scaffold appeared"
grep -qF '/ `oq_recommend_citation_invalid` /' "$PL" \
  && pass "D2d: plan halt roster carries oq_recommend_citation_invalid" \
  || fail "D2d: halt roster still missing the validator-fired type"

# ── D3 — plan unit walk (generate-units' successor) ──
grep -qF 'the unit walk is `references/unit-procedure.md`' "$PL" \
  && grep -qF 'the inline skeleton is authoritative for the unambiguous path' "$UP" \
  && pass "D3: plan Step 4 loads the unit walk; its loading contract keeps the inline skeleton authoritative" \
  || fail "D3: contract sentence missing (or plan no longer routes Step 4 to unit-procedure)"
# Retired: the Step-0.5 `ONLY when a probe is missing/stale/contradictory` gate (it probed the
# classic codebase-map.md / binding.md, which plan never reads). The task-typing condition moved
# from binding State-Map rows to symbol-index hits (plan types from the symbol index).
grep -qF 'open it ONLY when a symbol-index hit types a candidate `verify`/`extend` or a 7.6 collision fires' "$UP" \
  && grep -qF 'ONLY when a pass fires' "$UP" \
  && grep -qF 'whenever auto-deriving `.auto`' "$UP" \
  && grep -qF 'inline Step-2.5 rules' "$UP" \
  && pass "D3b: validation/modules/task-typing reads carry their conditions" \
  || fail "D3b: a unit-walk WHEN condition is missing"
grep -qF '(h) PBT properties citation check' "$UP" \
  && pass "D3d: 12.5.h no-fabrication rail in the authoritative inline list" \
  || fail "D3d: 12.5.h missing from the inline list"
grep -qF 'stay unconditional — they are the authoring contract' "$UP" \
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

# D5/D5b retired: the scan-codebase §Incremental-mode sync hop left with scan-codebase; the sync
# lane's changed set is now the zero-token derive-changed-paths.sh (commands/sync.md step 2).

# ── D6 — extract grammar-reference read scoping (wave split's successor) ──
grep -qF '§README roll-up + §data-mutation-policy at synthesis' "$P/skills/extract-intelligence/SKILL.md" \
  && pass "D6: grammar-reference read scoped (dispatch sections up front, synthesis sections at synthesis)" \
  || fail "D6: grammar-reference read scoping missing"

# ── Moat reads stay unconditional ──
grep -qF '**12.5 Polished-prompt render pass.** Validate the prompt-shape contract per `references/unit-schema.md`' "$UP" \
  && [ -f "$P/skills/plan/references/unit-schema.md" ] \
  && pass "M1: unit-schema still commanded at the 12.5 render pass (and resolves under plan/)" \
  || fail "M1: unit-schema command lost"
grep -qF 'runs on every run' "$EB" \
  && grep -qF 'Read `references/jit-bind-and-quarantine.md §3.9`' "$EB" \
  && grep -qF '`text` claims via ladder E3 verbatim' "$EB" \
  && grep -q '^## E3 Text-claim ladder' "$P/skills/execute-bolts/references/jit-bind-and-quarantine.md" \
  && pass "M2: the E3 bind ladder (ex express-bind) is commanded on every execute-bolts run" \
  || fail "M2: JIT-bind / E3 ladder command lost"
grep -qF 'READ FIRST: <plugin-root>/skills/extract-intelligence/references/prd-kontrak-template.md' "$P/skills/extract-intelligence/references/prd-kontrak-template.md" \
  && pass "M3: grammar-reference READ-FIRST in the dispatch core untouched" \
  || fail "M3: grammar-reference read weakened"
if ! grep -q 'regardless of classifier' "$P/commands/mega-sdd.md" \
   && grep -qF 'the automatic iter classifier was REMOVED' "$P/commands/mega-sdd.md"; then
  pass "M4: front-door flag texts stop claiming the parked classifier runs (round fold)"
else fail "M4: front door still sells the classifier as live"; fi
# M5: the two rosters are now plan's halt index and the halt-family registry entry; both must
# carry the type and agree it is plan's (validate-vault-oqs.sh fires it).
grep -qF '/ `oq_recommend_citation_invalid` /' "$PL" \
  && grep -qF -- '- `oq_recommend_citation_invalid` — plan' "$P/references/halt-families/intent-and-vault.md" \
  && pass "M5: plan halt roster and the halt-family registry both carry oq_recommend_citation_invalid" \
  || fail "M5: halt rosters disagree on oq_recommend_citation_invalid"
# M6: the content-rules read (successor of the generation-guide core) keeps its mandatory
# readability section; output mode is fixed (compact on layout-3), so the "active column" is stated.
grep -qF 'Content rules per section = `references/context-authoring.md` (readability' "$PL" \
  && grep -qF '## Readability standards (mandatory for `context.md`)' "$CA" \
  && grep -qF '`output_mode` is `compact` on layout-3' "$CA" \
  && pass "M6: content-rules read includes the mandatory readability section + the fixed output mode" \
  || fail "M6: content-rules read orphans a mandatory section"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
