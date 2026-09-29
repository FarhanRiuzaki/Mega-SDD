# detect-drift — --auto, chain integration & handoff

Loaded when detect-drift runs under `--auto` or as an orchestrate-flow chain phase.

## Contents

- `--auto` behavior
- `drift_framework_mismatch` blocker
- Handoff YAML
- Auto-trigger as a chain phase

## `--auto` behavior

detect-drift is **forked + non-interactive by default** (`context: fork`) — there is no interactive mode, so this table describes the *only* (deterministic) behavior; `--auto` is implied. Upstream callers (typically `/mega-sdd`) pass `--vault=…` / `--code=…` / `--scope=…` so Step 0 resolves without guessing.

| Step | Deterministic behavior (forked — never prompts) |
|---|---|
| Step 0 (vault path) | `--vault=<path>` arg, else auto-detect the CWD vault dir; unresolvable → `drift_inputs_missing` (vault) |
| Step 0 (codebase path) | `--code=<path>` arg, else CWD if it's obviously a repo (`composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod` / `requirements.txt`\|`pyproject.toml`); otherwise **never guess** → `drift_inputs_missing` (code) |
| Step 0 (mode=new) | STOP — surface `mode_migrate_after` (a hard rule) |
| Step 0 (scope dirs) | `--scope=<dirs\|@file>` arg — sync lane passes `--scope=@<vault>/.sync-changed-paths.txt` (the changed set `scripts/derive-changed-paths.sh` wrote); else full scan. Never self-resolves journal/git (journal rotated by `derive-changed-paths.sh` after its write; baseline = the symbol-index stamp GROUND rebuilt); `@`-prefixed → path-list file |
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
    #   → CONTINUE the Mode D chain: the engine first runs `scripts/rebind-units.sh --cwd=<root> --vault=<vault>
    #   --paths=@<the ACTUAL resolved SCOPE_DIRS @-path detect-drift scanned>` (a script is never a suggested_skill),
    #   then the reconcile hop:
    suggested_skill: mega-sdd:plan
    suggested_args: ["--reconcile", "--auto"]
    rationale: "<e.g. 'Sync lane: N drift finding(s) queued to PENDING-SYNC.md; continue Mode D → re-bind → reconcile' OR 'Zero drift; vault + code aligned'>"
    # STANDALONE (any other --scope: a non-sync @file whose basename ≠ .sync-changed-paths.txt, a drift-axis
    #   --scope, a bare scope-id, or no scope) → emit `next_action: null` instead. The DRIFT-REPORT.md +
    #   PENDING-SYNC.md ARE the deliverable; a human triages the queue later via `/mega-sdd:sync` or `resolve-oq`.
    # NEVER route drift to resolve-oq: resolve-oq has NO drift-consumption mode — it resolves normal vault OQs only
    #   (including any drift-CREATED `OQ-DC-N` stub in its ordinary intent mode), it does not consume drift findings.
  blockers: [] # on halt: a LIST of envelope bodies `[ { type, emitted_by, details } ]` — never a mapping (handoff-contract.md §blockers); populated on drift_framework_mismatch
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

**Sync-lane vs standalone detection (drives `next_action`).** detect-drift has NO dedicated sync flag (unlike `rebind-units.sh --paths`), so sync mode is inferred from the SCOPE_DIRS source (a convention, not a guaranteed flag). The discriminator is a **deterministic basename check**, NOT "any `@file`" (an `@file` scope is a general STANDALONE input per SKILL.md Step 0). **Sync lane** ⟺ the resolved `--scope` is an `@file` whose **basename == `.sync-changed-paths.txt`** — the canonical cross-skill scope artifact `scripts/derive-changed-paths.sh` writes, and the ONLY `--scope` the Mode D orchestrator (`orchestrate-flow --sync`) passes. On the sync lane emit `next_action.suggested_skill: mega-sdd:plan` `["--reconcile", "--auto"]`, with the re-bind hop `rebind-units.sh --paths=@<the EXACT resolved SCOPE_DIRS @-path detect-drift read>` named in the handoff (echo the actual scoped file — e.g. `@<vault>/.sync-changed-paths.txt` — NEVER a hardcoded literal, so even a misclassification can only point `--paths` at a file that provably exists and was actually scanned) to CONTINUE the chain (§3.3): `derive-changed-paths.sh` → detect-drift (scoped) → `rebind-units.sh` → `plan --reconcile` → execute. Everything else is **standalone** → `next_action: null`: a **non-sync `@file`** (`--scope=@<other>.txt`, basename ≠ `.sync-changed-paths.txt` — a documented-valid standalone input, e.g. a hand-authored path list), a drift-axis `--scope` (`schema-only` / `flows-only` / …), a bare scope-id `--scope=<id>` (the post-bolt auto-gate — governed by the severity→chain-action map above, which emits halt/pause/log, NOT a re-bind hand-off), or no scope (full scan). Queued drift stays in `PENDING-SYNC.md` awaiting human triage; the chain does not stall on it, but the moat still blocks downstream units/bolts if the re-bind re-surfaces a CONFLICT (§3.4 / §3.7, invariant #2). Never emit `resolve-oq` for drift routing.

## Auto-trigger as a chain phase

When orchestrate-flow runs detect-drift as an auto-gate after an execute-bolts batch (presence of `<vault>/bolts/` with recent `postflight.json` files — the hybrid auto-gate, DEFAULT-ON):

1. Scan fresh, filtered to the vault scope (detect-drift reads no bolt snapshot).
2. Map severity → chain action: CRITICAL drift on a LOCKED entity → emit a halt blocker (orchestrate-flow halts the chain); HIGH → emit a pause signal (surface to user); MEDIUM/LOW → log only, chain continues.

Standalone invocation (no chain context) behaves as a fresh full scan.
