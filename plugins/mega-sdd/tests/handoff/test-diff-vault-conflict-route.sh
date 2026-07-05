#!/usr/bin/env bash
# test-diff-vault-conflict-route.sh — pins the diff-vault halted-`diff_conflict`
# next_action ROUTE.
#
# A halted diff_conflict (a Resolved-OQ [x] vs new PRD contradiction whose content
# lives ONLY in VAULT-DIFF.md) is resolved by RE-INVOKING diff-vault WITHOUT --auto
# (interactive Step 5 walkthrough — diff-vault/references/auto-and-chain.md, the
# blocker-envelope resolution note; handoff-contract.md:7 skill-ref precedence +
# §Anti-halu invariants "Skills MUST emit next_action even on halted — it should
# point to the resolution path"). resolve-oq CANNOT consume it: resolve-oq walks only [ ] OQ
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

# ── Assertion C (handoff-contract): diff-vault routing row includes diff-vault ──
# handoff-contract's per-skill section is a one-row-per-producer routing table
# (M-02 ownership flip); extract the diff-vault ROW and assert its route enum
# offers mega-sdd:diff-vault (the halted diff_conflict re-invoke).
DV_BLOCK="$(grep -E '^\| `diff-vault` \|' "$CONTRACT")"
[ -n "$DV_BLOCK" ] || { echo "FAIL: could not extract the diff-vault routing row from $CONTRACT"; exit 1; }
if printf '%s\n' "$DV_BLOCK" | grep -q 'mega-sdd:diff-vault'; then
  pass "C: handoff-contract diff-vault row includes mega-sdd:diff-vault (halted diff_conflict route)"
else
  fail "C: handoff-contract diff-vault row omits mega-sdd:diff-vault"
fi

# ── Assertion D (handoff-contract): diff-vault enum names orchestrate-flow (clean) ──
# Parity with auto-and-chain branch (c): after a CLEAN vault-diff apply the enum's
# clean-apply slot must name mega-sdd:orchestrate-flow (it re-inspects CWD + re-plans —
# subsuming bind-codebase for brownfield and the ONLY valid hop for a greenfield vault
# where bind-codebase is inapplicable), NOT bind-codebase. auto-and-chain.md is
# diff-vault's OWN handoff reference → operative per §Precedence :7; this INDEX mirrors it.
if printf '%s\n' "$DV_BLOCK" | grep -q 'mega-sdd:orchestrate-flow'; then
  pass "D: handoff-contract diff-vault row names mega-sdd:orchestrate-flow for the clean-apply route (parity with auto-and-chain branch (c))"
else
  fail "D: handoff-contract diff-vault row omits mega-sdd:orchestrate-flow — clean-apply route must mirror auto-and-chain branch (c), not bind-codebase"
fi

# ── Assertion E (handoff-contract): diff-vault enum drops the stale bind-codebase ───
# bind-codebase hardcodes a brownfield assumption (wrong for a greenfield vault);
# orchestrate-flow subsumes it. The diff-vault row carries NO bind-codebase reference,
# so its absence from the whole row is unambiguous drift removal.
if printf '%s\n' "$DV_BLOCK" | grep -q 'mega-sdd:bind-codebase'; then
  fail "E: handoff-contract diff-vault row still names mega-sdd:bind-codebase — clean-apply route drifted from auto-and-chain (orchestrate-flow)"
else
  pass "E: handoff-contract diff-vault row no longer names mega-sdd:bind-codebase (drift removed)"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "test-diff-vault-conflict-route: ALL PASS"
  exit 0
else
  echo "test-diff-vault-conflict-route: $fails FAILURE(S)"
  exit 1
fi
