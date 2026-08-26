#!/usr/bin/env bash
# Extract PRD-kontrak lane, Step 1 (spec 2026-08-26-extract-revamp-contract-design.md):
# derive-extract-census.sh + validate-extract-census.sh contract.
#   - census enumerates CODE only (logs/.bak/data never enter — the MTConvert class)
#   - census determinism (byte-identical minus generated_at)
#   - gate recomputes coverage from census + module-PRD artifacts (B1 pattern):
#     unclaimed / double-claimed / phantom / uncited / missing-OQ all FAIL;
#     full claim + citation PASSes; no census.json → SKIP (legacy KB)
#   - shared enumeration: build-symbol-index.sh must import _lib/code_enum.py
#     (fixtures-derive-production lesson — two copied lists WILL drift)
# Run: bash tests/extract-census/test-extract-census.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
DERIVE="plugins/mega-sdd/scripts/derive-extract-census.sh"
GATE="plugins/mega-sdd/scripts/validate-extract-census.sh"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LEG="$TMP/legacy"; KB="$TMP/kb"
mkdir -p "$LEG/Log" "$LEG/BackupFile" "$LEG/lib"

# MTConvert-class legacy shape: 1 live entrypoint + 1 helper + noise
printf '<?php\nfunction convert($in) { return strtoupper($in); }\nconvert("x");\n' > "$LEG/index.php"
printf '<?php\nfunction helper() { return 1; }\n' > "$LEG/lib/util.php"
printf 'log line\n' > "$LEG/Log/log_1.1.2020.log"
printf 'OTR data\n' > "$LEG/BackupFile/OTR_1.TXT"
printf '<?php echo "old";\n' > "$LEG/index.php.bak"
printf 'runner\n' > "$LEG/Runner.bat"

# ── census enumeration + determinism ─────────────────────────────────────────
out=$(bash "$DERIVE" --legacy="$LEG" --kb-dir="$KB" </dev/null 2>&1); drc=$?
[ "$drc" -eq 0 ] && pass "derive exits 0" || fail "derive exited $drc: $out"
[ -f "$KB/census.json" ] && pass "census.json written" || fail "census.json missing"

paths=$(python3 -c "import json;print('\n'.join(r['path'] for r in json.load(open('$KB/census.json'))['files']))")
echo "$paths" | grep -qx "index.php" && pass "census counts index.php" || fail "index.php missing from census: $paths"
echo "$paths" | grep -qx "lib/util.php" && pass "census counts lib/util.php" || fail "lib/util.php missing"
echo "$paths" | grep -q "\.log" && fail "a .log leaked into the census" || pass "logs never enter the census"
echo "$paths" | grep -q "\.bak" && fail "a .bak leaked into the census" || pass ".bak backups never enter the census"
echo "$paths" | grep -q "OTR_" && fail "data file leaked into the census" || pass "data files never enter the census"

n=$(python3 -c "import json;print(json.load(open('$KB/census.json'))['file_count'])")
[ "$n" = "2" ] && pass "file_count=2 (code only)" || fail "file_count=$n (expected 2)"
stacks=$(python3 -c "import json;print(','.join(json.load(open('$KB/census.json'))['stacks']))")
[ "$stacks" = "php" ] && pass "stacks detected: php" || fail "stacks=$stacks (expected php)"
python3 -c "import json;d=json.load(open('$KB/census.json'));assert 'index.php' in d['entry_points']" \
  && pass "index.php flagged as entry point" || fail "entry_points missed index.php"
sha=$(python3 -c "import json;print(json.load(open('$KB/census.json'))['files'][0]['sha256'])")
[ -n "$sha" ] && [ "$sha" != "None" ] && pass "per-file sha256 recorded (freshness substrate)" || fail "sha256 missing"

cp "$KB/census.json" "$TMP/c1.json"
bash "$DERIVE" --legacy="$LEG" --kb-dir="$KB" --quiet </dev/null
if python3 -c "
import json
a=json.load(open('$TMP/c1.json')); b=json.load(open('$KB/census.json'))
a.pop('generated_at'); b.pop('generated_at')
raise SystemExit(0 if a==b else 1)"; then
  pass "census deterministic (identical tree → identical doc minus generated_at)"
else
  fail "census not deterministic across runs"
fi

# ── gate: SKIP without census (legacy numbered-tree KB) ─────────────────────
KB2="$TMP/kb-legacy"; mkdir -p "$KB2"
gout=$(bash "$GATE" --kb-dir="$KB2" </dev/null 2>&1); grc=$?
[ "$grc" -eq 0 ] && echo "$gout" | grep -q "SKIP" \
  && pass "no census.json → SKIP exit 0 (legacy KB unaffected)" \
  || fail "legacy-KB skip broken (rc=$grc): $gout"
python3 -c "import json;assert json.load(open('$KB2/.extract-census-state.json'))['status']=='SKIP'" \
  && pass "SKIP state recorded" || fail "SKIP state missing/wrong"

# ── gate: census present but no PRDs → FAIL ─────────────────────────────────
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && pass "census w/o module PRDs → FAIL (extraction incomplete)" \
  || fail "expected FAIL rc=1 with no PRDs, got rc=$grc"

# ── gate: unclaimed + uncited + phantom + double-claim + OQ section ─────────
mkdir -p "$KB/modules"
cat > "$KB/modules/converter.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: converter
classification: workflow
source_files:
  - index.php
---
# PRD — Converter

## 1. Purpose
Konversi input jadi uppercase (index.php:2).

## 2. Business Rules
| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-CONVERTER-1 | Input dikonversi ke huruf besar | Format hilir | index.php:2 |  | [LOCKED] |

## 3. Flow
```mermaid
flowchart LR
    A["Input"] --> B["Uppercase"] --> C["Output"]
```

## 4. Data In/Out
Teks masuk, teks kapital keluar (index.php:2-3).

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF

gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$gout" | grep -q "unclaimed" \
  && pass "lib/util.php unclaimed → FAIL names it" \
  || fail "unclaimed file not caught (rc=$grc): $gout"

# claim the second file but WITHOUT citing it → uncited FAIL
cat > "$KB/modules/util.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: util
classification: reference
source_files:
  - lib/util.php
---
# PRD — Util

## 1. Purpose
Helper murni.

## 2. Business Rules
_Tidak terdeteksi._

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
Fungsi murni tanpa persistensi.

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$gout" | grep -q "uncited" \
  && pass "claimed-but-never-cited file → FAIL uncited" \
  || fail "uncited not caught (rc=$grc): $gout"

# cite it → PASS end-to-end
cat > "$KB/modules/util.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: util
classification: reference
source_files:
  - lib/util.php
---
# PRD — Util

## 1. Purpose
Helper murni (lib/util.php:2).

## 2. Business Rules
_Tidak terdeteksi._

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
Fungsi murni tanpa persistensi (lib/util.php:2).

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 0 ] && echo "$gout" | grep -q "PASS" \
  && pass "full claim + citation → PASS" || fail "expected PASS (rc=$grc): $gout"
python3 -c "import json;assert json.load(open('$KB/.extract-census-state.json'))['status']=='PASS'" \
  && pass "PASS state recorded" || fail "PASS state missing/wrong"

# phantom claim (file not in census = fabrication signal)
cat > "$KB/modules/ghost.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: ghost
classification: reference
source_files:
  - imaginary.php
---
# PRD — ghost

## 1. Purpose
Klaim (imaginary.php:1).

## 2. Business Rules
_Tidak terdeteksi._

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
_Tidak terdeteksi._

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$gout" | grep -q "phantom" \
  && pass "claim of un-censused file → FAIL phantom_claims" \
  || fail "phantom claim not caught (rc=$grc): $gout"
rm "$KB/modules/ghost.prd.md"

# double claim (module boundary error)
cat > "$KB/modules/dupe.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: dupe
classification: reference
source_files:
  - index.php
---
# PRD — dupe

## 1. Purpose
Klaim (index.php:1).

## 2. Business Rules
_Tidak terdeteksi._

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
_Tidak terdeteksi._

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$gout" | grep -q "double_claimed" \
  && pass "file claimed by two PRDs → FAIL double_claimed" \
  || fail "double claim not caught (rc=$grc): $gout"
rm "$KB/modules/dupe.prd.md"

# missing OQ section
python3 - "$KB/modules/util.prd.md" <<'EOF'
import sys
p = sys.argv[1]
t = open(p).read()
open(p, "w").write(t.split("## 6. Open Questions")[0])
EOF
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$gout" | grep -q "missing_oq_section" \
  && pass "PRD without ## Open Questions → FAIL (explicit absence mandated)" \
  || fail "missing OQ section not caught (rc=$grc): $gout"

# ── mermaid hard rule on the new grammar ────────────────────────────────────
cat > "$KB/modules/util.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: util
classification: reference
source_files:
  - lib/util.php
---
# PRD — Util

## 1. Purpose
Helper murni (lib/util.php:2).

## 2. Business Rules
_Tidak terdeteksi._

## 3. Flow
Input lalu proses lalu output tanpa diagram.

## 4. Data In/Out
_Tidak terdeteksi._

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$gout" | grep -q "flow_not_mermaid" \
  && pass "substantive Flow section without mermaid fence → FAIL flow_not_mermaid" \
  || fail "flow_not_mermaid not caught (rc=$grc): $gout"

python3 - "$KB/modules/util.prd.md" <<'EOF'
import sys
p = sys.argv[1]
t = open(p).read()
fence = chr(96) * 3
bad = "\n".join([fence + "mermaid", "flowchart LR", "    A[cek saldo (rekening, valid)] --> B[\"ok\"]", fence])
t = t.replace("Input lalu proses lalu output tanpa diagram.", bad)
open(p, "w").write(t)
EOF
gout=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$gout" | grep -q "mermaid_syntax" \
  && pass "mermaid block violating Rule 1 (unquoted node) → FAIL via shared tokenizer" \
  || fail "mermaid_syntax not caught (rc=$grc): $gout"

# restore a fully-valid util PRD so later checks start from PASS state
cat > "$KB/modules/util.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: util
classification: reference
source_files:
  - lib/util.php
---
# PRD — Util

## 1. Purpose
Helper murni (lib/util.php:2).

## 2. Business Rules
_Tidak terdeteksi._

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
Fungsi murni tanpa persistensi (lib/util.php:2).

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF

# ── shared enumeration pin (derive-production, never copy) ──────────────────
grep -q "import code_enum" plugins/mega-sdd/scripts/build-symbol-index.sh \
  && pass "build-symbol-index.sh imports _lib/code_enum.py (shared enumeration)" \
  || fail "build-symbol-index.sh no longer imports code_enum — enumeration forked"
grep -q "import code_enum" "$DERIVE" \
  && pass "derive-extract-census.sh imports _lib/code_enum.py" \
  || fail "derive-extract-census.sh does not import code_enum"
if grep -q "EXCL_DIR_NAMES = {" plugins/mega-sdd/scripts/build-symbol-index.sh; then
  fail "build-symbol-index.sh still carries its own EXCL copy (drift risk)"
else
  pass "no duplicated exclusion constants left in build-symbol-index.sh"
fi

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
