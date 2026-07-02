#!/usr/bin/env bash
# test-2d-correctness.sh — god-review stage 2, Batch 2D (Med/Low).
#   H2  no-defaulted-standards POSITIVE detection: a WCAG/Material/palette-token value
#       shipped with no source citation (and no Design-Source OQ) → advisory
#       defaulted_standard_uncited. Rail-2 only checked the inverse before.
#   M1  Mermaid mandate no longer keyed solely on `### F-<prefix>-NNN`: a non-F-prefix
#       flow heading (`### User Login`) with no mermaid is now caught; structural
#       headings (Notes/Sources) are not mistaken for flows.
#   L1  validate-vault-binding-coverage advisory findings → WARN/exit 0 (was FAIL/exit 1).
#
# Run: bash tests/god-review-s2/test-2d-correctness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OQ="${ROOT}/plugins/mega-sdd/scripts/validate-vault-oqs.sh"
VF="${ROOT}/plugins/mega-sdd/scripts/validate-vault-flows.sh"
BC="${ROOT}/plugins/mega-sdd/scripts/validate-vault-binding-coverage.sh"
for f in "$OQ" "$VF" "$BC"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t corr2d)"
trap 'rm -rf "$WORK"' EXIT

hset() { OUT="$1" python3 -c "
import json,os
try: st=json.loads(os.environ['OUT']); print(' '.join(i.get('halt_type','') for i in st.get('issues',[])))
except Exception: print('ERR')"; }

note "== 2D: smaller correctness =="

# ── H2: defaulted design standard with no source ──
mkh2() {  # $1=sub  $2=02-arch body
  local d="$WORK/$1/.mega-sdd/vaults/tv"; mkdir -p "$d"
  printf '### F-U-001: View\n```mermaid\nflowchart TD\n  A --> B\n```\n' > "$d/04-flows.md"
  printf '%s\n' "$2" > "$d/02-architecture.md"
  printf '{"open_questions":[]}\n' > "$d/vault.json"
}
mkh2 h2-bad '# Architecture

The interface targets WCAG 2.1 AA and uses bg-blue-500 for primary actions.'
H2B="$(hset "$(bash "$OQ" --cwd="$WORK/h2-bad" --file-path="$WORK/h2-bad/.mega-sdd/vaults/tv/04-flows.md" 2>/dev/null)")"
case "$H2B" in
  *defaulted_standard_uncited*) ok "H2: uncited WCAG/palette value → defaulted_standard_uncited";;
  *) fail "H2: should flag uncited defaulted standard: '$H2B'";;
esac

mkh2 h2-good '# Architecture

The interface targets WCAG 2.1 AA (source: PRD §accessibility) for primary actions.'
H2G="$(hset "$(bash "$OQ" --cwd="$WORK/h2-good" --file-path="$WORK/h2-good/.mega-sdd/vaults/tv/04-flows.md" 2>/dev/null)")"
case "$H2G" in
  *defaulted_standard_uncited*) fail "H2: cited standard should NOT be flagged: '$H2G'";;
  *) ok "H2: WCAG value WITH a (source: …) on its line → quiet";;
esac

# ── M1: Mermaid mandate on a non-F-prefix flow heading ──
d="$WORK/m1/.mega-sdd/vaults/tv"; mkdir -p "$d"
cat > "$d/04-flows.md" <<'MD'
# Flows

### User Login
The user enters credentials and submits the form. No diagram here.

### Notes
Some scratch notes — not a flow, must be ignored.

### F-U-002: Checkout
```mermaid
flowchart TD
  A[Start] --> B[Done]
```

## Sources
- some ref
MD
M1OUT="$(bash "$VF" --cwd="$WORK/m1" --file-path="$d/04-flows.md" 2>/dev/null)"
M1="$(OUT="$M1OUT" python3 -c "
import json,os
st=json.loads(os.environ['OUT'])
ids=[(i.get('halt_type'), i.get('flow_id')) for i in st.get('issues',[])]
print('|'.join(f'{h}:{fid}' for h,fid in ids))")"
case "$M1" in
  *vault_flow_not_mermaid:User\ Login*) ok "M1: non-F-prefix flow 'User Login' with no mermaid is now caught";;
  *) fail "M1: non-F-prefix flow should be caught: '$M1'";;
esac
case "$M1" in
  *:Notes*|*:Sources*) fail "M1: a structural heading was mistaken for a flow: '$M1'";;
  *) ok "M1: structural headings (Notes/Sources) not treated as flows";;
esac
case "$M1" in
  *F-U-002*) fail "M1: F-U-002 has a mermaid diagram, should not be flagged: '$M1'";;
  *) ok "M1: F-prefix flow with a mermaid diagram stays quiet";;
esac

# ── L1: binding-coverage advisory → WARN / exit 0 (was FAIL / exit 1) ──
d="$WORK/l1/.mega-sdd/vaults/tv"; mkdir -p "$d"
printf '# Architecture\n\n## §payment-service\n\nDetails.\n' > "$d/02-architecture.md"
printf '# Binding\n\nNothing references that section id here.\n' > "$d/binding.md"
BCOUT="$(bash "$BC" --cwd="$WORK/l1" 2>/dev/null)"; BCEXIT=$?
BCSTATUS="$(OUT="$BCOUT" python3 -c "import json,os;print(json.loads(os.environ['OUT']).get('status'))" 2>/dev/null)"
BCHALT="$(hset "$BCOUT")"
case "$BCHALT" in
  *vault_binding_coverage_gap*) ok "L1: coverage gap detected (advisory)";;
  *) fail "L1: expected a coverage gap issue: '$BCHALT'";;
esac
[ "$BCEXIT" = "0" ] && ok "L1: advisory finding exits 0 (was 1)" || fail "L1: expected exit 0, got $BCEXIT"
[ "$BCSTATUS" = "WARN" ] && ok "L1: status WARN (not FAIL)" || fail "L1: expected status WARN, got '$BCSTATUS'"

# ── H2 round-2 (review): bare 'WCAG AA' (no version), Material-ERP non-fire, 05/06 corpus ──
mkfull() {  # $1=sub  $2=02  $3=03  $4=05  $5=06  $6=vault.json
  local d="$WORK/$1/.mega-sdd/vaults/tv"; mkdir -p "$d"
  printf '### F-U-001: View\n```mermaid\nflowchart TD\n  A --> B\n```\n' > "$d/04-flows.md"
  printf '%s\n' "$2" > "$d/02-architecture.md"
  printf '%s\n' "$3" > "$d/03-data-model.md"
  printf '%s\n' "$4" > "$d/05-decisions.md"
  printf '%s\n' "$5" > "$d/06-constraints.md"
  printf '%s\n' "$6" > "$d/vault.json"
}
runf() { hset "$(bash "$OQ" --cwd="$WORK/$1" --file-path="$WORK/$1/.mega-sdd/vaults/tv/04-flows.md" 2>/dev/null)"; }

# bare 'WCAG AA' (no version) — the plugin's own canonical phrasing — must fire
mkfull h2-bare '# Arch

The interface targets WCAG AA for interactive controls.' '# Data' '# Decisions' '# Constraints' '{"open_questions":[]}'
case "$(runf h2-bare)" in *defaulted_standard_uncited*) ok "H2 r2: bare 'WCAG AA' (no version) now fires";; *) fail "H2 r2: bare WCAG AA missed";; esac

# 'Material 3' in an ERP/warehouse domain must NOT fire (domain-agnosticism)
mkfull h2-erp '# Arch' '# Data

The warehouse tracks Material 3 inventory per SKU; each Material 3 batch is reconciled nightly.' '# Decisions' '# Constraints' '{"open_questions":[]}'
case "$(runf h2-erp)" in *defaulted_standard_uncited*) fail "H2 r2: 'Material 3' ERP domain false-fired";; *) ok "H2 r2: bare 'Material 3' (ERP) does NOT fire — domain-agnostic";; esac

# defaulted standard living in 06-constraints.md (the NFR home) must be caught
mkfull h2-06 '# Arch' '# Data' '# Decisions' '# Constraints

NFR: the app must meet WCAG 2.1 AAA across all screens.' '{"open_questions":[]}'
case "$(runf h2-06)" in *defaulted_standard_uncited*) ok "H2 r2: defaulted standard in 06-constraints.md is caught (corpus widened)";; *) fail "H2 r2: 06-constraints standard escaped";; esac

# same, but with a Design-Source OQ in 06 → escape hatch (no fire)
mkfull h2-06esc '# Arch' '# Data' '# Decisions' '# Constraints

NFR: the app must meet WCAG 2.1 AAA.

## Open Questions
- [ ] **OQ-DESIGN-1**: which design tokens / a11y source governs the palette? design-source undecided.' '{"open_questions":[]}'
case "$(runf h2-06esc)" in *defaulted_standard_uncited*) fail "H2 r2: Design-Source OQ in 06 should suppress the fire";; *) ok "H2 r2: a Design-Source OQ in 06 suppresses H2 (escape hatch widened)";; esac

if [ "$FAILED" -eq 0 ]; then note "ALL 2D OK"; else note "2D had failures"; fi
exit $FAILED
