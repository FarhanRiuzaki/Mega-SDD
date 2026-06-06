#!/usr/bin/env bash
# Moat regression (AUDIT Round-2 L3/L5/L6): the execute-bolts + orchestrate-flow
# fan-out prose must NEVER describe a depth-2 dispatch. Subagents cannot spawn
# subagents (hard depth-1 limit); the per-unit flow already dispatches three
# first-class agents (bolt-implementer -> spec-reviewer -> code-quality-reviewer),
# so any "squad subagent that then runs units" / "subagent batch that dispatches
# implementer+reviewers" is structurally impossible and silently degrades to inline
# implementation — LOSING the two-stage review (the moat's quality enforcement).
#
# This test pins the v4 invariant: main-thread controller + concurrent depth-1
# Agent dispatch + per-unit two-stage review. It FAILS if a known depth-2
# anti-pattern phrase reappears, and FAILS if the corrective design wording is
# deleted. Pure-prose fixes regress silently; this makes them enforceable.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

EB="${PLUGIN_ROOT}/skills/execute-bolts"
OF="${PLUGIN_ROOT}/skills/orchestrate-flow"

# Files in scope: the fan-out / dispatch prose.
FILES=(
  "${EB}/SKILL.md"
  "${EB}/references/squad-subagent.md"
  "${EB}/references/batch-and-fanout.md"
  "${EB}/references/superpowers-bridge.md"
  "${EB}/references/hard-rule-scan.md"
  "${OF}/references/routing-rules.md"
)

fail=0

# ── Forbidden depth-2 anti-patterns (case-insensitive, whitespace-normalized) ─
# Each was a literal phrase in the pre-fix broken design (validated against the
# pre-fix files: AUDIT Round-2). Markdown wraps these phrases across lines, so we
# normalize newlines->spaces before matching — a single-line grep would miss them.
FORBIDDEN=(
  "recursively for each unit"                          # squad subagent became the per-unit controller
  "each running multiple unit subagents internally"   # --per-squad --parallel depth-2 claim
  "dispatch ONE subagent"                              # squad-level subagent dispatch
  "inside its own subagent"                            # squad runs its parallel-units stream in a subagent
  "subagent batch via"                                 # --parallel as a nested subagent batch
  "writes are invisible"                               # L2 false premise (subagent writes invisible)
  "Each squad's controller then independently"         # squad subagent IS the controller (superpowers-bridge)
)

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "FAIL: scoped file missing: ${f#$PLUGIN_ROOT/}"; fail=1; continue; }
  norm=$(tr '\n' ' ' < "$f" | tr -s ' ')
  for pat in "${FORBIDDEN[@]}"; do
    if printf '%s' "$norm" | grep -qiF "$pat"; then
      echo "FAIL: depth-2 anti-pattern reappeared in ${f#$PLUGIN_ROOT/}: \"$pat\""
      fail=1
    fi
  done
done

# ── Required corrective wording (the fix must stay present) ───────────────────
# squad-subagent.md must assert the main-thread loop + no squad subagent.
SQ="${EB}/references/squad-subagent.md"
grep -qi "main-thread" "$SQ" || { echo "FAIL: squad-subagent.md lost the 'main-thread' loop design"; fail=1; }
grep -qi "NEVER forks a squad subagent" "$SQ" || { echo "FAIL: squad-subagent.md lost the 'NEVER forks a squad subagent' guard"; fail=1; }

# superpowers-bridge.md must keep the controller in the main thread.
SB="${EB}/references/superpowers-bridge.md"
grep -qi "main thread as the controller" "$SB" || { echo "FAIL: superpowers-bridge.md lost 'main thread as the controller'"; fail=1; }

if [ "$fail" -ne 0 ]; then
  echo "ALL: FAILED — depth-2 dispatch invariant violated (see above)."
  exit 1
fi

echo "PASS (no depth-2 anti-pattern; main-thread controller design intact)"
echo "ALL PASS"
