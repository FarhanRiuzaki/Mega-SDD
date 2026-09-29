#!/usr/bin/env bash
# Pin: the L0 code gates are wired into the skill surfaces.
set -u
err=0
cg="plugins/mega-sdd/skills/execute-bolts/references/code-gates.md"
sk="plugins/mega-sdd/skills/execute-bolts/SKILL.md"
dp="plugins/mega-sdd/scripts/derive-exec-plan.sh"
pc="plugins/mega-sdd/references/project-config.md"
tm="plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml"
tpl="plugins/mega-sdd/references/framework-conventions/_template.md"

[ -f "$cg" ] || { echo "missing code-gates.md"; err=1; }
if [ -f "$cg" ]; then
  for t in secret_in_code sast_critical_finding dep_not_found detect-toolchain "never impose" "l0-results.json"; do
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
# the inline plan writer puts the L0 wrapper in every task (the bridge's per-unit diagram that ran
# L0 before the review panel left with the retired --agents path; its last text: commit bb38ba0a)
grep -q 'run-code-gates.sh' "$dp" || { echo "derive-exec-plan.sh does not write the run-code-gates.sh step"; err=1; }
# config key + always-run carve-out documented
grep -q 'code_gates' "$pc" || { echo "project-config.md missing code_gates key"; err=1; }
# install-deps matrix carries the code-gate tools (secret + SAST). osv-scanner
# was dropped in v5.2.2 — no CVE/lockfile gate consumes it (see the deps audit);
# gate 5 dep-existence uses python3 urllib, not an installed tool.
for t in semgrep gitleaks; do
  grep -q "id: $t" "$tm" || { echo "tool-matrix missing $t"; err=1; }
done
# pack template documents the optional Toolchain override
grep -q '## Toolchain' "$tpl" || { echo "_template.md missing Toolchain section"; err=1; }
exit $err
