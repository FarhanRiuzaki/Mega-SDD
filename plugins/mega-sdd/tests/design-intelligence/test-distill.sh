#!/usr/bin/env bash
# Structural lint: run the distiller against the installed ui-ux-pro-max data and
# assert the 5 reference files are produced with the expected shape. Sync-time only.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC="${HOME}/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max"
SRC_VER="$(find "$SRC" -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | sort -V | tail -1)"
if [ -z "$SRC_VER" ]; then echo "SKIP: ui-ux-pro-max not installed"; exit 0; fi
DATA="${SRC_VER}/src/ui-ux-pro-max/data"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
python3 "${PLUGIN_ROOT}/scripts/_lib/distill-ui-ux.py" --data="$DATA" --out="$OUT" || { echo "FAIL: distiller errored"; exit 1; }
fail=0
for f in product-style-map.yaml style-principles.md typography-pairings.md ux-rules.md; do
  [ -s "${OUT}/${f}" ] || { echo "FAIL: ${f} missing/empty"; fail=1; }
done
# v7.4.0: palette-principles.md emit removed (zero runtime consumers) — stays dead
[ -e "${OUT}/palette-principles.md" ] && { echo "FAIL: palette-principles.md re-emitted (removed v7.4.0)"; fail=1; }
# product-style-map.yaml must parse as YAML and carry >=10 product entries each with the 4 required keys.
python3 - "$OUT/product-style-map.yaml" <<'PY' || fail=1
import sys, re
text = open(sys.argv[1]).read()
try:
    import yaml
    d = yaml.safe_load(text)
    entries = d.get("products", {})
    n = len(entries)
    for k, v in entries.items():
        for key in ("style", "palette", "typography", "a11y_baseline"):
            assert key in v, f"{k} missing {key}"
except ModuleNotFoundError:
    # PyYAML absent — structural fallback: count 2-space-indented product slug keys + required fields.
    n = len(re.findall(r"^  [a-z0-9-]+:\s*$", text, re.M))
    for key in ("style:", "palette:", "typography:", "a11y_baseline:"):
        assert text.count(key) >= 10, f"missing enough {key}"
assert n >= 10, f"only {n} products"
print(f"OK: {n} products")
PY
[ "$fail" = 0 ] && echo "PASS" || exit 1
