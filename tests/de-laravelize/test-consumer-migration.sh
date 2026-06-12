#!/usr/bin/env bash
set -u
err=0
files=(
  "plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md"
  "plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md"
  "plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md"
  "plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
  "plugins/mega-sdd/skills/scan-codebase/references/deep-scan-stage.md"
  "plugins/mega-sdd/skills/generate-units/references/auto-and-memory.md"
  "plugins/mega-sdd/skills/execute-bolts/references/halts-and-handoff.md"
  "plugins/mega-sdd/skills/scan-codebase/references/halts-flags-handoff.md"
  "plugins/mega-sdd/references/model-tiers.md"
  "plugins/mega-sdd/references/lib-patterns/laravel/rbac-libs.md"
)
for f in "${files[@]}"; do
  if grep -nE 'rbac\.lib *== *"spatie/permission"|rbac\.middleware|rbac\.gates|rbac\.policies|auth\.guard|starterkit_context\.rbac|slice\.rbac|rbac_lib|§rbac\b|rbac-extractor|^[[:space:]]*rbac:' "$f"; then
    echo "OLD ontology read in $f"; err=1
  fi
done
grep -q 'authz\.declarations\|authz\.mechanism' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "starterkit-derivation does not read authz ontology"; err=1; }
grep -q 'authz\.mechanism\|authz\.declarations\|Authz:' plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md || { echo "bolt-dispatch missing Authz line"; err=1; }
grep -q 'authz\.mechanism\|authz\.declarations\|Authz:' plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md || { echo "context-enrichment missing Authz line"; err=1; }
exit $err
