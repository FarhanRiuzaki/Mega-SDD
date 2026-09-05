#!/usr/bin/env bash
# Pin test — KB validators on the 7.6+ census-contracted module grammar
# (7.24.0, spec docs/superpowers/specs/2026-09-05-kb-verify-lane-design.md Fase 1).
#
# Why this exists: extract revamp 7.6.0 moved the KB to
# knowledge-base/modules/<domain>.prd.md (6-section, implicit-verified) but the
# kb_* validators + run-analyze discovery stayed on the legacy tree — every
# post-7.6 KB SKIP'd "no applicable files" while the aggregate reported PASS
# (field-proven on the Host-AS400 KB: real marker-count drift + 8 wrong claims
# behind a green report; research/2026-09-05-megasdd-skillgap-analysis.md §G).
# These pins hold the migration: module grammar validated, legacy grammar
# untouched, discovery sees BOTH layouts.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VKB="$ROOT/plugins/mega-sdd/scripts/validate-kb.sh"
RAN="$ROOT/plugins/mega-sdd/scripts/run-analyze.sh"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

TMP=$(mktemp -d 2>/dev/null || mktemp -d -t kbmod)
trap 'rm -rf "$TMP"' EXIT
KB="$TMP/.mega-sdd/knowledge-base"
mkdir -p "$KB/modules"

# ---- fixtures -----------------------------------------------------------------
cat > "$KB/census.json" <<'EOF'
{"census_version": 1, "file_count": 2, "files": [
  {"path": "src/billing.rb", "lines": 10},
  {"path": "src/helper.rb", "lines": 5}
]}
EOF

# Clean module PRD: 6 sections, counts consistent, both source_files cited,
# every [INFERRED] carries a basis, no [VERIFIED] tag, mermaid fence in §3.
cat > "$KB/modules/billing.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: billing
classification: workflow
depends_on: []
source_files:
  - src/billing.rb
  - src/helper.rb
inferred_count: 1
open_count: 1
locked_count: 1
intent_count: 1
artifact_count: 0
verified_count: 4
---

# PRD — Billing

## 1. Purpose

Billing engine (src/billing.rb:1). Helper util dipakai buat rounding (src/helper.rb:2).

## 2. Business Rules

| ID | Rule | Source | Confidence | Mutability |
|---|---|---|---|---|
| BR-BIL-1 | Invoice total = sum of lines | src/billing.rb:4 | | [LOCKED] |
| BR-BIL-2 | Discount cap 10% | src/billing.rb:7 | [INFERRED] (dasar: satu-satunya call site) | [INTENT] |

## 3. Flow

```mermaid
flowchart TD
    A["Start"] --> B["Sum lines"]
    B --> C["Apply discount"]
```

## 4. Data In/Out

- Input: order lines (src/billing.rb:3)

## 5. Edge Cases & Gotchas

1. Zero-line order returns 0 (src/billing.rb:9).

## 6. Open Questions

- OQ-BIL-1 [P2] — Discount cap 10% dari mana angkanya?
EOF

# Drifted module PRD: locked_count wrong, [VERIFIED] tag present, [INFERRED]
# without basis, one uncited source_files entry, §3 flow arrows w/o fence,
# open_count != OQ entries.
cat > "$KB/modules/broken.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: broken
classification: reference
depends_on: []
source_files:
  - src/billing.rb
  - src/helper.rb
inferred_count: 1
open_count: 2
locked_count: 3
intent_count: 1
artifact_count: 0
verified_count: 1
---

# PRD — Broken

## 1. Purpose

Something about billing (src/billing.rb:1). [VERIFIED]

## 2. Business Rules

| ID | Rule | Source | Confidence | Mutability |
|---|---|---|---|---|
| BR-BRK-1 | Rule with a source | src/billing.rb:4 | [INFERRED] (dasar: call site) | [INTENT] |

## 3. Flow

A --> B --> C

## 4. Data In/Out

_Tidak terdeteksi._

## 5. Edge Cases & Gotchas

1. Kayaknya proses lain yang bersihin record ini [INFERRED]

## 6. Open Questions

- OQ-BRK-1 [P3] — Only one OQ here.
EOF

# Legacy-grammar KB file (old 11-section layout) — regression guard.
mkdir -p "$KB/10-domains"
cat > "$KB/10-domains/old-domain.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: old-domain
verified_count: 1
inferred_count: 0
open_count: 0
---

# Old Domain

## 1. Purpose
x
## 2. Actors
x
## 3. Flow
_None detected_
## 4. Entities
x
## 5. Fields & Validation
x
## 6. Business Rules
One rule [VERIFIED] (src/billing.rb:4)
## 7. Integrations
x
## 8. Edge Cases
N/A
## 9. Rebuild Recommendations
x
## 10. Open Questions
x
## 11. Source Files
- `src/billing.rb`
EOF

run_surface() { # surface file -> echoes exit code; state left in $TMP/.mega-sdd
  bash "$VKB" --surface="$1" --cwd="$TMP" --file-path="$2" --quiet >/dev/null 2>&1
  echo $?
}
state_has() { grep -qF "$2" "$TMP/.mega-sdd/$1" 2>/dev/null; }

# ---- (a) clean module PRD: all four surfaces PASS -----------------------------
[ "$(run_surface output "$KB/modules/billing.prd.md")" = "0" ] \
  && ok "clean module: output PASS" || bad "clean module: output should PASS"
state_has .kb-output-state.json '"six_sections_present"' \
  && ok "output uses six_sections_present for module grammar" \
  || bad "module grammar not detected (six_sections_present check absent)"
state_has .kb-output-state.json 'implicit-default field' \
  && ok "verified/intent counts reported not-recomputable (implicit-default)" \
  || bad "implicit-default SKIP note missing"
[ "$(run_surface citations "$KB/modules/billing.prd.md")" = "0" ] \
  && ok "clean module: citations PASS (source_files cited + census-resolved)" \
  || bad "clean module: citations should PASS"
state_has .kb-citations-state.json '"grammar": "module"' \
  && ok "citations ran the module branch" || bad "citations fell through to legacy §11 branch"
[ "$(run_surface markers "$KB/modules/billing.prd.md")" = "0" ] \
  && ok "clean module: markers PASS" || bad "clean module: markers should PASS"
[ "$(run_surface flows "$KB/modules/billing.prd.md")" = "0" ] \
  && ok "clean module: flows PASS" || bad "clean module: flows should PASS"

# ---- (b) drifted module PRD: each defect class caught -------------------------
[ "$(run_surface output "$KB/modules/broken.prd.md")" = "1" ] \
  && ok "drifted module: output FAIL" || bad "drifted module: output should FAIL"
state_has .kb-output-state.json 'kb_marker_count_mismatch' \
  && ok "locked_count drift caught (kb_marker_count_mismatch)" || bad "count drift NOT caught"
state_has .kb-output-state.json '"field": "open_count"' \
  && ok "open_count vs \$6 OQ-entry drift caught" || bad "open_count drift NOT caught"
[ "$(run_surface markers "$KB/modules/broken.prd.md")" = "1" ] \
  && ok "drifted module: markers FAIL" || bad "drifted module: markers should FAIL"
state_has .kb-markers-state.json 'kb_verified_tag_in_module_grammar' \
  && ok "[VERIFIED] tag in module grammar caught" || bad "[VERIFIED]-tag violation NOT caught"
state_has .kb-markers-state.json 'kb_inferred_without_basis' \
  && ok "[INFERRED] without basis caught" || bad "basisless [INFERRED] NOT caught"
[ "$(run_surface flows "$KB/modules/broken.prd.md")" = "1" ] \
  && ok "drifted module: flows FAIL (arrows outside mermaid fence)" \
  || bad "unfenced flow should FAIL"

# uncited source_files entry: remove helper citation from a copy
sed 's/(src\/helper\.rb:2)//' "$KB/modules/billing.prd.md" > "$KB/modules/uncited.prd.md"
[ "$(run_surface citations "$KB/modules/uncited.prd.md")" = "1" ] \
  && ok "uncited source_files entry FAILs citations" || bad "uncited entry should FAIL"
state_has .kb-citations-state.json 'kb_source_file_uncited' \
  && ok "halt_type kb_source_file_uncited emitted" || bad "kb_source_file_uncited missing"
rm -f "$KB/modules/uncited.prd.md"

# unresolved entry (present in body, absent from census + disk)
sed 's/src\/helper\.rb/src\/ghost.rb/g' "$KB/modules/billing.prd.md" > "$KB/modules/ghost.prd.md"
[ "$(run_surface citations "$KB/modules/ghost.prd.md")" = "1" ] \
  && ok "unresolvable source_files entry FAILs citations" || bad "ghost entry should FAIL"
state_has .kb-citations-state.json 'kb_source_file_unresolved' \
  && ok "halt_type kb_source_file_unresolved emitted" || bad "kb_source_file_unresolved missing"
rm -f "$KB/modules/ghost.prd.md"

# ---- (c) legacy grammar untouched (regression guard) --------------------------
[ "$(run_surface output "$KB/10-domains/old-domain.md")" = "0" ] \
  && ok "legacy 11-section file still PASSes old schema" \
  || bad "legacy grammar regressed"
state_has .kb-output-state.json '"eleven_sections_present"' \
  && ok "legacy file still checked as eleven_sections_present" \
  || bad "legacy file wrongly routed to module schema"
[ "$(run_surface markers "$KB/10-domains/old-domain.md")" = "0" ] \
  && ok "legacy markers surface unchanged ([VERIFIED]+citation passes)" \
  || bad "legacy markers surface regressed"

# ---- (d) run-analyze discovery covers modules/ (glob pins + live aggregate) ---
for pin in "knowledge-base/modules" "files.kb_output" "files.kb_markers" "files.kb_flows"; do
  grep -q "$pin" "$RAN" && ok "run-analyze carries: $pin" || bad "run-analyze missing: $pin"
done
n_mod_globs=$(grep -c 'knowledge-base/modules" -name "\*.prd.md"' "$RAN")
[ "$n_mod_globs" -ge 8 ] \
  && ok "modules glob present at all discovery sites ($n_mod_globs >= 8)" \
  || bad "modules glob under-wired ($n_mod_globs sites, want >=8: 4 aggregate + 3 lists + citations loop)"

# live: full analyze on the fixture tree must NOT skip the kb_* validators
rm -f "$KB/modules/broken.prd.md"   # keep only the clean module + legacy file
bash "$RAN" --cwd="$TMP" >/dev/null 2>&1
REPORT="$TMP/.mega-sdd/CONSISTENCY-REPORT.md"
if [ -f "$REPORT" ]; then
  if grep -E '\| kb_(output|citations|markers|flows) \|' "$REPORT" | grep -q 'SKIP'; then
    bad "aggregate still SKIPs a kb_* validator on a modules/ KB"
  else
    ok "aggregate runs all kb_* validators on a modules/ KB (no SKIP)"
  fi
else
  bad "run-analyze produced no CONSISTENCY-REPORT.md"
fi

# ---- (e) SKIP-honesty (Fase 2): unknown layout → loud kb_discovery FAIL -------
T2=$(mktemp -d 2>/dev/null || mktemp -d -t kbmis)
mkdir -p "$T2/.mega-sdd/knowledge-base/modules-v3"
echo "# future layout" > "$T2/.mega-sdd/knowledge-base/modules-v3/foo.md"
bash "$RAN" --cwd="$T2" >/dev/null 2>&1
R2="$T2/.mega-sdd/CONSISTENCY-REPORT.md"
grep -q "kb_discovery" "$R2" 2>/dev/null && grep -q "MISCONFIGURED" "$R2" 2>/dev/null \
  && ok "unknown KB layout surfaces kb_discovery MISCONFIGURED row" \
  || bad "unknown KB layout still silent (no kb_discovery row)"
grep -q "Overall: FAIL" "$R2" 2>/dev/null \
  && ok "kb_discovery misconfiguration flips Overall to FAIL" \
  || bad "misconfigured KB discovery did not flip Overall"
rm -rf "$T2"

# non-subject files only (README + policy) → NO misconfiguration, quiet SKIP fine
T3=$(mktemp -d 2>/dev/null || mktemp -d -t kbok)
mkdir -p "$T3/.mega-sdd/knowledge-base"
echo "# KB index" > "$T3/.mega-sdd/knowledge-base/README.md"
echo "# policy" > "$T3/.mega-sdd/knowledge-base/data-mutation-policy.md"
bash "$RAN" --cwd="$T3" >/dev/null 2>&1
grep -q "kb_discovery" "$T3/.mega-sdd/CONSISTENCY-REPORT.md" 2>/dev/null \
  && bad "README/policy-only KB wrongly flagged MISCONFIGURED" \
  || ok "non-subject KB files do not trip kb_discovery"
rm -rf "$T3"

echo
if [ "$fail" -eq 0 ]; then echo "PASS kb-modules-grammar pins"; exit 0
else echo "kb-modules-grammar pins FAILED"; exit 1; fi
