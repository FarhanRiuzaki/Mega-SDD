# Checkpoint Protocol

`orchestrate-flow` writes per-step checkpoint files enabling **mid-skill resume** — not just inter-skill resume but also "bind-codebase crashed at claim 45 of 100 → resume at claim 46".

Inspired by LangGraph's checkpoint-per-node pattern (33k ⭐); implemented as JSONL files (per ITER6-OQ-5).

## Contents

- [Why](#why)
- [File location + format](#file-location--format)
- [Skill responsibilities](#skill-responsibilities)
- [Append-only writes (race-tolerant)](#append-only-writes-race-tolerant)
- [Resume command](#resume-command)
- [Rotation policy](#rotation-policy-per-iter6-oq-7-resolved)
- [Integration with handoff YAML](#integration-with-handoff-yaml)
- [Backward compatibility](#backward-compatibility)
- [Privacy + cleanup](#privacy--cleanup)
- [Anti-hallucination rails](#anti-hallucination-rails)
- [References](#references)

## Why

The base `--resume` is CWD-driven: it reads artifact presence to rebuild the cursor. That works for inter-skill resume (e.g., bind-codebase completed → skip ahead to generate-units). It does NOT work for mid-skill failures (e.g., bind-codebase crashed at claim 45; CWD shows partial binding.md; resume would re-run from claim 1).

Checkpoint protocol adds per-step persistence inside each skill invocation.

## File location + format

```
<vault>/.internal/checkpoints/
├── 2026-05-21T10:00:00Z-extract-intelligence-wave-3.jsonl
├── 2026-05-21T10:30:00Z-generate-intent-step-3.jsonl
├── 2026-05-21T11:00:00Z-bind-codebase-claim-45.jsonl
└── ...
```

Format: **JSONL** (one JSON object per line; append-only; race-tolerant).

### Per-checkpoint schema

```json
{"checkpoint_schema": 1, "skill": "bind-codebase", "step": "claim_validation", "step_id": "claim-45", "cursor": {"claim_index": 45, "claim_id": "C-045"}, "state": {"confirmed": 30, "conflict": 1, "oq": 14}, "next_step": "claim-46", "artifacts_so_far": ["binding.md.partial"], "resume_command": "bind-codebase ./vault --resume-from=claim-46", "timestamp": "2026-05-21T11:00:00Z"}
```

## Skill responsibilities

Each long-running skill MUST emit checkpoints at appropriate granularity:

| Skill | Checkpoint granularity |
|---|---|
| `extract-intelligence` | Per module PRD written |
| `scan-codebase` | Per major step (detect / tree / extract / write) |
| `bind-codebase` | Per claim (most granular; can be 100s per vault) |
| `generate-units` | Per unit candidate generated |
| `execute-bolts` | Per bolt (per unit invocation) |

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

> **Two-level resume (AUDIT L7):** checkpoints resume a skill's *sub-step*; they do NOT pick the phase. A *completed* phase (artifacts present) is skipped by the orchestrator regardless of any stale checkpoint, so chain-level "no state file" and skill-level checkpoint resume never conflict. Full precedence table → handoff-contract.md §Resume mechanics.

## Rotation policy (per ITER6-OQ-7 resolved)

- Keep checkpoints for last 3 runs in `<vault>/.internal/checkpoints/`
- Older checkpoints moved to `<vault>/.internal/checkpoints-archive/`
- Archive older than 180 days may be deleted manually (v7.3.0: the memory maintenance command was removed)
- "Run" boundaries detected by timestamp gaps >5 minutes between checkpoints

## Integration with handoff YAML

Handoff YAML gets one new field:

```yaml
handoff:
  # ... existing fields ...
  checkpoints:
    latest_step_id: claim-45
    checkpoint_file: <vault>/.internal/checkpoints/<timestamp>-<skill>-<step>.jsonl
    resume_command: "bind-codebase --resume-from=claim-46"
```

When skill emits `status: halted` with active checkpoints, orchestrator surfaces the resume command in chat:

```
⛔ Phase 3 of 5: bind-codebase → status: halted, items: 45/100 claims, blocked: 1

Last checkpoint: claim-45 at 2026-05-21T11:00:00Z
Resume command: /mega-sdd --resume (re-enters chain at bind-codebase claim-46)
```

## Backward compatibility

- Skills without checkpoint emission → resume continues to work via CWD-driven cursor (base behavior)
- v3.0 skills emit checkpoints; orchestrator reads them when present
- Old vaults without `.internal/checkpoints/` directory → created lazily on first checkpoint emission

## Privacy + cleanup

- Checkpoints contain cursor state ONLY (no sensitive payloads)
- Checkpoints live under the vault (`.internal/checkpoints/`); deleting the vault deletes them

## Anti-hallucination rails

- Checkpoint replay is DETERMINISTIC. Skill must produce same output for same cursor state.
- Skills cannot "skip ahead" in checkpoint replay; only resume from explicit cursor
- Resume re-validates inputs before proceeding (e.g., bind-codebase re-loads vault + codebase-map; if either changed since checkpoint, halt and ask user)
- Failed checkpoint writes (disk full) logged but DO NOT halt skill (graceful degradation)

## References

- LangGraph checkpoint pattern: https://github.com/langchain-ai/langgraph (concept inspiration)
- Design spec: `docs/superpowers/specs/2026-05-20-autonomy-layer-design.md` §6 (inter-skill resume)
- Design spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.5
