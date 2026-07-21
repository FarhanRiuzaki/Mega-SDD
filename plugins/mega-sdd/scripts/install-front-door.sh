#!/usr/bin/env bash
# install-front-door.sh — install/refresh the bare `/mega-sdd` user-level wrapper.
#
# WHY THIS EXISTS: Claude Code registers plugin commands ONLY under the plugin
# namespace (`/mega-sdd:<command>`) — there is no in-plugin way to claim the bare
# `/mega-sdd` verb (frontmatter `name:` only changes the display label). Standalone
# user-level commands (`~/.claude/commands/*.md`) DO get bare names, so the plugin
# ships this tiny wrapper there. The wrapper contains no chain logic: it resolves
# the active install path from installed_plugins.json and forwards verbatim to the
# plugin's front-door command, so it never goes stale across plugin updates.
#
# Called by hooks/session-start on every session (idempotent: version-marker
# check, writes only when absent or outdated). Manual: bash install-front-door.sh [--force]
#
# Ownership rail: a pre-existing ~/.claude/commands/mega-sdd.md WITHOUT our
# marker is treated as user-authored and NEVER overwritten (unless --force).

set -u

WRAPPER_VERSION="1"
MARKER="mega-sdd-front-door-wrapper v${WRAPPER_VERSION}"
TARGET_DIR="${HOME}/.claude/commands"
TARGET="${TARGET_DIR}/mega-sdd.md"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# Already current?
if [ -f "$TARGET" ] && [ "$FORCE" -eq 0 ]; then
  if grep -q "$MARKER" "$TARGET" 2>/dev/null; then
    exit 0  # up to date
  fi
  if ! grep -q "mega-sdd-front-door-wrapper" "$TARGET" 2>/dev/null; then
    # User-authored file (no marker of any version): respect it.
    exit 0
  fi
  # Older marker version → fall through and refresh.
fi

mkdir -p "$TARGET_DIR" 2>/dev/null || exit 0

TMP="${TARGET}.tmp.$$"
cat > "$TMP" <<'WRAPPER_EOF'
---
description: "Bare /mega-sdd front door (auto-installed user-level wrapper). Claude Code registers plugin commands only as /mega-sdd:<command>, so the plugin cannot claim the bare verb itself — this standalone wrapper provides it and forwards verbatim to the plugin's front-door command."
argument-hint: "[input] [--deep|--shallow] [--greenfield] [--scope=<id>] [--resume] [--manual] [flags…]"
---

Thin user-level wrapper for the mega-sdd front door. Plugin commands are always namespaced (`/mega-sdd:<command>`) in Claude Code, so this file supplies the bare `/mega-sdd` verb. It contains NO chain logic of its own.

Do exactly this:

1. Resolve the ACTIVE plugin install path (never hardcode a version):
   read `~/.claude/plugins/installed_plugins.json` → `plugins["mega-sdd@mega-sdd"][0].installPath`.
   If that key is absent, use the first plugins key matching `mega-sdd@*`.
2. Read `<installPath>/commands/mega-sdd.md` and follow it EXACTLY as if the user had invoked that command directly, passing through these user arguments verbatim: $ARGUMENTS
3. Do NOT print any deprecation notice for this wrapper — it is the canonical bare front door, not a deprecated alias.
4. If the install path cannot be resolved (plugin uninstalled), say so and suggest `/plugin install mega-sdd` — do not guess a path.

<!-- mega-sdd-front-door-wrapper v1 — managed by the mega-sdd plugin (hooks/session-start → scripts/install-front-door.sh). Edits here are preserved only if you remove this marker line. -->
WRAPPER_EOF

mv -f "$TMP" "$TARGET" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
exit 0
