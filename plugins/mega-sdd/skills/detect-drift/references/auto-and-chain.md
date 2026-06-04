# detect-drift — --auto, chain integration & handoff

Loaded when detect-drift runs under `--auto` or as an orchestrate-flow chain phase.

## `--auto` behavior

Passed by upstream callers (typically `/mega-sdd:orchestrate-flow`) to skip logistical prompts and the optional Step 5 walkthrough.

| Step | Interactive | `--auto` |
|---|---|---|
| Step 0 (vault path) | Ask | Auto-detect from CWD if exactly 1 |
| Step 0 (codebase path) | Ask | Use CWD if it's obviously a repo (`composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod`); otherwise REQUIRE an explicit arg — never guess |
| Step 0 (mode=new) | Surface migration trigger | Emit `drift_framework_mismatch` if the trigger isn't detectable, or refuse cleanly with a structured message |
| Step 0.5 (scope) | Ask | Default `full` |
| Step 1.5 (framework) | Detect, propose, confirm | Auto-confirm if a single signature is found; multi/ambiguous → emit `drift_framework_mismatch` |
| Step 5 (walkthrough) | Ask | **Skip.** Write `DRIFT-REPORT.md`, surface top 3 PRIORITY-1 findings in chat. Do NOT generate `DRIFT-ACTIONS.md` (a deliberate human decision) |

**Stays interactive even under `--auto`:** a major framework mismatch (vault implies one stack, code is another → emit blocker, never assume the vault is wrong) and the `mode=new` bail-out (a hard rule `--auto` doesn't change).

**`--auto` never:** generates `DRIFT-ACTIONS.md`; modifies vault content (read-only by design); opens PRs or runs code changes.

## `drift_framework_mismatch` blocker

Emitted when framework detection fails or conflicts with vault expectations. After emit, the skill stops; no report is generated for the mismatched scope; the caller decides whether to override scope or correct the vault.

```yaml
blocker:
  type: drift_framework_mismatch
  tag: n/a
  priority: n/a
  context: "<e.g. 'Step 1.5: vault implies Java/Spring per 02-architecture; codebase is PHP/Laravel per composer.json'>"
  resolver_owner: null
  resolver_route: null
  vault_version: "<current>"
  source_skill: detect-drift
  detected_framework: "<e.g. 'PHP/Laravel'>"
  expected_framework: "<e.g. 'Java/Spring'>"
```

## Handoff YAML

Under `--auto`, emit at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: detect-drift
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - <absolute path to <vault>/DRIFT-REPORT.md>
  next_action:
    suggested_skill: mega-sdd:resolve-oq   # if findings need triage; else null
    suggested_args: ["--auto"]
    rationale: "<e.g. 'N drift findings; route via resolve-oq' OR 'Zero drift; vault + code aligned'>"
  blockers: []                              # populated on drift_framework_mismatch
  metrics:
    items_processed: <N claims compared>
    items_blocked: <N drift findings>
  scope:                                    # when vault has scope_metadata
    id: <scope id, e.g. "BE">
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

Status `halted` on `drift_framework_mismatch`. Standalone invocation emits an informational chat hint only.

## Auto-trigger as a chain phase

When orchestrate-flow runs detect-drift as an auto-gate after an execute-bolts batch (presence of `<vault>/bolts/` with recent postflight snapshots + `--auto-gate`):

1. Switch to incremental mode (snapshot reuse, below).
2. Map severity → chain action: CRITICAL drift on a LOCKED entity → emit a halt blocker (orchestrate-flow halts the chain); HIGH → emit a pause signal (surface to user); MEDIUM/LOW → log only, chain continues.

Standalone invocation (no chain context) behaves as a fresh full scan, ignoring bolt snapshots.

## Snapshot reuse

Per `plugins/mega-sdd/references/shared-snapshot-schema.md`. With `--reuse-bolt-snapshots` (auto-set by the orchestrate-flow auto-gate):

1. For each unit in `vault.json`, read `<vault>/bolts/U-XXX/postflight.json` if present and fresher than `vault.json`.
2. Aggregate file-level sha256 + ast_signatures across valid snapshots.
3. Compare the aggregate vs vault expectations (Steps 1–4).
4. For files not in any postflight, fall back to a fresh scan (usually a small remainder).
5. Performance: ~5s on a 20-bolt batch vs ~28s for a full re-scan.

Stale detection: if `postflight.json.vault_sha256` ≠ the current `vault.json` sha256, fresh-scan that unit's files.

## Per-bolt incremental mode

Used by execute-bolts' per-bolt drift check. Single-bolt scope, invoked with `--per-bolt --unit=U-XXX`: compare only that bolt's `target_files` vs vault expectations and return a synchronous result (no report written):

```
per_bolt_drift_result:
  unit_id: U-XXX
  drift_detected: true | false
  critical_findings: [<list>]
  non_critical_findings: [<list>]
```

execute-bolts renders this inline in its compact streaming format.
