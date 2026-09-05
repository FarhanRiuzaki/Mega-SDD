#!/usr/bin/env bash
# Pin test — claim-verify lane enforcement (7.25.0, spec
# docs/superpowers/specs/2026-09-05-kb-verify-lane-design.md Fase 3).
#
# The lane's ENFORCEMENT is deterministic: write-verify-state.sh is the one
# writer of <kb>/.verify/<domain>.json (parses the agent's VERIFY REPORT,
# refuses inconsistent reports), and validate-extract-census.sh RECOMPUTES
# LOCKED coverage + the sample floor from each PRD body (B1 pattern) so a
# missing, failing, under-scoped, or forged verify state cannot hand off.
# The model side (does the verifier actually CATCH a seeded inversion) is a
# live-run acceptance item, not suite-testable — recorded in the spec.
# Run: bash tests/extract-census/test-claim-verify-gate.sh </dev/null

set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
GATE="plugins/mega-sdd/scripts/validate-extract-census.sh"
WRITER="plugins/mega-sdd/scripts/write-verify-state.sh"
AGENT="plugins/mega-sdd/agents/claim-verifier.md"
SKILL="plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
REF="plugins/mega-sdd/skills/extract-intelligence/references/claim-verify.md"

rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
KB="$TMP/kb"
mkdir -p "$KB/modules"

cat > "$KB/census.json" <<'EOF'
{"census_version":1,"file_count":1,"files":[{"path":"lib/money.php","lines":9}]}
EOF
cat > "$KB/modules/money.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: money
classification: workflow
source_files:
  - lib/money.php
---
# PRD — Money

## 1. Purpose
Rounding engine (lib/money.php:2).

## 2. Business Rules
| ID | Rule | Source | Confidence | Mutability |
|---|---|---|---|---|
| BR-M-1 | Round half-up to 2dp | lib/money.php:4 | | [LOCKED] |
| BR-M-2 | Negative amounts flip sign | lib/money.php:6 | | [INTENT] |

## 3. Flow
_Tidak terdeteksi._

## 4. Data In/Out
Input amounts (lib/money.php:3).

## 5. Edge Cases & Gotchas
1. Zero passthrough (lib/money.php:8).

## 6. Open Questions
_Tidak ada._
EOF

# ── (1) no verify state → claim_verify_missing ────────────────────────────────
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$out" | grep -q "claim_verify_missing" \
  && pass "missing .verify/<domain>.json → FAIL claim_verify_missing" \
  || fail "claim_verify_missing not raised (rc=$grc): $out"

# ── (2) writer refuses inconsistent reports ───────────────────────────────────
printf 'no report here\n' | bash "$WRITER" --kb-dir="$KB" --quiet 2>/dev/null \
  && fail "writer accepted input without a VERIFY REPORT block" \
  || pass "writer rejects input without VERIFY REPORT block"
bash "$WRITER" --kb-dir="$KB" --quiet 2>/dev/null <<'EOF' \
  && fail "writer accepted wrong=0 with WRONG finding lines" \
  || pass "writer rejects wrong-count vs findings inconsistency"
VERIFY REPORT
- module: money
- locked_total: 1
- locked_checked: 1
- money_checked: 1
- sampled: 8
- exact: 9
- imprecise: 0
- wrong: 0
- wrong_load_bearing: 0
- findings:
  - BR-M-2 | WRONG | sign is NOT flipped | lib/money.php:6
EOF
[ ! -f "$KB/.verify/money.json" ] && pass "rejected reports write no state" \
  || fail "rejected report still wrote state"

# ── (3) failing verify (wrong_load_bearing>0) → claim_verify_failed ───────────
bash "$WRITER" --kb-dir="$KB" --quiet <<'EOF' || fail "writer refused a valid failing report"
VERIFY REPORT
- module: money
- locked_total: 1
- locked_checked: 1
- money_checked: 1
- sampled: 8
- exact: 8
- imprecise: 0
- wrong: 2
- wrong_load_bearing: 1
- findings:
  - BR-M-1 | WRONG | code truncates, does not round | lib/money.php:4
  - BR-M-2 | WRONG | sign flip is for POSITIVE amounts | lib/money.php:6
EOF
python3 -c "import json;d=json.load(open('$KB/.verify/money.json'));assert d['status']=='FAIL' and d['wrong_load_bearing']==1" \
  && pass "failing report recorded status FAIL" || fail "failing report state wrong"
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$out" | grep -q "claim_verify_failed" \
  && pass "wrong_load_bearing>0 → FAIL claim_verify_failed" \
  || fail "claim_verify_failed not raised (rc=$grc): $out"

# ── (4) under-scoped report (LOCKED short / below sample floor) → incomplete ──
bash "$WRITER" --kb-dir="$KB" --quiet <<'EOF' >/dev/null || fail "writer refused under-scoped report"
VERIFY REPORT
- module: money
- locked_total: 0
- locked_checked: 0
- money_checked: 0
- sampled: 1
- exact: 1
- imprecise: 0
- wrong: 0
- wrong_load_bearing: 0
- findings: none
EOF
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 1 ] && echo "$out" | grep -q "claim_verify_incomplete" \
  && pass "under-scoped verify (recomputed LOCKED + floor) → claim_verify_incomplete" \
  || fail "claim_verify_incomplete not raised (rc=$grc): $out"

# ── (5) clean, fully-scoped report → gate PASS ────────────────────────────────
bash "$WRITER" --kb-dir="$KB" --quiet <<'EOF' || fail "writer refused clean report"
VERIFY REPORT
- module: money
- locked_total: 1
- locked_checked: 1
- money_checked: 2
- sampled: 8
- exact: 11
- imprecise: 0
- wrong: 0
- wrong_load_bearing: 0
- findings: none
EOF
out=$(bash "$GATE" --kb-dir="$KB" </dev/null 2>&1); grc=$?
[ "$grc" -eq 0 ] && pass "clean fully-scoped verify state → gate PASS" \
  || fail "expected PASS with clean verify state (rc=$grc): $out"

# ── (6) wiring pins: agent + skill + reference + model tier ───────────────────
grep -q "^name: claim-verifier" "$AGENT" && pass "claim-verifier agent exists" || fail "agent missing"
grep -q "^tools: Read, Grep, Glob, Bash$" "$AGENT" && pass "agent is read-only toolset" || fail "agent tools drifted"
grep -q "AskUserQuestion" "$AGENT" && fail "agent references AskUserQuestion (subagent-unavailable)" \
  || pass "agent never references AskUserQuestion"
grep -q "VERIFY REPORT" "$AGENT" && pass "agent carries the VERIFY REPORT contract" || fail "REPORT block missing from agent"
grep -q "claim-verifier" "$SKILL" && grep -q "write-verify-state.sh" "$SKILL" \
  && pass "SKILL.md dispatches the lane + the deterministic writer" || fail "SKILL.md wiring missing"
grep -q "claim_verify_failed" "$SKILL" && pass "SKILL.md carries the twice-failed halt subtype" || fail "halt subtype missing"
grep -q "extract-intelligence-verify" "$REF" && pass "reference names the model-tier role" || fail "tier role missing in reference"
grep -q "extract-intelligence-verify" "plugins/mega-sdd/references/model-tiers.md" \
  && pass "model-tiers catalog carries extract-intelligence-verify" || fail "model-tiers row missing"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
