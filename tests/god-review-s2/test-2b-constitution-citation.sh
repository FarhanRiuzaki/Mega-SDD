#!/usr/bin/env bash
# test-2b-constitution-citation.sh — god-review stage 2, Batch 2B (Critical).
# Pins the per-clause source-citation check in validate-constitution.sh.
#
# The rail "constitution clauses MUST cite source" (vault-core.md §constitution)
# was enforced by NOTHING — the shipped schema example modelled ~17/20 clauses uncited
# incl. invented NFRs (median < 200ms). Because a clause is injected into each unit's
# `## Hard rules` as a severity:error BLOCKING gate at execute-bolts, an uncited /
# defaulted clause enforces fabrication as ground truth. This pins: uncited clause →
# FAIL (naming it); fully-cited clause → PASS across every source form; and — because
# the constitution follows the vault's input language — the check is LANGUAGE-INVARIANT
# (fires + clears on an Indonesian constitution the same way).
#
# Run: bash tests/god-review-s2/test-2b-constitution-citation.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VC="${ROOT}/plugins/mega-sdd/scripts/validate-constitution.sh"
[ -f "$VC" ] || { echo "missing $VC"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t con2b)"
trap 'rm -rf "$WORK"' EXIT

mkvault() { # $1=cwd-subdir $2=constitution-body
  local d="$WORK/$1/.mega-sdd/vaults/tv"
  mkdir -p "$d"
  printf '%s\n' "$2" > "$d/constitution.md"
}

# ── bad-en: A-002 invented NFR + A-003 defaulted best-practice → uncited.
#    Uses the BOLD `- **A-NNN**:` clause format (as real vaults emit) so the bold
#    anchor path is exercised in the FIRE case — the pre-fix regex fail-opened on it. ──
mkvault bad-en '# Project Constitution

## §A. Coding standards
- **A-001**: All endpoints require the auth middleware (source: PRD §security)
- **A-002**: API response time median < 200ms
- **A-003**: Naming uses PascalCase for classes

## §E. Performance
- **E-001**: Background jobs < 30s'

# ── good-en: every clause cited via a DIFFERENT source form ──
mkvault good-en '# Project Constitution

## §A. Coding standards
- A-001: All endpoints require the auth middleware (source: PRD §security)
- A-002: Latency median < 200ms per SLA (source: 06-constraints.md §nfr)
- A-003: Follow the base pattern in src/Core/BaseService.cs:12
- A-004: Audit rule per the regulator (see https://regulator.example/rule-12)

## §D. Anti-patterns
- D-001: NEVER replicate the legacy customer-edit typo [[knowledge-base/critical-findings]]'

# ── good-id: Indonesian constitution, all clauses cited (language-invariant accept) ──
mkvault good-id '# Konstitusi Proyek

## §A. Standar Koding
- A-001: Semua endpoint wajib memakai middleware autentikasi (source: PRD §keamanan)
- A-002: Target latensi median < 200ms sesuai SLA (source: 06-constraints.md §nfr)'

# ── bad-id: Indonesian uncited clause (language-invariant fire) ──
mkvault bad-id '# Konstitusi Proyek

## §A. Standar Koding
- A-001: Semua endpoint wajib memakai middleware autentikasi (source: PRD §keamanan)
- A-002: Waktu respons API rata-rata di bawah 200ms'

run() { bash "$VC" --cwd="$WORK/$1" 2>/dev/null; }

# probe <json> <python-expr-over `d`> → prints result
probe() { python3 -c "
import json,os
d=json.loads(os.environ['J'])
print($1)
" 2>/dev/null; }

note "== 2B: constitution per-clause source citation =="

# bad-en: FAIL, names the uncited clauses, does NOT flag the cited A-001
J="$(run bad-en)"; export J
[ "$(probe "d.get('status')")" = "FAIL" ] && ok "bad-en → status FAIL" || fail "bad-en should FAIL"
unc="$(probe "','.join(sorted(set(sum([i.get('sample_uncited',[]) for i in d.get('issues',[]) if i.get('halt_type')=='constitution_clause_uncited'],[]))))")"
case "$unc" in
  *A-002*A-003*E-001*) ok "bad-en names uncited A-002,A-003,E-001 ($unc)";;
  *) fail "bad-en sample_uncited wrong: '$unc'";;
esac
[ "$(probe "any('A-001' in i.get('sample_uncited',[]) for i in d.get('issues',[]) if i.get('halt_type')=='constitution_clause_uncited')")" = "False" ] \
  && ok "bad-en does NOT flag the cited A-001" || fail "bad-en wrongly flagged A-001"

# good-en: PASS across all 5 source forms (§, (source:), file:line, URL, [[wikilink]])
J="$(run good-en)"; export J
[ "$(probe "d.get('status')")" = "PASS" ] && ok "good-en → status PASS (all source forms accepted)" || fail "good-en should PASS: $(probe "[c for c in d.get('checks',[]) if c.get('status')=='FAIL']")"
[ "$(probe "any(i.get('halt_type')=='constitution_clause_uncited' for i in d.get('issues',[]))")" = "False" ] \
  && ok "good-en emits no constitution_clause_uncited" || fail "good-en wrongly emitted uncited"

# good-id: Indonesian, all cited → PASS (proves check is NOT English-keyed)
J="$(run good-id)"; export J
[ "$(probe "d.get('status')")" = "PASS" ] && ok "good-id (Indonesian, cited) → PASS — language-invariant accept" || fail "good-id should PASS"

# bad-id: Indonesian uncited → FAIL (proves check fires regardless of language)
J="$(run bad-id)"; export J
[ "$(probe "d.get('status')")" = "FAIL" ] && ok "bad-id (Indonesian, uncited A-002) → FAIL — language-invariant fire" || fail "bad-id should FAIL"

# ── round-2 (review): a casual parenthetical is NOT a citation ──
mkvault casual '# Project Constitution

## §A. Coding standards
- **A-001**: All endpoints require auth (source: PRD §security)
- **A-002**: Follow the login flow (see the diagram) and keep it simple'
J="$(run casual)"; export J
[ "$(probe "d.get('status')")" = "FAIL" ] && ok "r2: casual '(see the diagram)' is NOT a source → A-002 flagged" || fail "r2: casual parenthetical wrongly counted as cited"
[ "$(probe "any('A-002' in i.get('sample_uncited',[]) for i in d.get('issues',[]) if i.get('halt_type')=='constitution_clause_uncited')")" = "True" ] \
  && ok "r2: A-002 named uncited" || fail "r2: A-002 should be uncited"

# ── round-2: heading-format clause must be checked (not a vacuous PASS) ──
mkvault heading '# Project Constitution

### A-001
A rule stated as a heading-style clause with no source anchor at all.'
J="$(run heading)"; export J
case "$(probe "d.get('status')")" in
  FAIL) ok "r2: heading-format '### A-001' clause is checked → FAIL (no vacuous PASS)";;
  *) fail "r2: heading-format clause should be FAIL, got $(probe "d.get('status')")";;
esac

if [ "$FAILED" -eq 0 ]; then note "ALL 2B OK"; else note "2B had failures"; fi
exit $FAILED
