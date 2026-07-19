#!/usr/bin/env bash
# test-binding-recertify.sh — P0 v4.92.0: binding freshness RECERTIFY at the moat gate.
#
# The live hole (research/2026-07-19-v5-architecture-research.md §1): the moat
# validator read binding.md STRUCTURE only — a hand-authored/stale binding.md
# with no active CONFLICT heading yielded PASS and opened execute-bolts. The
# fix recertifies binding_metadata.head against git ground truth: commits in
# <head>..HEAD, intersected with the binding.json claims[] anchor paths —
# EXCLUDING unit-attributed commits (shared B1 unit_of() grammar): pipeline
# bolt commits touch anchored files BY DESIGN (extend units anchor existing
# code) and are governed by B1/B3; recertify guards the OUT-OF-PIPELINE lane.
# Verdict ladder pinned here (migration-safe — a v4 artifact is never REJECTED):
#   1. head == HEAD (fresh bind)                        → PASS, nothing recorded
#   2. UNIT-attributed commit touches an anchored file  → PASS (B1/B3 lane,
#      no blocker; advisory head-mismatch notice only)
#   3. MIXED history: unit commit + plain out-of-pipeline commit both touching
#      anchored files                                   → FAIL (the non-unit
#      commit makes it stale; keterangan names the file)
#   4. plain commit touches an UNRELATED file only      → PASS + advisory notice
#   5. plain commit touches an anchored file (pure)     → FAIL binding_stale_recertify
#   6. head absent (legacy v4 binding)                  → PASS + advisory head-absent
#   7. binding.json absent (head present)               → PASS + advisory json-absent
#   8. not a git repo                                   → PASS, check skipped silently
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/scripts/validate-handoff-binding-units.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
bad()  { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }

PROJ="${ROOT}/proj"
VAULT="${PROJ}/.mega-sdd/vaults/v1"
STATE="${PROJ}/.mega-sdd/.validation-blockers.json"
mkdir -p "${VAULT}/units" "${PROJ}/src/models" "${PROJ}/src/services"

# ── git fixture: a real repo with an anchored file + an unrelated file ──
printf '<?php class Product {}\n' > "${PROJ}/src/models/Product.php"
printf '<?php class Mailer {}\n'  > "${PROJ}/src/services/Mailer.php"
git -C "$PROJ" init -q
git -C "$PROJ" config user.email recertify@test
git -C "$PROJ" config user.name recertify
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "baseline"
HEAD0="$(git -C "$PROJ" rev-parse HEAD)"

# write_binding <head-value-or-empty>: clean binding (no conflicts) + one unit.
write_binding() {
  local headline=""
  [ -n "$1" ] && headline="binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: $1"
  cat > "${VAULT}/binding.md" <<EOF
---
vault: v1
codebase_map: .mega-sdd/codebase/codebase-map.md
bound_at: 2026-07-19T00:00:00Z
strict: false
${headline}
---

# Binding Manifest

## Summary
- claims_total: 1
- confirmed: 1
- conflict: 0
- oq: 0

## Confirmed Claims (1)
- C-001 | 03-data-model.md:7 | src/models/Product.php:1 | Product entity exists
EOF
}
write_binding_json() {
  cat > "${VAULT}/binding.json" <<'EOF'
{
  "schema_version": "1.0",
  "generated_by": "derive-binding-json@1.0.0",
  "claims": [
    {"id": "C-001", "verdict": "CONFIRMED", "state": "IMPLEMENTED",
     "anchor": "src/models/Product.php:1", "confidence": "high"},
    {"id": "C-002", "verdict": "CONFIRMED", "state": "UNKNOWN",
     "anchor": "dynamic route detected; heuristic cannot classify", "confidence": "low"}
  ]
}
EOF
}
cat > "${VAULT}/units/U-001.md" <<'EOF'
---
id: U-001
title: Product model
binding_refs: []
---
# U-001
EOF

echo "== binding RECERTIFY at the moat gate =="

# ── Case 1: fresh binding, head == HEAD → PASS, no recertify record ──
write_binding "$HEAD0"
write_binding_json
bash "$VALIDATOR" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1; code=$?
[ "$code" = "0" ] || bad "case 1: fresh binding (head==HEAD) must PASS, got exit $code"
grep -q '"binding_stale_recertify"' "$STATE" && bad "case 1: fresh binding must not record binding_stale_recertify"
grep -q '"binding_head_mismatch"' "$STATE" && bad "case 1: fresh binding must not record a head-mismatch notice"
[ "$FAILED" = "0" ] && ok "case 1: fresh binding (head==HEAD) PASSes cleanly"

# ── Case 2: UNIT-ATTRIBUTED commit touches the anchored file → PASS (B1/B3 lane) ──
printf '<?php class Product { public $sku; }\n' > "${PROJ}/src/models/Product.php"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "feat(U-001): legit bolt"
bash "$VALIDATOR" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1; code=$?
if [ "$code" = "0" ] && ! grep -q '"binding_stale_recertify"' "$STATE"; then
  ok "case 2: unit-attributed commit (feat(U-001):) touching an anchored file → PASS (governed by B1/B3, not recertify)"
else
  bad "case 2: expected PASS with no stale drop for a pipeline bolt commit (got exit $code)"; head -40 "$STATE"
fi
grep -q '"type": "binding_head_mismatch"' "$STATE" \
  && ok "case 2: advisory binding_head_mismatch notice recorded (HEAD moved, in-pipeline only)" \
  || bad "case 2: head-mismatch advisory notice missing"

# ── Case 3: MIXED history — unit commit + plain out-of-pipeline commit, both
#    touching anchored files → FAIL (the non-unit commit makes it stale) ──
printf '<?php class Product { public $sku; public $name; }\n' > "${PROJ}/src/models/Product.php"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "chore: manual hotfix"
bash "$VALIDATOR" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1; code=$?
if [ "$code" = "1" ] && grep -q '"type": "binding_stale_recertify"' "$STATE"; then
  ok "case 3: MIXED history → FAIL (the non-unit 'chore: manual hotfix' commit makes it stale)"
else
  bad "case 3: expected exit 1 + binding_stale_recertify on mixed history (got exit $code)"; head -40 "$STATE"
fi
grep -q '"status": "FAIL"' "$STATE" || bad "case 3: state file must record status FAIL (the gate reads it)"
grep -q "binding sudah basi terhadap file yang di-bind" "$STATE" || bad "case 3: Indonesian keterangan missing"
grep -q "mega-sdd:sync" "$STATE" || bad "case 3: keterangan must route to /mega-sdd:sync"
grep -q "src/models/Product.php" "$STATE" || bad "case 3: keterangan must NAME the changed anchored file"

# ── Case 4: re-bind (fresh head), then plain commit on an UNRELATED file → PASS + notice ──
HEAD1="$(git -C "$PROJ" rev-parse HEAD)"
write_binding "$HEAD1"
printf '<?php class Mailer { public $dsn; }\n' > "${PROJ}/src/services/Mailer.php"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "chore: touch unrelated file"
bash "$VALIDATOR" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1; code=$?
if [ "$code" = "0" ] && ! grep -q '"binding_stale_recertify"' "$STATE"; then
  ok "case 4: unrelated out-of-pipeline commit → PASS (no anchored file changed — no block)"
else
  bad "case 4: expected PASS with no stale drop (got exit $code)"; head -40 "$STATE"
fi
grep -q '"type": "binding_head_mismatch"' "$STATE" \
  && ok "case 4: advisory binding_head_mismatch notice recorded" \
  || bad "case 4: head-mismatch advisory notice missing"

# ── Case 5: plain out-of-pipeline commit touches the anchored file (pure) → FAIL ──
printf '<?php class Product { public $sku; public $name; public $price; }\n' > "${PROJ}/src/models/Product.php"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "fix: hand-edit anchored model"
bash "$VALIDATOR" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1; code=$?
if [ "$code" = "1" ] && grep -q '"type": "binding_stale_recertify"' "$STATE"; then
  ok "case 5: pure out-of-pipeline commit touching an anchored file → FAIL binding_stale_recertify"
else
  bad "case 5: expected exit 1 + binding_stale_recertify (got exit $code)"; head -40 "$STATE"
fi

# ── Case 6: legacy binding WITHOUT binding_metadata.head → PASS + advisory ──
write_binding ""
bash "$VALIDATOR" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1; code=$?
if [ "$code" = "0" ] && ! grep -q '"binding_stale_recertify"' "$STATE"; then
  ok "case 6: head-less legacy binding → PASS (v4 artifact never REJECTED)"
else
  bad "case 6: legacy lane must PASS (got exit $code)"; head -40 "$STATE"
fi
grep -q '"type": "binding_head_absent"' "$STATE" \
  && ok "case 6: advisory binding_head_absent notice recorded" \
  || bad "case 6: head-absent advisory notice missing"

# ── Case 7: head present (stale) but NO binding.json → PASS + advisory ──
write_binding "$HEAD1"
rm -f "${VAULT}/binding.json"
bash "$VALIDATOR" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1; code=$?
if [ "$code" = "0" ] && ! grep -q '"binding_stale_recertify"' "$STATE"; then
  ok "case 7: no binding.json → PASS (anchor set unavailable — advisory only)"
else
  bad "case 7: json-absent lane must PASS (got exit $code)"; head -40 "$STATE"
fi
grep -q '"type": "binding_json_absent"' "$STATE" \
  && ok "case 7: advisory binding_json_absent notice recorded" \
  || bad "case 7: json-absent advisory notice missing"

# ── Case 8: NOT a git repo → check skipped silently, PASS ──
PROJ2="${ROOT}/nogit"
mkdir -p "${PROJ2}/.mega-sdd/vaults/v1/units"
cp "${VAULT}/binding.md" "${PROJ2}/.mega-sdd/vaults/v1/binding.md"
cp "${VAULT}/units/U-001.md" "${PROJ2}/.mega-sdd/vaults/v1/units/U-001.md"
STATE2="${PROJ2}/.mega-sdd/.validation-blockers.json"
bash "$VALIDATOR" --cwd="$PROJ2" --quiet </dev/null >/dev/null 2>&1; code=$?
if [ "$code" = "0" ] && ! grep -q 'binding_stale_recertify\|binding_head_absent\|binding_head_mismatch\|binding_json_absent' "$STATE2"; then
  ok "case 8: non-git project → PASS, recertify skipped silently (tolerant)"
else
  bad "case 8: non-git lane must PASS with zero recertify records (got exit $code)"; head -40 "$STATE2"
fi

if [ "$FAILED" = "0" ]; then echo "ALL PASS"; exit 0; else echo "FAILED"; exit 1; fi
