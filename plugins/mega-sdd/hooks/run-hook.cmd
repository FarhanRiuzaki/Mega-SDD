#!/usr/bin/env bash
# Cross-platform hook dispatcher for mega-sdd.
# Usage: run-hook.cmd <hook-name>
# Executes hooks/<hook-name> with appropriate interpreter.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

# Platform detection: Windows uses .ps1, otherwise bash
case "$(uname -s 2>/dev/null || echo "")" in
  MINGW*|MSYS*|CYGWIN*)
    if [ -f "${HOOK_PATH}.ps1" ]; then
      powershell -ExecutionPolicy Bypass -File "${HOOK_PATH}.ps1"
      exit $?
    fi
    ;;
esac

bash "$HOOK_PATH"
