#!/usr/bin/env bash
# Audit Phase 2b (spec 2026-08-11-audit-phase2b-scripts-and-owners.md) —
# S4 sync short-circuit wiring, S5 owner outcomes, S6 hand-synchronized
# contract parity pins (v1: presence-pair pins — each pair member must keep
# its half of the contract; a deleted half fails here before it drifts).
# Run: bash tests/surface/test-p11-owner-parity.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# ── S4 — sync claim-intersection short-circuit wired at all three surfaces ──
[ -x "$P/scripts/sync-intersect.sh" ] \
  && pass "S4: sync-intersect.sh present + executable" || fail "S4: script missing"
grep -qF 'sync-intersect.sh' "$P/commands/sync.md" \
  && grep -qF 'fail-closed' "$P/commands/sync.md" \
  && pass "S4b: sync.md names the gate with its fail-closed contract" \
  || fail "S4b: sync.md wiring missing"
grep -qF 'Short-circuit gate (BOTH lanes' "$P/skills/orchestrate-flow/references/routing-rules.md" \
  && pass "S4c: Mode D row carries the gate" || fail "S4c: Mode D wiring missing"
grep -qF 'sync-intersect.sh' "$P/skills/orchestrate-flow/SKILL.md" \
  && pass "S4d: --sync flag row names the gate" || fail "S4d: flag-row wiring missing"

# ── S5 — UAT step-row single owner ──
UO="$P/skills/emit-uat/references/uat-sections.md"
grep -qF 'OWNED by `references/uat-sections.md §Section 2`' "$P/skills/emit-uat/SKILL.md" \
  && grep -qF 'adds no rules of its own' "$P/skills/emit-uat/references/uat-template.md" \
  && grep -qF '| 1 | <Aksi> | <Expected Result> |' "$UO" \
  && grep -qF 'Pending — flow' "$UO" \
  && pass "S5a: UAT step-row grammar single-owned at uat-sections §Section 2" \
  || fail "S5a: UAT owner relocation incomplete"

# ── S5 — spawn-gate SKILL compression (owner intact, pins kept) ──
SC="$P/skills/scan-codebase/SKILL.md"
grep -qF 'OWNED in full by `references/scan-procedure.md §Spawn-cost gate`' "$SC" \
  && grep -qF 'ONE batched invocation' "$SC" \
  && grep -qF 'N_hash + N_extract' "$SC" \
  && ! grep -qF 'the exact re-run commands (`--engine=ast-grep`' "$SC" \
  && grep -q '^### Spawn-cost gate' "$P/skills/scan-codebase/references/scan-procedure.md" \
  && pass "S5b: spawn-gate restatement compressed; owner + Windows pins intact" \
  || fail "S5b: spawn-gate compression incomplete or a pin lost"

# ── S6 — parity pairs (presence-pair pins) ──
BT="$P/skills/bind-codebase/references/binding-md-template.md"
BM="$P/skills/resolve-oq/references/binding-mode.md"
if grep -qF '### ✅ CONFLICT-' "$BT" && grep -qF '### ✅ CONFLICT-' "$BM" \
   && grep -qF '**Resolution**: ✅ RESOLVED (' "$BT" && grep -qF '**Resolution**: ✅ RESOLVED (' "$BM"; then
  pass "S6a: ✅ RESOLVED marker shape present at BOTH the template owner and the writer (binding-mode)"
else fail "S6a: marker-grammar pair broken (template/writer drift or deletion)"; fi
EB="$P/skills/execute-bolts/SKILL.md"
BR="$P/skills/execute-bolts/references/superpowers-bridge.md"
if grep -qF 'The EXIT CODE is the discriminator' "$EB" && grep -qF 'The EXIT CODE decides, not' "$BR" \
   && grep -qF -- '--quiet' "$EB" && grep -qF -- '--quiet' "$BR"; then
  pass "S6b: exit-code discriminator + --quiet ban present at BOTH operational surfaces"
else fail "S6b: exit-code contract pair broken"; fi
n_ret=$(grep -lF 'findings only, no narrative (return-size contract)' "$P"/agents/*.md | wc -l | tr -d ' ')
[ "$n_ret" -ge 6 ] \
  && grep -qF 'findings-only' "$P/skills/execute-bolts/references/review-panel.md" \
  && pass "S6c: findings-only return contract in $n_ret agent bodies + the panel owner" \
  || fail "S6c: return-contract parity broken (agents carrying it: $n_ret)"
grep -qF 'step_type' "$P/agents/bolt-implementer.md" \
  && grep -qF 'canonical taxonomy' "$P/skills/execute-bolts/references/partial-state-and-saga.md" \
  && pass "S6d: step_type enum pair present (agent copy + canonical taxonomy home)" \
  || fail "S6d: step_type pair broken"
grep -qF 'findings.json' "$P/agents/resolution-verifier.md" \
  && grep -qF 'ONLY file' "$P/agents/resolution-verifier.md" \
  && pass "S6e: verifier bolt-dir scoping (findings.json ONLY-file rule) in the agent body" \
  || fail "S6e: verifier scoping pair broken"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
