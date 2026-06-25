#!/usr/bin/env bash
# resolve-plugin-root.sh — print the canonical mega-sdd plugin root, preferring
# the LATEST cached version.
#
# WHY: Claude Code keeps every downloaded plugin version side-by-side under
#   ~/.claude/plugins/cache/mega-sdd/mega-sdd/<version>/
# and never garbage-collects old ones. `${CLAUDE_PLUGIN_ROOT}` is NOT
# substituted inside reference files and NOT exported to the Bash tool, so
# skills derive a root from the path of a reference file they just Read. When a
# stale-version path leaks into a long session (or a dispatched subagent), that
# derived root can point at an OLD cache dir whose files still physically exist
# — a silent stale read of templates/scripts. This resolver re-anchors to the
# newest cached version so every pipeline skill reads current files.
#
# ASSUMPTION (deliberate): "latest" == highest SemVer directory present in the
# cache. On a downgrade/rollback that leaves a newer dir behind, this returns
# the newer dir. That is the defensible reading of "use the latest version";
# prune the cache if you intend to pin an older one.
#
# PORTABILITY: numeric field sort (`sort -t. -k1,1n -k2,2n -k3,3n`) on the
# version BASENAMES — NOT `sort -V`, which macOS/BSD `sort` lacks. Works on
# macOS, Linux, and Git Bash (Windows).
#
# Usage:
#   resolve-plugin-root.sh [FALLBACK_ROOT]
#     FALLBACK_ROOT  optional — printed when no versioned cache exists
#                    (manual / project-scoped / claude.ai / repo-dev installs).
#
# Exit: 0 + root on stdout when resolved; 1 when neither a cache version nor a
# usable fallback is available.

set -euo pipefail

CACHE_DIR="${HOME}/.claude/plugins/cache/mega-sdd/mega-sdd"
FALLBACK_ROOT="${1:-}"

if [ -d "$CACHE_DIR" ]; then
  # `|| true` neutralizes `set -o pipefail`: when no entry matches the version
  # regex, grep exits 1 and the assignment would otherwise abort the script
  # (under `set -e`) BEFORE reaching the fallback. Empty `latest` must fall
  # through to FALLBACK_ROOT, not crash.
  latest="$(
    ls -1 "$CACHE_DIR" 2>/dev/null \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
      | sort -t. -k1,1n -k2,2n -k3,3n \
      | tail -1 \
      || true
  )"
  if [ -n "$latest" ] && [ -d "${CACHE_DIR}/${latest}" ]; then
    printf '%s\n' "${CACHE_DIR}/${latest}"
    exit 0
  fi
fi

# No versioned cache (non-plugin-install) — fall back to the caller's root.
if [ -n "$FALLBACK_ROOT" ]; then
  printf '%s\n' "$FALLBACK_ROOT"
  exit 0
fi

echo "resolve-plugin-root: no cached version and no fallback root given" >&2
exit 1
