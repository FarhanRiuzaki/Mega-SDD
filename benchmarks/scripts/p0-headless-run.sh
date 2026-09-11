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
# Everything else is the plain runbook: no --classic / --lean / --lite, the front
# door decides. Transcript lands in ~/.claude/projects/<encoded-cwd>/<sid>.jsonl —
# that file + `git log` in the arm are the ONLY inputs to research/2026-08-04-p5-extract.py.
#
# usage: [P0_FLAGS="--lite"] p0-headless-run.sh <arm-dir> <prd-rel-path> <log-dir> [model]
#   prints the session id + transcript path; runs detached (nohup); exit 0 = launched.
#   P0_FLAGS (v8 P2, 2026-09-11): front-door flags spliced into the prompt verbatim
#   ("jalankan mega-sdd --lite dari …") so the classic and lite arms differ ONLY by
#   the flag (owner amendment 4: both arms on the same plugin version); recorded as
#   flags= in run.meta.
set -u
ARM="${1:?arm dir}"; PRD="${2:?prd rel path}"; LOG="${3:?log dir}"; MODEL="${4:-opus}"; FLAGS="${P0_FLAGS:-}"
[ -d "$ARM/.git" ] || { echo "not a git clone: $ARM" >&2; exit 2; }
[ -f "$ARM/$PRD" ] || { echo "PRD missing: $ARM/$PRD" >&2; exit 2; }
mkdir -p "$LOG"
SID="$(python3 -c 'import uuid;print(uuid.uuid4())')"
ENC="$(python3 -c 'import sys,re;print(re.sub(r"[^A-Za-z0-9]", "-", sys.argv[1]))' "$(cd "$ARM" && pwd -P)")"
TRANSCRIPT="$HOME/.claude/projects/$ENC/$SID.jsonl"
PROMPT="jalankan mega-sdd${FLAGS:+ $FLAGS} dari $PRD sampai semua unit selesai (DONE), lalu jalankan /mega-sdd:analyze di akhir."
SYS="Benchmark run on a disposable fixture (v8 P0 measurement, research/2026-09-10-v8-autonomous-runbook.md §1). The human owner is not present and AskUserQuestion is unavailable in this session. Whenever the mega-sdd chain would ask the user something (front-door confirmation, batched OQ, scope, toolchain, halts that wait for a human), choose the MOST CONSERVATIVE option yourself (the one easiest to revert: defer, keep vault, do not invent UI, do not widen scope), write one line '[ASSUMED-BY-RUNNER: <question> -> <choice>: <reason>]' in your reply, and CONTINUE the chain. Never stop to wait for a human. Do not skip or loosen any gate, validator, acceptance test or review — a failing gate is fixed by fixing the code, never by editing evidence files."
ALLOWED="Bash,Read,Write,Edit,MultiEdit,Glob,Grep,Skill,Agent,ToolSearch,TodoWrite,NotebookEdit,WebFetch"
{
  echo "sid=$SID"; echo "arm=$ARM"; echo "prd=$PRD"; echo "model=$MODEL"; echo "flags=$FLAGS"; echo "transcript=$TRANSCRIPT"
  echo "started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "head_before=$(cd "$ARM" && git rev-parse --short HEAD)"
  echo "plugin=$(claude plugin list 2>/dev/null | grep -A1 'mega-sdd@' | grep -o 'Version: .*' | head -1)"
} > "$LOG/run.meta"
cd "$ARM" || exit 2
nohup env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT claude -p "$PROMPT" \
  --model "$MODEL" --session-id "$SID" \
  --permission-mode acceptEdits --allowedTools "$ALLOWED" \
  --append-system-prompt "$SYS" \
  --output-format stream-json --verbose \
  < /dev/null > "$LOG/stream.jsonl" 2> "$LOG/stderr.log" &
echo "pid=$!" >> "$LOG/run.meta"
cat "$LOG/run.meta"
