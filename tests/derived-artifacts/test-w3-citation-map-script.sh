#!/usr/bin/env bash
# test-w3-citation-map-script.sh — W-batch W3 (spec 2026-07-19-w-batch-script-derive.md):
# the citation map + every in-document sha256 stamp is SCRIPT-COMPUTED.
#
#   1  build-citation-map.sh exit 1 + UNRESOLVED line for a fabricated path; map
#      still written with unresolved:true / source_sha256:null for that entry
#   2  schema_version "2.0"; entry hash byte-equals an in-test hashlib recompute
#      (fabrication-impossible pin)
#   3  FSD.md `pending` stamps for resolved paths replaced with the matching
#      12-char prefixes; the Source-vault header stamp == sha256(vault.json)[:12]
#   4  missing_sources[] carries {section, expected_source} from [Pending —] markers
#   5  clean re-run: exit 0, ONE stdout line (quiet-gates diet), idempotent
#      (second run leaves FSD.md byte-identical)
#   6  check-citation-drift.sh: exactly one DRIFT line, old12/new12 match the
#      pre/post hashes; stdout has neither '"sections"' nor any 64-hex string
#   7  deleted source → GONE line
#   8  no map → NO_PRIOR; corrupt JSON → PRIOR_UNREADABLE; both exit 0
#   9  forged prior source_sha256 surfaces as DRIFT (never passes) and the next
#      build overwrites it with the true hash
#  10  doc pins: SKILL.md Step 3 has no 'compute sha256'; SKILL.md names both
#      scripts; section-mapping.md schema says 2.0
#
# Run: bash tests/derived-artifacts/test-w3-citation-map-script.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="${ROOT}/plugins/mega-sdd/scripts/build-citation-map.sh"
DRIFT="${ROOT}/plugins/mega-sdd/scripts/check-citation-drift.sh"
SKILL="${ROOT}/plugins/mega-sdd/skills/emit-fsd/SKILL.md"
SM="${ROOT}/plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md"
for f in "$BUILD" "$DRIFT" "$SKILL" "$SM"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w3cm)"
trap 'rm -rf "$WORK"' EXIT

sha_of() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

# ── Fixture project ──
F="$WORK/proj"
V="$F/.mega-sdd/vaults/v1"
mkdir -p "$V/fsd" "$V/units" "$F/.mega-sdd/codebase"
printf '{"project_name":"w3-fixture","vault_version":"1.0"}\n' > "$V/vault.json"
printf '# Overview\n\nPurpose: fixture.\nScope: small.\n' > "$V/01-overview.md"
printf '## FR-007 Fixture requirement\n\nBody of FR-007.\n' > "$V/02-functional.md"
printf -- '---\nunit_id: U-001\n---\n# U-001\n' > "$V/units/U-001.md"
printf '# Codebase map\n\n## Entities\n' > "$F/.mega-sdd/codebase/codebase-map.md"
cat > "$V/fsd/FSD.md" <<'MD'
---
title: "W3 fixture — FSD"
mode: "pre-development"
---

# W3 fixture

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
MAP="$V/fsd/.citation-map.json"

note "== W3: script-computed citation map =="

# ── 1: bogus citation → exit 1 + UNRESOLVED + map still written ──
OUT=$(bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "UNRESOLVED .* vault/nonexistent-source.md"; then
  ok "1: exit 1 + UNRESOLVED line names the fabricated path"
else
  fail "1: rc=$RC out: $(echo "$OUT" | head -3)"
fi
if [ -f "$MAP" ] && MAP="$MAP" python3 - <<'PY'
import json, os, sys
m = json.load(open(os.environ["MAP"]))
e = [s for s in m["sections"] if s["source_path"] == "vault/nonexistent-source.md"]
sys.exit(0 if e and e[0].get("unresolved") is True and e[0]["source_sha256"] is None else 1)
PY
then ok "1: map still written; bogus entry has unresolved:true + source_sha256:null"
else fail "1: map missing or bogus entry not marked unresolved:true/null"; fi

# ── 2: schema 2.0 + hashlib byte-equality (fabrication-impossible pin) ──
H02=$(sha_of "$V/02-functional.md")
if MAP="$MAP" H02="$H02" python3 - <<'PY'
import json, os, sys
m = json.load(open(os.environ["MAP"]))
e = [s for s in m["sections"] if s["source_path"] == "vault/02-functional.md"]
sys.exit(0 if m["schema_version"] == "2.0" and e and all(x["source_sha256"] == os.environ["H02"] for x in e) else 1)
PY
then ok "2: schema_version 2.0 + 02-functional hash byte-equals in-test hashlib recompute"
else fail "2: schema/hash pin broken (expected $H02)"; fi

# ── 3: pending stamps replaced with 12-char prefixes; vault.json header stamp ──
HOV=$(sha_of "$V/01-overview.md"); HVJ=$(sha_of "$V/vault.json")
grep -q "vault/01-overview.md:L1-L4\` (sha256: \`${HOV:0:12}\`)" "$V/fsd/FSD.md" \
  && ok "3: 01-overview stamp replaced with its real 12-char prefix" \
  || fail "3: 01-overview stamp not replaced (want ${HOV:0:12})"
grep -q "\*\*Source vault:\*\* \`.mega-sdd/vaults/v1\` (sha256: \`${HVJ:0:12}\`)" "$V/fsd/FSD.md" \
  && ok "3: Source-vault header stamped with sha256(vault.json)[:12]" \
  || fail "3: vault.json header stamp wrong (want ${HVJ:0:12})"
grep -q '(sha256: pending)' "$V/fsd/FSD.md" && grep -q 'nonexistent-source.md (sha256: pending)' "$V/fsd/FSD.md" \
  && ok "3: unresolvable citation keeps its pending stamp (halt path — no hash minted)" \
  || fail "3: unresolvable citation's pending stamp missing"
grep -q 'Fence example stays untouched: (sha256: `pending`)' "$V/fsd/FSD.md" \
  && ok "3: code-fence pending untouched" || fail "3: fence content was rewritten"

# ── 4: missing_sources[] shape {section, expected_source} ──
if MAP="$MAP" python3 - <<'PY'
import json, os, sys
m = json.load(open(os.environ["MAP"]))
ms = m.get("missing_sources") or []
hit = [x for x in ms if x.get("expected_source") == "vault/03-open-questions.md" and x.get("section") == "1"]
sys.exit(0 if hit else 1)
PY
then ok "4: missing_sources[] carries {section: 1, expected_source: vault/03-open-questions.md}"
else fail "4: missing_sources shape wrong: $(python3 -c 'import json;print(json.load(open("'"$MAP"'")).get("missing_sources"))' 2>/dev/null)"; fi

# ── 5: remove bogus citation → clean exit 0, ONE line, idempotent ──
grep -v 'nonexistent-source' "$V/fsd/FSD.md" > "$V/fsd/FSD.md.tmp" && mv "$V/fsd/FSD.md.tmp" "$V/fsd/FSD.md"
OUT=$(bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null); RC=$?
N_LINES=$(printf '%s\n' "$OUT" | grep -c .)
if [ "$RC" -eq 0 ] && [ "$N_LINES" -eq 1 ]; then
  ok "5: clean run exits 0 with ONE stdout line (quiet-gates diet)"
else
  fail "5: rc=$RC lines=$N_LINES out: $OUT"
fi
B1=$(sha_of "$V/fsd/FSD.md")
bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null >/dev/null 2>&1
B2=$(sha_of "$V/fsd/FSD.md")
[ "$B1" = "$B2" ] && ok "5: idempotent — second run leaves FSD.md byte-identical" \
  || fail "5: second run mutated FSD.md ($B1 vs $B2)"

# ── 6: DRIFT line old12/new12 correctness + wholesale-read diet pin ──
PRE=$(sha_of "$V/02-functional.md")
echo "drifted line" >> "$V/02-functional.md"
POST=$(sha_of "$V/02-functional.md")
OUT=$(bash "$DRIFT" --vault="$V" --cwd="$F" </dev/null); RC=$?
N_DRIFT=$(printf '%s\n' "$OUT" | grep -c '^DRIFT ')
if [ "$RC" -eq 0 ] && [ "$N_DRIFT" -eq 1 ] \
   && echo "$OUT" | grep -q "^DRIFT 5 vault/02-functional.md ${PRE:0:12} ${POST:0:12}$"; then
  ok "6: exactly one DRIFT line; old12/new12 match the pre/post hashes"
else
  fail "6: rc=$RC drift-lines=$N_DRIFT out: $OUT (want old=${PRE:0:12} new=${POST:0:12})"
fi
if echo "$OUT" | grep -q '"sections"' || echo "$OUT" | grep -qE '[0-9a-f]{64}'; then
  fail "6: stdout leaks raw JSON or a 64-hex string (wholesale-read diet broken)"
else
  ok "6: stdout has neither '\"sections\"' nor any 64-hex string"
fi

# ── 7: deleted source → GONE ──
U001_BAK=$(cat "$V/units/U-001.md"); HU=$(sha_of "$V/units/U-001.md")
rm "$V/units/U-001.md"
OUT=$(bash "$DRIFT" --vault="$V" --cwd="$F" </dev/null); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^GONE 5 units/U-001.md ${HU:0:12}$"; then
  ok "7: deleted source prints GONE with the prior 12-char prefix"
else
  fail "7: rc=$RC out: $OUT"
fi
printf '%s\n' "$U001_BAK" > "$V/units/U-001.md"

# ── 8: NO_PRIOR + PRIOR_UNREADABLE, both exit 0 ──
mv "$MAP" "$MAP.bak"
OUT=$(bash "$DRIFT" --vault="$V" --cwd="$F" </dev/null); RC=$?
[ "$RC" -eq 0 ] && [ "$OUT" = "NO_PRIOR" ] && ok "8: absent map → NO_PRIOR, exit 0" \
  || fail "8: NO_PRIOR path wrong (rc=$RC out=$OUT)"
echo '{broken json' > "$MAP"
OUT=$(bash "$DRIFT" --vault="$V" --cwd="$F" </dev/null); RC=$?
[ "$RC" -eq 0 ] && [ "$OUT" = "PRIOR_UNREADABLE" ] && ok "8: corrupt map → PRIOR_UNREADABLE, exit 0" \
  || fail "8: PRIOR_UNREADABLE path wrong (rc=$RC out=$OUT)"
mv "$MAP.bak" "$MAP"

# ── 9: forged prior hash surfaces as DRIFT, then the next build overwrites it ──
JUNK="deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
MAP="$MAP" JUNK="$JUNK" python3 - <<'PY'
import json, os
p = os.environ["MAP"]
m = json.load(open(p))
for s in m["sections"]:
    if s["source_path"] == "vault/01-overview.md":
        s["source_sha256"] = os.environ["JUNK"]
json.dump(m, open(p, "w"), indent=2)
PY
OUT=$(bash "$DRIFT" --vault="$V" --cwd="$F" </dev/null)
echo "$OUT" | grep -q "^DRIFT 1 vault/01-overview.md ${JUNK:0:12} ${HOV:0:12}$" \
  && ok "9: forged prior hash surfaces as DRIFT (forgery never passes silently)" \
  || fail "9: forged hash did not surface as DRIFT: $OUT"
bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null >/dev/null 2>&1
if MAP="$MAP" HOV="$HOV" python3 - <<'PY'
import json, os, sys
m = json.load(open(os.environ["MAP"]))
e = [s for s in m["sections"] if s["source_path"] == "vault/01-overview.md"]
sys.exit(0 if e and all(x["source_sha256"] == os.environ["HOV"] for x in e) else 1)
PY
then ok "9: next build overwrites the forged value with the hashlib-true hash"
else fail "9: forged hash survived a rebuild"; fi

# ── 10: doc pins ──
STEP3=$(sed -n '/^### Step 3:/,/^### Step 4:/p' "$SKILL")
echo "$STEP3" | grep -q 'compute sha256' \
  && fail "10: SKILL.md Step 3 still says 'compute sha256'" \
  || ok "10: SKILL.md Step 3 no longer contains 'compute sha256'"
grep -q 'build-citation-map.sh' "$SKILL" && grep -q 'check-citation-drift.sh' "$SKILL" \
  && ok "10: SKILL.md names both scripts" || fail "10: SKILL.md missing a script name"
grep -q '"schema_version": "2.0"' "$SM" \
  && ok "10: section-mapping.md schema says 2.0" || fail "10: section-mapping schema not 2.0"

if [ "$FAILED" -eq 0 ]; then note "PASS: W3 citation-map script suite"; exit 0
else note "FAIL: W3 citation-map script suite"; exit 1; fi
