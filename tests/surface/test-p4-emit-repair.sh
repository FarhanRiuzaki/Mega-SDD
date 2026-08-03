#!/usr/bin/env bash
# test-p4-emit-repair.sh — v6 P4.2: the on-demand doc pack derives from the
# MODERN vault generation (spec 2026-08-03-v6-express-spine-design.md §P4.2).
#
# Pins:
#   1  FSD §5 falls back to 04-flows.md `### F-*` when 02-functional.md is
#      absent (the modern shape) — rows enumerate flows, priority stays an
#      honest "—" (flows carry no Priority field; never default MEDIUM).
#   2  FSD §6 falls back to 06-constraints.md `## Non-functional requirements`
#      rows, keyword-routed per category, labeled with the real source.
#   3  FSD §10 + PRD §6 accept BOTH vault.json OQ shapes (tag/text = the
#      derive-vault-json schema; id/question = the older authored shape).
#   4  The legacy 02-functional.md FR-heading branch is UNCHANGED (first hit wins).
#   5  vault_md.parse_rollup_categories accepts both roll-up heading spellings
#      (`## Open Questions (roll-up)` — the template form — and the bare form).
#
# CI-safe: bash + python3. Run with </dev/null.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
fails=0
ok()   { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

mkvault() { # $1 = project dir — a MODERN-shaped vault (no 02-functional.md)
  local V="$1/.mega-sdd/vaults/v1"
  mkdir -p "$V"
  printf '# Index\n\n## Vault Lock Status\n\n- **Vault version**: 1.0\n' > "$V/00-index.md"
  printf '# Overview\n\n## Product\n\nLeave app.\n' > "$V/01-overview.md"
  printf '# Architecture\n\n## Auth\n\nX.\n' > "$V/02-architecture.md"
  printf '# Data\n' > "$V/03-data-model.md"
  cat > "$V/04-flows.md" <<'EOF'
# Flows

### F-U-001: Submit leave request

```mermaid
flowchart TD
  A["form"] --> B["save"]
```

**Definition of Done**:
- request row created
- manager notified

### F-S-002: Nightly accrual

```mermaid
flowchart TD
  C["cron"] --> D["accrue"]
```

**Definition of Done**:
- balances updated
EOF
  printf '# Decisions\n' > "$V/05-decisions.md"
  cat > "$V/binding.md" <<'EOF'
# Binding

prose note: F-S-002 settle flow, see SEC-12 control note, unresolved OQ tracking
- **C-3** F-U-001 submit-leave claim CONFIRMED
EOF
  cat > "$V/06-constraints.md" <<'EOF'
# Constraints

## Non-functional requirements

| Category | Requirement | Source |
|---|---|---|
| Performance | p95 latency < 300ms | PRD §5 |
| Security | all endpoints require auth | PRD §5 |
| Ops | logs retained 90 days | PRD §5 |
EOF
  cat > "$V/vault.json" <<'EOF'
{"project_name": "leave", "open_questions": [
  {"tag": "OQ-AR-1", "text": "which test framework?", "priority": "P1", "category": "tech", "status": "open"},
  {"tag": "OQ-AR-2", "text": "resolved one", "priority": "P2", "category": "tech", "status": "resolved"}
]}
EOF
  echo "$V"
}

echo "── 1+2+3: FSD modern-vault fallbacks (§5 flows, §6 constraints, §10 tag/text OQs) ──"
PRJ="$W/modern"; mkdir -p "$PRJ"
V=$(mkvault "$PRJ")
OUT=$(bash "$P/scripts/build-fsd-core.sh" --vault="$V" --cwd="$PRJ" --quiet </dev/null 2>&1 | head -1)
F="$V/fsd/FSD.md"
[ -f "$F" ] && ok "FSD.md written on a modern vault ($OUT)" || fail "FSD build failed: $OUT"
if [ -f "$F" ]; then
  grep -qF "| F-U-001 | Submit leave request | — |" "$F" \
    && ok "§5 enumerates flows with honest '—' priority" || fail "§5 flow row missing or priority fabricated"
  grep -qF "F-S-002" "$F" && ok "§5 covers every flow" || fail "§5 dropped a flow"
  grep -qF "vault/04-flows.md" "$F" && ok "§5 cites the real source (04-flows.md)" || fail "§5 citation missing"
  grep -qF "Pending — vault/02-functional.md not yet generated" "$F" \
    && fail "§5 still emits the legacy-name Pending slot on a modern vault" \
    || ok "§5 no longer Pending on a modern vault"
  grep -qF "_Dari 06-constraints §Non-functional requirements:_" "$F" \
    && ok "§6 sources the modern NFR table with the real label" || fail "§6 constraints fallback missing"
  grep -qF "p95 latency < 300ms" "$F" && ok "§6 performance row routed" || fail "§6 performance row lost"
  grep -qF "all endpoints require auth" "$F" && ok "§6 security row routed" || fail "§6 security row lost"
  grep -qF "logs retained 90 days" "$F" && ok "§6 unmatched row lands in Other (never dropped)" || fail "§6 dropped an unmatched row"
  grep -qF "| OQ-AR-1 | which test framework? | P1 | tech |" "$F" \
    && ok "§10 renders tag/text vault.json OQs" || fail "§10 tag/text OQ shape not rendered"
  grep -qF "resolved one" "$F" && fail "§10 leaked a resolved OQ" || ok "§10 filters resolved OQs"
  # round blind-spot pins (code lane): citation honesty + verdict honesty
  grep -qF "[Source: vault/04-flows.md:L" "$F" \
    && ok "§5 per-FR Source stamps cite 04-flows.md with its own line numbers" \
    || fail "§5 Source stamps missing the flows path"
  grep -qF "Source: vault/02-functional.md" "$F" \
    && fail "§5 stamped a citation to the nonexistent 02-functional.md (fabricated citation)" \
    || ok "§5 no fabricated 02-functional.md citation on a modern vault"
  grep -qF "#### F-U-001" "$F" && ! grep -qF "FR-F-U-001" "$F" \
    && ok "§5 detail headings keep the real flow id (no FR-F-* mangling)" \
    || fail "§5 detail heading id mangled"
  grep -qF "C-3" "$F" && ok "§5 verdict extracted from a real claim line (C-3)" || fail "§5 claim line not honored"
  grep -qF "C-12" "$F" && fail "§5 fabricated claim C-12 from prose token SEC-12" || ok "§5 no claim fabricated from SEC-12 prose"
  awk '/## 5\./,/## 6\./' "$F" | grep -qF "flowchart TD" \
    && fail "§5 FR description swallowed the mermaid body (DoD over-capture)" \
    || ok "§5 DoD extraction stops at the bullet block (no mermaid swallow)"
fi

echo "── 3b: PRD §6 tag/text fallback ──"
OUTP=$(bash "$P/scripts/build-prd-core.sh" --out-root="$V" --vault="$V" --cwd="$PRJ" --mode=forward --quiet </dev/null 2>&1 | head -1)
PR="$V/prd/PRD.md"
if [ -f "$PR" ]; then
  grep -qF "OQ-AR-1" "$PR" && grep -qF "which test framework?" "$PR" \
    && ok "PRD §6 renders tag/text vault.json OQs" || fail "PRD §6 tag/text OQ shape not rendered"
else
  fail "PRD build failed on the modern vault: $OUTP"
fi

echo "── 4: legacy 02-functional.md branch unchanged (first hit wins) ──"
PRJ2="$W/legacy"; mkdir -p "$PRJ2"
V2=$(mkvault "$PRJ2")
cat > "$V2/02-functional.md" <<'EOF'
# Functional

## FR-001 — Submit request

**Priority:** HIGH

Body.
EOF
bash "$P/scripts/build-fsd-core.sh" --vault="$V2" --cwd="$PRJ2" --quiet </dev/null >/dev/null 2>&1
F2="$V2/fsd/FSD.md"
grep -qF "| FR-001 | Submit request | HIGH |" "$F2" \
  && ok "legacy FR headings still win when 02-functional.md exists" || fail "legacy FR branch broken"
grep -qF "| F-U-001 |" "$F2" \
  && fail "flows fallback fired despite a legacy 02-functional.md (double enumeration)" \
  || ok "flows fallback correctly suppressed on a legacy vault"

echo "── 5: rollup heading — both spellings parse ──"
PYOUT=$(PYTHONPATH="$P/scripts/_lib" python3 - <<'EOF'
import vault_md
paren = "## Open Questions (roll-up)\n\n### Business (PRIORITY-1)\n- [ ] **OQ-X-1** q?\n"
bare  = "## Open Questions roll-up\n\n### Technical decisions (PRIORITY-2)\n- [ ] **OQ-Y-2** q?\n"
free  = "## Open Questions (roll-up)\n\n### Compliance items (PRIORITY-3)\n- [ ] **OQ-Z-3** q?\n"
a = vault_md.parse_rollup_categories(paren)
b = vault_md.parse_rollup_categories(bare)
c = vault_md.parse_rollup_categories(free)
print("paren=%s bare=%s free=%s" % (a.get("OQ-X-1"), b.get("OQ-Y-2"), c.get("OQ-Z-3")))
EOF
)
echo "  $PYOUT"
# both spellings parse; categories stay FREE-TEXT verbatim (the derive fixture
# pins "PRD inconsistencies" flowing through — never enum-normalized)
case "$PYOUT" in
  *"paren=Business bare=Technical decisions free=Compliance items"*) ok "both spellings parse; free-text categories carry through verbatim" ;;
  *) fail "roll-up heading parse: $PYOUT" ;;
esac

echo
if [ "$fails" -eq 0 ]; then echo "test-p4-emit-repair: ALL PASS"; exit 0
else echo "test-p4-emit-repair: $fails FAILURE(S)"; exit 1; fi
