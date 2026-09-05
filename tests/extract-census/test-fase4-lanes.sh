#!/usr/bin/env bash
# Pin test — Fase 4 lanes (7.26.0, spec 2026-09-05-kb-verify-lane-design.md):
# script-derived counts + rollup recount + OQ probe advisory + site-census +
# encoding probe. Every check mirrors a field-proven Host-AS400 audit finding
# (agent-typed counts drifted 7/7 modules; README LOCKED 5-vs-4 + OQ split
# wrong; 4th CFTPNT write site missed; FILE REF evidence sat unnoticed;
# BIFREF non-UTF8).
# Run: bash tests/extract-census/test-fase4-lanes.sh </dev/null

set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
COUNTS="plugins/mega-sdd/scripts/derive-prd-counts.sh"
SITES="plugins/mega-sdd/scripts/derive-site-census.sh"
GATE="plugins/mega-sdd/scripts/validate-extract-census.sh"
DERIVE="plugins/mega-sdd/scripts/derive-extract-census.sh"
WRITER="plugins/mega-sdd/scripts/write-verify-state.sh"

rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"; LEG="$PROJ/legacy"; KB="$PROJ/.mega-sdd/knowledge-base"
mkdir -p "$LEG" "$KB/modules"

# Legacy fixture: fixed-format-ish RPG with 2 write sites + 1 call + col-7 dead
# write + a non-UTF8 member.
cat > "$LEG/prog.rpg" <<'EOF'
     C                     Z-ADD1         X
     C                     WRITERORDER
     C                     CALL 'HELPER'
     C*                    WRITERDEADFMT
     C                     Z-ADD2         Y
     C                     Z-ADD3         Z
     C                     MOVE X         W
     C                     WRITERAUDIT
EOF
printf 'A  FIELD1\xff\xfe binary-ish\n' > "$LEG/table.dds"

bash "$DERIVE" --legacy="$LEG" --kb-dir="$KB" --quiet </dev/null || fail "derive census failed"

# ── encoding probe ────────────────────────────────────────────────────────────
python3 -c "
import json; c=json.load(open('$KB/census.json'))
rows={r['path']:r for r in c['files']}
assert rows['table.dds'].get('encoding')=='non-utf8', rows['table.dds']
assert 'encoding' not in rows['prog.rpg']
" && pass "census flags non-utf8 member; utf8 member unflagged" \
  || fail "encoding probe wrong"

# ── module PRD (counts drifted on purpose; cites only ONE write site) ─────────
cat > "$KB/modules/core.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: core
classification: workflow
source_files:
  - prog.rpg
  - table.dds
inferred_count: 9
open_count: 0
locked_count: 2
intent_count: 0
artifact_count: 0
source_files_cited: 0
---
# PRD — Core

## 1. Purpose
Order writer (prog.rpg:2). Layout (table.dds:1).

## 2. Business Rules
| ID | Rule | Source | Confidence | Mutability |
|---|---|---|---|---|
| BR-C-1 | Write order record | prog.rpg:2 | | [LOCKED] |
| BR-C-2 | Helper resolves account | prog.rpg:3 | [INFERRED] (dasar: satu call site) | [INTENT] |

### Acceptance criteria
- AC-BR-C-1-1 — blocked-by-OQ-C-1 (fixture butuh layout EXTRA)

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
Order record ditulis (prog.rpg:2). Call HELPER (prog.rpg:3).

## 5. Edge Cases & Gotchas
1. Dead write di kolom-7 (prog.rpg:4) — do-not-replicate.

## 6. Open Questions
- OQ-C-1 [P1] — Layout file EXTRA hilang; kalau filenya dateng kejawab. (probe-glob: extras/*.dds)

## 7. Run & Recovery
Batch harian via job stream [UNKNOWN — CL tidak ada di source set]; window RRN via entry parm (prog.rpg:1).
EOF

# ── counts: check mode flags drift, --write trues up, idempotent ─────────────
bash "$COUNTS" --kb-dir="$KB" >/dev/null 2>&1 && fail "check mode should exit 1 on drift" \
  || pass "counts check mode exits 1 on drifted frontmatter"
bash "$COUNTS" --kb-dir="$KB" --write --quiet || fail "--write failed"
bash "$COUNTS" --kb-dir="$KB" --quiet && pass "post-write counts clean (idempotent)" \
  || fail "counts still drifted after --write"
python3 -c "
import re
t=open('$KB/modules/core.prd.md').read()
for k,v in [('inferred_count',1),('open_count',1),('locked_count',1),('intent_count',1),('artifact_count',0),('source_files_cited',2)]:
    m=re.search(r'^%s: (\d+)$'%k,t,re.M); assert m and int(m.group(1))==v,(k,m and m.group(1),v)
" && pass "derived values correct (incl. open=OQ entries, cited=2)" \
  || fail "derived values wrong"

# ── README rollup recount ─────────────────────────────────────────────────────
cat > "$KB/README.md" <<'EOF'
# KB
## Mutability Tier Distribution
| Module | LOCKED | INTENT | ARTIFACT |
|---|---|---|---|
| core | 1 | 1 | 0 |
| **Total** | **2** | **1** | **0** |

## Open Questions roll-up
Open questions: **3** (P1: 2, P2: 1, P3: 0)
EOF
# seed passing verify state so only Fase-4 findings remain
bash "$WRITER" --kb-dir="$KB" --quiet <<'EOF' || fail "verify writer failed"
VERIFY REPORT
- module: core
- locked_total: 1
- locked_checked: 1
- money_checked: 0
- sampled: 9
- exact: 10
- imprecise: 0
- wrong: 0
- wrong_load_bearing: 0
- findings: none
EOF
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$out" | grep -q "rollup_mismatch" \
  && pass "README drift (Total row + OQ split + total) → FAIL rollup_mismatch" \
  || fail "rollup_mismatch not raised (rc=$grc): $out"

# fix README → rollup clean
cat > "$KB/README.md" <<'EOF'
# KB
## Mutability Tier Distribution
| Module | LOCKED | INTENT | ARTIFACT |
|---|---|---|---|
| core | 1 | 1 | 0 |
| **Total** | **1** | **1** | **0** |

## Open Questions roll-up
Open questions: **1** (P1: 1, P2: 0, P3: 0)
EOF

# ── site census: uncovered site FAILs; cite it → PASS; probe advisory ────────
bash "$SITES" --legacy="$LEG" --kb-dir="$KB" --quiet </dev/null || fail "site derive failed"
python3 -c "
import json; d=json.load(open('$KB/.site-census.json'))
kinds=sorted((s['kind'],s['target']) for s in d['sites'])
assert kinds==[('call','HELPER'),('write','RAUDIT'),('write','RORDER')], kinds
assert d['stack_coverage'].get('dds','').startswith('no idiom'), d['stack_coverage']
" && pass "site census: 3 sites (col-7 dead write excluded), dds honestly no-idiom" \
  || fail "site census content wrong"
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$out" | grep -q '"target": "RAUDIT"' \
  && pass "uncited write site (RAUDIT prog.rpg:8, beyond ±2 of any cite) → FAIL site_uncovered" \
  || fail "site_uncovered not raised (rc=$grc): $out"
echo "$out" | grep -q "oq_answerable_from_disk" \
  && fail "probe advisory fired with no evidence on disk" \
  || pass "no probe advisory while evidence absent"

# cite the missing site (portable in-place edit — CI runs GNU sed, host BSD)
KB="$KB" python3 - <<'EOF'
import os
p = os.path.join(os.environ["KB"], "modules", "core.prd.md")
s = open(p).read()
s = s.replace("1. Dead write di kolom-7 (prog.rpg:4) — do-not-replicate.",
              "1. Dead write di kolom-7 (prog.rpg:4) — do-not-replicate.\n2. Audit record juga ditulis (prog.rpg:8).")
open(p, "w").write(s)
EOF
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 0 ] && pass "citing the site clears the gate → PASS" \
  || fail "gate still FAILs after citing site (rc=$grc): $out"

# evidence arrives → probe advisory fires, still PASS (advisory only)
mkdir -p "$PROJ/extras"; echo "A R EXTRA" > "$PROJ/extras/extra.dds"
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 0 ] && echo "$out" | grep -q "oq_answerable_from_disk" \
  && pass "evidence on disk → advisory oq_answerable_from_disk, gate stays PASS" \
  || fail "probe advisory wrong (rc=$grc): $out"
python3 -c "
import json; d=json.load(open('$KB/.extract-census-state.json'))
assert d['advisories']['oq_answerable_from_disk'], d['advisories']
assert d['status']=='PASS'
" && pass "advisory recorded in state, status PASS" || fail "advisory state wrong"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
