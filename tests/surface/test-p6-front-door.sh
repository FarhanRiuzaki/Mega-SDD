#!/usr/bin/env bash
# test-p6-front-door.sh — P6 surface collapse (5.0.0), v5 spec P6 row +
# decisions 1/2 + sequencing #3.
#
# Pins:
#   A  the three public verbs exist; the front door WRAPS the orchestrate-flow
#      machinery (Skill dispatch) instead of forking it; auto.md's brain moved
#      (one home) — the alias points at the front door, no duplicated detector.
#   B  /mega-sdd:emit — dispatch table to the three P5 doc-pack skills + the
#      no-arg doc-control maturity listing.
#   C  all 24 deprecation aliases: file still resolves, description carries
#      DEPRECATED, body prints the Indonesian keterangan first AND still
#      dispatches its old target (skill or vetted script) — behavior unbroken.
#   D  the 4 maintenance one-timers + sync are NOT aliased.
#   E  always-on description-byte math is DOWN vs the captured 4.97.0 baseline.
#   F  MOAT SEAM (sequencing #3): the UserPromptExpansion matcher gained the
#      front-door verb — proven s6-style: matcher matches a /mega-sdd prompt
#      exactly like /mega-sdd:execute-bolts (and does NOT match the other
#      verbs), and the driven hook blocks on FAIL moat / stays silent on PASS.
#   G  CLAUDE.md carries the decision-2 amendment; both manifests 5.0.0 match.
#
# CI-safe: bash + python3 only. Run with </dev/null.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
C="$P/commands"

fails=0
ok()   { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
has()  { grep -qF -- "$2" "$1"; }

echo "── A: the three public verbs + the front door wraps, not forks ──"
for f in mega-sdd.md sync.md emit.md; do
  [ -f "$C/$f" ] && ok "public verb file: $f" || fail "public verb MISSING: $f"
done
FD="$C/mega-sdd.md"
# wraps the existing machinery: derive-state digest + orchestrate-flow Skill dispatch
has "$FD" "derive-state.sh"            && ok "front door runs the derive-state digest" || fail "front door does not run derive-state.sh"
has "$FD" "mega-sdd:orchestrate-flow"  && ok "front door dispatches the orchestrate-flow skill" || fail "front door does not dispatch orchestrate-flow"
has "$FD" "Skill tool"                 && ok "front door dispatches via the Skill tool" || fail "front door missing Skill-tool dispatch"
# the moved brain (input-shape + adoption lane) lives in the front door
has "$FD" "certify-artifact.sh"        && ok "front door carries the adoption lane (certify-artifact)" || fail "adoption lane missing from front door"
has "$FD" "adoption_demote_confirm"    && ok "front door keeps the DEMOTE C2 confirm" || fail "DEMOTE C2 lane missing"
has "$FD" "--from-prompt"              && ok "front door keeps Mode B (free-text brief)" || fail "Mode B missing"
# the moat sentence: Skill-dispatched, never Agent-offloaded
grep -qiE 'NEVER (be )?(offloaded to the Agent|dispatch.*Agent|Agent-offload)' "$FD" \
  && ok "front door states Skill-dispatch-only (never Agent-offload)" || fail "front door missing the never-Agent-offload rule"
# one home for the brain: auto.md no longer carries the input-detector, it points here
has "$C/auto.md" "commands/mega-sdd.md" && ok "auto.md alias points at the front door" || fail "auto.md does not reference the front door"
grep -qF 'Is `<input>` a path to a directory?' "$C/auto.md" \
  && fail "auto.md still carries the input-shape detector (brain duplicated, not moved)" \
  || ok "auto.md no longer duplicates the input-shape detector (brain moved)"

echo "── B: /mega-sdd:emit dispatch table + maturity listing ──"
EM="$C/emit.md"
for pair in "prd:mega-sdd:emit-prd" "fsd:mega-sdd:emit-fsd" "sit:mega-sdd:emit-sit"; do
  doc="${pair%%:*}"; skill="${pair#*:}"
  grep -qF "$skill" "$EM" && ok "emit dispatch: $doc → $skill" || fail "emit dispatch missing: $doc → $skill"
done
has "$EM" "doc-control" && has "$EM" "maturity" \
  && ok "emit no-arg lane lists docs + maturity from doc-control stamps" || fail "emit no-arg maturity listing missing"
grep -qiF "never invent" "$EM" && ok "emit listing: maturity never invented" || fail "emit listing anti-fabrication line missing"

echo "── C: the 24 deprecation aliases (DEPRECATED + old dispatch intact) ──"
# name → dispatch marker that MUST survive in the body (skill or vetted script)
ALIASES="
analyze:run-analyze.sh
analyze-parallelism:analyze-parallelism.sh
auto:mega-sdd:orchestrate-flow
bind-codebase:mega-sdd:bind-codebase
detect-drift:mega-sdd:detect-drift
diff-vault:mega-sdd:diff-vault
emit-agents-md:mega-sdd:emit-agents-md
emit-fsd:mega-sdd:emit-fsd
emit-prd:mega-sdd:emit-prd
emit-sit:mega-sdd:emit-sit
enrich-semantics:enrich-workflows-staging.sh
execute-bolts:mega-sdd:execute-bolts
extract-intelligence:mega-sdd:extract-intelligence
generate-intent:mega-sdd:generate-intent
generate-units:mega-sdd:generate-units
graph:mega-sdd:graph
lint-units:validate-unit-spec.sh
list-modules:list-modules.sh
migrate-rules:migrate-v1-rules.sh
orchestrate-flow:mega-sdd:orchestrate-flow
replay:replay.sh
resolve-oq:mega-sdd:resolve-oq
scan-codebase:mega-sdd:scan-codebase
validate-handoff:validate-handoff-binding-units
"
n_alias=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  name="${row%%:*}"; marker="${row#*:}"
  f="$C/$name.md"
  if [ ! -f "$f" ]; then fail "alias file MISSING (typed /mega-sdd:$name broken): $name.md"; continue; fi
  n_alias=$((n_alias + 1))
  grep -q '^description:.*DEPRECATED' "$f" \
    && ok "alias $name: DEPRECATED description" || fail "alias $name: description not DEPRECATED"
  has "$f" "dilebur ke" \
    && ok "alias $name: Indonesian keterangan notice" || fail "alias $name: keterangan notice missing"
  has "$f" "$marker" \
    && ok "alias $name: still dispatches $marker" || fail "alias $name: old dispatch LOST ($marker) — behavior broken"
done <<EOF
$ALIASES
EOF
[ "$n_alias" -eq 24 ] && ok "exactly 24 aliases enumerated" || fail "alias count wrong: $n_alias (expected 24)"

echo "── D: maintenance one-timers + sync stay first-class ──"
for f in memory install-deps migrate-paths update-plugin sync; do
  if grep -q '^description:.*DEPRECATED' "$C/$f.md"; then
    fail "$f.md wrongly aliased (must stay first-class)"
  else
    ok "$f.md not aliased"
  fi
done

echo "── E: description-byte math DOWN vs 4.97.0 baseline ──"
# Baseline captured at v4.97.0 (pre-P6): commands 8970 + skills 10419 = 19389.
BASELINE=19389
TOTALS=$(python3 - "$P" <<'PYEOF'
import glob, re, sys
p = sys.argv[1]
def desc_bytes(path):
    txt = open(path, encoding='utf-8').read()
    m = re.match(r'^---\n(.*?)\n---\n', txt, re.S)
    if not m: return 0
    for ln in m.group(1).split('\n'):
        if ln.startswith('description:'):
            v = ln[len('description:'):].strip()
            if len(v) >= 2 and v[0] == '"' and v[-1] == '"': v = v[1:-1]
            return len(v.encode('utf-8'))
    return 0
cmd = sum(desc_bytes(f) for f in glob.glob(p + '/commands/*.md'))
skl = sum(desc_bytes(f) for f in glob.glob(p + '/skills/*/SKILL.md'))
print(f"{cmd} {skl} {cmd + skl}")
PYEOF
)
CMD_B=$(echo "$TOTALS" | awk '{print $1}')
SKL_B=$(echo "$TOTALS" | awk '{print $2}')
ALL_B=$(echo "$TOTALS" | awk '{print $3}')
echo "  commands=$CMD_B skills=$SKL_B total=$ALL_B baseline=$BASELINE"
[ "$ALL_B" -lt "$BASELINE" ] \
  && ok "always-on description bytes DOWN ($ALL_B < $BASELINE)" \
  || fail "description bytes NOT down ($ALL_B >= $BASELINE)"

echo "── F: UserPromptExpansion matcher — front-door verb gated like execute-bolts ──"
HJ="$P/hooks/hooks.json"
UPE="$P/hooks/user-prompt-expansion"
RX=$(python3 - "$HJ" <<'PYEOF'
import json, sys
cfg = json.load(open(sys.argv[1]))
print(cfg["hooks"]["UserPromptExpansion"][0]["matcher"])
PYEOF
)
[ -n "$RX" ] && ok "matcher extracted: $RX" || fail "UserPromptExpansion matcher missing"
m()  { printf '%s' "$1" | grep -qE "$RX"; }
# same gate behavior as the execute-bolts literals
m "/mega-sdd:execute-bolts" && ok "matcher: /mega-sdd:execute-bolts matches (unchanged)" || fail "matcher lost execute-bolts"
m "execute-bolts"           && ok "matcher: bare execute-bolts matches (unchanged)" || fail "matcher lost bare execute-bolts"
m "/mega-sdd"               && ok "matcher: /mega-sdd (front door, no args) matches" || fail "matcher does NOT cover /mega-sdd"
m "/mega-sdd --resume"      && ok "matcher: /mega-sdd with args matches" || fail "matcher does NOT cover /mega-sdd <args>"
m "mega-sdd"                && ok "matcher: bare command name mega-sdd matches" || fail "matcher does NOT cover bare mega-sdd"
# precision: the other verbs/aliases must stay expandable under a FAIL moat
m "/mega-sdd:sync"    && fail "matcher over-broad: /mega-sdd:sync matched (sync must stay usable on FAIL)" || ok "matcher precise: /mega-sdd:sync NOT matched"
m "/mega-sdd:analyze" && fail "matcher over-broad: /mega-sdd:analyze matched (diagnosis must stay usable)" || ok "matcher precise: /mega-sdd:analyze NOT matched"
# s6-style behavioral drive: the hook body blocks FAIL / stays silent on PASS —
# identical for the front-door path (the matcher, proven above, selects it).
bash -n "$UPE" && ok "user-prompt-expansion: bash -n clean" || fail "user-prompt-expansion: syntax error"
T=$(mktemp -d); mkdir -p "$T/.mega-sdd"
printf '{"status": "FAIL"}' > "$T/.mega-sdd/.validation-blockers.json"
O1=$(printf '{"cwd":"%s","prompt":"/mega-sdd"}' "$T" | bash "$UPE" 2>/dev/null)
printf '{"status": "PASS"}' > "$T/.mega-sdd/.validation-blockers.json"
O2=$(printf '{"cwd":"%s","prompt":"/mega-sdd"}' "$T" | bash "$UPE" 2>/dev/null)
rm -rf "$T"
case "$O1" in *'"decision": "block"'*) ok "driven hook: FAIL moat → block (front-door prompt)";; *) fail "driven hook: expected block, got ${O1:0:60}";; esac
[ -z "$O2" ] && ok "driven hook: PASS moat → silent" || fail "driven hook: expected silent on PASS"
# the front door must say every gated phase stays Skill-dispatched (moat text)
grep -qiF "Skill" "$FD" && grep -qiF "Agent" "$FD" \
  && ok "front door text covers Skill-vs-Agent dispatch" || fail "front door missing dispatch doctrine"

echo "── G: contract amendment + manifests ──"
grep -qiF "telemetry review" "$P/CLAUDE.md" \
  && ok "CLAUDE.md carries the decision-2 alias/removal amendment" || fail "CLAUDE.md amendment missing"
V1=$(grep -oE '"version": "[^"]+"' "$P/.claude-plugin/plugin.json" | head -1)
V2=$(grep -oE '"version": "[^"]+"' "$ROOT/.claude-plugin/marketplace.json" | head -1)
# The surface collapse landed in the 5.x MAJOR; assert major==5 (not a frozen
# minor — that is the version-archaeology anti-pattern) + the two manifests agree.
echo "$V1" | grep -qE '"version": "5\.[0-9]+\.[0-9]+"' && ok "plugin.json is on the 5.x surface major ($V1)" || fail "plugin.json not 5.x: $V1"
[ "$V1" = "$V2" ] && ok "marketplace.json matches plugin.json" || fail "manifest mismatch: $V1 vs $V2"

echo
if [ "$fails" -eq 0 ]; then
  echo "test-p6-front-door: ALL PASS"
  exit 0
else
  echo "test-p6-front-door: $fails FAILURE(S)"
  exit 1
fi
