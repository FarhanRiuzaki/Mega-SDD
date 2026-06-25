#!/usr/bin/env bash
# Cross-platform hook dispatcher for mega-sdd.
# Usage: bash run-hook.sh <hook-name>
#
# hooks.json invokes this as `bash run-hook.sh <name>` so that on Windows
# cmd.exe launches bash.exe with this file as a PATH ARGUMENT — it never
# tries to interpret the file itself. (When the file carried a .cmd
# extension, cmd ran it as a batch file and choked on the `#!` shebang:
# `'#!' is not recognized as an internal or external command`.)
#
# Executes hooks/<hook-name> with the appropriate interpreter.

set -euo pipefail

# Normalize backslashes: on Windows ${CLAUDE_PLUGIN_ROOT} can arrive with
# backslash separators (C:\Users\...\run-hook.sh). Git Bash's `dirname` only
# splits on '/', so without this SCRIPT_DIR would collapse to the CWD and
# every hook would resolve as "not found".
self="${0//\\//}"
SCRIPT_DIR="$(cd "$(dirname "$self")" && pwd)"
HOOK_NAME="${1:-}"

if [ -z "$HOOK_NAME" ]; then
  echo "ERROR: hook name required" >&2
  exit 1
fi

HOOK_PATH="${SCRIPT_DIR}/${HOOK_NAME}"
if [ ! -f "$HOOK_PATH" ]; then
  echo "ERROR: hook not found: $HOOK_PATH" >&2
  exit 1
fi

# Platform detection: Windows uses .ps1 if a port exists, otherwise bash.
case "$(uname -s 2>/dev/null || echo "")" in
  MINGW*|MSYS*|CYGWIN*)
    if [ -f "${HOOK_PATH}.ps1" ]; then
      powershell -ExecutionPolicy Bypass -File "${HOOK_PATH}.ps1"
      exit $?
    fi
    ;;
esac

bash "$HOOK_PATH"
