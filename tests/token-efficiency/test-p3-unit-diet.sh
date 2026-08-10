#!/usr/bin/env bash
# test-p3-unit-diet.sh — Batch 2 P3: the unit-spec diet (units are re-sent per-bolt
# AND per-review-lens; every frontmatter byte multiplies ~5-6x per full-tier attempt).
#
# Pins the diet contract (spec 2026-07-19-batch2-derive-and-diet.md, item P3):
#   (a) generate-units stops WRITING the gate-inert frontmatter surfaces —
#       grounding_evidence block, superpowers_skills, estimated_complexity, the
#       nested mutability map (source + rebuild_freedom) — mutability collapses to
#       ONE QUOTED line `<TIER> — <rationale incl. source>`; legacy units tolerated.
#   (b) acceptance criteria written ONCE — frontmatter acceptance_test[] is the
#       structured authority; verify keeps expanded (marker-bearing when HIGH) body
#       criteria (the A1 substrate); create/extend get the pointer line; ears: only
#       where it adds precision beyond expects: (roadmap pins intact).
#   (c) per-lens slice trim — security+standards drop Goal/Context/Out-of-scope;
#       quality KEEPS Goal + Out of scope (drops Context); spec lens FULL body;
#       design slice unchanged; blind BETWEEN-lens rail untouched.
# Plus the tolerance pair: validate-unit-spec.sh passes a unit WITHOUT the diet
# keys AND one WITH them (writer-side diet, reader-side tolerance); A1 unaffected
# in both directions.
#
# Run: bash tests/token-efficiency/test-p3-unit-diet.sh </dev/null
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
US="${P}/skills/generate-units/references/unit-schema.md"
TU="${P}/skills/generate-units/references/templates/unit.md"
DG="${P}/skills/generate-units/references/defensive-generation.md"
RP="${P}/skills/execute-bolts/references/review-panel.md"
BR="${P}/skills/execute-bolts/references/superpowers-bridge.md"
V="${P}/scripts/validate-unit-spec.sh"
for f in "$US" "$TU" "$DG" "$RP" "$BR" "$V"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d 2>/dev/null || mktemp -d -t p3diet)"
trap 'rm -rf "$W"' EXIT

echo "== P3: unit-spec diet =="

# ── (a) schema no longer instructs the dropped keys ──
for key in grounding_evidence superpowers_skills estimated_complexity; do
  if grep -qE "^${key}:" "$US"; then fail "unit-schema still instructs \`${key}:\` as a schema key"; else ok "unit-schema no longer instructs \`${key}:\`"; fi
done
if grep -qE "^\s*rebuild_freedom:" "$US"; then fail "unit-schema still carries the rebuild_freedom sub-map"; else ok "unit-schema rebuild_freedom sub-map gone"; fi
if grep -qE "^\s*(source|tier):\s*(kb_locked|LOCKED \| INTENT)" "$US"; then fail "nested mutability map keys survive in schema"; else ok "nested mutability map keys gone from schema"; fi

# quoted single-line mutability form + tolerance note
grep -qF 'mutability: "' "$US" && ok "schema shows the QUOTED single-line mutability form" || fail "quoted single-line mutability example missing"
grep -qF '<TIER> — <rationale incl. source>' "$US" && ok "schema states the <TIER> — <rationale incl. source> grammar" || fail "single-line mutability grammar comment missing"
grep -qiF 'Quoting is MANDATORY' "$US" && ok "schema mandates quoting (colon-space YAML regression class)" || fail "quoting mandate missing"
grep -qF 'Legacy keys' "$US" && grep -qF 'no longer writes them' "$US" && ok "legacy-tolerance note present (writer-side diet, readers tolerate)" || fail "legacy-tolerance note missing"
grep -qF '## Hard rules' "$US" && grep -qF 'DO_NOT_MODIFY' "$US" && ok "enforceable half still routed to ## Hard rules (grammar untouched)" || fail "Hard rules grammar reference lost"

# ── template lacks the dropped scaffold keys ──
for key in superpowers_skills estimated_complexity grounding_evidence; do
  if grep -qE "^${key}:" "$TU"; then fail "templates/unit.md still scaffolds \`${key}:\`"; else ok "templates/unit.md no longer scaffolds \`${key}:\`"; fi
done

# defensive-generation example sheds grounding_evidence, keeps grounding_confidence
if grep -qE "^grounding_evidence:" "$DG"; then fail "defensive-generation example still emits grounding_evidence"; else ok "defensive-generation example sheds grounding_evidence"; fi
grep -qF 'grounding_confidence: HIGH | MEDIUM | LOW' "$DG" && ok "grounding_confidence kept (A1 trigger condition)" || fail "grounding_confidence lost from defensive-generation"
grep -qF 'no frontmatter block needed' "$DG" && ok "anchor tally rerouted to chat summary line + body footer" || fail "chat-summary rerouting line missing"
grep -qF 'no longer written; legacy units carrying it are tolerated' "$DG" && ok "anti-halu rail speaks the diet (tolerated legacy)" || fail "anti-halu rail wording stale"

# ── (b) ears: roadmap pins survive + sharpened emission guidance ──
grep -q 'ears:' "$US" && ok "roadmap pin: \`ears:\` key survives (optional tier)" || fail "roadmap pin lost: ears: key"
grep -qF 'OPTIONAL (additive, backward-compatible)' "$US" && ok "roadmap pin: EARS optionality phrase survives" || fail "roadmap pin lost: OPTIONAL (additive, backward-compatible)"
grep -qF 'Absent → `expects:` (a literal output substring, or empty' "$US" && ok "roadmap pin: absent-ears backward-compat phrase survives" || fail "roadmap pin lost: absent-ears phrase"
grep -qF 'NEVER a restatement of expects' "$US" && grep -qF 'nothing parses ears downstream' "$US" && ok "ears: emitted only where it adds precision (never restating expects:)" || fail "ears emission guidance missing"

# ── (b) acceptance criteria written once — per-task_type body rule ──
grep -qF 'Acceptance criteria are the frontmatter' "$US" && ok "create/extend pointer-line form documented in schema" || fail "pointer-line form missing from schema"
grep -qF 'expanded criteria at ALL confidence levels' "$US" && ok "verify keeps expanded body criteria at ALL confidence levels (A1 substrate)" || fail "verify-keeps-expanded rule missing (A1 dulling risk)"
grep -qF '[grounded: src/Services/Purchase.php:142]' "$US" && grep -qF '[ungrounded] source-of-fund validation' "$US" && ok "A1 marker grammar block intact (verbatim)" || fail "A1 grammar block damaged"
grep -qF 'verify_grounding_untrusted' "$US" && ok "A1 enforcement pointer intact" || fail "verify_grounding_untrusted pointer lost"
grep -qF 'Acceptance criteria are the frontmatter' "$TU" && ok "template Acceptance-criteria placeholder is the pointer-line form" || fail "template still scaffolds expanded placeholder bullets"
grep -qF 'TBD OQ items / prose-only constraints' "$TU" && ok "template names the only non-restating additions (TBD OQs, prose-only constraints)" || fail "template non-restating guidance missing"

# ── (c) review-panel per-lens slice trim matches the locked decision ──
grep -qF 'security and standards lenses ALSO drop the `## Goal` / `## Context (read first)` / `## Out of scope` prose' "$RP" \
  && ok "security + standards drop Goal/Context/Out-of-scope" || fail "security/standards orientation-prose trim missing"
grep -qF 'KEEPS Goal + Out of scope' "$RP" && ok "quality lens KEEPS Goal + Out of scope (scope-creep judgment)" || fail "quality Goal+OoS keep missing"
grep -qF 'while still dropping Context' "$RP" && ok "quality lens drops Context" || fail "quality Context-drop missing"
grep -qF 'design lens slice is unchanged' "$RP" && ok "design lens slice unchanged (locked decision: not trimmed)" || fail "design-lens disposition undocumented"
# the four pre-existing pin strings must survive the wording extension
grep -qiF 'spec lens gets the full unit body verbatim' "$RP" && ok "pin survives: spec lens FULL body verbatim" || fail "pin lost: spec-lens-full"
grep -qiF 'NOT the Implementation-steps NARRATIVE' "$RP" && ok "pin survives: Implementation-steps narrative drop" || fail "pin lost: narrative drop"
grep -qiF 'Migration notes STAYS in every lens' "$RP" && ok "pin survives: Migration notes in every lens" || fail "pin lost: Migration notes"
grep -qiF 'blind' "$RP" && grep -qF 'NEVER contains' "$RP" && ok "pin survives: blind BETWEEN-lens rail (sizing changed, sharing untouched)" || fail "pin lost: blind rail"
# bridge diagram stays in sync
grep -qF 'Anchors/Anti-patterns + Migration notes' "$BR" && ok "pin survives: bridge slice includes Anchors/Anti-patterns + Migration notes" || fail "pin lost: bridge slice list"
grep -qiF 'sized to the lens' "$BR" && ok "pin survives: bridge sized-to-the-lens contract" || fail "pin lost: sized to the lens"
grep -qF 'NOT Goal/Context/Out-of-scope' "$BR" && grep -qF 'security/standards' "$BR" && ok "bridge diagram carries the per-lens trim" || fail "bridge diagram missing the trim"
grep -qF 'Goal/Out-of-scope for the quality lens' "$BR" && ok "bridge diagram carries the quality-lens exception" || fail "bridge quality exception missing"
if grep -qF 'superpowers_skills' "$BR"; then
  grep -qF 'no longer written' "$BR" && ok "bridge speaks superpowers_skills as legacy (no longer written)" || fail "bridge superpowers_skills wording stale"
fi

# ── tolerance pair: validate-unit-spec.sh over new-shape + old-shape fixtures ──
mkproj() { # $1=name → project dir with resolvable non-test source + a test file
  local p="$W/$1"; rm -rf "$p"
  mkdir -p "$p/src" "$p/tests" "$p/.mega-sdd/vaults/v1/units"
  printf 'a\nb\nc\nd\ne\n' > "$p/src/limits.ts"
  printf 'a\nb\nc\nd\ne\n' > "$p/tests/limits.test.ts"
  echo "$p"
}
run_v() { # $1=proj $2=unitfile → validator exit code (focal)
  bash "$V" --cwd="$1" --file-path="$2" --quiet >/dev/null 2>&1
  echo $?
}

# (1) NEW-shape create unit: no diet keys, quoted single-line mutability, pointer-line body
P1=$(mkproj newshape); F1="$P1/.mega-sdd/vaults/v1/units/U-001.md"
cat > "$F1" <<'EOF'
---
id: U-001
title: Create purchase limit endpoint
vault_source: 02-architecture.md#limits
task_type: create
grounding_confidence: MEDIUM
mutability: "LOCKED — BI Reg 23/2/2021 §4: field name+type+validation MUST preserve (kb_locked)"
module: M-default
depends_on: []
target_files:
  - path: src/api/limits.ts
    operation: create
acceptance_test:
  - type: test
    command: "npm test -- limits"
    expects: "passes"
binding_refs: []
---

## Goal
Create the purchase limit endpoint.

## Context (read first)
The vault architecture section defines a purchase limit endpoint that does not exist yet, so this unit builds it from the pattern the codebase already uses for read endpoints.

## Implementation steps
First, open src/limits.ts and study how the existing limit constants are structured, because the new endpoint must read those constants rather than duplicating the values inline.

## Acceptance criteria
Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-004 — is the daily cap configurable per tier?

## Out of scope
- Anything beyond the limits endpoint.
EOF
[ "$(run_v "$P1" "$F1")" -eq 0 ] && ok "tolerance: NEW-shape unit (no diet keys, quoted mutability, pointer-line body) PASSES" || fail "NEW-shape unit rejected by validate-unit-spec.sh"

# (2) OLD-shape unit carrying ALL legacy keys incl. the nested mutability map
P2=$(mkproj oldshape); F2="$P2/.mega-sdd/vaults/v1/units/U-002.md"
cat > "$F2" <<'EOF'
---
id: U-002
title: Legacy-shaped unit with pre-diet keys
vault_source: 02-architecture.md#limits
task_type: create
grounding_confidence: HIGH
grounding_evidence:
  upstream_artifacts: [codebase-map.md, binding.md]
  anchors_verified: 1/1
  target_files_collision_check: passed
  binding_state_summary: { NEW: 1 }
mutability:
  tier: LOCKED
  source: kb_locked
  rationale: "BI Reg 23/2/2021 §4 — field name + type + validation MUST preserve"
  rebuild_freedom:
    field_names: no
    field_types: no
    storage_shape: no
    flow_implementation: no
module: M-default
depends_on: []
target_files:
  - path: src/api/limits.ts
    operation: create
acceptance_test:
  - type: test
    command: "npm test -- limits"
    expects: "passes"
superpowers_skills:
  - test-driven-development
binding_refs: []
estimated_complexity: small
---

## Goal
Legacy-shaped unit.

## Implementation steps
This legacy unit body demonstrates that a pre-diet unit carrying every dropped frontmatter key still validates cleanly, because the diet is writer-side only.

## Acceptance criteria
- All tests pass
- Lint clean

## Out of scope
- Nothing.
EOF
[ "$(run_v "$P2" "$F2")" -eq 0 ] && ok "tolerance: OLD-shape unit (all legacy keys incl. nested mutability map) PASSES" || fail "OLD-shape legacy unit rejected — tolerance broken"

# (3) verify+HIGH with marker-bearing expanded criteria → PASS (A1 intact, green side)
P3=$(mkproj vhighok); F3="$P3/.mega-sdd/vaults/v1/units/U-003.md"
cat > "$F3" <<'EOF'
---
id: U-003
title: Verify purchase limits
vault_source: 02-architecture.md#limits
task_type: verify
grounding_confidence: HIGH
target_files: []
acceptance_test:
  - type: test
    command: "npm test -- limits"
    expects: "passes"
binding_refs: []
---

## Anchors
- src/limits.ts:3

## Implementation steps
No code changes. Run acceptance tests against existing implementation at src/limits.ts:3.

## Acceptance criteria
- [grounded: src/limits.ts:3] minimal purchase enforced
- [grounded: src/limits.ts:4] daily limit enforced

## Out of scope
- Nothing.
EOF
[ "$(run_v "$P3" "$F3")" -eq 0 ] && ok "A1 green side: verify+HIGH with marker-bearing expanded body criteria PASSES" || fail "verify+HIGH grounded unit rejected — A1 substrate damaged"

# (4) verify+HIGH with an [ungrounded] criterion → FAIL verify_grounding_untrusted
P4=$(mkproj vhighbad); F4="$P4/.mega-sdd/vaults/v1/units/U-004.md"
cat > "$F4" <<'EOF'
---
id: U-004
title: Verify purchase limits (ungrounded)
vault_source: 02-architecture.md#limits
task_type: verify
grounding_confidence: HIGH
target_files: []
acceptance_test:
  - type: test
    command: "npm test -- limits"
    expects: "passes"
binding_refs: []
---

## Anchors
- src/limits.ts:3

## Implementation steps
No code changes. Run acceptance tests against existing implementation at src/limits.ts:3.

## Acceptance criteria
- [grounded: src/limits.ts:3] minimal purchase enforced
- [ungrounded] source-of-fund validation

## Out of scope
- Nothing.
EOF
RC4="$(run_v "$P4" "$F4")"
if [ "$RC4" -ne 0 ] && grep -q 'verify_grounding_untrusted' "$P4/.mega-sdd/.unit-spec-state.json" 2>/dev/null; then
  ok "A1 red side: verify+HIGH with [ungrounded] criterion still FAILS verify_grounding_untrusted"
else
  fail "A1 red side broken: ungrounded verify+HIGH unit not flagged (rc=$RC4)"
fi

if [ "$FAILED" -eq 0 ]; then echo "ALL P3 OK"; else echo "P3 had failures"; fi
exit $FAILED
