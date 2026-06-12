#!/usr/bin/env bash
# Efficiency + anti-drift pins — from the 2026-06-10 redundancy/waste audit.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# E1 — pre-tool-use: .mega-sdd existence check ordered BEFORE the config grep
mega_line=$(grep -n 'PROJECT_ROOT}/.mega-sdd" \]; then exit 0' "$P/hooks/pre-tool-use" | head -1 | cut -d: -f1)
cfg_line=$(grep -nF 'telemetry:' "$P/hooks/pre-tool-use" | head -1 | cut -d: -f1)
[ -n "$mega_line" ] && [ -n "$cfg_line" ] && [ "$mega_line" -lt "$cfg_line" ] \
  && pass "E1: .mega-sdd guard before config grep ($mega_line < $cfg_line)" \
  || fail "E1: guard ordering wrong (mega=$mega_line cfg=$cfg_line)"

# E2 — post-tool-use: unit-write validators parallelized + wait
grep -q '( bash "$VALIDATOR_FC" --cwd="$PROJECT_ROOT" --quiet >/dev/null 2>&1 || true ) &' "$P/hooks/post-tool-use" \
  && grep -B2 -A8 'VALIDATOR_FOP" --cwd' "$P/hooks/post-tool-use" | grep -q 'wait' \
  && pass "E2: unit-write validators parallel + wait" \
  || fail "E2: parallel validator pattern missing"

# E3 — code-quality-reviewer aligned with catalog (opus)
grep -q '^model: opus' "$P/agents/code-quality-reviewer.md" \
  && pass "E3: code-quality-reviewer = opus (catalog row 17)" \
  || fail "E3: code-quality-reviewer model misaligned with catalog"

# E4 — detect-drift reuses map §7
grep -q 'REUSE FIRST' "$P/skills/detect-drift/SKILL.md" \
  && pass "E4: drift framework reuse-first" \
  || fail "E4: drift REUSE FIRST missing"

# E5 — OQ classifier memoization
grep -q 'Memoization (re-runs' "$P/skills/generate-intent/SKILL.md" \
  && pass "E5: OQ classifier memoization" \
  || fail "E5: memoization rule missing"

# E6 — phantom filenames eradicated
! grep -rq '04-functional-spec.md' "$P/skills/" \
  && ! grep -q '01-entities.md' "$P/skills/bind-codebase/references/binding-contract.md" \
  && pass "E6: phantom vault filenames eradicated" \
  || fail "E6: phantom filenames still present"

# E7 — KB 4-path priority consistent (paths.md read-side carries all 4)
grep -q 'docs/mega-sdd/knowledge-base/` → `old-reference/knowledge-base/' "$P/references/paths.md" \
  && pass "E7: paths.md KB read-side has all 4 paths" \
  || fail "E7: paths.md KB path order still drifted"

# E8 — handoff-contract precedence rule + scan block fixed
grep -q 'Precedence (anti-drift rule)' "$P/skills/orchestrate-flow/references/handoff-contract.md" \
  && grep -A8 '### `scan-codebase`' "$P/skills/orchestrate-flow/references/handoff-contract.md" | grep -q . \
  && grep -q 'starterkit-first — draft the vault scan-aware' "$P/skills/orchestrate-flow/references/handoff-contract.md" \
  && pass "E8: handoff precedence rule + scan block matches skill side" \
  || fail "E8: handoff-contract drift not fixed"

# E9 — safe write-back class cites its owner
grep -q 'definition OWNED by detect-drift Step 5' "$P/commands/sync.md" \
  && pass "E9: sync.md safe-class points at owner" \
  || fail "E9: safe-class ownership citation missing"

# E10 — FUNCTIONAL: non-SDD project quick exit (no block output, exit 0)
T=$(mktemp -d)
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"ls"}}' "$T" | bash "$P/hooks/pre-tool-use" 2>/dev/null); RCX=$?
[ "$RCX" -eq 0 ] && [ -z "$OUT" ] \
  && pass "E10: pre-tool-use non-SDD quick exit (exit 0, silent)" \
  || fail "E10: non-SDD exit broken (rc=$RCX out=${OUT:0:60})"
rm -rf "$T"

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
