#!/usr/bin/env bash
# test-sync-conflict-revalidate.sh — pins the living-vault S4 moat invariant:
# claim-scoped re-bind (--paths) must NEVER carry an active CONFLICT forward
# silently — active CONFLICTs are always re-validated and always re-surface as
# canonical headings the gate/validators read. Prose-pin across the 3 files
# that define the contract; a future cull that drops the rule fails this test.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../.."
rc=0

pin() {  # pin <file> <required-pattern> <label>
  if grep -qiE "$2" "$PLUGIN/$1" 2>/dev/null; then
    echo "PASS ($3)"
  else
    echo "FAIL ($3 — pattern missing in $1)"; rc=1
  fi
}

pin "skills/bind-codebase/references/binding-contract.md" \
    "every ACTIVE CONFLICT from the previous binding regardless of path intersection" \
    "contract: active conflicts always re-selected"
pin "skills/bind-codebase/references/binding-contract.md" \
    "carried-forward verdict is never silently upgraded or downgraded" \
    "contract: carry-forward immutability"
pin "skills/bind-codebase/references/binding-contract.md" \
    "no \`bound/\` while any conflict" \
    "contract: gate unchanged in --paths mode"
pin "skills/bind-codebase/SKILL.md" \
    "active CONFLICTs are ALWAYS re-validated, never carried silently" \
    "SKILL flag text carries the invariant"
pin "skills/orchestrate-flow/references/routing-rules.md" \
    "bind-codebase --paths=@" \
    "Mode D chain uses claim-scoped re-bind"
pin "skills/generate-units/references/task-typing.md" \
    "dedup_ambiguous\` halt, never a guess" \
    "reconcile: ambiguity halts, never guesses"

[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
