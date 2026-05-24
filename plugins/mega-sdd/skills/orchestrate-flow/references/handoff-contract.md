# Handoff Contract — Skill → Orchestrator (v2.0+, Iter 4)

When mega-sdd skills run under `--auto` (i.e., dispatched by `orchestrate-flow --deep` or `/mega-sdd:auto`), they MUST emit a structured **handoff record** at the end of their chat output. The orchestrator parses this record to decide whether to auto-continue the chain, pause on blocker, or stop.

This contract is required ONLY when `--auto` is in effect. Standalone skill invocations (user typed `/mega-sdd:<specific-skill>`) MAY emit the YAML but it is informational — no orchestrator consumes it.

---

## Handoff YAML schema

```yaml
handoff:
  emitted_by: <skill-name>              # e.g., generate-intent, bind-codebase
  emitted_at: <ISO8601 timestamp>
  status: completed | paused | halted
  artifacts:
    - <absolute path to primary output 1>
    - <absolute path to primary output 2>
    # ... list every file/dir this skill wrote
  next_action:
    suggested_skill: mega-sdd:<next-skill>     # e.g., mega-sdd:scan-codebase
    suggested_args: ["--flag=value", "positional"]  # exact CLI args to invoke
    rationale: "<1-sentence why this is the right next step>"
  blockers: []                          # empty when status=completed
                                        # populated when status=paused/halted (per halt-protocol §blocker envelope)
  metrics:                              # optional but encouraged
    duration_ms: <int>
    items_processed: <int>              # OQs / claims / units / etc — context-dependent
    items_blocked: <int>                # number that require human input
  checkpoints:                          # v3.0+ (Iter 6) — checkpoint protocol; optional
    latest_step_id: <string>            # e.g., "claim-45" for bind-codebase, "wave-3" for extract-intelligence
    checkpoint_file: <absolute-path>    # <vault>/.internal/checkpoints/<timestamp>-<skill>-<step>.jsonl (v3.4+ canonical per paths.md)
    resume_command: <string>            # e.g., "/mega-sdd:bind-codebase --resume-from=claim-46"
  constitution:                         # v3.13+ (Iter 17 — formally added Iter 20) — when constitution.md exists
    constitution_hash: <sha256>         # of <vault>/constitution.md at handoff emission time
    clauses_referenced: []              # clause IDs cited in this skill's output (e.g., ["A-001", "B-002"])
  pbt:                                  # v3.13+ (Iter 18 — formally added Iter 20) — when properties: present
    properties_validated: <N>           # count of property-based tests run this phase
    properties_failed: <N>              # count violated; details in postflight.json
  mutability:                           # v3.17+ (Iter 25 — propagates Iter 22 mutability tiers)
    tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }  # aggregate over claims/units processed
    locked_claims_touched: []           # specific claim/unit IDs with mutability_source = kb_locked
    artifact_discards_proposed: <N>     # count of [ARTIFACT] items flagged for discard (user confirmation pending)
  scope:                                # v3.20+ (Iter 28 — propagates multi-scope PRD picker)
    id: <scope id, e.g., "BE">          # from vault.json scope_metadata.id (omit if legacy single-scope vault)
    name: <scope name>                  # from vault.json scope_metadata.name
    sibling_scopes: []                  # list of OTHER scopes from PRD (informational)
    prd_sha256: <sha256>                # from vault.json (used by downstream skills to detect PRD changes)
  cycles:                               # v3.13+ (Iter 19 — formally added Iter 20) — when convergence loops active
    cycle_count: <N>                   # how many auto-recovery cycles ran
    halts_auto_resolved: []             # halt types resolved via memory recommendations
    halts_escalated_to_user: []         # halt types deferred for manual review
  replay:                               # v3.13+ (Iter 18 — formally added Iter 20) — when replay capture active
    snapshot_path: <abs path to .internal/replays/*.jsonl>
    divergence_classification: clean | minor | high | n/a
  starterkit_context:                   # v3.23+ (Iter 32) — optional; present when scan-codebase deep-scan stage ran
    reused: <bool>                      # true if cache hit (no subagent dispatch); false if fresh scan
    framework: <string>                 # e.g., laravel
    auth_lib: <enum>                    # mirrors §auth.lib in starterkit-context.yaml
    rbac_lib: <enum>                    # mirrors §rbac.lib
    ui_stack: <string>                  # short-form summary, e.g., "alpine + tailwind + sweetalert2"
    libs_count: <int>                   # total libs detected in §libs
  metadata:                             # v2.1+ (Iter 5) — memory layer integration; optional otherwise
    memory_context:                     # IN — orchestrator provides relevant memory slices to skill at invocation
      project_decisions_relevant: []    # rows from <project>/.mega-sdd/memory/decisions.md matching the skill's domain (v3.4+ canonical)
      project_conventions_relevant: []  # rows from conventions.md
      vault_outcomes_relevant: []       # rows from <vault>/.memory/*.json matching this skill
      user_patterns_relevant: []        # rows from ~/.mega-sdd/memory/patterns.md (when ≥1 matching pattern)
      user_preferences_relevant: []     # rows from preferences.md (flag defaults)
    memory_writes:                      # OUT — skill emits writes for orchestrator to persist
      - file: <relative-or-absolute-path>
        scope: user | project | vault
        action: append | update
        content: |
          <markdown row or JSON entry to append>
        source_run: <skill-name>@<timestamp>
```

### `starterkit_context:` (v3.23.0+, Iter 32)

Optional block carrying starterkit detection results forward through the chain.

**Producer:** scan-codebase v2.6.0+ Step 2 deep-scan stage emits this block when a framework is detected with confidence ≥ MEDIUM AND `starterkit-context.yaml` was written.

**Propagation:** orchestrate-flow passes this block to all downstream skills (generate-intent, bind-codebase, generate-units, execute-bolts) without modification.

**Schema:**

```yaml
starterkit_context:
  reused: <bool>                  # true if cache hit (no subagent dispatch); false if fresh scan
  framework: <string>             # e.g., laravel
  auth_lib: <enum>                # mirrors §auth.lib in starterkit-context.yaml
  rbac_lib: <enum>                # mirrors §rbac.lib
  ui_stack: <string>              # short-form summary, e.g., "alpine + tailwind + sweetalert2"
  libs_count: <int>               # total libs detected in §libs
```

**Consumer-side annotations:** generate-units and execute-bolts MAY append their own metrics under this block (see per-skill examples).

**Canonical source of truth for full structure:** `plugins/mega-sdd/references/starterkit-context-schema.md`

### Status values

- **`completed`** — skill ran successfully end-to-end. Orchestrator auto-continues to `next_action.suggested_skill` if `--deep` mode active.
- **`paused`** — skill completed its work BUT something downstream needs user attention (e.g., business OQs needing resolution, tech-OQ recommendations needing review). Chain pauses; user reviews surfaced items; resumes via `/mega-sdd:auto --resume` or `/mega-sdd:orchestrate-flow --deep --resume`.
- **`halted`** — hard blocker fired (CONFLICT, hard_rule_violated, dedup_ambiguous, etc.). `blockers` populated with one or more entries per halt-protocol. Chain stops. User resolves manually.

### Block of artifacts

Every skill MUST list its primary output paths (absolute). `orchestrate-flow` uses these to:
- Verify the skill actually produced output (sanity check before continuing)
- Locate the next skill's input (e.g., `bind-codebase` needs the vault path from `generate-intent`'s artifact list)
- Generate the final pipeline summary at chain end

---

## Per-skill expected emissions

### `extract-intelligence`

```yaml
handoff:
  emitted_by: extract-intelligence
  status: completed
  artifacts:
    - /path/to/.mega-sdd/knowledge-base/
    - /path/to/.mega-sdd/knowledge-base/README.md
  next_action:
    suggested_skill: mega-sdd:generate-intent
    suggested_args: ["--kb=.mega-sdd/knowledge-base/", "--auto"]
    rationale: "Knowledge base extracted; generate vault using KB as Mode B brief."
  metrics:
    items_processed: 35    # MD files written
    items_blocked: 0
```

Status `halted` when quality gate fails twice (per `extract-intelligence/references/wave-dispatch-templates.md` §gate failures).

### `generate-intent`

```yaml
handoff:
  emitted_by: generate-intent
  status: completed | paused
  artifacts:
    - /path/to/.mega-sdd/vaults/<slug>/
    - /path/to/.mega-sdd/vaults/<slug>/vault.json
  next_action:
    suggested_skill: mega-sdd:scan-codebase  # if brownfield
    # OR
    suggested_skill: mega-sdd:generate-units  # if greenfield
    suggested_args: ["--auto"]
    rationale: "..."
  metrics:
    items_processed: 48    # OQs generated
    items_blocked: 12      # OQs requiring stakeholder input (business / blocking)
```

Status `paused` when P1 business OQs are produced (downstream still works, but user should triage). Status `halted` on `oq_tech_missing_mode` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` / `oq_scan_missing_query`.

### `scan-codebase`

```yaml
handoff:
  emitted_by: scan-codebase
  status: completed
  artifacts:
    - /path/to/codebase-map.md
  next_action:
    suggested_skill: mega-sdd:bind-codebase
    suggested_args: ["/path/to/vault/", "--auto"]
    rationale: "Codebase mapped; validate vault claims against it."
  starterkit_context:
    reused: false
    framework: laravel
    auth_lib: sanctum
    rbac_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
```

Status `halted` on `deep_scan_subagent_all_failed`. Status soft-halt (warn-only, chain continues) on `deep_scan_subagent_failed` / `deep_scan_cache_corrupt`.

### `bind-codebase`

```yaml
handoff:
  emitted_by: bind-codebase
  status: completed | paused | halted
  artifacts:
    - /path/to/binding.md
    - /path/to/vault-bound/    # only if no CONFLICTs
  next_action:
    suggested_skill: mega-sdd:generate-units    # status=completed
    # OR
    suggested_skill: mega-sdd:resolve-oq        # status=halted on conflict
    suggested_args: ["--auto"]
  blockers: []  # OR populated on halt
  metrics:
    items_processed: 87    # claims
    items_blocked: 0       # CONFLICTs
```

Status `halted` on `bind_conflict` (per existing halt-protocol). Status `paused` when tech-OQ recommendations need user review (informational pause; downstream still runs).

### `generate-units`

```yaml
handoff:
  emitted_by: generate-units
  status: completed | halted
  artifacts:
    - /path/to/vault/units/
    - /path/to/vault/units/_index.md
  next_action:
    suggested_skill: mega-sdd:execute-bolts
    suggested_args: ["--all", "--auto"]
    rationale: "Units generated; execute via bolts."
  metrics:
    items_processed: 12    # units
    items_blocked: 0
  starterkit_context:
    reused: false
    framework: laravel
    auth_lib: sanctum
    rbac_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    units_with_starterkit_anchors: 12
    units_with_starterkit_rules: 8
```

Status `halted` on `cycle_detected` / `cross_squad_dep_invalid` / `dedup_ambiguous` / `unit_underspecified` / `hard_rule_unparseable` / `starterkit_rule_citation_missing`.

### `execute-bolts`

```yaml
handoff:
  emitted_by: execute-bolts
  status: completed | halted
  artifacts:
    - /path/to/vault/bolts/U-001/
    - /path/to/vault/bolts/U-002/
    # ... one per unit executed
  next_action:
    suggested_skill: mega-sdd:detect-drift
    suggested_args: []
    rationale: "All bolts executed; recommend periodic drift check."
  metrics:
    items_processed: 12    # units executed
    items_blocked: 0       # halts
  starterkit_context:
    reused: false
    framework: laravel
    auth_lib: sanctum
    rbac_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    bolts_used_starterkit_slice: 11
    slice_avg_size_kb: 1.6
```

Status `halted` on `test_fail` / `hard_rule_violated` / `hard_rule_unparseable` / `hard_rule_unanchored` / `cross_squad_interface_draft`.

### `diff-vault`

Canonical handoff YAML:

```yaml
emitted_by: diff-vault
emitted_at: <ISO8601>
status: completed | paused | halted
artifacts:
  - <abs path to <vault>/VAULT-DIFF.md>
  - <abs path to <vault>/vault.json (updated)>
  - <abs path to <vault>/00-index.md (updated)>
  - <abs path to <vault>/.mega-sdd/vault-diffs/<ISO8601>.patch>
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: invoke_skill | user_review
  suggested_skill: mega-sdd:bind-codebase | mega-sdd:resolve-oq
  suggested_args: ["--auto"]
blockers: []
metrics:
  decisions_appended: <N>
  conflicts_detected: <N>
```

Status `halted` on: `diff_conflict`

### `emit-agents-md`

Canonical handoff YAML:

```yaml
emitted_by: emit-agents-md
emitted_at: <ISO8601>
status: completed | halted
artifacts:
  - <abs path to <project>/AGENTS.md (created or updated)>
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: chain_complete
  hint: "AGENTS.md is the pipeline terminal output for AI agent consumers"
blockers: []
metrics:
  agents_md_lines: <N>
  rules_emitted: <N>
```

Status `halted` on: `user_authored_conflict | vault_not_found | vault_corrupt | greenfield_no_bind_context`

### `resolve-oq`

Canonical handoff YAML:

```yaml
emitted_by: resolve-oq
emitted_at: <ISO8601>
status: completed | paused | halted
artifacts:
  - <abs path to <vault>/01-overview.md (updated)>
  # ... (any vault file that had OQs resolved)
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: invoke_skill | user_review
  suggested_skill: mega-sdd:generate-units | mega-sdd:execute-bolts
  suggested_args: ["--auto"]
blockers: []
metrics:
  items_resolved: <N>
  items_deferred: <N>
  items_blocked: <N>
```

Status `halted` on: malformed vault | cycle protection in --binding mode

### `detect-drift`

Canonical handoff YAML:

```yaml
emitted_by: detect-drift
emitted_at: <ISO8601>
status: completed | halted
artifacts:
  - <abs path to <vault>/DRIFT-REPORT.md>
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: invoke_skill | user_review
  suggested_skill: mega-sdd:resolve-oq | mega-sdd:emit-agents-md
  suggested_args: ["--auto", "--scope=<id>"]  # propagate scope when detect-drift ran in scope-filtered mode
blockers: []
metrics:
  findings_critical: <N>
  findings_high: <N>
  findings_medium: <N>
  findings_low: <N>
```

Status `halted` on: `drift_framework_mismatch | constitution_drift_detected`

---

## Memory layer integration (v2.1+, Iter 5)

When `--auto` mode is active AND memory layer enabled (default; opt-out via `--memory-off`):

### Orchestrator memory read (chain start, ONCE per chain per MEMORY-OQ-7)

Before invoking the first skill in `--deep` mode:

1. Read user-scope: `~/.mega-sdd/memory/preferences.md` + `~/.mega-sdd/memory/patterns.md`
2. Read project-scope: `<cwd-project-root>/.mega-sdd/memory/decisions.md` + `conventions.md` + `outcomes.md`
3. Read vault-scope (if vault path detected in CWD): `<vault>/.memory/classifier-accuracy.json` + `bind-history.md` + `bolt-outcomes.json`
4. Build per-skill memory slices (only what's relevant to each skill's domain)
5. Pass slices to each skill via handoff YAML `metadata.memory_context` field at invocation

### Orchestrator memory write (after each phase, atomic per file)

After each skill emits its handoff YAML with `metadata.memory_writes`:

1. Parse each write entry (file, scope, action, content)
2. Resolve target path based on scope (user/project/vault)
3. Append (or update with supersedes marker) the content to the target file
4. Per MEMORY-OQ-6: append-only writes are atomic at fs level; concurrent runs do not collide
5. Failed writes logged to chat but do NOT halt the chain (memory is optional)

### Skill responsibilities

Per `references/handoff-contract.md` §metadata extension:

- Skill READS its memory slice from `metadata.memory_context` at startup (no disk re-read)
- Skill applies memory consultations per its own SKILL.md §Memory layer section
- Skill builds its memory writes during execution
- Skill emits all writes in `metadata.memory_writes` array at end

This keeps autonomy mode FAST (memory I/O batched at orchestrator level) and CONSISTENT (single source of truth for memory state per chain run).

### Schema mismatch handling (per MEMORY-OQ-1)

If orchestrator detects memory schema version mismatch during chain-start read:

1. Halt chain BEFORE first skill invocation
2. Emit `memory_schema_mismatch` blocker YAML
3. User runs migration helper via `mega-sdd:memory` skill
4. Resume chain via `--resume` after migration

## Orchestrator consumption logic

`orchestrate-flow --deep` (or `/mega-sdd:auto`) implements this control loop:

```
loop:
  invoke current skill with --auto
  parse handoff YAML from skill output
  if handoff.status == completed:
    log: "✓ Phase {N} of {M} completed: {skill}"
    if --deep AND no --stop-after match:
      current = handoff.next_action.suggested_skill
      args = handoff.next_action.suggested_args
      continue loop
    else:
      exit loop with summary
  if handoff.status == paused:
    log: "⏸ Phase {N} paused: {skill}. Items needing review: {items_blocked}"
    surface paused-item summary in chat
    exit loop awaiting user review
  if handoff.status == halted:
    log: "⛔ Phase {N} halted: {skill}. Blockers: {blockers list}"
    surface verbatim blocker YAMLs in chat
    exit loop awaiting user resolution

emit final summary:
  - Phases completed: {count} of {total proposed}
  - Phases paused: {count} (list)
  - Phases halted: {count} (list)
  - Artifacts produced: {flat list of all artifacts paths}
```

### Progress indication (AUTONOMY-OQ-4 resolved)

Before each skill invocation, orchestrator emits one line:
```
▶ Phase {current} of {total}: invoking {skill} ({args})
```

After each skill completes, orchestrator emits one line:
```
{status-icon} Phase {current} of {total}: {skill} → status: {status}, items: {items_processed}, blocked: {items_blocked}
```

This gives the user real-time visibility without polluting chat with verbose per-skill output (the skill's own output remains visible too, since skill invocations write directly to chat).

### Resume mechanics (AUTONOMY-OQ-2 resolved: CWD-driven)

`/mega-sdd:auto --resume` does NOT read a persisted state file. It re-runs CWD inspection per `routing-rules.md`, proposes the same chain, and:
- If artifacts already exist for earlier phases → skip them (cursor advances past them automatically based on CWD signals)
- If the cursor lands on a previously-halted phase → user must have resolved the blocker manually (else the same halt fires again, which is correct safety behavior)
- If user wants to RE-RUN a previously-completed phase → use `orchestrate-flow --from=<phase>` explicit override

This keeps orchestrator stateless (per the spec's "no state file" decision).

---

## Anti-halu invariants for handoff YAML

- Skills MUST NOT lie about status. If acceptance tests failed, status is `halted`, not `completed`.
- Skills MUST list every artifact they wrote. Missing artifacts means orchestrator can't find downstream input → cascade failure.
- Skills MUST emit `next_action` even on `halted` status — it should point to the resolution path (e.g., `resolve-oq` for binding conflicts, manual review for `dedup_ambiguous`).
- Orchestrator MUST surface blocker YAMLs verbatim. No paraphrasing.
- Orchestrator MUST NOT invoke `next_action.suggested_skill` if status is `paused` or `halted`. Chain pauses; user resumes manually.

---

## Backward compatibility

- Skills WITHOUT handoff emission (pre-v2.0) → orchestrator treats their completion as `status: completed` with `next_action: null`. Chain stops after that skill. Acceptable degraded behavior.
- Skills with handoff emission but invoked WITHOUT `--auto` → chat hint still visible to human. YAML is harmless (parseable but unused).
- v1.x `orchestrate-flow` (3-skill cap, no --deep) → unchanged behavior. The cap-lift is opt-in via `--deep`.

---

## Slash-command flag surface (v2.0+)

```
/mega-sdd:orchestrate-flow [--from=<phase>] [--to=<phase>] [--dry-run]
  + [--deep]      # NEW (v2.0): lift 3-skill cap; chain to pipeline-end when state clean
  + [--resume]    # NEW (v2.0): CWD-driven resume (no persisted state)
```

```
/mega-sdd:auto [input] [--deep|--shallow] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual]
                # NEW (v2.0) — one-shot autonomous pipeline
```
