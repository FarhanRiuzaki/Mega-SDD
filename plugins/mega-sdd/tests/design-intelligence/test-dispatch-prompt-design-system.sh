#!/usr/bin/env bash
# TDD harness: a ui_ux dispatch prompt with Design tokens but NO Design system => FAIL.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/scripts/validate-dispatch-prompt.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
PD="${ROOT}/.mega-sdd/vaults/v1/bolts/U-001"
mkdir -p "$PD"
# minimal pack so the gate does not SKIP: provide a UI quality signatures view_glob
# NOTE: resolver reads .mega-sdd/codebase/starterkit-context.yaml (not config.yaml)
PACKDIR="${ROOT}/.mega-sdd/codebase"; mkdir -p "$PACKDIR"
cat > "${ROOT}/.mega-sdd/codebase/starterkit-context.yaml" <<'EOF'
framework_pack: laravel
EOF
# Use the repo laravel pack via resolver default; if unavailable the gate SKIPs (acceptable).
cat > "${PD}/dispatch-prompt.md" <<'EOF'
starterkit_relevance: [ui_ux]
UI/UX: extends=layouts.app, notification=sweetalert2, idioms=[toast]
Design tokens: colors={primary:#2563EB}; spacing=8px; fonts=[Inter]
Reference code example
File: resources/views/orders/show.blade.php
Pattern: view
EOF
OUT="$(bash "$VALIDATOR" --cwd="$ROOT" --quiet 2>/dev/null; echo "EXIT=$?")"
code=$(grep -o 'EXIT=[0-9]*' <<<"$OUT" | cut -d= -f2)
state="${ROOT}/.mega-sdd/.dispatch-prompt-state.json"
if grep -q '"reason": "pack declares no' "$state" 2>/dev/null; then echo "SKIP: no pack view_glob in env"; exit 0; fi
grep -q '"issue": "design_system_not_injected"' "$state" || { echo "FAIL: expected design_system_not_injected finding"; cat "$state"; exit 1; }
[ "$code" = "1" ] || { echo "FAIL: expected exit 1, got $code"; exit 1; }
echo "PASS (negative)"
# Now add the Design system line => the prompt has tokens + design system + view exemplar,
# so ALL findings clear and the validator exits 0.
printf 'Design system: minimalism/trust-blue\n' >> "${PD}/dispatch-prompt.md"
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; pcode=$?
grep -q '"issue": "design_system_not_injected"' "$state" && { echo "FAIL: design_system_not_injected should be gone"; exit 1; }
[ "$pcode" = "0" ] || { echo "FAIL: expected exit 0 after fix, got $pcode"; cat "$state"; exit 1; }
echo "PASS (positive)"
# ADV-07b parity: a placeholder value ("Design system: TODO") is a vacuous pass and must re-fire.
sed -i.bak 's|^Design system: .*|Design system: TODO|' "${PD}/dispatch-prompt.md" && rm -f "${PD}/dispatch-prompt.md.bak"
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1
grep -q '"issue": "design_system_not_injected"' "$state" || { echo "FAIL: placeholder 'Design system: TODO' must re-fire design_system_not_injected"; cat "$state"; exit 1; }
echo "PASS (placeholder rejected)"
