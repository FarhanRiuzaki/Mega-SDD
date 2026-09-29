#!/usr/bin/env bash
# test-p1-claims-ledger-express.sh — v6 P1 proof suite (spec
# §P1.4, commit 1be513ef), trimmed to what survives 9.0:
#
#   2. Grammar byte-compat — an express-shaped binding.md (no-snapshot provenance
#      + the additive binding_metadata.retrieval key) through the REAL layout-2
#      chain: stamp -> derive-binding-json -> validate-handoff-binding-units
#      (FAIL on active CONFLICT, PASS once resolved). The retrieval key must be
#      parser-invisible (binding.json equal with/without it).
#   3. Seed-not-boundary reachability — a colliding symbol OUTSIDE the claim's
#      expected dir MUST be reachable via the unfiltered index query (the
#      collision sweep's substrate is global by construction), + prose pins that
#      the text-claim ladder E3 mandates the sweep, the fail-closed ladder, and
#      never-CONFIRMED-by-absence.
#   4. Flag surface — --express stays in the front-door hint with a body bullet
#      (translation law); ladder E3 is routed from execute-bolts SKILL.md.
#
# 9.0 P1 (spec 2026-09-27 §2/§7): bind-codebase and its express-bind.md /
# binding-contract.md / auto-memory-handoff.md are deleted. The per-claim
# retrieval ladder, its rails and the read-evidence field-diff rule survive
# VERBATIM as ladder E3 of the JIT per-unit bind
# (skills/execute-bolts/references/jit-bind-and-quarantine.md §E3), so the
# section-3 prose pins follow them there. RETIRED with the whole-vault express
# bind: the E0/E1 standard-lane fallback + rc taxonomy, the E2 ledger-skeleton
# completeness sweep + per-category note + scope_metadata propagation, the
# --paths / prior-binding.md composition, binding.md frontmatter provenance
# (no-snapshot / retrieval key / snapshot-verified override), the
# binding_input_complete predictive carve-out, and the --express spine switch
# (orchestrate-flow §Flags, bind-hop append, bind SKILL). Section 2 stays:
# derive-binding-json.sh + validate-handoff-binding-units.sh are the layout-2
# read/gate side (spec 2026-09-27 §7 #8/#10).
#
# 9.0 P1b: derive-claims-ledger.sh, make-bound.sh and validate-binding-json.sh
# were deleted (no surviving executor). RETIRED with them: section 1 (ledger
# determinism — the whole section pinned the ledger deriver), the section-2
# parity call and make-bound refuse/derive legs (the CONFLICT gate itself stays
# pinned through validate-handoff-binding-units, both directions), and section 5
# (claims-ledger.json registrations in paths.md + the Stop-hook prune list —
# the file has no writer left).
#
# CI-safe: bash + python3 only; no ast-grep dependency (index fixtures are
# hand-written; query-symbol-index.sh is a pure reader).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/plugins/mega-sdd"
FIX="$P/tests/graph/fixtures/derive-vault"

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ══ 2. Grammar byte-compat (express-shaped binding through the real chain) ═══
PROJ="$WORK/proj3"
EV="$PROJ/.mega-sdd/vaults/demo"
mkdir -p "$EV"
cp "$FIX"/0*.md "$EV/"

write_express_binding() {  # $1 = 1 active conflict | 2 resolved (DEFER)
  # Variant 2 mirrors a post-resolve-oq DEFER: the CONFLICT block stays as a
  # ✅ RESOLVED (DEFER) record, the State Map row re-verdicts to OQ, Summary
  # conflict drops to 0 (no CONFLICT verdict), the gate
  # sees the DEFER-resolved id as an ADVISORY extra (KEEP_VAULT would demand a
  # citing unit and correctly stay blocking — deliberately not this arm).
  local C_HEAD='### CONFLICT-1 — product name collision'
  local C_RES=''
  local ROW_DM02='| C-DM-02 | CONFLICT | UNKNOWN | modules/billing/Product.php:7 | medium | n/a |'
  local SUM_CONFLICT=1 SUM_OQ=1
  if [ "$1" = "2" ]; then
    C_HEAD='### ✅ CONFLICT-1 RESOLVED (DEFER) — product name collision'
    C_RES='- **Resolution**: ✅ RESOLVED (DEFER) 2026-08-03 — deferred to a later vault revision'
    ROW_DM02='| C-DM-02 | OQ | UNKNOWN | modules/billing/Product.php:7 | medium | n/a |'
    SUM_CONFLICT=0 SUM_OQ=2
  fi
  cat > "$EV/binding.md" <<EOF
---
vault: demo
codebase_map: .mega-sdd/codebase/codebase-map.md
bound_at: 2026-08-03T00:00:00Z
strict: false
binding_metadata:
  codebase_map_provenance: no-snapshot
  head: abc123def456
  retrieval: express-index@abc123de
---

# Binding Manifest

## Summary
- claims_total: 4
- confirmed: 2
- conflict: $SUM_CONFLICT
- oq: $SUM_OQ

## Confirmed Claims (2)
- C-DM-01 | 03-data-model.md:6 | app/Models/User.php:10 | System user account
- C-FL-01 | 04-flows.md:5 | app/Controllers/LeaveController.php:20 | Submit leave request

## Implementation State Map (4 — ALWAYS 6 columns; the Field diff cell is \`n/a\` unless precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-DM-01 | CONFIRMED | IMPLEMENTED | app/Models/User.php:10 | high | (exact match) |
| C-FL-01 | CONFIRMED | IMPLEMENTED | app/Controllers/LeaveController.php:20 | high | n/a |
$ROW_DM02
| C-DC-01 | OQ | NEW | — | n/a | n/a |

## Conflicts ($SUM_CONFLICT) — BLOCKING

$C_HEAD
- **Vault claim**: leave_request billing product entity
- **Codebase reality**: pre-existing Product class (modules/billing/Product.php:7)
- **Claim**: C-DM-02
- **Vault doc**: 03-data-model.md §Product
- **Codebase artifact**: modules/billing/Product.php
- **conflict_class**: naming-collision
- **resolution_complexity**: low
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT — vault Product is the target entity (modules/billing/Product.php:7)
$C_RES

## Open Questions (1)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | which auth strategy? | 05-decisions.md:6 | N/A (fresh OQ) |
EOF
}

write_express_binding 1
bash "$P/scripts/derive-binding-json.sh" --vault "$EV" >/dev/null 2>&1 \
  && pass "derive-binding-json (phase-0 stamp) rc 0 on express binding" \
  || fail "derive/stamp failed on express binding"
grep -qF 'REGENERATED by bind-codebase' "$EV/binding.md" \
  && pass "banner stamped" || fail "banner missing after stamp"

bash "$P/scripts/derive-binding-json.sh" --vault "$EV" >/dev/null 2>&1 \
  && pass "derive-binding-json rc 0 (express frontmatter accepted)" \
  || fail "derive-binding-json rejected express binding"

DBJ_CHECK=$(V="$EV" python3 - <<'PY'
import json, os
d = json.load(open(os.path.join(os.environ["V"], "binding.json")))
errs = []
if d.get("codebase_map_provenance") != "no-snapshot":
    errs.append(f"provenance={d.get('codebase_map_provenance')}")
if d.get("head") != "abc123def456":
    errs.append(f"head={d.get('head')}")
ids = {c["id"]: c for c in d["claims"]}
if ids.get("C-DM-02", {}).get("verdict") != "CONFLICT":
    errs.append("C-DM-02 verdict wrong")
if ids.get("C-DM-01", {}).get("vault_source") != "03-data-model.md:6":
    errs.append("C-DM-01 vault_source wrong")
print(";".join(errs) if errs else "OK")
PY
)
[ "$DBJ_CHECK" = "OK" ] \
  && pass "binding.json carries provenance/head/verdicts verbatim (retrieval key invisible)" \
  || fail "binding.json content: $DBJ_CHECK"

# retrieval-key invisibility: strip the key, re-derive, compare (minus generated_at)
cp "$EV/binding.json" "$WORK/with-key.json"
python3 - "$EV/binding.md" <<'PY'
import sys
p = sys.argv[1]
lines = [l for l in open(p, encoding="utf-8").read().splitlines(True)
         if "retrieval: express-index@" not in l]
open(p, "w", encoding="utf-8").writelines(lines)
PY
bash "$P/scripts/derive-binding-json.sh" --vault "$EV" >/dev/null 2>&1
KEY_INVIS=$(A="$WORK/with-key.json" B="$EV/binding.json" python3 - <<'PY'
import json, os
a = json.load(open(os.environ["A"])); b = json.load(open(os.environ["B"]))
a.pop("generated_at", None); b.pop("generated_at", None)
print("OK" if a == b else "DIFF")
PY
)
[ "$KEY_INVIS" = "OK" ] \
  && pass "binding.json identical with/without the additive retrieval key" \
  || fail "the retrieval key leaked into binding.json"
write_express_binding 1
bash "$P/scripts/derive-binding-json.sh" --vault "$EV" >/dev/null 2>&1

# the moat gate: active CONFLICT in an express binding -> FAIL + blocker
bash "$P/scripts/validate-handoff-binding-units.sh" --cwd="$PROJ" --quiet >/dev/null 2>&1
GATE_RC=$?
grep -q '"conflict_unresolved"' "$PROJ/.mega-sdd/.validation-blockers.json" 2>/dev/null \
  && [ "$GATE_RC" -eq 1 ] \
  && pass "CONFLICT gate FAILs on the express binding (conflict_unresolved)" \
  || fail "CONFLICT gate did not fire on express binding (rc=$GATE_RC)"

# resolved variant -> gate opens
write_express_binding 2
bash "$P/scripts/derive-binding-json.sh" --vault "$EV" >/dev/null 2>&1 \
  || fail "derive-binding-json failed on resolved express binding"
bash "$P/scripts/validate-handoff-binding-units.sh" --cwd="$PROJ" --quiet >/dev/null 2>&1
grep -q '"status": "PASS"' "$PROJ/.mega-sdd/.validation-blockers.json" 2>/dev/null \
  && pass "gate PASSes once the express CONFLICT is structurally resolved" \
  || fail "gate did not PASS after resolution"

# ══ 3. Seed-not-boundary reachability ════════════════════════════════════════
IDX="$WORK/symbol-index.json"
cat > "$IDX" <<'EOF'
{"generated_by":"build-symbol-index.sh","generated_at":"2026-08-03T00:00:00Z","head_commit":"abc123def4567890","astgrep_version":"0.42.3","file_count":2,"symbol_count":2,"symbols":[{"name":"Product","kind":"php-class","file":"app/Models/Product.php","line":5,"signature":"class Product extends Model","lang":"php"},{"name":"Product","kind":"php-class","file":"modules/billing/Product.php","line":7,"signature":"class Product","lang":"php"}]}
EOF
ROWS_ALL=$(bash "$P/scripts/query-symbol-index.sh" --index="$IDX" --name=Product 2>/dev/null | wc -l | tr -d ' ')
ROWS_DIR=$(bash "$P/scripts/query-symbol-index.sh" --index="$IDX" --name=Product --dir=app 2>/dev/null | wc -l | tr -d ' ')
OUTSIDE_HIT=$(bash "$P/scripts/query-symbol-index.sh" --index="$IDX" --name=Product 2>/dev/null | grep -c "modules/billing/Product.php" || true)
[ "$ROWS_ALL" = "2" ] && [ "$ROWS_DIR" = "1" ] && [ "$OUTSIDE_HIT" = "1" ] \
  && pass "seed-not-boundary: the UNFILTERED name query surfaces the out-of-dir collision (2 rows global, 1 scoped)" \
  || fail "seed-not-boundary reachability: all=$ROWS_ALL dir=$ROWS_DIR outside=$OUTSIDE_HIT"

# 9.0 P1: express-bind.md §E3 relocated VERBATIM to the JIT bind's ladder E3.
EB="$P/skills/execute-bolts/references/jit-bind-and-quarantine.md"
grep -qF 'Collision sweep (moat-critical' "$EB" \
  && grep -qF 'repo-WIDE' "$EB" \
  && pass "ladder E3 mandates the repo-wide collision sweep" \
  || fail "collision sweep mandate missing"
# (the pre-9.0 pin was a two-line grep -F pattern — an OR of 'two' and the
# indented second line; pinned here as single-line fragments, which is stricter)
grep -qF 'legs, BOTH mandatory' "$EB" \
  && grep -qF 'one bounded repo-wide `Grep` for the' "$EB" \
  && grep -qF 'the index sees only tracked files' "$EB" \
  && pass "collision sweep carries the mandatory Grep leg (index-coverage residual closed)" \
  || fail "Grep leg / index-coverage disclosure missing"
# (RETIRED 9.0 P1: E2 completeness sweep / ledger-as-skeleton, the per-category
# this-category-is-empty note, the --paths prior-binding.md composition, and the
# scope_metadata → binding.md header propagation — all whole-vault express-bind
# steps; the JIT bind derives claims per unit via derive-unit-claims.sh.)
grep -qF 'Never mint `regex_tier` in this lane' "$EB" \
  && pass "regex_tier honestly excluded (no tier signal without the map)" \
  || fail "regex_tier instruction still underivable"
# (RETIRED 9.0 P1: the E1 unknown-rc catch-all — it guarded the fallback to the
# standard bind lane, which no longer exists.)

# (RETIRED 9.0 P1: predictive-checks binding_input_complete express carve-out —
# the check died with the bind hop; auto-memory-handoff.md's snapshot-verified
# override — whole-vault binding.md provenance, deleted with bind-codebase.)
# binding-contract.md's express field-diff variant is now the ONLY field-diff
# rule of ladder E3: read evidence, never the map's ast precision tier.
grep -qF "A field diff is allowed ONLY when the entity's source file was" "$EB" \
  && grep -qF 'never inferred from index signatures' "$EB" \
  && ! grep -qF 'precision_tier' "$EB" \
  && pass "ladder E3 field-diff precondition is read-evidence (no ast-tier contradiction)" \
  || fail "field-diff ast-tier contradiction unamended"
grep -qF 'CONFIRMED-by-absence' "$EB" \
  && pass "never-CONFIRMED-by-absence rail present" \
  || fail "CONFIRMED-by-absence rail missing"
grep -qF 'Index rows are POINTERS, never evidence' "$EB" \
  && grep -qF 'Verdicts anchor to READ evidence only' "$EB" \
  && pass "query-never-inject rail (A3) present" \
  || fail "A3 rail missing"
grep -qF 'shed raw file-read content' "$EB" \
  && pass "anti-rot context discipline (A1) present" \
  || fail "A1 anti-rot discipline missing"
grep -qF 'NOT optional and NOT scoped' "$EB" \
  && pass "collision sweep pinned unconditional" \
  || fail "collision sweep conditionality leak"

# ══ 4. Flag surface ═══════════════════════════════════════════════════════════
FD="$P/commands/mega-sdd.md"
XB="$P/skills/execute-bolts/SKILL.md"
# (6.0.0 cull: the bind-codebase command alias is gone — the typed --express
# surface is the front door, asserted below.)
grep -q -- '--express' <(grep 'argument-hint:' "$FD") \
  && pass "--express in the front-door argument-hint" \
  || fail "--express missing from front-door hint"
# 9.0 P1: the flag is still in the hint, so the translation law still demands a
# body bullet — now "accepted, selects no spine, no bind hop, no fallback".
grep -qF -- '`--express` — accepted; it selects no spine' "$FD" \
  && grep -qF 'there is no bind hop and no standard-lane fallback' "$FD" \
  && pass "front-door --express bullet present (translation law satisfied)" \
  || fail "front-door --express bullet missing"
# (RETIRED 9.0 P1: orchestrate-flow §Flags spine switch, the bind-hop --express
# append rule, and the bind SKILL --express declaration — the spine switch and
# bind-codebase are gone.)
grep -qF 'references/jit-bind-and-quarantine.md' "$XB" \
  && grep -qF 'ladder E3' "$XB" \
  && pass "execute-bolts SKILL.md routes to ladder E3 (one level deep)" \
  || fail "ladder E3 reference not routed from execute-bolts SKILL.md"

# ══ 5. Registrations — RETIRED ═══════════════════════════════════════════════
# (RETIRED 9.0 P1: the loud standard-lane fallback + standard-fallback audit
# token, the fallback no-retrieval-key rule, and express binding.md provenance
# = no-snapshot — the standard bind lane and the whole-vault express binding.md
# writer are deleted. Section 2 still proves the layout-2 READ side parses the
# no-snapshot + retrieval-key frontmatter.)
# (RETIRED 9.0 P1b: the claims-ledger.json paths.md registration and Stop-hook
# prune-list pins — derive-claims-ledger.sh, the file's only writer, is deleted.)

# ══ verdict ═══════════════════════════════════════════════════════════════════
echo
if [ "$fails" -eq 0 ]; then
  echo "test-p1-claims-ledger-express: ALL PASS"
  exit 0
else
  echo "test-p1-claims-ledger-express: $fails FAILURE(S)"
  exit 1
fi
