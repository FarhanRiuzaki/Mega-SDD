#!/usr/bin/env bash
# dirty-journal.test.sh — living-vault S1: PostToolUse Write/Edit journal append.
# Pins: (1) mapped-repo source write IS journaled with repo-relative path;
#       (2) .mega-sdd/** writes are NEVER journaled (anti-feedback-loop);
#       (3) unmapped repos get NO journal;
#       (4) hook exits 0 in all cases (advisory, never blocks).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/../../plugins/mega-sdd/hooks/post-tool-use"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0

# Case 1: mapped repo, source write → journaled
mkdir -p "$TMP/mapped/.mega-sdd/codebase" "$TMP/mapped/app"
echo "# map" > "$TMP/mapped/.mega-sdd/codebase/codebase-map.md"
printf '%s' "{\"session_id\":\"t\",\"cwd\":\"$TMP/mapped\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMP/mapped/app/user.rb\"}}" | bash "$HOOK" >/dev/null 2>&1
J="$TMP/mapped/.mega-sdd/codebase/.dirty-paths.jsonl"
if grep -q '"path":"app/user.rb"' "$J" 2>/dev/null; then echo "PASS (mapped source write journaled)"; else echo "FAIL (mapped source write NOT journaled)"; rc=1; fi

# Case 2: own-output write → NOT journaled
printf '%s' "{\"session_id\":\"t\",\"cwd\":\"$TMP/mapped\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMP/mapped/.mega-sdd/vaults/x/binding.md\"}}" | bash "$HOOK" >/dev/null 2>&1
ROWS=$(grep -c . "$J" 2>/dev/null || echo 0)
if [ "$ROWS" = "1" ]; then echo "PASS (own-output write not journaled)"; else echo "FAIL (journal rows=$ROWS, expected 1)"; rc=1; fi

# Case 3: unmapped repo → no journal
mkdir -p "$TMP/unmapped/src"
printf '%s' "{\"session_id\":\"t\",\"cwd\":\"$TMP/unmapped\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMP/unmapped/src/a.go\"}}" | bash "$HOOK" >/dev/null 2>&1
if [ ! -f "$TMP/unmapped/.mega-sdd/codebase/.dirty-paths.jsonl" ]; then echo "PASS (unmapped repo not journaled)"; else echo "FAIL (unmapped repo journaled)"; rc=1; fi

# Case 4: journal past 1 MB → hook stops appending (runaway guard)
python3 -c "open('$TMP/mapped/.mega-sdd/codebase/.dirty-paths.jsonl','w').write('x'*1100000)"
printf '%s' "{\"session_id\":\"t\",\"cwd\":\"$TMP/mapped\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMP/mapped/app/more.rb\"}}" | bash "$HOOK" >/dev/null 2>&1
SZ=$(wc -c < "$J" 2>/dev/null | tr -d ' ')
if [ "$SZ" = "1100000" ]; then echo "PASS (1MB cap: no append)"; else echo "FAIL (cap breached: size=$SZ)"; rc=1; fi

[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
