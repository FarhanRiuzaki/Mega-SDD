#!/usr/bin/env bash
# test-w2-contract-pins.sh — W-batch W2 (spec 2026-07-19-w-batch-script-derive.md):
# binding.json is script-derived from binding.md — doc/skill contract pins.
#
#   P1  bind SKILL Step 4.5 runs derive-binding-json.sh and NO LONGER instructs
#       the model to re-emit 'from the SAME claim data'
#   P2  binding-md-template carries the three new grammar obligations —
#       binding_metadata `head:`, the `[reason:` Anchor-cell token (closed
#       enum), the `- **Claim**:` conflict-block line — while 'ALWAYS 6
#       columns' survives (no 7th column)
#   P3  binding-mode re-derives via derive-binding-json.sh; the hand-patch-json
#       instruction ("set the claim's `resolution:`") is gone; no post-derive
#       parity re-run is prescribed
#   P4  binding-json-schema: generated_by = derive-binding-json@1.0.0, schema
#       stays "1.0", the resolution-enum line + 'bind-time authoring
#       obligation' pins survive
#   P5  _lib/binding_md.py exists; BOTH the validator and the generator import
#       it (one grammar, never forked)
#   P6  empirical: derive on the plugin round-trip fixture → parity validator
#       exits 0 on the derived pair (top-level CI exercises the shared lib)
#   P7  tests/god-review-s4/test-4d-contract-truth.sh still exits 0 (all its
#       string + empirical pins survive W2)
#
# Run: bash tests/derived-artifacts/test-w2-contract-pins.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
SKILL="${P}/skills/bind-codebase/SKILL.md"
BMT="${P}/skills/bind-codebase/references/binding-md-template.md"
BJS="${P}/skills/bind-codebase/references/binding-json-schema.md"
BM="${P}/skills/resolve-oq/references/binding-mode.md"
LIB="${P}/scripts/_lib/binding_md.py"
DERIVE="${P}/scripts/derive-binding-json.sh"
VALIDATE="${P}/scripts/validate-binding-json.sh"
VCC="${P}/scripts/validate-conflict-classification.sh"
FX="${P}/tests/graph/fixtures/derive-full"
for f in "$SKILL" "$BMT" "$BJS" "$BM" "$DERIVE" "$VALIDATE" "$VCC"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w2pins)"
trap 'rm -rf "$WORK"' EXIT

echo "== W2 contract pins: binding.json is derived, never re-typed =="

# ── P1: SKILL Step 4.5 ──
grep -qF 'derive-binding-json.sh' "$SKILL" && ok "P1: Step 4.5 runs derive-binding-json.sh" || fail "P1: derive script not named in SKILL.md"
if grep -qF 'from the SAME claim data' "$SKILL"; then fail "P1: model re-emission instruction ('from the SAME claim data') survives"; else ok "P1: re-emission instruction gone (json is derived, not re-typed)"; fi
grep -qF 'fix the Step-4' "$SKILL" && ok "P1: exit 2 = authoring bug posture (fix the Step-4 write and re-run)" || fail "P1: exit-2 remediation posture missing"

# ── P2: template grammar ──
grep -qF 'ALWAYS 6 columns' "$BMT" && ok "P2: 'ALWAYS 6 columns' survives (token lives INSIDE the Anchor cell)" || fail "P2: 6-column pin lost"
grep -qF '[reason:' "$BMT" && ok "P2: [reason: <enum>] Anchor-cell token grammar present" || fail "P2: reason-token grammar missing"
grep -qF 'truncated_section' "$BMT" && grep -qF 'kb_confirmed' "$BMT" && ok "P2: closed state_reason enum spelled out" || fail "P2: closed enum incomplete"
grep -qF -- '- **Claim**:' "$BMT" && ok "P2: '- **Claim**:' conflict-block line present" || fail "P2: Claim-line grammar missing"
grep -qE '^\s+head: ' "$BMT" && ok "P2: binding_metadata head: field present" || fail "P2: head: frontmatter field missing"

# ── P3: binding-mode write-back ──
grep -qF 'derive-binding-json.sh' "$BM" && ok "P3: binding-mode re-derives binding.json via the script" || fail "P3: re-derive instruction missing"
if grep -qF "set the claim's" "$BM"; then fail "P3: hand-patch-json instruction survives"; else ok "P3: hand-patch-json instruction gone"; fi
grep -qF -- '- **Claim**: C-NNN' "$BM" && ok "P3: write-back ensures the Claim line (legacy self-heal)" || fail "P3: Claim-line self-heal missing"
grep -qF 'Do NOT re-run `validate-binding-json.sh`' "$BM" && ok "P3: no tautological post-derive parity re-run" || fail "P3: parity-re-run posture missing"

# ── P4: schema pins ──
grep -qF 'derive-binding-json@1.0.0' "$BJS" && ok "P4: generated_by = derive-binding-json@1.0.0" || fail "P4: generated_by provenance stale"
grep -qF '"schema_version": "1.0"' "$BJS" && ok "P4: schema_version stays 1.0 (key set unchanged)" || fail "P4: schema_version drifted"
grep -qF '"resolution": "KEEP_VAULT | KEEP_CODE | DEFER | SPLIT | null"' "$BJS" && ok "P4: resolution-enum line intact (4D pin)" || fail "P4: resolution enum line lost"
grep -qF 'bind-time authoring obligation' "$BJS" && ok "P4: honest anchor-enforcement story intact (4D pin)" || fail "P4: authoring-obligation phrasing lost"

# ── P5: shared lib, both scripts ──
[ -f "$LIB" ] && ok "P5: scripts/_lib/binding_md.py exists" || fail "P5: binding_md.py missing"
# anchored to REAL import statements — the bare 'binding_md' token also lives
# in header comments, so a grammar fork that keeps the comment would pass
grep -qE '(^|[[:space:]])(from binding_md import|import binding_md)' "$VALIDATE" \
  && ok "P5: validator imports the shared parser (import statement, not a comment)" \
  || fail "P5: validator does not IMPORT binding_md (comment-only reference?)"
grep -qE '(^|[[:space:]])(from binding_md import|import binding_md)' "$DERIVE" \
  && ok "P5: generator imports the shared parser (import statement, not a comment)" \
  || fail "P5: generator does not IMPORT binding_md (comment-only reference?)"
grep -qF -- '- **Claim**' "$VCC" && ok "P5: conflict-classification WARNs on a Claim-less ACTIVE block" || fail "P5: Claim-line WARN missing from validate-conflict-classification.sh"

# ── P6: empirical — top-level CI exercises the shared lib ──
V="$WORK/v1"; mkdir -p "$V"
cp "$FX/binding.md" "$V/binding.md"
bash "$DERIVE" --vault "$V" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] || fail "P6: derive failed on the round-trip fixture (rc=$RC)"
bash "$VALIDATE" --vault "$V" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "P6: validate-binding-json.sh green on a freshly derived pair" || fail "P6: parity validator rejects the derived pair (rc=$RC)"

# ── P7: 4D contract-truth suite survives W2 ──
if bash "${ROOT}/tests/god-review-s4/test-4d-contract-truth.sh" </dev/null >/dev/null 2>&1; then
  ok "P7: test-4d-contract-truth.sh still exits 0"
else
  fail "P7: 4D contract pins broken by W2"
fi

if [ "$FAILED" -eq 0 ]; then echo "ALL W2 PINS OK"; exit 0; else echo "W2 pins FAILED"; exit 1; fi
