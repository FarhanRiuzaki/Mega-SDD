#!/usr/bin/env bash
# test-analyze-freshness.sh — S1/S2 proof obligations for the semantic-scoped
# validation tranche (spec 2026-08-03-semantic-scoped-validation.md).
#
# Proves, against a live fixture project:
#   1. Reuse is REAL: an unchanged per-file family is not re-spawned (state-slot
#      mtime frozen) and the report/state disclose the reused count honestly.
#   2. A changed file re-runs; its verdict updates.
#   3. The env-coupled family (vault_oqs) re-runs when the CODE tree changes,
#      even though no vault doc changed (code_fingerprint invalidation) — while
#      the pure KB families keep reusing on the same run.
#   4. unit_spec runs as ONE project-wide invocation and is NEVER reused
#      (state mtime advances every FULL run); unit_baseline is recorded.
#   5. Masking mutant: a family whose FAILing file is validated BEFORE a PASSing
#      one reports FAIL at the boundary (severity-max), not the slot's PASS.
#   6. plugin_version mismatch invalidates the whole ledger.
#   7. --fresh forces a full re-run.
#   8. --aggregate-only neither creates nor mutates the ledger.
#   9. Ledger families ⊆ the six reusable families (unit_spec/bolt_artifacts/
#      kb_citations never appear).
#  10. Doc pins: lint-units --changed-only contract, chain auto-lint row,
#      analyze --fresh surfaces.
#
# CI-safe: bash + python3 + git only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/mega-sdd"
ANALYZE="$PLUGIN_ROOT/scripts/run-analyze.sh"

[ -f "$ANALYZE" ] || { echo "FAIL: run-analyze.sh not found"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

_state() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d[sys.argv[2]])" "$ROOT/.mega-sdd/.analyze-state.json" "$1"; }
_boundary() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['boundaries'][sys.argv[2]]['status'])" "$ROOT/.mega-sdd/.analyze-state.json" "$1"; }
_mtime() { python3 -c "import os,sys;print(int(os.stat(sys.argv[1]).st_mtime))" "$1"; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

# ── Fixture: git project with KB files, a vault doc, and unit files ──────────
mkdir -p "$ROOT/.mega-sdd/knowledge-base/10-domains" \
         "$ROOT/.mega-sdd/knowledge-base/40-business-rules" \
         "$ROOT/.mega-sdd/vaults/demo/units" "$ROOT/src"
git -C "$ROOT" init -q
git -C "$ROOT" config user.email "t@t"; git -C "$ROOT" config user.name "t"

# aa-fail: an uncited [VERIFIED] claim -> kb_markers FAIL, and missing count
# fields/sections -> kb_output FAIL. zz-pass: no markers (kb_markers PASS).
printf -- '---\ndomain: aa\n---\n# AA\n[VERIFIED] uncited claim here\n' \
  > "$ROOT/.mega-sdd/knowledge-base/10-domains/aa-fail.md"
printf -- '---\ndomain: zz\n---\n# ZZ\nplain prose, no confidence markers\n' \
  > "$ROOT/.mega-sdd/knowledge-base/10-domains/zz-pass.md"
# zz-rules: a fully-PASSING kb_output file, placed in 40-business-rules so the
# kb_output family validates it LAST (the family's file list concatenates
# 10-domains -> 20-workflows -> 40-business-rules deterministically). Its PASS
# lands in the single-slot state file ON TOP of aa-fail's FAIL — the masking
# hazard the severity-max fix exists for.
{
  printf -- '---\ndomain: zz-rules\nverified_count: 0\ninferred_count: 0\nopen_count: 0\n---\n# ZZ Rules\n\n'
  for s in "1. Purpose" "2. Actors" "3. Flow" "4. Entities" "5. Fields & Validation" \
           "6. Business Rules" "7. Integrations" "8. Edge Cases" \
           "9. Rebuild Recommendations" "10. Open Questions" "11. Source Files"; do
    printf -- '## %s\nx\n\n' "$s"
  done
} > "$ROOT/.mega-sdd/knowledge-base/40-business-rules/zz-rules.md"
printf -- '# Index\nno OQs here\n' > "$ROOT/.mega-sdd/vaults/demo/00-index.md"
# vault.json MUST exist: the vault_oqs reuse key includes the sibling vault.json
# sha, and the round proved a fixture without one is blind to the TAB-collapse
# class (an empty sibling sha on both sides made broken reuse look healthy).
printf -- '{}\n' > "$ROOT/.mega-sdd/vaults/demo/vault.json"
# TWO units: with one unit, a regression back to the per-unit O(n^2) loop is
# indistinguishable from the single project-wide invocation.
printf -- '---\nid: U-001\ntitle: t\n---\n# U-001\n' \
  > "$ROOT/.mega-sdd/vaults/demo/units/U-001.md"
printf -- '---\nid: U-002\ntitle: t2\n---\n# U-002\n' \
  > "$ROOT/.mega-sdd/vaults/demo/units/U-002.md"
printf -- 'fn main() {}\n' > "$ROOT/src/app.rs"
git -C "$ROOT" add -A >/dev/null 2>&1; git -C "$ROOT" commit -qm init

MARK_SLOT="$ROOT/.mega-sdd/.kb-markers-state.json"
UNIT_SLOT="$ROOT/.mega-sdd/.unit-spec-state.json"
OQ_SLOT="$ROOT/.mega-sdd/.vault-oqs-state.json"
LEDGER="$ROOT/.mega-sdd/.analyze-freshness.json"

# ── Run 1: cold (no ledger) ──────────────────────────────────────────────────
bash "$ANALYZE" --cwd="$ROOT" --quiet >/dev/null 2>&1
[ -f "$LEDGER" ] && pass "run1 writes the freshness ledger" || fail "run1: no ledger written"
[ "$(_state scope_mode)" = "scoped" ] && pass "run1 scope_mode=scoped (default)" || fail "run1 scope_mode=$(_state scope_mode)"
R1_RERUN="$(_state rerun_files)"
[ "$(_state reused_files)" = "0" ] && pass "run1 reuses nothing (cold)" || fail "run1 reused=$(_state reused_files) on a cold ledger"

# 9. family whitelist
WL=$(python3 -c "
import json
d = json.load(open('$LEDGER'))
allowed = {'kb_output','kb_markers','kb_flows','vault_flows','fsd_slots','vault_oqs'}
extra = set(d.get('families', {})) - allowed
print('OK' if not extra else 'EXTRA:' + ','.join(sorted(extra)))")
[ "$WL" = "OK" ] && pass "ledger families ⊆ the six reusable families" || fail "ledger family whitelist: $WL"

# 4b. unit_baseline recorded
UB=$(python3 -c "import json;print(len(json.load(open('$LEDGER')).get('unit_baseline',{})))")
[ "$UB" = "2" ] && pass "unit_baseline records both unit files" || fail "unit_baseline has $UB entries (want 2)"

# 4c. TAB-collapse regression pin: the vault_oqs ledger entry must carry the REAL
# sibling vault.json sha (64 hex chars) — a collapsed row records "" and reuse
# silently dies in every project with a vault.json.
SIB_LEN=$(python3 -c "
import json
d = json.load(open('$LEDGER'))
ent = d['families'].get('vault_oqs', {})
print(len(next(iter(ent.values()))['sibling_sha']) if ent else -1)")
[ "$SIB_LEN" = "64" ] && pass "vault_oqs ledger entry carries the real sibling_sha" || fail "vault_oqs sibling_sha length=$SIB_LEN (want 64 — TAB-collapse regression)"

# 5. masking mutant — kb_output validates aa-fail (10-domains, FAIL) BEFORE
# zz-rules (40-business-rules, PASS): the single-slot state file ends holding
# the PASS, but the boundary must report the severity-max FAIL.
KBO_SLOT_JSON="$ROOT/.mega-sdd/.kb-output-state.json"
KBO_SLOT_ST=$(python3 -c "import json;d=json.load(open('$KBO_SLOT_JSON'));print(d.get('status','?'), d.get('checked_file','?'))" 2>/dev/null || echo "? ?")
case "$KBO_SLOT_ST" in
  "PASS "*zz-rules.md) pass "masking hazard live: kb_output slot holds the later PASS (${KBO_SLOT_ST#PASS })" ;;
  *) fail "fixture did not produce the masking hazard (slot: $KBO_SLOT_ST — expected PASS on zz-rules.md)" ;;
esac
KBO_BOUND="$(_boundary kb_output)"
[ "$KBO_BOUND" = "FAIL" ] && pass "kb_output boundary=FAIL (severity-max beats the slot's PASS)" || fail "kb_output boundary=$KBO_BOUND — the slot's PASS masked an earlier FAIL"

# ── Run 2: warm, nothing changed ─────────────────────────────────────────────
M_MARK1=$(_mtime "$MARK_SLOT"); M_UNIT1=$(_mtime "$UNIT_SLOT")
sleep 1
bash "$ANALYZE" --cwd="$ROOT" --quiet >/dev/null 2>&1
M_MARK2=$(_mtime "$MARK_SLOT"); M_UNIT2=$(_mtime "$UNIT_SLOT")
R2_RERUN="$(_state rerun_files)"

[ "$(_state reused_files)" -gt 0 ] && pass "run2 reuses per-file verdicts ($(_state reused_files) reused)" || fail "run2 reused=0 — reuse dead"
[ "$M_MARK1" = "$M_MARK2" ] && pass "run2: kb_markers slot mtime frozen (validator NOT spawned)" || fail "run2: kb_markers slot rewritten — reuse did not skip the spawn"
[ "$M_UNIT1" != "$M_UNIT2" ] && pass "run2: unit_spec re-ran (never reused — env-coupled single invocation)" || fail "run2: unit_spec slot mtime frozen — it must ALWAYS re-run"
[ "$(_boundary kb_markers)" = "FAIL" ] && pass "run2: reused FAIL verdict stays FAIL (honest reuse)" || fail "run2: kb_markers=$(_boundary kb_markers) — reuse laundered a FAIL"
rtk_scope_line=$(grep -F "Scope: per-file validators" "$ROOT/.mega-sdd/CONSISTENCY-REPORT.md" || true)
[ -n "$rtk_scope_line" ] && pass "report carries the honest Scope line" || fail "report missing the Scope line"

# ── Run 3: one KB file changes -> it re-runs and its verdict FLIPS ───────────
printf -- '---\ndomain: zz\n---\n# ZZ\n[VERIFIED] a new uncited claim\n' \
  > "$ROOT/.mega-sdd/knowledge-base/10-domains/zz-pass.md"
sleep 1
bash "$ANALYZE" --cwd="$ROOT" --quiet >/dev/null 2>&1
M_MARK3=$(_mtime "$MARK_SLOT")
[ "$M_MARK2" != "$M_MARK3" ] && pass "run3: changed KB file re-validated" || fail "run3: change did not trigger a re-run"
ZZ_ST=$(python3 -c "
import json
d = json.load(open('$LEDGER'))
for rel, e in d['families'].get('kb_markers', {}).items():
    if rel.endswith('zz-pass.md'):
        print(e['status']); break
else:
    print('?')")
[ "$ZZ_ST" = "FAIL" ] && pass "run3: the changed file's ledgered verdict flipped PASS->FAIL" || fail "run3: zz-pass kb_markers status=$ZZ_ST (want FAIL — verdict not recomputed)"
R3_REUSED="$(_state reused_files)"
[ "$R3_REUSED" -gt 0 ] && pass "run3: unchanged pure files still reused ($R3_REUSED)" || fail "run3: reuse collapsed on a single-file change"

# ── Run 4: CODE change (outside .mega-sdd) -> env-coupled re-runs, pure reuses ─
# vault_oqs may legitimately write no state slot (PASS with nothing to report),
# so the observable is the rerun COUNT: a steady-state run re-runs only the
# always-fresh unit_spec; a code change must add the env-coupled vault_oqs doc.
M_MARK4a=$(_mtime "$MARK_SLOT")
printf -- 'fn main() { println!("changed"); }\n' > "$ROOT/src/app.rs"
sleep 1
bash "$ANALYZE" --cwd="$ROOT" --quiet >/dev/null 2>&1
M_MARK4b=$(_mtime "$MARK_SLOT")
R4_RERUN="$(_state rerun_files)"
[ "$R4_RERUN" -gt "$R2_RERUN" ] && pass "run4: code-tree change re-ran the env-coupled family (rerun $R2_RERUN -> $R4_RERUN)" || fail "run4: rerun_files=$R4_RERUN not above the steady-state $R2_RERUN — fingerprint invalidation dead"
[ "$M_MARK4a" = "$M_MARK4b" ] && pass "run4: pure kb_markers still reused across the code change" || fail "run4: pure family re-ran on an unrelated code change"

# ── Run 5: KB-tree DELETE -> kb-coupled families re-run (laundering pin) ─────
# vault_oqs resolves citations + its KB inventory in knowledge-base/, and
# kb_output resolves depends_on against sibling KB files: deleting a KB file
# must invalidate their reuse even though no validated doc changed. The round
# proved sha-only keys laundered a stale PASS here.
KBO_SLOT="$ROOT/.mega-sdd/.kb-output-state.json"
M_KBO5a=$(_mtime "$KBO_SLOT")
rm "$ROOT/.mega-sdd/knowledge-base/40-business-rules/zz-rules.md"
sleep 1
bash "$ANALYZE" --cwd="$ROOT" --quiet >/dev/null 2>&1
M_KBO5b=$(_mtime "$KBO_SLOT")
[ "$M_KBO5a" != "$M_KBO5b" ] && pass "run5: KB delete re-ran kb_output (kb_fingerprint invalidation)" || fail "run5: kb_output reused across a KB delete — stale-PASS laundering regression"

# ── O(n^2) collapse: unit_spec spawns exactly ONCE for 2 units ───────────────
REALBASH=$(command -v bash)
mkdir -p "$ROOT/shim"
printf '#!%s\necho "$1" >> "%s/spawn.log"\nexec %s "$@"\n' "$REALBASH" "$ROOT" "$REALBASH" > "$ROOT/shim/bash"
chmod +x "$ROOT/shim/bash"
: > "$ROOT/spawn.log"
PATH="$ROOT/shim:$PATH" bash "$ANALYZE" --cwd="$ROOT" --quiet --fresh >/dev/null 2>&1
US_SPAWNS=$(grep -c "validate-unit-spec.sh" "$ROOT/spawn.log" 2>/dev/null || true)
[ "$US_SPAWNS" = "1" ] && pass "unit_spec spawned exactly once for 2 units (O(n^2) collapsed)" || fail "unit_spec spawned $US_SPAWNS time(s) for 2 units (want exactly 1)"

# ── 6. plugin_version invalidation ───────────────────────────────────────────
python3 -c "
import json
d = json.load(open('$LEDGER')); d['plugin_version'] = '0.0.0'
json.dump(d, open('$LEDGER','w'))"
bash "$ANALYZE" --cwd="$ROOT" --quiet >/dev/null 2>&1
[ "$(_state reused_files)" = "0" ] && pass "version-mismatched ledger fully invalidated" || fail "reused $(_state reused_files) file(s) from a version-mismatched ledger"

# ── 7. --fresh ───────────────────────────────────────────────────────────────
bash "$ANALYZE" --cwd="$ROOT" --quiet --fresh >/dev/null 2>&1
[ "$(_state scope_mode)" = "fresh" ] && [ "$(_state reused_files)" = "0" ] \
  && pass "--fresh forces a full re-run (scope_mode=fresh, 0 reused)" \
  || fail "--fresh: scope_mode=$(_state scope_mode) reused=$(_state reused_files)"

# ── 8. --aggregate-only never touches the ledger ─────────────────────────────
M_LED1=$(_mtime "$LEDGER"); sleep 1
bash "$ANALYZE" --cwd="$ROOT" --quiet --aggregate-only >/dev/null 2>&1
M_LED2=$(_mtime "$LEDGER")
[ "$M_LED1" = "$M_LED2" ] && pass "--aggregate-only leaves the ledger untouched" || fail "--aggregate-only mutated the ledger"
[ "$(_state scope_mode)" = "aggregate" ] && pass "aggregate run reports scope_mode=aggregate" || fail "aggregate scope_mode=$(_state scope_mode)"

# ── 10. Doc pins ─────────────────────────────────────────────────────────────
LU="$PLUGIN_ROOT/skills/orchestrate-flow/references/diagnostics-procedures.md"
grep -qF -- "--changed-only" "$LU" \
  && grep -qF "changed ∪ dependents" "$LU" \
  && grep -qF "no freshness ledger — full sweep" "$LU" \
  && pass "diagnostics-procedures.md (lint-units' post-cull home) pins --changed-only + closure rule + honest fallback" \
  || fail "diagnostics-procedures.md missing a --changed-only contract element"
grep -qF -- "lint-units --changed-only" "$PLUGIN_ROOT/skills/orchestrate-flow/references/chain-execution.md" \
  && pass "chain auto-lint row passes --changed-only" \
  || fail "chain-execution.md auto-lint row not scoped"
grep -qF -- "--fresh" "$PLUGIN_ROOT/skills/analyze/SKILL.md" \
  && grep -qF "Scoped by default" "$PLUGIN_ROOT/skills/analyze/SKILL.md" \
  && grep -qF "Semantic-scoped by default" "$PLUGIN_ROOT/skills/analyze/SKILL.md" \
  && pass "analyze SKILL.md (the surviving doc plane post-6.0.0-cull) documents --fresh + both scoped-default phrasings" \
  || fail "analyze SKILL.md missing --fresh or the scoped-default prose"
grep -qF -- "lint-units --changed-only" "$PLUGIN_ROOT/commands/mega-sdd.md" \
  && pass "front-door diagnostics table row scoped (--changed-only)" \
  || fail "mega-sdd.md auto-lint row not scoped"

echo
if [ "$fails" -eq 0 ]; then
  echo "test-analyze-freshness: ALL PASS"
  exit 0
else
  echo "test-analyze-freshness: $fails FAILURE(S)"
  exit 1
fi
