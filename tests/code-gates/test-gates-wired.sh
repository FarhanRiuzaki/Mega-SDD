#!/usr/bin/env bash
# Pin: the L0 code gates are wired into the skill surfaces.
set -u
err=0
cg="plugins/mega-sdd/skills/execute-bolts/references/code-gates.md"
sk="plugins/mega-sdd/skills/execute-bolts/SKILL.md"
sb="plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md"
rp="plugins/mega-sdd/skills/execute-bolts/references/review-panel.md"
pc="plugins/mega-sdd/references/project-config.md"
tm="plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml"
tpl="plugins/mega-sdd/references/framework-conventions/_template.md"

[ -f "$cg" ] || { echo "missing code-gates.md"; err=1; }
if [ -f "$cg" ]; then
  for t in secret_in_code sast_critical_finding dep_not_found detect-toolchain "never impose" "Deterministic scan results"; do
    grep -qi "$t" "$cg" || { echo "code-gates.md missing: $t"; err=1; }
  done
  # the critical pair is never disableable
  grep -qiE "secret.*always run|always run.*secret" "$cg" || { echo "code-gates.md: secrets-always-run rail missing"; err=1; }
fi
# SKILL routes the ref + the opt-out flag with the always-run carve-out
if [ -f "$sk" ]; then
  grep -q 'references/code-gates.md' "$sk" || { echo "SKILL.md does not route code-gates.md"; err=1; }
  grep -q -- '--no-code-gates' "$sk" || { echo "SKILL.md missing --no-code-gates flag"; err=1; }
  grep -qi 'ALWAYS run' "$sk" || { echo "SKILL.md missing secrets/dep always-run carve-out"; err=1; }
fi
# bridge diagram runs L0 BEFORE the panel
if [ -f "$sb" ]; then
  grep -q 'L0 code gates' "$sb" || { echo "bridge missing L0 step"; err=1; }
  # FIRST occurrence: S7-C added a re-dispatch back-reference to the L0 box in the
  # merge branch (below tier selection); the structural claim is about the box itself.
  awk '/RUN L0 code gates/{if(!l0)l0=NR} /SELECT panel tier/{if(!p)p=NR} END{exit !(l0 && p && l0<p)}' "$sb" \
    || { echo "bridge: L0 must run before panel tier selection"; err=1; }
fi
# panel prompts carry the L0 results
grep -q 'Deterministic scan results' "$rp" || { echo "review-panel.md missing L0 injection"; err=1; }
# config key + always-run carve-out documented
grep -q 'code_gates' "$pc" || { echo "project-config.md missing code_gates key"; err=1; }
# install-deps matrix carries the three tools
for t in semgrep gitleaks osv-scanner; do
  grep -q "id: $t" "$tm" || { echo "tool-matrix missing $t"; err=1; }
done
# pack template documents the optional Toolchain override
grep -q '## Toolchain' "$tpl" || { echo "_template.md missing Toolchain section"; err=1; }
exit $err
