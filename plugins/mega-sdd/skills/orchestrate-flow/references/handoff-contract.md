# Handoff Contract — Skill → Orchestrator

When mega-sdd skills run under `--auto` (i.e., dispatched by `orchestrate-flow --deep` or `/mega-sdd`), they MUST emit a structured **handoff record** at the end of their chat output. The orchestrator parses this record to decide whether to auto-continue the chain, pause on blocker, or stop.

This contract is required ONLY when `--auto` is in effect. Standalone skill invocations (the user asked for one skill by phrase, outside a chain) MAY emit the YAML but it is informational — no orchestrator consumes it.

> **Precedence (anti-drift rule):** each skill's OWN handoff reference (e.g. `scan-codebase/references/halts-flags-handoff.md`, `execute-bolts/references/halts-and-handoff.md`) is the OPERATIVE emission spec — it loads with the emitting skill at runtime. The per-skill blocks below are a cross-skill INDEX for the orchestrator/consumer side; when they disagree with a skill's own reference, the skill's reference wins and the block here is the bug. Top-level field names/types in §Handoff YAML schema remain binding for everyone (the validator enforces those).

---

## Contents

- [Handoff YAML schema](#handoff-yaml-schema)
- [Field-level schema annotations](#field-level-schema-annotations)
- [Per-skill expected emissions](#per-skill-expected-emissions)
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
  blockers: []                          # non-empty (>=1 entry) REQUIRED when status=halted per halt-protocol §blocker envelope
                                        # (validate-handoff-yaml.sh FAILs invalid_handoff on an empty/absent envelope on a halt);
                                        # MAY be empty on status=completed or status=paused
  metrics:                              # optional but encouraged
    duration_ms: <int>
    items_processed: <int>              # OQs / claims / units / etc — context-dependent
    items_blocked: <int>                # number that require human input
  checkpoints:                          # checkpoint protocol; optional
    latest_step_id: <string>            # e.g., "claim-45" for bind-codebase, "wave-3" for extract-intelligence
    checkpoint_file: <absolute-path>    # <vault>/.internal/checkpoints/<timestamp>-<skill>-<step>.jsonl (canonical per paths.md)
    resume_command: <string>            # e.g., "bind-codebase --resume-from=claim-46"
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
    halts_auto_resolved: []             # halt types resolved via grounded recommendations
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
  metadata:                             # optional; carries resolved model tiers when present
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

TYPE: string — must match one of the values in `plugins/mega-sdd/references/halt-protocol.md §halt-protocol source_skill` enum (e.g., `generate-intent`, `bind-codebase`). Identifies the producing skill.

### `emitted_at:` (REQUIRED)

TYPE: string — ISO8601 timestamp. Identifies when the handoff was emitted. Required even if orchestrator never uses it for routing; presence confirms skill ran to handoff-emit step.

### `status:` (REQUIRED)

TYPE: enum — one of `completed | paused | halted`. Drives orchestrator control-flow decision (auto-continue / surface-items / surface-blocker).

### `artifacts:` (REQUIRED)

TYPE: array\<string\> — absolute file paths. Non-empty when `status==completed`; may be empty when `status==halted` (skill may not have written output). Every file/dir the skill wrote must be listed; orchestrator uses to verify output and locate downstream input.

> **Existence-checked at orchestrator boundary.** The per-hop gate (`validate-handoff-yaml.sh`) existence-checks every listed path (`os.path.exists` — file or dir) after schema validation passes. Missing path → halt `artifact_missing`. Closes finding D3-002 (silent-failure path closure). Skill authors: any path you list here MUST exist on disk at handoff emission time, or orchestrator will block the chain. Do not list speculative/future paths.

### Pre-validation: handoff block presence in chat output (orchestrator-side)

Before any schema check, the per-hop gate (`validate-handoff-yaml.sh` per `handoff-consumption.md §b.script`) scans the sub-skill's chat output (last assistant message) for a `handoff:` block (fenced yaml or inline). Skills emit handoff YAML **inline in chat output** (see "Emission contract" below) — NOT to a file on disk. No block, OR multiple blocks with CONFLICTING `emitted_by` values → FAIL `handoff_missing` with a 300-char `response_tail` for diagnosis (same-emitter duplicates validate the LAST block — the producer's own emission). Closes finding D3-001 (silent-failure path closure).

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

> **Validator coverage:** `validate-handoff-yaml.sh` now type-checks the CONDITIONAL fields below **when present** (list fields: `blockers`; object fields: `metrics`/`constitution`/`pbt`/`mutability`/`scope`/`replay`/`checkpoints`/`cycles`/`starterkit_context`/`metadata`) in addition to the four required fields. Type-checks are **never required-on-absence** — a handoff that legitimately omits an optional block is not failed; only a PRESENT field of the wrong shape is. This closes the F3/F4 "PARTIAL" gap (the validator previously enforced only the 4 required fields + `artifacts`) without changing the blocking contract for handoffs that omit optional fields.

### `blockers:` (REQUIRED)

TYPE: array\<object\> — non-empty per halt-protocol `§blocker envelope` when `status==halted` (`validate-handoff-yaml.sh` FAILs `invalid_handoff` on an empty/absent blocker envelope on a halt). MAY be empty when `status==completed` or `status==paused` — a paused skill legitimately carries `blockers: []` and surfaces triage via `metrics.items_blocked` (e.g. generate-intent's P1-OQ pause; per §Precedence :7 the skill's own reference is operative). This narrows :40/:163 to agree with `§Status values` :249, the halted-specific source.

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

### `metadata:` (OPTIONAL)

TYPE: object — carries `model_tiers:` (below) when orchestrate-flow resolved overrides. (v7.3.0: the memory_context / memory_writes fields are REMOVED with the memory lane; a handoff carrying them from an older producer is ignored, never validated against.)

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
- **`paused`** — skill completed its work BUT something downstream needs user attention (e.g., business OQs needing resolution). Chain pauses; user reviews surfaced items; resumes via `/mega-sdd --resume` or `/mega-sdd --deep --resume`.
- **`halted`** — hard blocker fired (CONFLICT, hard_rule_violated, dedup_ambiguous, etc.). `blockers` populated with one or more entries per halt-protocol. Chain stops. User resolves manually.

### Block of artifacts

Every skill MUST list its primary output paths (absolute). `orchestrate-flow` uses these to:
- Verify the skill actually produced output (sanity check before continuing)
- Locate the next skill's input (e.g., `bind-codebase` needs the vault path from `generate-intent`'s artifact list)
- Generate the final pipeline summary at chain end

---

## Per-skill expected emissions

A compact consumer-side ROUTING INDEX — one row per producer. Per §Precedence above, each skill's OWN handoff reference (last column) is the OPERATIVE emission spec (full YAML template, metrics fields, conditional blocks, examples); producers emit per their local template — this file owns only the base schema (§Handoff YAML schema + §Field-level schema annotations) and this routing index.

| Producer | Statuses (halt enum) | `next_action` routing — conditional branches | Operative emission spec |
|---|---|---|---|
| `extract-intelligence` | completed \| halted (a module's quality gate fails twice per `prd-kontrak-template.md` §Per-module quality gate) | → `mega-sdd:generate-intent --kb=<kb> --auto` | `extract-intelligence/references/handoff.md` |
| `generate-intent` | completed \| paused (P1 business OQs — user triage; downstream still works) \| halted (`oq_tech_missing_mode` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` / `oq_scan_missing_query` / `memory_in_use`) | CWD-conditional on codebase-map presence (routing-rules.md :53/:55): brownfield + codebase-map PRESENT → `mega-sdd:bind-codebase` (the norm under the scan-first reorder); brownfield + NO codebase-map on disk yet → `mega-sdd:scan-codebase`; greenfield → `mega-sdd:generate-units` | `generate-intent/references/auto-and-handoff.md` |
| `scan-codebase` | completed \| halted (`deep_scan_subagent_all_failed` / `dep_missing` / `memory_in_use`); soft-halt warn-only, chain continues (`deep_scan_subagent_failed` / `deep_scan_cache_corrupt`) | CWD-conditional: no vault yet → `mega-sdd:generate-intent --scan=<map> --auto` (starterkit-first — draft the vault scan-aware); vault already present → `mega-sdd:bind-codebase <vault> --auto`; sync lane (`--changed-only` under Mode D), incremental ran → `mega-sdd:detect-drift --vault=<vault> --scope=@<vault>/.sync-changed-paths.txt --auto`; sync-lane full-scan fallback → SKIP detect-drift, hand off mega-sdd:bind-codebase `<vault> --auto` (no changed set to scope; continue Mode D straight to a FULL re-bind per §3.8(b)(1) — a scope-less detect-drift null-terminates the chain before the re-bind) | `scan-codebase/references/halts-flags-handoff.md` |
| `bind-codebase` | completed \| paused \| halted (`bind_conflict` / `bind_conflict_constitution_violation` / `framework_pack_missing` / `framework_pack_cycle` / `framework_pack_unparseable` / `memory_in_use`); tech-OQ recommendations are advisory — surfaced in binding.md, status stays `completed` (bind-codebase §2.7) | completed → `mega-sdd:generate-units` — args STATE-based on what this bind actually did, not the `--paths` flag: `["--auto"]` on a full re-bind (incl. a `--paths` run that fell back per binding-contract.md "Fallback to full re-bind"); `["--reconcile", "--auto"]` ONLY when a claim-scoped re-bind actually executed (S4 living-vault sync lane §3.3/§3.6) so generate-units reconciles in place; halted on conflict → `mega-sdd:resolve-oq` (args unchanged) | `bind-codebase/references/auto-memory-handoff.md` |
| `generate-units` | completed \| halted (`cycle_detected` / `cross_squad_dep_invalid` / `interface_ref_missing` / `cross_squad_ambiguous` / `cross_module_dep_invalid` / `module_cycle_detected` / `dedup_ambiguous` / `unit_underspecified` / `hard_rule_unparseable` / `starterkit_rule_citation_missing` / `unit_oq_trace_missing`) | → `mega-sdd:execute-bolts --all --parallel --auto` (wave layering from the chain's analyze-parallelism JSON when in context; the overlap rail stays with the dispatcher) | `generate-units/references/auto-and-memory.md` |
| `execute-bolts` | completed \| halted (any entry of the canonical bolt-halt enum — single owner, see pointer below) | → `mega-sdd:detect-drift` (never terminal — the DEFAULT-ON drift auto-gate); `suggested_args: ["--scope=<id>"]` when the batch ran scope-filtered so detect-drift inherits it (AUDIT L9), else `[]`; phase advance is an informational `next_action.hint`, never a `suggested_skill`; `metrics.acceptance_test_concerns` (array of `{unit, concern}`; empty when none) is consumed by the chain-end summary diagnostics (`chain-execution.md`) | `execute-bolts/references/halts-and-handoff.md` |
| `diff-vault` | completed \| paused \| halted (`diff_conflict` / `memory_in_use` / `delta_too_large`) | clean apply → `mega-sdd:orchestrate-flow` (re-inspects CWD + re-plans; subsumes the brownfield re-bind hop and is the only valid hop for a greenfield vault; a from-prompt apply's `.delta-changed-paths.txt` is picked up by the router's §Delta lane row there); halted `delta_too_large` → `mega-sdd:orchestrate-flow` re-plan after the user's full_lane/split_ticket/cancel choice; completed + new `[ ]` OQ rows materialized (`OQ-{CODE}-{N+1}`) → `mega-sdd:resolve-oq` (its `[ ]`-walk can consume them); halted `diff_conflict` → re-invoke `mega-sdd:diff-vault` WITHOUT `--auto` (interactive Step 5) — NEVER resolve-oq, which cannot read a `VAULT-DIFF.md` conflict (its OQ is `[x]` resolved and lives only in `VAULT-DIFF.md`; per §Anti-halu invariants a halted `next_action` must point at the true resolution path) | `diff-vault/references/auto-and-chain.md` |
| `resolve-oq` | completed \| paused \| halted (malformed vault / cycle protection in `--binding` mode / `memory_in_use`) | `--binding` action-mix (binding-mode.md Step 5): any KEEP_CODE or SPLIT → `mega-sdd:bind-codebase` (re-bind is clean); ONLY KEEP_VAULT/DEFER → `mega-sdd:generate-units` (a blanket re-bind would loop the same CONFLICT); intent mode → `mega-sdd:orchestrate-flow` (resume chain) | `resolve-oq/references/auto-memory-handoff.md` |
| `detect-drift` | completed \| halted (`drift_framework_mismatch` / `constitution_drift_detected` / `memory_in_use`) | sync lane (SCOPE_DIRS resolved from `--scope=@<vault>/.sync-changed-paths.txt`, passed by orchestrate-flow --sync) → `mega-sdd:bind-codebase --paths=@<vault>/.sync-changed-paths.txt --auto` (CONTINUE Mode D → claim-scoped re-bind §3.3/§3.8); standalone / post-bolt auto-gate (drift-axis `--scope`, bare `--scope=<id>`, or no scope) → `next_action: null` (DRIFT-REPORT.md + PENDING-SYNC.md ARE the deliverable; the severity→action map governs the post-bolt gate); NEVER `resolve-oq` — it has no drift-consumption mode (a drift-CREATED OQ-DC-N stub resolves in resolve-oq's ordinary intent mode) | `detect-drift/references/auto-and-chain.md` |
| `emit-fsd` | completed \| halted (`quality_gate_failed`, subtype `pdf_render_failed` / `template_slot_unfilled`) | terminal — `suggested_skill: null` | local copy in `emit-fsd/SKILL.md` §Handoff emission |
| `install-deps` | completed \| halted (`install_failed` / `pkg_mgr_not_found`) | terminal — `suggested_skill: null` (user-explicit; no auto-next) | local copy in `install-deps/SKILL.md` §Handoff emission |
| `emit-agents-md` | completed \| halted (`user_authored_conflict` / `vault_not_found` / `vault_corrupt` / `greenfield_no_bind_context`) | `type: chain_complete` — AGENTS.md is the pipeline terminal output | local copy in `emit-agents-md/SKILL.md` §Handoff emission |

**Canonical bolt-halt enum (single owner).** The 29-entry execute-bolts halt enum lives ONLY in `execute-bolts/references/halts-and-handoff.md §Handoff emission` (`halt-taxonomy.md` classifies every entry into always-stop / cycle-eligible / soft). This index deliberately carries NO copy — consult the owner; with a single home, copy-drift is impossible by construction.

---

## Orchestrator consumption logic

The operative control loop (incl. the confidence-aware auto-continue floor) lives ONCE in `references/handoff-consumption.md §Orchestrator consumption loop` — the duplicate copy that used to sit here is gone (M-04); this section keeps only the pieces that are NOT in the consumption reference:

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

`/mega-sdd --resume` does NOT read a persisted state file. It re-runs CWD inspection per `routing-rules.md`, proposes the same chain, and:
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
/mega-sdd [--from=<phase>] [--to=<phase>] [--dry-run]
  + [--deep]      # NEW: lift 3-skill cap; chain to pipeline-end when state clean
  + [--resume]    # NEW: CWD-driven resume (no persisted state)
```

```
/mega-sdd [input] [--deep|--shallow] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual]
                # NEW — one-shot autonomous pipeline. --step-after/--stop-after are FRONT-DOOR
                # aliases rendered to --to= before dispatch (commands/mega-sdd.md §Flag handling);
                # orchestrate-flow itself accepts only --to.
```
