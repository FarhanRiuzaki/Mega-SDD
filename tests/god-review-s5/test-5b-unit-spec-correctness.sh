#!/usr/bin/env bash
# test-5b-unit-spec-correctness.sh — god-review stage 5, Batch 5B.
# Pins validate-unit-spec.sh correctness:
#
#   GU-TASKTYPE-ENUM-1   'Verify' / '"verify"' normalize; 'modify' is flagged
#                        (closed enum) — none silently disarm the A1 rail.
#   GU-VUS-TF-SWALLOW-1  the FIRST frontmatter target_files item is read —
#                        render_test_missing fires for a view-first unit.
#   GU-VUS-A1-DOC-ANCHOR-1  vault/PRD .md anchors + line-less anchors are NOT
#                        grounding; real source anchors still pass.
#   GU-HR-GRAMMAR-1      bullet-evasion shapes are unparseable; generic
#                        directives counted, not laundered; annotations/fences
#                        whitelisted.
#   GU-TTCONTRACT-1      empty Anchors/Migration notes flagged; Migration notes
#                        forbidden on create; ADD/KEEP/REMOVE completeness.
#   GU-VUS-AT-PRESENCE-1 acceptance_test presence machine-checked.
#   GU-SK-CITE-2         lowercase `citation:` shape accepted.
#
# Run: bash tests/god-review-s5/test-5b-unit-spec-correctness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VUS="${ROOT}/plugins/mega-sdd/scripts/validate-unit-spec.sh"
[ -f "$VUS" ] || { echo "missing $VUS"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t vus5b)"
trap 'rm -rf "$WORK"' EXIT

# mkcase <name> <unit-content> → runs validator; sets J (state json) + RC
mkcase() {
  local d="$WORK/$1"
  mkdir -p "$d/.mega-sdd/vaults/demo/units" "$d/src"
  printf 'line1\nline2\nline3\n' > "$d/src/billing.py"
  printf '%s\n' "$2" > "$d/.mega-sdd/vaults/demo/units/U-001.md"
  bash "$VUS" --cwd="$d" --file-path="$d/.mega-sdd/vaults/demo/units/U-001.md" --quiet >/dev/null 2>&1
  RC=$?
  J="$d/.mega-sdd/.unit-spec-state.json"
}
halts() { python3 -c "import json; print(sorted({i['halt_type'] for i in json.load(open('$J'))['issues']}))"; }

BASE_FM='unit_id: U-001
title: T
target_files: []
vault_source: 03-data-model.md'

note "== 5B: validate-unit-spec correctness =="

# ── GU-TASKTYPE-ENUM-1 ──
mkcase enum-case "---
$BASE_FM
task_type: Verify
grounding_confidence: HIGH
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- tax works [ungrounded]"
[ "$RC" -eq 1 ] && halts | grep -q verify_grounding_untrusted \
  && ok "ENUM: 'Verify' (case drift) normalizes — A1 still fires" || fail "ENUM: case drift disarmed A1 (rc=$RC, $(halts))"

mkcase enum-quoted "---
$BASE_FM
task_type: \"verify\"
grounding_confidence: \"HIGH\"
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- tax works [ungrounded]"
[ "$RC" -eq 1 ] && halts | grep -q verify_grounding_untrusted \
  && ok "ENUM: quoted YAML scalars normalize — A1 still fires" || fail "ENUM: quoted scalars disarmed A1 (rc=$RC, $(halts))"

mkcase enum-invalid "---
$BASE_FM
task_type: modify
acceptance_test:
  - type: unit
    assert: works
---
## Implementation steps
Body."
[ "$RC" -eq 1 ] && halts | grep -q unit_underspecified \
  && ok "ENUM: invalid 'modify' flagged (closed enum, never silent)" || fail "ENUM: invalid enum passes silently (rc=$RC)"

# ── GU-VUS-A1-DOC-ANCHOR-1 ──
mkcase a1-vaultdoc "---
$BASE_FM
task_type: verify
grounding_confidence: HIGH
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- tax works [grounded: .mega-sdd/vaults/demo/bound/03-entities.md:1]"
[ "$RC" -eq 1 ] && ok "A1: vault-doc anchor is NOT grounding (the criteria-live-in-the-PRD class)" || fail "A1: vault-doc anchor passes (rc=$RC)"

mkcase a1-lineless "---
$BASE_FM
task_type: verify
grounding_confidence: HIGH
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- tax works [grounded: src/billing.py]"
[ "$RC" -eq 1 ] && ok "A1: line-less anchor is NOT grounding" || fail "A1: line-less anchor passes (rc=$RC)"

mkcase a1-real "---
$BASE_FM
task_type: verify
grounding_confidence: HIGH
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- tax works [grounded: src/billing.py:2]"
[ "$RC" -eq 0 ] && ok "A1: real source anchor still passes (no over-block)" || fail "A1: real anchor false-blocks (rc=$RC, $(halts))"

# ── GU-HR-GRAMMAR-1 ──
mkcase hr-evasion "---
$BASE_FM
task_type: create
target_files:
  - src/x.py
acceptance_test:
  - type: unit
    assert: works
---
## Hard rules
* NEVER touch the payments ledger schema
1. All handlers MUST be idempotent somehow
DO NOT modify src/billing.py directly

## Implementation steps
Body."
[ "$RC" -eq 1 ] && halts | grep -q hard_rule_unparseable \
  && ok "GRAMMAR: bullet-evasion shapes (asterisk/numbered/bare) are unparseable" || fail "GRAMMAR: evasion shapes silently skipped (rc=$RC, $(halts))"

mkcase hr-annot "---
$BASE_FM
task_type: create
target_files:
  - src/x.py
acceptance_test:
  - type: unit
    assert: works
---
## Hard rules
- DO NOT modify src/billing.py
Citation: binding.md §Suggested Unit Hard Rules

## Implementation steps
Body."
halts | grep -q hard_rule_unparseable && fail "GRAMMAR: annotation sub-line false-flagged" || ok "GRAMMAR: Citation annotation line whitelisted"

# ── GU-TTCONTRACT-1 ──
mkcase tt-empty "---
$BASE_FM
task_type: extend
target_files:
  - src/x.py
acceptance_test:
  - type: unit
    assert: works
---
## Anchors

## Migration notes

## Implementation steps
Body."
[ "$RC" -eq 1 ] && python3 -c "
import json, sys
d = json.load(open('$J'))
det = ' '.join(i['detail'] for i in d['issues'])
sys.exit(0 if 'EMPTY' in det else 1)
" && ok "CONTRACT: empty Anchors + Migration notes flagged (content, not heading presence)" || fail "CONTRACT: empty sections pass (rc=$RC)"

mkcase tt-createmig "---
$BASE_FM
task_type: create
target_files:
  - src/x.py
acceptance_test:
  - type: unit
    assert: works
---
## Migration notes
- ADD: [x] KEEP: [y] REMOVE: []

## Implementation steps
Body."
[ "$RC" -eq 1 ] && python3 -c "
import json, sys
d = json.load(open('$J'))
sys.exit(0 if any('MUST NOT' in i['detail'] for i in d['issues']) else 1)
" && ok "CONTRACT: create WITH Migration notes flagged (12.5.d MUST-NOT direction)" || fail "CONTRACT: create+Migration passes (rc=$RC)"

mkcase tt-sublists "---
$BASE_FM
task_type: extend
target_files:
  - src/x.py
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Migration notes
- ADD: [nama]

## Implementation steps
Body."
[ "$RC" -eq 1 ] && python3 -c "
import json, sys
d = json.load(open('$J'))
sys.exit(0 if any('missing sub-list' in i['detail'] for i in d['issues']) else 1)
" && ok "CONTRACT: Migration notes missing KEEP/REMOVE sub-lists flagged" || fail "CONTRACT: partial sub-lists pass (rc=$RC)"

# ── GU-VUS-AT-PRESENCE-1 ──
mkcase at-missing "---
$BASE_FM
task_type: create
target_files:
  - src/x.py
---
## Implementation steps
Body."
[ "$RC" -eq 1 ] && python3 -c "
import json, sys
d = json.load(open('$J'))
sys.exit(0 if any('acceptance_test' in str(i.get('missing_fields', [])) for i in d['issues']) else 1)
" && ok "AT: missing acceptance_test flagged (schema 'No exceptions' now machine-checked)" || fail "AT: missing acceptance_test passes (rc=$RC)"

mkcase at-empty "---
$BASE_FM
task_type: create
target_files:
  - src/x.py
acceptance_test: []
---
## Implementation steps
Body."
[ "$RC" -eq 1 ] && ok "AT: empty acceptance_test list flagged" || fail "AT: empty list passes (rc=$RC)"

# ── GU-SK-CITE-2 ──
mkcase sk-lower "---
$BASE_FM
task_type: create
target_files:
  - src/x.py
starterkit_context_consumed: true
acceptance_test:
  - type: unit
    assert: works
---
## Hard rules
- MUST follow starterkit idiom: use Flux components
citation: \"starterkit-context.yaml §ui_ux.idioms\"

## Implementation steps
Body."
halts | grep -q starterkit_rule_citation_missing && fail "SK-CITE: lowercase citation shape still false-flagged" || ok "SK-CITE: lowercase 'citation:' shape accepted (both documented shapes)"

# ── round-2 pins ──
mkcase r2-indent-evasion "---
$BASE_FM
task_type: create
target_files:
  - src/x.py
acceptance_test:
  - type: unit
    assert: works
---
## Hard rules
 * NEVER touch app/Legacy.php

## Implementation steps
Body."
[ "$RC" -eq 1 ] && halts | grep -q hard_rule_unparseable \
  && ok "r2 ATK-2: one-space-indented evasion shape still flagged" || fail "r2 ATK-2: indent defeats the evasion net (rc=$RC)"

mkcase r2-lstrip "---
$BASE_FM
task_type: verify
grounding_confidence: HIGH
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- tax works [grounded: .mega-sdd/vaults/demo/binding.json:1]"
mkdir -p "$WORK/r2-lstrip/.mega-sdd/vaults/demo"; printf '{}\n' > "$WORK/r2-lstrip/.mega-sdd/vaults/demo/binding.json"
bash "$VUS" --cwd="$WORK/r2-lstrip" --file-path="$WORK/r2-lstrip/.mega-sdd/vaults/demo/units/U-001.md" --quiet >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "r2 LSTRIP: relative .mega-sdd non-.md anchor rejected (lstrip bug closed)" || fail "r2 LSTRIP: .mega-sdd artifact anchor grounds (rc=$RC)"

mkcase r2-mdsource "---
$BASE_FM
task_type: verify
grounding_confidence: HIGH
acceptance_test:
  - type: unit
    assert: works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- pricing page shows tiers [grounded: content/pricing.md:1]"
mkdir -p "$WORK/r2-mdsource/content"; printf 'tiers\n' > "$WORK/r2-mdsource/content/pricing.md"
bash "$VUS" --cwd="$WORK/r2-mdsource" --file-path="$WORK/r2-mdsource/.mega-sdd/vaults/demo/units/U-001.md" --quiet >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "r2 ATK-5: markdown-SOURCE anchor (content/*.md) grounds — docs-site projects not hard-blocked" || fail "r2 ATK-5: md-source project false-blocked (rc=$RC)"

mkcase r2-decorated "---
$BASE_FM
task_type: extend
target_files:
  - src/x.py
acceptance_test:
  - type: unit
    assert: works
---
## Anchors (from binding)
- src/billing.py:1

## Migration notes (auto-populated)
- ADD: [x] KEEP: [y] REMOVE: []

## Implementation steps
Body."
[ "$RC" -eq 0 ] && ok "r2 ATK-3: decorated section headings accepted (no false unit_underspecified)" || fail "r2 ATK-3: decorated headings false-flag (rc=$RC, $(halts))"

# ── GU-VUS-TF-SWALLOW-1 (needs the laravel pack detail_view_glob) ──
D="$WORK/tf-first"; mkdir -p "$D/.mega-sdd/codebase" "$D/.mega-sdd/vaults/demo/units"
printf -- '---\nframework: laravel\n---\n' > "$D/.mega-sdd/codebase/codebase-map.md"
cat > "$D/.mega-sdd/vaults/demo/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: Show view
task_type: create
target_files:
  - path: resources/views/widgets/show.blade.php
vault_source: 04-flows.md
acceptance_test:
  - type: feature
    assert: page loads
---
## Implementation steps
Body.
EOF
bash "$VUS" --cwd="$D" --file-path="$D/.mega-sdd/vaults/demo/units/U-001.md" --quiet >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$D/.mega-sdd/.unit-spec-state.json'))
sys.exit(0 if any(i['halt_type'] == 'render_test_missing' for i in d['issues']) else 1)
" && ok "TF-SWALLOW: detail view as the FIRST/only target file fires render_test_missing" \
  || fail "TF-SWALLOW: view-first unit still skips the render gate (rc=$RC)"

if [ "$FAILED" -eq 0 ]; then note "ALL 5B OK"; else note "5B had failures"; fi
exit $FAILED
