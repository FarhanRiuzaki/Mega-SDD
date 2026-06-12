#!/usr/bin/env bash
# Functional: SessionStart injects top instincts (conf >=0.7), bounded; opt-out honored.
# Plus wiring pins: schema ref routed, learning-rules owns emission, config keys, hooks matcher.
set -u
err=0
SS=plugins/mega-sdd/hooks/session-start

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.mega-sdd/memory/instincts" "$T/.mega-sdd/vaults"
cat > "$T/.mega-sdd/memory/instincts/high.yaml" <<'Y'
id: high
trigger: "rendering a money field"
action: "use the project money helper"
confidence: 0.8
domain: ui
scope: project
status: active
Y
cat > "$T/.mega-sdd/memory/instincts/low.yaml" <<'Y'
id: low
trigger: "low-signal thing"
action: "should not inject"
confidence: 0.5
domain: general
scope: project
status: active
Y
cat > "$T/.mega-sdd/memory/instincts/retired.yaml" <<'Y'
id: retired
trigger: "old thing"
action: "should not inject either"
confidence: 0.9
domain: general
scope: project
status: retired
Y

out=$(cd "$T" && printf '{"session_id":"s1","cwd":"%s","source":"startup"}' "$T" | bash "$OLDPWD/$SS")
echo "$out" | grep -q '<learned-instincts>' || { echo "instinct block missing"; err=1; }
echo "$out" | grep -q 'money helper' || { echo "conf-0.8 instinct not injected"; err=1; }
echo "$out" | grep -q 'should not inject' && { echo "conf-0.5 or retired instinct leaked in"; err=1; }
echo "$out" | grep -qi 'unless the user' || { echo "advisory disclaimer missing"; err=1; }
# opt-out
echo "instincts: false" > "$T/.mega-sdd/config.yaml"
out=$(cd "$T" && printf '{"session_id":"s1","cwd":"%s","source":"startup"}' "$T" | bash "$OLDPWD/$SS")
echo "$out" | grep -q '<learned-instincts>' && { echo "instincts: false not honored"; err=1; }

# wiring pins
grep -q 'references/instincts.md' plugins/mega-sdd/skills/memory/SKILL.md || { echo "SKILL.md does not route instincts.md"; err=1; }
grep -q 'Instinct emission' plugins/mega-sdd/skills/memory/references/learning-rules.md || { echo "learning-rules missing instinct emission"; err=1; }
grep -q '_seen.jsonl' plugins/mega-sdd/skills/memory/references/instincts.md || { echo "instincts.md missing promotion ledger"; err=1; }
grep -q 'instincts:' plugins/mega-sdd/references/project-config.md || { echo "project-config missing instincts key"; err=1; }
grep -q 'gateguard:' plugins/mega-sdd/references/project-config.md || { echo "project-config missing gateguard key"; err=1; }
grep -q 'Skill|Bash|Edit|Write' plugins/mega-sdd/hooks/hooks.json || { echo "hooks.json PreToolUse matcher not widened for Edit/Write"; err=1; }
grep -q 'MultiEdit' plugins/mega-sdd/hooks/hooks.json && { echo "hooks.json still references MultiEdit (not a current tool)"; err=1; }
grep -q 'instincts' plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md || { echo "T2 historical-memory slice missing instincts"; err=1; }
bash -n "$SS" || { echo "session-start syntax error"; err=1; }
bash -n plugins/mega-sdd/hooks/pre-tool-use || { echo "pre-tool-use syntax error"; err=1; }
exit $err
