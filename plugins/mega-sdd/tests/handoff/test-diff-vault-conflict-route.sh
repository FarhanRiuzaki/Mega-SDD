#!/usr/bin/env bash
# test-diff-vault-conflict-route.sh — pins the diff-vault halted-`diff_conflict`
# next_action ROUTE.
#
# A halted diff_conflict (a Resolved-OQ [x] vs new PRD contradiction whose content
# lives ONLY in VAULT-DIFF.md) is resolved by RE-INVOKING diff-vault WITHOUT --auto
# (interactive Step 5 walkthrough — diff-vault/references/auto-and-chain.md, the
# blocker-envelope resolution note; handoff-contract.md:7 skill-ref precedence +
# :748 "Skills MUST emit next_action even on halted — it should point to the
# resolution path"). resolve-oq CANNOT consume it: resolve-oq walks only [ ] OQ
# entries (SKILL.md) and reads vault docs 00-06, never VAULT-DIFF.md. resolve-oq
# stays the correct route for the SEPARATE completed + NEW-[ ]-OQ outcome
# (diff-vault materializes OQ-{CODE}-{N+1} rows the [ ]-walk can consume).
#
# Static doc-parity grep test. CI-safe: bash + awk + grep only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CHAIN="${PLUGIN_ROOT}/skills/diff-vault/references/auto-and-chain.md"
CONTRACT="${PLUGIN_ROOT}/skills/orchestrate-flow/references/handoff-contract.md"

for f in "$CHAIN" "$CONTRACT"; do
  [ -f "$f" ] || { echo "FAIL: not found: $f"; exit 1; }
done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# ── Assertion A (auto-and-chain): diff-vault IS a next_action route ────────────
# The interactive re-invoke branch must exist as suggested_skill: mega-sdd:diff-vault.
if grep -q 'suggested_skill: mega-sdd:diff-vault' "$CHAIN"; then
  pass "A: auto-and-chain routes halted diff_conflict to 'suggested_skill: mega-sdd:diff-vault' (interactive re-invoke, no --auto)"
else
  fail "A: no 'suggested_skill: mega-sdd:diff-vault' in auto-and-chain.md — halted diff_conflict must re-invoke diff-vault (no --auto)"
fi

# ── Assertion B (auto-and-chain): resolve-oq is NOT the diff_conflict route ─────
# The resolve-oq suggested_skill line must be scoped to the new-OQ/completed case,
# never the conflict. grep is anchored on the literal `suggested_skill:
# mega-sdd:resolve-oq`, so branch (a)'s explanatory "resolve-oq CANNOT ..." prose
# on the diff-vault line does not match.
if grep 'suggested_skill: mega-sdd:resolve-oq' "$CHAIN" | grep -qi 'conflict'; then
  fail "B: a 'suggested_skill: mega-sdd:resolve-oq' line still names the conflict case — resolve-oq cannot consume a VAULT-DIFF.md diff_conflict"
else
  pass "B: resolve-oq route is scoped to the new-OQ/completed case, not the conflict"
fi

# ── Assertion C (handoff-contract): diff-vault block enum includes diff-vault ───
# Extract the ### `diff-vault` block; assert its suggested_skill enum offers
# mega-sdd:diff-vault. (emitted_by: diff-vault has no mega-sdd: prefix → no false match.)
DV_BLOCK="$(awk '
  /^### `diff-vault`/ {inblk=1; next}
  /^### / {if (inblk) inblk=0}
  inblk {print}
' "$CONTRACT")"
[ -n "$DV_BLOCK" ] || { echo "FAIL: could not extract §diff-vault block from $CONTRACT"; exit 1; }
if printf '%s\n' "$DV_BLOCK" | grep -q 'mega-sdd:diff-vault'; then
  pass "C: handoff-contract §diff-vault enum includes mega-sdd:diff-vault (halted diff_conflict route)"
else
  fail "C: handoff-contract §diff-vault enum omits mega-sdd:diff-vault"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "test-diff-vault-conflict-route: ALL PASS"
  exit 0
else
  echo "test-diff-vault-conflict-route: $fails FAILURE(S)"
  exit 1
fi
