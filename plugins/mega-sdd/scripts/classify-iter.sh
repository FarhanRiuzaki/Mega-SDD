#!/usr/bin/env bash
# classify-iter.sh — Iter 65 deterministic iter classifier (EP1 pre-work / EP2 post-work)
#
# Per plugins/mega-sdd/CLAUDE.md §Iter Ceremony Classifier + spec §3.4.
# Inputs: git/filesystem state only. Output: JSON enum PATCH | MINOR | MAJOR.
# NO LLM judgment. No heuristics beyond declared criteria.
#
# Usage:
#   classify-iter.sh --ep=EP1 [--explicit-flag=<patch|minor|major>] [--emit-telemetry=<path>]
#   classify-iter.sh --ep=EP2 [--explicit-flag=<patch|minor|major>] [--emit-telemetry=<path>]
#
# Exit codes:
#   0 = classifier ran cleanly (output JSON on stdout)
#   1 = invalid arguments
#   2 = git command failed (not in repo, etc.)

set -euo pipefail

# --- Arg parsing ---
EP=""
EXPLICIT_FLAG=""
EMIT_TELEMETRY=""

for arg in "$@"; do
  case "$arg" in
    --ep=EP1) EP="EP1" ;;
    --ep=EP2) EP="EP2" ;;
    --explicit-flag=*) EXPLICIT_FLAG="${arg#*=}" ;;
    --emit-telemetry=*) EMIT_TELEMETRY="${arg#*=}" ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$EP" ]]; then
  echo "ERROR: --ep=EP1 OR --ep=EP2 required" >&2
  exit 1
fi

# --- Validate git context ---
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not in a git repository" >&2
  exit 2
fi

# --- Classifier criteria (per CLAUDE.md §Classifier criteria) ---

VAULT_CONTRACT_PATH="plugins/mega-sdd/skills/generate-intent/references/vault-contract.md"
HANDOFF_CONTRACT_PATH="plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"

if [[ "$EP" == "EP1" ]]; then
  # Pre-work: working-tree diff vs HEAD
  EST_FILES_CHANGED=$(git diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ')
  EST_HALT_ENUM_DIFF=$(git diff HEAD -- "$VAULT_CONTRACT_PATH" 2>/dev/null | grep -cE "^[+-].*type:.*\|" || true)
  EST_NEW_SKILL_DIR=$(git diff --name-status HEAD 2>/dev/null | grep -cE "^A.*plugins/mega-sdd/skills/.*/SKILL\.md$" || true)
  EST_HANDOFF_DIFF=$(git diff HEAD -- "$HANDOFF_CONTRACT_PATH" 2>/dev/null | grep -cE "^[+-].*TYPE:" || true)
  EST_SKILL_BODY_MODIFIED=$(git diff --name-only HEAD 2>/dev/null | grep -cE "plugins/mega-sdd/skills/.*/SKILL\.md$" || true)
  BREAKING_MARKER=0  # EP1 has no commit message yet; relies on --explicit-flag
else
  # Post-work: last commit diff
  FILES_CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l | tr -d ' ')
  HALT_ENUM_DIFF=$(git diff HEAD~1 HEAD -- "$VAULT_CONTRACT_PATH" 2>/dev/null | grep -cE "^[+-].*type:.*\|" || true)
  NEW_SKILL_DIR=$(git diff --name-status HEAD~1 HEAD 2>/dev/null | grep -cE "^A.*plugins/mega-sdd/skills/.*/SKILL\.md$" || true)
  HANDOFF_DIFF=$(git diff HEAD~1 HEAD -- "$HANDOFF_CONTRACT_PATH" 2>/dev/null | grep -cE "^[+-].*TYPE:" || true)
  SKILL_BODY_MODIFIED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -cE "plugins/mega-sdd/skills/.*/SKILL\.md$" || true)
  BREAKING_MARKER=$(git log -1 --pretty=%B 2>/dev/null | grep -c "BREAKING CHANGE:" || true)
  # Map EP2 vars into EST_ prefix for unified logic below
  EST_FILES_CHANGED=$FILES_CHANGED
  EST_HALT_ENUM_DIFF=$HALT_ENUM_DIFF
  EST_NEW_SKILL_DIR=$NEW_SKILL_DIR
  EST_HANDOFF_DIFF=$HANDOFF_DIFF
  EST_SKILL_BODY_MODIFIED=$SKILL_BODY_MODIFIED
fi

# --- Apply classifier criteria ---
CRITERIA_MATCHED=()
ITER_TYPE="PATCH"  # default; promoted by triggers below

# MAJOR triggers (highest precedence)
if [[ "$EST_NEW_SKILL_DIR" -gt 0 ]]; then
  CRITERIA_MATCHED+=("new_skill_dir")
  ITER_TYPE="MAJOR"
fi
if [[ "$BREAKING_MARKER" -gt 0 ]]; then
  CRITERIA_MATCHED+=("breaking_change_marker")
  ITER_TYPE="MAJOR"
fi
if [[ "$EST_FILES_CHANGED" -gt 15 ]]; then
  CRITERIA_MATCHED+=("files_changed_gt_15")
  ITER_TYPE="MAJOR"
fi

# MINOR triggers (only if not MAJOR)
if [[ "$ITER_TYPE" != "MAJOR" ]]; then
  if [[ "$EST_FILES_CHANGED" -ge 5 && "$EST_FILES_CHANGED" -le 15 ]]; then
    CRITERIA_MATCHED+=("files_changed_5_15")
    ITER_TYPE="MINOR"
  fi
  if [[ "$EST_HALT_ENUM_DIFF" -gt 0 ]]; then
    CRITERIA_MATCHED+=("halt_enum_modified")
    ITER_TYPE="MINOR"
  fi
  if [[ "$EST_HANDOFF_DIFF" -gt 0 ]]; then
    CRITERIA_MATCHED+=("handoff_contract_field_added")
    ITER_TYPE="MINOR"
  fi
  if [[ "$EST_SKILL_BODY_MODIFIED" -gt 0 ]]; then
    CRITERIA_MATCHED+=("existing_skill_body_modified")
    ITER_TYPE="MINOR"
  fi
fi

# --- Precedence: explicit flag > classifier output > default ---
if [[ -n "$EXPLICIT_FLAG" ]]; then
  case "$EXPLICIT_FLAG" in
    patch|minor|major)
      OVERRIDE_FLAG="$EXPLICIT_FLAG"
      ITER_TYPE=$(echo "$EXPLICIT_FLAG" | tr '[:lower:]' '[:upper:]')
      CRITERIA_MATCHED+=("explicit_flag_override")
      ;;
    *)
      echo "ERROR: --explicit-flag must be patch|minor|major (got: $EXPLICIT_FLAG)" >&2
      exit 1
      ;;
  esac
else
  OVERRIDE_FLAG="null"
fi

# Default-PATCH if no triggers fired AND no explicit flag (CRITERIA_MATCHED empty)
if [[ "${#CRITERIA_MATCHED[@]}" -eq 0 ]]; then
  CRITERIA_MATCHED+=("default_patch")
fi

# --- Emit JSON to stdout ---
CRITERIA_JSON=$(printf '"%s",' "${CRITERIA_MATCHED[@]}" | sed 's/,$//')
EXPLICIT_FLAG_JSON=$(if [[ "$OVERRIDE_FLAG" == "null" ]]; then echo "null"; else echo "\"$OVERRIDE_FLAG\""; fi)

cat <<EOF
{
  "iter_type": "$ITER_TYPE",
  "evaluation_point": "$EP",
  "criteria_matched": [$CRITERIA_JSON],
  "explicit_flag": $EXPLICIT_FLAG_JSON,
  "inputs": {
    "files_changed": $EST_FILES_CHANGED,
    "halt_enum_diff": $EST_HALT_ENUM_DIFF,
    "new_skill_dir": $EST_NEW_SKILL_DIR,
    "handoff_contract_field_diff": $EST_HANDOFF_DIFF,
    "skill_body_modified": $EST_SKILL_BODY_MODIFIED,
    "breaking_change_marker": $BREAKING_MARKER
  }
}
EOF

# --- Emit telemetry event (if --emit-telemetry path provided) ---
if [[ -n "$EMIT_TELEMETRY" ]]; then
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  TURN_ID="${TURN_ID:-unknown-turn}"
  SESSION_ID="${SESSION_ID:-unknown-session}"
  TELEMETRY_EVENT=$(cat <<EOF
{"ts":"$TS","skill":"orchestrate-flow","event_type":"iter_classifier_output","turn_id":"$TURN_ID","session_id":"$SESSION_ID","iter_classifier":{"ep":"$EP","output":"$ITER_TYPE","criteria_matched":[$CRITERIA_JSON],"explicit_flag":$EXPLICIT_FLAG_JSON},"payload":{"inputs":{"files_changed":$EST_FILES_CHANGED,"halt_enum_diff":$EST_HALT_ENUM_DIFF,"new_skill_dir":$EST_NEW_SKILL_DIR}}}
EOF
)
  # Append to telemetry file (mkdir -p parent if needed)
  mkdir -p "$(dirname "$EMIT_TELEMETRY")"
  echo "$TELEMETRY_EVENT" >> "$EMIT_TELEMETRY"
fi
