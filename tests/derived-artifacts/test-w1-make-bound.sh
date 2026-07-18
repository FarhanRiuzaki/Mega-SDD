#!/usr/bin/env bash
# test-w1-make-bound.sh — W-batch W1 (spec 2026-07-19-w-batch-script-derive.md):
# <vault>/bound/ is DERIVED by scripts/make-bound.sh from the vault docs +
# binding.json — never re-typed by the model. Fixture is parity-TRUE by
# construction: binding.md authored in the W2 grammar, binding.json derived via
# scripts/derive-binding-json.sh. Cases:
#
#   a  clean bind → exit 0 with the exact one-line summary; bound/ contains
#      exactly the copied 0x docs + the binding.md mirror; mirror + unannotated
#      doc byte-identical (cmp); annotated docs identical to sources once the
#      inserted '<!-- BIND: ' lines are removed
#   b  annotation content + placement exact: merged same-line comment
#      '<!-- BIND: confirmed=C-001, confirmed=C-002 -->' directly after the
#      ORIGINAL cited line; second doc annotated; descending-insert correctness
#      (the later cited line's content stays directly above its comment)
#   c  skipped counting pinned in the PASS line — K=3 (section-style +
#      out-of-bounds + null vault_source all count as skipped)
#   d  any CONFLICT verdict → exit 2 naming the claim id; pre-existing bound/
#      left byte-identical; no .bound.tmp.* litter
#   e  --strict + an OQ verdict → exit 2, fs untouched; without --strict the
#      OQ row is annotated in claim-id form 'oq=C-0NN' (not OQ-NN)
#   f  idempotent: second clean run → bound/ byte-identical (diff -r)
#   g  parity-broken pair (hand-edited binding.json verdict) → non-zero
#      passthrough from validate-binding-json.sh, fs untouched
#   h  missing binding.json → exit 3; missing --vault → exit 3
#
# Run: bash tests/derived-artifacts/test-w1-make-bound.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
MB="${P}/scripts/make-bound.sh"
DERIVE="${P}/scripts/derive-binding-json.sh"
for f in "$MB" "$DERIVE"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w1bound)"
trap 'rm -rf "$WORK"' EXIT

no_litter() {  # <vault> — no .bound.tmp.* temp dirs left behind
  [ "$(find "$1" -maxdepth 1 -name '.bound.tmp.*' | wc -l | tr -d ' ')" = "0" ]
}

mk_fixture() {  # <dir> — parity-true clean fixture (7 claims, 3 docs)
  mkdir -p "$1"
  printf '{"vault": "fixture"}\n' > "$1/vault.json"
  printf 'line1\nline2\nline3\n' > "$1/00-index.md"
  printf 'l1\nl2\nl3\nl4\nl5 entity Product\nl6\nl7 oq target\n' > "$1/03-data-model.md"
  printf 'f1\nf2\nf3 endpoint\nf4\n' > "$1/04-flows.md"
  cat > "$1/binding.md" <<'MD'
---
vault: fixture
binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: abc123def456
---
# Binding Manifest

## Confirmed Claims
- C-001 | 03-data-model.md:5 | app/Models/Product.php:1 | Product entity exists
- C-002 | 03-data-model.md:5 | app/Models/Product.php:9 | Product has sku
- C-003 | 04-flows.md:3 | routes/api.php:12 | endpoint registered
- C-004 | 03-data-model.md:7 | — | legacy user table unknown
- C-005 | 03-data-model.md §Product | app/Models/Product.php | section-style cite
- C-006 | 03-data-model.md:999 | app/X.php:1 | out-of-bounds cite

## Implementation State Map (7)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | app/Models/Product.php:1 | high | (exact match) |
| C-002 | CONFIRMED | IMPLEMENTED | app/Models/Product.php:9 | high | n/a |
| C-003 | CONFIRMED | IMPLEMENTED | routes/api.php:12 | high | n/a |
| C-004 | OQ | NEW | — | n/a | n/a |
| C-005 | CONFIRMED | IMPLEMENTED | app/Models/Product.php | medium | n/a |
| C-006 | CONFIRMED | UNKNOWN | ambiguous [reason: ambiguous_match] | low | n/a |
| C-007 | CONFIRMED | IMPLEMENTED | app/Y.php:3 | high | n/a |

## Conflicts (0)

## Open Questions (1)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | legacy user table? | 03-data-model.md:7 | N/A (fresh OQ) |
MD
  bash "$DERIVE" --vault "$1" </dev/null >/dev/null 2>&1 || { echo "fixture derive failed"; exit 1; }
}

echo "== W1: make-bound derives bound/ =="

# ── a. clean derive: exact summary + copy-set + byte-identity ──
V="$WORK/v"; mk_fixture "$V"
OUT=$(bash "$MB" --vault "$V" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$OUT" = "PASS: bound/ derived (3 docs, 4 annotations, 3 skipped)" ] \
  && ok "a: clean bind → exit 0 with the exact one-line summary" \
  || fail "a: rc=$RC out: $OUT"
LISTING=$(ls "$V/bound" | sort | tr '\n' ' ')
[ "$LISTING" = "00-index.md 03-data-model.md 04-flows.md binding.md " ] \
  && ok "a: bound/ contains exactly the copied docs + the binding.md mirror" \
  || fail "a: bound/ listing wrong: $LISTING"
cmp -s "$V/bound/binding.md" "$V/binding.md" \
  && ok "a: bound/binding.md mirror byte-identical (cmp)" \
  || fail "a: mirror diverges from vault-root binding.md"
cmp -s "$V/bound/00-index.md" "$V/00-index.md" \
  && ok "a: unannotated doc byte-identical to source" \
  || fail "a: unannotated 00-index.md not byte-identical"
for d in 03-data-model.md 04-flows.md; do
  grep -v '^<!-- BIND: ' "$V/bound/$d" > "$WORK/strip.$d"
  cmp -s "$WORK/strip.$d" "$V/$d" \
    && ok "a: $d identical to source once BIND comment lines are removed" \
    || fail "a: $d differs from source beyond the inserted BIND lines"
done

# ── b. annotation content + placement exact ──
[ "$(sed -n '6p' "$V/bound/03-data-model.md")" = '<!-- BIND: confirmed=C-001, confirmed=C-002 -->' ] \
  && ok "b: merged same-line comment exact (comma-joined, binding.json order) after original line 5" \
  || fail "b: merged comment wrong: $(sed -n '6p' "$V/bound/03-data-model.md")"
[ "$(sed -n '5p' "$V/bound/03-data-model.md")" = 'l5 entity Product' ] \
  && [ "$(sed -n '8p' "$V/bound/03-data-model.md")" = 'l7 oq target' ] \
  && ok "b: descending insert — both cited lines stay directly above their comments" \
  || fail "b: cited-line placement shifted"
[ "$(sed -n '4p' "$V/bound/04-flows.md")" = '<!-- BIND: confirmed=C-003 -->' ] \
  && ok "b: second doc annotated after its cited line" \
  || fail "b: 04-flows.md annotation wrong: $(sed -n '4p' "$V/bound/04-flows.md")"

# ── c. skipped counting (section-style + out-of-bounds + null = 3) ──
echo "$OUT" | grep -qF "3 skipped" \
  && ok "c: PASS line pins K=3 (section-style + out-of-bounds + null vault_source)" \
  || fail "c: skip count wrong in: $OUT"

# ── e2 (order matters: strict refusal against the bound/ produced in a) ──
cp -R "$V/bound" "$WORK/snap-strict"
OUT=$(bash "$MB" --vault "$V" --strict </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "C-004" \
  && ok "e: --strict + OQ verdict → exit 2 naming the claim id" \
  || fail "e: strict refusal wrong (rc=$RC): $OUT"
diff -r "$WORK/snap-strict" "$V/bound" >/dev/null 2>&1 && no_litter "$V" \
  && ok "e: strict refusal touches nothing (bound/ intact, no temp litter)" \
  || fail "e: strict refusal modified the filesystem"
grep -qF '<!-- BIND: oq=C-004 -->' "$V/bound/03-data-model.md" \
  && ok "e: without --strict the OQ row is annotated oq=C-004 (claim-id form, not OQ-NN)" \
  || fail "e: oq annotation missing/wrong form"

# ── f. idempotent: second clean run → byte-identical bound/ ──
cp -R "$V/bound" "$WORK/snap-idem"
bash "$MB" --vault="$V" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && diff -r "$WORK/snap-idem" "$V/bound" >/dev/null 2>&1 \
  && ok "f: second clean run → bound/ byte-identical (diff -r; --vault= form accepted)" \
  || fail "f: re-run not idempotent (rc=$RC)"

# ── d. CONFLICT verdict → exit 2, fs untouched ──
VC="$WORK/vc"; cp -R "$V" "$VC"
python3 - "$VC/binding.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("| C-007 | CONFIRMED | IMPLEMENTED | app/Y.php:3 | high | n/a |",
              "| C-007 | CONFLICT | UNKNOWN | app/Y.php:3 | high | n/a |")
s = s.replace("## Conflicts (0)", """## Conflicts (1) — BLOCKING
### CONFLICT-1 — Y mismatch
- **Claim**: C-007
- **Verdict**: CONFLICT (BLOCKING)""")
open(p, "w", encoding="utf-8").write(s)
PY
bash "$DERIVE" --vault "$VC" </dev/null >/dev/null 2>&1 || fail "d: re-derive after CONFLICT edit failed"
cp -R "$VC/bound" "$WORK/snap-conflict"
OUT=$(bash "$MB" --vault "$VC" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "C-007" \
  && ok "d: CONFLICT verdict → exit 2 naming the conflicting claim id" \
  || fail "d: conflict refusal wrong (rc=$RC): $OUT"
diff -r "$WORK/snap-conflict" "$VC/bound" >/dev/null 2>&1 && no_litter "$VC" \
  && ok "d: refusal leaves the pre-existing bound/ byte-identical, no temp litter" \
  || fail "d: refusal touched the filesystem"

# ── g. parity-broken pair → non-zero passthrough, fs untouched ──
VP="$WORK/vp"; cp -R "$V" "$VP"
python3 - "$VP/binding.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["claims"][0]["verdict"] = "OQ"   # md still says CONFIRMED → parity FAIL
json.dump(d, open(p, "w", encoding="utf-8"), indent=2)
PY
cp -R "$VP/bound" "$WORK/snap-parity"
OUT=$(bash "$MB" --vault "$VP" </dev/null 2>&1); RC=$?
[ "$RC" -ne 0 ] && echo "$OUT" | grep -qF "parity" \
  && ok "g: parity-broken pair → non-zero passthrough (rc=$RC) with the parity FAIL detail" \
  || fail "g: parity gate not enforced (rc=$RC): $OUT"
diff -r "$WORK/snap-parity" "$VP/bound" >/dev/null 2>&1 && no_litter "$VP" \
  && ok "g: parity failure touches nothing on disk" \
  || fail "g: parity failure modified the filesystem"

# ── h. missing binding.json → exit 3; missing --vault → exit 3 ──
VM="$WORK/vm"; mkdir -p "$VM"
cp "$V/vault.json" "$V/00-index.md" "$V/binding.md" "$VM/"
bash "$MB" --vault "$VM" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "h: missing binding.json → exit 3" \
  || fail "h: missing binding.json rc=$RC (want 3)"
bash "$MB" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "h: missing --vault → exit 3 (usage)" \
  || fail "h: usage rc=$RC (want 3)"

if [ "$FAILED" -eq 0 ]; then echo "ALL W1 MAKE-BOUND OK"; exit 0; else echo "W1 make-bound FAILED"; exit 1; fi
