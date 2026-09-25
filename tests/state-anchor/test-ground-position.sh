#!/usr/bin/env bash
# State anchor — GROUND keeps POSITION when the engine fails (spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §5 entry 1). The engine
# rides the ONE python exec that reads POSITION; POSITION is printed first inside
# try/finally, so an engine exception can never change it — and the round-F1
# sync-pending guard (maintenance_sync → index rebuild DEFERRED) depends on it.
# Also: GROUND run from a team subdir resolves the project root for the engine.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_NOSYSTEM=1 HOME="$WORK/home"
mkdir -p "$HOME"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# a private plugin copy: derive-state is a no-op (the fixture's state.json is the
# truth under test) and freshness.py raises on import
PL="$WORK/plugin"; mkdir -p "$PL"; cp -a "$REPO/plugins/mega-sdd/." "$PL/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$PL/scripts/derive-state.sh"
F="$WORK/p"; mkdir -p "$F/.mega-sdd/vaults/v/units" "$F/src"
echo x > "$F/src/a.ts"
printf '{"derived":{"position":"maintenance_sync"}}\n' > "$F/.mega-sdd/state.json"
( cd "$F" && git init -q . && git -c user.name=t -c user.email=t@t add -A && git -c user.name=t -c user.email=t@t commit -qm x )

cp "$PL/scripts/_lib/freshness.py" "$WORK/freshness.ok.py"
printf 'raise RuntimeError("engine exploded")\n' > "$PL/scripts/_lib/freshness.py"
O=$(bash "$PL/scripts/ground.sh" --cwd="$F" 2>&1)
case "$O" in *"freshness check failed (RuntimeError)"*"index: rebuild DEFERRED"*) ok "engine raises → POSITION kept, index rebuild still DEFERRED" ;;
  *) bad "engine failure changed GROUND: [$O]" ;; esac

cp "$WORK/freshness.ok.py" "$PL/scripts/_lib/freshness.py"
O=$(bash "$PL/scripts/ground.sh" --cwd="$F" 2>&1)
case "$O" in *"mega-sdd state @"*"Rule: code at HEAD"*"index: rebuild DEFERRED"*) ok "healthy engine: state block printed, then the same DEFERRED guard" ;;
  *) bad "healthy GROUND: [$O]" ;; esac

# GROUND from a team subdir (relative and absolute --cwd): the engine resolves the root
mkdir -p "$F/apps/web"
O=$( cd "$F" && bash "$PL/scripts/ground.sh" --cwd=apps/web 2>&1 )
case "$O" in *"mega-sdd state @"*"GROUND: pre-init"*) ok "relative subdir --cwd: engine ran on the resolved root, rest unchanged (pre-init)" ;;
  *) bad "relative subdir: [$O]" ;; esac
[ ! -d "$F/apps/web/.mega-sdd" ] && ok "subdir: nothing minted under the subdir" || bad "phantom .mega-sdd minted in the subdir"

[ "$fail" -eq 0 ] && { echo "PASS state-anchor ground position"; exit 0; }
echo "state-anchor ground position FAILED"; exit 1
