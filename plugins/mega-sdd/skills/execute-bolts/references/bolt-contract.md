# Bolt Contract

A "bolt" is the code artifact produced from executing one unit. The contract specifies what a bolt MUST and MUST NOT do.

## A bolt MUST

- Touch only files in the unit's `target_files` whitelist (each with declared `operation: create|modify|delete`)
- Preserve every `existing_interfaces` contract (verified by acceptance tests)
- Pass every `acceptance_test` entry (test type runs, manual type prompts user to confirm)
- Produce ≥1 git commit per bolt (atomic — partial bolts are not committed)
- Write a `bolt-report.md` under `<vault>/bolts/U-XXX/`

## A bolt MUST NOT

- Modify files outside `target_files`
- Skip acceptance tests (no `--no-test` or similar)
- Auto-resolve OQs (any "TBD: OQ-XXX" in unit body must be answered before bolt finalizes — user is prompted)
- Squash commits across multiple units (one unit = one commit set; commits across units stay separate)
- Push to remote (push is a separate user action — bolt is local-only)

## Commit message format

```
feat(U-XXX): <unit title>

<short summary of what the bolt accomplished>

Refs: <vault-source citation>
Binding: <binding refs if brownfield>
Tests: <test pass count> passing
```

## Failure modes (and bolt behavior)

| Failure | Bolt behavior |
|---|---|
| Acceptance test fails | Retry up to `--max-retries` (default 3); halt + bolt-report on final fail |
| File outside whitelist needed | Halt immediately; user must edit unit |
| Unit body step ambiguous | Halt; prompt user |
| Test framework not installed | Halt; halt-protocol blocker |
| Git commit fails (e.g., pre-commit hook) | Surface hook error verbatim; do not bypass with --no-verify |

## Idempotency

Re-running a bolt for a unit that's already DONE:
- Default: refuse with message ("U-XXX already complete — use `--force` to re-execute")
- `--force`: re-run from scratch; previous commits remain in git history; new bolt-report supersedes
- `--dry-run`: walks steps but does NOT commit; useful for preview
