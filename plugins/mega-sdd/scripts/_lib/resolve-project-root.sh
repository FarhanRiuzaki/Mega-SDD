#!/usr/bin/env bash
# resolve-project-root.sh — shared helper for hooks + scripts (Iter 71).
#
# Walks UP from a given path to find the project root containing .mega-sdd/.
# Required because: the model can change CWD (e.g., cd into .mega-sdd/knowledge-base/
# during extract-intelligence), and harness-provided CWD then points to a SUBFOLDER
# of the project — naively writing to ${CWD}/.mega-sdd/... creates nested
# .mega-sdd/knowledge-base/.mega-sdd/ paths. Walking up corrects this.
#
# Source this file then call resolve_project_root "$CWD".
#
# Resolution rule:
#   1. If passed-in path itself is a project root (has child .mega-sdd/ AND is NOT
#      named .mega-sdd) → return it.
#   2. Else walk up to parent; repeat.
#   3. If reach / without finding a project root → return original input (greenfield
#      / init scenario where .mega-sdd/ doesn't yet exist; caller's existence
#      checks will still no-op correctly).
#
# Note the basename != ".mega-sdd" guard: prevents matching a hypothetical
# .mega-sdd/.mega-sdd/ nested layout (defensive — Iter 71 bug showed this CAN
# happen when prior runs created the nested dir).

resolve_project_root() {
  local d="${1:-$PWD}"
  local orig="$d"
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    if [ -d "$d/.mega-sdd" ] && [ "$(basename "$d")" != ".mega-sdd" ]; then
      echo "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  # Fallback: greenfield / no .mega-sdd ancestor — use original input.
  echo "$orig"
}
