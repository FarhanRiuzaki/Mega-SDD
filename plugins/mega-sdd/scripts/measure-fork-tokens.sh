#!/usr/bin/env bash
# measure-fork-tokens.sh — A/B comparator for the detect-drift context:fork token win.
#
# WHY: CLAUDE.md (Capability-adoption decisions) and the moat-token-tradeoff memory
# both gate extending `context: fork` to scan-codebase / bind-codebase on a LIVE
# before/after measurement of detect-drift confirming the win. This script does the
# compare; it does NOT re-instrument — it diffs two .token-cost-state.json snapshots
# already produced by report-token-cost.sh (which sums message.usage across every
# subagent turn and cost-weights it, correcting the harness's last-turn-only undercount).
#
# Procedure that produces the inputs: research/2026-06-26-fork-token-measurement-procedure.md
#
# Usage:
#   measure-fork-tokens.sh --baseline=<state.json> --fork=<state.json> \
#       [--skill=<name>] [--margin=<0..1>] [--json]
#     --baseline  the NO-FORK run snapshot (context: fork removed from detect-drift)
#     --fork      the FORK run snapshot (main, context: fork present)
#     --skill     compare a single by_skill bucket's cost_weighted instead of the total
#     --margin    require fork to be at least this fraction below baseline (default 0)
#     --json      emit a machine verdict instead of the human line
#
# Verdict: fork_cost < baseline_cost * (1 - margin)  =>  WIN  (exit 0)
#          otherwise                                  =>  NO-WIN (exit 1)
#          unreadable/absent input                    =>  ERROR (exit 2)

set -u

BASELINE="" FORK="" SKILL="" MARGIN="0" JSON=0
for arg in "$@"; do
  case "$arg" in
    --baseline=*) BASELINE="${arg#*=}" ;;
    --fork=*)     FORK="${arg#*=}" ;;
    --skill=*)    SKILL="${arg#*=}" ;;
    --margin=*)   MARGIN="${arg#*=}" ;;
    --json)       JSON=1 ;;
    *) echo "measure-fork-tokens: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$BASELINE" ] || [ -z "$FORK" ]; then
  echo "measure-fork-tokens: --baseline and --fork are required" >&2; exit 2
fi

BASELINE="$BASELINE" FORK="$FORK" SKILL="$SKILL" MARGIN="$MARGIN" JSON="$JSON" python3 <<'PY'
import json, os, sys

def load(path):
    if not path or not os.path.isfile(path):
        sys.stderr.write("measure-fork-tokens: cannot read snapshot: %s\n" % path)
        sys.exit(2)
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        sys.stderr.write("measure-fork-tokens: unparseable snapshot %s (%s)\n" % (path, type(e).__name__))
        sys.exit(2)

def cost(state, skill):
    if skill:
        for b in state.get("by_skill", []):
            if b.get("skill") == skill:
                return float(b.get("cost_weighted", 0))
        sys.stderr.write("measure-fork-tokens: skill %r not in snapshot by_skill[]\n" % skill)
        sys.exit(2)
    v = state.get("cost_weighted_total")
    if v is None:
        sys.stderr.write("measure-fork-tokens: snapshot missing cost_weighted_total\n")
        sys.exit(2)
    return float(v)

skill  = os.environ["SKILL"] or ""
try:
    margin = float(os.environ["MARGIN"])
except ValueError:
    sys.stderr.write("measure-fork-tokens: --margin must be a number in [0,1]\n"); sys.exit(2)
if not (0.0 <= margin < 1.0):
    sys.stderr.write("measure-fork-tokens: --margin must be in [0,1)\n"); sys.exit(2)

base = cost(load(os.environ["BASELINE"]), skill)
fork = cost(load(os.environ["FORK"]), skill)
threshold = base * (1.0 - margin)
win = fork < threshold
delta = fork - base
pct = (100.0 * delta / base) if base else 0.0
label = ("detect-drift bucket" if skill else "cost-weighted total")

if os.environ["JSON"] == "1":
    print(json.dumps({
        "metric": label, "skill": skill or None,
        "baseline": int(round(base)), "fork": int(round(fork)),
        "delta": int(round(delta)), "pct": round(pct, 1),
        "margin": margin, "verdict": "WIN" if win else "NO-WIN",
    }))
else:
    print("fork-token A/B (%s): baseline=%d  fork=%d  delta=%d (%.1f%%)  margin=%.0f%%  => %s"
          % (label, round(base), round(fork), round(delta), pct, margin * 100,
             "WIN" if win else "NO-WIN"))

sys.exit(0 if win else 1)
PY
