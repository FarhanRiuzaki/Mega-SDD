#!/usr/bin/env bash
# test-p1-claims-ledger-express.sh — v6 P1 proof suite (spec
# 2026-08-03-v6-express-spine-design.md §P1.4):
#
#   1. Ledger determinism — derive-claims-ledger.sh on the shared vault fixture:
#      claim set, verbatim text, SRC_RE-form sources, byte-identical re-derive,
#      honest exit 2 on an empty/grammarless vault.
#   2. Grammar byte-compat — an express-shaped binding.md (no-snapshot provenance
#      + the additive binding_metadata.retrieval key) through the REAL chain:
#      stamp -> derive-binding-json -> validate-binding-json ->
#      validate-handoff-binding-units (FAIL on active CONFLICT) -> make-bound
#      (refuses, then passes once resolved). The retrieval key must be
#      parser-invisible (binding.json equal with/without it).
#   3. Seed-not-boundary reachability — a colliding symbol OUTSIDE the claim's
#      expected dir MUST be reachable via the unfiltered index query (the
#      collision sweep's substrate is global by construction), + prose pins that
#      express-bind.md mandates the sweep, the fail-closed ladder, and
#      never-CONFIRMED-by-absence.
#   4. Flag parity — --express registered across every surface the translation
#      law requires (front-door hint + body, orchestrate-flow §Flags, bind SKILL,
#      bind command alias, express-bind.md routed from SKILL.md).
#   5. Fallback honesty + registrations — loud standard-lane fallback rules
#      pinned; claims-ledger.json registered in paths.md + both hook prune lists.
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

# ══ 1. Ledger determinism ═════════════════════════════════════════════════════
V1="$WORK/proj1/.mega-sdd/vaults/demo"
mkdir -p "$V1"
cp "$FIX"/0*.md "$V1/"

bash "$P/scripts/derive-claims-ledger.sh" --vault "$V1" >/dev/null 2>&1
[ $? -eq 0 ] && [ -f "$V1/claims-ledger.json" ] \
  && pass "ledger derives (rc 0) on the shared vault fixture" \
  || fail "ledger derive failed on the shared vault fixture"

LEDGER_CHECK=$(V="$V1" python3 - <<'PY'
import json, os, re
d = json.load(open(os.path.join(os.environ["V"], "claims-ledger.json")))
errs = []
ids = [c["id"] for c in d["claims"]]
types = {c["type"] for c in d["claims"]}
if len(ids) != len(set(ids)):
    errs.append("duplicate claim ids")
for want in ("mode", "entity", "flow", "decision"):
    if want not in types:
        errs.append(f"missing claim type {want}")
SRC_RE = re.compile(r"^(\d{2}-[A-Za-z0-9._-]+\.md):(\d+)$")
for c in d["claims"]:
    if not SRC_RE.match(c["source"]):
        errs.append(f"{c['id']}: source not SRC_RE form: {c['source']}")
ent = next((c for c in d["claims"] if c["type"] == "entity" and c.get("entity") == "leave_request"), None)
if not ent:
    errs.append("leave_request entity claim missing")
else:
    if "LeaveRequest" not in ent["hints"]["symbols"]:
        errs.append("PascalCase hint variant missing")
    if not ent.get("fields"):
        errs.append("entity fields[] empty")
if not d.get("doc_shas", {}).get("03-data-model.md"):
    errs.append("doc_shas missing 03-data-model.md")
print(";".join(errs) if errs else "OK")
PY
)
[ "$LEDGER_CHECK" = "OK" ] \
  && pass "ledger schema: types, unique ids, SRC_RE sources, hints, fields, doc_shas" \
  || fail "ledger schema check: $LEDGER_CHECK"

# verbatim text: the entity claim text is the fixture's Purpose comment, verbatim
grep -qF '"text": "System user account"' "$V1/claims-ledger.json" \
  && pass "claim text is verbatim vault text (Purpose comment)" \
  || fail "entity claim text not verbatim from the vault"

# byte-identical re-derive (generated_at preserved on identical content)
S1=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V1/claims-ledger.json','rb').read()).hexdigest())")
bash "$P/scripts/derive-claims-ledger.sh" --vault "$V1" >/dev/null 2>&1
S2=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V1/claims-ledger.json','rb').read()).hexdigest())")
[ "$S1" = "$S2" ] \
  && pass "re-derive is byte-identical (deterministic, generated_at preserved)" \
  || fail "re-derive changed bytes"

# empty vault -> honest exit 2, ledger NOT written
V2="$WORK/proj2/.mega-sdd/vaults/empty"
mkdir -p "$V2"
for f in 00-index.md 01-overview.md 02-architecture.md 03-data-model.md 04-flows.md 05-decisions.md 06-constraints.md; do
  printf '# stub\n' > "$V2/$f"
done
bash "$P/scripts/derive-claims-ledger.sh" --vault "$V2" >/dev/null 2>&1
RC=$?
[ "$RC" -eq 2 ] && [ ! -f "$V2/claims-ledger.json" ] \
  && pass "zero-claims vault -> exit 2, ledger NOT written (fail-closed)" \
  || fail "zero-claims vault: rc=$RC written=$([ -f "$V2/claims-ledger.json" ] && echo yes || echo no)"

# missing vault dir -> exit 3
bash "$P/scripts/derive-claims-ledger.sh" --vault "$WORK/nope" >/dev/null 2>&1
[ $? -eq 3 ] && pass "missing vault dir -> exit 3" || fail "missing vault dir rc != 3"

# ── 1b. Round-folded adversarial arms ────────────────────────────────────────
# abs vs rel vs trailing-slash invocation -> byte-identical ledger (the vault
# field records the slug, never the caller's argument)
S_ABS=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V1/claims-ledger.json','rb').read()).hexdigest())")
( cd "$WORK/proj1" && bash "$P/scripts/derive-claims-ledger.sh" --vault .mega-sdd/vaults/demo >/dev/null 2>&1 )
bash "$P/scripts/derive-claims-ledger.sh" --vault "$V1/" >/dev/null 2>&1
S_REL=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V1/claims-ledger.json','rb').read()).hexdigest())")
[ "$S_ABS" = "$S_REL" ] \
  && pass "abs/rel/trailing-slash invocations are byte-identical (vault = slug)" \
  || fail "invocation form changed ledger bytes"
grep -qF '"vault": "demo"' "$V1/claims-ledger.json" \
  && pass "vault field is the slug, not the caller path" \
  || fail "vault field leaks the invocation path"

# mode claim comes from the Vault Lock SECTION, never a prose decoy line
V4="$WORK/proj4/.mega-sdd/vaults/decoy"
mkdir -p "$V4"; cp "$FIX"/0*.md "$V4/"
python3 - "$V4/00-index.md" <<'PY'
import sys
p = sys.argv[1]
c = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write("# Vault\n\n- **Implementation mode**: `WRONG-decoy`\n\n" + c)
PY
bash "$P/scripts/derive-claims-ledger.sh" --vault "$V4" >/dev/null 2>&1
python3 - "$V4/claims-ledger.json" <<'PY' && pass "mode claim scoped to the Vault Lock section (decoy ignored)" || fail "mode claim harvested from a prose decoy line"
import json, sys
d = json.load(open(sys.argv[1]))
m = [c for c in d["claims"] if c["type"] == "mode"]
sys.exit(0 if m and "WRONG-decoy" not in m[0]["text"] else 1)
PY

# grammar-marginal DBML fails LOUD (exit 2), never a silently narrowed universe
V5="$WORK/proj5/.mega-sdd/vaults/marginal"
mkdir -p "$V5"; cp "$FIX"/0*.md "$V5/"
printf '# DM\n\n```dbml\nTable caf\303\251_orders {\n  id int\n}\n```\n' > "$V5/03-data-model.md"
bash "$P/scripts/derive-claims-ledger.sh" --vault "$V5" >/dev/null 2>&1
[ $? -eq 2 ] && pass "unparseable Table name -> exit 2 (no silent entity drop)" \
  || fail "unparseable Table name did not fail loud"
printf '# DM\n\n```dbml\nTable inline { id int }\nTable after {\n  id int\n}\n```\n' > "$V5/03-data-model.md"
bash "$P/scripts/derive-claims-ledger.sh" --vault "$V5" >/dev/null 2>&1
[ $? -eq 2 ] && pass "one-line Table block -> exit 2 (depth desync fails loud)" \
  || fail "one-line Table did not fail loud"

# constraint (NFR table, incl. escaped pipe) + component (## §) claim types
V6="$WORK/proj6/.mega-sdd/vaults/full"
mkdir -p "$V6"; cp "$FIX"/0*.md "$V6/"
cat > "$V6/06-constraints.md" <<'EOF'
# Constraints

## §tech-constraints Technical constraints

## Non-functional requirements

| Category | Requirement | Source |
|----------|-------------|--------|
| Performance | p95 API \| latency < 300ms | PRD §7 |
| Scalability | Support 10k concurrent users | PRD §8 |
EOF
bash "$P/scripts/derive-claims-ledger.sh" --vault "$V6" >/dev/null 2>&1
python3 - "$V6/claims-ledger.json" <<'PY' && pass "constraint + component types extracted; escaped pipe unescaped verbatim" || fail "constraint/component extraction or escaped-pipe handling wrong"
import json, sys
d = json.load(open(sys.argv[1]))
types = {c["type"] for c in d["claims"]}
cons = [c for c in d["claims"] if c["type"] == "constraint"]
comp = [c for c in d["claims"] if c["type"] == "component"]
ok = ("constraint" in types and "component" in types
      and any(c["text"] == "p95 API | latency < 300ms" for c in cons)
      and any(c.get("native_id") == "tech-constraints" for c in comp))
sys.exit(0 if ok else 1)
PY

# ══ 2. Grammar byte-compat (express-shaped binding through the real chain) ═══
PROJ="$WORK/proj3"
EV="$PROJ/.mega-sdd/vaults/demo"
mkdir -p "$EV"
cp "$FIX"/0*.md "$EV/"
cp "$FIX/expected-vault.json" "$EV/vault.json"   # make-bound requires a vault manifest

write_express_binding() {  # $1 = 1 active conflict | 2 resolved (DEFER)
  # Variant 2 mirrors a post-resolve-oq DEFER: the CONFLICT block stays as a
  # ✅ RESOLVED (DEFER) record, the State Map row re-verdicts to OQ, Summary
  # conflict drops to 0 — make-bound proceeds (no CONFLICT verdict), the gate
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

bash "$P/scripts/validate-binding-json.sh" --vault "$EV" >/dev/null 2>&1 \
  && pass "validate-binding-json parity rc 0" \
  || fail "binding.json parity failed"

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

bash "$P/scripts/make-bound.sh" --vault "$EV" >/dev/null 2>&1
[ $? -eq 2 ] && [ ! -d "$EV/bound" ] \
  && pass "make-bound REFUSES (rc 2) while the express CONFLICT is active" \
  || fail "make-bound did not refuse on active CONFLICT"

# resolved variant -> gate opens, bound/ derives
write_express_binding 2
bash "$P/scripts/derive-binding-json.sh" --vault "$EV" >/dev/null 2>&1 \
  || fail "derive-binding-json failed on resolved express binding"
bash "$P/scripts/validate-handoff-binding-units.sh" --cwd="$PROJ" --quiet >/dev/null 2>&1
grep -q '"status": "PASS"' "$PROJ/.mega-sdd/.validation-blockers.json" 2>/dev/null \
  && pass "gate PASSes once the express CONFLICT is structurally resolved" \
  || fail "gate did not PASS after resolution"
bash "$P/scripts/make-bound.sh" --vault "$EV" >/dev/null 2>&1 \
  && [ -f "$EV/bound/binding.md" ] \
  && pass "make-bound derives bound/ from the resolved express binding" \
  || fail "make-bound failed on resolved express binding"

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

EB="$P/skills/bind-codebase/references/express-bind.md"
grep -qF 'Collision sweep (moat-critical' "$EB" \
  && grep -qF 'repo-WIDE' "$EB" \
  && pass "express-bind.md mandates the repo-wide collision sweep" \
  || fail "collision sweep mandate missing"
grep -qF 'two
   legs, BOTH mandatory' "$EB" && grep -qF 'the index sees only tracked files' "$EB" \
  && pass "collision sweep carries the mandatory Grep leg (index-coverage residual closed)" \
  || fail "Grep leg / index-coverage disclosure missing"
grep -qF 'completeness sweep' "$EB" && grep -qF 'SKELETON, never the claim
   boundary' "$EB" \
  && pass "E2 mandates the completeness sweep (ledger = skeleton)" \
  || fail "completeness sweep mandate missing"
grep -qF 'this-category-is-empty note' "$EB" \
  && pass "per-category coverage obligation pinned" \
  || fail "category coverage obligation missing"
grep -qF 'sanctioned read' "$EB" && grep -qF 'LEDGER ids' "$EB" \
  && pass "--paths composition: prior binding sanctioned + id-space mapping rules" \
  || fail "--paths composition rules missing"
grep -qF 'constrain claim validation to the scope' "$EB" \
  && pass "scope_metadata propagation preserved in express" \
  || fail "scope paragraph missing"
grep -qF 'Never mint `regex_tier` in this lane' "$EB" \
  && pass "regex_tier honestly excluded (no tier signal without the map)" \
  || fail "regex_tier instruction still underivable"
grep -qF 'an unknown rc is never treated as pass' "$EB" \
  && pass "unknown-rc catch-all on the E1 fallback" \
  || fail "rc taxonomy still open"

# sibling contracts carry the express carve-outs
PC="$P/skills/orchestrate-flow/references/predictive-checks.md"
grep -qF 'express_carve_out' "$PC" && grep -qF 'run ONLY the vault.json arm' "$PC" \
  && pass "predictive-checks binding_input_complete carries the express carve-out" \
  || fail "predictive-check would falsely halt a mapless express chain"
AMH="$P/skills/bind-codebase/references/auto-memory-handoff.md"
grep -qF -- '--express` override' "$AMH" && grep -qF 'never `"snapshot-verified"` on an express bind' "$AMH" \
  && pass "auto-memory-handoff snapshot check carries the express override" \
  || fail "provenance precedence still points the wrong way"
BCON="$P/skills/bind-codebase/references/binding-contract.md"
grep -qF -- '`--express` provenance variant' "$BCON" \
  && pass "binding-contract field-diff precondition amended for express" \
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

# ══ 4. Flag parity across every surface ══════════════════════════════════════
FD="$P/commands/mega-sdd.md"
OF="$P/skills/orchestrate-flow/SKILL.md"
BS="$P/skills/bind-codebase/SKILL.md"
# (6.0.0 cull: the bind-codebase command alias is gone — the typed --express
# surface is the front door, asserted below.)
grep -q -- '--express' <(grep 'argument-hint:' "$FD") \
  && pass "--express in the front-door argument-hint" \
  || fail "--express missing from front-door hint"
grep -qF -- '`--express` / `--classic` — forwarded VERBATIM' "$FD" \
  && pass "front door forwards --express/--classic verbatim (translation law satisfied)" \
  || fail "front-door --express bullet missing"
grep -qF -- '`--express` / `--classic`: the spine switch' "$OF" \
  && pass "orchestrate-flow §Flags owns the spine switch" \
  || fail "orchestrate-flow §Flags missing --express"
grep -qF 'appends `--express` to every `bind-codebase` hop' "$OF" \
  && pass "orchestrator appends --express to bind hops (P2 default)" \
  || fail "bind-hop append rule missing"
grep -qF -- '`--express` (claim-scoped retrieval lane' "$BS" \
  && pass "bind SKILL declares --express" \
  || fail "bind SKILL missing --express"
grep -qF 'references/express-bind.md' "$BS" \
  && pass "SKILL.md routes to express-bind.md (one level deep)" \
  || fail "express-bind.md not routed from SKILL.md"
# (bind command alias removed in the 6.0.0 cull — no typed-alias hint to pin.)

# ══ 5. Fallback honesty + registrations ══════════════════════════════════════
grep -qF 'fall back to the' "$EB" && grep -qF 'standard-fallback' "$EB" \
  && pass "loud standard-lane fallback + audit token pinned" \
  || fail "fallback honesty rules missing"
grep -qF 'NO `binding_metadata.retrieval` key' "$EB" \
  && pass "fallback run must not carry the express retrieval key" \
  || fail "fallback retrieval-key rule missing"
grep -qF 'no-snapshot' "$EB" \
  && pass "express provenance = no-snapshot (closed enum untouched)" \
  || fail "express provenance rule missing"

PM="$P/references/paths.md"
grep -qF 'claims-ledger.json' "$PM" \
  && grep -qF 'derive-claims-ledger.sh' "$PM" \
  && pass "claims-ledger.json registered in paths.md (layout + per-skill row)" \
  || fail "paths.md registration missing"
# (v7.5.0 №D: the PostToolUse debounce probe died with the validator fan-out —
# the Stop-hook probe below is the surviving prune list.)
grep -qF 'claims-ledger.json' "$P/hooks/stop" \
  && pass "claims-ledger.json in the Stop-hook prune list" \
  || fail "Stop prune list missing claims-ledger.json"

# ══ verdict ═══════════════════════════════════════════════════════════════════
echo
if [ "$fails" -eq 0 ]; then
  echo "test-p1-claims-ledger-express: ALL PASS"
  exit 0
else
  echo "test-p1-claims-ledger-express: $fails FAILURE(S)"
  exit 1
fi
