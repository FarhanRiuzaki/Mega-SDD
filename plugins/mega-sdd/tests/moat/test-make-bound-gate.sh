#!/usr/bin/env bash
# test-make-bound-gate.sh — pins the W1 gate posture: <vault>/bound/ is
# produced ONLY by scripts/make-bound.sh (bind Step 5), which independently
# REFUSES while any CONFLICT verdict is in binding.json — converting the
# Step-5 prose gate into script enforcement (gates>rules doctrine). Prose pins
# guard the SKILL/contract wording against culls; the empirical section proves
# the refusal on a live mini-fixture; the pre-existing sync-conflict pin suite
# must survive W1 unmodified.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../.."
rc=0

pin() {  # pin <file> <required-pattern> <label>
  if grep -qiE "$2" "$PLUGIN/$1" 2>/dev/null; then
    echo "PASS ($3)"
  else
    echo "FAIL ($3 — pattern missing in $1)"; rc=1
  fi
}

# ── prose pins ──
pin "skills/bind-codebase/SKILL.md" \
    "make-bound\.sh" \
    "SKILL Step 5 runs make-bound.sh"
pin "skills/bind-codebase/SKILL.md" \
    "NEVER hand-write" \
    "SKILL forbids hand-writing bound/"
pin "skills/bind-codebase/references/binding-contract.md" \
    "no \`bound/\` while any conflict" \
    "contract: pinned conflict-gate phrase survives W1"
pin "skills/bind-codebase/references/binding-contract.md" \
    "make-bound\.sh" \
    "contract documents make-bound.sh as the bound/ producer"

# ── empirical: CONFLICT verdict → exit 2; pre-existing bound/ untouched ──
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t mbgate)"
trap 'rm -rf "$WORK"' EXIT
V="$WORK/v"; mkdir -p "$V"
printf '{"vault": "mini"}\n' > "$V/vault.json"
printf 'a1\na2\n' > "$V/00-index.md"
printf 'd1\nd2\nd3\n' > "$V/03-data-model.md"
cat > "$V/binding.md" <<'MD'
# Binding Manifest

## Confirmed Claims
- C-001 | 03-data-model.md:2 | app/Svc.php:9 | claim text

## Implementation State Map (2)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | app/Svc.php:9 | high | n/a |
| C-002 | CONFLICT | UNKNOWN | app/Svc.php:20 | medium | n/a |

## Conflicts (1) — BLOCKING
### CONFLICT-1 — Svc mismatch
- **Claim**: C-002
- **Verdict**: CONFLICT (BLOCKING)
MD
bash "$PLUGIN/scripts/derive-binding-json.sh" --vault "$V" </dev/null >/dev/null 2>&1 \
  || { echo "FAIL (fixture derive-binding-json failed)"; rc=1; }
# pre-seed a previously-clean bound/ (stale-bound semantics: refusal keeps it)
mkdir -p "$V/bound"
cp "$V/00-index.md" "$V/03-data-model.md" "$V/binding.md" "$V/bound/"
SUM_BEFORE=$( (cd "$V/bound" && cat 00-index.md 03-data-model.md binding.md) | cksum )

OUT=$(bash "$PLUGIN/scripts/make-bound.sh" --vault "$V" </dev/null 2>&1); MRC=$?
if [ "$MRC" -eq 2 ] && echo "$OUT" | grep -qF "C-002"; then
  echo "PASS (empirical: CONFLICT verdict refuses with exit 2, names C-002)"
else
  echo "FAIL (empirical refusal — rc=$MRC out: $OUT)"; rc=1
fi
SUM_AFTER=$( (cd "$V/bound" && cat 00-index.md 03-data-model.md binding.md) | cksum )
N_TMP=$(find "$V" -maxdepth 1 -name '.bound.tmp.*' | wc -l | tr -d ' ')
if [ "$SUM_BEFORE" = "$SUM_AFTER" ] && [ "$N_TMP" = "0" ]; then
  echo "PASS (empirical: refusal leaves the pre-existing clean bound/ untouched, no temp litter)"
else
  echo "FAIL (empirical: refusal modified bound/ or littered temp dirs)"; rc=1
fi

# ── the pre-existing conflict-pin suite must stay green under W1 ──
if bash "$HERE/test-sync-conflict-revalidate.sh" </dev/null >/dev/null 2>&1; then
  echo "PASS (test-sync-conflict-revalidate.sh still exits 0)"
else
  echo "FAIL (test-sync-conflict-revalidate.sh broken by W1)"; rc=1
fi

[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
