#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the extract-intelligence deepening (v3.72.0+).
#
# WHAT THIS PROVES (Fork-A — deterministic, script-provable):
#   1. The P1–P4 deep disciplines are wired into the SUBAGENT'S OWN SYSTEM PROMPT
#      (agents/domain-extractor.md §Deep disciplines — moved there from the typed
#      wave-dispatch-templates.md block by tranche 5d; the agent body loads on every
#      dispatch BY CONSTRUCTION) + the REPORT BACK provenance self-check fields — i.e.
#      they reach every extraction subagent ("otomatis"), not just the parent SKILL.md
#      the subagents never read.
#   2. validate-extraction-scorecard.sh returns correct verdicts: SKIP (absent — back-compat),
#      PASS (consistent), FAIL (PARTIAL/MISSING principle with ZERO [OPEN] markers — the
#      hidden-gap silent-drift case), and PASS+advisory once the gap is honestly surfaced
#      as an [OPEN] marker. (Validators verified in isolation are not proof of real reasoning
#      — see Fork-B below — but the verdict logic IS the keystone B1 gate, and it is real.)
#   3. The §3a stages: schema documents the enriched OPTIONAL fields (per-field
#      mutability/visibility + new/hidden/promoted deltas + dynamic_disclosures) AND preserves
#      bare-string input_fields (back-compat — no consumer breaks; semantic-depth invariant #7).
#
# WHAT THIS DOES *NOT* PROVE (Fork-B — LLM skill-body behavior, real-run-only):
#   - extract-intelligence subagents ACTUALLY performing the P1–P4 deeper reasoning on real
#     legacy code (locating readers for writers, tracing clone-inheritance, enumerating all
#     rule sites, classifying by structure).
#   - Wave 5 ACTUALLY emitting an honest scorecard (not up-ranking a principle to hide a gap).
#   These are dispatch-prompt/SKILL.md guidance; green checks below do NOT imply they are
#   verified — they are verified only by a real extract run.
#
# Run: bash tests/fixtures/iter80-extract-deepening/verify.sh
# Exit 0 = all Fork-A assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../.." && pwd)"
SCRIPTS="${PLUGIN_ROOT}/plugins/mega-sdd/scripts"
EI="${PLUGIN_ROOT}/plugins/mega-sdd/skills/extract-intelligence"
DISPATCH="${EI}/references/wave-dispatch-templates.md"
SCHEMA="${EI}/references/knowledge-base-schema.md"
SCORECARD_VALIDATOR="${SCRIPTS}/validate-extraction-scorecard.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

for f in "$SCORECARD_VALIDATOR" "$DISPATCH" "$SCHEMA"; do
  [ -f "$f" ] || { fail "missing: $f"; exit 1; }
done

# Pristine copy: the validator writes state into <cwd>/.mega-sdd/ — keep the committed fixture clean.
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t iter80)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$HERE"/. "$WORK"/

jget() { python3 -c "
import json,sys
try:
    d=json.load(open('$1'));print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

# ── 1. P1–P4 wired into the SUBAGENT SYSTEM PROMPT (Fork-A: reaches subagents by construction) ──
note "=== 1. P1–P4 deep disciplines wired into the domain-extractor agent body — Fork-A ==="
AGENT_BODY="${PLUGIN_ROOT}/plugins/mega-sdd/agents/domain-extractor.md"
[ -f "$AGENT_BODY" ] || { fail "missing: $AGENT_BODY"; exit 1; }
grep -q "Deep disciplines" "$AGENT_BODY" && ok "Deep disciplines block present in the agent body (system prompt)" || fail "no Deep disciplines block in agents/domain-extractor.md"
grep -q "State & data provenance" "$AGENT_BODY" && ok "P1 (state writer<->reader provenance + clone inheritance) present" || fail "P1 missing from the agent body"
grep -q "Enumerate ALL sites" "$AGENT_BODY" && ok "P2 (enumerate all rule/flow sites + entry-point dispatchers) present" || fail "P2 missing from the agent body"
grep -q "Behaviour-as-EXECUTED" "$AGENT_BODY" && ok "P3 (behaviour-as-executed / debug-as-feature) present" || fail "P3 missing from the agent body"
grep -q "Classify files by structure" "$AGENT_BODY" && ok "P4 (structural file classification) present" || fail "P4 missing from the agent body"
grep -q "provenance_anomalies" "$AGENT_BODY" && ok "REPORT BACK self-check field provenance_anomalies present in the agent body" || fail "REPORT BACK provenance self-check missing"
grep -q "provenance_read_side_thin" "$DISPATCH" && ok "Wave-3 non-blocking advisory provenance_read_side_thin present (controller-side, stays in the templates)" || fail "Wave-3 provenance advisory missing"

# ── 2. Scorecard validator verdicts (Fork-A: the keystone B1 gate is real) ─────────────
note ""
note "=== 2. validate-extraction-scorecard.sh verdicts — Fork-A ==="

# 2a — PASS on the consistent kb-good
bash "$SCORECARD_VALIDATOR" --cwd="$WORK/kb-good" --quiet >/dev/null; GOOD_EXIT=$?
GOOD_STATE="$WORK/kb-good/.mega-sdd/.extraction-scorecard-state.json"
GOOD_STATUS=$(jget "$GOOD_STATE" "d.get('status')")
note "  kb-good: status=$GOOD_STATUS exit=$GOOD_EXIT"
[ "$GOOD_STATUS" = "PASS" ] && ok "PASS on a fully-COVERED, consistent scorecard" || fail "kb-good expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] && ok "exit 0" || fail "kb-good expected exit 0, got '$GOOD_EXIT'"

# 2b — FAIL on kb-bad (P1 PARTIAL but ZERO [OPEN] markers in KB → hidden gap)
bash "$SCORECARD_VALIDATOR" --cwd="$WORK/kb-bad" --quiet >/dev/null; BAD_EXIT=$?
BAD_STATE="$WORK/kb-bad/.mega-sdd/.extraction-scorecard-state.json"
BAD_STATUS=$(jget "$BAD_STATE" "d.get('status')")
BAD_ISSUES=$(jget "$BAD_STATE" "','.join(i['type'] for i in d.get('issues',[]))")
note "  kb-bad: status=$BAD_STATUS exit=$BAD_EXIT issues=[$BAD_ISSUES]"
[ "$BAD_STATUS" = "FAIL" ] && ok "FAIL on hidden gap (PARTIAL principle, no [OPEN] markers)" || fail "kb-bad expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] && ok "exit 1 (blocking verdict)" || fail "kb-bad expected exit 1, got '$BAD_EXIT'"
echo "$BAD_ISSUES" | grep -q "hidden_gap" && ok "issue type = hidden_gap" || fail "kb-bad expected hidden_gap issue, got [$BAD_ISSUES]"

# 2c — once the gap is surfaced as an [OPEN] marker → PASS + advisory (honest PARTIAL)
cp -R "$WORK/kb-bad" "$WORK/kb-open"
printf '\n> [OPEN] update_status arrives via clone from issuance — confirm reader. (inherited / cross-domain seam)\n' \
  >> "$WORK/kb-open/.mega-sdd/knowledge-base/10-domains/10-lc-amendments.md"
bash "$SCORECARD_VALIDATOR" --cwd="$WORK/kb-open" --quiet >/dev/null; OPEN_EXIT=$?
OPEN_STATE="$WORK/kb-open/.mega-sdd/.extraction-scorecard-state.json"
OPEN_STATUS=$(jget "$OPEN_STATE" "d.get('status')")
OPEN_MARKERS=$(jget "$OPEN_STATE" "d.get('open_marker_count')")
note "  kb-open: status=$OPEN_STATUS exit=$OPEN_EXIT open_markers=$OPEN_MARKERS"
[ "$OPEN_STATUS" = "PASS" ] && ok "PASS once the gap is honestly surfaced as [OPEN] (PARTIAL+[OPEN] is the passing state)" || fail "kb-open expected PASS, got '$OPEN_STATUS'"
[ "$OPEN_EXIT" = "0" ] && ok "exit 0" || fail "kb-open expected exit 0, got '$OPEN_EXIT'"

# 2d — SKIP when no scorecard (back-compat: pre-v3.72.0 KB never fails)
mkdir -p "$WORK/kb-none/.mega-sdd/knowledge-base/10-domains"
printf '# domain\nno scorecard here\n' > "$WORK/kb-none/.mega-sdd/knowledge-base/10-domains/d.md"
bash "$SCORECARD_VALIDATOR" --cwd="$WORK/kb-none" --quiet >/dev/null; NONE_EXIT=$?
NONE_STATUS=$(jget "$WORK/kb-none/.mega-sdd/.extraction-scorecard-state.json" "d.get('status')")
note "  kb-none: status=$NONE_STATUS exit=$NONE_EXIT"
[ "$NONE_STATUS" = "SKIP" ] && ok "SKIP on absent scorecard (back-compat)" || fail "kb-none expected SKIP, got '$NONE_STATUS'"
[ "$NONE_EXIT" = "0" ] && ok "exit 0 (absence never blocks)" || fail "kb-none expected exit 0, got '$NONE_EXIT'"

# ── 3. §3a schema enrichment + bare-string back-compat (Fork-A) ────────────────────────
note ""
note "=== 3. §3a stages: schema enrichment — Fork-A ==="
grep -q "dual-key-re-entry" "$SCHEMA" && ok "per-field mutability enum (incl. dual-key-re-entry) documented" || fail "§3a mutability enum missing"
grep -q "new_fields_vs_prior" "$SCHEMA" && ok "delta field new_fields_vs_prior documented" || fail "new_fields_vs_prior missing"
grep -q "hidden_fields_vs_prior" "$SCHEMA" && ok "delta field hidden_fields_vs_prior documented" || fail "hidden_fields_vs_prior missing"
grep -q "promoted_to_mutable_vs_prior" "$SCHEMA" && ok "delta field promoted_to_mutable_vs_prior documented" || fail "promoted_to_mutable_vs_prior missing"
grep -q "dynamic_disclosures" "$SCHEMA" && ok "within-stage dynamic_disclosures documented" || fail "dynamic_disclosures missing"
grep -q "BARE-STRING form" "$SCHEMA" && ok "bare-string input_fields back-compat preserved (no consumer breaks)" || fail "bare-string back-compat note missing"
grep -q "NOT a parallel" "$SCHEMA" && ok "enrichment is on the SAME stages: block (reuse, not a parallel artifact)" || fail "reuse-compliance note missing"

note ""
note "── Fork-B (NOT asserted here — real-run-only): extract subagents performing the P1–P4"
note "   reasoning on real legacy code; Wave 5 emitting an honest (non-up-ranked) scorecard."
note "   Dispatch-prompt/SKILL.md guidance; verified only by a real extract run."
note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL Fork-A assertions passed."
else
  note "SOME assertions FAILED (see FAIL above)."
fi
exit $FAILED
