#!/usr/bin/env bash
# test-vault-layout3-migration.sh — v8 P3 goal item 1: `migrate-paths --vault-layout=3`
# (layout-2 four-file vault → layout-3 `context.md`), proven on the clinic 7-file fixture
# taken through the layout-2 rung first (gate contract, mirrors the layout-2 test m1–m9):
#   m1  dry-run is the DEFAULT: prints the plan, mutates NOTHING
#   m2  apply: 4 docs → context.md with ONLY the layout-3 H2 contract (no leaked sibling H2)
#   m3  derive-vault-json AFTER == derive BEFORE on entities/flows/adrs/oqs; vault_layout 3
#   m4  the mandatory "full JIT re-bind required" message names rebind-units.sh --units=all
#   m5  the four docs + binding.md/json/claims-ledger are ARCHIVED (git mv) under
#       _meta/archive/layout2/ — nothing deleted
#   m6  binding.md is split per unit into bolts/U-XXX/binding-migrated.json by binding_refs
#       (claims + CONFLICT blocks + OQ refs) — and NEVER into the hook-guarded binding.json
#   m7  unit vault_source doc names rewritten to context.md (anchors untouched)
#   m8  idempotency: a second --vault-layout=3 run is a no-op
#   m9  dirty-tree refusal on --apply
#   m10 a legacy 7-file vault is refused with a pointer to the layout-2 rung
#   m11 migrate-paths.sh --vault-layout=3 is the front door (dispatches the rung per vault)
# Run: bash tests/migrate-paths/test-vault-layout3-migration.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO="$(cd "$HERE/../.." && pwd)"
S="$REPO/plugins/mega-sdd/scripts"; MP="$S/migrate-paths.sh"; M3="$S/migrate-vault-layout3.sh"; DV="$S/derive-vault-json.sh"
FIX="$HERE/fixtures/clinic-vault7"
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
P="$W/proj"; V="$P/.mega-sdd/vaults/clinic"; mkdir -p "$P/.mega-sdd/vaults"
cp -R "$FIX" "$V"; [ -f "$V/00-index.md" ] || { echo "fixture missing: $FIX" >&2; exit 2; }
G() { git -C "$P" -c user.email=t@t -c user.name=t "$@"; }
( cd "$P" && git init -q . ) && G add -A >/dev/null && G commit -qm seed

# ── m10: legacy 7-file vault refused by the layout-3 rung ──
OUT="$(bash "$M3" --vault="$V" --cwd="$P" 2>&1)"; RC=$?
[ $RC -eq 2 ] && echo "$OUT" | grep -q 'layout-2' && ok "m10: legacy 7-file vault → exit 2, points at the layout-2 rung" || bad "m10: rc=$RC $OUT"

# take the fixture to layout-2 with the existing rung, then seed one unit with binding_refs
( cd "$P" && bash "$MP" --vault-layout="$V" --apply >/dev/null 2>&1 ) || bad "precondition: layout-2 rung failed"
[ -f "$V/vault.md" ] || bad "precondition: vault.md missing after the layout-2 rung"
mkdir -p "$V/units"
cat > "$V/units/U-001.md" <<'MD'
---
id: U-001
title: t
task_type: extend
vault_source: model.md#patient
binding_refs:
  - C-001
  - CONFLICT-1
  - OQ-DM-1
target_files:
  - path: src/a.ts
    operation: modify
acceptance_test:
  - type: test
    command: x
    expects: "ok"
---
# u
MD
cat > "$V/binding.md" <<'MD'
# Binding Manifest

## Confirmed Claims (1)

| ID | Claim | Verdict |
|---|---|---|
| C-001 | patient entity exists | CONFIRMED |

## Conflicts (1) — BLOCKING

### ✅ CONFLICT-1 RESOLVED (KEEP_CODE) — slot rule differs

Resolution: KEEP_CODE by owner 2026-09-01.
MD
cat > "$V/binding.json" <<'JSON'
{"schema_version": "1.0", "head": "abc123", "claims": [{"id": "C-001", "verdict": "CONFIRMED", "state": "IMPLEMENTED", "state_reason": null, "anchor": "src/models/patient.ts:12", "confidence": "high", "field_diff": "n/a", "vault_source": "model.md:7", "resolution": null}]}
JSON
bash "$DV" --vault="$V" >/dev/null 2>&1 || bad "precondition: derive-vault-json (layout-2) failed"
BEFORE="$(python3 -c "import json;d=json.load(open('$V/vault.json'));print({k:len(d.get(k,[])) for k in ('entities','flows','adrs','open_questions')})")"
G add -A >/dev/null && G commit -qm "layout-2 + unit + binding" >/dev/null

# ── m1: dry-run default ──
OUT="$(bash "$M3" --vault="$V" --cwd="$P" 2>&1)"; RC=$?
[ $RC -eq 0 ] && echo "$OUT" | grep -q '\[dry-run\] write' && [ ! -f "$V/context.md" ] && [ -f "$V/vault.md" ] && [ -z "$(G status --porcelain)" ] \
  && ok "m1: dry-run is the default — plan printed, nothing written, tree clean" || bad "m1: rc=$RC tree=$(G status --porcelain | wc -l) $(echo "$OUT" | head -c 200)"
echo "$OUT" | grep -q 'Preview only' && ok "m1b: preview footer" || bad "m1b: no preview footer"

# ── m9: dirty-tree refusal on --apply ──
echo dirty >> "$V/units/U-001.md"
OUT="$(bash "$M3" --vault="$V" --cwd="$P" --apply 2>&1)"; RC=$?
[ $RC -eq 2 ] && echo "$OUT" | grep -q 'REFUSED' && [ ! -f "$V/context.md" ] && ok "m9: dirty tree → --apply refused (exit 2), nothing written" || bad "m9: rc=$RC $OUT"
G checkout -q -- "$V/units/U-001.md"

# ── m11 + m2: front door + apply ──
OUT="$( cd "$P" && bash "$MP" --vault-layout=3 --apply 2>&1 )"; RC=$?
[ $RC -eq 0 ] && [ -f "$V/context.md" ] && ok "m11: migrate-paths.sh --vault-layout=3 --apply dispatches the rung (context.md written)" || bad "m11: rc=$RC $(echo "$OUT" | tail -5)"
H2S="$(grep -E '^## ' "$V/context.md" | sed 's/^## //' | tr '\n' '|')"
python3 - "$H2S" <<'PY' && ok "m2: context.md carries ONLY layout-3 H2s (Flows/Data model/Constraints/Open Questions + Overview/Architecture/Decisions), no leaked layout-2 sibling H2" || bad "m2: H2s = $H2S"
import sys; h = [x for x in sys.argv[1].split("|") if x]
allowed = {"Overview", "Architecture", "Flows", "Data model", "Constraints", "Open Questions", "Decisions"}
assert set(h) <= allowed and {"Flows", "Data model", "Constraints", "Open Questions"} <= set(h), h
PY
grep -q '^vault_layout: 3' "$V/context.md" && ok "m2b: frontmatter vault_layout: 3" || bad "m2b: layout marker: $(head -5 "$V/context.md")"
grep -q '^\*\*Entities (DBML)\*\*\|^### \|```dbml' "$V/context.md" && ok "m2c: folded docs keep their content (grouping H2 → bold label, H3+ verbatim)" || bad "m2c: folded content shape"

# ── m3: derive parity ──
AFTER="$(python3 -c "import json;d=json.load(open('$V/vault.json'));print({k:len(d.get(k,[])) for k in ('entities','flows','adrs','open_questions')})")"
[ "$BEFORE" = "$AFTER" ] && ok "m3: derive-vault-json AFTER == BEFORE ($AFTER)" || bad "m3: before=$BEFORE after=$AFTER"
[ "$(python3 -c "import json;print(json.load(open('$V/vault.json')).get('vault_layout'))")" = "3" ] && ok "m3b: vault.json vault_layout 3" || bad "m3b: vault.json layout"

# ── m4: mandatory re-bind ──
echo "$OUT" | grep -q 'full JIT re-bind required' && echo "$OUT" | grep -q 'rebind-units.sh' && ok "m4: mandatory full JIT re-bind message names rebind-units.sh --units=all" || bad "m4: $(echo "$OUT" | tail -6)"

# ── m5: archive, nothing deleted ──
A="$V/_meta/archive/layout2"
for f in vault.md model.md flows.md constraints.md binding.md binding.json; do [ -f "$A/$f" ] || bad "m5: $f not archived"; [ -e "$V/$f" ] && bad "m5: $f still at the vault root"; done
G status --porcelain | grep -q '^R  .*binding.md -> .*archive/layout2/binding.md' && ok "m5: docs + binding archived via git mv (history kept)" || bad "m5: git status: $(G status --porcelain | head -3)"

# ── m6: per-unit split, never binding.json ──
BM="$V/bolts/U-001/binding-migrated.json"
[ -f "$BM" ] && python3 - "$BM" <<'PY' && ok "m6: bolts/U-001/binding-migrated.json carries the cited claim (with anchor), the CONFLICT block (with its RESOLUTION line) and the OQ ref" || bad "m6: $(cat "$BM" 2>/dev/null | head -c 300)"
import json, sys; d = json.load(open(sys.argv[1]))
assert d["schema"] == "unit-binding-migrated/1" and d["unit"] == "U-001"
assert [c["id"] for c in d["claims"]] == ["C-001"] and d["claims"][0]["anchor"] == "src/models/patient.ts:12"
assert d["conflicts"][0]["id"] == "CONFLICT-1" and "KEEP_CODE" in (d["conflicts"][0]["block"] or "")
assert d["oq_refs"] == ["OQ-DM-1"], d
PY
[ ! -e "$V/bolts/U-001/binding.json" ] && ok "m6b: the hook-guarded bolts/U-001/binding.json was NOT written by the migration (sole writer = write-unit-binding.sh)" || bad "m6b: migration wrote binding.json"

# ── m7: vault_source rewrite ──
grep -q '^vault_source: context.md#patient' "$V/units/U-001.md" && ok "m7: unit vault_source doc name rewritten model.md → context.md (anchor kept)" || bad "m7: $(grep vault_source "$V/units/U-001.md")"

# ── m8: idempotent ──
G add -A >/dev/null && G commit -qm migrated >/dev/null
OUT="$( cd "$P" && bash "$MP" --vault-layout=3 --apply 2>&1 )"; RC=$?
[ $RC -eq 0 ] && echo "$OUT" | grep -qi 'no-op\|already layout-3\|no layout-2 vaults' && [ -z "$(G status --porcelain)" ] && ok "m8: second run is a no-op" || bad "m8: rc=$RC $(echo "$OUT" | tail -3)"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
