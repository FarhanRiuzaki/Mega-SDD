#!/usr/bin/env bash
# Artifact-delivery contract pins — every pipeline output has a consumer (or is
# explicitly terminal), and handoff seams are enforced. From the 2026-06-10
# producer→consumer matrix audit.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# D1 — KB orphans wired into generate-intent --kb
for k in "suggested-system-flow.md" "module-dependency-graph.md" "50-integrations/"; do
  grep -q -- "$k" "$P/skills/generate-intent/references/kb-submode.md" \
    && pass "D1: kb-submode consumes $k" \
    || fail "D1: kb-submode missing consumption row for $k"
done
grep -q "Never silently dropped" "$P/skills/generate-intent/references/kb-submode.md" \
  && pass "D1: integrations never-silently-dropped rail" \
  || fail "D1: never-silently-dropped rail missing"

# D2 — module graph seeds generate-units module derivation
grep -q "kb_module_graph" "$P/skills/generate-units/references/decomposition-rails.md" \
  && pass "D2: generate-units reads kb_module_graph seed" \
  || fail "D2: kb_module_graph seed missing from decomposition-rails"

# D3 — codebase-map §6 delivered to bolts when starterkit-context absent
grep -q "Codebase patterns:" "$P/skills/execute-bolts/references/context-enrichment.md" \
  && grep -q "never write-only" "$P/skills/scan-codebase/references/codebase-map-schema.md" \
  && pass "D3: map §6 fallback wired + schema consumer note" \
  || fail "D3: map §6 fallback / consumer note missing"

# D4 — missing_sources surfaced at chain end
grep -q "missing_sources" "$P/skills/orchestrate-flow/references/chain-execution.md" \
  && pass "D4: FSD missing_sources surfaced in final summary" \
  || fail "D4: missing_sources consumer missing from chain-execution"

# D5 — next_action.confidence actually consumed (auto-continue demotion)
grep -q "next_action.confidence is present AND < confidence_minimum" "$P/skills/orchestrate-flow/references/handoff-consumption.md" \
  && pass "D5: confidence floor demotes auto-continue" \
  || fail "D5: confidence consumer missing from handoff-consumption"

# D6 — drift scope-hint logging
grep -q "Scope hint received" "$P/skills/detect-drift/SKILL.md" \
  && pass "D6: detect-drift logs scope hint" \
  || fail "D6: scope-hint log line missing"

# D7 — mode-dependent artifact documented
grep -q "DRIFT-ACTIONS.md\` is the RETIRED" "$P/skills/orchestrate-flow/references/routing-rules.md" \
  && pass "D7: DRIFT-ACTIONS documented as retired in every mode (PENDING-SYNC is the only queue)" \
  || fail "D7: DRIFT-ACTIONS retirement note missing"

# D8 — validator scope-args seam (FUNCTIONAL — runs the real validator 3 ways)
T=$(mktemp -d)
mkdir -p "$T/vault/bolts/U-001"
cat > "$T/h1.txt" <<EOF
\`\`\`yaml
handoff:
  emitted_by: execute-bolts
  emitted_at: 2026-06-10T12:00:00Z
  status: completed
  artifacts:
    - $T/vault/bolts/U-001
  scope:
    id: BE
    name: Backend
  next_action:
    suggested_skill: mega-sdd:detect-drift
    suggested_args: []
    rationale: "periodic drift check"
  blockers: []
  metrics:
    items_processed: 3
    items_blocked: 0
\`\`\`
EOF
sed 's/suggested_args: \[\]/suggested_args: ["--scope=BE"]/' "$T/h1.txt" > "$T/h2.txt"
sed '/^  scope:/,/^    name: Backend/d' "$T/h1.txt" > "$T/h3.txt"
v() { bash "$P/scripts/validate-handoff-yaml.sh" --cwd="$T" --response-file="$1" </dev/null 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['status'], d.get('halt_type'))"; }
r1=$(v "$T/h1.txt"); r2=$(v "$T/h2.txt"); r3=$(v "$T/h3.txt")
[ "$r1" = "FAIL scope_args_missing" ] && pass "D8a: scoped handoff without --scope → FAIL scope_args_missing" || fail "D8a: expected FAIL scope_args_missing, got: $r1"
[ "$r2" = "PASS None" ] && pass "D8b: scoped handoff WITH --scope → PASS" || fail "D8b: expected PASS, got: $r2"
[ "$r3" = "PASS None" ] && pass "D8c: unscoped handoff → PASS (no false positive)" || fail "D8c: expected PASS, got: $r3"
# D8d — BLOCK-style suggested_args (the 2026-06-11 parser 2-level fix): violation must still fire
sed 's/suggested_args: \[\]/suggested_args:\n      - "--verbose"/' "$T/h1.txt" > "$T/h4.txt"
r4=$(v "$T/h4.txt")
[ "$r4" = "FAIL scope_args_missing" ] && pass "D8d: block-style args w/o --scope → FAIL (parser keeps 2-level nesting)" || fail "D8d: expected FAIL scope_args_missing, got: $r4"
rm -rf "$T"

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
