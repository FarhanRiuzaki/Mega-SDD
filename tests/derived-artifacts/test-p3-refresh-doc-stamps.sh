#!/usr/bin/env bash
# test-p3-refresh-doc-stamps.sh — P3 (v5 spec P3 row; research §4 "Maturity +
# freshness"): refresh-doc-stamps.sh updates ONLY the script-owned doc-control
# state-stamp block in an emitted doc — every other byte untouched
# (stamp-binding-boilerplate.sh precedent: parser-invisible block).
#
#   1  first stamp: block inserted after frontmatter; STAMP-ONLY-CHANGE PIN —
#      removing the exact inserted block restores the original file
#      byte-identically (cmp on the masked copy)
#   2  idempotent: re-run with the same flags is a byte-identical no-op
#   3  refresh: only flag-passed fields change; generated_at preserved
#   4  parser-invisible: build-citation-map.sh entry set + stamps identical
#      across stamping; validate-fsd-slots.sh still PASSes
#   5  missing doc → exit 2; bad --doc → exit 2
#   6  P5 WIRING (was: P3 ships unwired): every emitter final step + the
#      orchestrate-flow chain boundary invoke the script
#
# Run: bash tests/derived-artifacts/test-p3-refresh-doc-stamps.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
REFRESH="${ROOT}/plugins/mega-sdd/scripts/refresh-doc-stamps.sh"
BUILD="${ROOT}/plugins/mega-sdd/scripts/build-citation-map.sh"
SLOTS="${ROOT}/plugins/mega-sdd/scripts/validate-fsd-slots.sh"
for f in "$REFRESH" "$BUILD" "$SLOTS"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t p3rds)"
trap 'rm -rf "$WORK"' EXIT

F="$WORK/proj"
V="$F/.mega-sdd/vaults/v1"
mkdir -p "$V/fsd"
printf '{"project_name":"p3-rds"}\n' > "$V/vault.json"
printf '# Overview\n\nPurpose.\n' > "$V/01-overview.md"
cat > "$V/fsd/FSD.md" <<'MD'
---
title: "RDS fixture — FSD"
mode: "pre-development"
---

# RDS fixture

**Mode:** Pre-development · **Source vault:** `.mega-sdd/vaults/v1` (sha256: `pending`)

## 1. Overview

Body.

**Sources for this section:**
- [¹] `vault/01-overview.md:L1-L3` (sha256: `pending`)
MD
DOC="$V/fsd/FSD.md"
cp "$DOC" "$WORK/original.md"

note "== P3: refresh-doc-stamps =="

# ── Pre-stamp citation build (baseline entry set for check 4) ──
bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null >/dev/null 2>&1 || { fail "pre: baseline build failed"; }
python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(json.dumps([ (e["fsd_section"],e["source_path"],e["source_sha256"]) for e in m["sections"] ]))' \
  "$V/fsd/.citation-map.json" > "$WORK/entries-before.json"
cp "$DOC" "$WORK/stamped-citations.md"   # FSD.md with real stamps, pre doc-control

# ── 1: first stamp + the stamp-only-change pin ──
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --position="units 0/3" --generated-at=2026-07-19T00:00:00Z </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q '^PASS: stamped fsd-doc-control' \
  && ok "1: first stamp exits 0 (block inserted)" || fail "1: rc=$RC out: $OUT"
grep -q '<!-- mega-sdd:doc-control' "$DOC" && grep -q 'maturity: pre-development' "$DOC" \
  && grep -q 'position: units 0/3' "$DOC" && grep -q 'generated_at: 2026-07-19T00:00:00Z' "$DOC" \
  && ok "1: block carries maturity + position + generated_at" || fail "1: block fields missing"
# Masked copy: strip the exact inserted substring (block + trailing blank line)
python3 - "$DOC" "$WORK/masked.md" <<'PY'
import re, sys
t = open(sys.argv[1], "rb").read().decode("utf-8", errors="surrogateescape")
m = re.sub(r"<!-- mega-sdd:doc-control\n.*?-->\n\n", "", t, count=1, flags=re.DOTALL)
open(sys.argv[2], "wb").write(m.encode("utf-8", errors="surrogateescape"))
PY
cmp -s "$WORK/masked.md" "$WORK/stamped-citations.md" \
  && ok "1: STAMP-ONLY-CHANGE PIN — masked copy byte-equals the pre-stamp file (every other byte identical)" \
  || fail "1: bytes outside the doc-control block changed"

# ── 2: idempotent no-op ──
B1=$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$DOC")
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --position="units 0/3" --generated-at=2026-07-19T00:00:00Z </dev/null 2>&1); RC=$?
B2=$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$DOC")
[ "$RC" -eq 0 ] && [ "$B1" = "$B2" ] && echo "$OUT" | grep -q 'idempotent no-op' \
  && ok "2: same-flags re-run is a byte-identical no-op" || fail "2: rc=$RC b1=$B1 b2=$B2 out: $OUT"

# ── 3: refresh updates ONLY flag-passed fields; generated_at preserved ──
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --maturity=post-development </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && grep -q 'maturity: post-development' "$DOC" && grep -q 'position: units 0/3' "$DOC" \
  && grep -q 'generated_at: 2026-07-19T00:00:00Z' "$DOC" \
  && ok "3: --maturity refresh; position + generated_at preserved" || fail "3: rc=$RC out: $OUT"
python3 - "$DOC" "$WORK/masked2.md" <<'PY'
import re, sys
t = open(sys.argv[1], "rb").read().decode("utf-8", errors="surrogateescape")
m = re.sub(r"<!-- mega-sdd:doc-control\n.*?-->\n\n", "", t, count=1, flags=re.DOTALL)
open(sys.argv[2], "wb").write(m.encode("utf-8", errors="surrogateescape"))
PY
cmp -s "$WORK/masked2.md" "$WORK/stamped-citations.md" \
  && ok "3: refresh touched no byte outside the block" || fail "3: refresh leaked outside the block"

# ── 4: parser-invisible — citation entry set + slot scan unchanged ──
bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null >/dev/null 2>&1; RC=$?
python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(json.dumps([ (e["fsd_section"],e["source_path"],e["source_sha256"]) for e in m["sections"] ]))' \
  "$V/fsd/.citation-map.json" > "$WORK/entries-after.json"
[ "$RC" -eq 0 ] && cmp -s "$WORK/entries-before.json" "$WORK/entries-after.json" \
  && ok "4: build-citation-map entry set identical across doc-control stamping (parser-invisible)" \
  || fail "4: rc=$RC — stamping changed the citation entry set"
bash "$SLOTS" --cwd="$F" --file-path="$DOC" --quiet </dev/null >/dev/null 2>&1 \
  && ok "4: validate-fsd-slots PASSes on the stamped doc (no slot markers introduced)" \
  || fail "4: validate-fsd-slots FAILed on the stamped doc"

# ── 5: usage lanes ──
bash "$REFRESH" --vault="$V" --doc=sit </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "5: missing doc (<vault>/sit/SIT.md) → exit 2" || fail "5: missing-doc rc=$RC (want 2)"
bash "$REFRESH" --vault="$V" --doc='FSD;rm' </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "5: malformed --doc → exit 2" || fail "5: malformed --doc rc=$RC (want 2)"

# ── 6: P5 wiring — emitters + orchestrate-flow chain boundary invoke it ──
# (P3 shipped the script UNWIRED and this check pinned that; P5 v4.97.0 wired
# it, so the pin flips: every doc-pack's final step AND the chain-boundary
# refresh in orchestrate-flow must name the script.)
WIRED=1
for w in skills/emit-fsd skills/emit-prd skills/emit-sit skills/orchestrate-flow; do
  grep -rq 'refresh-doc-stamps' "${ROOT}/plugins/mega-sdd/$w" 2>/dev/null || { WIRED=0; fail "6: $w lost the refresh-doc-stamps.sh wiring (P5)"; }
done
[ "$WIRED" -eq 1 ] && ok "6: P5 wiring live — emit-fsd/emit-prd/emit-sit + orchestrate-flow chain boundary invoke refresh-doc-stamps.sh"

if [ "$FAILED" -eq 0 ]; then note "PASS: P3 refresh-doc-stamps suite"; exit 0
else note "FAIL: P3 refresh-doc-stamps suite"; exit 1; fi
