#!/usr/bin/env bash
# Orchestrates the full measurable benchmark for both arms.
# Usage: run-benchmark.sh <baseline-worktree-root> [--skip-quality]
#   <baseline-worktree-root>: a worktree at the BASELINE commit, e.g.
#     git worktree add --detach /tmp/megasdd-baseline 91a944a
#   The OPTIMIZED arm is this repo checkout itself (must be at/after a09e430).
# Outputs: benchmarks/results/{baseline,optimized}/*.json
# Then run: python3 benchmarks/scripts/compare-results.py
set -u
BASE_ROOT="${1:?baseline worktree root}"; shift || true
SKIP_Q=0; [ "${1:-}" = "--skip-quality" ] && SKIP_Q=1
BENCH="$(cd "$(dirname "$0")/.." && pwd)"
OPT_ROOT="$(cd "$BENCH/.." && pwd)"
mkdir -p "$BENCH/results/baseline" "$BENCH/results/optimized" "$BENCH/results/comparison"

for arm in baseline optimized; do
  if [ "$arm" = baseline ]; then R="$BASE_ROOT"; else R="$OPT_ROOT"; fi
  echo "== $arm ($R) =="
  bash "$BENCH/scripts/measure-static.sh"      "$R" "$arm" "$BENCH/results/$arm/static.json"
  python3 "$BENCH/scripts/measure-duplication.py" "$R" "$arm" "$BENCH/results/$arm/duplication.json"
  bash "$BENCH/scripts/measure-context.sh"     "$R" "$arm" "$BENCH/results/$arm/context.json"
  if [ "$SKIP_Q" -eq 0 ]; then
    bash "$BENCH/scripts/quality-gate.sh"      "$R" "$arm" "$BENCH/results/$arm/quality.json" || true
  fi
done
echo "Done. Next: python3 $BENCH/scripts/compare-results.py"
