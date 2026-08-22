#!/usr/bin/env bash
# test-vault-layout-migration.sh — v7 Fase 3 commit (c): the migrate-paths
# --vault-layout rung, proven on the clinic 7-file fixture (gate contract):
#   m1  dry-run is the DEFAULT: prints the plan, mutates NOTHING
#   m2  apply: 7 files -> 4 files (+ vault.json), old docs gone
#   m3  derive-vault-json AFTER == derive BEFORE (modulo doc/origin/layout/
#       category/timestamps — the layout-carried fields)
#   m4  the mandatory "full re-bind required" message is printed
#   m5  origin tokens stamped from the source doc (constraints-native = none)
#   m6  00-index residue moved (frontmatter lock + Glossary/Changelog/
#       Auto-Classification/Source documents sections), ceremony DROPPED+NAMED
#   m7  unit vault_source doc-name refs rewritten (03-data-model.md -> model.md)
#   m8  idempotency: a second --vault-layout run is a no-op
#   m9  dirty-tree refusal on --apply
# Run: bash tests/migrate-paths/test-vault-layout-migration.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
MP="$REPO/plugins/mega-sdd/scripts/migrate-paths.sh"
DV="$REPO/plugins/mega-sdd/scripts/derive-vault-json.sh"
FIX="$HERE/fixtures/clinic-vault7"

if [ -f "$REPO/plugins/mega-sdd/scripts/_lib/resolve-python.sh" ]; then
  # shellcheck disable=SC1091
  . "$REPO/plugins/mega-sdd/scripts/_lib/resolve-python.sh"
  if mega_sdd_python; then PY="$MEGA_SDD_PY"; else
    echo "SKIP: no usable python interpreter"; exit 0
  fi
fi

rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

W="$(mktemp -d 2>/dev/null || mktemp -d -t vlmig)"
trap 'rm -rf "$W"' EXIT

mkproj() {  # fresh git project with the clinic vault
  local p="$1"
  mkdir -p "$p/.mega-sdd/vaults"
  cp -R "$FIX" "$p/.mega-sdd/vaults/clinic"
  ( cd "$p" && git init -q . && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm init ) >/dev/null 2>&1
}

# ── m1: dry-run default ──────────────────────────────────────────────────────
P1="$W/p1"; mkproj "$P1"
OUT=$(bash "$MP" --vault-layout --cwd="$P1" </dev/null 2>&1); R=$?
[ "$R" -eq 0 ] && echo "$OUT" | grep -q 'dry-run' && echo "$OUT" | grep -q 'Preview only' \
  && pass "m1: dry-run is the default (plan printed)" || fail "m1: rc=$R"
[ -f "$P1/.mega-sdd/vaults/clinic/00-index.md" ] && [ ! -f "$P1/.mega-sdd/vaults/clinic/vault.md" ] \
  && pass "m1: nothing mutated under dry-run" || fail "m1: dry-run mutated the vault"
echo "$OUT" | grep -q 'DROPPED 00-index sections' \
  && pass "m6a: dropped ceremony NAMED in the plan" || fail "m6a: dropped sections not named"

# ── m2–m7: apply on a fresh project ─────────────────────────────────────────
P2="$W/p2"; mkproj "$P2"
V="$P2/.mega-sdd/vaults/clinic"
cp -R "$V" "$W/before"
bash "$DV" --vault="$W/before" </dev/null >/dev/null 2>&1 \
  || fail "setup: pre-migration derive failed"
OUT2=$(bash "$MP" --vault-layout --apply --cwd="$P2" </dev/null 2>&1); R2=$?
[ "$R2" -eq 0 ] && pass "m2: apply exit 0" || { fail "m2: apply rc=$R2"; echo "$OUT2" | tail -5; }
ok2=1
for f in vault.md model.md flows.md constraints.md vault.json; do
  [ -f "$V/$f" ] || { ok2=0; fail "m2: $f missing after apply"; }
done
for f in 00-index.md 01-overview.md 02-architecture.md 03-data-model.md 04-flows.md 05-decisions.md 06-constraints.md; do
  [ -f "$V/$f" ] && { ok2=0; fail "m2: legacy $f survived apply"; }
done
[ "$ok2" -eq 1 ] && pass "m2: 7 files -> 4 files + vault.json"

echo "$OUT2" | grep -q 'full re-bind required' \
  && pass "m4: mandatory full re-bind message printed" || fail "m4: re-bind message missing"

# m3: derive parity (before vs after, modulo layout-carried fields)
M3=$("$PY" - "$W/before/vault.json" "$V/vault.json" <<'EOF'
import json, sys
def norm(p):
    d = json.load(open(p))
    for k in ("generated_at", "vault_layout", "changelog", "sources"):
        d.pop(k, None)
    for cls in ("entities", "flows", "adrs", "open_questions"):
        for e in d.get(cls, []):
            for k in ("doc", "origin", "resolved_at", "deferred_at", "category"):
                e.pop(k, None)
    return d
a, b = norm(sys.argv[1]), norm(sys.argv[2])
if a == b:
    print("OK")
else:
    for k in set(a) | set(b):
        if a.get(k) != b.get(k):
            print("DIFF", k)
EOF
)
[ "$M3" = "OK" ] && pass "m3: derive after == derive before (modulo layout fields)" \
  || fail "m3: derive parity broken: $M3"

# m5: origin tokens
grep -q '\[origin: vault.md#Architecture\]' "$V/constraints.md" \
  && grep -q '\[origin: model.md\]' "$V/constraints.md" \
  && grep -q '\[origin: flows.md\]' "$V/constraints.md" \
  && pass "m5: origin tokens stamped from source docs" || fail "m5: origin stamps missing"
if grep -E 'OQ-CLINIC-00(1|6)[^ ]*\*\*.*\[origin:' "$V/constraints.md" >/dev/null; then
  fail "m5: constraints-native OQ wrongly stamped with an origin"
else
  pass "m5: constraints-native OQs carry NO origin"
fi

# m6: residue moved
head -20 "$V/vault.md" | grep -q '^vault_layout: 2' \
  && head -20 "$V/vault.md" | grep -q 'prd_status: "final"' \
  && pass "m6b: lock values -> YAML frontmatter (+ vault_layout: 2)" || fail "m6b: frontmatter lock missing"
for secname in '## Glossary' '## Changelog' '## Auto-Classification Review' '## Source documents'; do
  grep -q "^$secname" "$V/vault.md" || fail "m6c: residue section '$secname' not moved"
done
grep -q '^## Glossary' "$V/vault.md" && pass "m6c: residue sections moved into vault.md"
grep -q 'Reading order' "$V/vault.md" && fail "m6d: ceremony leaked into vault.md" \
  || pass "m6d: ceremony (reading order etc.) dropped"

# m7: unit doc-name rewrite
grep -q 'model.md §Entities' "$V/units/U-001.md" \
  && ! grep -q '03-data-model.md' "$V/units/U-001.md" \
  && pass "m7: unit vault_source doc names rewritten" || fail "m7: unit refs not rewritten"

# m8: idempotency
OUT8=$(bash "$MP" --vault-layout --cwd="$P2" </dev/null 2>&1); R8=$?
[ "$R8" -eq 0 ] && echo "$OUT8" | grep -q 'no legacy vaults' \
  && pass "m8: second run is a no-op" || fail "m8: not idempotent (rc=$R8)"

# m9: dirty-tree refusal on apply
P3="$W/p3"; mkproj "$P3"
echo dirty >> "$P3/.mega-sdd/vaults/clinic/01-overview.md"
OUT9=$(bash "$MP" --vault-layout --apply --cwd="$P3" </dev/null 2>&1); R9=$?
[ "$R9" -eq 2 ] && echo "$OUT9" | grep -q 'REFUSED' \
  && pass "m9: dirty tree refuses --apply (rc=2)" || fail "m9: dirty guard broken (rc=$R9)"
[ -f "$P3/.mega-sdd/vaults/clinic/00-index.md" ] \
  && pass "m9: refused run mutated nothing" || fail "m9: refused run mutated the vault"

echo
[ $rc -eq 0 ] && echo "ALL PASS (vault-layout migration)" || echo "FAILURES PRESENT"
exit $rc
