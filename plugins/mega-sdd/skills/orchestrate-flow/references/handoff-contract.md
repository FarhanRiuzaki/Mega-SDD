# Handoff Contract — Skill → Orchestrator

When mega-sdd skills run under `--auto` (i.e., dispatched by `orchestrate-flow --deep` or `/mega-sdd:auto`), they MUST emit a structured **handoff record** at the end of their chat output. The orchestrator parses this record to decide whether to auto-continue the chain, pause on blocker, or stop.

This contract is required ONLY when `--auto` is in effect. Standalone skill invocations (user typed `/mega-sdd:<specific-skill>`) MAY emit the YAML but it is informational — no orchestrator consumes it.

> **Precedence (anti-drift rule):** each skill's OWN handoff reference (e.g. `scan-codebase/references/halts-flags-handoff.md`, `execute-bolts/references/halts-and-handoff.md`) is the OPERATIVE emission spec — it loads with the emitting skill at runtime. The per-skill blocks below are a cross-skill INDEX for the orchestrator/consumer side; when they disagree with a skill's own reference, the skill's reference wins and the block here is the bug. Top-level field names/types in §Handoff YAML schema remain binding for everyone (the validator enforces those).

---

## Contents

- [Handoff YAML schema](#handoff-yaml-schema)
- [Field-level schema annotations](#field-level-schema-annotations)
- [Per-skill expected emissions](#per-skill-expected-emissions)
- [Memory layer integration](#memory-layer-integration)
- [Orchestrator consumption logic](#orchestrator-consumption-logic)
- [Anti-halu invariants for handoff YAML](#anti-halu-invariants-for-handoff-yaml)
- [Backward compatibility](#backward-compatibility)
- [Slash-command flag surface](#slash-command-flag-surface)

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
  checkpoints:                          # checkpoint protocol; optional
    latest_step_id: <string>            # e.g., "claim-45" for bind-codebase, "wave-3" for extract-intelligence
    checkpoint_file: <absolute-path>    # <vault>/.internal/checkpoints/<timestamp>-<skill>-<step>.jsonl (canonical per paths.md)
    resume_command: <string>            # e.g., "/mega-sdd:bind-codebase --resume-from=claim-46"
  constitution:                         # when constitution.md exists
    constitution_hash: <sha256>         # of <vault>/constitution.md at handoff emission time
    clauses_referenced: []              # clause IDs cited in this skill's output (e.g., ["A-001", "B-002"])
  pbt:                                  # when properties: present
    properties_validated: <N>           # count of property-based tests run this phase
    properties_failed: <N>              # count violated; details in postflight.json
  mutability:                           # tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }  # aggregate over claims/units processed
    locked_claims_touched: []           # specific claim/unit IDs with mutability_source = kb_locked
    artifact_discards_proposed: <N>     # count of [ARTIFACT] items flagged for discard (user confirmation pending)
  scope:                                # id: <scope id, e.g., "BE">          # from vault.json scope_metadata.id (omit if legacy single-scope vault)
    name: <scope name>                  # from vault.json scope_metadata.name
    sibling_scopes: []                  # list of OTHER scopes from PRD (informational)
    prd_sha256: <sha256>                # from vault.json (used by downstream skills to detect PRD changes)
  cycles:                               # when convergence loops active
    cycle_count: <N>                   # how many auto-recovery cycles ran
    halts_auto_resolved: []             # halt types resolved via memory recommendations
    halts_escalated_to_user: []         # halt types deferred for manual review
  replay:                               # when replay capture active
    snapshot_path: <abs path to .internal/replays/*.jsonl>
    divergence_classification: clean | minor | high | n/a
  starterkit_context:                   # optional; present when scan-codebase deep-scan stage ran
    reused: <bool>                      # true if cache hit (no subagent dispatch); false if fresh scan
    framework: <string>                 # e.g., laravel
    auth_lib: <enum>                    # mirrors §auth.lib in starterkit-context.yaml
    authz_lib: <enum>                   # mirrors §authz.lib
    ui_stack: <string>                  # short-form summary, e.g., "alpine + tailwind + sweetalert2"
    libs_count: <int>                   # total libs detected in §libs
  metadata:                             # memory layer integration; optional otherwise
    memory_context:                     # IN — orchestrator provides relevant memory slices to skill at invocation
      project_decisions_relevant: []    # rows from <project>/.mega-sdd/memory/decisions.md matching the skill's domain (canonical)
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
    model_tiers:                        # resolved model tier per named subagent role
      auth-extractor: sonnet            # example; actual entries depend on chain roles
      code-quality-reviewer: opus       # catalog default; may be overridden by CLI/project/user
      # ... (all roles relevant to chain)
    model_tier_sources:                 # auth-extractor: catalog           # catalog | user | project | cli
      code-quality-reviewer: catalog
```

---

## Field-level schema annotations

Each annotation is machine-readable for the Step 6.b validation gate.
`(REQUIRED)` — must be present in every handoff regardless of context.
`(CONDITIONAL)` — must be present when stated runtime condition is met.
`(OPTIONAL)` — encouraged but absence is never a halt.

### `emitted_by:` (REQUIRED)

TYPE: string — must match one of the values in `vault-contract.md §halt-protocol source_skill` enum (e.g., `generate-intent`, `bind-codebase`). Identifies the producing skill.

### `emitted_at:` (REQUIRED)

TYPE: string — ISO8601 timestamp. Identifies when the handoff was emitted. Required even if orchestrator never uses it for routing; presence confirms skill ran to handoff-emit step.

### `status:` (REQUIRED)

TYPE: enum — one of `completed | paused | halted`. Drives orchestrator control-flow decision (auto-continue / surface-items / surface-blocker).

### `artifacts:` (REQUIRED)

TYPE: array\<string\> — absolute file paths. Non-empty when `status==completed`; may be empty when `status==halted` (skill may not have written output). Every file/dir the skill wrote must be listed; orchestrator uses to verify output and locate downstream input.

> **Existence-checked at orchestrator boundary.** Orchestrate-flow Step `b.vii` verifies every listed path with `test -f` (files) or `test -d` (dirs) after schema validation passes. Missing path → halt `artifact_missing`. Closes finding D3-002 (silent-failure path closure). Skill authors: any path you list here MUST exist on disk at handoff emission time, or orchestrator will block the chain. Do not list speculative/future paths.

### Pre-validation: handoff block presence in chat output (orchestrator-side)

Before any schema check, orchestrate-flow Step `b.0` scans the sub-skill's chat output (last assistant message) for a YAML code fence containing a top-level `handoff:` key. Skills emit handoff YAML **inline in chat output** (see "Emission contract" below) — NOT to a file on disk. If no block can be located, OR if multiple conflicting `handoff:` blocks are present → halt `handoff_missing` with `chat_tail_excerpt` field (last 500 chars of sub-skill chat) for diagnosis. Closes finding D3-001 (silent-failure path closure).

**Design note:** the original design used `test -f <path>` against a path convention that no skill implemented. Skills always emit handoff in chat; the file-check would have produced spurious `handoff_missing` halts on every run. Corrected to chat-block detection.

### Emission contract (skill-author rule)

Every skill's `## Handoff emission` section MUST cause the skill to print a YAML code fence as the LAST assistant message it emits before exiting. Example minimal emission:

```
... (skill's regular chat output) ...

\`\`\`yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: 2026-05-25T14:32:00Z
  status: completed
  artifacts: ["<vault>/binding.md"]
  next_action: { suggested_skill: "mega-sdd:generate-units", suggested_args: [], rationale: "..." }
  blockers: []
\`\`\`
```

Skills MAY also write the same YAML to `<vault>/.internal/checkpoints/<ISO8601>-<skill>.handoff.yaml` for replay/audit, but the chat-output emission is the **authoritative source** orchestrator reads.

Skill authors: ensure your `§Handoff emission` step runs even on error paths (best-effort emit with `status: halted` and populated `blockers:` array; do NOT crash before reaching it).

### `next_action:` (REQUIRED)

TYPE: object — `{ suggested_skill: string, suggested_args: array<string>, rationale: string }`. Required even on `status==halted` — must point to the resolution path (e.g., `resolve-oq` for binding conflicts).

**`next_action.confidence` (OPTIONAL)** — TYPE: number in `[0,1]` or `null`. The producer's confidence that the recommended next step is correct. Promotes confidence from a prose/chat string (the iter-33 D5 gap — the convergence loop's hardcoded `≥0.80` was never a typed field) to a **typed, validator-enforced** field: `validate-handoff-yaml.sh` now type-checks it (a present value outside `[0,1]` → `handoff_type_mismatch`). This lays the F4 foundation for confidence-aware orchestration (e.g. demote auto-continue to user-review below a config floor) without the prior free-text-parsing brittleness. Omitting it never fails the handoff.

> **Validator coverage:** `validate-handoff-yaml.sh` now type-checks the CONDITIONAL fields below **when present** (list fields: `blockers`/`checkpoints`/`cycles`; object fields: `metrics`/`constitution`/`pbt`/`mutability`/`scope`/`replay`/`starterkit_context`/`metadata`) in addition to the four required fields. Type-checks are **never required-on-absence** — a handoff that legitimately omits an optional block is not failed; only a PRESENT field of the wrong shape is. This closes the F3/F4 "PARTIAL" gap (the validator previously enforced only the 4 required fields + `artifacts`) without changing the blocking contract for handoffs that omit optional fields.

### `blockers:` (REQUIRED)

TYPE: array\<object\> — empty array when `status==completed`; non-empty per halt-protocol `§blocker envelope` when `status==paused|halted`.

### `metrics:` (OPTIONAL but encouraged)

TYPE: object — skill-specific metric fields (e.g., `duration_ms`, `items_processed`, `items_blocked`). Consult per-skill section for declared metric field names.

### `checkpoints:` (CONDITIONAL — if skill emits resume-capable checkpoints)

TYPE: object — `{ latest_step_id: string, checkpoint_file: string (absolute path), resume_command: string }`. Required when skill ran to a checkpoint boundary and supports `--resume-from`.

### `constitution:` (CONDITIONAL — if vault has constitution.md)

TYPE: object — `{ constitution_hash: string (sha256), clauses_referenced: array<string> }`. Required when `<vault>/constitution.md` exists.

### `pbt:` (CONDITIONAL — if unit has properties: array)

TYPE: object — `{ properties_validated: int, properties_failed: int }`. Required when property-based tests ran during this phase.

### `mutability:` (CONDITIONAL — if skill processes mutability-tier claims)

TYPE: object — `{ tier_distribution: { LOCKED: int, INTENT: int, ARTIFACT: int }, locked_claims_touched: array<string>, artifact_discards_proposed: int }`. Required when skill processed claims with mutability tier metadata.

### `scope:` (CONDITIONAL — if vault has scope_metadata)

TYPE: object — `{ id: string, name: string, sibling_scopes: array<string>, prd_sha256: string }`. Required when `vault.json` has `scope_metadata` key.

### `cycles:` (CONDITIONAL — if convergence loop ran)

TYPE: object — `{ cycle_count: int, halts_auto_resolved: array<string>, halts_escalated_to_user: array<string> }`. Required when orchestrator ran ≥1 convergence cycle.

### `replay:` (CONDITIONAL — if replay capture active)

TYPE: object — `{ snapshot_path: string (absolute path), divergence_classification: enum (clean | minor | high | n/a) }`. Required when replay capture was active for this run.

### `metadata:` (OPTIONAL — memory layer integration; when active)

TYPE: object — `{ memory_context: object, memory_writes: array<object> }`. Optional — memory layer off (`--memory-off`) omits this block entirely.

### `model_tiers:` (CONDITIONAL — if orchestrate-flow resolved overrides)

TYPE: object {
  `<role-name>`: enum (haiku | sonnet | opus)
}

Nested under `metadata:`. Resolved model tier per named subagent role. Sub-skills consult this block before each subagent dispatch; absent role-name → use catalog default per `plugins/mega-sdd/references/model-tiers.md` §Catalog.

Condition: present when orchestrate-flow Step 2.8 ran.

Companion field: `metadata.model_tier_sources:` (OPTIONAL) — same keys; values are the override source for each tier (`catalog` | `user` | `project` | `cli`) for debugging.

TYPE (companion): object {
  `<role-name>`: enum (catalog | user | project | cli)
}

### `starterkit_context:` (CONDITIONAL — if scan-codebase deep-scan ran successfully)

TYPE: object (see `plugins/mega-sdd/references/starterkit-context-schema.md` for full structure). Required when scan-codebase deep-scan stage ran successfully and a framework was detected with confidence ≥ MEDIUM.

Optional block carrying starterkit detection results forward through the chain.

**Producer:** scan-codebase deep-scan stage emits this block when a framework is detected with confidence ≥ MEDIUM AND `starterkit-context.yaml` was written.

**Propagation:** orchestrate-flow passes this block to all downstream skills (generate-intent, bind-codebase, generate-units, execute-bolts) without modification.

**Schema:**

```yaml
starterkit_context:
  reused: <bool>                  # true if cache hit (no subagent dispatch); false if fresh scan
  framework: <string>             # e.g., laravel
  auth_lib: <enum>                # mirrors §auth.lib in starterkit-context.yaml
  authz_lib: <enum>               # mirrors §authz.lib
  ui_stack: <string>              # short-form summary, e.g., "alpine + tailwind + sweetalert2"
  libs_count: <int>               # total libs detected in §libs
```

**Consumer-side annotations:** generate-units and execute-bolts MAY append their own metrics under this block (see per-skill examples).

**Canonical source of truth for full structure:** `plugins/mega-sdd/references/starterkit-context-schema.md`

**Type-check enforceability:** fields with explicit `TYPE:` annotations above are validated at Step 6.b.i. Fields without a `TYPE:` annotation bypass type check (warn-only log). covers all top-level fields + 1 level of nesting (e.g., `mutability.tier_distribution.LOCKED`). Deeper nesting deferred to +.

### Status values

- **`completed`** — skill ran successfully end-to-end. Orchestrator auto-continues to `next_action.suggested_skill` if `--deep` mode active.
- **`paused`** — skill completed its work BUT something downstream needs user attention (e.g., business OQs needing resolution). Chain pauses; user reviews surfaced items; resumes via `/mega-sdd:auto --resume` or `/mega-sdd:orchestrate-flow --deep --resume`.
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
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - /path/to/.mega-sdd/knowledge-base/
    - /path/to/.mega-sdd/knowledge-base/README.md
  next_action:
    suggested_skill: mega-sdd:generate-intent
    suggested_args: ["--kb=.mega-sdd/knowledge-base/", "--auto"]
    rationale: "Knowledge base extracted; generate vault using KB as Mode B brief."
  blockers: []
  metrics:
    items_processed: 35    # MD files written
    items_blocked: 0
  scope:                                  # when target vault will have scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from PRD if available>
  mutability:                             # extract-intelligence is PRIMARY tier producer
    tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
    locked_claims_touched: []
    artifact_discards_proposed: <N>
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
    flows_with_stages: 3   # OPTIONAL (semantic-depth) — count of 04-flows.md flows that carried a `stages:` block verbatim from KB §3a (multi-step workflows preserved, not flattened)
```

Status `paused` when P1 business OQs are produced (downstream still works, but user should triage). Status `halted` on `oq_tech_missing_mode` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` / `oq_scan_missing_query` / `memory_in_use`.

> **Staged-input carry-over invariant (semantic-depth).** `stages:` propagates KB §3a → vault `04-flows.md` → units the SAME way OQ-IDs and constitution clauses do: copied verbatim, never re-derived (see `generate-intent/references/vault-contract.md §stages-propagation`). The `metrics.flows_with_stages` field above is **OPTIONAL** — type-checked-when-present by `validate-handoff-yaml.sh` (it rides the existing `metrics:` object check; an `int` when emitted), **never required-on-absence** (a vault with no staged workflows simply omits it; the O-3/O-4 false-FAIL trap is avoided). The carry-over is checked at the artifact layer: `validate-vault-flow-staging.sh` follows each flow's `_kb_source` back-reference and, on a `vault_flow_staging_drop`, surfaces it as **advisory** via `/mega-sdd:analyze` (v4 Hybrid demoted this from a hard-block — it no longer blocks execute-bolts). The handoff metric is a visibility signal, not a gate.

### `scan-codebase`

```yaml
handoff:
  emitted_by: scan-codebase
  status: completed
  artifacts:
    - /path/to/codebase-map.md
    # conditional (deep-scan ran): starterkit-context.yaml, reuse-index.yaml,
    # .shared-snapshots/codebase-map.snapshot.json — per the operative copy
  next_action:
    # CWD-conditional (mirrors scan-codebase/references/halts-flags-handoff.md — the operative copy):
    #   no vault yet (starterkit-first default)          → mega-sdd:generate-intent --scan=<map> --auto
    #   vault already present                            → mega-sdd:bind-codebase <vault> --auto
    #   sync lane (--changed-only under Mode D)          → mega-sdd:detect-drift --auto
    suggested_skill: mega-sdd:generate-intent
    suggested_args: ["--scan=/path/to/.mega-sdd/codebase/codebase-map.md", "--auto"]
    rationale: "Codebase mapped; starterkit-first — draft the vault scan-aware (bind-codebase next when a vault already exists)."
  starterkit_context:
    reused: false
    framework: laravel
    auth_lib: sanctum
    authz_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
```

Status `halted` on `deep_scan_subagent_all_failed` / `dep_missing` / `memory_in_use`. Status soft-halt (warn-only, chain continues) on `deep_scan_subagent_failed` / `deep_scan_cache_corrupt`.

### `bind-codebase`

```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: <ISO8601>
  status: completed | paused | halted
  artifacts:
    - /path/to/<vault>/binding.md
    - /path/to/<vault>/bound/    # only if no CONFLICTs (canonical nested path per references/paths.md; never the legacy <vault>-bound/ sibling)
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

Status `halted` on `bind_conflict` / `bind_conflict_constitution_violation` / `framework_pack_missing` / `framework_pack_cycle` / `framework_pack_unparseable` / `memory_in_use` (per existing halt-protocol). Tech-OQ recommendations do NOT pause the chain — they are surfaced in binding.md for post-binding review and bind emits `status: completed` (advisory, never block; see `bind-codebase` §2.7).

### `generate-units`

```yaml
handoff:
  emitted_by: generate-units
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - /path/to/<vault>/units/            # canonical nested path (never the legacy <vault>-bound/ sibling)
    - /path/to/<vault>/units/_index.md
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
    authz_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    units_with_starterkit_anchors: 12
    units_with_starterkit_rules: 8
```

Status `halted` on `cycle_detected` / `cross_squad_dep_invalid` / `interface_ref_missing` / `cross_squad_ambiguous` / `cross_module_dep_invalid` / `module_cycle_detected` / `dedup_ambiguous` / `unit_underspecified` / `hard_rule_unparseable` / `starterkit_rule_citation_missing` / `unit_oq_trace_missing` (the Step 12.5.g MOAT-CRITICAL OQ-propagation halt) / `memory_in_use`.

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
    suggested_args: []                     # → ["--scope=<id>"] when the bolt batch ran scope-filtered (vault has scope_metadata): propagate scope so detect-drift inherits it instead of full-scanning (AUDIT L9). Stays [] for a single-scope vault.
    rationale: "All bolts executed; recommend periodic drift check."
  metrics:
    items_processed: 12    # units ACTUALLY executed (committed). MUST be 0 for a
                           # --dry-run/preview or an "all units already done" no-op
                           # re-run — those legitimately produce no bolt artifacts,
                           # and the bolt_artifacts_missing gate keys off this field
                           # (fires only when items_processed > 0 yet no bolts/ dir
                           # is listed). Never report the *would-process* count here.
    items_blocked: 0       # halts
  starterkit_context:
    reused: false
    framework: laravel
    auth_lib: sanctum
    authz_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    bolts_used_starterkit_slice: 11
    slice_avg_size_kb: 1.6
```

Status `halted` on any entry of the canonical bolt-halt enum (owner: `execute-bolts/references/halts-and-handoff.md §Handoff emission` — this block is regenerated from it): `test_fail` / `hard_rule_violated` / `hard_rule_unparseable` / `hard_rule_unanchored` / `hard_rule_mixed_grammar` / `verify_unit_writable` / `cross_squad_interface_draft` / `module_blocked_by` / `dep_missing` / `secret_in_code` / `sast_critical_finding` / `dep_not_found` / `review_critical_unresolved` / `pbt_citation_invalid` / `pbt_property_violated` / `batch_suite_red` / `batch_suite_gate_missing` / `postflight_evidence_missing` / `whitelist_violation` / `commit_rejected_by_hook` / `bolt_repeated_partial_failure` / `partial_state_corrupt` / `dispatch_prompt_too_large` / `bolt_introduces_locked_drift` / `scope_creep_detected` / `provenance_missing` / `self_assessment_missing` / `bolt_artifacts_missing` / `memory_in_use`.

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
scope:                                  # when vault has scope_metadata
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

Status `halted` on: `diff_conflict` / `memory_in_use`

### `emit-agents-md`

Canonical handoff YAML:

```yaml
emitted_by: emit-agents-md
emitted_at: <ISO8601>
status: completed | halted
artifacts:
  - <abs path to <project>/AGENTS.md (created or updated)>
scope:                                  # when vault has scope_metadata
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

Status `halted` on: `user_authored_conflict | vault_not_found | vault_corrupt | greenfield_no_bind_context | memory_in_use`

### `resolve-oq`

Canonical handoff YAML:

```yaml
emitted_by: resolve-oq
emitted_at: <ISO8601>
status: completed | paused | halted
artifacts:
  - <abs path to <vault>/01-overview.md (updated)>
  # ... (any vault file that had OQs resolved)
scope:                                  # when vault has scope_metadata
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

Status `halted` on: malformed vault | cycle protection in --binding mode | `memory_in_use`

### `detect-drift`

Canonical handoff YAML:

```yaml
emitted_by: detect-drift
emitted_at: <ISO8601>
status: completed | halted
artifacts:
  - <abs path to <vault>/DRIFT-REPORT.md>
scope:                                  # when vault has scope_metadata
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

Status `halted` on: `drift_framework_mismatch | constitution_drift_detected | memory_in_use`

### `emit-fsd` (, contract block added per C-001)

Canonical handoff YAML with TYPE annotations:

```yaml
emitted_by: emit-fsd                              # TYPE: string (literal: "emit-fsd")
emitted_at: <ISO8601>                             # TYPE: string (ISO8601)
status: completed | halted                        # TYPE: enum (completed | halted)
artifacts:                                        # TYPE: array<string> (absolute paths)
  - <abs path to <vault>/fsd/FSD.md>              # REQUIRED
  - <abs path to <vault>/fsd/FSD.pdf>             # CONDITIONAL — present when pandoc + LaTeX available; OR FSD.html if LaTeX absent; OR absent if pandoc absent
  - <abs path to <vault>/fsd/.citation-map.json>  # REQUIRED
  - <abs path to <vault>/fsd/FSD.styling.yaml>    # REQUIRED
next_action:
  suggested_skill: null                           # TYPE: string | null (always null — FSD is terminal)
  suggested_args: []                              # TYPE: array<string>
  rationale: "FSD emitted; upload <vault>/fsd/FSD.pdf to Confluence per corporate workflow."   # TYPE: string
blockers: []                                      # TYPE: array<object> — populated on quality_gate_failed
scope:                                            # CONDITIONAL — when vault has scope_metadata
  id: <scope id>                                  # TYPE: string (enum from vault.json scope_metadata.allowed_scopes)
  name: <scope name>                              # TYPE: string
  sibling_scopes: []                              # TYPE: array<string>
  prd_sha256: <sha256>                            # TYPE: string (sha256 hex)
metrics:
  sections_emitted: <int>                         # TYPE: int (≥0, ≤10) — count of FSD sections rendered
  sections_excluded: <int>                        # TYPE: int (≥0, ≤10) — count of FSD sections filtered out via --sections OR include_sections styling
  citations_count: <int>                          # TYPE: int (≥0) — total citations in .citation-map.json
  drift_callouts_count: <int>                     # TYPE: int (≥0) — sections changed since last emit; 0 on first emit
  mode: "pre-dev" | "post-dev"                    # TYPE: enum (pre-dev | post-dev)
  pdf_emitted: <true | false>                     # TYPE: bool
  fallback_format: null | "html" | "markdown"     # TYPE: enum (null | html | markdown) — set when pandoc/LaTeX absent
```

Status `halted` on: `quality_gate_failed` with `subtype: pdf_render_failed` OR `subtype: template_slot_unfilled` (per `vault-contract.md §quality_gate_failed subtypes` closure).

### `install-deps` (, contract block added per C-002)

Canonical handoff YAML with TYPE annotations:

```yaml
emitted_by: install-deps                          # TYPE: string (literal: "install-deps")
emitted_at: <ISO8601>                             # TYPE: string (ISO8601)
status: completed | halted                        # TYPE: enum (completed | halted)
artifacts:                                        # TYPE: array<string>
  - <abs path to <project>/.mega-sdd/memory/install-outcomes.md>   # REQUIRED
next_action:
  suggested_skill: null                           # TYPE: string | null (install is user-explicit; no auto-next)
  suggested_args: []                              # TYPE: array<string>
  rationale: "Deps installed; mega-sdd full-precision mode enabled. Re-run /mega-sdd:install-deps --force-recheck if needed."
blockers: []                                      # TYPE: array<object> — populated on install_failed / pkg_mgr_not_found
metrics:
  tools_audited: <int>                            # TYPE: int (≥0) — count of tools checked in audit pass
  tools_already_present: <int>                    # TYPE: int (≥0) — already installed pre-skill
  tools_installed: <int>                          # TYPE: int (≥0) — successfully installed this run
  tools_failed: <int>                             # TYPE: int (≥0) — install or verify failed
  tools_sudo_pending: <int>                       # TYPE: int (≥0) — requires_sudo (printed but not auto-run)
  detected_os: "macos" | "linux" | "wsl" | "windows-bash" | "unknown"                                # TYPE: enum
  detected_pkg_mgr: "brew" | "apt" | "dnf" | "pacman" | "apk" | "winget" | "scoop" | "choco" | "cargo-fallback" | "none"   # TYPE: enum
```

Status `halted` on: `install_failed` (install command failed OR verify_cmd failed post-install) OR `pkg_mgr_not_found` (no compatible package manager + no fallbacks).

### `execute-bolts` — extension (per C-003)

The `acceptance_test_concerns: []` field added to execute-bolts handoff `metrics:` block but never declared in handoff-contract.md schema. closure adds TYPE annotation:

```yaml
# Append to execute-bolts handoff metrics block (existing block at line ~362):
metrics:
  # ... existing fields (items_processed, items_blocked, bolts_used_starterkit_slice, slice_avg_size_kb) ...
  acceptance_test_concerns:                       # , (declared per C-003)
    - unit: U-007                                 # TYPE: array<object {unit: string, concern: string}>
      concern: "..."                              # Empty array when no bolts flagged concerns. Consumed by orchestrate-flow Step 7 final summary diagnostics surface.
```

Status `halted` enumeration: full list now `test_fail | hard_rule_violated | hard_rule_unparseable | hard_rule_unanchored | hard_rule_mixed_grammar | verify_unit_writable | cross_squad_interface_draft | module_blocked_by | dep_missing | secret_in_code | sast_critical_finding | dep_not_found | review_critical_unresolved | pbt_citation_invalid | pbt_property_violated | batch_suite_red | batch_suite_gate_missing | postflight_evidence_missing | whitelist_violation | commit_rejected_by_hook | bolt_repeated_partial_failure | partial_state_corrupt | dispatch_prompt_too_large | bolt_introduces_locked_drift | scope_creep_detected | provenance_missing | self_assessment_missing | bolt_artifacts_missing | memory_in_use` (canonical owner: `execute-bolts/references/halts-and-handoff.md §Handoff emission`; regenerate here on change — never let the two drift).

---

## Memory layer integration

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

Per the `§metadata` extension in this contract:

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

**Two-level resume — no contradiction with per-skill checkpoints (AUDIT L7).** "No state file" applies to the **chain level** only. There are two distinct, non-conflicting mechanisms at two granularities:

| Level | Granularity | Mechanism | Owner |
|---|---|---|---|
| Chain | *which phase* to resume | CWD / artifact inspection (`routing-rules.md`) — reads NO persisted chain-state file | orchestrate-flow |
| Within a phase | *which sub-step* to resume | the phase skill's own checkpoint cursor (`checkpoint-protocol.md`, `<vault>/.internal/checkpoints/`) via `--resume-from=<step-id>` | the phase skill (e.g. bind-codebase) |

Precedence is unambiguous because the levels never overlap: CWD inspection first selects the phase. If that phase's artifacts already exist (completed), the orchestrator **skips it entirely** and its stale checkpoints are irrelevant. If the phase is incomplete, the orchestrator **re-enters it** and the skill's checkpoint resumes mid-execution from its cursor. A checkpoint never overrides phase selection, and phase selection never reaches into a skill's sub-steps.

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

## Slash-command flag surface

```
/mega-sdd:orchestrate-flow [--from=<phase>] [--to=<phase>] [--dry-run]
  + [--deep]      # NEW: lift 3-skill cap; chain to pipeline-end when state clean
  + [--resume]    # NEW: CWD-driven resume (no persisted state)
```

```
/mega-sdd:auto [input] [--deep|--shallow] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual]
                # NEW — one-shot autonomous pipeline
```
