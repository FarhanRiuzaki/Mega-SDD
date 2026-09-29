#!/usr/bin/env bash
# test-3c-secret-redaction.sh — god-review stage 3, Batch 3C.
# Pins secret-scan.sh delivering what it attests (AH-1).
#
#   AH-1  a PEM private-key block is redacted WHOLE — no base64 body line and no
#         END marker survives --redact (pre-fix: only the BEGIN header was
#         stripped while the report said redacted:true, exit 0 — making the
#         residue LESS detectable to downstream scanners).
#         A truncated block (no END marker) still gets its header redacted.
#   AH-6  RETIRED in 9.0 P1: it pinned scan-codebase's deep-scan write sites
#         (deep-scan-dispatch.md Step 10.5.3 + halts-flags-handoff.md gate
#         prose). scan-codebase was removed and deep-scan was the only producer
#         of starterkit-context.yaml / reuse-index.yaml (v9 design §7 #1). The
#         surviving --redact caller (extract-intelligence's pre-write gate) is
#         pinned by tests/fmea/test-fmea-pins.sh U1 and
#         tests/extract-census/test-prd-kontrak-engine.sh.
#
# Run: bash tests/god-review-s3/test-3c-secret-redaction.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SS="${ROOT}/plugins/mega-sdd/scripts/secret-scan.sh"
[ -f "$SS" ] || { echo "missing $SS"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t sec3c)"
trap 'rm -rf "$WORK"' EXIT

note "== 3C: secret-scan redaction integrity =="

# ── AH-1: whole PEM block redacted (body + END must NOT survive) ──
A="$WORK/artifact.md"
{
  echo '# scan artifact'
  echo 'config = "-----BEGIN RSA PRIVATE KEY-----'
  echo 'MIIEowIBAAKCAQEAfakebody1fakebody1fakebody1fakebody1'
  echo 'MIIEowIBAAKCAQEAfakebody2fakebody2fakebody2fakebody2'
  echo '-----END RSA PRIVATE KEY-----"'
  echo 'other = 1'
} > "$A"
OUT="$(bash "$SS" --redact "$A")"; RC=$?
[ "$RC" -eq 0 ] || fail "AH-1: --redact exited $RC"
if grep -q "fakebody1" "$A" || grep -q "END RSA PRIVATE KEY" "$A"; then
  fail "AH-1: key body or END marker SURVIVED --redact (the pre-fix hole)"
else
  ok "AH-1: no base64 body line and no END marker survives --redact"
fi
grep -q "\[REDACTED-SECRET\]" "$A" && ok "AH-1: block replaced with [REDACTED-SECRET]" || fail "AH-1: no redaction marker written"
grep -q 'other = 1' "$A" && ok "AH-1: surrounding lines intact" || fail "AH-1: redaction damaged surrounding content"
COUNT="$(OUT="$OUT" python3 -c "import json,os;d=json.loads(os.environ['OUT']);print(sum(1 for f in d['findings'] if f['pattern'].startswith('private-key')))")"
[ "$COUNT" = "1" ] && ok "AH-1: exactly ONE private-key finding (no header double-report)" || fail "AH-1: expected 1 private-key finding, got $COUNT"

# ── AH-1: truncated block (no END) → header AND body redacted via fallback ──
B="$WORK/truncated.md"
{
  echo '-----BEGIN OPENSSH PRIVATE KEY-----'
  echo 'b3BlbnNzaC1rZXktdjEAAAAAtruncatedtruncatedtruncated'
  echo 'b3BlbnNzaC1rZXktdjEAAAAAtruncatedline2line2line2line2'
} > "$B"
bash "$SS" --redact "$B" >/dev/null
grep -q "BEGIN OPENSSH PRIVATE KEY" "$B" && fail "AH-1: truncated-block header survived" || ok "AH-1: truncated block (no END) — header redacted (fallback)"
grep -q "b3BlbnNzaC" "$B" && fail "r2: truncated-block BODY survived --redact (the residue hole)" \
  || ok "r2: truncated block — contiguous base64 body consumed by the fallback (no residue)"

# ── round-2 (fix-review): a truncated block followed by a complete one must NOT
#    swallow the innocent text between them (no-BEGIN-crossing + kind backreference) ──
E="$WORK/twoblocks.md"
{
  echo '-----BEGIN RSA PRIVATE KEY-----'
  echo 'MIIEowIBAAKCAQEAtruncatedfirstblocknoendmarkerhere'
  echo 'INNOCENT LINE that must survive redaction'
  echo '-----BEGIN EC PRIVATE KEY-----'
  echo 'MIGkAgEBBDBsecondblockbodysecondblockbodysecondbody'
  echo '-----END EC PRIVATE KEY-----'
} > "$E"
bash "$SS" --redact "$E" >/dev/null
grep -q "INNOCENT LINE that must survive" "$E" \
  && ok "r2: innocent text between a truncated and a complete block SURVIVES (no cross-block swallow)" \
  || fail "r2: cross-block swallow — innocent content redacted"
if grep -q "MIGkAgEBBDB" "$E" || grep -q "MIIEowIBAAKCAQEAtruncated" "$E"; then
  fail "r2: key material survived in the two-block case"
else
  ok "r2: both blocks' key material redacted (complete via \\1-matched span; truncated via fallback)"
fi

# ── AH-1 regression: the other families still redact fully ──
C="$WORK/mixed.md"
{
  echo 'aws = AKIAABCDEFGHIJKLMNOP'
  echo 'password: "supersecretvalue99"'
  echo 'gh = ghp_abcdefghijklmnopqrstuvwxyz0123456789'
} > "$C"
bash "$SS" --redact "$C" >/dev/null
if grep -q "AKIAABCDEFGHIJKLMNOP" "$C" || grep -q "supersecretvalue99" "$C" || grep -q "ghp_abcdef" "$C"; then
  fail "AH-1: a non-PEM family survived --redact (regression)"
else
  ok "AH-1: AWS key / generic assignment / GitHub token all still redact"
fi

# ── AH-1: clean file → no findings, exit 0, content untouched ──
D="$WORK/clean.md"
printf '%s\n' '# clean' 'nothing here' > "$D"
OUT="$(bash "$SS" --check "$D")"; RC=$?
[ "$RC" -eq 0 ] && ok "AH-1: clean file → --check exit 0" || fail "AH-1: clean file should exit 0, got $RC"

if [ "$FAILED" -eq 0 ]; then note "ALL 3C OK"; else note "3C had failures"; fi
exit $FAILED
