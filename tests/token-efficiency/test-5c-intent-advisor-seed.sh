#!/usr/bin/env bash
# test-5c-intent-advisor-seed.sh — tranche 5c (spec 2026-07-30 §5c).
# PROSE-CONTRACT PINS for the seed-not-boundary invariant: BOTH phase-advisor
# legs (bind + intent) must dispatch a compact seed the advisor EXPANDS PAST —
# never a pasted corpus, never a dispatch that caps the advisor's horizon.
# (The BEHAVIORAL seed-not-boundary fixture lives on the bind leg:
# tests/phase-advisor/test-advisor-bundle.sh plants evidence outside the bundle
# and proves it reachable. These pins guard the intent leg's prose-tier rails —
# the same tier as the dispatch they guard.)
#
#   INTENT  Step 3.7 dispatches PATHS + OQ counts, NOT pasted vault/source;
#           the checklist carries the expansion contract and coverage_gap
#           explicitly REQUIRES sweeping the whole on-disk source (the case a
#           seed cannot contain).
#   BIND    the shipped `.advisor-bundle.md` contract is UNTOUCHED — bundle is
#           a seed, missed_match greps the WHOLE map.
#   AGENT   phase-advisor keeps Read/Grep/Glob (without them "expand past the
#           seed" is dead prose).
#
# Run: bash tests/token-efficiency/test-5c-intent-advisor-seed.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GI_SK="${ROOT}/plugins/mega-sdd/skills/generate-intent/SKILL.md"
GI_CL="${ROOT}/plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md"
BC_SK="${ROOT}/plugins/mega-sdd/skills/bind-codebase/SKILL.md"
BC_CL="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md"
AG="${ROOT}/plugins/mega-sdd/agents/phase-advisor.md"
for f in "$GI_SK" "$GI_CL" "$BC_SK" "$BC_CL" "$AG"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== INTENT leg: paths-not-paste dispatch + expansion contract =="
grep -qF 'NOT the pasted file contents' "$GI_SK" && ok "Step 3.7 dispatches PATHS, not the pasted corpus" || fail "Step 3.7 still pastes"
if grep -qF 'the drafted 7 vault files, and the source (PRD/brief/KB)' "$GI_SK"; then fail "old pasted-corpus dispatch wording survives"; else ok "old pasted-corpus wording gone"; fi
grep -qF 'a SEED it expands past, never its horizon' "$GI_SK" && ok "SKILL.md names the seed-not-horizon invariant" || fail "invariant missing from SKILL.md"
grep -qF 'the OQ counts (constraints.md' "$GI_SK" && ok "dispatch carries the OQ counts (the compact seed; layout-2 home)" || fail "seed content unnamed"
grep -qF 'The seed is never your horizon' "$GI_CL" && ok "checklist opens with the expansion contract" || fail "checklist contract missing"
grep -qF 'Evidence that is NOT in the dispatch is IN SCOPE' "$GI_CL" && ok "checklist: outside-the-seed evidence is IN SCOPE (a bounded review is a moat regression)" || fail "in-scope rule missing"
grep -qF 'you MUST sweep the WHOLE source' "$GI_CL" && ok "coverage_gap REQUIRES the whole-source sweep (the case a seed cannot contain)" || fail "whole-source sweep mandate missing"
grep -qF 'open the on-disk files yourself' "$GI_CL" && ok "checklist: advisor opens the corpus itself (Read/Grep/Glob)" || fail "on-disk read instruction missing"
# review-round rails (ADV-5C-001/002/003/007)
grep -qF 'OUT OF SCOPE for `coverage_gap`' "$GI_CL" && ok "scope/phase carve-out: sibling-scope / out-of-phase sections are NOT gaps (filtered-paste bound restored as a rule)" || fail "scope/phase carve-out missing"
grep -qF 'the scope id + phase N/total' "$GI_SK" && ok "seed carries scope id + phase on filtered runs" || fail "scope/phase seed missing"
grep -qF 'never raise `fabrication` against a Figma-cited claim' "$GI_CL" && ok "Figma-MCP carve-out: no on-disk path, never grounds fabrication" || fail "Figma carve-out missing"
if grep -qF 'Figma export' "$GI_SK" || grep -qF 'Figma export' "$GI_CL"; then fail "phantom 'Figma export' path still named"; else ok "phantom 'Figma export' path gone (MCP frames marked unreadable; screenshots stay in scope)"; fi
grep -qF 'verify every named path resolves on disk' "$GI_SK" && ok "fail-closed pre-dispatch path check (unresolvable → advisor unavailable, never clean)" || fail "path precondition missing"
grep -qF 'unreadable_source' "$GI_CL" && ok "a path that does not open = an unreadable_source finding, never an unearned empty list" || fail "unreadable-source rail missing"
grep -qF '(+ `constitution.md` when present)' "$GI_CL" && ok "constitution.md included in the Reads (8th fabrication-bearing file)" || fail "constitution.md missing from Reads"
# the materialization contract must be untouched by the dispatch-shape change
for m in 'fabrication' 'missed_oq' 'misclassification' 'coverage_gap' 'Step 3.5 classifier' 'Changelog note'; do
  grep -qF "$m" "$GI_CL" || fail "materialization surface lost: $m"
done
grep -qF 'Materialization (done by generate-intent, not the advisor)' "$GI_CL" && ok "materialization section intact (4 finding types + owner unchanged)" || fail "materialization section broken"
grep -qF 'advisor: {model, findings:{high,med,low}}' "$GI_SK" && ok "advisor provenance record unchanged" || fail "provenance record drifted"

note "== BIND leg parity: the shipped bundle contract untouched =="
grep -qF 'not the pasted corpus' "$BC_CL" && ok "bind checklist: bundle is a seed, not a paste" || fail "bind checklist drifted"
grep -qF 'never your horizon' "$BC_CL" && ok "bind checklist: seed-not-horizon contract intact" || fail "bind horizon contract lost"
grep -qF 'Grep the WHOLE codebase-map' "$BC_CL" && ok "bind missed_match: whole-map grep mandate intact (the intent leg's whole-source sweep mirrors this)" || fail "bind whole-map mandate lost"
grep -qF 'build-advisor-bundle.sh' "$BC_SK" && ok "bind bundle builder invocation intact" || fail "bind builder invocation lost"
grep -qF 'the bundle is a seed, never the advisor'\''s horizon' "$BC_SK" && ok "bind SKILL.md invariant intact" || fail "bind SKILL.md invariant lost"

note "== AGENT: expansion is possible, not dead prose =="
grep -qE '^tools: .*Read' "$AG" && grep -qE '^tools: .*Grep' "$AG" && grep -qE '^tools: .*Glob' "$AG" \
  && ok "phase-advisor keeps Read+Grep+Glob (the expansion contract is executable)" || fail "phase-advisor tools regressed"
if grep -qE '^tools: .*(Write|Edit|Bash)' "$AG"; then fail "phase-advisor gained mutating tools (read-only rail broken)"; else ok "phase-advisor stays read-only"; fi

note "== SPEC: 5c recorded =="
SPEC="${ROOT}/docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md"
grep -qF '5c — intent-leg phase-advisor seed dispatch. SHIPPED' "$SPEC" && ok "spec §5c marked shipped with the design" || fail "spec §5c stale"
grep -qF 'no bundle builder' "$SPEC" && ok "spec names the intent-leg no-builder decision (everything is on disk after Step 3)" || fail "no-builder rationale missing"

if [ "$FAILED" -eq 0 ]; then note "ALL 5C SEED-NOT-BOUNDARY PINS OK"; else note "5c pins FAILED"; fi
exit $FAILED
