#!/usr/bin/env bash
# Code style playbook — the T2 `code_style_slice` CHANNEL pin
# (docs/superpowers/specs/2026-09-16-code-style-playbook-design.md §3). Without a channel the pack
# section is dead text (elysia.md lesson) — so this pins that the FIRST `## Code style` section of
# the resolved pack chain reaches the implementer's dispatch prompt:
#   1  spring project → `## Code style (from spring.md §Code style …)` emitted with all 4 bullets,
#      exactly ONE header (no chain merge), listed in sections_emitted
#   2  EMIT order = template order: after `## Framework pack rules`
#   3  --unit-tier=xs → held at the FLOOR (first bullet = doc-comment tool + read by survives; skip /
#      names cut; overflow pointer to Tier 3; `code_style_slice.xs_floor` recorded)
#   4  packless project → NO section, omission recorded with the chain named (never padded)
#   5  style rule, not a gate: no validator / hook reads `code_style` (F.5)
# Run: bash tests/comment-diet/test-code-style-slice.sh </dev/null
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/mega-sdd"
BUILD="$PLUGIN_ROOT/scripts/build-dispatch-prompt.sh"
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
if [ -f "$PLUGIN_ROOT/scripts/_lib/resolve-python.sh" ]; then
  # shellcheck disable=SC1091
  . "$PLUGIN_ROOT/scripts/_lib/resolve-python.sh"
  if mega_sdd_python; then PY="$MEGA_SDD_PY"; else echo "SKIP: no usable python interpreter"; exit 0; fi
else echo "missing resolve-python.sh"; exit 1; fi
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t csslice)"; trap 'rm -rf "$WORK"' EXIT

mkproj() {  # mkproj <name> <framework|-> -> project root (unit targets a Spring service file)
  local p="$WORK/$1"; mkdir -p "$p/.mega-sdd/vaults/v1/units"
  cat > "$p/.mega-sdd/vaults/v1/units/U-001.md" <<'MD'
---
id: U-001
title: Add the order reservation service
task_type: create
scope: S-01
scope_name: Orders
module: orders
risk: low
status: pending
target_files:
  - path: src/main/java/com/acme/orders/service/OrderReservationService.java
    operation: create
acceptance_test:
  - command: "mvn -q -Dtest=OrderReservationServiceTest test"
    _authored_by: same-pass
---

## Intent

Reserve inventory for an order and release it after the hold window.

## Hard rules

- DO NOT modify src/main/java/com/acme/orders/entity/Order.java
MD
  if [ "$2" != "-" ]; then
    mkdir -p "$p/.mega-sdd/codebase"
    printf -- '---\nframework: %s\n---\n# Codebase map\n' "$2" > "$p/.mega-sdd/codebase/codebase-map.md"
  fi
  printf '%s' "$p"
}
run() {  # run <proj> [extra-flag] -> $WORK/<name>.json ; returns builder rc
  local n; n="$(basename "$1")"
  bash "$BUILD" --cwd="$1" --vault="$1/.mega-sdd/vaults/v1" --unit=U-001 --plugin-root="$PLUGIN_ROOT" --explain ${2:-} \
    > "$WORK/$n.json" 2> "$WORK/$n.err" </dev/null
}
jq_has() {  # jq_has <json> <emitted|omitted> <key> -> 0/1 ; omitted also prints the reason
  "$PY" - "$1" "$2" "$3" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); kind, key = sys.argv[2], sys.argv[3]
if kind == "emitted":
    sys.exit(0 if key in d.get("sections_emitted", []) else 1)
om = {o["section"]: o["reason"] for o in d.get("sections_omitted", [])}
if key in om:
    print(om[key]); sys.exit(0)
sys.exit(1)
PY
}

# ── 1. spring project: section emitted, 4 bullets, one header, no merge ───────
P1="$(mkproj spring-full spring)"
run "$P1" && pass "1: builder exit 0 on the spring fixture" || fail "1: builder rc=$? ($(head -3 "$WORK/spring-full.err"))"
PR1="$P1/.mega-sdd/vaults/v1/bolts/U-001/dispatch-prompt.md"
HDR='## Code style (from spring.md §Code style — stack delta over Iron Rule 6; a style rule, not a gate)'
[ "$(/usr/bin/grep -c -F "$HDR" "$PR1" 2>/dev/null)" = "1" ] && pass "1: exactly ONE code-style header, citing spring.md (no chain merge)" || fail "1: header count != 1"
/usr/bin/grep -q -F -- '- **Doc-comment tool**: Javadoc — **read by**: Checkstyle' "$PR1" && /usr/bin/grep -q -F -- '- **Skip**:' "$PR1" \
  && /usr/bin/grep -q -F -- '- **Write**:' "$PR1" && /usr/bin/grep -q -F -- '- **Names carry the meaning**:' "$PR1" \
  && pass "1: all four slots reach the implementer at level 0" || fail "1: a slot is missing from the prompt"
jq_has "$WORK/spring-full.json" emitted code_style_slice >/dev/null && pass "1: code_style_slice in sections_emitted" || fail "1: not in sections_emitted"
! /usr/bin/grep -q -F 'Tier 3: read the full pack §Code style' "$PR1" && pass "1: no overflow pointer at level 0 (4 bullets ≤ 6)" || fail "1: overflow pointer at level 0"

# ── 2. EMIT order = template order (after Framework pack rules) ───────────────
L_PACK="$(/usr/bin/grep -n -F '## Framework pack rules' "$PR1" | head -1 | cut -d: -f1)"
L_CS="$(/usr/bin/grep -n -F "$HDR" "$PR1" | head -1 | cut -d: -f1)"
if [ -n "$L_PACK" ] && [ -n "$L_CS" ] && [ "$L_CS" -gt "$L_PACK" ]; then pass "2: emitted after ## Framework pack rules (template order; pack rules matched the service glob)"
else fail "2: order — pack rules line=$L_PACK code style line=$L_CS"; fi

# ── 3. unit_tier xs: held at the floor (first bullet survives) ───────────────
P3="$(mkproj spring-xs spring)"
run "$P3" --unit-tier=xs && pass "3: builder exit 0 under --unit-tier=xs" || fail "3: builder rc=$?"
PR3="$P3/.mega-sdd/vaults/v1/bolts/U-001/dispatch-prompt.md"
/usr/bin/grep -q -F "$HDR" "$PR3" && /usr/bin/grep -q -F -- '- **Doc-comment tool**: Javadoc' "$PR3" \
  && ! /usr/bin/grep -q -F -- '- **Skip**:' "$PR3" && ! /usr/bin/grep -q -F -- '- **Names carry the meaning**:' "$PR3" \
  && /usr/bin/grep -q -F '(+3 more — Tier 3: read the full pack §Code style)' "$PR3" \
  && pass "3: xs keeps the floor bullet (doc-comment tool + read by), cuts skip/write/names, points at Tier 3" || fail "3: xs floor shape wrong"
jq_has "$WORK/spring-xs.json" omitted code_style_slice.xs_floor >/dev/null && pass "3: code_style_slice.xs_floor recorded in sections_omitted" || fail "3: xs_floor not recorded"

# ── 4. packless project: omitted, reason names the chain ─────────────────────
P4="$(mkproj packless -)"
run "$P4" && pass "4: builder exit 0 on the packless fixture" || fail "4: builder rc=$?"
PR4="$P4/.mega-sdd/vaults/v1/bolts/U-001/dispatch-prompt.md"
! /usr/bin/grep -q -F '## Code style (from' "$PR4" && pass "4: no code-style section on a packless project (never padded)" || fail "4: section fabricated"
R4="$(jq_has "$WORK/packless.json" omitted code_style_slice || true)"
case "$R4" in *'no `## Code style` section in the resolved pack chain'*) pass "4: omission recorded, reason names the chain" ;;
  *) fail "4: omission reason wrong/missing: '$R4'" ;; esac

# ── 5. style rule, not a gate ────────────────────────────────────────────────
! /usr/bin/grep -rl -E 'code_style|Code style' "$PLUGIN_ROOT/scripts"/validate-*.sh "$PLUGIN_ROOT/hooks" 2>/dev/null | /usr/bin/grep -v 'validate-pack.sh' | /usr/bin/grep -q . \
  && pass "5: no validator/hook reads the code-style slice (F.5 — validate-pack.sh only lints the pack header)" || fail "5: a gate reads code_style"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
