#!/usr/bin/env bash
# test-validator-hardening.sh — Batch 1 tech-agnostic validator hardening from the
# god-review of extract-intelligence (research/2026-07-01-god-review-extract-intelligence.md).
# Pins H1, M4, M5, M6, M7, L4, L5 against recurrence with a MULTI-STACK fixture matrix
# (C#/Go/Java/Rust/Python × GDPR/HIPAA/PCI + a non-regulatory clean domain), because
# each defect is one-codebase-tuning that fails-open / no-ops on every other stack.
#
# Run: bash tests/tech-agnostic/test-validator-hardening.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
S="${ROOT}/plugins/mega-sdd/scripts"
CIT="$S/validate-kb.sh"
CIT_FLAGS="--surface=citations"
MRK="$S/validate-kb.sh"
MRK_FLAGS="--surface=markers"
LEAK="$S/kb-leak-scan.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
for f in "$CIT" "$MRK" "$LEAK"; do [ -f "$f" ] || { fail "missing $f"; exit 1; }; done

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t vhard)"
trap 'rm -rf "$WORK"' EXIT
jget() { python3 -c "import json,sys
try: print($2)
except Exception as e: print('ERR:'+str(e))" <<< "$1" 2>/dev/null; }

# ── H1: citation extension whitelist — C#/.NET §11 must NOT SKIP-green ─────────
note '=== H1: C#/Kotlin/TSX §11 citations are EXTRACTED (no fail-open SKIP) ==='
H="$WORK/h1/.mega-sdd/knowledge-base/10-domains"; mkdir -p "$H"
printf '%s\n' '# 1. Purpose [VERIFIED]
## 11. Source References
- `Services/OrderService.cs:45`
- `ui/App.tsx:3`
- `Model.kt:9`' > "$H/order.md"
R=$(bash "$CIT" $CIT_FLAGS --cwd="$WORK/h1" --file-path="$H/order.md" 2>/dev/null)
TC=$(jget "$R" "json.load(sys.stdin).get('total_citations')")
ST=$(jget "$R" "json.load(sys.stdin).get('status')")
note "  status=$ST total_citations=$TC"
[ "$TC" = "3" ] && ok ".cs/.tsx/.kt all extracted (was 0 → SKIP-green)" || fail "expected 3 citations, got '$TC'"
[ "$ST" != "SKIP" ] && ok "not a fail-open SKIP (status=$ST)" || fail "still SKIP-green"

# H1b: 0 citations + [VERIFIED] → WARN; N/A §11 → SKIP
NA="$WORK/h1b/.mega-sdd/knowledge-base/10-domains"; mkdir -p "$NA"
printf '%s\n' '# 1. Purpose [VERIFIED]
## 11. Source References
per BI Regulation 23.2:2021 (no file)' > "$NA/x.md"
W=$(jget "$(bash "$CIT" $CIT_FLAGS --cwd="$WORK/h1b" --file-path="$NA/x.md" 2>/dev/null)" "json.load(sys.stdin).get('status')")
[ "$W" = "WARN" ] && ok "0-citations-in-grounded-KB → WARN (not silent SKIP)" || fail "expected WARN, got '$W'"
printf '%s\n' '# 1. Purpose [VERIFIED]
## 11. Source References
_None detected_' > "$NA/y.md"
NAS=$(jget "$(bash "$CIT" $CIT_FLAGS --cwd="$WORK/h1b" --file-path="$NA/y.md" 2>/dev/null)" "json.load(sys.stdin).get('status')")
[ "$NAS" = "SKIP" ] && ok "N/A §11 exempt → SKIP (not WARN)" || fail "expected SKIP on N/A, got '$NAS'"

# ── M7: per-claim gate rejects regulation/version/time tokens ──────────────────
note ''
note '=== M7: [VERIFIED] citing ONLY a regulation/version/time token → uncited ==='
M="$WORK/m7/.mega-sdd/knowledge-base/10-domains"; mkdir -p "$M"
printf '%s\n' '# 1. Purpose
## 7. Business Rules
| ID | Rule | Src | Conf |
|---|---|---|---|
| R1 | Cap per BI 23.2:2021 [VERIFIED] |  | [VERIFIED] |
| R2 | Fee logic in Services/Fee.cs:45 [VERIFIED] |  | [VERIFIED] |
## 11. Source References
- `Services/Fee.cs:45`' > "$M/r.md"
R=$(bash "$MRK" $MRK_FLAGS --cwd="$WORK/m7" --file-path="$M/r.md" 2>/dev/null)
UC=$(jget "$R" "json.load(sys.stdin).get('verified_uncited')")
CI=$(jget "$R" "json.load(sys.stdin).get('verified_cited')")
note "  cited=$CI uncited=$UC"
[ "$UC" = "1" ] && ok "regulation-only claim flagged uncited" || fail "expected 1 uncited, got '$UC'"
[ "$CI" = "1" ] && ok "real .cs cite still counts as cited" || fail "expected 1 cited, got '$CI'"

# ── L4 + L5: Oracle tokens + --stack=all unions target idioms ──────────────────
note ''
note '=== L4+L5: Oracle DDL leak + C# target-idiom via --stack=all ==='
LK="$WORK/l4/knowledge-base/10-domains"; mkdir -p "$LK"
printf '%s\n' '# Order
id NUMBER(10) in Oracle, name VARCHAR2(200), notes NCLOB.
target leaks IServiceCollection and [HttpGet].' > "$LK/o.md"
OUT=$(bash "$LEAK" --kb-dir="$WORK/l4" --stack=all 2>&1)
echo "$OUT" | grep -q "VARCHAR2\|Oracle\|NUMBER(" && ok "Oracle DDL token detected (L4)" || fail "Oracle token missed"
echo "$OUT" | grep -q "IServiceCollection" && ok "C# target-idiom detected via --stack=all (L5)" || fail "target idiom missed"

# ── M6: SCAN_DIRS + section-awareness ─────────────────────────────────────────
note ''
note '=== M6: 40-business-rules + 99-rebuild scanned; Source cell + Departures skipped ==='
BR="$WORK/m6/knowledge-base/40-business-rules"; RB="$WORK/m6/knowledge-base/99-rebuild-architecture"
mkdir -p "$BR" "$RB"
printf '%s\n' '# Business Rules
| ID | Rule | Source | Mut |
|---|---|---|---|
| R1 | never negative | app/MySQLHelper.php:4 | [LOCKED] |
| R2 | saved via Eloquent scopes | app/O.php:1 | [LOCKED] |' > "$BR/rules.md"
printf '%s\n' '# Rebuild
persists via a DbContext per write.
## Departures from Legacy
was Laravel Eloquent; target .NET with MSSQL.' > "$RB/a.md"
OUT=$(bash "$LEAK" --kb-dir="$WORK/m6" --stack=all 2>&1)
echo "$OUT" | grep -q "R2 | saved via Eloquent" && ok "rule-text leak (Eloquent) flagged in 40-business-rules" || fail "rule-text leak missed (dir not scanned?)"
echo "$OUT" | grep -q "DbContext" && ok "99-rebuild body leak flagged" || fail "rebuild-body leak missed"
echo "$OUT" | grep -q "MySQLHelper" && fail "Source-cell path wrongly flagged (not section-aware)" || ok "Source-cell legacy path NOT flagged"
echo "$OUT" | grep -qi "Laravel\|MSSQL\|Entity Framework" && fail "Departures-from-Legacy wrongly flagged" || ok "Departures-from-Legacy section NOT flagged"

# ── M4: multi-ecosystem legacy-root auto-detect + ambiguous multi-hit ──────────
note ''
note '=== M4: Go/.NET auto-detect + recursive basename + ambiguous multi-hit ==='
G="$WORK/m4go"; mkdir -p "$G/_source/internal/order" "$G/.mega-sdd/knowledge-base/10-domains"
touch "$G/_source/go.mod" "$G/_source/internal/order/handler.go"
printf '%s\n' '# 1. Purpose [VERIFIED]
## 11. Source References
- `handler.go:12`' > "$G/.mega-sdd/knowledge-base/10-domains/o.md"
GS=$(jget "$(bash "$CIT" $CIT_FLAGS --cwd="$G" --file-path="$G/.mega-sdd/knowledge-base/10-domains/o.md" 2>/dev/null)" "json.load(sys.stdin).get('status')")
[ "$GS" = "PASS" ] && ok "Go legacy (go.mod) auto-detected + nested basename resolved" || fail "Go resolve expected PASS, got '$GS'"
A="$WORK/m4amb"; mkdir -p "$A/_source/a" "$A/_source/b" "$A/.mega-sdd/knowledge-base/10-domains"
touch "$A/_source/composer.json" "$A/_source/a/User.php" "$A/_source/b/User.php"
printf '%s\n' '# 1. Purpose [VERIFIED]
## 11. Source References
- `User.php:10`' > "$A/.mega-sdd/knowledge-base/10-domains/u.md"
AR=$(bash "$CIT" $CIT_FLAGS --cwd="$A" --file-path="$A/.mega-sdd/knowledge-base/10-domains/u.md" 2>/dev/null)
AMB=$(jget "$AR" "json.load(sys.stdin).get('ambiguous')")
AST=$(jget "$AR" "json.load(sys.stdin).get('status')")
[ "$AMB" = "1" ] && [ "$AST" = "FAIL" ] && ok "ambiguous basename (2 paths) → NOT resolved (FAIL)" || fail "ambiguous expected FAIL/1, got status=$AST amb=$AMB"

# (M5 arms removed v7 Fase 2 — audit-domain-rules.sh demoted to an analyze LLM instruction.)

# ── Review-round fixes (adversarial pass) ─────────────────────────────────────
note ''
note '=== R1: backtick-wrapped reg token [VERIFIED] -> UNCITED (check-3 removed) ==='
BK="$WORK/r1/.mega-sdd/knowledge-base/10-domains"; mkdir -p "$BK"
printf '%s\n' '## 7. Rules
- Cap per BI `23.2:2021` [VERIFIED]
- Real `Services/Fee.cs:45` [VERIFIED]
## 11. Source References
- `Services/Fee.cs:45`' > "$BK/r.md"
R=$(bash "$MRK" $MRK_FLAGS --cwd="$WORK/r1" --file-path="$BK/r.md" 2>/dev/null)
[ "$(jget "$R" "json.load(sys.stdin).get('verified_uncited')")" = "1" ] && ok "backtick-wrapped reg token flagged uncited (dominant path)" || fail "backtick reg token wrongly CITED (check-3 hole)"

note ''
note '=== R2: extensionless source citation (Gemfile:3) resolves ==='
EX="$WORK/r2"; mkdir -p "$EX/_source" "$EX/.mega-sdd/knowledge-base/10-domains"
printf 'gem rails\n\n\n' > "$EX/_source/Gemfile"
printf '# P [VERIFIED]\n## 11. Source References\n- `Gemfile:3`\n' > "$EX/.mega-sdd/knowledge-base/10-domains/g.md"
R=$(bash "$CIT" $CIT_FLAGS --cwd="$EX" --file-path="$EX/.mega-sdd/knowledge-base/10-domains/g.md" 2>/dev/null)
[ "$(jget "$R" "json.load(sys.stdin).get('status')")" = "PASS" ] && ok "Gemfile:3 extensionless citation resolves (tech-agnostic)" || fail "extensionless source citation not resolved"

note ''
note '=== R3: §11 prose-wrapped citation extracts the PATH, not the first word ==='
PW="$WORK/r3"; mkdir -p "$PW/_source" "$PW/.mega-sdd/knowledge-base/10-domains"
touch "$PW/_source/config.yaml"
printf '# P [VERIFIED]\n## 11. Source References\n- see `config.yaml:3` for detail\n' > "$PW/.mega-sdd/knowledge-base/10-domains/p.md"
R=$(bash "$CIT" $CIT_FLAGS --cwd="$PW" --file-path="$PW/.mega-sdd/knowledge-base/10-domains/p.md" 2>/dev/null)
[ "$(jget "$R" "len(json.load(sys.stdin).get('broken_citations',[]))")" = "0" ] && ok "prose-wrapped span extracts config.yaml (not 'see')" || fail "prose span mis-extracted → false broken"

note ''
note '=== R4: kb-leak data-row "source of funds" does NOT hide a later-row leak ==='
LR="$WORK/r4/knowledge-base/30-data-model"; mkdir -p "$LR"
printf '%s\n' '# Data
| Field | Notes |
|---|---|
| amount | the source of funds check |
| balance | stored as VARCHAR2 in the ledger |' > "$LR/d.md"
OUT=$(bash "$LEAK" --kb-dir="$WORK/r4" --stack=all 2>&1)
echo "$OUT" | grep -q "VARCHAR2" && ok "leak in later row NOT hidden by data-row 'source' (header needs separator)" || fail "data-row 'source' hijacked source_col and HID the leak"

note ''
# (R5 arm removed with M5 — same demoted validator.)

note ''
[ "$FAILED" -eq 0 ] && note "tech-agnostic hardening: all assertions passed." || note "tech-agnostic hardening: FAILURES above."
exit $FAILED
