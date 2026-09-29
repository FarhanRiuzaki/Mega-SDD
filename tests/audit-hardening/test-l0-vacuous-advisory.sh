#!/usr/bin/env bash
# test-l0-vacuous-advisory.sh — 7.13.0 (spec 2026-08-31 §1 + §2c).
#
# Field class (DD9000 #11): a typecheck-only repo makes gate-L0 format/lint SKIP
# on every bolt — 36 honest per-bolt skips never became a HUMAN decision. GROUND
# now surfaces it ONCE per run as an ADVISORY (never a gate). Pins:
#   A  .mega-sdd + tsconfig-only repo → advisory notice + probe {advisory:true}
#      stamped with plugin_version (typecheck ALONE does not silence — field case)
#   B  a linter/formatter config appears → silent, probe {advisory:false}
#   C  a recorded decision (.mega-sdd/l0-toolchain-decision.json) → fully silent,
#      no probe minted
#   D  a project pack carrying `## Toolchain` → silent (the F-14 override path);
#      D2 one holding only the _template placeholders → still advises
#   E  no .mega-sdd/ → nothing minted (phantom-root doctrine)
# And §2c — the C1 battery reads EVERY vault layout via vault_layouts, not just
# the legacy `*-bound/` sibling:
#   G  Guard 4 flags a verify+writable unit in a CANONICAL vault
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="$ROOT/plugins/mega-sdd/scripts/ground.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

echo "── A: typecheck-only repo gets the one-time advisory ──"
F1="$WORK/a"; mkdir -p "$F1/.mega-sdd"
printf '{"compilerOptions":{}}' > "$F1/tsconfig.json"
OUT=$(bash "$G" --cwd="$F1" 2>/dev/null)
echo "$OUT" | grep -q "l0_toolchain_vacuous" && ok "A1 advisory notice emitted" || bad "A1 no advisory: $(echo "$OUT" | head -2)"
echo "$OUT" | grep -q "l0-toolchain-decision.json" && ok "A2 notice names the decision-file path (the silence contract)" || bad "A2 notice lacks the decision path"
P="$F1/.mega-sdd/.l0-toolchain-probe.json"
python3 - "$P" <<'EOF' && ok "A3 probe: advisory:true, typecheckers counted, plugin_version stamped" || bad "A3 probe wrong shape"
import json, sys
p = json.load(open(sys.argv[1]))
assert p["advisory"] is True and p["formatters"] == 0 and p["linters"] == 0, p
assert p["typecheckers"] == 1, p
assert p.get("plugin_version") not in (None, "", "unknown"), p
assert p.get("written_at"), p
EOF

echo "── B: a real linter config silences the advisory ──"
printf '{}' > "$F1/biome.json"
OUT=$(bash "$G" --cwd="$F1" 2>/dev/null)
echo "$OUT" | grep -q "l0_toolchain_vacuous" && bad "B1 advisory still fires with biome.json present" || ok "B1 silent once a formatter/linter exists"
python3 -c "import json,sys; p=json.load(open(sys.argv[1])); assert p['advisory'] is False, p" "$P" \
  && ok "B2 probe refreshed to advisory:false" || bad "B2 probe not refreshed"

echo "── C: a recorded decision ends the conversation ──"
F2="$WORK/c"; mkdir -p "$F2/.mega-sdd"
printf '{"compilerOptions":{}}' > "$F2/tsconfig.json"
printf '{"decision":"na","by":"user"}' > "$F2/.mega-sdd/l0-toolchain-decision.json"
OUT=$(bash "$G" --cwd="$F2" 2>/dev/null)
echo "$OUT" | grep -q "l0_toolchain_vacuous" && bad "C1 advisory fired past a recorded decision" || ok "C1 silent"
[ -f "$F2/.mega-sdd/.l0-toolchain-probe.json" ] && bad "C2 probe minted despite the decision" || ok "C2 no probe minted"

echo "── D: a project pack with ## Toolchain silences (F-14 override path) ──"
F3="$WORK/d"; mkdir -p "$F3/.mega-sdd/packs"
printf '{"compilerOptions":{}}' > "$F3/tsconfig.json"
printf -- '---\nframework: x\n---\n## Toolchain\n```yaml\nlint_cmd: bunx biome check .\n```\n' > "$F3/.mega-sdd/packs/x.md"
OUT=$(bash "$G" --cwd="$F3" 2>/dev/null)
echo "$OUT" | grep -q "l0_toolchain_vacuous" && bad "D1 advisory fired though the pack carries Toolchain commands" || ok "D1 silent"
# P3b OD-4: the block copied from _template and never filled engages no gate (run-code-gates.sh,
# tests/code-gates 6c2), so it must not silence the advisory either — one test, _lib/pack_toolchain.py.
F3B="$WORK/d2"; mkdir -p "$F3B/.mega-sdd/packs"
printf '{"compilerOptions":{}}' > "$F3B/tsconfig.json"
{ printf -- '---\nframework: x\n---\n'; awk '/^## /{p=/^## Toolchain/} p' "$ROOT/plugins/mega-sdd/references/framework-conventions/_template.md"; } > "$F3B/.mega-sdd/packs/x.md"
OUT=$(bash "$G" --cwd="$F3B" 2>/dev/null)
grep -q '^  lint_cmd: *<' "$F3B/.mega-sdd/packs/x.md" && echo "$OUT" | grep -q "l0_toolchain_vacuous" \
  && ok "D2 a placeholder-only ## Toolchain does not silence the advisory" || bad "D2 placeholder-only Toolchain silenced GROUND"

echo "── E: no .mega-sdd → nothing minted ──"
F4="$WORK/e"; mkdir -p "$F4"
printf '{"compilerOptions":{}}' > "$F4/tsconfig.json"
bash "$G" --cwd="$F4" >/dev/null 2>&1
[ -d "$F4/.mega-sdd" ] && bad "E1 GROUND minted .mega-sdd on a pre-init repo" || ok "E1 no phantom root"

echo "── G: Guard 4 covers the CANONICAL vault layout ──"
F6="$WORK/g"; mkdir -p "$F6/.mega-sdd/vaults/myvault/units"
printf '{"decision":"na"}' > "$F6/.mega-sdd/l0-toolchain-decision.json"
cat > "$F6/.mega-sdd/vaults/myvault/units/U-010.md" <<'MD'
---
id: U-010
task_type: verify
target_files:
  - path: src/x.py
    operation: modify
---
# U-010
MD
OUT=$(bash "$G" --cwd="$F6" 2>/dev/null)
echo "$OUT" | grep -q "verify_unit_writable: U-010" && ok "G1 verify+writable unit flagged in the canonical layout" || bad "G1 canonical unit invisible to Guard 4: $(echo "$OUT" | head -2)"
# P3b OD-3: not C1 — the notice names the execute-bolts halt, never a dispatch auto-clear.
VN=$(echo "$OUT" | grep "verify_unit_writable: U-010")
echo "$VN" | grep -q "^\[advisory\] .*pre-flight 2 halts" && ! echo "$VN" | grep -q "auto-clear\|self-resolved" && ok "G2 notice is advisory and names the pre-flight 2 halt" || bad "G2 notice still claims self-resolve/auto-clear: $VN"

echo; [ $err -eq 0 ] && { echo "test-l0-vacuous-advisory: ALL PASS"; exit 0; } || { echo "test-l0-vacuous-advisory: FAILED"; exit 1; }
