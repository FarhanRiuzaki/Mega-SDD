#!/usr/bin/env bash
# test-2a-oq-schema.sh — god-review stage 2, Batch 2A (Critical).
# Pins the OQ-schema realignment in validate-vault-oqs.sh against recurrence.
#
# The pre-fix arm grepped the markdown body for `[tech]` / `mode:` / `scan_target:`
# — a grammar generate-intent NEVER emits (it emits `[tech / scan]` inline + the
# resolution_mode/scan_query/scan_citations/fallback_if_wrong fields in vault.json).
# Consequences it pins: (1) FAIL-OPEN — the three resolution_mode halts never fired
# on a real vault; (2) CRY-WOLF — oq_misclassified_tech false-fired on a correctly
# tagged `[tech / scan]` OQ. Fix = markdown bracket grammar for the mis-tag check +
# vault.json open_questions[] as the structured authority for the mode-dependent halts.
#
# Run: bash tests/god-review-s2/test-2a-oq-schema.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OQ="${ROOT}/plugins/mega-sdd/scripts/validate-vault-oqs.sh"
[ -f "$OQ" ] || { echo "missing $OQ"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t oq2a)"
trap 'rm -rf "$WORK"' EXIT
V="$WORK/.mega-sdd/vaults/tv"
mkdir -p "$V"

# ── Markdown OQ roll-up: mix of correctly-tagged + an untagged tech-text OQ ──
cat > "$V/02-architecture.md" <<'MD'
# Architecture

## Open Questions
- [ ] **OQ-AR-1** [P1] [tech / scan] [conf: high]: which test framework does the repo use? — resolve: scan codebase-map §test_frameworks
- [ ] **OQ-AR-7** [P2] [tech / recommend] [conf: medium]: what HTTP error envelope shape? — resolve: see Auto-Classification Review
- [ ] **OQ-AR-8** [P2] [tech / recommend] [conf: medium]: which logging library? — resolve: see Auto-Classification Review
- [ ] **OQ-AR-9** [P1] [tech] [conf: low]: which caching layer belongs here? — resolve: TBD
- [ ] **OQ-FL-3** [P1] [business] [conf: high]: does the cancellation flow refund prior payments? — resolve: PM/finance team
- [ ] **OQ-XX-1** [P2]: which naming convention should model files use? — resolve: TBD
MD

# ── vault.json structured authority (open_questions[]) ──
cat > "$V/vault.json" <<'JSON'
{
  "open_questions": [
    {"tag":"OQ-AR-1","category":"tech","resolution_mode":"scan","scan_query":"codebase-map §test_frameworks","classification_confidence":"high"},
    {"tag":"OQ-AR-7","category":"tech","resolution_mode":"recommend","recommendation":"Use RFC 7807 problem+json","rationale":"industry standard","scan_citations":["app/Http/ErrorResource.cs:12"],"classification_confidence":"medium"},
    {"tag":"OQ-AR-8","category":"tech","resolution_mode":"recommend","recommendation":"Use structured logger","rationale":"consistency","scan_citations":["src/log.go:3"],"fallback_if_wrong":"revisit if perf regresses","classification_confidence":"medium"},
    {"tag":"OQ-AR-9","category":"tech","classification_confidence":"low"},
    {"tag":"OQ-FL-3","category":"business","resolution_mode":"blocking","classification_confidence":"high"}
  ]
}
JSON

OUT="$(bash "$OQ" --cwd="$WORK" --file-path="$V/02-architecture.md" 2>/dev/null)"

# jhalts <json> → prints "halt_type oq_id" per issue
assert() {
  # $1 = python bool expr over `halts` (list of (halt_type, oq_id, missing)) ; $2 = label
  local expr="$1" label="$2"
  local r
  r="$(OUT="$OUT" python3 -c "
import json,os
st=json.loads(os.environ['OUT'])
halts=[(i.get('halt_type'), i.get('oq_id'), i.get('missing_fields') or []) for i in st.get('issues',[])]
print('PASS' if ($expr) else 'FAIL')
" 2>/dev/null)"
  [ "$r" = "PASS" ] && ok "$label" || fail "$label"
}

note "== 2A: OQ-schema realignment =="

# FAIL-OPEN fixes: the mode-dependent halts now fire off vault.json structured fields
assert "any(h=='oq_tech_missing_mode' and o=='OQ-AR-9' for h,o,m in halts)" \
  "oq_tech_missing_mode fires on a tech OQ with no resolution_mode (OQ-AR-9)"
assert "any(h=='oq_recommend_underspecified' and o=='OQ-AR-7' and 'fallback_if_wrong' in m for h,o,m in halts)" \
  "oq_recommend_underspecified fires + names fallback_if_wrong (OQ-AR-7)"

# CRY-WOLF fixes: correctly-tagged OQs stay quiet
assert "not any(h=='oq_misclassified_tech' and o=='OQ-AR-1' for h,o,m in halts)" \
  "correctly-tagged [tech / scan] OQ does NOT trip oq_misclassified_tech (OQ-AR-1)"
assert "not any(h=='oq_scan_missing_query' for h,o,m in halts)" \
  "scan OQ with scan_query populated does NOT trip oq_scan_missing_query (OQ-AR-1)"
assert "not any(h=='oq_recommend_underspecified' and o=='OQ-AR-8' for h,o,m in halts)" \
  "fully-specified recommend OQ does NOT over-fire (OQ-AR-8)"
assert "not any(h=='oq_tech_missing_mode' and o in ('OQ-AR-1','OQ-AR-7','OQ-AR-8') for h,o,m in halts)" \
  "tech OQs WITH resolution_mode do NOT trip oq_tech_missing_mode"

# Mis-tag advisory still works on a genuinely untagged tech-text OQ
assert "any(h=='oq_misclassified_tech' and o=='OQ-XX-1' for h,o,m in halts)" \
  "untagged tech-text OQ still trips oq_misclassified_tech (OQ-XX-1)"

# business OQ stays quiet
assert "not any(o=='OQ-FL-3' for h,o,m in halts)" \
  "business OQ produces no schema issue (OQ-FL-3)"

# REGRESSION guard: the pre-fix phantom grammar keyed on `mode:`/`scan_target:` lines —
# assert the fix does NOT depend on those (a vault with NO such lines still validates).
assert "not any('mode:' in (h or '') for h,o,m in halts)" \
  "no dependence on markdown mode:/scan_target: lines (phantom grammar retired)"

if [ "$FAILED" -eq 0 ]; then note "ALL 2A OK"; else note "2A had failures"; fi
exit $FAILED
