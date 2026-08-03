#!/usr/bin/env bash
# measure-fork-ab.sh — friction-guarded driver for the detect-drift context:fork A/B.
#
# WHY: the A/B itself is two MANUAL harness runs of detect-drift (one with
# `context: fork`, one without) — no script can automate them, and no script closes the
# real open blocker, which is a METHODOLOGY constraint (the baseline must come from a
# representative session; see the procedure doc). What a script CAN do is remove the two
# silent footguns that would otherwise let a fresh operator record a phantom verdict:
#
#   1. WRONG PLUGIN INSTANCE. The baseline arm strips `context: fork` from a SKILL.md, but
#      a fresh session loads the plugin the harness resolved — typically the marketplace
#      CACHE (~/.claude/plugins/cache/mega-sdd/mega-sdd/<ver>/), NOT your dev checkout. Edit
#      the dev file, load the cache, and the baseline STILL forks → baseline==fork → a
#      phantom NO-WIN with no error. This tool catches that MECHANICALLY: a fork emits a
#      subagent_end_marker (subagent_turns>0); an inline run does not (subagent_turns==0).
#      So `capture baseline` REFUSES if subagent_turns>0 (a fork ran → wrong instance /
#      un-stripped fork), and `capture fork` REFUSES if subagent_turns==0 (no fork ran →
#      SubagentStop didn't fire OR the loaded instance lacks the fork). Runtime behaviour,
#      not a file checksum — it verifies which instance the harness ACTUALLY loaded.
#   2. UNCAPTURED FORK COST (SubagentStop). Same subagent_turns==0 check on the fork arm;
#      the compare step also passes --require-subagent to the underlying comparator.
#
# It also records the BASELINE CONFOUND as raw numbers (accumulated-context proxy =
# cache_read tokens the inline baseline re-processed) so a future reader can trust or
# reject the delta. It NEVER judges representativeness — it records; the human judges.
#
# This is a thin wrapper: capture shells out to report-token-cost.sh; compare shells out
# to measure-fork-tokens.sh (the raw comparator, which guards the fork arm only). Drop to
# measure-fork-tokens.sh directly if you need to bypass the arm-aware baseline guard.
#
# Procedure (the two manual runs + the guards in context):
#   research/2026-06-26-fork-token-measurement-procedure.md
#
# Usage:
#   measure-fork-ab.sh capture <baseline|fork> --cwd=<project-root> [--quiet]
#   measure-fork-ab.sh compare               --cwd=<project-root> [--skill=<name>] [--margin=<0..1>] [--json]
#   measure-fork-ab.sh status                --cwd=<project-root>
#   measure-fork-ab.sh reset                 --cwd=<project-root>
#
# CI-safe: bash + python3 only. Exit 0 = ok / WIN; 1 = NO-WIN; 2 = usage or guard refusal.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPORT="$HERE/report-token-cost.sh"
COMPARE="$HERE/measure-fork-tokens.sh"

CMD="${1:-}"; [ $# -gt 0 ] && shift || true

CWD="" ARM="" SKILL="detect-drift" MARGIN="0.10" JSON=0 QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*)    CWD="${arg#--cwd=}" ;;
    --skill=*)  SKILL="${arg#--skill=}" ;;
    --margin=*) MARGIN="${arg#--margin=}" ;;
    --json)     JSON=1 ;;
    --quiet)    QUIET=1 ;;
    baseline|fork) ARM="$arg" ;;
    "") ;;
    *) echo "measure-fork-ab: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

usage() {
  cat >&2 <<EOF
usage:
  measure-fork-ab.sh capture <baseline|fork> --cwd=<project-root> [--quiet]
  measure-fork-ab.sh compare               --cwd=<project-root> [--skill=<name>] [--margin=<0..1>] [--json]
  measure-fork-ab.sh status                --cwd=<project-root>
  measure-fork-ab.sh reset                 --cwd=<project-root>
EOF
  exit 2
}

[ -n "$CWD" ] || { echo "measure-fork-ab: --cwd=<project-root> is required" >&2; usage; }
[ -d "$CWD/.mega-sdd" ] || { echo "measure-fork-ab: no .mega-sdd/ under $CWD — run in a vault/target project" >&2; exit 2; }

ABDIR="$CWD/.mega-sdd/.fork-ab"
STATE="$CWD/.mega-sdd/.token-cost-state.json"

case "$CMD" in
  capture)
    [ "$ARM" = baseline ] || [ "$ARM" = fork ] || { echo "measure-fork-ab: capture needs an arm: baseline | fork" >&2; usage; }
    [ -x "$REPORT" ] || { echo "measure-fork-ab: missing $REPORT" >&2; exit 2; }
    mkdir -p "$ABDIR"
    # (Re)compute the cost state from the current telemetry, then guard + capture it.
    bash "$REPORT" --cwd="$CWD" --quiet || true
    [ -f "$STATE" ] || { echo "measure-fork-ab: report-token-cost produced no state ($STATE) — is telemetry on?" >&2; exit 2; }

    ARM="$ARM" STATE="$STATE" ABDIR="$ABDIR" QUIET="$QUIET" python3 <<'PY'
import json, os, sys, shutil

arm   = os.environ["ARM"]
state = os.environ["STATE"]
abdir = os.environ["ABDIR"]
quiet = os.environ["QUIET"] == "1"

try:
    with open(state) as f:
        s = json.load(f)
except Exception as e:
    sys.stderr.write("measure-fork-ab: cannot read cost state %s (%s)\n" % (state, type(e).__name__))
    sys.exit(2)

have = bool(s.get("have_telemetry"))
turns = s.get("turns")
subs  = s.get("subagent_turns")
cost  = s.get("cost_weighted_total")
btt   = s.get("by_token_type") or {}
cache_read = btt.get("cache_read_input_tokens", 0)

if not have or not isinstance(turns, int) or turns <= 0:
    sys.stderr.write(
        "measure-fork-ab: the current telemetry has no usable turns (have_telemetry=%r, turns=%r).\n"
        "  Did detect-drift actually run to completion with telemetry on, AFTER you reset\n"
        "  telemetry.jsonl for this arm? Nothing captured.\n" % (have, turns))
    sys.exit(2)

if not isinstance(subs, int):
    sys.stderr.write("measure-fork-ab: cost state has no integer subagent_turns (%r) — stale report-token-cost.sh? Nothing captured.\n" % (subs,))
    sys.exit(2)

# --- The arm-aware footgun guard (see the header). -----------------------------
if arm == "fork" and subs <= 0:
    sys.stderr.write(
        "measure-fork-ab: FORK arm captured subagent_turns=0 — no fork actually ran.\n"
        "  Either SubagentStop did not fire in your environment (see the procedure's SubagentStop\n"
        "  gate), OR the plugin instance your session loaded does NOT have `context: fork` (e.g. a\n"
        "  marketplace-cache version predating the fork, or a branch without it). Confirm a fork\n"
        "  ran, then re-capture. Nothing captured.\n")
    sys.exit(2)
if arm == "baseline" and subs > 0:
    sys.stderr.write(
        "measure-fork-ab: BASELINE arm captured subagent_turns=%d — a subagent ran, but the no-fork\n"
        "  baseline must run detect-drift INLINE (0 subagent turns). Two likely causes:\n"
        "    (a) TELEMETRY NOT RESET before this arm — a prior subagent run is still in\n"
        "        telemetry.jsonl (e.g. the Precondition-1 SubagentStop check, a small execute-bolts).\n"
        "        Fix: `rm -f .mega-sdd/memory/telemetry.jsonl && : > .mega-sdd/memory/telemetry.jsonl`,\n"
        "        re-run detect-drift, re-capture.\n"
        "    (b) WRONG PLUGIN INSTANCE — the instance your session loaded STILL has `context: fork`\n"
        "        (you stripped the fork from your dev checkout, but the harness loads a DIFFERENT\n"
        "        instance, typically the marketplace CACHE ~/.claude/plugins/cache/mega-sdd/mega-sdd/\n"
        "        <ver>/). Fix: strip the fork on the instance actually loaded (or rebuild the cache\n"
        "        from a fork-stripped build), re-run.\n"
        "  Rule out (a) first (it's cheaper). Nothing captured.\n" % subs)
    sys.exit(2)

# Passed the guard — copy the pristine snapshot (faithful comparator input) and record
# the confound-relevant raw numbers in the manifest. No judgment is recorded.
shutil.copyfile(state, os.path.join(abdir, arm + ".json"))

man_path = os.path.join(abdir, "manifest.json")
try:
    with open(man_path) as f:
        man = json.load(f)
except Exception:
    man = {}
man.setdefault("arms", {})
man["arms"][arm] = {
    "turns": turns,
    "subagent_turns": subs,
    "cost_weighted_total": cost,
    "cache_read_input_tokens": cache_read,   # accumulated-context proxy (inline baseline re-processes this)
    "cache_read_pct_of_cost": (round(100.0 * cache_read * 0.10 / cost, 1) if isinstance(cost, (int, float)) and cost else 0.0),
}
with open(man_path, "w") as f:
    json.dump(man, f, indent=2)

if not quiet:
    print("measure-fork-ab: captured %s — turns=%d subagent_turns=%d cost_weighted=%s"
          % (arm, turns, subs, cost))
    if arm == "baseline":
        print("  confound note (raw, un-judged): this inline baseline re-processed cache_read=%s tokens "
              "(~%s%% of its cost-weighted total)." % (cache_read, man["arms"][arm]["cache_read_pct_of_cost"]))
        print("  A large accumulated context inflates the inline baseline and thus the apparent win. "
              "Confirm this reflects a REPRESENTATIVE mid-pipeline session before trusting the delta — "
              "this tool records the number, it does NOT judge representativeness.")
PY
    ;;

  compare)
    [ -x "$COMPARE" ] || { echo "measure-fork-ab: missing $COMPARE" >&2; exit 2; }
    B="$ABDIR/baseline.json"; F="$ABDIR/fork.json"
    [ -f "$B" ] || { echo "measure-fork-ab: baseline not captured yet — run: capture baseline --cwd=$CWD" >&2; exit 2; }
    [ -f "$F" ] || { echo "measure-fork-ab: fork not captured yet — run: capture fork --cwd=$CWD" >&2; exit 2; }

    # Underlying comparator, --require-subagent always on. Compare the detect-drift bucket
    # AND the run total; the bucket isolates the skill, the total catches fork overhead
    # pushed onto the parent. Verdict + exit code come from the run total.
    CMPERR="$ABDIR/.cmp-stderr.txt"   # under the vault, not a predictable shared /tmp path
    bucket_json=$(bash "$COMPARE" --baseline="$B" --fork="$F" --skill="$SKILL" --margin="$MARGIN" --require-subagent --json 2>/dev/null) || true
    total_json=$(bash "$COMPARE" --baseline="$B" --fork="$F" --margin="$MARGIN" --require-subagent --json 2>"$CMPERR")
    rc=$?
    if [ $rc -eq 2 ]; then
      echo "measure-fork-ab: comparator refused a verdict (exit 2):" >&2
      cat "$CMPERR" >&2 2>/dev/null || true
      rm -f "$CMPERR"
      exit 2
    fi
    rm -f "$CMPERR"

    ABDIR="$ABDIR" BUCKET="$bucket_json" TOTAL="$total_json" SKILL="$SKILL" MARGIN="$MARGIN" JSON="$JSON" RC="$rc" python3 <<'PY'
import json, os, sys

abdir  = os.environ["ABDIR"]
skill  = os.environ["SKILL"]
margin = os.environ["MARGIN"]
emit   = os.environ["JSON"] == "1"
rc     = int(os.environ["RC"])

def loadj(s):
    try: return json.loads(s) if s.strip() else None
    except Exception: return None

bucket = loadj(os.environ["BUCKET"])
total  = loadj(os.environ["TOTAL"])
try:
    with open(os.path.join(abdir, "manifest.json")) as f:
        man = json.load(f)
except Exception:
    man = {}
base_arm = (man.get("arms") or {}).get("baseline") or {}

confound = {
    "judged": False,   # this tool never judges representativeness
    "baseline_turns": base_arm.get("turns"),
    "baseline_cost_weighted_total": base_arm.get("cost_weighted_total"),
    "baseline_cache_read_input_tokens": base_arm.get("cache_read_input_tokens"),
    "baseline_cache_read_pct_of_cost": base_arm.get("cache_read_pct_of_cost"),
    "note": ("The no-fork baseline runs detect-drift INLINE and re-processes the session's "
             "accumulated context (proxy: cache_read). If that context is not representative of a "
             "real mid-pipeline session, the delta is over- or under-stated. Trust or reject the "
             "verdict on this basis; the tool records, it does not judge."),
}
result = {
    "verdict": (total or {}).get("verdict"),
    "margin": float(margin),
    "total": total,
    "detect_drift_bucket": bucket,
    "confound": confound,
}
with open(os.path.join(abdir, "result.json"), "w") as f:
    json.dump(result, f, indent=2)

if emit:
    print(json.dumps(result))
else:
    def line(tag, d):
        if not d: return "  %s: (unavailable)" % tag
        return ("  %s: baseline=%s fork=%s delta=%s (%.1f%%) => %s"
                % (tag, d.get("baseline"), d.get("fork"), d.get("delta"),
                   d.get("pct", 0.0), d.get("verdict")))
    print("fork-token A/B (margin=%.0f%%, --require-subagent):" % (float(margin) * 100))
    print(line("run total       ", total))
    print(line("%-16s" % (skill + " bucket"), bucket))
    print("  confound (raw, UN-JUDGED): baseline inline re-processed cache_read=%s tokens "
          "(~%s%% of baseline cost); baseline turns=%s, cost_weighted=%s."
          % (confound["baseline_cache_read_input_tokens"], confound["baseline_cache_read_pct_of_cost"],
             confound["baseline_turns"], confound["baseline_cost_weighted_total"]))
    print("  → Judge whether that baseline reflects a representative mid-pipeline session before "
          "trusting this verdict. Recorded to .mega-sdd/.fork-ab/result.json.")
sys.exit(0 if rc == 0 else 1)
PY
    ;;

  status)
    ABDIR="$ABDIR" python3 <<'PY'
import json, os
abdir = os.environ["ABDIR"]
try:
    with open(os.path.join(abdir, "manifest.json")) as f:
        man = json.load(f)
except Exception:
    man = {}
arms = man.get("arms") or {}
for arm in ("baseline", "fork"):
    a = arms.get(arm)
    if a:
        print("  %-8s captured — turns=%s subagent_turns=%s cost_weighted=%s"
              % (arm, a.get("turns"), a.get("subagent_turns"), a.get("cost_weighted_total")))
    else:
        print("  %-8s not captured" % arm)
if arms.get("baseline") and arms.get("fork"):
    print("  → both arms captured; run: compare")
PY
    ;;

  reset)
    rm -rf "$ABDIR"
    echo "measure-fork-ab: cleared $ABDIR"
    ;;

  ""|help|-h|--help)
    usage
    ;;
  *)
    echo "measure-fork-ab: unknown command: $CMD" >&2
    usage
    ;;
esac
