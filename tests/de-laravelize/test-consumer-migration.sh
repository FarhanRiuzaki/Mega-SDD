#!/usr/bin/env bash
set -u
err=0
# 9.0 (P1): the classic generate-units + scan-codebase skills were deleted.
#   - generate-units/references/starterkit-derivation.md (Step 7.7) was DROPPED, not relocated
#     (v9 design §7 decision 1: deep-scan was its only producer) -> its checks are retired.
#   - scan-codebase/references/{deep-scan-gate,deep-scan-dispatch,halts-flags-handoff}.md were
#     deleted with the skill (no deep-scan remains) -> retired.
#   - generate-units/references/auto-and-memory.md was relocated into
#     plan/references/unit-procedure.md -> the OLD-ontology guard is repointed there.
# P3 C5: execute-bolts bolt-dispatch-prompt.md + context-enrichment.md were deleted with the builder -> retired.
# 9.0 (P1b): references/lib-patterns/ was deleted (no surviving consumer) -> its rbac-libs.md entry is retired.
files=(
  "plugins/mega-sdd/skills/plan/references/unit-procedure.md"
  "plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
  "plugins/mega-sdd/skills/execute-bolts/references/halts-and-handoff.md"
  "plugins/mega-sdd/references/model-tiers.md"
)
for f in "${files[@]}"; do
  # A missing file would make the negative grep below pass vacuously.
  [ -f "$f" ] || { echo "MISSING consumer file $f"; err=1; continue; }
  if grep -nE 'rbac\.lib *== *"spatie/permission"|rbac\.middleware|rbac\.gates|rbac\.policies|auth\.guard|starterkit_context\.rbac|slice\.rbac|rbac_lib|§rbac\b|rbac-extractor|^[[:space:]]*rbac:' "$f"; then
    echo "OLD ontology read in $f"; err=1
  fi
done
exit $err
