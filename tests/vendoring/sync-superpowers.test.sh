#!/usr/bin/env bash
# Verifies vendored superpowers skills exist and are well-formed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VENDORED="${REPO_ROOT}/plugins/mega-sdd/skills/_vendored"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -d "$VENDORED" ] || fail "vendored dir missing: $VENDORED"
[ -f "${VENDORED}/ATTRIBUTION.md" ] || fail "ATTRIBUTION.md missing"

for skill in executing-plans subagent-driven-development test-driven-development using-git-worktrees; do
  [ -d "${VENDORED}/${skill}" ] || fail "skill missing: ${skill}"
  [ -f "${VENDORED}/${skill}/SKILL.md" ] || fail "${skill}/SKILL.md missing"
  grep -q "^name: " "${VENDORED}/${skill}/SKILL.md" || fail "${skill}/SKILL.md frontmatter missing"
done

# ATTRIBUTION should not have TBD after sync
if grep -q "Vendored from version:\*\* TBD" "${VENDORED}/ATTRIBUTION.md"; then
  fail "ATTRIBUTION.md still has TBD — sync script did not run"
fi

echo "OK: all 4 vendored skills present with frontmatter, attribution complete"
