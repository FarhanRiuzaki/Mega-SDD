# Checkpoint Protocol (v2.0+, Iter 6)

`orchestrate-flow` v2.0+ writes per-step checkpoint files enabling **mid-skill resume** — not just inter-skill resume (Iter 4) but also "bind-codebase crashed at claim 45 of 100 → resume at claim 46".

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

Iter 4's `--resume` is CWD-driven: it reads artifact presence to rebuild the cursor. That works for inter-skill resume (e.g., bind-codebase completed → skip ahead to generate-units). It does NOT work for mid-skill failures (e.g., bind-codebase crashed at claim 45; CWD shows partial binding.md; resume would re-run from claim 1).

Checkpoint protocol adds per-step persistence inside each skill invocation.

## File location + format

```
<vault>/.internal/checkpoints/
├── 2026-05-21T10:00:00Z-extract-intelligence-wave-3.jsonl
├── 2026-05-21T10:30:00Z-generate-intent-step-3.jsonl
├── 2026-05-21T11:00:00Z-bind-codebase-claim-45.jsonl
└── ...
```

Format: **JSONL** (one JSON object per line; append-only; race-tolerant per memory layer convention).

### Per-checkpoint schema

```json
{"checkpoint_schema": 1, "skill": "bind-codebase", "step": "claim_validation", "step_id": "claim-45", "cursor": {"claim_index": 45, "claim_id": "C-045"}, "state": {"confirmed": 30, "conflict": 1, "oq": 14}, "next_step": "claim-46", "artifacts_so_far": ["binding.md.partial"], "resume_command": "/mega-sdd:bind-codebase ./vault --resume-from=claim-46", "timestamp": "2026-05-21T11:00:00Z"}
```

## Skill responsibilities

Each long-running skill MUST emit checkpoints at appropriate granularity:

| Skill | Checkpoint granularity |
|---|---|
| `extract-intelligence` | Per wave (5 waves total) |
| `scan-codebase` | Per major step (detect / tree / extract / write) |
| `bind-codebase` | Per claim (most granular; can be 100s per vault) |
| `generate-units` | Per unit candidate generated |
| `execute-bolts` | Per bolt (per unit invocation) |

Skills that complete in <5s SHOULD NOT emit checkpoints (overhead > value). Examples: `resolve-oq` per-OQ-step, `diff-vault` per-section.

## Append-only writes (race-tolerant)

Each checkpoint write is a single fs.append. Concurrent skill invocations on same vault (rare) do NOT corrupt the JSONL file. Reader (resume command) scans lines, takes most recent for each step_id.

## Resume command

`/mega-sdd:<skill> --resume-from=<step-id>`:

1. Walk checkpoints in chronological order
2. Find latest checkpoint matching this skill's invocation context
3. Restore cursor state from `cursor` field
4. Continue execution from `next_step`

For `--auto` mode invocations (via orchestrate-flow), resume is automatic on `/mega-sdd:auto --resume`:

1. Orchestrator reads ALL checkpoints in current vault
2. Identifies last incomplete skill invocation (most recent checkpoint without a "completed" marker)
3. Invokes that skill with `--resume-from=<latest-step-id>`
4. Skill resumes mid-execution
5. After skill completes, chain continues per Iter 4 handoff YAML protocol

## Rotation policy (per ITER6-OQ-7 resolved)

- Keep checkpoints for last 3 runs in `<vault>/.internal/checkpoints/`
- Older checkpoints moved to `<vault>/.internal/checkpoints-archive/`
- `mega-sdd:memory prune` (Iter 5) cleans archive older than 180 days
- "Run" boundaries detected by timestamp gaps >5 minutes between checkpoints

## Integration with handoff YAML

Handoff YAML (Iter 4) gets one new field:

```yaml
handoff:
  # ... existing fields ...
  checkpoints:                          # v2.0+ (Iter 6)
    latest_step_id: claim-45
    checkpoint_file: <vault>/.internal/checkpoints/<timestamp>-<skill>-<step>.jsonl
    resume_command: "/mega-sdd:bind-codebase --resume-from=claim-46"
```

When skill emits `status: halted` with active checkpoints, orchestrator surfaces the resume command in chat:

```
⛔ Phase 3 of 5: bind-codebase → status: halted, items: 45/100 claims, blocked: 1

Last checkpoint: claim-45 at 2026-05-21T11:00:00Z
Resume command: /mega-sdd:auto --resume (re-enters chain at bind-codebase claim-46)
```

## Backward compatibility

- v2.1 skills (no checkpoint emission) → resume continues to work via CWD-driven cursor (Iter 4 behavior)
- v3.0 skills emit checkpoints; orchestrator reads them when present
- Old vaults without `.internal/checkpoints/` directory → created lazily on first checkpoint emission

## Privacy + cleanup

- Checkpoints contain cursor state ONLY (no sensitive payloads)
- For sensitive-info contexts, `--memory-off` flag suppresses checkpoints
- `mega-sdd:memory clear --scope=vault` deletes checkpoints with vault

## Anti-hallucination rails

- Checkpoint replay is DETERMINISTIC. Skill must produce same output for same cursor state.
- Skills cannot "skip ahead" in checkpoint replay; only resume from explicit cursor
- Resume re-validates inputs before proceeding (e.g., bind-codebase re-loads vault + codebase-map; if either changed since checkpoint, halt and ask user)
- Failed checkpoint writes (disk full) logged but DO NOT halt skill (graceful degradation)

## References

- LangGraph checkpoint pattern: https://github.com/langchain-ai/langgraph (concept inspiration)
- Iter 4 spec: `docs/superpowers/specs/2026-05-20-autonomy-layer-design.md` §6 (inter-skill resume)
- Iter 6 spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.5
