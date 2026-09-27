#!/usr/bin/env bash
# test-sync-conflict-revalidate.sh — pins the living-vault S4 moat invariant:
# the claim-scoped re-bind hop of the sync lane (--paths) must NEVER carry an
# active CONFLICT forward silently, and the CONFLICT gate is unchanged in that
# scoped mode. Prose-pin across the files that define the surviving contract;
# a future cull that drops the rule fails this test.
#
# 9.0 P1 (design docs/superpowers/specs/2026-09-27-v9-simplification-design.md
# §2, §3, §7 #5/#9): skills/bind-codebase (its `--paths` mode, SKILL flag text
# and references/binding-contract.md) and skills/generate-units were deleted.
# The re-bind hop is now per unit — `scripts/rebind-units.sh --paths=@…`
# re-verdicts every claim of each affected unit with the SAME JIT writer
# (`write-unit-binding.sh`); there is no whole-vault binding.md to carry
# verdicts into. So:
#   RETIRED  the binding-contract.md pins "every ACTIVE CONFLICT from the
#            previous binding regardless of path intersection" and
#            "carried-forward verdict is never silently upgraded or
#            downgraded" — both described how a partial whole-vault bind
#            selected/carried claims into a new binding.md; that mechanism no
#            longer exists (a non-affected unit's own bolts/U-XXX/binding.json
#            is left untouched and the dispatch gate reads it as-is).
#   REPOINTED the gate-unchanged, never-carried-silently, Mode D hop and
#            reconcile no-guess rules to their surviving homes (below).
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

# gate unchanged in --paths mode (was: binding-contract.md "no `bound/` while
# any conflict") — the scoped re-bind hop closes the gate exactly as dispatch does.
pin "skills/orchestrate-flow/references/routing-rules.md" \
    "a CONFLICT closes the gate for the affected units exactly as at dispatch" \
    "Mode D re-bind hop: gate unchanged in --paths mode"
pin "commands/sync.md" \
    "The binding CONFLICT gate applies unchanged — sync never bypasses the moat" \
    "sync lane: CONFLICT gate applies unchanged"
# the invariant itself, on the surviving --paths flag text (was: bind-codebase SKILL.md)
pin "commands/sync.md" \
    "rebind-units\.sh --cwd=<root> --vault=<vault> --paths=@<vault>/\.sync-changed-paths\.txt\` re-verdicts, with the SAME JIT writers" \
    "sync re-bind hop re-verdicts with the JIT writers"
# 9.0: the re-bind hop re-verdicts only the AFFECTED units (rebind-units.sh processes the
# intersecting set). The classic wording "active CONFLICTs always re-validated" was never
# true of that script; the invariant that matters is that an unresolved CONFLICT outside
# the changed set is never carried silently: it still closes that unit's gate at dispatch.
pin "commands/sync.md" \
    "an unresolved CONFLICT there still closes that unit's gate at dispatch \(invariant #2\)" \
    "sync flag text carries the invariant (unaffected CONFLICTs stay gated)"
# Mode D chain keeps the claim-scoped re-bind hop (was: bind-codebase --paths=@)
pin "skills/orchestrate-flow/references/routing-rules.md" \
    "scripts/rebind-units\.sh --cwd=\. --vault=<vault> --paths=@<vault>/\.sync-changed-paths\.txt\` → \`plan --reconcile\`" \
    "Mode D chain uses claim-scoped re-bind"
# reconcile no-guess rail (was: generate-units/references/task-typing.md)
pin "skills/plan/references/task-typing.md" \
    "dedup_ambiguous\` halt, never a guess" \
    "reconcile: ambiguity halts, never guesses"

[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
