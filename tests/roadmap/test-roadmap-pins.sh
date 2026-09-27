#!/usr/bin/env bash
# Adopt-now roadmap pins — worktree-proofing, interop pair, CI recipe, EARS tier,
# recorded capability decisions (spec: 2026-06-10-fmea-and-future-roadmap.md).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# A — worktree-safe git probes (no literal .git/<state> paths left in rails)
! grep -rq '`\.git/rebase-merge`' "$P/skills/" "$P/commands/" \
  && grep -q -- '--git-path rebase-merge' "$P/skills/execute-bolts/SKILL.md" \
  && grep -q -- '--git-path rebase-merge' "$P/commands/sync.md" \
  && pass "A: rebase probes worktree-safe (rev-parse --git-path)" \
  || fail "A: literal .git/ state probes still present"
grep -q -- '--git-path hooks' "$P/skills/execute-bolts/SKILL.md" \
  && pass "A2: hook probe worktree-safe" || fail "A2: hook probe still literal"
# A3 (scan walk-up `test -e not -d`) RETIRED 9.0 P1: it pinned prose in the deleted
# scan-codebase skill's scan-procedure.md (the classic scan-first spine, removed by
# design — spec 2026-09-27-v9-simplification-design.md §3). No relocated equivalent;
# the surviving worktree-safe git probes stay pinned by A/A2 above.

# B/F — capability decisions recorded (do not silently re-propose)
grep -q 'context: fork.*PILOT LIVE' "$P/CLAUDE.md" \
  && pass "B: context:fork decision recorded (pilot live on detect-drift v3.0.0, evidence cited)" \
  || fail "B: fork decision missing from CLAUDE.md"
grep -q 'Skill-scoped `hooks:` frontmatter — NOT adopted for the moat' "$P/CLAUDE.md" \
  && pass "F: skill-scoped-hooks decision recorded (moat stays global)" \
  || fail "F: skill-scoped hooks decision missing"

# C — AGENTS.md interop pair
grep -q '@AGENTS.md' "$P/skills/emit-agents-md/SKILL.md" \
  && grep -q 'does NOT read AGENTS.md natively' "$P/skills/emit-agents-md/SKILL.md" \
  && grep -q 'Never edit CLAUDE.md without explicit yes' "$P/skills/emit-agents-md/SKILL.md" \
  && pass "C: interop pair (AGENTS.md + @AGENTS.md stub, consent-gated)" \
  || fail "C: interop pair missing"

# D — CI recipe exists + pointers + the --bare warning. 9.0 P1b relocated it from
# $P/references/ci-recipe.md (no skill/hook/script loads it) to repo docs; the pointers
# must name the new path.
CIR="docs/mega-sdd/ci-recipe.md"
[ -f "$CIR" ] && [ ! -e "$P/references/ci-recipe.md" ] \
  && grep -q -- '--bare' "$CIR" \
  && grep -q 'docs/mega-sdd/ci-recipe.md' "$P/references/project-config.md" \
  && grep -q 'docs/mega-sdd/ci-recipe.md' "$P/README.md" \
  && pass "D: CI recipe shipped + wired (incl. --bare bypass warning)" \
  || fail "D: CI recipe missing or unwired"
grep -q "Don't auto-resolve PENDING-SYNC.md in CI" "$CIR" \
  && pass "D2: CI recipe preserves the moat (no auto-resolve)" \
  || fail "D2: CI moat rule missing"
# D3 — the per-unit CONFLICT gate: without --units= a bolts/U-*/binding.json CONFLICT is only
# advisory (validate-handoff-binding-units.sh exits 0), so every gate invocation in the recipe
# and in project-config's Headless/CI section must carry --units=all; the full audit is rebind-units --units=all.
# The check reads the COMMAND token only (up to the closing backtick / `;` / `|`), so a
# `--units=all` in the surrounding prose cannot satisfy it.
GATE_RE='validate-handoff-binding-units\.sh"? --cwd[^`;|]*'
! grep -ohE "$GATE_RE" "$CIR" "$P/references/project-config.md" | grep -v -- '--units=all' | grep -q . \
  && [ "$(grep -cE "$GATE_RE" "$CIR")" -ge 4 ] \
  && grep -qE "$GATE_RE" "$P/references/project-config.md" \
  && grep -qE 'rebind-units\.sh"? --cwd[^`;|]*--units=all' "$CIR" \
  && pass "D3: CI gates carry --units=all (per-unit CONFLICT blocks) + full audit via rebind-units" \
  || fail "D3: a CI gate step omits --units=all (per-unit CONFLICTs would pass)"

# E — EARS optional tier (backward-compatible). The unit schema moved from the deleted
# generate-units skill to plan/references/unit-schema.md (9.0 P1 relocation).
US="$P/skills/plan/references/unit-schema.md"
grep -q 'ears:' "$US" \
  && grep -q 'OPTIONAL (additive, backward-compatible)' "$US" \
  && grep -q 'Absent → `expects:` (a literal output substring, or empty' "$US" \
  && pass "E: EARS tier optional + backward-compatible" \
  || fail "E: EARS tier missing or not optional"

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
