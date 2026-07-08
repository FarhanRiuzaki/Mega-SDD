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

# ─── Unified cleanup (registered BEFORE the scan scratch exists) ────────────
# An interrupt during the scan must not leave the PRE-redaction row in TMPDIR;
# the write temp is covered too; the lock is released ONLY if we acquired it
# (rmdir'ing a contender's fresh lock would double-release). NOTE: a later
# `trap ... EXIT` would REPLACE this one — keep the single cleanup().
_SCAN_TMP=""
TEMP_FILE=""
LOCK_FILE=""
ACQUIRED=0
cleanup() {
  [ -n "${_SCAN_TMP:-}" ] && rm -f "$_SCAN_TMP" 2>/dev/null
  [ -n "${TEMP_FILE:-}" ] && rm -f "$TEMP_FILE" 2>/dev/null
  if [ "${ACQUIRED:-0}" -eq 1 ] && [ -n "${LOCK_FILE:-}" ]; then
    rmdir "$LOCK_FILE" 2>/dev/null || true
  fi
  return 0
}
trap cleanup EXIT INT TERM

# Secret-scan the incoming content BEFORE it touches the memory file (M-16:
# appends moved from the orchestrator's single batch point to per-skill
# emission-time writes, so the redaction rail moves INTO the writer — one
# deterministic place instead of N prose sites; memory files can be
# git-tracked, a leaked credential here ships). Scans ONLY the new content,
# not the whole target file, and runs BEFORE the lock is held. Redaction
# keeps the row shape ([REDACTED-SECRET] replaces the value).
# Fail-open BUT NEVER SILENT: a missing scanner / unwritable scratch / failed
# scan keeps the ORIGINAL content and the write proceeds (memory is optional;
# graceful degradation), with one WARN on stderr so a disabled rail is
# observable in chain logs. The scratch write is GUARDED: a partial write
# (ENOSPC) must not replace CONTENT with a truncated prefix — on write
# failure we skip the scan and keep the original bytes.
# Content normalization: exactly ONE trailing newline is guaranteed on the
# appended block (extra trailing newlines are stripped by the scan
# round-trip — same normalization the stdin path always had).
_SCAN="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/secret-scan.sh"
if [ -f "$_SCAN" ]; then
  _SCAN_TMP=$(mktemp "${TMPDIR:-/tmp}/mw-scan.XXXXXX" 2>/dev/null || echo "")
  if [ -n "$_SCAN_TMP" ] && printf '%s\n' "$CONTENT" > "$_SCAN_TMP" 2>/dev/null; then
    if bash "$_SCAN" --redact "$_SCAN_TMP" >/dev/null 2>&1; then
      # Trust the scratch ONLY on scan success — a scanner dying mid-rewrite
      # could leave it truncated; on failure keep the original bytes.
      CONTENT=$(cat "$_SCAN_TMP" 2>/dev/null || printf '%s' "$CONTENT")
    else
      echo "WARN: secret-scan failed; content written unredacted" >&2
    fi
  else
    echo "WARN: secret-scan skipped (scratch file unavailable); content written unredacted" >&2
  fi
  rm -f "${_SCAN_TMP:-}" 2>/dev/null
  _SCAN_TMP=""
else
  echo "WARN: secret-scan.sh not found; content written unredacted" >&2
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
      # Atomic steal: mv succeeds for exactly ONE process (the old rmdir+mkdir
      # pair let a second process rmdir the winner's FRESH lock and both "hold" it)
      if mv "$LOCK_FILE" "${LOCK_FILE}.stale.$$" 2>/dev/null; then
        rmdir "${LOCK_FILE}.stale.$$" 2>/dev/null || true
      fi
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

# Atomic write: temp file → rename. Cleanup (temp removal + lock release) is
# owned by the single trap registered above — do NOT add a second `trap` here,
# it would REPLACE the first and orphan the scan scratch on interrupt.
TEMP_FILE="${FILE}.tmp.$$"

if [ "$MODE" = "append" ] && [ -f "$FILE" ]; then
  cp "$FILE" "$TEMP_FILE" 2>/dev/null || true
  printf '%s\n' "$CONTENT" >> "$TEMP_FILE"
else
  printf '%s\n' "$CONTENT" > "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$FILE"
# Lock released by trap (rmdir on EXIT)

exit 0
