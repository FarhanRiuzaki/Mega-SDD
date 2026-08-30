#!/usr/bin/env bash
# test-f14-project-pack.sh — F-14 (spec 2026-08-30 §6).
#
# Field defect: the project authored .mega-sdd/packs/elysia.md for its stack;
# the resolver read only the plugin pack root, the GROUND matcher read only
# root manifests (the elysia dependency lived in apps/api/package.json), and
# state.json was minted pre-git and never regenerated — so 36/36 dispatches got
# `_universal` and every pack-driven gate SKIPped. Pins:
#   A  a project pack at .mega-sdd/packs/<name>.md auto-resolves via its
#      detection_signature against a ONE-LEVEL WORKSPACE manifest, with no
#      starterkit-context / codebase-map / state.json — chain most-specific-first
#      across roots (project pack extends the plugin _universal)
#   B  --section merges the project pack's section FIRST
#   C  cache: hit is byte-identical; editing the project pack OR adding a
#      manifest dependency busts it (cold re-resolve, not a stale answer)
#   D  a project pack SHADOWS a same-named plugin pack; plugin resolution of a
#      root manifest is unchanged (regression)
#   E  the shared matcher (state_probes) reports the project pack + nested manifest
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"; R="$P/scripts/_lib/resolve-framework-pack.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

F="$WORK/proj"; mkdir -p "$F/.mega-sdd/packs" "$F/apps/api" "$F/apps/web"
printf '{"name":"api","dependencies":{"elysia":"^1.2.0"}}\n' > "$F/apps/api/package.json"
printf '{"name":"web","dependencies":{"react":"^19"}}\n' > "$F/apps/web/package.json"
cat > "$F/.mega-sdd/packs/elysia.md" <<'MD'
---
framework: elysia
framework_version_range: "1.x"
detection_signature:
  package_manifest: package.json
  dependency_marker: "elysia"
extends: _universal
pack_tier: full
---
# Elysia pack (project-local)

## Naming standards
- ELYSIA_PROJECT_NAMING_TOKEN: route files are kebab-case
MD

echo "── A: project pack auto-resolves from a workspace manifest ──"
OUT=$(bash "$R" --cwd="$F" 2>"$WORK/err"); rc=$?
[ "$OUT" = "elysia.md _universal.md" ] && ok "A1 chain = elysia.md _universal.md (project pack → plugin _universal)" || bad "A1 chain='$OUT' rc=$rc $(head -3 "$WORK/err")"
grep -q "live GROUND matcher" "$WORK/err" && ok "A2 resolved by the live matcher (no state.json needed)" || bad "A2 source: $(head -2 "$WORK/err")"

echo "── B: --section merges the project section first ──"
OUT=$(bash "$R" --cwd="$F" --section=naming --quiet 2>/dev/null)
printf '%s' "$OUT" | head -3 | grep -q "from elysia.md" && printf '%s' "$OUT" | grep -q "ELYSIA_PROJECT_NAMING_TOKEN" \
  && ok "B1 project pack section emitted first, then _universal" || bad "B1 section merge: $(printf '%s' "$OUT" | head -3)"

echo "── C: cache correctness ──"
OUT1=$(bash "$R" --cwd="$F" --quiet 2>/dev/null); OUT2=$(bash "$R" --cwd="$F" --quiet 2>/dev/null)
[ "$OUT1" = "$OUT2" ] && [ -f "$F/.mega-sdd/.cache/pack-resolver/_chain.out" ] && ok "C1 second call is a byte-identical hit" || bad "C1 cache hit differs"
sleep 1; printf '\n## Idioms\n- new\n' >> "$F/.mega-sdd/packs/elysia.md"
OUT=$(bash "$R" --cwd="$F" --section=idioms --quiet 2>/dev/null)
printf '%s' "$OUT" | grep -q "from elysia.md" && ok "C2 editing the project pack busts the cache (new section visible)" || bad "C2 stale cache after project pack edit: $(printf '%s' "$OUT" | head -2)"
# a new dependency in a nested manifest must re-resolve (no stale _universal)
G="$WORK/proj2"; mkdir -p "$G/.mega-sdd/packs" "$G/apps/api"; cp "$F/.mega-sdd/packs/elysia.md" "$G/.mega-sdd/packs/"
printf '{"name":"api","dependencies":{}}\n' > "$G/apps/api/package.json"
OUT=$(bash "$R" --cwd="$G" --quiet 2>/dev/null); [ "$OUT" = "_universal.md" ] || bad "C3 precondition: expected _universal, got '$OUT'"
sleep 1; printf '{"name":"api","dependencies":{"elysia":"^1.2.0"}}\n' > "$G/apps/api/package.json"
OUT=$(bash "$R" --cwd="$G" --quiet 2>/dev/null)
[ "$OUT" = "elysia.md _universal.md" ] && ok "C3 adding the dependency to apps/api/package.json busts the cache → elysia" || bad "C3 stale: '$OUT'"

echo "── D: shadowing + plugin regression ──"
H="$WORK/proj3"; mkdir -p "$H/.mega-sdd/packs"
printf '{"require":{"laravel/framework":"^11.0"}}\n' > "$H/composer.json"
OUT=$(bash "$R" --cwd="$H" --quiet 2>/dev/null)
[ "$OUT" = "laravel.md _universal.md" ] && ok "D1 plugin pack still resolves from a root manifest (laravel)" || bad "D1 plugin resolution changed: '$OUT'"
cat > "$H/.mega-sdd/packs/laravel.md" <<'MD'
---
framework: laravel
detection_signature:
  package_manifest: composer.json
  dependency_marker: "laravel/framework"
extends: _universal
---
# House Laravel pack

## Naming standards
- HOUSE_LARAVEL_TOKEN
MD
sleep 1
OUT=$(bash "$R" --cwd="$H" --section=naming --quiet 2>/dev/null)
printf '%s' "$OUT" | grep -q "HOUSE_LARAVEL_TOKEN" && ok "D2 a project pack SHADOWS the same-named plugin pack" || bad "D2 project laravel.md not preferred: $(printf '%s' "$OUT" | head -2)"

echo "── E: the shared matcher ──"
python3 - "$P/scripts/_lib" "$F" <<'EOF' && ok "E1 state_probes.probe_framework_pack → elysia via apps/api/package.json" || bad "E1 matcher did not find the project pack / nested manifest"
import sys, os
sys.path.insert(0, sys.argv[1]); import state_probes as sp
r = sp.probe_framework_pack(sys.argv[2], sp.probe_manifests(sys.argv[2]))
assert r["pack"] == "elysia" and r["manifest"] == "apps/api/package.json", r
assert "apps/api/package.json" in sp.probe_workspace_manifests(sys.argv[2])
assert sp.probe_manifests(sys.argv[2]) == [], sp.probe_manifests(sys.argv[2])  # root probe stays root-only
EOF
grep -q '".mega-sdd", "packs"' "$P/scripts/ground.sh" && ok "E2 ground.sh checks the canonical project pack dir" || bad "E2 ground.sh lacks .mega-sdd/packs"

echo; [ $err -eq 0 ] && { echo "test-f14-project-pack: ALL PASS"; exit 0; } || { echo "test-f14-project-pack: FAILED"; exit 1; }
