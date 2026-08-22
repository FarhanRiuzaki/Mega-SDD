#!/usr/bin/env bash
# Wiring pins of the multi-PRD lifecycle contract.
# v7 Fase 2: build-project-index.sh (the derived project.md manifest writer) is
# DELETED — advisory artifact with no gate reader; the lifecycle contract lives
# in prose + vault dirs. Only the wiring pins below remain.
set -u
err=0

REF=plugins/mega-sdd/references/multi-prd-lifecycle.md
[ -f "$REF" ] || { echo "multi-prd-lifecycle.md missing"; err=1; }
if [ -f "$REF" ]; then
  for t in "diff-vault" "new vault" "sync" "project constitution" "when unsure" "Doc-type agnostic"; do
    grep -qi "$t" "$REF" || { echo "lifecycle ref missing: $t"; err=1; }
  done
fi
grep -q 'Multi-PRD lane' plugins/mega-sdd/skills/using-mega-sdd/SKILL.md || { echo "router not wired in using-mega-sdd"; err=1; }
grep -qi 'Project constitution gate' plugins/mega-sdd/skills/bind-codebase/SKILL.md || { echo "project-constitution gate not in bind-codebase"; err=1; }
# zero-phantom: the deleted index script must not be referenced anywhere runnable
grep -rq 'build-project-index' plugins/mega-sdd/scripts plugins/mega-sdd/hooks && { echo "phantom build-project-index reference"; err=1; }
exit $err
