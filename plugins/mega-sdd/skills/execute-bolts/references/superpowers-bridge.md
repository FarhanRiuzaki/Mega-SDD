# Bolt report + whitelist

The two execute-bolts contracts every run uses: target_files whitelist enforcement and the canonical `bolt-report.md` schema. `execute-bolts` runs in the main thread as the controller; the default inline run (`inline-run.md`) dispatches no implementer agent, and superpowers, when installed, is an optional technique there (`inline-run.md` §(c)), never a requirement. **Scope:** the per-unit `--agents` path (its dispatch order, the implementer + review-panel flow and its halt protocol) was retired in P3 (spec v9 §8.6); that text is in git history at commit bb38ba0a.

## Contents

- [Whitelist enforcement](#whitelist-enforcement)
- [bolt-report.md schema](#bolt-reportmd-schema)

## Whitelist enforcement

Before each implementation step, verify the step only touches files in the unit's `target_files`. If a step would touch an out-of-list file:
- Halt.
- Surface: "Unit U-XXX wants to modify <file> but it's not in target_files. Edit the unit or restructure."

Backstop (B3 — deterministic): `validate-bolt-artifacts.sh --whitelist-scan` (Stop-hook +
execute-bolts gate-time) diffs each bolted unit's COMMITTED paths against `target_files`
∪ sanctioned extras (vault/bolt artifacts, `.mega-sdd/`, test files); an escaped path
blocks the next `execute-bolts` with `whitelist_violation`. The prose rule above is the
first line; the observer is the contract.

## bolt-report.md schema

Per unit, after execution. This is the CANONICAL schema (single owner — other refs
describe pieces of it; on conflict this block wins):

```yaml
---
unit: U-XXX
status: success | failed | partial | halted_postflight | forced_pass
attempted_at: <timestamp>
duration_seconds: N
commits: [<sha1>]              # ONE commit per bolt (bolt-contract discipline);
                               # >1 only for sanctioned retry amend-chains
files_touched: [...]
tests_run: [...]
test_results: passed/failed counts
retries: N
target_hashes:                 # MANDATORY — sha256 of each target_files entry
  <repo-relative-path>: <sha256-hex>   # AT COMMIT TIME (living-vault staleness anchor)
scope: <scope-id>              # only when vault.json carries scope_metadata
---

# Bolt Report — U-XXX

## Summary
<one paragraph>

## Acceptance criteria status
- [ ] / [x] criterion 1
- [ ] / [x] criterion 2

## Failures (if any)
<test output, error messages, hypothesis>
```

Statuses `halted_postflight` (post-flight Hard-rule violation recorded — see
hard-rule-scan.md) and `forced_pass` (`--force-skip-postflight` used — anti-bypass
policy applies) are first-class: consumers (compute-unit-staleness, the sync lane,
`_summary.md`) must not treat them as schema errors.
