#!/usr/bin/env bash
# test-4d-contract-truth.sh — god-review stage 4, Batch 4D.
# Pins contract truth + schema/enum coherence:
#
#   BC-PARITY-5COL     validate-binding-json.sh: aligned separators are not claim
#                      rows; short rows are ERRORS (not silent skips); a claims[]
#                      entry missing "id" is a clean FAIL (exit 2), not a traceback.
#   BC-RESOLVE-TOKEN   resolve-oq --binding writes the structural marker grammar the
#                      gate reads; CONFIRMED_PENDING_CODE_UPDATE is gone plugin-wide.
#   RSOQ-LIVELOCK      KEEP_VAULT/DEFER hand-off no longer prescribes the re-bind
#                      that re-raises the same CONFLICT forever.
#   BC-ADVISOR-RO-1    phase-advisor's tool list delivers its read-only attestation.
#   BC-ANCHOR-ATTEST-1 binding-json-schema states the honest enforcement story.
#   BC-RECOMMEND-CONF-1 recommend-mode confidence gate is consistent across files
#                      and matches generate-intent's shipped heuristics.
#   BC-HANDOFF-3       handoff-contract bind block uses <vault>/bound/ + emitted_at.
#   BC-VAL-6 (docs)    example conflict IDs use the canonical CONFLICT-N form.
#
# Run: bash tests/god-review-s4/test-4d-contract-truth.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VBJ="${ROOT}/plugins/mega-sdd/scripts/validate-binding-json.sh"
PA="${ROOT}/plugins/mega-sdd/agents/phase-advisor.md"
HC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
BM="${ROOT}/plugins/mega-sdd/skills/resolve-oq/references/binding-mode.md"
CR="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md"
BJS="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md"
OQR="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/oq-resolution.md"
BC="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md"
BMT="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md"
COQ="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/constitution-and-oq.md"
VH="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/handoff-validation.md"
for f in "$VBJ" "$PA" "$HC" "$BM" "$CR" "$BJS" "$OQR" "$BC" "$BMT" "$COQ" "$VH"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t ct4d)"
trap 'rm -rf "$WORK"' EXIT

note "== 4D: contract truth + schema coherence =="

# ── BC-PARITY-5COL: empirical validator behavior ──
V1="$WORK/v1"; mkdir -p "$V1"
cat > "$V1/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
|:---|:---:|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | a.php:1 | high | n/a |
MD
printf '%s\n' '{"claims": [{"id": "C-001", "verdict": "CONFIRMED", "state": "IMPLEMENTED"}]}' > "$V1/binding.json"
bash "$VBJ" --vault "$V1" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "PARITY: aligned separators (|:---:|) parse as separators, not phantom claims" || fail "PARITY: aligned separator still phantom-FAILs (rc=$RC)"

V2="$WORK/v2"; mkdir -p "$V2"
cat > "$V2/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (1)
|---|---|---|---|---|---|
| C-002 | CONFIRMED | NEW | — | n/a |
MD
printf '%s\n' '{"claims": []}' > "$V2/binding.json"
OUT=$(bash "$VBJ" --vault "$V2" 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q "malformed State Map row" \
  && ok "PARITY: 5-cell row is an ERROR (silent-skip divergence hole closed)" \
  || fail "PARITY: short row still silently skipped (rc=$RC)"

V3="$WORK/v3"; mkdir -p "$V3"
cat > "$V3/binding.md" <<'MD'
# Binding Manifest
## Implementation State Map (0)
|---|---|---|---|---|---|
MD
printf '%s\n' '{"claims": [{"verdict": "CONFIRMED", "state": "NEW"}]}' > "$V3/binding.json"
OUT=$(bash "$VBJ" --vault "$V3" 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q "missing 'id'" && ! echo "$OUT" | grep -q "Traceback" \
  && ok "PARITY: claims[] entry missing id → clean FAIL exit 2 (no traceback)" \
  || fail "PARITY: id-less claim crashes or passes (rc=$RC): $(echo "$OUT" | head -2)"

# ── BC-RESOLVE-TOKEN + RSOQ-LIVELOCK ──
grep -qF 'Resolution write-back grammar' "$BM" && ok "RESOLVE-TOKEN: binding-mode defines the structural write-back grammar" || fail "RESOLVE-TOKEN: grammar missing"
grep -qF '✅ RESOLVED (KEEP_VAULT — code update pending)' "$BM" && ok "RESOLVE-TOKEN: KEEP_VAULT marker uses the gate-readable form" || fail "RESOLVE-TOKEN: KEEP_VAULT marker stale"
if grep -rqF 'CONFIRMED_PENDING_CODE_UPDATE' "${ROOT}/plugins/mega-sdd"; then fail "RESOLVE-TOKEN: undefined CONFIRMED_PENDING_CODE_UPDATE marker survives plugin-wide"; else ok "RESOLVE-TOKEN: undefined enum marker eradicated plugin-wide"; fi
grep -qF 'do NOT suggest a re-bind' "$BM" && ok "RSOQ-LIVELOCK: KEEP_VAULT/DEFER hand-off no longer prescribes the looping re-bind" || fail "RSOQ-LIVELOCK: livelock hand-off survives"
if grep -qF 'now should produce bound-vault cleanly' "$BM"; then fail "RSOQ-LIVELOCK: false 'cleanly' promise survives"; else ok "RSOQ-LIVELOCK: false clean-re-bind promise removed"; fi
grep -qF 'a re-bind BEFORE the code change re-raises this CONFLICT' "$CR" && ok "RSOQ-LIVELOCK: conflict-resolution KEEP_VAULT states the re-raise truth" || fail "RSOQ-LIVELOCK: conflict-resolution stale"
if grep -qF 'generated units include "update code to match" task as a prerequisite' "$CR"; then fail "RESOLVE-TOKEN: unimplemented unit-prerequisite promise survives"; else ok "RESOLVE-TOKEN: unimplemented promise replaced with the real carrier (binding_refs)"; fi
grep -qF '"resolution": "KEEP_VAULT | KEEP_CODE | DEFER | SPLIT | null"' "$BJS" && ok "RESOLVE-TOKEN: binding.json schema defines the resolution field" || fail "RESOLVE-TOKEN: resolution field undefined"

# ── BC-ADVISOR-RO-1 ──
grep -qE '^tools: Read, Grep, Glob$' "$PA" && ok "ADVISOR-RO: tool list is Read/Grep/Glob (read-only delivered by tooling)" || fail "ADVISOR-RO: tool list still grants write capability"
if grep -qE '^tools:.*Bash' "$PA"; then fail "ADVISOR-RO: Bash survives in the advisor tool list"; else ok "ADVISOR-RO: no shell capability"; fi

# ── BC-ANCHOR-ATTEST-1 ──
grep -qF 'bind-time authoring obligation' "$BJS" && ok "ANCHOR-ATTEST: honest enforcement story (authoring obligation, advisor sampling, A1 rail scope)" || fail "ANCHOR-ATTEST: attestation still claims unimplemented enforcement"
if grep -qF 'anchor accuracy is enforced at bind time' "$BJS"; then fail "ANCHOR-ATTEST: old positive attestation survives"; else ok "ANCHOR-ATTEST: old attestation removed"; fi

# ── BC-RECOMMEND-CONF-1 ──
grep -qF '`classification_confidence: high` OR `medium`' "$OQR" && ok "RECOMMEND-CONF: Step 2.7 fires at high+medium (matches shipped generate-intent heuristics)" || fail "RECOMMEND-CONF: recommend gate still high-only dead code"
if grep -qF 'flow through as blocking' "$OQR"; then fail "RECOMMEND-CONF: contradictory 'flow through as blocking' survives"; else ok "RECOMMEND-CONF: no resolution_mode mutation on confidence grounds"; fi
grep -qF '**Recommend mode**: surfaced at `high` AND `medium`' "$BC" && ok "RECOMMEND-CONF: binding-contract confidence gate split per mode" || fail "RECOMMEND-CONF: binding-contract gate stale"
if grep -qF -- '--accept-recommendations' "$OQR"; then fail "RECOMMEND-CONF: unimplemented --accept-recommendations flag survives"; else ok "RECOMMEND-CONF: unimplemented flag prose removed"; fi

# ── BC-HANDOFF-3 ── (M-02 ownership flip: the OPERATIVE bind handoff template is the
# skill's own auto-memory-handoff.md; handoff-contract's per-skill section is now a
# routing index with no YAML blocks. Pin the operative template — same assertions.)
AMH="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md"
python3 - "$AMH" <<'PY' && ok "HANDOFF-3: operative bind template uses <vault>/bound/ + emitted_at (no legacy vault-bound/)" || fail "HANDOFF-3: operative bind handoff template stale"
import re, sys
doc = open(sys.argv[1]).read()
# Header suffix is NOT part of this pin — it moved from "(--auto)" to "(UNCONDITIONAL)"
# when bind's handoff stopped being --auto-gated (fork-safety fix, 2026-07-30). The pinned
# subject is the TEMPLATE BODY below it, unchanged: <vault>/bound/ + emitted_at, no legacy
# vault-bound/. Anchor on the stable header stem so a future rename cannot silently skip it.
m = re.search(r"## Handoff emission[^\n]*\n.*?```yaml\n(.*?)```", doc, re.S)
assert m, "bind handoff template not found"
b = m.group(1)
sys.exit(0 if ("emitted_at:" in b and "<vault>/bound/" in b and "vault-bound/" not in b) else 1)
PY

# ── BC-VAL-6 (docs): canonical conflict-ID examples ──
grep -qF 'CONFLICT-N (BLOCKING)' "$BM" && ok "VAL-6: binding-mode presents conflicts as CONFLICT-N" || fail "VAL-6: binding-mode still models C-NNN headings"
grep -qF 'conflict_id: CONFLICT-7' "$COQ" && ok "VAL-6: constitution halt YAML uses the canonical conflict-ID form" || fail "VAL-6: constitution example still C-007"

# ── template + marker grammar pins ──
grep -qF 'ALWAYS 6 columns' "$BMT" && ok "PARITY: template pins 6-columns-always (5-col churn loop prevented)" || fail "PARITY: template annotation still ambiguous"
grep -qF 'Resolution markers are STRUCTURAL' "$BMT" && ok "GATE-2: template documents the structural marker grammar" || fail "GATE-2: template grammar note missing"
grep -qF '`conflict_unresolved` (the moat' "$VH" && ok "MSG-1: validate-handoff command routes per drop type" || fail "MSG-1: command remediation stale"

if [ "$FAILED" -eq 0 ]; then note "ALL 4D OK"; else note "4D had failures"; fi
exit $FAILED
