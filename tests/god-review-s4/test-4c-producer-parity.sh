#!/usr/bin/env bash
# test-4c-producer-parity.sh — god-review stage 4, Batch 4C (re-scoped in 9.0 P1).
#
# Originally pinned producer→consumer parity between scan-codebase's map,
# bind-codebase and generate-units. 9.0 P1 (spec
# docs/superpowers/specs/2026-09-27-v9-simplification-design.md §2/§3/§7) removed
# all three classic skills; `plan` is the only unit producer and the bind is the
# per-unit JIT bind inside execute-bolts. What was RETIRED here, and why:
#   BC-PREFLIGHT-LEGACY  validate-preflight's bind-codebase map probe (legacy
#                        <root>/codebase-map.md, express no-map PASS, classic no-map
#                        FATAL). bind-codebase now FATALs `skill_removed_in_9` for
#                        every input (pinned for the removed set in
#                        tests/express-default/test-p2-ground-express-default.sh).
#   BC-MAPARG-1 + r2     the pre-tool-use DEGENERATE-MAP arm keyed on
#   (POISON-A/B, SPACES, SKILL_NAME=mega-sdd:bind-codebase and its map positional. The
#   S4R-1)               skill no longer exists, so the arm cannot fire; it is kept
#                        byte-for-byte in P1 (§3 Hooks, §7 #7) and is a P1b prune
#                        candidate (its wiring stays grep-pinned by
#                        tests/god-review-s3/test-3a-validator-gate.sh INT-1).
#   BC-TRUNC-1           the capped-map truncation signal (implementation-state.md,
#                        binding-contract.md, binding-json-schema.md, the
#                        generate-units UNKNOWN sub-rule). No capped map exists in the
#                        JIT lane (`truncated_section` cannot occur —
#                        execute-bolts/references/jit-bind-and-quarantine.md); layout-2
#                        binding grammar is owned by code (§7 #10;
#                        derive-binding-json's state_reason stays pinned by
#                        tests/graph/test-derive-binding-json.sh).
#   BC-STALE-1           bind-codebase Step 1 snapshot-verified stamp==HEAD and the
#                        codebase-map-schema attestation (both files deleted; the map
#                        is a pre-9.0 artefact, never a routing key).
#
# What SURVIVES and is REPOINTED to plan's typing contract:
#   BC-STATE-2  a fuzzy anchor never mints a `verify` unit (the operative owner of
#               plan-time typing is plan-procedure.md §Step 4; task-typing.md
#               delegates to it); binding.json row precedence is defined; a
#               bidirectional (PARTIAL_FIELDS_BOTH-shaped) delta is an `extend` with
#               HUMAN REVIEW mandatory; no competing unconditional IMPLEMENTED→verify
#               table row anywhere in the skills (single-owner holds).
#
# Run: bash tests/god-review-s4/test-4c-producer-parity.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PLUGIN="${ROOT}/plugins/mega-sdd"
TT="${PLUGIN}/skills/plan/references/task-typing.md"
PP="${PLUGIN}/skills/plan/references/plan-procedure.md"
UP="${PLUGIN}/skills/plan/references/unit-procedure.md"
for f in "$TT" "$PP" "$UP"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 4C: task_type producer guarantees (plan) =="

# ── BC-STATE-2: a fuzzy anchor never mints `verify` (single owner + rail) ──
grep -qF 'is owned by `plan-procedure.md §Step 4`' "$TT" \
  && ok "BC-STATE-2: task-typing delegates plan-time typing to its single owner (plan-procedure §Step 4)" \
  || fail "BC-STATE-2: task-typing no longer names plan-procedure §Step 4 as the typing owner"
grep -qF 'Never `verify` on a fuzzy hit' "$PP" \
  && ok "BC-STATE-2: single owner carries the no-verify-on-fuzzy qualifier (plan-procedure.md)" \
  || fail "BC-STATE-2: fuzzy-hit→verify guard lost from the single owner"
grep -qF '`verify` units MUST have a concrete anchor — the symbol-index hit recorded in `## Anchors` (never a fuzzy hit)' "$UP" \
  && ok "BC-STATE-2: unit-procedure rail — verify needs a concrete (non-fuzzy) anchor" \
  || fail "BC-STATE-2: unit-procedure verify-anchor rail lost"

# ── BC-STATE-2: row precedence defined ──
grep -qF '**Row precedence** (when a unit'"'"'s claims match both rows): the unresolved-CONFLICT halt first, then KEEP_VAULT.' "$TT" \
  && ok "BC-STATE-2: row precedence defined (unresolved-CONFLICT halt before KEEP_VAULT)" \
  || fail "BC-STATE-2: precedence rule missing"

# ── BC-STATE-2: bidirectional delta → `extend` with HUMAN REVIEW mandatory ──
# Must sit inside the `extend` activation section (it is the extend assignment).
EXT_SEC=$(awk '/^## `extend` activation/{f=1; print; next} /^## /{f=0} f' "$TT")
if printf '%s\n' "$EXT_SEC" | grep -A2 -F 'When the delta runs **both directions**' | grep -qF 'HUMAN REVIEW mandatory before bolt'; then
  ok "BC-STATE-2: both-directions delta assigns extend with HUMAN REVIEW mandatory"
else
  fail "BC-STATE-2: both-directions delta no longer an extend with mandatory HUMAN REVIEW"
fi

# ── BC-STATE-2: single owner holds — no competing unconditional IMPLEMENTED→verify row ──
# (the defensive-generation copy that hosted the contradiction was deleted with
# generate-units; guard every skill + plugin reference so it cannot re-grow.)
if grep -rqE '^\| *`?IMPLEMENTED`? *(\(V == C\))? *\| *`verify`' "${PLUGIN}/skills" "${PLUGIN}/references"; then
  fail "BC-STATE-2: a competing unconditional IMPLEMENTED→verify table row re-grew"
else
  ok "BC-STATE-2: no competing IMPLEMENTED→verify table row (single-owner holds)"
fi

if [ "$FAILED" -eq 0 ]; then note "ALL 4C OK"; else note "4C had failures"; fi
exit $FAILED
