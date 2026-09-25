#!/usr/bin/env bash
# windows-check.sh — the D32 release-gate check for the state anchor (8.8.0), run ONCE on an
# office laptop (Git Bash). Spec: docs/superpowers/specs/2026-09-25-state-anchor-design.md D32.
#
#   bash research/2026-09-26-state-anchor-fase2/windows-check.sh [<plugin-root>]
#
# <plugin-root> defaults to this repo's plugins/mega-sdd. Everything runs in a throwaway temp
# dir; nothing in any real project is touched. Paste the whole output back to the owner thread.
# It answers the D32 questions with numbers instead of assumptions:
#   1  git / bash / python versions (git >= 2.31 for --diff-merges)
#   2  `x=$(exec git …)` is ONE process on MSYS (the idiom the session-start miss path uses)
#   3  MSYS keeps `:(glob)**/Name` and `a..b` pathspecs intact (MSYS_NO_PATHCONV=1)
#   4  python piped stdout encoding (the gate prints `·` and `—`)
#   5  the production hooks on a fixture: process counts + wall ms for UPS, SessionStart
#      hit / miss, Stop steady, and the gate's in-run dispatch (ALLOW and DENY)
#   6  git-dir writes (the view cache + seen ring) under the EDR
set -u
PLUGIN="${1:-$(cd "$(dirname "$0")/../../plugins/mega-sdd" && pwd)}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME/.claude/commands" "$HOME/.claude/plugins/cache/x/superpowers"
V=$(grep -m1 '^WRAPPER_VERSION=' "$PLUGIN/scripts/install-front-door.sh" | tr -dc '0-9')
printf '<!-- mega-sdd-front-door-wrapper v%s -->\n' "$V" > "$HOME/.claude/commands/mega-sdd.md"
ms() { # GNU date (Git Bash) has %3N; BSD date prints a literal N → fall back to python
  local v; v=$(date +%s%3N 2>/dev/null)
  case "$v" in *[!0-9]*|"") v=$(python3 -c 'import time;print(int(time.time()*1000))' 2>/dev/null || python -c 'import time;print(int(time.time()*1000))') ;; esac
  printf '%s' "$v"; }
echo "== 1 versions"; uname -a; bash --version | head -1; git --version
for p in python3 python py; do command -v $p >/dev/null 2>&1 && echo "$p -> $(command -v $p) : $($p --version 2>&1)"; done

echo "== 2 \$(exec git …) process count"
SH="$T/shim"; CNT="$T/cnt"; mkdir -p "$SH"
for tool in bash git python3 python cat sed grep dirname uname date; do
  real=$(command -v "$tool" 2>/dev/null) || continue
  printf '#!/bin/bash\necho %s >> "%s"\nexec "%s" "$@"\n' "$tool" "$CNT" "$real" > "$SH/$tool"; chmod +x "$SH/$tool"
done
: > "$CNT"; PATH="$SH:$PATH" bash -c 'x=$(exec git --version) || rc=$?; echo "$x"' >/dev/null
echo "processes seen by the shim (bash itself + git): $(tr '\n' ' ' < "$CNT")"

echo "== 3 MSYS pathspec conversion"
R="$T/r"; mkdir -p "$R/a/b" && cd "$R" && git init -q . && echo 1 > a/b/Widget.tsx && git add -A && git -c user.name=t -c user.email=t@t commit -qm 1
echo 2 >> a/b/Widget.tsx && git -c user.name=t -c user.email=t@t commit -qam 2
echo "glob (NO_PATHCONV): [$(MSYS_NO_PATHCONV=1 git diff --name-only HEAD~1 HEAD -- ':(glob)**/Widget.tsx')]"
echo "glob (default):     [$(git diff --name-only HEAD~1 HEAD -- ':(glob)**/Widget.tsx')]"
echo "range a..b:         [$(MSYS_NO_PATHCONV=1 git log --format=%h HEAD~1..HEAD | tr '\n' ' ')]"
cd "$T"

echo "== 4 python piped stdout encoding"
for p in python3 python; do command -v $p >/dev/null 2>&1 && echo "$p: $($p -c 'import sys;print(sys.stdout.encoding)' | cat) / utf8-forced: $(PYTHONIOENCODING=utf-8 $p -c 'print("· —")' | cat)"; done

echo "== 5 production hooks on a fixture"
F="$T/proj"; VA="$F/.mega-sdd/vaults/web"; mkdir -p "$F/src" "$VA/units"
printf 'lane: lite\n' > "$F/.mega-sdd/config.yaml"
printf 'export const a = 1\nexport function api() {}\n' > "$F/src/client.ts"; printf 'x\n' > "$F/src/Login.tsx"
printf -- '---\nid: U-001\ntitle: t\ntarget_files:\n  - path: src/Login.tsx\n    operation: modify\nacceptance_test:\n  - type: test\n    command: x\n    expects: "ok"\n---\n## Anchors\n- `src/client.ts:1-2` — `api`\n' > "$VA/units/U-001.md"
( cd "$F" && git init -q . && git add -A && git -c user.name=t -c user.email=t@t commit -qm seed )
bash "$PLUGIN/scripts/derive-unit-claims.sh" --cwd="$F" --vault="$VA" --units=U-001 >/dev/null 2>&1
bash "$PLUGIN/scripts/write-unit-binding.sh" --cwd="$F" --vault="$VA" --unit=U-001 --claims="$VA/bolts/_wave-claims.json" >/dev/null 2>&1
SHA=$(python -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$VA/bolts/U-001/binding.json" 2>/dev/null || python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$VA/bolts/U-001/binding.json")
printf 'mega-sdd-trace:execute-bolts:U-001\n  binding_sha256: %s\n' "$SHA" > "$VA/bolts/U-001/dispatch-prompt.md"
run() { # label hook json
  : > "$CNT"; local a b; a=$(ms)
  ( cd "$F" && printf '%s' "$3" | PATH="$SH:$PATH" bash "$PLUGIN/hooks/$2" >"$T/out" 2>/dev/null )
  b=$(ms); sleep 1
  printf '%-32s procs=%-3s ms=%-6s %s\n' "$1" "$(grep -c . "$CNT")" "$((b - a))" "$(tr '\n' ' ' < "$CNT" | head -c 160)"
}
run "Stop (bootstrap, no cache)" stop "{\"session_id\":\"s\",\"cwd\":\"$F\",\"transcript_path\":\"/x\"}"
sleep 1
run "SessionStart HIT" session-start '{"source":"startup","session_id":"sess-win-0001"}'
grep -q '^mega-sdd state @' "$T/out" && echo "   block printed: $(grep -c . "$T/out") lines" || echo "   !! no state block"
run "UserPromptSubmit" user-prompt-submit "{\"session_id\":\"sess-win-0001\",\"cwd\":\"$F\",\"prompt\":\"hi\"}"
( cd "$F" && echo 'export const c = 3' >> src/client.ts && git -c user.name=t -c user.email=t@t commit -qam "feat: moved" )
run "SessionStart MISS" session-start '{"source":"startup","session_id":"sess-win-0002"}'
run "UserPromptSubmit after move" user-prompt-submit "{\"session_id\":\"sess-win-0001\",\"cwd\":\"$F\",\"prompt\":\"hi\"}"
grep -q 'HEAD moved this session' "$T/out" && echo "   HEAD-moved line printed" || echo "   !! no HEAD-moved line"
run "Stop steady" stop "{\"session_id\":\"s\",\"cwd\":\"$F\",\"transcript_path\":\"/x\"}"
P="mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: $VA/bolts/U-001/dispatch-prompt.md"
run "Gate in-run (expect DENY stale)" pre-tool-use "{\"session_id\":\"s\",\"cwd\":\"$F\",\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"mega-sdd:bolt-implementer\",\"prompt\":\"$P\"}}"
grep -q 'binding_stale' "$T/out" && echo "   DENY binding_stale ok" || echo "   !! expected binding_stale: $(head -c 300 "$T/out")"

echo "== 6 git-dir writes under the EDR"
GD=$(cd "$F" && git rev-parse --git-dir)
ls -la "$F/$GD"/mega-sdd-* 2>/dev/null || ls -la "$GD"/mega-sdd-* 2>/dev/null || echo "   !! no view cache / seen ring in the git dir"
echo "== done"
