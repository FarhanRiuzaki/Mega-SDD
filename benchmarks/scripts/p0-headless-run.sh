#!/usr/bin/env bash
# p0-headless-run.sh — launch ONE P5/P0 measurement arm as a headless Claude Code
# session on a FIXTURE clone (v8 autonomous program §1, 2026-09-10). The owner is
# not standing by, so the run is driven by `claude -p`; the deviations from the
# interactive P5 protocol are stated here and in the report, not hidden:
#   - AskUserQuestion is DISABLED under -p (probed 2026-09-10: "No such tool
#     available … disabled for this session, in subagents as well as here"). Every
#     ask the chain would raise shows up in the transcript as a tool_use attempt
#     that errors; the model is told (system prompt below) to take the most
#     conservative option itself and tag it [ASSUMED-BY-RUNNER]. So:
#       interaction_points = ask ATTEMPTS (countable), human-wait = 0 by
#       construction, idle_ratio measures model+tool time only.
#   - Permissions: an explicit --allowedTools allowlist (never the global bypass).
#   - Model pinned (default opus = parity with both P5 arms).
#   - Headless failure mode (2026-09-14, lite 7.37.0 arm): the controller ended its
#     turn while two implementers ran; `claude -p` waited exactly 10 min, killed the
#     remaining agents and exited with a `success` result — DONE never reached. The
#     system prompt now forbids ending the turn while background work runs; the chain
#     scripts add a same-session `--resume` guard keyed on .mega-sdd/CONSISTENCY-REPORT.md.
# Everything else is the plain runbook: no --classic / --lean / --lite, the front
# door decides. Transcript lands in ~/.claude/projects/<encoded-cwd>/<sid>.jsonl —
# that file + `git log` in the arm are the ONLY inputs to research/2026-08-04-p5-extract.py (commit 04d2e0ab).
#
# Vanilla control arm (P0_ARM=vanilla, 2026-09-26): the SAME launcher, model, tool allowlist,
#   permission mode and headless rules, but the mega-sdd plugins are disabled for the session
#   (--settings enabledPlugins false) and the prompt is the plain product task — so every
#   "mega-sdd vs Claude Code" claim has a like-for-like denominator. Purity is verified from the
#   stream's init record (plugins / skills / slash commands): a vanilla arm that still loads any
#   mega-sdd surface is KILLED and marked purity=FAIL (not data). Both arms record the full
#   plugin roster (plugins=) — other plugins are a confound to hold equal across arms, not hide.
#
# usage: [P0_ARM=megasdd|vanilla] [P0_ENTRY=chain|frontdoor] [P0_FLAGS="--lite"] [P0_PLUGIN_DIR=<plugin tree>] p0-headless-run.sh <arm-dir> <prd-rel-path> <log-dir> [model]
#   prints the session id + transcript path; runs detached (nohup); exit 0 = launched.
#   P0_FLAGS (v8 P2, 2026-09-11): front-door flags spliced into the prompt verbatim
#   ("jalankan mega-sdd --lite dari …") so the classic and lite arms differ ONLY by
#   the flag (owner amendment 4: both arms on the same plugin version); recorded as
#   flags= in run.meta.
set -u
ARM="${1:?arm dir}"; PRD="${2:?prd rel path}"; LOG="${3:?log dir}"; MODEL="${4:-opus}"; FLAGS="${P0_FLAGS:-}"
KIND="${P0_ARM:-megasdd}"
case "$KIND" in megasdd|vanilla) ;; *) echo "P0_ARM must be megasdd|vanilla: $KIND" >&2; exit 2 ;; esac
[ "$KIND" = vanilla ] && [ -n "$FLAGS" ] && { echo "P0_FLAGS is a mega-sdd front-door flag; not valid with P0_ARM=vanilla" >&2; exit 2; }
[ -d "$ARM/.git" ] || { echo "not a git clone: $ARM" >&2; exit 2; }
[ -f "$ARM/$PRD" ] || { echo "PRD missing: $ARM/$PRD" >&2; exit 2; }
mkdir -p "$LOG"; LOG="$(cd "$LOG" && pwd -P)"   # absolute: the launcher cd's into the arm below
SID="$(python3 -c 'import uuid;print(uuid.uuid4())')"
ENC="$(python3 -c 'import sys,re;print(re.sub(r"[^A-Za-z0-9]", "-", sys.argv[1]))' "$(cd "$ARM" && pwd -P)")"
TRANSCRIPT="$HOME/.claude/projects/$ENC/$SID.jsonl"
PROMPT="jalankan mega-sdd${FLAGS:+ $FLAGS} dari $PRD sampai semua unit selesai (DONE), lalu jalankan /mega-sdd:analyze di akhir."
# P0_ENTRY=frontdoor (2026-09-27, lane router): the way a user starts the plugin — the front
# door command with the PRD, nothing about units or analyze in the prompt (that wording presumed
# the pipeline and forced an analyze pass). The front door's route-lane.sh then picks the lane.
ENTRY="${P0_ENTRY:-chain}"
case "$ENTRY" in chain|frontdoor) ;; *) echo "P0_ENTRY must be chain|frontdoor: $ENTRY" >&2; exit 2 ;; esac
[ "$ENTRY" = frontdoor ] && PROMPT="/mega-sdd:mega-sdd${FLAGS:+ $FLAGS} $PRD"
# Vanilla task = the same deliverable the mega-sdd chain is judged on (every requirement +
# Definition of Done / acceptance criterion of the PRD, tests, green suite, committed code),
# with no method prescribed — Claude Code decides how to plan, test and review.
VPROMPT="implementasikan $PRD sepenuhnya di repo ini: setiap requirement dan setiap Definition of Done / acceptance criterion di PRD terpenuhi, dengan test untuk tiap kriteria, seluruh test suite hijau, dan pekerjaan di-commit ke git dengan pesan yang jelas."
VSYS="Benchmark run on a disposable fixture (vanilla control arm, benchmarks/runbooks/vanilla-vs-megasdd.md). The human owner is not present and AskUserQuestion is unavailable in this session. Whenever you would ask the user something, choose the MOST CONSERVATIVE option yourself (the one easiest to revert: defer, do not invent UI, do not widen scope), write one line '[ASSUMED-BY-RUNNER: <question> -> <choice>: <reason>]' in your reply, and CONTINUE. Never stop to wait for a human. Never weaken, skip or delete a test to make it pass — a failing test is fixed by fixing the code. NEVER end your turn while any background agent or task is still running — this is a headless session: an ended turn exits the process 10 minutes later. Only end the turn when the work is complete and committed."
# The mega-sdd arm launches exactly as before, unless P0_PLUGIN_DIR pins a plugin TREE (the
# installed marketplace copy is then disabled and the tree is loaded as mega-sdd@inline — a
# release candidate measured without touching the user's global plugin cache).
DISABLE='{"enabledPlugins":{"mega-sdd@mega-sdd":false,"mega-sdd-extras@mega-sdd":false}}'
EXTRA=(); PLUGIN_VER=""
if [ "$KIND" = vanilla ]; then
  PROMPT="$VPROMPT"
  EXTRA=(--settings "$DISABLE")
elif [ -n "${P0_PLUGIN_DIR:-}" ]; then
  case "$P0_PLUGIN_DIR" in /*) ;; *) P0_PLUGIN_DIR="$PWD/$P0_PLUGIN_DIR" ;; esac   # claude starts in $ARM
  [ -f "$P0_PLUGIN_DIR/.claude-plugin/plugin.json" ] || { echo "P0_PLUGIN_DIR is not a plugin tree: $P0_PLUGIN_DIR" >&2; exit 2; }
  # plugin= must name the TREE under test, not the installed copy this session disables (the 9.0
  # smoke recorded plugin=Version: 8.7.2 beside purity=PASS mega-sdd 9.0.0). No version = no run.
  PLUGIN_VER="$(python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get("version"); print(v) if v else sys.exit(1)' \
    "$P0_PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null)" \
    || { echo "P0_PLUGIN_DIR plugin.json has no readable version: $P0_PLUGIN_DIR" >&2; exit 2; }
  PLUGIN_VER="Version: $PLUGIN_VER"
  EXTRA=(--settings "$DISABLE" --plugin-dir "$P0_PLUGIN_DIR")
fi
SYS="Benchmark run on a disposable fixture (v8 P0 measurement, research/2026-09-10-v8-autonomous-runbook.md §1). The human owner is not present and AskUserQuestion is unavailable in this session. Whenever the mega-sdd chain would ask the user something (front-door confirmation, batched OQ, scope, toolchain, halts that wait for a human), choose the MOST CONSERVATIVE option yourself (the one easiest to revert: defer, keep vault, do not invent UI, do not widen scope), write one line '[ASSUMED-BY-RUNNER: <question> -> <choice>: <reason>]' in your reply, and CONTINUE the chain. Never stop to wait for a human. Do not skip or loosen any gate, validator, acceptance test or review — a failing gate is fixed by fixing the code, never by editing evidence files. NEVER end your turn while any background implementer, panel lens or task is still running — this is a headless session: an ended turn exits the process 10 minutes later and the chain dies (v8 P2 lite 7.37.0 arm, 2026-09-14). Wait for background results with a blocking poll and only end the turn after /mega-sdd:analyze has run."
[ "$ENTRY" = frontdoor ] && SYS="${SYS% Wait for background results*} Wait for background results with a blocking poll and only end the turn when the work is complete and committed."
[ "$KIND" = vanilla ] && SYS="$VSYS"
ALLOWED="Bash,Read,Write,Edit,MultiEdit,Glob,Grep,Skill,Agent,ToolSearch,TodoWrite,NotebookEdit,WebFetch"
{
  echo "sid=$SID"; echo "arm=$ARM"; echo "prd=$PRD"; echo "model=$MODEL"; echo "flags=$FLAGS"; echo "entry=$ENTRY"; echo "arm_kind=$KIND"; echo "transcript=$TRANSCRIPT"
  echo "started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "head_before=$(cd "$ARM" && git rev-parse --short HEAD)"
  echo "plugin=${PLUGIN_VER:-$(claude plugin list 2>/dev/null | grep -A1 'mega-sdd@' | grep -o 'Version: .*' | head -1)}"; echo "plugin_dir=${P0_PLUGIN_DIR:-}"
} > "$LOG/run.meta"
BENCH="$(cd "$(dirname "$0")" && pwd -P)"   # before the cd below: $0 may be relative
cd "$ARM" || exit 2
nohup env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT claude -p "$PROMPT" \
  --model "$MODEL" --session-id "$SID" \
  --permission-mode acceptEdits --allowedTools "$ALLOWED" \
  --append-system-prompt "$SYS" ${EXTRA[@]+"${EXTRA[@]}"} \
  --output-format stream-json --verbose \
  < /dev/null > "$LOG/stream.jsonl" 2> "$LOG/stderr.log" &
PID=$!
echo "pid=$PID" >> "$LOG/run.meta"
# Arm purity + plugin roster from the init record (first ~90 s of the session).
for _ in $(seq 1 90); do
  grep -q '"subtype":"init"' "$LOG/stream.jsonl" 2>/dev/null && break
  sleep 1
done
if python3 "$BENCH/arm-purity.py" "$LOG/stream.jsonl" "$KIND" >> "$LOG/run.meta"; then
  :
else
  kill "$PID" 2>/dev/null
  echo "KILLED: arm purity failed (see purity= in run.meta) — not data" >&2
fi
cat "$LOG/run.meta"
