#!/usr/bin/env bash
# test-unit-granularity.sh — 7.20.0 (spec 2026-09-01-unit-granularity-coarsening.md).
#
# Team ask "1 subagent per sprint (5 related units)" was REJECTED on the record
# (depth-1 runtime limit — research/2026-09-01-sprint-subagent-granularity.md);
# the shipped lever is UPSTREAM: coarser units + a cohesion merge advisory.
# Execution stays per-unit forever. Pins:
#   A  --max-complexity gains `large` (story-sized, 600 LOC / 8 files)
#   B  config `unit_granularity: fine|coarse` + precedence flag > config > default
#   C  the medium DEFAULT (300 LOC / 5 files) did not move
#   D  unit-schema atomicity: threshold stays advisory-no-validator + names the knob
#   E  lint-units merge_candidate advisory: all 6 criteria + never-halt/never-auto-merge
#   F  precedent guard: squad-subagent.md still rejects the group-subagent topology
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GU="$ROOT/plugins/mega-sdd/skills/generate-units/SKILL.md"
US="$ROOT/plugins/mega-sdd/skills/generate-units/references/unit-schema.md"
DP="$ROOT/plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md"
SQ="$ROOT/plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md"
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

echo "── A: the large knob ──"
grep -q -- '--max-complexity=small|medium|large' "$GU" && ok "A1 flag enum carries large" || bad "A1 enum missing large"
grep -q "600 LOC" "$GU" && grep -q "story-sized" "$GU" && ok "A2 large semantics (600 LOC, story-sized) in SKILL" || bad "A2 large semantics missing"
grep -qE '600 LOC.*8 files|≤8 files' "$GU" && ok "A3 file bound 8 rides with large" || bad "A3 file bound missing"

echo "── B: config + precedence ──"
grep -q "unit_granularity: fine|coarse" "$GU" && ok "B1 config key documented" || bad "B1 config key missing"
grep -q "flag > config > default" "$GU" && ok "B2 precedence order pinned" || bad "B2 precedence missing"
grep -q "coarse→large" "$GU" && grep -q "fine→small" "$GU" && ok "B3 config→enum mapping explicit" || bad "B3 mapping missing"

echo "── C: default did not move ──"
grep -q "< 300 LOC and ≤ 5 files → single unit" "$GU" && ok "C1 Step 3 default threshold intact" || bad "C1 default threshold changed/moved"
grep -qE 'absen keduanya.*medium|default 300 LOC' "$GU" && ok "C2 medium stays the no-flag/no-config default" || bad "C2 default fallback missing"

echo "── D: unit-schema atomicity ──"
grep -q "advisory — no validator measures it" "$US" && ok "D1 threshold stays advisory class" || bad "D1 advisory clause lost"
grep -q "unit_granularity: coarse" "$US" && grep -q "story-sized" "$US" && ok "D2 atomicity rule names the knob" || bad "D2 knob missing from atomicity rule"
grep -q "granularity-independent" "$US" && ok "D3 other rails declared granularity-independent" || bad "D3 rails-independence clause missing"

echo "── E: cohesion merge advisory ──"
grep -q "Merge-candidate advisory" "$DP" && ok "E1 advisory present in lint-units Step 3" || bad "E1 advisory missing"
for c in "same \`module:\`" "task_type: create|extend" "target_files\` ≤ 2" "no \`## Hard rules\`" "no \`properties:\`" "self-contained"; do
  grep -qF "$c" "$DP" && ok "E2 criterion: $c" || bad "E2 criterion missing: $c"
done
grep -q "never a halt, never an auto-merge" "$DP" && ok "E3 advisory-forever clause" || bad "E3 never-halt/never-auto-merge missing"
grep -q "merge_candidate: U-00X..U-00Z" "$DP" && ok "E4 emission format pinned" || bad "E4 emission format missing"
grep -q "2026-09-01-sprint-subagent-granularity" "$DP" && ok "E5 research provenance cited" || bad "E5 research citation missing"

echo "── F: precedent guard (the rejection stays on the record) ──"
grep -q "NEVER forks a squad subagent" "$SQ" && grep -q "depth-1" "$SQ" \
  && ok "F1 squad-subagent depth-1 rejection intact (also rejects sprint-subagent)" || bad "F1 group-subagent rejection eroded"

echo; [ $err -eq 0 ] && { echo "test-unit-granularity: ALL PASS"; exit 0; } || { echo "test-unit-granularity: FAILED"; exit 1; }
