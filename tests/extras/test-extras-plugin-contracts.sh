#!/usr/bin/env bash
# test-extras-plugin-contracts.sh — mega-sdd-extras P0 pins (spec 2026-09-06 §5):
#   1. manifests: extras plugin.json valid + marketplace parity for EVERY plugin entry
#      (closes the gap where CI only anchors plugins[0]);
#   2. zero-cost: extras ships NO hooks/, NO scripts/, NO .mcp.json;
#   3. containment: skill description carries no census phrase, no bare `key: value`
#      (valid YAML), states never-auto-triggers; command dispatches the skill;
#   4. wording pins: one page per invocation, never starts a server, never writes
#      pipeline state, NOT verified, tokens NOT AVAILABLE, the Figma ladder, forceCode ban,
#      installed_plugins.json resolution;
#   5. core UNCHANGED: no core slice skill/command, exactly 6 core command files,
#      anchor core byte length pinned (same awk as the playwright-embed suite).
# CI-safe: bash + python3 only. `claude plugin validate` runs when the CLI is on PATH.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
X="$REPO/plugins/mega-sdd-extras"
P="$REPO/plugins/mega-sdd"
SK="$X/skills/slice-design/SKILL.md"
PR="$X/skills/slice-design/references/slice-procedure.md"
CMD="$X/commands/slice.md"
fails=0
ok()   { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
has()  { grep -qF -- "$2" "$1"; }

echo "── 1: manifests + marketplace parity (every entry) ──"
python3 - "$REPO" <<'EOF' && ok "plugin.json valid, marketplace parity holds for every plugin entry" || fail "manifest/marketplace parity"
import json, sys, os
R = sys.argv[1]
mp = json.load(open(os.path.join(R, ".claude-plugin", "marketplace.json")))
plugins = mp["plugins"]
assert len(plugins) == 2, f"expected 2 marketplace entries, got {len(plugins)}"
names = [p["name"] for p in plugins]
assert names == ["mega-sdd", "mega-sdd-extras"], names
for p in plugins:
    src = p["source"].lstrip("./")
    pj = json.load(open(os.path.join(R, src, ".claude-plugin", "plugin.json")))
    assert pj["name"] == p["name"], (pj["name"], p["name"])
    assert pj["version"] == p["version"], f"{p['name']}: marketplace {p['version']} != plugin.json {pj['version']}"
x = json.load(open(os.path.join(R, "plugins/mega-sdd-extras/.claude-plugin/plugin.json")))
assert x["name"] == "mega-sdd-extras" and x["version"].count(".") == 2
EOF

echo "── 2: zero-cost — no hooks, scripts, or MCP servers in extras ──"
for d in hooks scripts .mcp.json; do
  [ -e "$X/$d" ] && fail "extras ships $d (zero-cost rail broken)" || ok "extras has no $d"
done

echo "── 3: containment + YAML-safe description ──"
DESC=$(awk 'BEGIN{f=0} /^---[[:space:]]*$/{f++; next} f==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$SK")
[ -n "$DESC" ] && ok "skill description present" || fail "skill description missing"
BODY=$(printf '%s' "$DESC" | sed 's/^"//; s/"$//')
printf '%s' "$BODY" | grep -q ': ' && fail "description carries a bare 'key: value' colon-space (breaks YAML frontmatter)" || ok "description has no colon-space"
[ "${#BODY}" -le 1024 ] && ok "description ≤ 1024 chars (${#BODY})" || fail "description too long (${#BODY})"
printf '%s' "$BODY" | grep -qi 'never auto-triggers' && ok "description declares never-auto-triggers" || fail "description lacks the never-auto-triggers clause"
CENSUS='spec out|dev handoff|pecah PRD|buat dev|siapkan context|kontrak handoff|extract intelligence|reverse engineer|legacy intelligence|pecah legacy|rebuild|revamp|jalankan otomatis|orchestrate|open questions|knowledge-base|bound-vault|kode berubah|lanjutin'
printf '%s' "$BODY" | grep -qiE "$CENSUS" && fail "description leaks a core census trigger phrase" || ok "description census-free"
has "$CMD" "mega-sdd-extras:slice-design" && ok "command dispatches mega-sdd-extras:slice-design" || fail "command does not dispatch the skill"
L=$(wc -l < "$SK" | tr -d ' '); [ "$L" -le 200 ] && ok "SKILL.md ≤ 200 lines ($L)" || fail "SKILL.md too long ($L)"
has "$PR" "## Contents" && ok "procedure reference carries a ToC" || fail "procedure reference lacks ## Contents"
has "$SK" "references/slice-procedure.md" && ok "SKILL.md routes its reference (one level deep)" || fail "reference unrouted"

echo "── 4: wording pins (the rails the field run relies on) ──"
for pin in "One page per invocation" "never starts, installs, or backgrounds" "never writes mega-sdd pipeline state" "NOT verified" "NOT AVAILABLE" "mega-sdd-trace:slice-design" "never auto-triggers" "installed_plugins.json"; do
  has "$SK" "$pin" && ok "SKILL pin: $pin" || fail "SKILL pin missing: $pin"
done
for pin in "get_metadata" "get_design_context" "get_variable_defs" "get_screenshot" "forceCode" "figma-design-to-code" "installed_plugins.json" "satu page per jalan" "never start, install, or background"; do
  has "$PR" "$pin" && ok "procedure pin: $pin" || fail "procedure pin missing: $pin"
done
grep -qE 'get_metadata.*get_design_context|get_design_context.*get_variable_defs' "$SK" && ok "SKILL states the Figma ladder order" || fail "ladder order not stated"
for pin in "One page per invocation" "NEVER writes mega-sdd pipeline state" "never starts, installs, or backgrounds" "NOT verified"; do
  has "$CMD" "$pin" && ok "command pin: $pin" || fail "command pin missing: $pin"
done

echo "── 5: core UNCHANGED ──"
[ -e "$P/skills/slice-design" ] && fail "core regrew skills/slice-design" || ok "core has no slice-design skill (v7.4.0 removal stands)"
[ -e "$P/commands/slice.md" ] && fail "core regrew commands/slice.md" || ok "core has no commands/slice.md"
N=$(ls "$P/commands"/*.md | wc -l | tr -d ' '); [ "$N" -eq 6 ] && ok "core command surface still 6 files" || fail "core command surface is $N files"
CORE=$(awk 'BEGIN{dash=0;body=0}
  /^---[[:space:]]*$/{dash++; if(dash==2)body=1; next}
  body==0{next}
  /ANCHOR-CORE ends/{exit}
  {print}' "$P/skills/using-mega-sdd/SKILL.md")
n=$(printf '%s' "$CORE" | wc -c | tr -d ' ')
[ "$n" -eq 3844 ] && ok "core anchor unchanged ($n B — extras adds nothing to it)" || fail "core anchor changed: $n B (baseline 3844)"
printf '%s' "$CORE" | grep -qi "extras\|slice" && fail "extras/slice leaked into the core anchor" || ok "no extras/slice mention in the core anchor"
has "$P/references/paths.md" ".mega-sdd/slices/" && ok "core paths.md lists the slices/ artifact home" || fail "paths.md lacks the slices/ row"
grep -q 'mega-sdd-extras.*built' "$P/CLAUDE.md" && ok "core CLAUDE.md clause records extras as built" || fail "CLAUDE.md clause still says demand-only"
grep -q 'claude plugin validate plugins/mega-sdd-extras' "$REPO/.github/workflows/tests.yml" && ok "CI validates the extras manifest" || fail "CI lacks the extras validate step"

echo "── 6: claude plugin validate (when the CLI is present) ──"
if command -v claude >/dev/null 2>&1; then
  if claude plugin validate "$X" >/dev/null 2>&1; then ok "claude plugin validate plugins/mega-sdd-extras"; else fail "claude plugin validate rejected the extras plugin"; fi
else
  echo "  SKIP: claude CLI not on PATH — CI runs the validate step"
fi

echo
if [ "$fails" -eq 0 ]; then echo "OK: all mega-sdd-extras contract pins green"; exit 0
else echo "FAILURES: $fails"; exit 1; fi
