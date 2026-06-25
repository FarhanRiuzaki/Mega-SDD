#!/usr/bin/env bash
# Test the latest-version resolver (scripts/resolve-plugin-root.sh) and the
# glob-anchored invocation snippet the pipeline reference blocks embed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESOLVER="${PLUGIN_DIR}/scripts/resolve-plugin-root.sh"

pass=0; fail=0
ok()   { printf 'PASS  %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf 'FAIL  %s\n   expected: %s\n   got     : %s\n' "$1" "$2" "$3"; fail=$((fail+1)); }

mkcache() { # $1=HOME root, rest=versions; creates cache dirs
  local home="$1"; shift
  local base="$home/.claude/plugins/cache/mega-sdd/mega-sdd"
  local v; for v in "$@"; do mkdir -p "$base/$v/scripts"; done
  printf '%s\n' "$base"
}

# 1. Latest-by-SemVer (NOT lexical: 4.100.0 > 4.36.0 > 4.9.0)
T1="$(mktemp -d)"; B1="$(mkcache "$T1" 4.9.0 4.36.0 4.100.0 4.31.0 notaversion)"
got="$(HOME="$T1" bash "$RESOLVER" "/stale/fallback")"
[ "$got" = "$B1/4.100.0" ] && ok "latest-by-semver" || bad "latest-by-semver" "$B1/4.100.0" "$got"

# 2. Cache present → a STALE fallback is ignored (the bug scenario)
[ "$got" = "$B1/4.100.0" ] && ok "stale-fallback-ignored-when-cache-present" \
  || bad "stale-fallback-ignored-when-cache-present" "$B1/4.100.0" "$got"

# 3. No cache → fallback root echoed
T3="$(mktemp -d)"
got="$(HOME="$T3" bash "$RESOLVER" "/derived/root")"
[ "$got" = "/derived/root" ] && ok "no-cache-falls-back" || bad "no-cache-falls-back" "/derived/root" "$got"

# 4. No cache + no fallback → exit 1
HOME="$T3" bash "$RESOLVER" >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "no-cache-no-fallback-exit-1" || bad "no-cache-no-fallback-exit-1" "exit 1" "exit $?"

# 4b. Cache dir EXISTS but only INVALID entries (grep matches nothing) → must
#     fall back, NOT abort under set -o pipefail (regression for the crash bug).
T4="$(mktemp -d)"; mkdir -p "$T4/.claude/plugins/cache/mega-sdd/mega-sdd/notaversion" "$T4/.claude/plugins/cache/mega-sdd/mega-sdd/README"
got="$(HOME="$T4" bash "$RESOLVER" "/fallback/root")"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$got" = "/fallback/root" ]; } \
  && ok "invalid-only-cache-falls-back" || bad "invalid-only-cache-falls-back" "rc0 /fallback/root" "rc$rc $got"

# 4c. Cache dir EXISTS but EMPTY → fall back, no abort.
T4b="$(mktemp -d)"; mkdir -p "$T4b/.claude/plugins/cache/mega-sdd/mega-sdd"
got="$(HOME="$T4b" bash "$RESOLVER" "/fallback/root")"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$got" = "/fallback/root" ]; } \
  && ok "empty-cache-falls-back" || bad "empty-cache-falls-back" "rc0 /fallback/root" "rc$rc $got"

# 5. Glob-anchored invocation defeats a stale anchor even when only NEWER
#    versions ship the resolver (old cached versions predate it).
T5="$(mktemp -d)"; B5="$(mkcache "$T5" 4.29.0 4.31.0 4.37.0 4.38.0)"
cp "$RESOLVER" "$B5/4.37.0/scripts/"; cp "$RESOLVER" "$B5/4.38.0/scripts/"
DERIVED="$B5/4.31.0"  # stale anchor in context
got="$(HOME="$T5" bash -c '
  DERIVED="'"$DERIVED"'"
  R="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
  PR="$([ -n "$R" ] && bash "$R" "$DERIVED" || echo "$DERIVED")"
  [ -n "$PR" ] || PR="$DERIVED"; printf "%s" "$PR"
')"
[ "$got" = "$B5/4.38.0" ] && ok "glob-anchored-defeats-stale-anchor" \
  || bad "glob-anchored-defeats-stale-anchor" "$B5/4.38.0" "$got"

# 6. All-old cache (no resolver anywhere) → degrade to DERIVED, never worse
T6="$(mktemp -d)"; B6="$(mkcache "$T6" 4.29.0 4.31.0)"; DERIVED="$B6/4.31.0"
got="$(HOME="$T6" bash -c '
  DERIVED="'"$DERIVED"'"
  R="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
  PR="$([ -n "$R" ] && bash "$R" "$DERIVED" || echo "$DERIVED")"
  [ -n "$PR" ] || PR="$DERIVED"; printf "%s" "$PR"
')"
[ "$got" = "$DERIVED" ] && ok "all-old-degrades-to-derived" || bad "all-old-degrades-to-derived" "$DERIVED" "$got"

rm -rf "$T1" "$T3" "$T4" "$T4b" "$T5" "$T6"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
