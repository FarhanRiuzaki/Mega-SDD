#!/usr/bin/env bash
# test-generate-intent-map-present-route.sh — pins the generate-intent `--auto`
# handoff next_action ROUTE to be CWD-conditional on codebase-map presence.
#
# Defect (#11, LOW/self-healing): generate-intent's --auto handoff emitted
# `suggested_skill: mega-sdd:scan-codebase` for EVERY brownfield (mode=existing)
# vault, conditioned ONLY on IMPLEMENTATION_MODE, never on codebase-map presence.
# Under the LIVE scan-first brownfield reorder (routing-rules.md :110/:115),
# scan-codebase ALWAYS runs BEFORE generate-intent — generate-intent is even
# invoked WITH `--scan=<map>` — so `.mega-sdd/codebase/codebase-map.md` already
# exists when generate-intent completes. The unconditional scan-codebase route is
# therefore a BACKWARD mis-route (redundant full re-scan) instead of the forward
# generate-intent → bind-codebase the CWD matrix prescribes (routing-rules.md :55).
#
# Correct routing (grounded in the AUTHORITATIVE matrix routing-rules.md :53/:55 +
# scan-codebase's already-correct CWD-conditional mirror, halts-flags-handoff.md
# :117-122 / handoff-contract.md scan-codebase routing row):
#   mode=existing + NO codebase-map on disk → mega-sdd:scan-codebase
#   mode=existing + codebase-map PRESENT     → mega-sdd:bind-codebase   (the norm under scan-first)
#   mode=new (greenfield)                    → mega-sdd:generate-units
#
# Both surfaces MUST carry the map-present→bind branch in sync or surface-drift
# reopens the gap: the OPERATIVE emission spec
# (generate-intent/references/auto-and-handoff.md §Handoff emission) AND the
# cross-skill routing index (handoff-contract.md generate-intent row).
#
# Static doc-parity grep test (mirrors test-diff-vault-conflict-route.sh). This is
# NOT a validator invocation — a handoff emitting EITHER route parses fine; only
# the ROUTE is wrong pre-fix. CI-safe: bash + awk + grep only.
#
# RED pre-fix (map-present→bind branch absent from both surfaces);
# GREEN post-fix (present in both).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUTOHANDOFF="${PLUGIN_ROOT}/skills/generate-intent/references/auto-and-handoff.md"
CONTRACT="${PLUGIN_ROOT}/skills/orchestrate-flow/references/handoff-contract.md"

for f in "$AUTOHANDOFF" "$CONTRACT"; do
  [ -f "$f" ] || { echo "FAIL: not found: $f"; exit 1; }
done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# Extract the §Handoff emission block from auto-and-handoff.md (between its header
# and the next "## " header — §Memory layer).
GI_BLOCK="$(awk '
  /^## Handoff emission/ {inblk=1; next}
  /^## / {if (inblk) inblk=0}
  inblk {print}
' "$AUTOHANDOFF")"
[ -n "$GI_BLOCK" ] || { echo "FAIL: could not extract §Handoff emission block from $AUTOHANDOFF"; exit 1; }

# handoff-contract.md's §Per-skill expected emissions is a one-row-per-producer
# ROUTING TABLE (M-02 ownership flip — the operative emission spec is the skill's
# own reference; the contract row is the consumer-side index). Extract the
# generate-intent row.
GI_CONTRACT_BLOCK="$(grep -E '^\| `generate-intent` \|' "$CONTRACT")"
[ -n "$GI_CONTRACT_BLOCK" ] || { echo "FAIL: could not extract the generate-intent routing row from $CONTRACT"; exit 1; }

# ── Assertion A (RED pre-fix): auto-and-handoff routes map-present → bind ────────
if printf '%s\n' "$GI_BLOCK" | grep -q 'suggested_skill: mega-sdd:bind-codebase'; then
  pass "A: auto-and-handoff §Handoff emission carries 'suggested_skill: mega-sdd:bind-codebase' (map-present brownfield hop)"
else
  fail "A: auto-and-handoff §Handoff emission has NO 'suggested_skill: mega-sdd:bind-codebase' — brownfield-with-codebase-map must route to bind-codebase, not re-scan (routing-rules.md :55)"
fi

# ── Assertion B (RED pre-fix): handoff-contract §generate-intent routes to bind ─
if printf '%s\n' "$GI_CONTRACT_BLOCK" | grep -q 'mega-sdd:bind-codebase'; then
  pass "B: handoff-contract generate-intent row carries the 'mega-sdd:bind-codebase' route (surface parity with auto-and-handoff)"
else
  fail "B: handoff-contract generate-intent row has NO 'mega-sdd:bind-codebase' route — routing index stale; surface-drift vs auto-and-handoff"
fi

# ── Assertion C (map-present branch is codebase-map-conditioned, not unconditional)
# The bind route must be gated on codebase-map presence (the branch condition),
# not an unconditional replacement. Confirm both surfaces name the map condition
# alongside the bind route.
if printf '%s\n' "$GI_BLOCK" | grep -qi 'codebase-map'; then
  pass "C1: auto-and-handoff §Handoff emission names the codebase-map presence condition"
else
  fail "C1: auto-and-handoff §Handoff emission bind route is not conditioned on codebase-map presence"
fi
if printf '%s\n' "$GI_CONTRACT_BLOCK" | grep -qi 'codebase-map'; then
  pass "C2: handoff-contract generate-intent row names the codebase-map presence condition"
else
  fail "C2: handoff-contract generate-intent row bind route is not conditioned on codebase-map presence"
fi

# ── Assertion D (negative twin, GREEN both pre+post): map-ABSENT still → scan ────
# Guards against over-correction: a brownfield vault with NO codebase-map must
# still route to scan-codebase. This branch is UNCHANGED by the fix.
if printf '%s\n' "$GI_BLOCK" | grep -q 'suggested_skill: mega-sdd:scan-codebase'; then
  pass "D1: auto-and-handoff §Handoff emission still routes map-absent brownfield to 'suggested_skill: mega-sdd:scan-codebase'"
else
  fail "D1: auto-and-handoff §Handoff emission lost the map-absent → scan-codebase branch (over-correction)"
fi
if printf '%s\n' "$GI_CONTRACT_BLOCK" | grep -q 'mega-sdd:scan-codebase'; then
  pass "D2: handoff-contract generate-intent row still routes map-absent brownfield to 'mega-sdd:scan-codebase'"
else
  fail "D2: handoff-contract generate-intent row lost the map-absent → scan-codebase branch (over-correction)"
fi

# ── Assertion E (regression guard, GREEN both pre+post): greenfield → units ─────
if printf '%s\n' "$GI_BLOCK" | grep -q 'suggested_skill: mega-sdd:generate-units'; then
  pass "E1: auto-and-handoff §Handoff emission keeps the greenfield → generate-units branch"
else
  fail "E1: auto-and-handoff §Handoff emission lost the greenfield → generate-units branch"
fi
if printf '%s\n' "$GI_CONTRACT_BLOCK" | grep -q 'mega-sdd:generate-units'; then
  pass "E2: handoff-contract generate-intent row keeps the greenfield → generate-units branch"
else
  fail "E2: handoff-contract generate-intent row lost the greenfield → generate-units branch"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "test-generate-intent-map-present-route: ALL PASS"
  exit 0
else
  echo "test-generate-intent-map-present-route: $fails FAILURE(S)"
  exit 1
fi
