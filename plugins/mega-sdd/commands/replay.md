---
description: Replay a bolt's execution + detect divergence vs prior runs. Read-only diagnostic. Captures bolt-state snapshot (preflight + postflight + bolt-report + git refs); diffs current run vs latest prior. Useful for regression detection after code changes OR debugging non-deterministic bolt behavior. Pure bash + jq; zero new runtime deps.
argument-hint: <unit-id> [--vault=<path>] [--capture-only] [--diff-against=<replay-id>] [--format=table|json]
---

Replay + divergence detection for `execute-bolts` outcomes. Per Iter 18 research finding — IBM DFAH (2026) + LangGraph time-travel validate replay as missing primitive for agentic-dev debugging.

User arguments: $ARGUMENTS

## Procedure

### Step 1 — Resolve vault + unit

- Probe `<project>/.mega-sdd/vaults/*/vault.json` (v3.4+) OR `<project>/docs/mega-sdd/vaults/*/vault.json` (legacy)
- Required positional: `<unit-id>` (e.g., U-001)
- Validate unit exists in vault; halt with helpful error if not

### Step 2 — Capture current bolt state (replay artifact)

Read existing bolt artifacts:
- `<vault>/bolts/<unit-id>/bolt-report.md` (Iter 3+)
- `<vault>/bolts/<unit-id>/preflight.json` (Iter 3+; Hard Rule snapshots)
- `<vault>/bolts/<unit-id>/postflight.json` (Iter 3+; Hard Rule validation results)
- Unit's `target_files` after-state (file checksums via `sha256sum`)

Build snapshot:

```json
{
  "replay_schema": 1,
  "unit_id": "U-001",
  "captured_at": "2026-05-21T16:30:00Z",
  "vault_version": "1.1",
  "git_sha_before": "<commit before bolt>",
  "git_sha_after": "<commit after bolt>",
  "test_command": "./vendor/bin/phpunit --filter=LoginExtensionTest",
  "test_exit_code": 0,
  "test_duration_ms": 1240,
  "target_files": [
    {
      "path": "app/Http/Controllers/Api/LoginController.php",
      "operation": "modify",
      "sha256_after": "abc123...",
      "lines_changed": "+12 -2",
      "before_sha256": "def456...",
      "after_sha256": "abc123..."
    }
  ],
  "preflight": { /* from preflight.json */ },
  "postflight": { /* from postflight.json */ },
  "hard_rules_validated": [
    {"rule_id": "do-not-modify-token-gen", "status": "PASS"},
    {"rule_id": "response-shape-locked", "status": "PASS"}
  ],
  "halt": null,
  "duration_total_ms": 14500
}
```

Persist to `<vault>/.internal/replays/<unit-id>-<timestamp>.json`. JSONL append pattern (race-tolerant per Iter 5+10 memory convention).

### Step 3 — Diff against prior runs (if any)

If prior replay snapshots exist for same `unit-id`:

```bash
# Latest prior:
PRIOR=$(ls -t <vault>/.internal/replays/<unit-id>-*.json | sed -n '2p')
CURRENT=<vault>/.internal/replays/<unit-id>-<latest>.json

# Field-level diff using jd
jd "$PRIOR" "$CURRENT" > <vault>/.internal/replays/<unit-id>-divergence.patch
```

If `jd` available (per Iter 14 adoption), use it for canonical JSON diff. Fall back to manual field-by-field comparison.

### Step 4 — Classify divergence

For each diff entry:

| Divergence type | Severity | Auto-action |
|---|---|---|
| `test_exit_code` changed (0 → non-0 OR vice-versa) | 🔴 HIGH | Halt — regression |
| `test_duration_ms` change > 50% | 🟡 MEDIUM | Warning — perf shift |
| `target_files.sha256_after` mismatch on same target | 🔴 HIGH | Halt — code differs |
| `target_files.lines_changed` differs > 20% | 🟡 MEDIUM | Warning — scope drift |
| `hard_rules_validated[].status` changed | 🔴 HIGH | Halt — rail change |
| `halt` field differs (null vs populated) | 🔴 HIGH | Halt — pipeline behavior changed |
| Cosmetic differences (timestamps only) | 🟢 LOW | Ignore |

### Step 5 — Render output

Default `--format=table`:

```
Replay analysis: U-001
Current run:  2026-05-21T16:30:00Z (replay-3)
Prior run:    2026-05-21T11:45:00Z (replay-2)

Diff summary:
  🟢 No divergence in:
     - test_exit_code (0)
     - target_files set (1 file: LoginController.php)
     - hard_rules_validated count (2/2 PASS)

  🟡 Minor divergence:
     - test_duration_ms: 1240ms → 1180ms (-5%; within normal range)
     - lines_changed: +12 -2 → +13 -2 (1 line added)

  🔴 No high-severity divergence detected.

Verdict: BOLT IS REPRODUCIBLE. Minor variance within tolerance.
```

For `--format=json`: machine-parseable structured output.

### Step 6 — Hand-off

| Outcome | Suggested action |
|---|---|
| Zero divergence | "Bolt fully deterministic — no action needed" |
| Cosmetic-only (timestamps) | "Run reproducible; ignore" |
| Minor (perf shift, line count) | "Acceptable variance; document if performance budget tight" |
| High-severity | "REGRESSION detected — review `.internal/replays/<unit-id>-divergence.patch`; revert OR re-investigate unit" |

## Common pitfalls

### No prior replay snapshots exist

First time running replay → no diff possible. Skill captures current state for future comparison. Re-run after next bolt invocation to see divergence.

### `--capture-only` flag

Skip diff step; only capture current state. Useful for establishing baseline before refactor.

### `--diff-against=<replay-id>` flag

Compare against specific historical replay (not just latest prior). Useful for "compare to known-good run from 2 weeks ago".

### Stale snapshots

Replays older than 180d → auto-prune in `mega-sdd:memory prune` operation. Configurable per `~/.mega-sdd/memory/config.yaml`.

### Bolt halted (no successful state to replay)

If bolt-report.md shows `status: halted_*`, replay capture proceeds but classifies as "partial snapshot". Diff against prior successful run still useful for "what went wrong".

## Anti-halu rails

- Replay is READ-ONLY — never modifies code, vault, or memory
- Diff classification is DETERMINISTIC (rule table; no LLM judgment)
- Snapshots stored as JSON Lines (race-tolerant append per Iter 10 paths convention)
- Cosmetic-only divergence (timestamps) explicitly excluded from halt classification
- All halt classifications cite specific fields + values that differ

## Use cases

1. **Regression detection** — re-run bolt after code refactor; replay confirms no behavior drift
2. **Non-determinism debugging** — same unit produces different outputs across runs → divergence pinpoints which fields differ
3. **CI/CD integration** — run replay in CI; halt PR on high-severity divergence
4. **Audit trail** — historical replays show bolt evolution per unit across vault lifecycle

## References

- Iter 18 spec (this iter)
- Iter 14 jd adoption (used for canonical JSON diff)
- Iter 6 checkpoint protocol (related but distinct — checkpoints are mid-skill state, replays are bolt outcomes)
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — bolt-report.md + preflight.json + postflight.json producers
