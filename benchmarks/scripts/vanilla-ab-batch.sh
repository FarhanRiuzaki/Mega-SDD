#!/usr/bin/env bash
# vanilla-ab-batch.sh — run a vanilla-vs-mega-sdd block SEQUENTIALLY, one fresh fixture copy per
# run (benchmarks/runbooks/vanilla-vs-megasdd.md §4, §6). Each line of <plan> is
#   <scenario> <arm> <run-id> <prd-rel-path>
# with <arm> = vanilla | lite | classic | routed | guarded (routed = the front door with the PRD and no flag:
# the lane router decides; guarded = the front door with --guarded, the one spec pipeline — both P0_ENTRY=frontdoor). Per run:
#   1. cp -R <fixture> (node_modules included — installed OUTSIDE the clock) → <work>/<scenario>-<run-id>
#   2. vanilla only: the user-level /mega-sdd wrapper (~/.claude/commands/mega-sdd.md) is moved
#      aside for the run and restored after (the mega-sdd arm's session-start re-heals it anyway);
#      without this the arm's purity check fails, by design
#   3. launch via p0-headless-run.sh (mega-sdd arms load P0_PLUGIN_DIR when set), wait for exit,
#      kill at the wall cap (BENCH_WALL_CAP_MIN, default 240) and record timeout=1
#   4. git-log.txt + arm-metrics.py --repo --base → <results>/<scenario>/<arm>-<run-id>/metrics.json
# Runs are sequential on purpose: concurrent arms share the machine and the account rate limit.
#
# usage: vanilla-ab-batch.sh <plan> <fixture-dir> <work-dir> <results-dir> [model]
set -u
PLAN="${1:?plan}"; FIX="${2:?fixture}"; WORK="${3:?work dir}"; RES="${4:?results dir}"; MODEL="${5:-opus}"
BENCH="$(cd "$(dirname "$0")" && pwd -P)"
CAP=$(( ${BENCH_WALL_CAP_MIN:-240} * 60 ))
WRAP="$HOME/.claude/commands/mega-sdd.md"; WRAP_BAK="$HOME/.claude/commands/.mega-sdd.md.bench-bak"
BASE="$(git -C "$FIX" rev-parse HEAD)"
mkdir -p "$WORK" "$RES"
restore_wrapper() { [ -f "$WRAP_BAK" ] && mv -f "$WRAP_BAK" "$WRAP"; return 0; }
trap restore_wrapper EXIT INT TERM

while read -r SCEN ARMNAME RID PRD; do
  case "$SCEN" in ''|\#*) continue ;; esac
  OUT="$RES/$SCEN/$ARMNAME-$RID"; ARMDIR="$WORK/$SCEN-$ARMNAME-$RID"
  if [ -f "$OUT/metrics.json" ]; then echo "skip (done): $OUT"; continue; fi
  mkdir -p "$(dirname "$OUT")"; rm -rf "$ARMDIR"; cp -R "$FIX" "$ARMDIR"
  case "$ARMNAME" in
    vanilla) KIND=vanilla; FLAGS="" ;;
    lite)    KIND=megasdd; FLAGS="--lite" ;;
    classic) KIND=megasdd; FLAGS="" ;;
    routed)  KIND=megasdd; FLAGS="" ;;
    guarded) KIND=megasdd; FLAGS="--guarded" ;;
    *) echo "unknown arm: $ARMNAME" >&2; continue ;;
  esac
  [ "$KIND" = vanilla ] && [ -f "$WRAP" ] && mv -f "$WRAP" "$WRAP_BAK"
  echo "== $(date -u +%H:%M:%SZ) launch $SCEN $ARMNAME $RID"
  ENTRY=chain; case "$ARMNAME" in routed|guarded) ENTRY=frontdoor ;; esac
  P0_ARM=$KIND P0_ENTRY=$ENTRY P0_FLAGS="$FLAGS" P0_PLUGIN_DIR="${P0_PLUGIN_DIR:-}" \
    bash "$BENCH/p0-headless-run.sh" "$ARMDIR" "$PRD" "$OUT" "$MODEL" > "$OUT.launch.log" 2>&1
  PID=$(grep -m1 '^pid=' "$OUT/run.meta" 2>/dev/null | cut -d= -f2)
  START=$(date +%s)
  while [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; do
    if [ $(( $(date +%s) - START )) -gt "$CAP" ]; then
      kill "$PID" 2>/dev/null; echo "timeout=1 cap_min=$(( CAP / 60 ))" >> "$OUT/run.meta"; break
    fi
    sleep 20
  done
  echo "finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUT/run.meta"
  restore_wrapper
  git -C "$ARMDIR" log --format="%h %cI %s" > "$OUT/git-log.txt"
  python3 "$BENCH/arm-metrics.py" "$OUT" --repo "$ARMDIR" --base "$BASE" --json "$OUT/metrics.json" >/dev/null \
    || echo "metrics FAILED: $OUT" >&2
  grep -E '^(purity|timeout)=' "$OUT/run.meta"
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print('   wall',d['speed']['wall_min'],'review_ready',d['speed']['review_ready_min'],'cost',d['tokens']['cost_usd'],'clean',d['clean']['is_clean'])" "$OUT/metrics.json" 2>/dev/null
done < "$PLAN"
echo "== batch done $(date -u +%H:%M:%SZ)"
