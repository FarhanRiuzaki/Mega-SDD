#!/usr/bin/env bash
# test-4d-contract-truth.sh — god-review stage 4, Batch 4D.
# Pins contract truth + schema/enum coherence:
#
#   BC-PARITY-5COL     _lib/binding_md.py parse_state_map (driven through its
#                      generator, derive-binding-json.sh): aligned separators are not
#                      claim rows; short rows are ERRORS (exit 2), not silent skips.
#   BC-RESOLVE-TOKEN   resolve-oq --binding writes the structural marker grammar the
#                      gate reads; CONFIRMED_PENDING_CODE_UPDATE is gone plugin-wide;
#                      the derived binding.json carries the closed `resolution` enum.
#   RSOQ-LIVELOCK      KEEP_VAULT/DEFER hand-off no longer prescribes the re-bind
#                      that re-raises the same CONFLICT forever.
#   BC-ADVISOR-RO-1    retired v7.4.0 — the phase-advisor agent was removed (Fase 5).
#   BC-RECOMMEND-CONF-1 confidence grades the CATEGORY call, never the tech decision
#                      (references/vault-core.md — the relocated OQ contract).
#   BC-VAL-6 (docs)    example conflict IDs use the canonical CONFLICT-N form.
#   MSG-1              a conflict_unresolved drop routes to the moat halt, never to
#                      a frontmatter edit.
#
# 9.0 P1 (spec 2026-09-27-v9-simplification-design.md §2/§7): bind-codebase was
# deleted. Pins on its own references (conflict-resolution, binding-json-schema,
# oq-resolution, binding-contract, binding-md-template, constitution-and-oq,
# handoff-validation, auto-memory-handoff) were REPOINTED to the surviving owner of
# the same behaviour, or RETIRED when the behaviour itself left with the skill:
#   RETIRED  BC-ANCHOR-ATTEST-1 (the classic whole-vault binding.json attestation doc;
#            the lite JIT writer verifies anchors itself — jit-bind-and-quarantine.md)
#   RETIRED  BC-HANDOFF-3 (bind-codebase's <vault>/bound/ handoff emission; no bind
#            phase emits a handoff any more)
#   RETIRED  VAL-6 constitution halt YAML (bind_conflict_constitution_violation was
#            emitted only by bind-codebase Step 2.10)
#   RETIRED  PARITY "ALWAYS 6 columns" template annotation (binding.md has no author
#            left; the 5-cell-row ERROR stays pinned behaviourally above)
#
# 9.0 P1b: validate-binding-json.sh was deleted (its only executor, make-bound.sh,
# left with bind-codebase). BC-PARITY-5COL V1/V2 pin the SURVIVING binding_md
# grammar, so they were REPOINTED to derive-binding-json.sh (parse_state_map
# full=True, exit 2 on parse errors). V3 (claims[] missing "id") was json-side
# validator logic with no surviving owner and was RETIRED with it.
#
# Run: bash tests/god-review-s4/test-4d-contract-truth.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
DBJ="${ROOT}/plugins/mega-sdd/scripts/derive-binding-json.sh"
BMD="${ROOT}/plugins/mega-sdd/scripts/_lib/binding_md.py"
UB="${ROOT}/plugins/mega-sdd/scripts/_lib/unit_binding.py"
BM="${ROOT}/plugins/mega-sdd/skills/resolve-oq/references/binding-mode.md"
VC="${ROOT}/plugins/mega-sdd/references/vault-core.md"
JIT="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/jit-bind-and-quarantine.md"
for f in "$DBJ" "$BMD" "$UB" "$BM" "$VC" "$JIT"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t ct4d)"
trap 'rm -rf "$WORK"' EXIT

note "== 4D: contract truth + schema coherence =="

# ── BC-PARITY-5COL: empirical State Map grammar behavior (via the generator) ──
V1="$WORK/v1"; mkdir -p "$V1"
cat > "$V1/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
|:---|:---:|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | a.php:1 | high | n/a |
MD
bash "$DBJ" --vault "$V1" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && python3 -c '
import json, sys
ids = [c["id"] for c in json.load(open(sys.argv[1]))["claims"]]
sys.exit(0 if ids == ["C-001"] else 1)' "$V1/binding.json" \
  && ok "PARITY: aligned separators (|:---:|) parse as separators, not phantom claims" || fail "PARITY: aligned separator still phantom-FAILs (rc=$RC)"

V2="$WORK/v2"; mkdir -p "$V2"
cat > "$V2/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
|---|---|---|---|---|---|
| C-002 | CONFIRMED | NEW | — | n/a |
MD
OUT=$(bash "$DBJ" --vault "$V2" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q "malformed State Map row" \
  && ok "PARITY: 5-cell row is an ERROR (silent-skip divergence hole closed)" \
  || fail "PARITY: short row still silently skipped (rc=$RC)"

# ── BC-RESOLVE-TOKEN + RSOQ-LIVELOCK ──
grep -qF 'Resolution write-back grammar' "$BM" && ok "RESOLVE-TOKEN: binding-mode defines the structural write-back grammar" || fail "RESOLVE-TOKEN: grammar missing"
grep -qF '✅ RESOLVED (KEEP_VAULT — code update pending)' "$BM" && ok "RESOLVE-TOKEN: KEEP_VAULT marker uses the gate-readable form" || fail "RESOLVE-TOKEN: KEEP_VAULT marker stale"
if grep -rqF 'CONFIRMED_PENDING_CODE_UPDATE' "${ROOT}/plugins/mega-sdd"; then fail "RESOLVE-TOKEN: undefined CONFIRMED_PENDING_CODE_UPDATE marker survives plugin-wide"; else ok "RESOLVE-TOKEN: undefined enum marker eradicated plugin-wide"; fi
grep -qF 'do NOT suggest a re-bind' "$BM" && ok "RSOQ-LIVELOCK: KEEP_VAULT/DEFER hand-off no longer prescribes the looping re-bind" || fail "RSOQ-LIVELOCK: livelock hand-off survives"
if grep -qF 'now should produce bound-vault cleanly' "$BM"; then fail "RSOQ-LIVELOCK: false 'cleanly' promise survives"; else ok "RSOQ-LIVELOCK: false clean-re-bind promise removed"; fi
# 9.0 P1 repoint: the re-bind truth used to live in bind-codebase conflict-resolution.md
# ("a re-bind BEFORE the code change re-raises this CONFLICT" — the classic whole-vault
# bind). The only bind left is the per-unit JIT bind, whose writer CARRIES a human
# resolution forward while the claim + its code paths are unchanged — binding-mode.md
# states that truth, and the carry-forward block it names must exist in the writer.
grep -qF 'a later re-bind keeps them (`_lib/unit_binding.py` carries a resolution forward while the claim and its code paths are unchanged)' "$BM" \
  && grep -qF 'human-resolution carry-forward' "$UB" \
  && ok "RSOQ-LIVELOCK: binding-mode states the JIT re-bind truth (resolution carried forward; writer implements it)" \
  || fail "RSOQ-LIVELOCK: binding-mode re-bind truth stale or unimplemented"
# 9.0 P1 repoint (was conflict-resolution.md-scoped): the unimplemented unit-prerequisite
# promise must not come back anywhere; the real carrier (binding_refs) is named.
if grep -rqF 'generated units include "update code to match" task as a prerequisite' "${ROOT}/plugins/mega-sdd"; then fail "RESOLVE-TOKEN: unimplemented unit-prerequisite promise survives"; else ok "RESOLVE-TOKEN: unimplemented unit-prerequisite promise absent plugin-wide"; fi
grep -qF 'the obligation stays traceable via the CONFLICT-N reference the affected units carry in `binding_refs`' "$BM" \
  && ok "RESOLVE-TOKEN: KEEP_VAULT names the real carrier (binding_refs)" || fail "RESOLVE-TOKEN: KEEP_VAULT carrier missing"
# 9.0 P1 repoint (was bind-codebase binding-json-schema.md): the layout-2 grammar is owned
# by the code (§7 decision 10), so pin the derived field BEHAVIOURALLY — a RESOLVED block
# with the gate-readable KEEP_VAULT marker derives "resolution": "KEEP_VAULT", an active
# CONFLICT derives null — and the closed enum KEEP_VAULT | KEEP_CODE | DEFER | SPLIT.
V4="$WORK/v4"; mkdir -p "$V4"
cat > "$V4/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (2)
|---|---|---|---|---|---|
| C-001 | CONFLICT | IMPLEMENTED | a.php:1 | high | n/a |
| C-002 | CONFLICT | IMPLEMENTED | b.php:1 | high | n/a |
## Conflicts (2) — BLOCKING
### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT) — Auth uses Bearer
- **Claim**: C-001
- **Resolution**: ✅ RESOLVED (KEEP_VAULT — code update pending) 2026-09-27 — vault is right
### CONFLICT-2 — Session cookie
- **Claim**: C-002
MD
bash "$DBJ" --vault "$V4" >/dev/null 2>&1; RC=$?
python3 - "$V4/binding.json" "$BMD" <<'PY' && [ "$RC" -eq 0 ] \
  && ok "RESOLVE-TOKEN: derived binding.json defines resolution = KEEP_VAULT | KEEP_CODE | DEFER | SPLIT | null" \
  || fail "RESOLVE-TOKEN: binding.json resolution field undefined or wrong (derive rc=$RC)"
import json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[2]))
import binding_md
res = {c["id"]: c.get("resolution", "ABSENT") for c in json.load(open(sys.argv[1]))["claims"]}
ok = (res == {"C-001": "KEEP_VAULT", "C-002": None}
      and tuple(binding_md.RESOLUTION_ACTIONS) == ("KEEP_VAULT", "KEEP_CODE", "DEFER", "SPLIT"))
sys.exit(0 if ok else 1)
PY

# ── BC-ADVISOR-RO-1 (retired v7.4.0) — the agent must STAY deleted ──
if [ -e "${ROOT}/plugins/mega-sdd/agents/phase-advisor.md" ]; then fail "ADVISOR-RO: phase-advisor.md is back (removed v7.4.0)"; else ok "ADVISOR-RO: phase-advisor stays removed"; fi

# ── BC-RECOMMEND-CONF-1 ──
# 8.5.0 (spec 2026-09-20-oq-business-only-design.md): the S4 finding was "a high-only gate makes
# Step 2.7 dead code" — the business-only rule removes the confidence gate altogether (confidence
# grades the CATEGORY call, not the decision), so a tech OQ is decided at every confidence.
# 9.0 P1 repoint: bind-codebase oq-resolution.md (Step 2.7) + binding-contract.md are gone; the
# rule now lives once, in the relocated OQ contract references/vault-core.md, where `plan`
# decides tech OQs at authoring time. File-scoped negatives became plugin-wide negatives.
grep -qF 'A correctly tagged tech OQ is decided by the AI at every confidence' "$VC" && ok "RECOMMEND-CONF: tech OQs are decided at every confidence (no high-only dead code)" || fail "RECOMMEND-CONF: decision still confidence-gated"
if grep -rqF 'flow through as blocking' "${ROOT}/plugins/mega-sdd"; then fail "RECOMMEND-CONF: contradictory 'flow through as blocking' survives"; else ok "RECOMMEND-CONF: no resolution_mode mutation on confidence grounds (plugin-wide)"; fi
grep -qF '**What confidence gates**: the CATEGORY call, not the decision.' "$VC" && ok "RECOMMEND-CONF: vault-core — confidence never gates a tech decision" || fail "RECOMMEND-CONF: vault-core confidence gate stale"
if grep -rqF 'NEVER auto-accept a recommendation' "${ROOT}/plugins/mega-sdd"; then fail "RECOMMEND-CONF: the superseded never-auto-accept rail survives (8.5.0: tech is decided, business never is)"; else ok "RECOMMEND-CONF: superseded rail gone; the citation + business-signal rails replace it"; fi
grep -qF 'Two things stay forbidden: an invented citation, and "deciding" a missing fact.' "$VC" \
  && grep -qF '**Never decided by the AI** (they are `business`' "$VC" \
  && ok "RECOMMEND-CONF: the replacement rail is present (never decide business; never unverifiable citations)" || fail "RECOMMEND-CONF: replacement anti-halu rail missing"
if grep -rqF -- '--accept-recommendations' "${ROOT}/plugins/mega-sdd"; then fail "RECOMMEND-CONF: unimplemented --accept-recommendations flag survives"; else ok "RECOMMEND-CONF: unimplemented flag prose removed (plugin-wide)"; fi

# ── BC-VAL-6 (docs): canonical conflict-ID examples ──
grep -qF 'CONFLICT-N (BLOCKING)' "$BM" && ok "VAL-6: binding-mode presents conflicts as CONFLICT-N" || fail "VAL-6: binding-mode still models C-NNN headings"

# ── marker grammar + drop routing pins ──
# 9.0 P1 repoint (was bind-codebase binding-md-template.md): the structural marker grammar
# is documented where it is written — resolve-oq binding-mode's layout-2 leg.
tr '\n' ' ' < "$BM" | tr -s ' ' | grep -qF 'a marker anywhere else (prose, a legacy table) does NOT clear the gate' \
  && ok "GATE-2: binding-mode documents the structural marker grammar (only heading/Resolution-line markers clear the gate)" || fail "GATE-2: structural marker grammar note missing"
# 9.0 P1 repoint (was bind-codebase handoff-validation.md): the conflict_unresolved drop
# is raised by the per-unit JIT gate and routes to the moat halt (resolve-oq --binding).
grep -qF 'FAIL with `conflict_unresolved` drops ⇒ **halt `binding_conflict`**' "$JIT" && ok "MSG-1: JIT bind gate routes conflict_unresolved to the binding_conflict halt" || fail "MSG-1: conflict_unresolved remediation stale"

if [ "$FAILED" -eq 0 ]; then note "ALL 4D OK"; else note "4D had failures"; fi
exit $FAILED
