#!/usr/bin/env bash
# Pin test — Fase 5 grammar upgrades (7.27.0, spec
# 2026-09-05-kb-verify-lane-design.md): rebuild_after DAG, AC-for-LOCKED,
# §7 Run & Recovery (workflow), decision-table advisory, undeclared-reference
# advisory, flow-vs-[ARTIFACT] advisory, negative-claim rail prose pins.
# Run: bash tests/extract-census/test-fase5-grammar.sh </dev/null

set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
GATE="plugins/mega-sdd/scripts/validate-extract-census.sh"
WRITER="plugins/mega-sdd/scripts/write-verify-state.sh"

rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
KB="$TMP/kb"
mkdir -p "$KB/modules"

cat > "$KB/census.json" <<'EOF'
{"census_version":1,"file_count":2,"files":[
 {"path":"src/a.rb","lines":5},{"path":"src/b.rb","lines":5}]}
EOF

# Module A: workflow, [LOCKED] BR with NO AC, NO §7, prose rule with 3
# connectors, flow naming a dead component, cites B's file WITHOUT depends_on,
# rebuild_after cycle partner.
cat > "$KB/modules/alpha.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: alpha
classification: workflow
depends_on: []
rebuild_after: [beta]
source_files:
  - src/a.rb
---
# PRD — Alpha

## 1. Purpose
Poster utama (src/a.rb:1). Konsultasi helper beta (src/b.rb:2).

## 2. Business Rules
| ID | Rule | Source | Confidence | Mutability |
|---|---|---|---|---|
| BR-ALPHA-1 | Total dibulatkan half-up | src/a.rb:2 | | [LOCKED] |
| BR-ALPHA-2 | Kirim bila flag aktif dan cabang sama atau region beda dan bukan koreksi | src/a.rb:3 | | [INTENT] |

## 3. Flow
```mermaid
flowchart LR
    A["Input"] --> B["RATEFIX pilih kurs"] --> C["Output"]
```

## 4. Data In/Out
RATEFIX resolver kurs lama — mati, tidak dipanggil (src/a.rb:4) [ARTIFACT]

## 5. Edge Cases & Gotchas
1. Boundary nol (src/a.rb:5).

## 6. Open Questions
_Tidak ada._
EOF

cat > "$KB/modules/beta.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: beta
classification: reference
depends_on: [alpha]
rebuild_after: [alpha]
source_files:
  - src/b.rb
---
# PRD — Beta

## 1. Purpose
Helper (src/b.rb:2).

## 2. Business Rules
_Tidak terdeteksi._

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
_Tidak terdeteksi._ (src/b.rb:2)

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Open Questions
_Tidak ada._
EOF

for dom in alpha beta; do
  bash "$WRITER" --kb-dir="$KB" --quiet <<EOF2 >/dev/null || fail "verify seed $dom failed"
VERIFY REPORT
- module: $dom
- locked_total: 1
- locked_checked: 1
- money_checked: 1
- sampled: 8
- exact: 10
- imprecise: 0
- wrong: 0
- wrong_load_bearing: 0
- findings: none
EOF2
done

out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] || fail "expected FAIL on the seeded-defect fixture (rc=$grc)"
echo "$out" | grep -q "ac_missing_for_locked" \
  && pass "[LOCKED] BR without AC → FAIL ac_missing_for_locked" \
  || fail "ac_missing_for_locked not raised: $out"
echo "$out" | grep -q "Run & Recovery — workflow module" \
  && pass "workflow module without §7 → FAIL missing_sections(7)" \
  || fail "§7 requirement not enforced: $out"
echo "$out" | grep -q "rebuild_after entries missing from depends_on" \
  && pass "rebuild_after ⊄ depends_on → FAIL rebuild_order_invalid (subset)" \
  || fail "subset rule not enforced: $out"
echo "$out" | grep -q "cycle involving" \
  && pass "alpha↔beta rebuild_after cycle → FAIL rebuild_order_invalid (DAG)" \
  || fail "cycle not detected: $out"
echo "$out" | grep -q "rule_needs_decision_table" \
  && pass "advisory: ≥3-connector prose rule flagged (decision-table smell)" \
  || fail "decision-table advisory missing: $out"
echo "$out" | grep -q "undeclared_reference" \
  && pass "advisory: cites beta's file w/o depends_on → undeclared_reference" \
  || fail "undeclared_reference advisory missing: $out"
echo "$out" | grep -q "flow_names_artifact_component" \
  && pass "advisory: flow §3 names RATEFIX marked [ARTIFACT] (FNDCUR class)" \
  || fail "flow-artifact advisory missing: $out"

# ── fix the fixture → clean PASS ─────────────────────────────────────────────
KB="$KB" python3 - <<'EOF'
import os
p = os.path.join(os.environ["KB"], "modules", "alpha.prd.md")
s = open(p).read()
s = s.replace("depends_on: []\nrebuild_after: [beta]", "depends_on: [beta]\nrebuild_after: [beta]")
s = s.replace("| BR-ALPHA-2 | Kirim bila flag aktif dan cabang sama atau region beda dan bukan koreksi | src/a.rb:3 | | [INTENT] |",
              "| BR-ALPHA-2 | Routing per decision table di bawah | src/a.rb:3 | | [INTENT] |")
s = s.replace("## 3. Flow", """### Acceptance criteria
- AC-BR-ALPHA-1-1 — given 10.005 · when posting · then 10.01 · oracle: golden-master legacy run

## 3. Flow""")
s = s.replace('    A["Input"] --> B["RATEFIX pilih kurs"] --> C["Output"]',
              '    A["Input"] --> B["Pilih kurs"] --> C["Output"]')
s += "\n## 7. Run & Recovery\nBatch harian; restart per window [UNKNOWN — scheduler di luar source set] (src/a.rb:1).\n"
open(p, "w").write(s)
p2 = os.path.join(os.environ["KB"], "modules", "beta.prd.md")
s2 = open(p2).read()
s2 = s2.replace("rebuild_after: [alpha]", "rebuild_after: []")
open(p2, "w").write(s2)
EOF
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 0 ] && pass "fixed fixture (AC + §7 + DAG + declared ref) → PASS" \
  || fail "fixed fixture still FAILs (rc=$grc): $out"

# ── prose pins: negative-claim rail + grammar carriers ───────────────────────
EXTR="plugins/mega-sdd/agents/domain-extractor.md"
VERI="plugins/mega-sdd/agents/claim-verifier.md"
TPL="plugins/mega-sdd/skills/extract-intelligence/references/prd-kontrak-template.md"
grep -q "Negative claims carry their scope" "$EXTR" \
  && pass "extractor carries the negative-claim scope rail" || fail "extractor rail missing"
grep -q "test the scope, not just the letter" "$VERI" \
  && pass "verifier tests negative-claim scope" || fail "verifier rail missing"
grep -q "rebuild_after" "$TPL" && grep -q "Decision-table mandate" "$TPL" \
  && grep -q "### Acceptance criteria" "$TPL" && grep -q "## 7. Run & Recovery" "$TPL" \
  && pass "template carries rebuild_after + decision-table + AC + §7" \
  || fail "template grammar carriers missing"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
