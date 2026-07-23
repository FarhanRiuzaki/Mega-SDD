#!/usr/bin/env bash
# test-doc-versioning.sh — Design B (spec 2026-07-23-uat-docpack-and-doc-versioning-design.md
# §4): refresh-doc-stamps.sh gains a script-owned document-versioning engine —
# version/status stamp fields, a .doc-history.json sidecar, and an
# auto-generated "Riwayat Revisi" region — while the legacy 3-field stamp lane
# stays byte-identical when the new flags are absent.
#
#   1  legacy lane UNCHANGED: plain stamp → no sidecar, no region, 3-field block
#   2  arg guards: --bump w/o --change-note, --approve w/o --approver, and
#      --bump+--approve together each exit 2 with their specific message
#   3  first --bump → sidecar 0.1/draft; block gains version/status; region with
#      ONE row (note + commit anchor); Oleh cell = emit (model-run)
#   4  second --bump → 0.2; TWO rows; 0.2 row above 0.1 (latest first)
#   5  note sanitization: '{{'/'|' neutralized (slot-scan + table safety)
#   6  --approve → 1.0/approved; event:approval in sidecar; Oleh cell = approver
#   7  --bump after approve → 1.1 + status back to draft
#   8  non-version refresh leaves version/status/region + sidecar bytes unchanged
#   9  MASKED-COPY PIN: stripping BOTH script-owned regions restores pre-stamp bytes
#  10  region grammar: no '## ', '{{', '(sha256:', '[Source:' (validator-invisible)
#  11  regression: test-p3-refresh-doc-stamps.sh still passes
#
# Run: bash tests/derived-artifacts/test-doc-versioning.sh </dev/null
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
REFRESH="${ROOT}/plugins/mega-sdd/scripts/refresh-doc-stamps.sh"
[ -f "$REFRESH" ] || { echo "missing $REFRESH"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t docver)"
trap 'rm -rf "$WORK"' EXIT

sha_of()    { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
region_of() {
  python3 - "$1" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read()
m = re.search(r"<!-- mega-sdd:revision-history -->\n.*?<!-- /mega-sdd:revision-history -->", t, re.DOTALL)
sys.stdout.write(m.group(0) if m else "")
PY
}

# ── Fixture: mirrors test-p3-refresh-doc-stamps.sh's FSD fixture ──
F="$WORK/proj"
V="$F/.mega-sdd/vaults/v1"
mkdir -p "$V/fsd"
printf '{"project_name":"docver"}\n' > "$V/vault.json"
printf '# Overview\n\nPurpose.\n' > "$V/01-overview.md"
cat > "$V/fsd/FSD.md" <<'MD'
---
title: "Doc-versioning fixture — FSD"
mode: "pre-development"
---

# Doc-versioning fixture

**Mode:** Pre-development · **Source vault:** `.mega-sdd/vaults/v1` (sha256: `pending`)

## 1. Overview

Body.

**Sources for this section:**
- [¹] `vault/01-overview.md:L1-L3` (sha256: `pending`)
MD
DOC="$V/fsd/FSD.md"
cp "$DOC" "$WORK/original.md"

# The sidecar's `commit` field comes from `git rev-parse --short HEAD`, so the
# fixture must be a real repo with a HEAD commit — otherwise git_short_hash
# returns "-" and check 3's "(commit " anchor would spuriously fail.
git -C "$F" init -q
git -C "$F" -c user.email=t@example.com -c user.name=tester -c commit.gpgsign=false add -A
git -C "$F" -c user.email=t@example.com -c user.name=tester -c commit.gpgsign=false commit -q -m fixture
git -C "$F" rev-parse HEAD >/dev/null 2>&1 || { echo "fixture git setup failed"; exit 1; }

note "== Doc versioning: refresh-doc-stamps version/status + Riwayat Revisi =="

# ── 1: legacy lane UNCHANGED — plain stamp creates no sidecar, no region ──
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --position="units 0/3" --generated-at=2026-07-23T00:00:00Z </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ ! -f "$V/fsd/.doc-history.json" ] \
  && ! grep -q 'mega-sdd:revision-history' "$DOC" && ! grep -q '^version:' "$DOC" \
  && echo "$OUT" | grep -q '^PASS: stamped fsd-doc-control' \
  && ok "1: legacy stamp unchanged (no sidecar, no region, 3-field block)" || fail "1: rc=$RC out: $OUT"

# ── 2: arg guards each exit 2 with the specific message ──
bash "$REFRESH" --vault="$V" --doc=fsd --bump </dev/null >"$WORK/e" 2>&1; RC=$?
[ "$RC" -eq 2 ] && grep -q 'requires --change-note' "$WORK/e" \
  && ok "2: --bump without --change-note → exit 2" || fail "2: bump-no-note rc=$RC $(cat "$WORK/e")"
bash "$REFRESH" --vault="$V" --doc=fsd --approve </dev/null >"$WORK/e" 2>&1; RC=$?
[ "$RC" -eq 2 ] && grep -q 'requires --approver' "$WORK/e" \
  && ok "2: --approve without --approver → exit 2" || fail "2: approve-no-approver rc=$RC $(cat "$WORK/e")"
bash "$REFRESH" --vault="$V" --doc=fsd --bump --approve --change-note=x --approver=y </dev/null >"$WORK/e" 2>&1; RC=$?
[ "$RC" -eq 2 ] && grep -q 'mutually exclusive' "$WORK/e" \
  && ok "2: --bump + --approve together → exit 2 (mutually exclusive)" || fail "2: mutual rc=$RC $(cat "$WORK/e")"
[ ! -f "$V/fsd/.doc-history.json" ] && ok "2: rejected guards created no sidecar" || fail "2: a guard leaked a sidecar"

# ── 3: first --bump → sidecar 0.1/draft; block + one region row ──
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --bump --change-note="Emisi awal" </dev/null 2>&1); RC=$?
region_of "$DOC" > "$WORK/r3"
ROWS=$(grep -cE '^\| [0-9]+\.[0-9]+ ' "$WORK/r3")
SVER=$(python3 -c 'import json,sys;h=json.load(open(sys.argv[1]));print(h["version"],h["status"])' "$V/fsd/.doc-history.json" 2>/dev/null)
[ "$RC" -eq 0 ] && [ "$SVER" = "0.1 draft" ] \
  && grep -q '^version: 0.1' "$DOC" && grep -q '^status: draft' "$DOC" \
  && [ "$ROWS" -eq 1 ] && grep -qF 'Emisi awal' "$WORK/r3" && grep -qF '(commit ' "$WORK/r3" \
  && grep -qF 'emit (model-run)' "$WORK/r3" \
  && ok "3: first --bump → 0.1/draft, block fields, one region row (note + commit), Oleh=emit (model-run)" \
  || fail "3: rc=$RC sver='$SVER' rows=$ROWS out: $OUT"

# ── 4: second --bump → 0.2; two rows; latest (0.2) above 0.1 ──
bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --bump --change-note="Regenerasi 1" </dev/null >/dev/null 2>&1; RC=$?
region_of "$DOC" > "$WORK/r4"
ROWS=$(grep -cE '^\| [0-9]+\.[0-9]+ ' "$WORK/r4")
L02=$(grep -n '^| 0.2 ' "$WORK/r4" | head -1 | cut -d: -f1)
L01=$(grep -n '^| 0.1 ' "$WORK/r4" | head -1 | cut -d: -f1)
SVER=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$V/fsd/.doc-history.json")
[ "$RC" -eq 0 ] && [ "$SVER" = "0.2" ] && [ "$ROWS" -eq 2 ] && [ -n "$L02" ] && [ -n "$L01" ] && [ "$L02" -lt "$L01" ] \
  && ok "4: second --bump → 0.2, two rows, latest (0.2) above 0.1" \
  || fail "4: rc=$RC sver='$SVER' rows=$ROWS L02='$L02' L01='$L01'"

# ── 5: note sanitization — escaped pipe rendered, no literal {{ ──
bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --bump --change-note='a | b {{x}}' </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && grep -qF 'a \| b (x)' "$DOC" && ! grep -qF '{{' "$DOC" \
  && ok "5: note sanitized — escaped pipe rendered, no literal {{ anywhere in doc" || fail "5: rc=$RC sanitization"

# ── 6: --approve → 1.0/approved; event:approval; Oleh = approver ──
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --approve --approver="Budi, QA Lead" </dev/null 2>&1); RC=$?
region_of "$DOC" > "$WORK/r6"
EVT=$(python3 -c 'import json,sys;h=json.load(open(sys.argv[1]));r=h["history"][-1];print(h["version"],h["status"],r.get("event",""),r["actor"])' "$V/fsd/.doc-history.json")
[ "$RC" -eq 0 ] && [ "$EVT" = "1.0 approved approval Budi, QA Lead" ] \
  && grep -q '^version: 1.0' "$DOC" && grep -q '^status: approved' "$DOC" \
  && grep -qF 'Budi, QA Lead' "$WORK/r6" \
  && ok "6: --approve → 1.0/approved, event:approval in sidecar, Oleh=Budi, QA Lead" || fail "6: rc=$RC evt='$EVT' out: $OUT"

# ── 7: --bump after approve → 1.1 + status back to draft ──
bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --bump --change-note="Perbaikan pasca-approval" </dev/null >/dev/null 2>&1; RC=$?
SVER=$(python3 -c 'import json,sys;h=json.load(open(sys.argv[1]));print(h["version"],h["status"])' "$V/fsd/.doc-history.json")
[ "$RC" -eq 0 ] && [ "$SVER" = "1.1 draft" ] && grep -q '^version: 1.1' "$DOC" && grep -q '^status: draft' "$DOC" \
  && ok "7: --bump after approve → 1.1, status back to draft" || fail "7: rc=$RC sver='$SVER'"

# ── 8: non-version refresh leaves version state + sidecar bytes untouched ──
D1=$(sha_of "$DOC"); S1=$(sha_of "$V/fsd/.doc-history.json")
bash "$REFRESH" --vault="$V" --doc=fsd --position="units 0/3" </dev/null >/dev/null 2>&1; RC=$?
D2=$(sha_of "$DOC"); S2=$(sha_of "$V/fsd/.doc-history.json")
[ "$RC" -eq 0 ] && [ "$D1" = "$D2" ] && [ "$S1" = "$S2" ] \
  && grep -q '^version: 1.1' "$DOC" && grep -q 'mega-sdd:revision-history' "$DOC" \
  && ok "8: non-version refresh — doc + sidecar bytes unchanged, version/status/region intact" \
  || fail "8: rc=$RC d1=$D1 d2=$D2 s1=$S1 s2=$S2"

# ── 9: MASKED-COPY PIN — strip BOTH script-owned regions → pre-stamp bytes ──
python3 - "$DOC" "$WORK/masked.md" <<'PY'
import re, sys
t = open(sys.argv[1], "rb").read().decode("utf-8", errors="surrogateescape")
t = re.sub(r"<!-- mega-sdd:revision-history -->\n.*?<!-- /mega-sdd:revision-history -->\n\n", "", t, count=1, flags=re.DOTALL)
t = re.sub(r"<!-- mega-sdd:doc-control\n.*?-->\n\n", "", t, count=1, flags=re.DOTALL)
open(sys.argv[2], "wb").write(t.encode("utf-8", errors="surrogateescape"))
PY
cmp -s "$WORK/masked.md" "$WORK/original.md" \
  && ok "9: MASKED PIN — stripping both script-owned regions restores the pre-stamp file byte-identically" \
  || { fail "9: bytes outside the two script-owned regions changed"; diff "$WORK/original.md" "$WORK/masked.md" | head; }

# ── 10: region grammar — validator-invisible ──
region_of "$DOC" > "$WORK/r10"
if ! grep -q '^## ' "$WORK/r10" && ! grep -qF '{{' "$WORK/r10" \
   && ! grep -qF '(sha256:' "$WORK/r10" && ! grep -qF '[Source:' "$WORK/r10"; then
  ok "10: region carries no heading / slot / sha256 / Source token (validator-invisible)"
else
  fail "10: region introduced a validator-visible token"
fi

# ── 11: regression — the legacy stamp suite still passes ──
if bash "$ROOT/tests/derived-artifacts/test-p3-refresh-doc-stamps.sh" </dev/null >/dev/null 2>&1; then
  ok "11: test-p3-refresh-doc-stamps.sh still passes (legacy contract intact)"
else
  fail "11: test-p3-refresh-doc-stamps.sh regressed"
fi

if [ "$FAILED" -eq 0 ]; then note "PASS: doc-versioning suite"; exit 0
else note "FAIL: doc-versioning suite"; exit 1; fi
