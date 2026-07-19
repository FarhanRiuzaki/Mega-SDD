#!/usr/bin/env bash
# test-p3-emission-parity.sh — P3 emission engine (v5 spec
# docs/superpowers/specs/2026-07-19-v5-execution-spec.md P3 row; research §4):
# THE BYTE-PARITY PHASE GATE. The --doc parameterization of
# build-citation-map.sh / check-citation-drift.sh is a PURE parameterization —
# the FSD lane is byte-identical with the flag absent and with --doc=fsd
# (invariant-3 machinery; the fixture flow mirrors the pre-P3 baseline capture).
#
#   1  full flow WITHOUT --doc: fabricated citation → exit 1 + UNRESOLVED;
#      clean build exits 0 with ONE stdout line; stamps become real 12-hex;
#      idempotent re-run; DRIFT / GONE / NO_PRIOR / PRIOR_UNREADABLE grammar
#   2  full flow WITH --doc=fsd: EVERY capture (stdout+rc, FSD.md bytes
#      post-stamp, .citation-map.json minus emitted_at, every drift output)
#      byte-equals the no-flag run
#   3  P5 seam: --doc=prd against <vault>/prd/PRD.md writes
#      <vault>/prd/.citation-map.json + stamps; drift --doc=prd reads it;
#      missing doc dir → exit 2
#   4  validate-fsd-slots.sh stays byte-untouched by P3 generalization
#      (its PostToolUse contract keys on fsd paths — P5 seam, engine doc §P5)
#
# Run: bash tests/derived-artifacts/test-p3-emission-parity.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="${ROOT}/plugins/mega-sdd/scripts/build-citation-map.sh"
DRIFT="${ROOT}/plugins/mega-sdd/scripts/check-citation-drift.sh"
ENGINE="${ROOT}/plugins/mega-sdd/references/emission-engine.md"
SLOTS="${ROOT}/plugins/mega-sdd/scripts/validate-fsd-slots.sh"
for f in "$BUILD" "$DRIFT" "$ENGINE" "$SLOTS"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t p3par)"
trap 'rm -rf "$WORK"' EXIT

sha_of() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

# ── Fixture factory: identical deterministic bytes per run ──
mk_fixture() { # $1 = project dir
  local F="$1" V="$1/.mega-sdd/vaults/v1"
  mkdir -p "$V/fsd" "$V/units" "$F/.mega-sdd/codebase"
  printf '{"project_name":"p3-parity","vault_version":"1.0"}\n' > "$V/vault.json"
  printf '# Overview\n\nPurpose: fixture.\nScope: small.\n' > "$V/01-overview.md"
  printf '## FR-007 Fixture requirement\n\nBody of FR-007.\n' > "$V/02-functional.md"
  printf -- '---\nunit_id: U-001\n---\n# U-001\n' > "$V/units/U-001.md"
  printf '# Codebase map\n\n## Entities\n' > "$F/.mega-sdd/codebase/codebase-map.md"
  cat > "$V/fsd/FSD.md" <<'MD'
---
title: "P3 parity fixture — FSD"
mode: "pre-development"
---

# P3 parity fixture

## Functional Specification Document

**Version:** 1.0 · **Date:** 2026-07-19 · **Classification:** Internal
**Mode:** Pre-development · **Source vault:** `.mega-sdd/vaults/v1` (sha256: `pending`)

---

## 1. Overview

Fixture overview content.

[Pending — vault/03-open-questions.md not yet generated]

**Sources for this section:**
- [¹] `vault/01-overview.md:L1-L4` (sha256: `pending`)

## 5. Functional Requirements

#### FR-007 — Fixture requirement

Fixture body.

[Source: vault/02-functional.md:L1-L3 (sha256: pending)]

[Source: vault/nonexistent-source.md (sha256: pending)]

**Sources for this section:**
- [¹] `vault/02-functional.md:L1-L3` (sha256: `pending`)
- [²] `units/U-001.md` (sha256: `pending`)
- [³] `codebase-map.md` (sha256: `pending`)

```markdown
Fence example stays untouched: (sha256: `pending`)
```
MD
}

snap_map() { # $1 = map path — strip ONLY the volatile emitted_at timestamp
  python3 - "$1" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
m.pop("emitted_at", None)
print(json.dumps(m, indent=2, sort_keys=False))
PY
}

# ── run_flow <fixture-dir> <capture-dir> [extra flags] — the FULL flow ──
run_flow() {
  local F="$1" CAP="$2" EXTRA="${3:-}" V="$1/.mega-sdd/vaults/v1" out rc
  local MAP="$V/fsd/.citation-map.json"
  mkdir -p "$CAP"
  # 01 fabricated citation → exit 1 UNRESOLVED; map still written
  out=$(bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/01-stdout.txt"; cp "$V/fsd/FSD.md" "$CAP/01-FSD.md"; snap_map "$MAP" > "$CAP/01-map.json"
  # 02 remove the fabricated line → clean build
  grep -v 'nonexistent-source' "$V/fsd/FSD.md" > "$V/fsd/FSD.md.tmp" && mv "$V/fsd/FSD.md.tmp" "$V/fsd/FSD.md"
  out=$(bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/02-stdout.txt"; cp "$V/fsd/FSD.md" "$CAP/02-FSD.md"; snap_map "$MAP" > "$CAP/02-map.json"
  # 03 idempotency re-run
  out=$(bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/03-stdout.txt"; cp "$V/fsd/FSD.md" "$CAP/03-FSD.md"
  # 04 drift clean (no output)
  out=$(bash "$DRIFT" --vault="$V" --cwd="$F" $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/04-drift.txt"
  # 05 source drifted
  printf 'drifted line\n' >> "$V/02-functional.md"
  out=$(bash "$DRIFT" --vault="$V" --cwd="$F" $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/05-drift.txt"
  # 06 source deleted → GONE (then restore)
  cp "$V/units/U-001.md" "$CAP/.u001.bak"; rm "$V/units/U-001.md"
  out=$(bash "$DRIFT" --vault="$V" --cwd="$F" $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/06-drift.txt"; mv "$CAP/.u001.bak" "$V/units/U-001.md"
  # 07 no map → NO_PRIOR; corrupt map → PRIOR_UNREADABLE
  mv "$MAP" "$MAP.bak"
  out=$(bash "$DRIFT" --vault="$V" --cwd="$F" $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/07-drift.txt"
  printf '{broken json\n' > "$MAP"
  out=$(bash "$DRIFT" --vault="$V" --cwd="$F" $EXTRA </dev/null 2>&1); rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out" > "$CAP/08-drift.txt"
  mv "$MAP.bak" "$MAP"
}

note "== P3: emission-engine byte-parity =="

# ── 1: invariant properties on the no-flag run ──
F1="$WORK/proj-noflag"; mk_fixture "$F1"; run_flow "$F1" "$WORK/cap-noflag" ""
grep -q '^rc=1$' "$WORK/cap-noflag/01-stdout.txt" && grep -q 'UNRESOLVED .* vault/nonexistent-source.md' "$WORK/cap-noflag/01-stdout.txt" \
  && ok "1: fabricated citation → exit 1 + UNRESOLVED names the path" \
  || fail "1: unresolved lane wrong: $(head -3 "$WORK/cap-noflag/01-stdout.txt")"
grep -q '^rc=0$' "$WORK/cap-noflag/02-stdout.txt" && [ "$(grep -c . "$WORK/cap-noflag/02-stdout.txt")" -eq 2 ] \
  && ok "1: clean build exits 0 with ONE stdout line (quiet-gates diet)" \
  || fail "1: clean build output: $(cat "$WORK/cap-noflag/02-stdout.txt")"
grep -qE '\(sha256: `?[0-9a-f]{12}' "$WORK/cap-noflag/02-FSD.md" && ! grep -q 'nonexistent' "$WORK/cap-noflag/02-FSD.md" \
  && ok "1: stamps are real 12-hex after the clean build" \
  || fail "1: stamped FSD.md wrong"
cmp -s "$WORK/cap-noflag/02-FSD.md" "$WORK/cap-noflag/03-FSD.md" \
  && ok "1: idempotent — re-run leaves FSD.md byte-identical" \
  || fail "1: second run mutated FSD.md"
grep -q '^DRIFT 5 vault/02-functional.md [0-9a-f]\{12\} [0-9a-f]\{12\}$' "$WORK/cap-noflag/05-drift.txt" \
  && ok "1: DRIFT grammar (section + path + old12 + new12)" || fail "1: DRIFT line wrong: $(cat "$WORK/cap-noflag/05-drift.txt")"
grep -q '^GONE 5 units/U-001.md [0-9a-f]\{12\}$' "$WORK/cap-noflag/06-drift.txt" \
  && ok "1: GONE grammar" || fail "1: GONE line wrong: $(cat "$WORK/cap-noflag/06-drift.txt")"
grep -q '^NO_PRIOR$' "$WORK/cap-noflag/07-drift.txt" && grep -q '^PRIOR_UNREADABLE$' "$WORK/cap-noflag/08-drift.txt" \
  && ok "1: NO_PRIOR + PRIOR_UNREADABLE lanes" || fail "1: prior-map lanes wrong"

# ── 2: --doc=fsd byte-equals the no-flag run (THE PARITY PIN) ──
F2="$WORK/proj-docfsd"; mk_fixture "$F2"; run_flow "$F2" "$WORK/cap-docfsd" "--doc=fsd"
if diff -r "$WORK/cap-noflag" "$WORK/cap-docfsd" >/dev/null 2>&1; then
  ok "2: EVERY capture byte-identical with --doc=fsd (stdout+rc, FSD.md post-stamp, map minus emitted_at, all drift outputs)"
else
  fail "2: --doc=fsd diverged from the no-flag run:"; diff -r "$WORK/cap-noflag" "$WORK/cap-docfsd" | head -20
fi

# ── 3: the P5 seam — --doc=prd lane works; missing doc dir → exit 2 ──
F3="$WORK/proj-prd"; V3="$F3/.mega-sdd/vaults/v1"
mkdir -p "$V3/prd"; printf '{"project_name":"p3-prd"}\n' > "$V3/vault.json"
printf '# Overview seed\n' > "$V3/01-overview.md"
printf '# PRD\n\n## 1. Overview\n\nBody. [Source: vault/01-overview.md (sha256: pending)]\n' > "$V3/prd/PRD.md"
OUT=$(bash "$BUILD" --vault="$V3" --cwd="$F3" --mode=pre-dev --doc=prd </dev/null 2>&1); RC=$?
H1=$(sha_of "$V3/01-overview.md")
if [ "$RC" -eq 0 ] && [ -f "$V3/prd/.citation-map.json" ] && grep -q "(sha256: ${H1:0:12})" "$V3/prd/PRD.md" \
   && grep -q '"emitted_by": "emit-prd via scripts/build-citation-map.sh"' "$V3/prd/.citation-map.json"; then
  ok "3: --doc=prd stamps PRD.md + writes <vault>/prd/.citation-map.json (emitted_by: emit-prd)"
else
  fail "3: prd lane rc=$RC out: $OUT"
fi
OUT=$(bash "$DRIFT" --vault="$V3" --cwd="$F3" --doc=prd </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "3: drift --doc=prd reads the prd map (clean → no output)" \
  || fail "3: prd drift rc=$RC out: $OUT"
OUT=$(bash "$BUILD" --vault="$V3" --cwd="$F3" --mode=pre-dev --doc=sit </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q 'SIT.md not found' \
  && ok "3: absent doc dir → exit 2 (SIT.md not found)" || fail "3: missing-doc lane rc=$RC out: $OUT"

# ── 4: validate-fsd-slots.sh not generalized in P3 (PostToolUse seam pin) ──
grep -q -- '--doc' "$SLOTS" \
  && fail "4: validate-fsd-slots.sh grew a --doc flag — P3 declared this a P5 seam (PostToolUse contract risk)" \
  || ok "4: validate-fsd-slots.sh stays fsd-scoped (P5 seam per emission-engine.md)"
grep -q 'validate-fsd-slots.sh' "$ENGINE" && grep -q 'refresh-doc-stamps.sh' "$ENGINE" \
  && ok "4: engine doc names both P5 seams" || fail "4: engine doc missing a seam note"

if [ "$FAILED" -eq 0 ]; then note "PASS: P3 emission-parity suite"; exit 0
else note "FAIL: P3 emission-parity suite"; exit 1; fi
