#!/usr/bin/env bash
# GROUND Guard 7 (deep_scan_cache_corrupt), pinned by behavior. A legacy
# .mega-sdd/codebase/starterkit-context.yaml with no top-level key is renamed aside to
# starterkit-context.yaml.corrupt-<ts> (filename-safe: no ':' or '.'), never deleted; a valid
# one is left alone. This pins the ts_fname carve-out (P3 C7): Guard 2 used to define it, and a
# NameError in Guard 7 would be swallowed by its `except Exception: pass`, so nothing is renamed.
#   a1  the notice names deep_scan_cache_corrupt
#   a2  the corrupt file is gone from its path
#   a3  exactly one .corrupt-<filename-safe ts> sibling exists
#   a4  its content is intact (forensics kept)
#   b   a valid file: no notice, no rename
# Run: bash tests/state/test-ground-guard7-corrupt-rename.sh </dev/null
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="$ROOT/plugins/mega-sdd/scripts/ground.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

C="$WORK/a/.mega-sdd/codebase"; mkdir -p "$C"
printf '{"decision":"na"}' > "$WORK/a/.mega-sdd/l0-toolchain-decision.json"
printf '   \n- not a mapping\n' > "$C/starterkit-context.yaml"
OUT=$(bash "$G" --cwd="$WORK/a" 2>/dev/null)
echo "$OUT" | grep -q "deep_scan_cache_corrupt" && ok "a1 notice names deep_scan_cache_corrupt" || bad "a1 no notice: $(echo "$OUT" | head -2)"
[ ! -e "$C/starterkit-context.yaml" ] && ok "a2 corrupt file moved aside" || bad "a2 corrupt file still in place"
N=$(ls "$C" | grep -cE '^starterkit-context\.yaml\.corrupt-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9-]+Z$')
[ "$N" = 1 ] && ok "a3 renamed to .corrupt-<filename-safe ts>" || bad "a3 rename target wrong: $(ls "$C" | tr '\n' ' ')"
cat "$C"/starterkit-context.yaml.corrupt-* 2>/dev/null | grep -q 'not a mapping' \
  && ok "a4 forensics kept (content intact)" || bad "a4 renamed content lost"

V="$WORK/b/.mega-sdd/codebase"; mkdir -p "$V"
printf '{"decision":"na"}' > "$WORK/b/.mega-sdd/l0-toolchain-decision.json"
printf 'framework: laravel\n' > "$V/starterkit-context.yaml"
OUT=$(bash "$G" --cwd="$WORK/b" 2>/dev/null)
{ ! echo "$OUT" | grep -q "deep_scan_cache_corrupt"; } && [ -f "$V/starterkit-context.yaml" ] \
  && [ "$(ls "$V" | wc -l | tr -d ' ')" = 1 ] && ok "b a valid file: no notice, no rename" || bad "b valid file touched: $(ls "$V" | tr '\n' ' ')"

echo; [ $err -eq 0 ] && { echo "test-ground-guard7-corrupt-rename: ALL PASS"; exit 0; } || { echo "test-ground-guard7-corrupt-rename: FAILED"; exit 1; }
