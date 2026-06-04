#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the staged-input semantic-depth walking skeleton (v3.71.0+).
#
# WHAT THIS PROVES (Fork-A — deterministic, script-provable):
#   1. validate-kb-flows.sh raises the ADVISORY kb_flow_staging_missing on a workflow that
#      looks multi-step but has no `stages:` block — WITHOUT flipping status (Iter-78.1 #1).
#      The staged KB (kb-good) raises NO advisory.
#   2. validate-vault-flow-staging.sh FAILs (vault_flow_staging_drop) when a vault flow cites a
#      KB workflow (`_kb_source`) that HAS a stages: block but the vault flow DROPPED it; PASSes
#      when the flow preserved it. Deterministic back-reference match — no fuzzy title matching.
#   3. enrich-workflows-staging.sh PROPOSES a stages: block (with per-stage field allocation)
#      from the cited legacy wizard, and --apply patches the KB so the advisory then clears.
#   4. PreToolUse Branch 14 actually FIRES: it blocks mega-sdd:execute-bolts (continue:false) on
#      the vault-bad drop and falls through cleanly on vault-good. (The advisor's non-negotiable
#      gate — validators verified in isolation are NOT proof the hook fires. Prose/wiring failed
#      4x before; this asserts the wire.)
#
# WHAT THIS DOES *NOT* PROVE (Fork-B — LLM skill-body behavior, real-run-only):
#   - extract-intelligence actually AUTHORING the `## 3a` stages: block from a real legacy codebase.
#   - generate-intent actually PRESERVING stages: verbatim into 04-flows during a real vault gen.
#   These are skill-body guidance (SKILL.md prose), not deterministic scripts. Green checks below
#   do NOT imply they are verified — they are verified only by a real extract/intent run.
#
# Run: bash tests/fixtures/iter77-semantic-depth/verify.sh
# Exit 0 = all Fork-A assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../.." && pwd)"
SCRIPTS="${PLUGIN_ROOT}/plugins/mega-sdd/scripts"
HOOK="${PLUGIN_ROOT}/plugins/mega-sdd/hooks/pre-tool-use"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ FAIL: %s\n' "$*"; FAILED=1; }

for f in "$SCRIPTS/validate-kb-flows.sh" "$SCRIPTS/validate-vault-flow-staging.sh" \
         "$SCRIPTS/enrich-workflows-staging.sh" "$HOOK"; do
  [ -f "$f" ] || { fail "missing: $f"; exit 1; }
done

# Pristine copy: validators/hook/enrich write state + telemetry; keep the committed fixture clean.
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t iter77)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$HERE"/. "$WORK"/

jget() { python3 -c "
import json,sys
try:
    d=json.load(open('$1'));print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

# ── 1. KB staging advisory (Fork-A) ───────────────────────────────────────────
note "=== 1. validate-kb-flows advisory (kb_flow_staging_missing) — Fork-A ==="
KB_BAD="$WORK/kb-bad/.mega-sdd/knowledge-base/20-workflows/import-request.md"
bash "$SCRIPTS/validate-kb-flows.sh" --cwd="$WORK/kb-bad" --file-path="$KB_BAD" --quiet >/dev/null
BAD_KB_STATE="$WORK/kb-bad/.mega-sdd/.kb-flows-state.json"
BAD_STATUS=$(jget "$BAD_KB_STATE" "d.get('status')")
BAD_ADV=$(jget "$BAD_KB_STATE" "','.join(a['halt_type'] for a in d.get('advisories',[]))")
note "  kb-bad: status=$BAD_STATUS advisories=[$BAD_ADV]"
[ "$BAD_STATUS" = "PASS" ] && ok "advisory does NOT flip status (Iter-78.1 #1)" || fail "kb-bad status expected PASS (advisory must not flip), got '$BAD_STATUS'"
echo "$BAD_ADV" | grep -q "kb_flow_staging_missing" && ok "kb_flow_staging_missing raised on multi-step KB w/o stages" || fail "kb-bad missing the kb_flow_staging_missing advisory"

KB_GOOD="$WORK/kb-good/.mega-sdd/knowledge-base/20-workflows/import-request.md"
bash "$SCRIPTS/validate-kb-flows.sh" --cwd="$WORK/kb-good" --file-path="$KB_GOOD" --quiet >/dev/null
GOOD_KB_STATE="$WORK/kb-good/.mega-sdd/.kb-flows-state.json"
GOOD_ADV=$(jget "$GOOD_KB_STATE" "len(d.get('advisories',[]))")
note "  kb-good: advisories=$GOOD_ADV"
[ "$GOOD_ADV" = "0" ] && ok "staged KB raises NO advisory" || fail "kb-good should have 0 advisories, got '$GOOD_ADV'"

# ── 2. Vault staging-drop blocking validator (Fork-A) ──────────────────────────
note ""
note "=== 2. validate-vault-flow-staging (vault_flow_staging_drop) — Fork-A ==="
bash "$SCRIPTS/validate-vault-flow-staging.sh" --cwd="$WORK/vault-bad" --quiet >/dev/null; VB_EXIT=$?
VB_STATE="$WORK/vault-bad/.mega-sdd/.vault-flow-staging-state.json"
VB_STATUS=$(jget "$VB_STATE" "d.get('status')")
VB_CNT=$(jget "$VB_STATE" "d['summary']['drop_count']")
VB_FLOW=$(jget "$VB_STATE" "d['issues'][0]['flow_id'] if d['issues'] else None")
note "  vault-bad: status=$VB_STATUS exit=$VB_EXIT drops=$VB_CNT flow=$VB_FLOW"
[ "$VB_STATUS" = "FAIL" ] && ok "FAIL on dropped staging (KB had stages, vault flow dropped them)" || fail "vault-bad expected FAIL, got '$VB_STATUS'"
[ "$VB_EXIT" = "1" ] && ok "exit 1 (blocking)" || fail "vault-bad expected exit 1, got '$VB_EXIT'"
[ "$VB_CNT" = "1" ] && ok "exactly 1 drop detected" || fail "vault-bad expected 1 drop, got '$VB_CNT'"
[ "$VB_FLOW" = "F-U-001" ] && ok "drop attributed to F-U-001" || fail "vault-bad drop flow expected F-U-001, got '$VB_FLOW'"

bash "$SCRIPTS/validate-vault-flow-staging.sh" --cwd="$WORK/vault-good" --quiet >/dev/null; VG_EXIT=$?
VG_STATE="$WORK/vault-good/.mega-sdd/.vault-flow-staging-state.json"
VG_STATUS=$(jget "$VG_STATE" "d.get('status')")
VG_CNT=$(jget "$VG_STATE" "d['summary']['drop_count']")
note "  vault-good: status=$VG_STATUS exit=$VG_EXIT drops=$VG_CNT"
[ "$VG_STATUS" = "PASS" ] && ok "PASS when staging preserved" || fail "vault-good expected PASS, got '$VG_STATUS'"
[ "$VG_EXIT" = "0" ] && ok "exit 0" || fail "vault-good expected exit 0, got '$VG_EXIT'"
[ "$VG_CNT" = "0" ] && ok "0 drops" || fail "vault-good expected 0 drops, got '$VG_CNT'"

# 2b — the DOMINANT flatten case (no stages AND no _kb_source) → non-blocking advisory.
# The blocking arm needs _kb_source; this advisory covers wholesale-flatten + PRD-only.
mkdir -p "$WORK/vault-flatten/.mega-sdd/vaults/demo"
cat > "$WORK/vault-flatten/.mega-sdd/vaults/demo/04-flows.md" <<'FEOF'
# 04 — Flows
### F-U-001: Import request (maker-checker)
**Steps**:
1. Maker submits lc_number, amount, beneficiary
2. Checker reviews then approves or rejects
FEOF
bash "$SCRIPTS/validate-vault-flow-staging.sh" --cwd="$WORK/vault-flatten" --quiet >/dev/null; VF_EXIT=$?
VF_STATE="$WORK/vault-flatten/.mega-sdd/.vault-flow-staging-state.json"
VF_STATUS=$(jget "$VF_STATE" "d.get('status')")
VF_ADV=$(jget "$VF_STATE" "','.join(a['halt_type'] for a in d.get('advisories',[]))")
note "  vault-flatten (workflow signal, no stages, no _kb_source): status=$VF_STATUS exit=$VF_EXIT advisories=[$VF_ADV]"
[ "$VF_STATUS" = "PASS" ] && ok "advisory does NOT block (dominant flatten case is WARN, not FAIL)" || fail "flatten advisory must not flip status, got '$VF_STATUS'"
[ "$VF_EXIT" = "0" ] && ok "exit 0 (advisory never blocks bolts)" || fail "flatten advisory expected exit 0, got '$VF_EXIT'"
echo "$VF_ADV" | grep -q "vault_flow_staging_missing" && ok "vault_flow_staging_missing raised (covers flatten-without-backref + PRD-only)" || fail "flatten case missing the advisory"

# ── 3. Enrichment helper proposes + applies (Fork-A) ───────────────────────────
note ""
note "=== 3. enrich-workflows-staging propose + apply (legacy-root AUTO-DISCOVERED) — Fork-A ==="
# Place the legacy under the enrich project root so --legacy-root can be AUTO-DISCOVERED
# (probe: <proj>/legacy). Proves /mega-sdd:auto can call enrich without hand-feeding the path.
mkdir -p "$WORK/enrich/legacy"; cp "$WORK/legacy/import_request.php" "$WORK/enrich/legacy/"
bash "$SCRIPTS/enrich-workflows-staging.sh" --vault="$WORK/enrich/.mega-sdd/vaults/demo" \
     --semantic=staged-input --quiet >/dev/null
DISC=$(jget "$WORK/enrich/.mega-sdd/vaults/demo/.x" "0" 2>/dev/null)
# the script prints legacy_root_auto_discovered; re-run capturing stdout to assert it
AUTO_JSON=$(bash "$SCRIPTS/enrich-workflows-staging.sh" --vault="$WORK/enrich/.mega-sdd/vaults/demo" --semantic=staged-input 2>/dev/null)
echo "$AUTO_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print('  auto-discovered legacy_root:', d.get('legacy_root_auto_discovered'), '->', d.get('legacy_root'))" 2>/dev/null
echo "$AUTO_JSON" | python3 -c "import json,sys; sys.exit(0 if json.load(sys.stdin).get('legacy_root_auto_discovered') else 1)" 2>/dev/null && ok "legacy-root AUTO-DISCOVERED (no --legacy-root needed → /mega-sdd:auto-friendly)" || fail "legacy-root not auto-discovered"
PROP="$WORK/enrich/.mega-sdd/vaults/demo/ENRICHMENT-PROPOSALS.md"
[ -f "$PROP" ] && ok "ENRICHMENT-PROPOSALS.md written" || fail "proposals file not written"
if [ -f "$PROP" ]; then
  grep -q "stages:" "$PROP" && ok "stages: block proposed" || fail "no stages: block in proposals"
  grep -q "lc_number" "$PROP" && ok "S1 maker fields allocated (lc_number/amount/beneficiary)" || fail "S1 fields not allocated"
  grep -q "approval_note" "$PROP" && ok "S2 checker fields allocated (approval_note/decision)" || fail "S2 fields not allocated"
  grep -q '"checked_at"' "$PROP" && fail "computed field checked_at wrongly allocated (should be excluded)" || ok "computed checked_at correctly excluded"
fi
# --apply patches the KB; advisory then clears
bash "$SCRIPTS/enrich-workflows-staging.sh" --vault="$WORK/enrich/.mega-sdd/vaults/demo" \
     --legacy-root="$WORK/legacy" --semantic=staged-input --apply --quiet >/dev/null
ENR_KB="$WORK/enrich/.mega-sdd/knowledge-base/20-workflows/import-request.md"
grep -q "stage_id:" "$ENR_KB" && ok "--apply patched the KB workflow in-place" || fail "--apply did not patch KB"
bash "$SCRIPTS/validate-kb-flows.sh" --cwd="$WORK/enrich" --file-path="$ENR_KB" --quiet >/dev/null
ENR_ADV=$(jget "$WORK/enrich/.mega-sdd/.kb-flows-state.json" "len(d.get('advisories',[]))")
[ "$ENR_ADV" = "0" ] && ok "advisory clears after --apply (loop closed)" || fail "advisory should clear post-apply, got '$ENR_ADV'"

# ── 4. PreToolUse Branch 14 actually FIRES (Fork-A — the non-negotiable gate) ──
note ""
note "=== 4. PreToolUse Branch 14 hook-fire — Fork-A (the 4x-failure-prevention gate) ==="
# state files written above; pipe a real execute-bolts Skill payload through the hook.
mkpayload() { python3 -c "import json;print(json.dumps({'cwd':'$1','tool_name':'Skill','tool_input':{'skill':'mega-sdd:execute-bolts'}}))"; }
OUT_BAD=$(mkpayload "$WORK/vault-bad" | bash "$HOOK" 2>/dev/null)
echo "$OUT_BAD" | grep -q "vault-flow-staging validator found" \
  && ok "Branch 14 FIRES on vault-bad (blocks execute-bolts with staging reason)" \
  || { fail "Branch 14 did NOT fire on vault-bad"; note "    got: $OUT_BAD"; }
BLOCKED=$(echo "$OUT_BAD" | python3 -c "import json,sys;print(json.load(sys.stdin).get('continue'))" 2>/dev/null)
[ "$BLOCKED" = "False" ] && ok "emits continue:false (block)" || fail "expected continue:false, got '$BLOCKED'"

OUT_GOOD=$(mkpayload "$WORK/vault-good" | bash "$HOOK" 2>/dev/null)
[ -z "$OUT_GOOD" ] && ok "falls through on vault-good (no block when staging preserved)" \
  || { fail "vault-good unexpectedly blocked"; note "    got: $OUT_GOOD"; }

note ""
note "── Fork-B (NOT asserted here — real-run-only): extract-intelligence authoring §3a stages:,"
note "   generate-intent preserving stages: verbatim. SKILL.md guidance; verified by a real run."
note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL Fork-A assertions passed."
else
  note "SOME assertions FAILED (see ✗ above)."
fi
exit $FAILED
