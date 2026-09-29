# Checkpoint Protocol

> **Status:** declared contract — no skill or script emits per-step checkpoints at HEAD and no skill accepts `--resume-from`; `--resume` is CWD-driven only (SKILL.md Step 9). Kept as the target design.

`orchestrate-flow` writes per-step checkpoint files enabling **mid-skill resume** — not just inter-skill resume but also "`plan` crashed after writing U-012 of 30 units → resume at U-013".

Inspired by LangGraph's checkpoint-per-node pattern (33k ⭐); implemented as JSONL files (per ITER6-OQ-5).

## Contents

- [Why](#why)
- [File location + format](#file-location--format)
- [Skill responsibilities](#skill-responsibilities)
- [Append-only writes (race-tolerant)](#append-only-writes-race-tolerant)
- [Resume command](#resume-command)
- [Rotation policy](#rotation-policy)
- [Integration with handoff YAML](#integration-with-handoff-yaml)
- [Backward compatibility](#backward-compatibility)
- [Privacy + cleanup](#privacy--cleanup)
- [Anti-hallucination rails](#anti-hallucination-rails)
- [References](#references)

## Why

The base `--resume` is CWD-driven: it reads artifact presence to rebuild the cursor. That works for inter-skill resume (e.g., `plan` completed, `units/_index.md` present → skip ahead to `execute-bolts`). It does NOT work for mid-skill failures (e.g., `plan` crashed after U-012; CWD shows a partial `units/`; resume would re-run plan from Step 1).

Checkpoint protocol adds per-step persistence inside each skill invocation.

## File location + format

```
<vault>/.internal/checkpoints/
├── 2026-05-21T10:00:00Z-extract-intelligence-module-2.jsonl
├── 2026-05-21T10:30:00Z-plan-unit-12.jsonl
├── 2026-05-21T11:00:00Z-execute-bolts-U-003.jsonl
└── ...
```

Format: **JSONL** (one JSON object per line; append-only; race-tolerant).

### Per-checkpoint schema

```json
{"checkpoint_schema": 1, "skill": "plan", "step": "unit_write", "step_id": "unit-12", "cursor": {"unit_index": 12, "unit_id": "U-012"}, "state": {"units_written": 12, "units_planned": 30, "oq": 4}, "next_step": "unit-13", "artifacts_so_far": ["context.md", "units/U-012.md"], "resume_command": "plan <prd> --resume-from=unit-13", "timestamp": "2026-05-21T11:00:00Z"}
```

## Skill responsibilities

Each long-running skill MUST emit checkpoints at appropriate granularity:

| Skill | Checkpoint granularity |
|---|---|
| `extract-intelligence` | Per module PRD written |
| `plan` | Per unit written (Step 4: `units/U-XXX.md`, `_index.md` last) |
| `execute-bolts` | Per bolt (per unit). The JIT bind's `bolts/U-XXX/binding.json` is the per-unit bind record, and one unit re-binds via `scripts/rebind-units.sh --units=U-XXX`. |

Skills that complete in <5s SHOULD NOT emit checkpoints (overhead > value). Examples: `resolve-oq` per-OQ-step, `diff-vault` per-section.

## Append-only writes (race-tolerant)

Each checkpoint write is a single fs.append. Concurrent skill invocations on same vault (rare) do NOT corrupt the JSONL file. Reader (resume command) scans lines, takes most recent for each step_id.

## Resume invocation

A skill re-dispatched with `--resume-from=<step-id>` (via the front door `/mega-sdd --resume`, or a standalone phrase invocation carrying the flag):

1. Walk checkpoints in chronological order
2. Find latest checkpoint matching this skill's invocation context
3. Restore cursor state from `cursor` field
4. Continue execution from `next_step`

For `--auto` mode invocations (via orchestrate-flow), resume is automatic on `/mega-sdd --resume`:

1. CWD / artifact inspection (`routing-rules.md`) first selects WHICH PHASE to resume — the orchestrator itself keeps NO chain-level state file (see handoff-contract.md §Resume mechanics).
2. *Within that re-entered phase only*, read the phase skill's checkpoints in the current vault; identify the last incomplete invocation (most recent checkpoint without a "completed" marker).
3. Invoke that skill with `--resume-from=<latest-step-id>`.
4. Skill resumes mid-execution from its checkpoint cursor (SUB-STEP granularity).
5. After the skill completes, the chain continues per the handoff YAML protocol.

> **Two-level resume:** checkpoints resume a skill's *sub-step*; they do NOT pick the phase. A *completed* phase (artifacts present) is skipped by the orchestrator regardless of any stale checkpoint, so chain-level "no state file" and skill-level checkpoint resume never conflict. Full precedence table → handoff-contract.md §Resume mechanics.

## Rotation policy

- Keep checkpoints for last 3 runs in `<vault>/.internal/checkpoints/`
- Older checkpoints moved to `<vault>/.internal/checkpoints-archive/`
- Archive older than 180 days may be deleted manually
- "Run" boundaries detected by timestamp gaps >5 minutes between checkpoints

## Integration with handoff YAML

Handoff YAML gets one new field:

```yaml
handoff:
  # ... existing fields ...
  checkpoints:
    latest_step_id: unit-12
    checkpoint_file: <vault>/.internal/checkpoints/<timestamp>-<skill>-<step>.jsonl
    resume_command: "plan <prd> --resume-from=unit-13"
```

When skill emits `status: halted` with active checkpoints, orchestrator surfaces the resume command in chat:

```
⛔ Phase 1 of 2: plan → status: halted, items: 12/30 units, blocked: 1

Last checkpoint: unit-12 at 2026-05-21T11:00:00Z
Resume command: /mega-sdd --resume (re-enters chain at plan unit-13)
```

## Backward compatibility

- Skills without checkpoint emission → resume continues to work via CWD-driven cursor (base behavior)
- Skills that emit checkpoints → orchestrator reads them when present
- Old vaults without `.internal/checkpoints/` directory → created lazily on first checkpoint emission

## Privacy + cleanup

- Checkpoints contain cursor state ONLY (no sensitive payloads)
- Checkpoints live under the vault (`.internal/checkpoints/`); deleting the vault deletes them

## Anti-hallucination rails

- Checkpoint replay is DETERMINISTIC. Skill must produce same output for same cursor state.
- Skills cannot "skip ahead" in checkpoint replay; only resume from explicit cursor
- Resume re-validates inputs before proceeding (e.g., plan re-reads the PRD and the GROUND state; if the PRD sha (`derive-plan-pins.sh` `prd_sha256`) or HEAD changed since the checkpoint, halt and ask the user)
- Failed checkpoint writes (disk full) logged but DO NOT halt skill (graceful degradation)

## References

- LangGraph checkpoint pattern: https://github.com/langchain-ai/langgraph (concept inspiration)
- Design spec: `docs/superpowers/specs/2026-05-20-autonomy-layer-design.md` §6 (inter-skill resume)
- Design spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.5
