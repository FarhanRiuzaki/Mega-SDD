#!/usr/bin/env bash
# test-3d-cache-correctness.sh — god-review stage 3, Batch 3D.
# Pins what survives of the deep-scan cache-correctness fixes in 9.0.
#
# 9.0 P1 retired (design 2026-09-27-v9-simplification-design.md §3, §7 #1/#8):
#   ECO-3 + round-2 dotnet digest checks — compute-lock-digests.sh was deleted
#     (its sole callers were the removed scan-codebase skill).
#   DS-1/DS-2 deep-scan-gate.md / deep-scan-dispatch.md pins (signature inputs,
#     stale_slices ∪= prior.partial_slices, no per_slice entry for failed
#     domains) — the scan-codebase skill (the only starterkit-context producer)
#     was deleted.
#   DS-2 starterkit_metrics_inconsistent remediation — its only producer (the
#     classic generate-units handoff) is gone; the halt left the registry.
#   DS-6 cache-reuse rule + invalidation matrix — producer-only prose, dropped
#     from the schema with the producer.
#
# Still pinned (the schema survives: legacy starterkit-context.yaml files stay
# readable by execute-bolts / validate-unit-spec / ground.sh):
#   DS-1   the legacy cache_signatures schema comments carry src_component.
#   DS-2   no surviving doc revives the stale `--force-deep` remediation.
#   DS-6   the canonical schema documents 5 per_slice entries incl. reuse.
#
# Run: bash tests/god-review-s3/test-3d-cache-correctness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCS="${ROOT}/plugins/mega-sdd/references/starterkit-context-schema.md"
# vault-core.md relocated in 9.0 from skills/generate-intent/references/ to the
# plugin-root references/; vault-contract.md's surviving contracts went there
# and to skills/plan/references/.
VCORE="${ROOT}/plugins/mega-sdd/references/vault-core.md"
PLANREF="${ROOT}/plugins/mega-sdd/skills/plan/references"
HPR="${ROOT}/plugins/mega-sdd/references/halt-protocol.md"
HFAM="${ROOT}/plugins/mega-sdd/references/halt-families"
for f in "$SCS" "$VCORE" "$HPR"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done
for d in "$PLANREF" "$HFAM"; do [ -d "$d" ] || { echo "missing $d"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 3D: deep-scan cache correctness (surviving schema pins) =="

# ── DS-1: legacy signature schema comments carry src_component ──
grep -qF 'src_component(auth)' "$SCS" && ok "DS-1: schema comments mirror the signature inputs (src_component)" || fail "DS-1: schema comments stale"

# ── DS-2: the stale --force-deep remediation is not revived anywhere it could land ──
if grep -qF 're-run `scan-codebase --force-deep`' "$VCORE" || grep -qF 're-run `scan-codebase --force-deep`' "$HPR" \
   || grep -rqF 're-run `scan-codebase --force-deep`' "$HFAM/" || grep -rqF 're-run `scan-codebase --force-deep`' "$PLANREF/"; then
  fail "DS-2: stale --force-deep remediation survives"
else
  ok "DS-2: no stale --force-deep remediation"
fi

# ── DS-6: canonical schema documents 5 slices incl. reuse ──
python3 - "$SCS" <<'PY' && ok "DS-6: schema per_slice block lists all 5 domains (incl. reuse)" || fail "DS-6: schema per_slice incomplete"
import re, sys
doc = open(sys.argv[1]).read()
m = re.search(r"^  per_slice:.*?^```", doc, re.M | re.S)
assert m, "per_slice block not found"
block = m.group(0)
missing = [d for d in ("auth:", "authz:", "ui_ux:", "libs:", "reuse:") if d not in block]
sys.exit(0 if not missing else 1)
PY

if [ "$FAILED" -eq 0 ]; then note "ALL 3D OK"; else note "3D had failures"; fi
exit $FAILED
