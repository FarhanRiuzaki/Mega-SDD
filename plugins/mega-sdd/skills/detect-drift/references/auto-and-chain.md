# detect-drift — --auto, chain integration & handoff

Loaded when detect-drift runs under `--auto` or as an orchestrate-flow chain phase.

## Contents

- `--auto` behavior
- `drift_framework_mismatch` blocker
- Handoff YAML
- Auto-trigger as a chain phase
- Snapshot reuse
- Per-bolt incremental mode

## `--auto` behavior

Since v3.0.0 detect-drift is **forked + non-interactive by default** (`context: fork`) — there is no interactive mode, so this table describes the *only* (deterministic) behavior; `--auto` is implied. Upstream callers (typically `/mega-sdd:orchestrate-flow`) pass `--vault=…` / `--code=…` / `--scope=…` so Step 0 resolves without guessing.

| Step | Deterministic behavior (forked — never prompts) |
|---|---|
| Step 0 (vault path) | `--vault=<path>` arg, else auto-detect the CWD vault dir; unresolvable → `drift_inputs_missing` (vault) |
| Step 0 (codebase path) | `--code=<path>` arg, else CWD if it's obviously a repo (`composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod` / `requirements.txt`\|`pyproject.toml`); otherwise **never guess** → `drift_inputs_missing` (code) |
| Step 0 (mode=new) | STOP — surface `mode_migrate_after` (a hard rule) |
| Step 0 (scope dirs) | `--scope=<dirs\|@file>` arg — sync lane passes `--scope=@<vault>/.sync-changed-paths.txt` (scan's resolved changed set); else full scan. Never self-resolves journal/git post-scan (both consumed by scan-codebase); `@`-prefixed → path-list file |
| Step 1.5 (framework) | Auto-detect; single signature → use it; multi/ambiguous → `drift_framework_mismatch` |
| Step 5 (direction calls) | Queue every finding to `PENDING-SYNC.md`; `--auto-apply=safe` writes back ONLY the narrow safe class. Never `DRIFT-ACTIONS.md`, never a walkthrough |

**No interactive path:** a major framework mismatch (vault implies one stack, code is another) emits `drift_framework_mismatch`; `mode=new` bails with `mode_migrate_after` — both as blockers, never prompts.

**Never:** generates `DRIFT-ACTIONS.md`; calls `AskUserQuestion`; modifies vault content outside the `--auto-apply=safe` class; opens PRs or runs code changes.

## `drift_inputs_missing` blocker

Emitted when a required Step-0 input can't be resolved from `$ARGUMENTS` or the CWD (a fork cannot ask). After emit, the skill stops; no report is generated.

```yaml
blocker:
  type: drift_inputs_missing
  tag: n/a
  priority: n/a
  context: "<e.g. 'Step 0: CODE_DIR unresolved — CWD is not a recognizable repo and no --code arg was passed'>"
  resolver_owner: null
  resolver_route: "re-invoke with --code=<repo-root> (and/or --vault=<vault-dir>)"
  vault_version: "<current or n/a>"
  source_skill: detect-drift
  missing: "<code | vault>"
```

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

Under `--auto`, emit at the end of skill output per the local template below — the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

```yaml
handoff:
  emitted_by: detect-drift
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - <absolute path to <vault>/DRIFT-REPORT.md>
    - <absolute path to <vault>/PENDING-SYNC.md>   # queued direction calls (when findings need triage)
  next_action:
    # Branch on invocation mode (see "Sync-lane vs standalone detection" below).
    # SYNC LANE  ⟺  the resolved --scope is an @file whose basename == `.sync-changed-paths.txt`
    #   → CONTINUE the Mode D chain into claim-scoped re-bind (spec §3.3).
    #   `--paths` echoes the ACTUAL resolved SCOPE_DIRS @-path detect-drift scanned (NOT a hardcoded literal):
    suggested_skill: mega-sdd:bind-codebase
    suggested_args: ["--paths=@<resolved SCOPE_DIRS @-path, e.g. <vault>/.sync-changed-paths.txt>", "--auto"]
    rationale: "<e.g. 'Sync lane: N drift finding(s) queued to PENDING-SYNC.md; continue Mode D → claim-scoped re-bind (§3.3)' OR 'Zero drift; vault + code aligned'>"
    # STANDALONE (any other --scope: a non-sync @file whose basename ≠ .sync-changed-paths.txt, a drift-axis
    #   --scope, a bare scope-id, or no scope) → emit `next_action: null` instead. The DRIFT-REPORT.md +
    #   PENDING-SYNC.md ARE the deliverable; a human triages the queue later via `/mega-sdd:sync` or `resolve-oq`.
    # NEVER route drift to resolve-oq: resolve-oq has NO drift-consumption mode — it resolves normal vault OQs only
    #   (including any drift-CREATED `OQ-DC-N` stub in its ordinary intent mode), it does not consume drift findings.
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

**Sync-lane vs standalone detection (drives `next_action`).** detect-drift has NO dedicated sync flag (unlike bind's `--paths` / scan's `--changed-only`), so sync mode is inferred from the SCOPE_DIRS source (a convention, not a guaranteed flag). The discriminator is a **deterministic basename check**, NOT "any `@file`" (an `@file` scope is a general STANDALONE input per SKILL.md Step 0). **Sync lane** ⟺ the resolved `--scope` is an `@file` whose **basename == `.sync-changed-paths.txt`** — the canonical cross-skill scope artifact scan-codebase `--changed-only` writes, and the ONLY `--scope` the Mode D orchestrator (`orchestrate-flow --sync`) passes. On the sync lane emit `next_action.suggested_skill: mega-sdd:bind-codebase` with `--paths=@<the EXACT resolved SCOPE_DIRS @-path detect-drift read>` (echo the actual scoped file — e.g. `@<vault>/.sync-changed-paths.txt` — NEVER a hardcoded literal, so even a misclassification can only point `--paths` at a file that provably exists and was actually scanned) to CONTINUE the chain (§3.3): scan `--changed-only` → detect-drift (scoped) → claim-scoped re-bind → reconcile → execute. Everything else is **standalone** → `next_action: null`: a **non-sync `@file`** (`--scope=@<other>.txt`, basename ≠ `.sync-changed-paths.txt` — a documented-valid standalone input, e.g. a hand-authored path list), a drift-axis `--scope` (`schema-only` / `flows-only` / …), a bare scope-id `--scope=<id>` (the post-bolt auto-gate — governed by the severity→chain-action map above, which emits halt/pause/log, NOT a bind hand-off), or no scope (full scan). Queued drift stays in `PENDING-SYNC.md` awaiting human triage; the chain does not stall on it, but the moat still blocks downstream units/bolts if the re-bind re-surfaces a CONFLICT (§3.4 / §3.7, invariant #2). Never emit `resolve-oq` for drift routing.

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
