#!/usr/bin/env bash
# check-recursion-budget.sh — Iter 65 anti-recursive guard runtime
#
# Per plugins/mega-sdd/CLAUDE.md §Anti-Recursive Guard + spec §7.
# Tracks per-task re-plan count + re-validate count via ephemeral state file.
# Emits telemetry events for guard activity (Iter 65 day-0 instrumentation
# per user mandate — required for tune #2 distribution analysis at Iter 68).
#
# Usage:
#   check-recursion-budget.sh --action=increment-replan --task-id=<id> --trigger=<execution_failed|ambiguity_increased|contract_mismatch> [--max-replan=<int>] [--emit-telemetry=<path>]
#   check-recursion-budget.sh --action=increment-revalidate --task-id=<id> [--max-revalidate=<int>] [--emit-telemetry=<path>]
#   check-recursion-budget.sh --action=status --task-id=<id>
#   check-recursion-budget.sh --action=reset --task-id=<id>
#
# State file: <project>/.mega-sdd/.replan-budget (JSON per task)
#
# Exit codes:
#   0 = within budget; action succeeded
#   1 = invalid arguments
#   2 = state file I/O error
#   3 = REPLAN_BUDGET_EXCEEDED (halt should fire)
#   4 = REVALIDATE_BUDGET_EXCEEDED (halt should fire)

set -euo pipefail

# --- Arg parsing ---
ACTION=""
TASK_ID=""
TRIGGER=""
MAX_REPLAN=2  # default per RULE 2
MAX_REVALIDATE=3
EMIT_TELEMETRY=""

for arg in "$@"; do
  case "$arg" in
    --action=*) ACTION="${arg#*=}" ;;
    --task-id=*) TASK_ID="${arg#*=}" ;;
    --trigger=*) TRIGGER="${arg#*=}" ;;
    --max-replan=*) MAX_REPLAN="${arg#*=}" ;;
    --max-revalidate=*) MAX_REVALIDATE="${arg#*=}" ;;
    --emit-telemetry=*) EMIT_TELEMETRY="${arg#*=}" ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$ACTION" || -z "$TASK_ID" ]]; then
  echo "ERROR: --action and --task-id required" >&2
  exit 1
fi

# --- Validate trigger for increment-replan (RULE 1 closed enum) ---
if [[ "$ACTION" == "increment-replan" ]]; then
  case "$TRIGGER" in
    execution_failed|ambiguity_increased|contract_mismatch)
      # Valid trigger
      ;;
    "")
      echo "ERROR: --trigger required for increment-replan (RULE 1 closed enum: execution_failed | ambiguity_increased | contract_mismatch)" >&2
      exit 1
      ;;
    *)
      echo "ERROR: invalid trigger '$TRIGGER' (RULE 1 closed enum: execution_failed | ambiguity_increased | contract_mismatch). Note: bind-codebase CONFLICT is NOT a re-plan trigger per RULE 1.5." >&2
      exit 1
      ;;
  esac
fi

# --- State file location ---
# Try to find project root (where .mega-sdd/ lives) by walking up from PWD
find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.mega-sdd" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  echo "$PWD"  # fallback
}

PROJECT_ROOT=$(find_project_root)
STATE_FILE="$PROJECT_ROOT/.mega-sdd/.replan-budget"

mkdir -p "$(dirname "$STATE_FILE")"

# --- Helper: read task state (lightweight JSON parse via grep/sed; no jq dep) ---
read_task_state() {
  local task_id="$1"
  local field="$2"  # replan_count | revalidate_count | trigger_history
  if [[ ! -f "$STATE_FILE" ]]; then
    case "$field" in
      replan_count|revalidate_count) echo "0" ;;
      trigger_history) echo "" ;;
    esac
    return 0
  fi
  # Match task block by ID; extract field value
  local block
  block=$(awk -v id="\"$task_id\"" '
    BEGIN { in_block = 0; depth = 0; buf = "" }
    {
      if ($0 ~ id) { in_block = 1 }
      if (in_block) {
        buf = buf $0 "\n"
        for (i=1; i<=length($0); i++) {
          c = substr($0, i, 1)
          if (c == "{") depth++
          if (c == "}") { depth--; if (depth == 0 && in_block) { print buf; in_block = 0; depth = 0; buf = "" } }
        }
      }
    }
  ' "$STATE_FILE" 2>/dev/null || true)

  case "$field" in
    replan_count)
      echo "$block" | grep -oE '"replan_count":[ ]*[0-9]+' | head -1 | grep -oE '[0-9]+' || echo "0"
      ;;
    revalidate_count)
      echo "$block" | grep -oE '"revalidate_count":[ ]*[0-9]+' | head -1 | grep -oE '[0-9]+' || echo "0"
      ;;
    trigger_history)
      echo "$block" | grep -oE '"trigger_history":[ ]*\[[^]]*\]' | head -1 | sed 's/.*\[//; s/\]//' || echo ""
      ;;
  esac
}

write_task_state() {
  local task_id="$1"
  local replan="$2"
  local revalidate="$3"
  local trigger_hist="$4"

  # Simplest approach: rewrite whole file with this task's updated block.
  # For Iter 65 conservative scope: one task per state file (no multi-task).
  # Future iters can add multi-task indexing if needed.
  cat > "$STATE_FILE" <<EOF
{
  "schema_version": "1.0",
  "tasks": {
    "$task_id": {
      "replan_count": $replan,
      "revalidate_count": $revalidate,
      "trigger_history": [$trigger_hist],
      "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
  }
}
EOF
}

emit_telemetry_event() {
  local event_type="$1"
  local payload="$2"
  if [[ -z "$EMIT_TELEMETRY" ]]; then return 0; fi
  local ts turn_id session_id
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  turn_id="${TURN_ID:-unknown-turn}"
  session_id="${SESSION_ID:-unknown-session}"
  mkdir -p "$(dirname "$EMIT_TELEMETRY")"
  echo "{\"ts\":\"$ts\",\"skill\":\"orchestrate-flow\",\"event_type\":\"$event_type\",\"turn_id\":\"$turn_id\",\"session_id\":\"$session_id\",\"payload\":$payload}" >> "$EMIT_TELEMETRY"
}

# --- Actions ---
case "$ACTION" in
  increment-replan)
    CURRENT_REPLAN=$(read_task_state "$TASK_ID" "replan_count")
    CURRENT_REVALIDATE=$(read_task_state "$TASK_ID" "revalidate_count")
    CURRENT_HIST=$(read_task_state "$TASK_ID" "trigger_history")
    NEW_REPLAN=$((CURRENT_REPLAN + 1))
    NEW_HIST="$CURRENT_HIST"
    if [[ -n "$NEW_HIST" ]]; then NEW_HIST="$NEW_HIST,"; fi
    NEW_HIST="$NEW_HIST\"$TRIGGER\""

    # Always emit replan_triggered event first
    emit_telemetry_event "replan_triggered" "{\"task_id\":\"$TASK_ID\",\"trigger\":\"$TRIGGER\",\"replan_count_before\":$CURRENT_REPLAN,\"replan_count_after\":$NEW_REPLAN}"

    if [[ "$NEW_REPLAN" -gt "$MAX_REPLAN" ]]; then
      # Budget exceeded → halt
      emit_telemetry_event "replan_budget_exceeded" "{\"task_id\":\"$TASK_ID\",\"max_replan_count\":$MAX_REPLAN,\"actual_replan_count\":$NEW_REPLAN,\"trigger_history\":[$NEW_HIST],\"halt_emitted\":\"quality_gate_failed:replan_budget_exceeded\"}"
      write_task_state "$TASK_ID" "$NEW_REPLAN" "$CURRENT_REVALIDATE" "$NEW_HIST"
      cat <<EOF
{
  "status": "REPLAN_BUDGET_EXCEEDED",
  "task_id": "$TASK_ID",
  "max_replan_count": $MAX_REPLAN,
  "actual_replan_count": $NEW_REPLAN,
  "trigger_history": [$NEW_HIST],
  "halt_to_emit": "quality_gate_failed:replan_budget_exceeded"
}
EOF
      exit 3
    else
      write_task_state "$TASK_ID" "$NEW_REPLAN" "$CURRENT_REVALIDATE" "$NEW_HIST"
      cat <<EOF
{
  "status": "OK",
  "task_id": "$TASK_ID",
  "replan_count": $NEW_REPLAN,
  "max_replan_count": $MAX_REPLAN,
  "remaining_budget": $((MAX_REPLAN - NEW_REPLAN))
}
EOF
    fi
    ;;

  increment-revalidate)
    CURRENT_REPLAN=$(read_task_state "$TASK_ID" "replan_count")
    CURRENT_REVALIDATE=$(read_task_state "$TASK_ID" "revalidate_count")
    CURRENT_HIST=$(read_task_state "$TASK_ID" "trigger_history")
    NEW_REVALIDATE=$((CURRENT_REVALIDATE + 1))

    emit_telemetry_event "revalidate_triggered" "{\"task_id\":\"$TASK_ID\",\"revalidate_count_before\":$CURRENT_REVALIDATE,\"revalidate_count_after\":$NEW_REVALIDATE}"

    if [[ "$NEW_REVALIDATE" -gt "$MAX_REVALIDATE" ]]; then
      emit_telemetry_event "revalidate_budget_exceeded" "{\"task_id\":\"$TASK_ID\",\"max_revalidate_count\":$MAX_REVALIDATE,\"actual_revalidate_count\":$NEW_REVALIDATE,\"halt_emitted\":\"quality_gate_failed:revalidate_budget_exceeded\"}"
      write_task_state "$TASK_ID" "$CURRENT_REPLAN" "$NEW_REVALIDATE" "$CURRENT_HIST"
      cat <<EOF
{
  "status": "REVALIDATE_BUDGET_EXCEEDED",
  "task_id": "$TASK_ID",
  "max_revalidate_count": $MAX_REVALIDATE,
  "actual_revalidate_count": $NEW_REVALIDATE,
  "halt_to_emit": "quality_gate_failed:revalidate_budget_exceeded"
}
EOF
      exit 4
    else
      write_task_state "$TASK_ID" "$CURRENT_REPLAN" "$NEW_REVALIDATE" "$CURRENT_HIST"
      cat <<EOF
{
  "status": "OK",
  "task_id": "$TASK_ID",
  "revalidate_count": $NEW_REVALIDATE,
  "max_revalidate_count": $MAX_REVALIDATE,
  "remaining_budget": $((MAX_REVALIDATE - NEW_REVALIDATE))
}
EOF
    fi
    ;;

  status)
    REPLAN=$(read_task_state "$TASK_ID" "replan_count")
    REVALIDATE=$(read_task_state "$TASK_ID" "revalidate_count")
    HIST=$(read_task_state "$TASK_ID" "trigger_history")
    cat <<EOF
{
  "task_id": "$TASK_ID",
  "replan_count": $REPLAN,
  "max_replan_count": $MAX_REPLAN,
  "revalidate_count": $REVALIDATE,
  "max_revalidate_count": $MAX_REVALIDATE,
  "trigger_history": [$HIST]
}
EOF
    ;;

  reset)
    write_task_state "$TASK_ID" "0" "0" ""
    cat <<EOF
{
  "status": "RESET",
  "task_id": "$TASK_ID"
}
EOF
    ;;

  *)
    echo "ERROR: invalid --action '$ACTION' (expected: increment-replan | increment-revalidate | status | reset)" >&2
    exit 1
    ;;
esac
