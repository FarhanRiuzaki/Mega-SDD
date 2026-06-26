#!/usr/bin/env bash
# Functional: PreCompact snapshot + Stop compaction advisor + session resume line.
set -u
err=0
PC=plugins/mega-sdd/hooks/pre-compact
ST=plugins/mega-sdd/hooks/stop
SS=plugins/mega-sdd/hooks/session-start

bash -n "$PC" || { echo "pre-compact syntax error"; err=1; }
bash -n "$ST" || { echo "stop syntax error"; err=1; }
bash -n "$SS" || { echo "session-start syntax error"; err=1; }

# hooks.json wires PreCompact
grep -q '"PreCompact"' plugins/mega-sdd/hooks/hooks.json || { echo "hooks.json missing PreCompact"; err=1; }
grep -q 'pre-compact' plugins/mega-sdd/hooks/hooks.json || { echo "hooks.json PreCompact not routed"; err=1; }

# PreCompact: fixture vault with units + bolts -> snapshot with phase guess + HEAD
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
( cd "$T" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base )
mkdir -p "$T/.mega-sdd/vaults/v/units" "$T/.mega-sdd/vaults/v/bolts/U-001"
printf -- '---\nid: U-001\n---\n' > "$T/.mega-sdd/vaults/v/units/U-001.md"
printf -- '---\nid: U-002\n---\n' > "$T/.mega-sdd/vaults/v/units/U-002.md"
echo "# report" > "$T/.mega-sdd/vaults/v/bolts/U-001/bolt-report.md"
printf '{"cwd":"%s","trigger":"auto"}' "$T" | bash "$PC"
SNAP="$T/.mega-sdd/.compaction-snapshot.json"
[ -f "$SNAP" ] || { echo "snapshot not written"; err=1; }
if [ -f "$SNAP" ]; then
  grep -q '"trigger": "auto"' "$SNAP" || { echo "snapshot missing trigger"; err=1; }
  grep -q '"units_total": 2' "$SNAP" || { echo "snapshot wrong units_total"; err=1; }
  grep -q '"bolts_done": 1' "$SNAP" || { echo "snapshot wrong bolts_done"; err=1; }
  grep -qi 'executing bolts' "$SNAP" || { echo "snapshot missing phase guess"; err=1; }
fi
# malformed vault still exits 0 (no crash)
rm -rf "$T/.mega-sdd/vaults/v/units"
printf '{"cwd":"%s","trigger":"manual"}' "$T" | bash "$PC"; [ $? -eq 0 ] || { echo "pre-compact must exit 0 on degenerate vault"; err=1; }
# non-mega-sdd dir: no snapshot, exit 0
T2=$(mktemp -d); printf '{"cwd":"%s","trigger":"auto"}' "$T2" | bash "$PC"; [ $? -eq 0 ] || { echo "non-sdd must exit 0"; err=1; }
[ -f "$T2/.mega-sdd/.compaction-snapshot.json" ] && { echo "non-sdd wrote a snapshot"; err=1; }; rm -rf "$T2"

# Compaction advisor lives on UserPromptSubmit (doc audit: Stop stdout is
# debug-log-only; UserPromptSubmit stdout reaches context). Over-threshold +
# active vault -> notice; opt-out honored; under-threshold silent; Stop is clean.
UPS=plugins/mega-sdd/hooks/user-prompt-submit
bash -n "$UPS" || { echo "user-prompt-submit syntax error"; err=1; }
T3=$(mktemp -d)
mkdir -p "$T3/.mega-sdd/vaults/v/units"
printf -- '---\nid: U-001\n---\n' > "$T3/.mega-sdd/vaults/v/units/U-001.md"
TRANS=$(mktemp)
# Over-threshold fixture: claude-fable-5 is a 1M-context family (user-prompt-submit
# resolves its window to 1,000,000), so the advisor fires at >80% = >800k tokens.
# 905k context (900k cache_read + 10k input + 5k cache_creation = 915k) clears the bar.
printf '%s\n' '{"message":{"usage":{"input_tokens":10000,"cache_read_input_tokens":900000,"cache_creation_input_tokens":5000,"output_tokens":2000},"model":"claude-fable-5"}}' > "$TRANS"
out=$(printf '{"cwd":"%s","transcript_path":"%s"}' "$T3" "$TRANS" | bash "$UPS")
echo "$out" | grep -qi 'safe place to /compact' || { echo "advisor did not fire over threshold"; err=1; }
# opt-out
echo "compaction_notice: false" > "$T3/.mega-sdd/config.yaml"
out=$(printf '{"cwd":"%s","transcript_path":"%s"}' "$T3" "$TRANS" | bash "$UPS")
echo "$out" | grep -qi 'safe place to /compact' && { echo "opt-out not honored"; err=1; }
rm -f "$T3/.mega-sdd/config.yaml"
# under threshold -> silent
printf '%s\n' '{"message":{"usage":{"input_tokens":1000,"cache_read_input_tokens":5000,"cache_creation_input_tokens":1000},"model":"claude-fable-5"}}' > "$TRANS"
out=$(printf '{"cwd":"%s","transcript_path":"%s"}' "$T3" "$TRANS" | bash "$UPS")
echo "$out" | grep -qi 'safe place to /compact' && { echo "advisor fired under threshold"; err=1; }
# Stop hook no longer emits the advisor (relocated)
printf '%s\n' '{"message":{"usage":{"input_tokens":10000,"cache_read_input_tokens":160000,"cache_creation_input_tokens":5000}}}' > "$TRANS"
mkdir -p "$T3/.mega-sdd/memory"; : > "$T3/.mega-sdd/memory/telemetry.jsonl"
out=$(printf '{"cwd":"%s","transcript_path":"%s","session_id":"s1","stop_hook_active":"false"}' "$T3" "$TRANS" | bash "$ST")
echo "$out" | grep -qi 'safe place to /compact' && { echo "Stop still emits advisor (should be relocated)"; err=1; }
# hooks.json wires UserPromptSubmit + dropped MultiEdit
grep -q '"UserPromptSubmit"' plugins/mega-sdd/hooks/hooks.json || { echo "hooks.json missing UserPromptSubmit"; err=1; }
grep -q 'MultiEdit' plugins/mega-sdd/hooks/hooks.json && { echo "hooks.json still has MultiEdit (not a current tool)"; err=1; }
grep -q 'Skill|Bash|Edit|Write"' plugins/mega-sdd/hooks/hooks.json || { echo "PreToolUse matcher not Edit|Write"; err=1; }
rm -f "$TRANS"; rm -rf "$T3"

# SessionStart resume line from a snapshot
T4=$(mktemp -d); mkdir -p "$T4/.mega-sdd/vaults/v"
printf '{"ts":"x","trigger":"auto","head":"abc","phase":{"guess":"executing bolts (1/2 done)","units_total":2,"bolts_done":1},"pending_sync_open":0}' > "$T4/.mega-sdd/.compaction-snapshot.json"
out=$(cd "$T4" && printf '{"session_id":"s1","cwd":"%s","source":"compact"}' "$T4" | bash "$OLDPWD/$SS")
echo "$out" | grep -qi 'resumed after a compaction' || { echo "session-start missing resume line"; err=1; }
rm -rf "$T4"

# config key documented
grep -q 'compaction_notice' plugins/mega-sdd/references/project-config.md || { echo "project-config missing compaction_notice"; err=1; }
exit $err
