#!/usr/bin/env bash
# test-derive-binding-json.sh — W-batch W2 (spec 2026-07-19-w-batch-script-derive.md):
# binding.json is DERIVED from binding.md by scripts/derive-binding-json.sh —
# never re-typed by the model. 10 cases:
#
#   1  round-trip: full-shape binding.md → exit 0; json-equality vs the
#      checked-in expected json (state_reason set + token stripped from anchor;
#      vault_source from the Confirmed list, null otherwise; resolution only on
#      the Claim-mapped claim; head/provenance from frontmatter; verbatim
#      '—'/'n/a' preserved); then validate-binding-json.sh on the derived pair
#      exits 0
#   2  CONFLICT-ADV-N resolved-heading variant derives resolution
#   3  unknown [reason: bogus] token → exit 2, json untouched
#   4  Anchor cell citing truncation with NO token → exit 2 (anti-dull)
#   5  RESOLVED block without Claim line → exit 2; Claim id absent from the
#      State Map → exit 2
#   6  5-cell row → exit 2 ('malformed State Map row'); duplicate id → exit 2
#   7  empty State Map table → exit 0 with claims: []; missing heading → exit 2
#   8  missing frontmatter → exit 0 with null head/provenance
#   9  resolve-oq simulation: derive → mark RESOLVED (+ Claim line) in md →
#      re-derive → resolution appears, head unchanged, pre-existing json
#      atomically replaced; unchanged content preserves generated_at
#      (idempotent, no churn)
#  10  no --vault → exit 3 (usage, matching validate-binding-json.sh)
#
# Run: bash plugins/mega-sdd/tests/graph/test-derive-binding-json.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DERIVE="${PLUGIN_ROOT}/scripts/derive-binding-json.sh"
VALIDATE="${PLUGIN_ROOT}/scripts/validate-binding-json.sh"
FX="${SCRIPT_DIR}/fixtures"
[ -f "$DERIVE" ] || { echo "missing $DERIVE"; exit 1; }

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w2derive)"
trap 'rm -rf "$WORK"' EXIT

json_eq_ignoring_stamp() {  # <derived> <expected> — equality with generated_at popped
  python3 - "$1" "$2" <<'PY'
import json, sys
a = json.load(open(sys.argv[1], encoding="utf-8"))
b = json.load(open(sys.argv[2], encoding="utf-8"))
a.pop("generated_at", None); b.pop("generated_at", None)
sys.exit(0 if a == b else 1)
PY
}

echo "== W2: derive-binding-json =="

# ── 1. round-trip vs checked-in expected json + parity on the derived pair ──
V1="$WORK/v1"; mkdir -p "$V1"
cp "$FX/derive-full/binding.md" "$V1/binding.md"
OUT=$( (cd "$WORK" && bash "$DERIVE" --vault v1 </dev/null 2>&1) ); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -qF "PASS: derived binding.json (5 claims)" \
  && ok "1: full-shape derive exits 0 (5 claims)" \
  || fail "1: derive rc=$RC out: $(echo "$OUT" | head -3)"
json_eq_ignoring_stamp "$V1/binding.json" "$FX/derive-full/expected-binding.json" \
  && ok "1: derived json equals checked-in expected (token stripped → state_reason; vault_source/resolution mapped; verbatim cells)" \
  || fail "1: derived json diverges from expected: $(cat "$V1/binding.json" 2>/dev/null | head -5)"
bash "$VALIDATE" --vault "$V1" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "1: validate-binding-json.sh exits 0 on the derived pair" \
  || fail "1: parity validator rejects the derived pair (rc=$RC)"

# ── 2. CONFLICT-ADV-N resolved-heading variant ──
V2="$WORK/v2"; mkdir -p "$V2"
cat > "$V2/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-003 | CONFLICT | UNKNOWN | app/Svc.php:9 | medium | n/a |

## Conflicts (1) — BLOCKING
### ✅ CONFLICT-ADV-1 RESOLVED (KEEP_CODE — vault patched) — advisor false CONFIRMED
- **Claim**: C-003
- **Verdict**: CONFLICT (BLOCKING)
MD
bash "$DERIVE" --vault "$V2" </dev/null >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$V2/binding.json'))
sys.exit(0 if d['claims'][0]['resolution'] == 'KEEP_CODE' else 1)
" && [ "$RC" -eq 0 ] && ok "2: CONFLICT-ADV-N resolved heading derives resolution KEEP_CODE" \
  || fail "2: ADV variant resolution missing (rc=$RC)"

# ── 3. unknown [reason:] token → exit 2, no json written ──
V3="$WORK/v3"; mkdir -p "$V3"
cat > "$V3/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | UNKNOWN | somewhere [reason: bogus] | low | n/a |
MD
OUT=$(bash "$DERIVE" --vault "$V3" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "unknown [reason: bogus]" && [ ! -f "$V3/binding.json" ] \
  && ok "3: unknown [reason:] token → exit 2, json NOT written" \
  || fail "3: unknown token handling wrong (rc=$RC): $(echo "$OUT" | head -2)"

# ── 4. anti-dull: truncation cited with NO token → exit 2 ──
V4="$WORK/v4"; mkdir -p "$V4"
cat > "$V4/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-044 | CONFIRMED | UNKNOWN | truncated §4 — absence is not evidence | low | n/a |
MD
OUT=$(bash "$DERIVE" --vault "$V4" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "cites truncation without a" && [ ! -f "$V4/binding.json" ] \
  && ok "4: 'truncat' anchor without token → exit 2 (S4 MUST machine-enforced)" \
  || fail "4: anti-dull check missing (rc=$RC): $(echo "$OUT" | head -2)"

# ── 5. RESOLVED without Claim line / Claim id not in State Map → exit 2 ──
V5A="$WORK/v5a"; mkdir -p "$V5A"
cat > "$V5A/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-002 | CONFLICT | UNKNOWN | a.php:1 | medium | n/a |

## Conflicts (1) — BLOCKING
### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT — code update pending) — mismatch
- **Verdict**: CONFLICT (BLOCKING)
MD
OUT=$(bash "$DERIVE" --vault "$V5A" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "no '- **Claim**: C-NNN' line" \
  && ok "5a: RESOLVED block without Claim line → exit 2 (remediation named)" \
  || fail "5a: Claim-line rule missing (rc=$RC): $(echo "$OUT" | head -2)"
V5B="$WORK/v5b"; mkdir -p "$V5B"
python3 - "$V5A/binding.md" "$V5B/binding.md" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("- **Verdict**", "- **Claim**: C-999\n- **Verdict**", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
OUT=$(bash "$DERIVE" --vault "$V5B" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "not present in the State Map" \
  && ok "5b: Claim id absent from the State Map → exit 2" \
  || fail "5b: unknown Claim id accepted (rc=$RC): $(echo "$OUT" | head -2)"

# ── 6. 5-cell row → exit 2 (contract error string); duplicate id → exit 2 ──
V6A="$WORK/v6a"; mkdir -p "$V6A"
cat > "$V6A/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
|---|---|---|---|---|---|
| C-002 | CONFIRMED | NEW | — | n/a |
MD
OUT=$(bash "$DERIVE" --vault "$V6A" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "malformed State Map row" \
  && ok "6a: 5-cell row → exit 2 with the shared-parser contract string" \
  || fail "6a: short-row contract lost (rc=$RC): $(echo "$OUT" | head -2)"
V6B="$WORK/v6b"; mkdir -p "$V6B"
cat > "$V6B/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (2)
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | a.php:1 | high | n/a |
| C-001 | CONFIRMED | NEW | — | n/a | n/a |
MD
OUT=$(bash "$DERIVE" --vault "$V6B" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "duplicate claim id" \
  && ok "6b: duplicate claim id → exit 2" \
  || fail "6b: duplicate id accepted (rc=$RC): $(echo "$OUT" | head -2)"

# ── 7. empty table → exit 0 claims:[]; missing heading → exit 2 ──
V7A="$WORK/v7a"; mkdir -p "$V7A"
cat > "$V7A/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (0)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
MD
bash "$DERIVE" --vault "$V7A" </dev/null >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$V7A/binding.json'))
sys.exit(0 if d['claims'] == [] else 1)
" && [ "$RC" -eq 0 ] && ok "7a: empty State Map table → exit 0, claims: []" \
  || fail "7a: empty-table handling wrong (rc=$RC)"
V7B="$WORK/v7b"; mkdir -p "$V7B"
printf '# Binding Manifest\n\nNo state map here.\n' > "$V7B/binding.md"
OUT=$(bash "$DERIVE" --vault "$V7B" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "missing '## Implementation State Map' heading" \
  && ok "7b: missing State Map heading → exit 2 (broken Step-4 write)" \
  || fail "7b: heading-less md accepted (rc=$RC): $(echo "$OUT" | head -2)"

# ── 8. missing frontmatter → exit 0 with null head/provenance (warn only) ──
V8="$WORK/v8"; mkdir -p "$V8"
cat > "$V8/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | a.php:1 | high | n/a |
MD
bash "$DERIVE" --vault "$V8" </dev/null >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$V8/binding.json'))
sys.exit(0 if d['head'] is None and d['codebase_map_provenance'] is None else 1)
" && [ "$RC" -eq 0 ] && ok "8: absent frontmatter → exit 0, head/provenance null" \
  || fail "8: frontmatter-less derive wrong (rc=$RC)"

# ── 9. resolve-oq simulation: re-derive after write-back + generated_at rules ──
V9="$WORK/v9"; mkdir -p "$V9"
cat > "$V9/binding.md" <<'MD'
---
vault: v9
binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: feedbeef1234
---
# Binding Manifest
## Implementation State Map (1)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-010 | CONFLICT | UNKNOWN | app/X.php:5 | medium | n/a |

## Conflicts (1) — BLOCKING
### CONFLICT-1 — X mismatch
- **Claim**: C-010
- **Verdict**: CONFLICT (BLOCKING)
MD
bash "$DERIVE" --vault "$V9" </dev/null >/dev/null 2>&1 || fail "9: initial derive failed"
STAMP1=$(python3 -c "import json; print(json.load(open('$V9/binding.json'))['generated_at'])")
# idempotent re-derive on unchanged md → byte-identical file (generated_at preserved)
SUM1=$(python3 -c "import hashlib; print(hashlib.sha256(open('$V9/binding.json','rb').read()).hexdigest())")
sleep 1
bash "$DERIVE" --vault "$V9" </dev/null >/dev/null 2>&1 || fail "9: idempotent re-derive failed"
SUM2=$(python3 -c "import hashlib; print(hashlib.sha256(open('$V9/binding.json','rb').read()).hexdigest())")
[ "$SUM1" = "$SUM2" ] && ok "9: unchanged content preserves generated_at (byte-identical re-derive, no churn)" \
  || fail "9: re-derive churned the file (generated_at restamped on identical content)"
# resolve-oq write-back: mark RESOLVED on the heading + Resolution line, re-derive
python3 - "$V9/binding.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("### CONFLICT-1 — X mismatch",
              "### ✅ CONFLICT-1 RESOLVED (DEFER) — X mismatch")
s = s.replace("- **Verdict**: CONFLICT (BLOCKING)",
              "- **Verdict**: CONFLICT (BLOCKING)\n- **Resolution**: ✅ RESOLVED (DEFER) 2026-07-19 — downgraded to OQ")
open(p, "w", encoding="utf-8").write(s)
PY
bash "$DERIVE" --vault "$V9" </dev/null >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$V9/binding.json'))
c = d['claims'][0]
sys.exit(0 if (c['resolution'] == 'DEFER' and d['head'] == 'feedbeef1234'
               and d['generated_at'] != '$STAMP1') else 1)
" && [ "$RC" -eq 0 ] && ok "9: re-derive after write-back → resolution appears, head unchanged, json replaced (fresh stamp)" \
  || fail "9: resolve-oq simulation wrong (rc=$RC): $(cat "$V9/binding.json" | head -8)"
[ -f "$V9/binding.json.tmp" ] && fail "9: tmp file left behind (non-atomic write)" \
  || ok "9: atomic replace (no tmp litter)"

# ── 10. usage: no --vault → exit 3 ──
bash "$DERIVE" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "10: missing --vault → exit 3 (matches validate-binding-json.sh convention)" \
  || fail "10: usage exit wrong (rc=$RC)"

if [ "$FAILED" -eq 0 ]; then echo "ALL W2 DERIVE OK"; exit 0; else echo "W2 derive FAILED"; exit 1; fi
