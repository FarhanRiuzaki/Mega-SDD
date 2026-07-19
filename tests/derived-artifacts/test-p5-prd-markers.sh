#!/usr/bin/env bash
# test-p5-prd-markers.sh — P5 (v5 spec 2026-07-19-v5-execution-spec.md P5 row;
# research §4 "emit-prd"): marker preservation is a DETERMINISTIC check
# (scripts/check-prd-markers.sh), not a prose-trusted rule — [VERIFIED]/
# [INFERRED]/[OPEN] markers ride verbatim from KB claims into the PRD; an
# [INFERRED] claim presented as fact must FAIL.
#
#   1  KB claim [INFERRED] cited with marker carried verbatim → PASS
#   2  marker-stripped PRD line (same citation, no marker) → exit 1
#      MARKER_STRIPPED + keterangan
#   3  marker-UPGRADED line ([VERIFIED] where KB says [INFERRED]) → exit 1
#      MARKER_UPGRADED
#   4  file-level citation (no line anchor) into a marker-carrying KB file
#      with no marker on the PRD line → exit 1 MARKER_MISSING
#   5  fenced code blocks skipped (quoted terse notation is not a claim
#      surface — decision 4); no KB found → exit 0 note (forward mode)
#
# Run: bash tests/derived-artifacts/test-p5-prd-markers.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CHECK="${ROOT}/plugins/mega-sdd/scripts/check-prd-markers.sh"
[ -f "$CHECK" ] || { echo "missing $CHECK"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t p5prd)"
trap 'rm -rf "$WORK"' EXIT

PROJ="$WORK/proj"
KB="$PROJ/.mega-sdd/knowledge-base/10-domain"
mkdir -p "$KB" "$PROJ/.mega-sdd/prd"
cat > "$KB/approval.md" <<'MD'
# Approval domain

## Claims
- [VERIFIED] Leave request butuh approval manager [Source: legacy/src/Approval.php:10]
- [INFERRED] Approval berjalan dua level (maker-checker) [Source: legacy/src/Approval.php:44]
- [OPEN] Channel notifikasi approval belum diketahui
MD
# line numbers: the [INFERRED] claim is on L5, [VERIFIED] on L4

PRD="$PROJ/.mega-sdd/prd/PRD.md"
write_prd() { # $1 = variant
  case "$1" in
    clean) cat > "$PRD" <<'MD'
# PRD

## 3. Kebutuhan Fungsional

- [VERIFIED] Leave request butuh approval manager [Source: knowledge-base/10-domain/approval.md:L4 (sha256: pending)]
- [INFERRED] Approval berjalan dua level (maker-checker) [Source: knowledge-base/10-domain/approval.md:L5 (sha256: pending)]

```php
// quoted terse notation rides in a fence — not a claim surface
$levels = 2; // per approval.md
```
MD
      ;;
    stripped) cat > "$PRD" <<'MD'
# PRD

## 3. Kebutuhan Fungsional

- Approval berjalan dua level (maker-checker) [Source: knowledge-base/10-domain/approval.md:L5 (sha256: pending)]
MD
      ;;
    upgraded) cat > "$PRD" <<'MD'
# PRD

## 3. Kebutuhan Fungsional

- [VERIFIED] Approval berjalan dua level (maker-checker) [Source: knowledge-base/10-domain/approval.md:L5 (sha256: pending)]
MD
      ;;
    filelevel) cat > "$PRD" <<'MD'
# PRD

## 3. Kebutuhan Fungsional

- Approval berjalan dua level (maker-checker) [Source: knowledge-base/10-domain/approval.md (sha256: pending)]
MD
      ;;
  esac
}

note "== P5: check-prd-markers =="

# ── 1: marker carried verbatim → PASS ──
write_prd clean
OUT=$(bash "$CHECK" --prd="$PRD" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'clean' \
  && ok "1: [INFERRED] carried verbatim → PASS ($OUT)" || fail "1: rc=$RC out: $OUT"

# ── 2: marker stripped → FAIL ──
write_prd stripped
OUT=$(bash "$CHECK" --prd="$PRD" --cwd="$PROJ" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'MARKER_STRIPPED .*approval.md:L5 \[INFERRED\]' \
   && echo "$OUT" | grep -q 'KETERANGAN'; then
  ok "2: GATE FIRED — stripped marker → exit 1 MARKER_STRIPPED + keterangan"
else fail "2: rc=$RC out: $OUT"; fi

# ── 3: marker upgraded → FAIL ──
write_prd upgraded
OUT=$(bash "$CHECK" --prd="$PRD" --cwd="$PROJ" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'MARKER_STRIPPED' && echo "$OUT" | grep -q 'MARKER_UPGRADED .*PRD=\[VERIFIED\] KB=\[INFERRED\]'; then
  ok "3: GATE FIRED — [VERIFIED] where KB says [INFERRED] → MARKER_UPGRADED (+ stripped)"
else fail "3: rc=$RC out: $OUT"; fi

# ── 4: file-level citation, marker-carrying file, no marker on line → FAIL ──
write_prd filelevel
OUT=$(bash "$CHECK" --prd="$PRD" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'MARKER_MISSING' \
  && ok "4: file-level citation without any marker → MARKER_MISSING" \
  || fail "4: rc=$RC out: $OUT"

# ── 5: fence skip + no-KB lane ──
write_prd clean
OUT=$(bash "$CHECK" --prd="$PRD" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "5: fenced quoted notation never flagged (clean fixture carries a fence)" \
  || fail "5: fence handling rc=$RC out: $OUT"
NOKB="$WORK/nokb"; mkdir -p "$NOKB"
cp "$PRD" "$NOKB/PRD.md"
OUT=$(bash "$CHECK" --prd="$NOKB/PRD.md" --cwd="$NOKB" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'no knowledge base' \
  && ok "5: no KB → exit 0 with forward-mode note" || fail "5: no-KB lane rc=$RC out: $OUT"

if [ "$FAILED" -eq 0 ]; then note "PASS: P5 prd-markers suite"; exit 0
else note "FAIL: P5 prd-markers suite"; exit 1; fi
