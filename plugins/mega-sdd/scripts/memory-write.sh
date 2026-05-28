#!/usr/bin/env bash
# memory-write.sh — Deterministic memory file writer with lock acquisition.
#
# Extracts the lock → write → release pattern from skill-body prose into a
# deterministic script. Skills invoke via Bash instead of relying on the
# model to follow lock-acquisition prose instructions.
#
# Per vault-contract.md §Concurrency contract: advisory file lock, 3 retries
# with backoff (100ms / 500ms / 1500ms), atomic write (temp + rename).
#
# Usage:
#   memory-write.sh --file=<target> --content=<content-or-stdin> --scope=<user|project|vault>
#   echo "content" | memory-write.sh --file=<target> --scope=project
#
# Inputs:
#   --file=<path>     Target memory file (absolute or relative to CWD)
#   --content=<text>  Content to write (if absent, reads from stdin)
#   --scope=<scope>   user | project | vault (informational; for telemetry)
#   --mode=<mode>     append | overwrite (default: append)
#   --cwd=<path>      Project root (for telemetry; default: pwd)
#
# Output:
#   exit 0 = write succeeded
#   exit 1 = lock acquisition failed after retries (memory_in_use halt)
#   exit 2 = error (bad args, target not writable)
#
# Side-effect: emits telemetry if telemetry.jsonl exists + lock retry happened.

set -uo pipefail

FILE=""
CONTENT=""
SCOPE="project"
MODE="append"
CWD=""

for arg in "$@"; do
  case "$arg" in
    --file=*) FILE="${arg#--file=}" ;;
    --content=*) CONTENT="${arg#--content=}" ;;
    --scope=*) SCOPE="${arg#--scope=}" ;;
    --mode=*) MODE="${arg#--mode=}" ;;
    --cwd=*) CWD="${arg#--cwd=}" ;;
  esac
done
# Resolve project root (Iter 71 — class-bug fix: if invoked from a sub-folder
# like .mega-sdd/knowledge-base/, walk UP to the outermost .mega-sdd/ parent
# so state files land in the canonical location, not nested .mega-sdd/.mega-sdd/).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi


if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ -z "$FILE" ]; then
  echo "ERROR: --file=<path> required" >&2
  exit 2
fi

# Read content from stdin if not provided via --content
if [ -z "$CONTENT" ]; then
  CONTENT=$(cat 2>/dev/null)
fi

if [ -z "$CONTENT" ]; then
  echo "ERROR: no content provided (--content or stdin)" >&2
  exit 2
fi

# Ensure target directory exists
TARGET_DIR=$(dirname "$FILE")
mkdir -p "$TARGET_DIR" 2>/dev/null || { echo "ERROR: cannot create $TARGET_DIR" >&2; exit 2; }

# Lock acquisition with retry
LOCK_FILE="${FILE}.lock"
MAX_RETRIES=3
RETRY_DELAYS=(0.1 0.5 1.5)
ACQUIRED=0

for i in $(seq 0 $((MAX_RETRIES - 1))); do
  # Try exclusive create (O_EXCL equivalent via mkdir — atomic on all filesystems)
  if mkdir "$LOCK_FILE" 2>/dev/null; then
    ACQUIRED=1
    break
  fi

  # Check if lock is stale (>30s old)
  if [ -d "$LOCK_FILE" ]; then
    LOCK_AGE=$(python3 -c "import os,time; print(int(time.time() - os.path.getmtime('$LOCK_FILE')))" 2>/dev/null || echo 0)
    if [ "$LOCK_AGE" -gt 30 ]; then
      rmdir "$LOCK_FILE" 2>/dev/null || true
      if mkdir "$LOCK_FILE" 2>/dev/null; then
        ACQUIRED=1
        break
      fi
    fi
  fi

  # Backoff
  sleep "${RETRY_DELAYS[$i]}" 2>/dev/null || sleep 1
done

if [ "$ACQUIRED" -eq 0 ]; then
  # Emit memory_in_use telemetry if possible
  TELEMETRY_FILE="${CWD}/.mega-sdd/memory/telemetry.jsonl"
  if [ -f "$TELEMETRY_FILE" ]; then
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    echo "{\"ts\":\"$TS\",\"skill\":\"memory-write\",\"event_type\":\"halt_fired\",\"session_id\":\"script\",\"hook_source\":null,\"payload\":{\"halt_type\":\"memory_in_use\",\"file\":\"$FILE\",\"lock_path\":\"$LOCK_FILE\",\"attempts\":$MAX_RETRIES}}" >> "$TELEMETRY_FILE" 2>/dev/null || true
  fi
  echo "ERROR: lock acquisition failed after $MAX_RETRIES retries on $LOCK_FILE" >&2
  exit 1
fi

# Atomic write: temp file → rename
TEMP_FILE="${FILE}.tmp.$$"

cleanup() {
  rm -f "$TEMP_FILE" 2>/dev/null
  rmdir "$LOCK_FILE" 2>/dev/null || true
}
trap cleanup EXIT

if [ "$MODE" = "append" ] && [ -f "$FILE" ]; then
  cp "$FILE" "$TEMP_FILE" 2>/dev/null || true
  printf '%s\n' "$CONTENT" >> "$TEMP_FILE"
else
  printf '%s\n' "$CONTENT" > "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$FILE"
# Lock released by trap (rmdir on EXIT)

exit 0
