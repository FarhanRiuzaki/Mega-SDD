"through" with end-range PAST what's on disk (only U-017..U-025 exist; U-026..U-030 missing).
This MUST still fail — defense-in-depth should NOT introduce false-negative.

```yaml
handoff:
  emitted_by: mega-sdd:execute-bolts
  emitted_at: 2026-05-30T00:00:00Z
  status: completed
  artifacts:
    - .mega-sdd/vaults/test-vault/bolts/U-017/ through U-030/
  next_action:
    suggested_skill: mega-sdd:detect-drift
    suggested_args: []
    rationale: "test"
  blockers: []
```
