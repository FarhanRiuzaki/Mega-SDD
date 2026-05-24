---
name: orchestrate-flow
version: 3.2.0
description: Multi-skill lifecycle orchestrator for mega-sdd. Inspects CWD, proposes a chain of sub-skills (extract-intelligence / generate-intent / scan-codebase / bind-codebase / generate-units / execute-bolts / resolve-oq / detect-drift / diff-vault), confirms once, then executes the chain in --auto mode. (v1.3+, Iter 4) `--deep` flag lifts 3-skill cap and chains to pipeline-end with auto-continue via handoff YAML protocol; `--resume` resumes a paused chain from CWD state (no persisted state file). Triggers — "orchestrate", "run flow", "auto mega-sdd", "do the next thing", "what's next", or paraphrases.
---

# Orchestrate-Flow — Lifecycle Orchestrator

**Announce at start:** "I'm using the orchestrate-flow skill to inspect CWD and propose the next phases."

## When to use

- "run the flow" / "auto mega-sdd" / "do the next thing"
- "what's next" / "orchestrate"
- After completing one phase, user wants automatic transition

## Procedure

1. **Parse args.** Persist `WORK_DIR`, optional `--from=<phase>`, `--to=<phase>`, optional `--deep` (v1.3+), optional `--resume` (v1.3+).

2. **Deterministic CWD inspection** per `references/routing-rules.md` §CWD inspection. Output a state snapshot:
   ```
   prd: present | absent
   vault: present | absent (path: ...)
   bound_vault: present | absent
   units: N
   bolts: N
   codebase_map: present | absent
   knowledge_base: present | absent (path: ...)  # (v2.3.1+ Iter 21) priority order: .mega-sdd/knowledge-base → docs/knowledge-base → docs/mega-sdd/knowledge-base → old-reference/knowledge-base
   git_repo: yes | no
   oq_p0_p1_count: N
   mode_inferred: greenfield | brownfield | legacy-rebuild
   squad_count: N  # (v1.1+) from <vault>/_meta/squads.yaml; 0 if file absent or single squad
   interfaces_count: N  # (v1.1+) count of files in <vault>/interfaces/ (excluding _index.md); 0 if folder absent
   starterkit: detected | absent  # (v2.4+ Iter 27) framework manifest probe
     framework: <name|null>       # e.g., laravel-base-26 (pack match), laravel (universal), null (no manifest)
     pack_match: yes | no         # yes if framework-conventions/<framework>.md exists; no if universal fallback
     manifest_path: <path|null>   # e.g., composer.json, package.json, Gemfile, pyproject.toml, go.mod, Cargo.toml
   ```

2.5. **Starterkit detection + mode classification (v2.4+, Iter 27).**

   Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield": starterkit is REQUIRED by default; greenfield only when user opts in explicitly.

   Three modes determined by inspection:

   | Mode | Trigger | Pipeline ordering |
   |---|---|---|
   | **A — Starterkit-first** (DEFAULT) | `starterkit: detected` + `pack_match: yes` | scan-codebase FIRST (loads pack into context) → generate-intent (pack-aware vault) → bind → units → bolts |
   | **B — Framework-detected** (universal fallback) | `starterkit: detected` + `pack_match: no` | scan-codebase FIRST (universal conventions from `_universal.md`) → generate-intent → bind → units → bolts |
   | **C — Greenfield (EXPLICIT)** | `--greenfield` flag OR (cwd empty/.git-only AND user confirms via halt) | generate-intent (stack-agnostic) → user scaffolds later → re-run with scan to bind |

   **Default behavior** when starterkit absent AND `--greenfield` NOT set → halt with `no_starterkit_detected`:

   ```yaml
   halt:
     type: no_starterkit_detected
     reason: "Mega-sdd default workflow requires a framework starterkit (composer.json / package.json / Gemfile / etc.) for delivery-grade output. Vault generation produces stack-agnostic designs without it."
     options:
       a: "Scaffold a starterkit first (recommended). For Laravel: clone base-laravel-26. For Django: django-admin startproject. For Rails: rails new. Then re-run."
       b: "Proceed as greenfield with --greenfield flag (vault stays stack-agnostic; you scaffold + re-run scan/bind later)"
       c: "Cancel"
   ```

   **Legacy rebuild scenario** (extract-intelligence + scan-on-target):
   ```
   extract-intelligence <legacy> → KB
     ↓
   scan-codebase (TARGET — new framework scaffold) → codebase-map.md
     ↓
   generate-intent --kb=<kb> --scan=<codebase-map> → vault aware of BOTH legacy domain AND target scaffold conventions
     ↓ bind → units → bolts
   ```

   **Memory hint**: user's last starterkit preference saved to `~/.mega-sdd/memory/preferences.md` `last_used_starterkit:` — next legacy-rebuild prompts "Last 3 projects used `laravel-base-26`. Use same starterkit?" Y/N/other.

2.7. **Memory-informed routing preflight (v3.0.0+, Iter 33).**

   Per `references/memory/routing-outcomes.md` schema. Optional — falls through silently if memory file absent or insufficient history.

   a. Compute project fingerprint: `sha256(composer.json + package.json + framework_pack_path)[:16]`

   b. Read `<project>/.mega-sdd/memory/routing-outcomes.md` (if exists; else skip to step 3).

   c. Filter rows matching current fingerprint.

   d. Apply decision rules:
      - **≥3 prior rows, converged=yes, same chain-used:** recommend that chain as default; LOG to user: "Routing recommendation from past N runs (all converged in avg X min)"
      - **≥2 prior rows, converged=no, same chain-used:** WARN user: "Past N runs of this chain failed (halts: <list>); consider alternate chain"; fall through to routing-rules.md default (user decides)
      - **Mixed results OR <3 prior rows:** fall through to routing-rules.md default (no override)

   e. If file parse fails: emit SOFT halt `routing_outcome_corrupt` + auto-invalidate (rename to `.corrupt-<ISO8601>`); fall through to default; LOG to user: "routing-outcomes.md corrupt; auto-invalidated; chain proceeds with default routing"

   f. Update chain proposal with recommendation OR fall-through default. Continue to Step 3.

2.8. **Model-tier override resolution (v3.1.0+, Iter 34).**

Per `references/model-tiers.md` override syntax. Resolves model tier per named subagent role from override chain. Default-on; no flag needed to invoke.

a. **Read CLI flags from invocation**: collect all `--model-tier=<role>:<tier>` flags into a dict `cli_overrides`.

b. **Read `<project>/.mega-sdd/config.yaml`**: parse `model_tiers:` section if present; build `project_overrides` dict.

c. **Read `~/.mega-sdd/memory/preferences.md` `## Model tiers` section**: build `user_overrides` dict.

d. **Compute final resolved tier per role** (override chain precedence: CLI > project > user > catalog):
   - For each role mentioned in any override source:
     - If role in cli_overrides → use cli value
     - Else if role in project_overrides → use project value
     - Else if role in user_overrides → use user value
     - Else → use catalog default (read from `plugins/mega-sdd/references/model-tiers.md` §Catalog)

e. **Emit final `model_tiers:` dict in handoff metadata** for all downstream skills:
   ```yaml
   metadata:
     model_tiers:
       auth-extractor: sonnet
       rbac-extractor: sonnet
       code-quality-reviewer: sonnet  # override applied — was opus in catalog
       # ... (all 17 roles or subset that's in overrides)
     model_tier_sources:  # provenance trail for debugging (OPTIONAL)
       auth-extractor: catalog
       code-quality-reviewer: project-config
   ```

f. **Forward-compat tolerance**: if any role mentioned in override sources doesn't exist in catalog → emit SOFT halt `model_tier_unknown` (warn-only); log warning; ignore that override; chain proceeds with catalog default for unknown roles.

   ```yaml
   # Example model_tier_unknown envelope:
   type: model_tier_unknown
   source_skill: orchestrate-flow
   details:
     unknown_role: "some-future-role"
     override_source: "project-config"
     override_file: "<project>/.mega-sdd/config.yaml:line-N"
   next_action:
     type: log_and_continue
     hint: "Role 'some-future-role' not found in references/model-tiers.md catalog. Override ignored. Either remove from override OR add the role to the catalog if it's a real subagent role."
   ```

g. **Logging**: log resolved tier summary to chain output for user audit, e.g.:
   `Model tier overrides applied: code-quality-reviewer=sonnet (project-config); audit-probe=sonnet (cli-flag)`

h. **No file writes** — Step 2.8 is purely resolution; resolved tiers live in handoff metadata only.

3. **Build proposed chain** per `references/routing-rules.md` §Decision matrix.
   - Default mode (no `--deep`): hard cap 3 sub-skills (legacy behavior, backward-compatible).
   - **`--deep` mode (v1.3+)**: cap LIFTED — chain extends to pipeline-end per `references/routing-rules.md` §Deep-chain decision matrix. Auto-continue between phases via handoff YAML protocol (see `references/handoff-contract.md`).

3.5. **Predictive preflight (v3.0.0+, Iter 33, generalizes Step 4 first-run pre-flight).**

Per `references/predictive-checks.md` catalog. Runs BEFORE invoking any skill in proposed chain.

a. For each skill in proposed chain (in order):
   - Read `references/predictive-checks.md` §<skill> preflight checks section
   - For each check entry: run `command`; verify against `expected`
   - On match → pass; continue
   - On mismatch:
     - If `fatal: no` → accumulate warning; will surface to user before chain start
     - If `fatal: yes` → emit halt `predictive_check_failed` with check_id + skill in details; STOP chain (do NOT invoke any skill)

b. After all skills checked:
   - If ≥1 warning accumulated → display warnings to user via single message before chain start (e.g., "⚠️ tree-sitter not installed; chain will use regex engine")
   - If chain halted with `predictive_check_failed` → output halt YAML envelope + exit (no Step 4 / Step 5 / Step 6)

c. Wall-clock budget: ≤2 sec total (lightweight bash checks only); if budget exceeded → log warning + proceed (graceful degradation)

d. **Step 4 special case (preserved for back-compat):** existing Step 4 "First-run pre-flight (only if chain includes execute-bolts)" continues to run AFTER Step 3.5 — it covers execute-bolts-specific behaviors that the generic catalog doesn't capture. Future iters MAY fold Step 4 entirely into predictive-checks.md catalog; not in scope for Iter 33.

```yaml
# Example predictive_check_failed envelope:
type: predictive_check_failed
source_skill: orchestrate-flow
details:
  failing_check_id: tree_sitter_present
  failing_skill: scan-codebase
  command_run: "command -v tree-sitter || command -v tree-sitter-cli"
  expected: "exit 0"
  actual: "exit 1 (binary not found)"
next_action:
  type: user_install_dep
  hint: "Install tree-sitter (brew install tree-sitter OR cargo install tree-sitter-cli OR npm install -g tree-sitter-cli) then re-run. Alternatively, run scan-codebase with --engine=regex flag to bypass tree-sitter."
```

4. **First-run pre-flight (only if chain includes execute-bolts):**
   - Check superpowers OR `_vendored/` availability
   - If neither → propose install command, halt chain proposal

5. **Present plan + single `AskUserQuestion`** (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only.

6. **Execute chain.** Dispatch sub-skills with `--auto` flag. Pause on blocker artifacts (any type) per `vault-contract.md` §halt-protocol. `resolve-oq` step is always interactive on per-OQ choices.

   **Chain proposal UX clarity (v1.4+, Iter 9 Bug 4 fix)**: when surfacing the upfront confirmation, include a "Halts may re-engage you" line so users have accurate expectations:

   ```
   Proposed pipeline (--deep):
     1. generate-intent ./prd.md  → vault
     2. scan-codebase             → codebase-map.md
     3. bind-codebase             → binding.md + bound-vault/
     4. generate-units            → units/
     5. execute-bolts --all       → bolts/

   Halts may re-engage you mid-chain (test failures, business OQ
   resolutions, hard-rule violations, dedup ambiguity, recommendation
   reviews). Otherwise runs end-to-end silently with progress indicators.

   [Run] [Edit] [Cancel]
   ```

   User confirmation is ONE-TIME for chain proposal; halts are NOT additional confirmations — they're interventions on real issues.

   Per sub-skill in chain (loop):

   a. **Dispatch sub-skill** with assembled flags + memory slice via `metadata.memory_context`. Pass canonical top-level propagation fields (scope, constitution, mutability, pbt, cycles, replay, starterkit_context) from previous handoff if present.

   b. **Validation gate (v3.0.0+, Iter 33) — validate received handoff against `references/handoff-contract.md` schema annotations:**

      0. **Handoff presence check (v3.2.0+, Iter 40 — silent-failure path closure):**
         After sub-skill exits, orchestrator computes expected handoff path per per-skill emission convention in `handoff-contract.md` (typically `<vault>/.internal/checkpoints/<ISO8601-date>-<skill>.handoff.yaml` OR similar — consult per-skill section).
         - If file does not exist (`test ! -f`) OR size is 0 bytes → emit halt `handoff_missing` with details `{failing_skill, expected_handoff_path, last_known_step: <best-effort from any checkpoint trail or "unknown">}`; STOP chain.
         - Closes Iter 38 audit D3-001. Previously, missing handoff caused orchestrator to either proceed with empty state OR fail downstream with cryptic file-not-found errors; now halts at the exact failing boundary.

         ```yaml
         # Example handoff_missing envelope:
         type: handoff_missing
         source_skill: orchestrate-flow
         details:
           failing_skill: bind-codebase
           expected_handoff_path: "<vault>/.internal/checkpoints/2026-05-25-bind-codebase.handoff.yaml"
           last_known_step: "Step 7 (binding entries written)"
         next_action:
           type: inspect_subskill_logs
           hint: "Sub-skill `bind-codebase` exited without emitting handoff YAML. Inspect chat output for crash logs OR re-run `/mega-sdd:bind-codebase` standalone to reproduce. Likely cause: skill crashed before §Handoff emission step OR file write failed (disk full / permissions)."
         ```

      i. **Type-check fields against handoff-contract.md TYPE annotations (v3.0.0+, Iter 33 F4):**
         For each field present in handoff YAML:
         - Lookup TYPE annotation in handoff-contract.md §<field-name> section
         - If TYPE annotation absent → log warn-only ("field <name> has no TYPE in schema; skipping type check"); continue
         - If TYPE annotation present → validate value matches TYPE:
           - `string` → value is string (not int/array/object)
           - `int` → value is integer; respect `(≥N)` constraint if present
           - `enum (a | b | c)` → value is in allowed list
           - `array<T>` → value is array AND each element matches T
           - `object {...}` → value is object AND each declared sub-field matches its TYPE
           - `string (sha256 hex)` → value is 64-char hex string
           - `string (ISO8601)` → value matches ISO8601 pattern
         - On type mismatch → emit halt `handoff_type_mismatch` with details {failing_skill, field_name, expected_type, actual_type, actual_value (truncated to 100 chars)}; STOP chain.

      ```yaml
      # Example handoff_type_mismatch envelope:
      type: handoff_type_mismatch
      source_skill: orchestrate-flow
      details:
        failing_skill: bind-codebase
        field_name: "scope.id"
        expected_type: "string (enum from vault.json scope_metadata.allowed_scopes)"
        actual_type: "object"
        actual_value: "{ id: 'BE', name: 'Backend' }"
      next_action:
        type: edit_skill_template
        hint: "Field scope.id should be a string (enum value), not an object. Edit bind-codebase handoff template to emit scope.id as 'BE' string directly. Likely cause: handoff template emitted the entire scope object as scope.id by mistake. (Possible upstream: vault.json shape changed; verify scope_metadata schema.)"
      ```

      ii. Parse handoff YAML; if YAML parse fails → emit halt `invalid_handoff` with details `{failing_skill, parse_error}`; STOP chain.

      iii. For each field declared `(REQUIRED)` in handoff-contract.md schema:
           - If field absent in handoff YAML → emit halt `invalid_handoff` with details `{failing_skill, missing_field, severity: REQUIRED}`; STOP chain.

      iv. For each field declared `(CONDITIONAL — <condition>)`:
           - Evaluate condition against orchestrator's known runtime state at chain-start (e.g., "if vault has scope_metadata" → check vault.json `scope_metadata` key read during chain-start CWD inspection).
           - If condition met AND field absent → emit halt `invalid_handoff` with details `{failing_skill, missing_field, severity: CONDITIONAL, condition_evaluated: <result>}`; STOP chain.
           - If condition NOT met → field absence OK; continue.

      v. For each field declared `(OPTIONAL)`:
           - Field absence OK; log presence/absence for telemetry only.

      vi. If all schema validation passes → proceed to step vii.

      vii. **Artifact existence check (v3.2.0+, Iter 40 — silent-failure path closure):**
         Iterate the `artifacts: [paths]` array from the validated handoff. For each path:
         - If absolute file path: verify `test -f <path>` returns 0.
         - If absolute directory path: verify `test -d <path>` returns 0.
         - If relative path: log warn-only ("artifact path is relative; cannot existence-check") + continue.
         If ANY listed artifact fails the existence check → emit halt `artifact_missing` with details `{failing_skill, missing_paths: array, present_paths: array, handoff_file: <path>}`; STOP chain.
         Closes Iter 38 audit D3-002. Previously, missing artifacts caused next-stage skill to fail with cryptic "file not found"; now halts at producer boundary with explicit list.

         ```yaml
         # Example artifact_missing envelope:
         type: artifact_missing
         source_skill: orchestrate-flow
         details:
           failing_skill: generate-units
           missing_paths: ["<vault>/units/U-007.md", "<vault>/units/U-008.md"]
           present_paths: ["<vault>/units/U-001.md", "<vault>/units/U-002.md", ..., "<vault>/units/U-006.md"]
           handoff_file: "<vault>/.internal/checkpoints/2026-05-25-generate-units.handoff.yaml"
         next_action:
           type: re_run_producer
           hint: "Producer skill `generate-units` declared 8 unit files in handoff but only wrote 6. Re-run `/mega-sdd:generate-units` standalone to reproduce. Likely cause: skill crashed mid-loop after emitting handoff metadata for all units but only writing some. Inspect chat output."
         ```

      viii. If all checks pass → continue to step c.

   ```yaml
   # Example invalid_handoff envelope (REQUIRED field missing):
   type: invalid_handoff
   source_skill: orchestrate-flow
   details:
     failing_skill: bind-codebase
     missing_field: "scope.id"
     field_severity: CONDITIONAL
     condition_evaluated: "vault has scope_metadata = TRUE"
     handoff_file: "<vault>/.internal/checkpoints/2026-05-24-bind-codebase.handoff.yaml"
   next_action:
     type: edit_skill_template
     hint: "Edit plugins/mega-sdd/skills/bind-codebase/SKILL.md §Handoff emission YAML template to include scope: block per handoff-contract.md schema. After fix, re-run chain. (Phase A1 audit closure should have prevented this — verify your skill body is up to date.)"
   ```

   c. **Propagate handoff metadata** to next skill in chain: pass canonical top-level fields (scope, constitution, mutability, pbt, cycles, replay, starterkit_context) without modification per orchestrator consumption logic. Memory slice for next skill built from updated state.

   d. **Update progress indicator** (v1.3+, per AUTONOMY-OQ-4): before each skill invocation, emit one chat line:
   ```
   ▶ Phase {current} of {total}: invoking {skill} ({args})
   ```
   After each skill completes, emit one summary line:
   ```
   {✓|⏸|⛔} Phase {current} of {total}: {skill} → status: {status}, items: {items_processed}, blocked: {items_blocked}
   ```

   e. **Halt-check**: if `status==halted` → exit loop; proceed to Step 7 (emit final summary with verbatim blocker YAMLs).

   f. **Continue-loop**: if `status==completed` → continue to next sub-skill in chain.

   **Auto-integrated diagnostics (v2.2+, Iter 13)**: per audit `docs/superpowers/audits/2026-05-21-command-sprawl-audit-v3.6.md` consolidation restoring "single command" philosophy. Inside `--deep` chain (OR `--auto` mode), the orchestrator AUTOMATICALLY invokes diagnostic commands at appropriate phases — user does NOT run these separately:

   | Phase | Auto-runs | Output integration |
   |---|---|---|
   | After `generate-units` completes | `lint-units` (per `commands/lint-units.md` Procedure) | One-line chat summary: "lint: N HIGH / M MEDIUM / K LOW grounding; X/Y anchors verified" + halt-on-LOW-strict if `--strict-quality` flag set |
   | Before `execute-bolts` invocation | `analyze-parallelism` (per `commands/analyze-parallelism.md`) | Wave plan computed; passed to execute-bolts to drive `--parallel` batch dispatch |
   | After `execute-bolts` completes | `list-modules` (per `commands/list-modules.md` table format) | Per-module status table in chain end summary |
   | After all phases complete | `emit-agents-md` (per `commands/emit-agents-md.md`, respecting `config.yaml defaults.emit_agents_md: true|false`) | `AGENTS.md` (or `.mega-sdd.md` sibling) written at repo root |
   | After all phases complete | Memory review check (per `commands/memory.md review` if `~/.mega-sdd/memory/patterns.md` has ≥1 pending suggestion) | Surface in chain summary: "N pending learning suggestions → review via `/mega-sdd:memory review`" |

   These diagnostics run TRANSPARENTLY — chat output includes their summaries inline with phase progress lines. User does NOT need to know they exist as separate commands.

   **Manual override**: users invoking individual commands directly (`/mega-sdd:lint-units` etc.) still works for debugging/one-off use. Auto-invocations skip when user explicitly disables via `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags on `auto`/`orchestrate-flow`.

7. **Emit final summary** with completed/paused/skipped per step + verbatim blocker YAMLs if any. In `--deep` mode, append:
   - Total phases proposed, total phases completed, total artifacts produced (flat path list)
   - **(v2.2+, Iter 13) Auto-integrated diagnostics summary**:
     - Quality metrics from auto lint-units (units HIGH/MEDIUM/LOW counts)
     - Parallelism speedup from auto analyze-parallelism (X.Yx vs sequential)
     - Per-module status from auto list-modules (X/Y modules completed)
     - AGENTS.md emission confirmation (file path + section count)
     - Memory review prompt if pending suggestions exist
   - **(v3.0.0+, Iter 33) Predictive preflight metrics:**

   ```yaml
   metrics:
     predictive_warnings_count: <int>     # NEW v3.0.0+: count of non-fatal predictive warnings shown
     predictive_halts_count: <int>        # NEW v3.0.0+: count of fatal predictive halts (always ≤1 since fatal halts STOP)
   ```

   - **(v3.1.1+, Iter 35) Phase context (appended to final summary when vault.json has `phase` field):**

     **Phase context (v3.1.1+, Iter 35):**

     If `vault.json` has `phase` field, append to summary:

     IF `vault.phase < vault.phase_total`:
       "Phase <N> of <M> complete. To start Phase <N+1>: see `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md` §Phase <N+1> OR run `/mega-sdd:generate-intent --kb=<KB> --phase=<N+1>`."

     IF `vault.phase == vault.phase_total`:
       "Phase <N> of <M> complete. All phases finished."

     IF `phase` field absent (single-phase project OR pre-v3.26.0 vault):
       Omit phase context section.

     This complements the execute-bolts handoff `next_action.hint` from Iter 35 — orchestrate-flow surfaces the same info at chain summary level for user visibility.

7.5. **End-of-chain routing-outcomes memory write (v3.0.0+, Iter 33).**

   Per `references/memory/routing-outcomes.md` write protocol.

   a. Compute:
      - `chain-used`: short label, e.g., "starterkit-first (scan→intent→bind→units→bolts)"
      - `duration-min`: integer wall-clock from Step 1 → now
      - `converged`: yes if final status==completed AND blockers==[]; no otherwise
      - `halts-fired`: count of unique halt types fired during chain

   b. Acquire file lock on `<project>/.mega-sdd/memory/routing-outcomes.md` (reuse existing memory file-lock pattern: backoff + retry 3x; fail with `memory_in_use` if all retries fail).

   c. If file does not exist: create with header per schema doc.

   d. Append row to `## Entries` section via Bash `>>` heredoc (per memory-schema.md §6 POSIX append requirement).

   e. Release lock.

   f. LOG to user: "routing-outcomes.md updated (entry: <chain-used> | <duration-min>min | converged=<yes/no>)"

   NOTE: Skip Step 7.5 entirely if `--memory-off` flag set (existing flag respects opt-out).

8. **Resume support (v1.3+, per AUTONOMY-OQ-2 — CWD-driven, no state file).**

   When invoked with `--resume`:
   - Skip the upfront confirmation (chain was already approved last run)
   - Re-run CWD inspection (Step 2) — produces fresh state snapshot
   - Build chain per routing-rules; if state shows certain artifacts already exist (e.g., vault.json present) → skip those phases automatically; cursor lands on the next un-done phase
   - Execute from cursor onward
   - If a previously-halted phase still has its blocker unresolved → halt fires again identically. User MUST resolve blocker BEFORE re-running `--resume`.

## Hard rails

- No content generation by the orchestrator itself.
- No state file (resumption = re-invoke `orchestrate-flow --resume`; CWD inspection rebuilds state).
- No skill runs in parallel.
- Sub-skill substance prompts ALWAYS surface to human.
- Chain depth ≤ 3 by default; `--deep` flag (v1.3+) lifts the cap with auto-continue via handoff YAML.
- (v1.3+) `--deep` mode does NOT relax any halt-condition. Every blocker still fires identically. Auto-continue happens ONLY when skill reports `status: completed` with empty `blockers: []`.

## Greenfield vs Brownfield routing

Per `references/routing-rules.md` §Greenfield vs brownfield detection.

## Mode-migration

If CWD signals say "brownfield" but vault says `mode: greenfield` (or vice versa):
- Halt
- Emit mode-migration prompt — user chooses to update vault or re-detect

**Structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: mode_migrate
  emitted_at: <ISO8601 timestamp>
  emitted_by: orchestrate-flow
  details:
    vault_mode: greenfield | existing  # what vault.json says
    cwd_signals: [.git, package.json, ...]  # what was detected
    resolution: "update vault.mode to match CWD" | "re-detect by moving to clean dir"
  next_action: "Confirm correct mode then re-run /mega-sdd:orchestrate-flow"
```

## Flags

- `--from=<phase>`: resume from a specific phase (skip earlier phases even if state says they're needed)
- `--to=<phase>`: stop at a specific phase (do not chain beyond it)
- `--dry-run`: show proposed chain without executing
- (v1.3+) `--deep`: lift 3-skill cap; chain to pipeline-end via handoff-YAML auto-continue
- (v1.3+) `--resume`: re-enter a paused/halted chain; skip upfront confirmation; CWD inspection rebuilds cursor position; halts re-fire if blockers unresolved
- (v1.4+) `--memory-off`: disable memory layer (no reads, no writes) for this chain
- (v2.0+) Checkpoint protocol auto-emits per-step JSONL files at `<vault>/.internal/checkpoints/` (per `references/checkpoint-protocol.md`); enables mid-skill resume

## Hybrid drift gate phase (v2.5.0+, Iter 30 §6.4 — DEFAULT-ON)

After `execute-bolts --all` batch completes (or with retried halts), orchestrate-flow AUTO-invokes `detect-drift` as gate phase. Per spec §6.4 default-on policy.

### Gate behavior

```
✓ execute-bolts: 20/20 done (or 18/20 + 2 halts resolved via propose-and-confirm)
▶ Phase 5.5/6: detect-drift (auto-gate, hybrid mode — DEFAULT-ON)
  Scope: <scope_id> — scope-filtered scan
  Comparing: bolt postflight snapshots vs vault (shared snapshot machinery per references/shared-snapshot-schema.md)
  Speed: 4s (vs 28s full re-scan; snapshot reuse saves 6x)
  
⚠️ Drift findings: N (X CRITICAL, Y HIGH, Z MEDIUM, W LOW)
```

### Severity → chain action mapping (per Iter 25 + Iter 30)

| Severity | Trigger | Chain action |
|---|---|---|
| CRITICAL | Drift on LOCKED entity (data-mutation-policy.md tier) | HALT chain; user MUST resolve before proceeding |
| HIGH | Drift on CONFIRMED claim with no mutability source OR INTENT outcome change | PAUSE; user can override with audit-significant decision |
| MEDIUM | Drift on INTENT claim implementation change | LOG + continue; surface in batch summary |
| LOW | Drift on ARTIFACT cleanup OR style only | LOG only; no chain interruption |

### Opt-out

- `--no-drift-check` flag in `/mega-sdd:auto` or `execute-bolts` → skip auto-drift gate entirely
- Escape hatch, not default

### On-demand drift (separate from auto-gate)

`/mega-sdd:detect-drift` standalone (no chain context) → behaves as v1.2.x: fresh full scan; ignores bolt snapshots. Auto-gate path uses snapshot reuse per `references/shared-snapshot-schema.md`.

## Convergence loops (v2.3+, Iter 19)

Per user request — formalize iteration cycles antara skills yang sebelumnya manual (`--resume` driven). "Cycling agent" pattern.

### Cycle-eligible halt types

ONLY these halts trigger auto-loop. Other halts ALWAYS stop chain (human-required):

| Halt type | Auto-loop action | Safety condition |
|---|---|---|
| `bind_conflict` | Auto-invoke `resolve-oq --binding` with memory-pre-filled recommendations → re-run `bind-codebase` | Recommendation confidence ≥ 0.80 (per Iter 7); else stop |
| `module_blocked_by` | Auto-run prerequisite module first → resume requested module | All prerequisites identifiable + non-circular |
| `cross_squad_interface_draft` | Wait (with backoff: 30s, 60s, 120s) for producer to lock interface; retry up to 3 times | Producer squad has lock-in-progress signal in memory |
| `oq_recommend_underspecified` | Auto-regenerate recommendation fields from binding context → re-run generate-intent | Memory has fallback rationale template |

### Halt types that ALWAYS STOP chain (no auto-loop; human required)

- `hard_rule_violated` — code in working tree; user reviews + decides revert vs edit
- `dedup_ambiguous` — multi-path resolution; user picks intent
- `quality_gate_failed` — extract-intelligence; user reviews wave output
- `oq_business_p1_unresolved` — stakeholder decision required
- `test_fail` after 3 retries — manual investigation needed
- `hard_rule_unparseable` / `hard_rule_unanchored` — config error; user fixes
- `cross_squad_dep_invalid` — explicit blocked_by needed; user configures (canonical name per `handoff-contract.md`; was `cross_module_dep_invalid` pre-v2.3.2 Iter 25)
- `memory_schema_mismatch` — migration prompt; user opts in
- `mode_migrate` — vault/code mode contradiction; user decides
- `scope_not_declared_in_prd` — generate-intent: `--scope=<id>` flag mismatches PRD scopes block. ALWAYS STOP (user must pick valid scope from PRD declared list or cancel). v3.20+ Iter 28.
- `prd_no_scopes_block_user_rejected_retrofit` — generate-intent: PRD lacks `scopes:` frontmatter AND user rejected AI retrofit AND chose cancel. ALWAYS STOP (user manually retrofits PRD or chooses single-scope fallback). v3.20+ Iter 28.
- `prd_retrofit_low_confidence` — generate-intent: AI retrofit subagent returned `overall_confidence: LOW`. ALWAYS STOP (user reviews/accepts anyway / single-scope fallback / cancel). v3.20+ Iter 28.
- `prd_path_missing` — diff-vault (v1.3.0+ Iter 29): vault.json.prd_path_at_generation points to non-existent file. ALWAYS STOP (user must restore PRD or regenerate vault).
- `deep_scan_subagent_all_failed` (v2.5.1+, Iter 32) — scan-codebase: all 4 deep-scan subagents failed. User re-runs later.
- `starterkit_rule_citation_missing` (v2.5.1+, Iter 32) — generate-units: starterkit-derived Hard Rule lacks citation. User edits unit.
- `bind_conflict_constitution_violation` (v1.8+, Iter 20) — bind-codebase: claim conflicts with constitution security clause.
- `framework_pack_missing` (v1.9+, Iter 23) — bind-codebase: pack referenced but file absent.
- `framework_pack_cycle` (v1.9+, Iter 23) — bind-codebase: pack inheritance has cycle.
- `framework_pack_unparseable` (v1.9+, Iter 23) — bind-codebase: pack file YAML/markdown parse failed.
- `constitution_drift_detected` (v1.4+, Iter 30) — detect-drift: security/compliance clause drift in code.
- `drift_framework_mismatch` (v1.2+, Iter 12) — detect-drift: scanned framework differs from vault.
- `diff_conflict` (v0.3+, Iter 3) — diff-vault: Resolved-OQ/Decision conflict needs stakeholder.
- `memory_in_use` (v1.0+, Iter 5) — memory: concurrent writer holds lock.
- `dispatch_prompt_too_large` (v2.6+, Iter 30) — execute-bolts: bolt prompt > 10KB cap.
- `bolt_repeated_partial_failure` (v2.6+, Iter 30) — execute-bolts: 3 partial-state cycles failed.
- `provenance_missing` (v2.6+, Iter 30) — execute-bolts: modified file lacks provenance trailer.
- `bolt_introduces_locked_drift` (v2.6+, Iter 30) — execute-bolts: bolt drift on LOCKED entity.
- `self_assessment_missing` (v2.6+, Iter 30) — execute-bolts: bolt-report lacks self-assessment.
- `dep_missing` (v2.0+, Iter 6) — scan-codebase: required binary missing.
- `oq_recommend_citation_invalid` (v1.3+, Iter 2) — generate-intent: OQ recommendation cites missing KB section.
- `predictive_check_failed` (v3.0.0+, Iter 33) — orchestrate-flow: fatal preflight check failed; chain blocked.
- `invalid_handoff` (v3.0.0+, Iter 33) — orchestrate-flow: handoff schema validation failed; producer-side error.
- `handoff_type_mismatch` (v3.0.0+, Iter 33) — orchestrate-flow: handoff field type mismatch with schema annotation.
- `handoff_missing` (v3.2.0+, Iter 40) — orchestrate-flow: sub-skill exited but no handoff YAML at expected path (silent-failure path closure).
- `artifact_missing` (v3.2.0+, Iter 40) — orchestrate-flow: handoff YAML lists artifact paths that don't exist on disk (silent-failure path closure).
- `partial_state_corrupt` (v2.7.3+, Iter 40) — execute-bolts `--resume`: partial-state.json fails JSON parse (silent-failure path closure).

### Halt types that are SOFT (warn-only, chain continues)

- `deep_scan_subagent_failed` (v2.5.1+, Iter 32) — scan-codebase: single deep-scan subagent failed. Auto-retried; partial output on second failure.
- `deep_scan_cache_corrupt` (v2.5.1+, Iter 32) — scan-codebase: starterkit-context.yaml YAML parse failed. Cache auto-invalidated; subagents re-dispatched. Transparent.
- `routing_outcome_corrupt` (v3.0.0+, Iter 33) — orchestrate-flow: routing-outcomes.md parse failure. Auto-invalidate + log; chain proceeds.
- `model_tier_unknown` (v3.1.0+, Iter 34) — orchestrate-flow: override source references a role not in model-tiers.md catalog. Auto-ignore + log; chain proceeds with catalog default. Forward-compat.

### `--converge` flag (v2.3+)

Default behavior in `--deep` mode:

- `--converge` (default ON in `--deep`) — auto-loop eligible halts up to `--max-cycles`
- `--no-converge` — STOP on any halt (pre-v2.3 behavior; explicit user resume needed)
- `--max-cycles=N` — max convergence iterations before forcing human review (default 3; canonical with `/mega-sdd:orchestrate-flow` command)

### Convergence loop algorithm

```
loop until clean OR max-cycles reached:
  execute current skill
  parse handoff YAML

  if status == completed AND blockers empty:
    proceed to next_action.suggested_skill (Iter 4 behavior)

  if status == halted AND blocker.type in CYCLE_ELIGIBLE:
    log: "🔁 Cycle {N}/{max}: halt={type}; auto-resolving..."

    invoke resolver skill (resolve-oq / module-runner / interface-wait / regen):
      - resolver MUST have HIGH confidence recovery path
      - resolver writes resolution to vault.json + memory
      - resolver returns success or "needs manual"

    if resolver success:
      re-run halted skill from checkpoint
      check if halt clears → loop continues
      if halt persists → escalate (treat as manual)

    if resolver needs-manual:
      escalate: stop chain, surface blocker, user resolves

  if status == halted AND blocker.type NOT in CYCLE_ELIGIBLE:
    STOP — surface blocker; user-required halt

  if cycle count >= max:
    STOP — emit "convergence_max_reached" with cycle history; user reviews
```

### Per-cycle chat output

```
▶ Phase 3 of 5: bind-codebase
⛔ Halt: bind_conflict (3 conflicts detected)
🔁 Cycle 1/5: auto-resolving via resolve-oq...
   ↳ C-007 (auth conflict) → recommendation: KEEP_CODE (memory pattern 8/10; conf: 0.95) → ACCEPTED
   ↳ C-009 (sanctum vs passport) → recommendation: KEEP_VAULT (per constitution §B-001) → ACCEPTED
   ↳ C-011 (audit table schema) → recommendation: SPLIT (per past pattern) → ACCEPTED
✓ Cycle 1 complete: 3 conflicts resolved. Re-running bind-codebase...

▶ Phase 3 of 5: bind-codebase (re-run)
✓ Phase 3 of 5: bind-codebase → status: completed, items: 24 claims, blocked: 0
   Convergence: 1 cycle (3 conflicts auto-resolved via memory; 0 manual)
```

### Halt YAML extension for convergence

When chain force-stops at max-cycles:

```yaml
blocker:
  type: convergence_max_reached
  emitted_at: <ISO8601>
  emitted_by: orchestrate-flow
  details:
    cycles_attempted: 5
    halt_history:
      - cycle: 1, halt: bind_conflict, auto-resolved: yes
      - cycle: 2, halt: bind_conflict (different conflicts), auto-resolved: yes
      - cycle: 3, halt: bind_conflict (recurring), auto-resolved: no — recommendation confidence dropped to 0.65
    last_halt: bind_conflict (C-019, auth-related; memory has 2 conflicting patterns)
  next_action: "Recurring conflict detected after 5 cycles. Run /mega-sdd:resolve-oq --binding manually OR re-configure vault claim. Memory has 2 conflicting patterns for this conflict type — review via /mega-sdd:memory show patterns"
```

### Anti-halu rails (mandatory)

- Auto-loop ONLY for eligible halt types listed above (closed set; never expanded silently)
- Resolver MUST have HIGH-confidence recovery path (≥0.80 per Iter 7); else escalate
- `--max-cycles` hard limit prevents runaway
- Every cycle logged in chain summary + memory `outcomes.md` (audit trail)
- If same halt recurs after auto-resolution → escalate (don't loop on identical recurring failure)
- `--no-converge` flag preserves pre-v2.3 behavior (stop on any halt)

### Backward compatibility

- v3.11 pipelines invoked WITHOUT `--converge` → unchanged behavior (stop on any halt)
- `--auto` chain mode → `--converge` defaults ON (autonomous behavior)
- Manual `orchestrate-flow` mode → `--converge` defaults OFF (per-phase control)
- `--max-cycles` flag override available always

### Bolt halt convergence bridge (v2.5.0+, Iter 30 §6.7)

Iter 19 convergence loops handled: `bind_conflict`, `module_blocked_by`, `cross_squad_interface_draft`, `oq_recommend_underspecified`.

Iter 30 adds **propose-and-confirm bridge** for bolt halts:

| Bolt halt type | Convergence behavior |
|---|---|
| `test_fail` (after retries) | Propose-and-confirm fix → user approve → re-execute single bolt → continue batch |
| `hard_rule_violated` | Propose-and-confirm fix → user approve → re-execute → continue |
| `pbt_property_violated` | Propose-and-confirm fix → user approve → re-execute → continue |

Cycle counter respects `--max-cycles` (default 3). One cycle = 1 propose + 1 user decision + 1 re-execute attempt.

**Cycle escalation**: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop). Prevents propose-and-confirm from looping on structurally-broken unit.

**Configuration** (`~/.mega-sdd/memory/config.yaml`):
```yaml
halt_auto_propose:
  test_fail: propose
  hard_rule_violated: propose
  pbt_property_violated: propose
```

Per-halt-type override allowed (set to `pause` to disable propose for that type).

## Checkpoint protocol (v2.0+, Iter 6)

Per `references/checkpoint-protocol.md`:

- Each long-running skill emits per-step checkpoints (JSONL) at `<vault>/.internal/checkpoints/`
- Resume via `--resume-from=<step-id>` (per-skill) OR `/mega-sdd:auto --resume` (chain-wide; orchestrator finds latest checkpoint automatically)
- Granularity per skill — extract-intelligence per wave, bind-codebase per claim, etc.
- Rotation: last 3 runs kept; older archived; prune >180d via `mega-sdd:memory prune`
- Checkpoint emission integrates with handoff YAML via new `checkpoints` field

### Resume logic in orchestrator (v2.0+)

When `/mega-sdd:auto --resume` invoked:

1. Scan `<vault>/.internal/checkpoints/*.jsonl` for current vault context
2. Identify last incomplete skill invocation (most recent checkpoint without "completed" marker)
3. Build chain starting from that skill with `--resume-from=<latest-step-id>` flag
4. Skill resumes mid-execution
5. After skill completes, chain auto-continues per Iter 4 handoff YAML protocol

If NO checkpoints found → fall back to Iter 4 CWD-driven resume (artifact presence).

## Memory layer (v1.4+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), the orchestrator is the SINGLE memory I/O point for the chain per MEMORY-OQ-7. Skills do not re-read disk; they receive slices via handoff YAML.

### Chain start (single memory read)

Before invoking first skill in `--deep` mode:

1. Read user-scope: `~/.mega-sdd/memory/preferences.md` + `~/.mega-sdd/memory/patterns.md`
2. Read project-scope: `<cwd-project>/.mega-sdd/memory/decisions.md` + `conventions.md` + `outcomes.md`
3. Read vault-scope (if vault detected): `<vault>/.memory/classifier-accuracy.json` + `bind-history.md` + `bolt-outcomes.json`
4. Verify all `memory_schema` versions match expected; halt with `memory_schema_mismatch` blocker if any differ (per MEMORY-OQ-1)
5. Build per-skill memory slices (filter to only what each skill needs)
6. Surface chain history in confirmation: "Past 3 runs: 2 completed, 1 halted on bind_conflict. Continue?"

### Per-phase invocation

When invoking each skill via Skill tool:

1. Pass that skill's memory slice via handoff YAML `metadata.memory_context` field (per `references/handoff-contract.md` §Memory layer integration)
2. Skill reads from in-memory slice — no disk re-read

### Per-phase write batching

When skill emits handoff with `metadata.memory_writes`:

1. Validate each write entry (file, scope, action, content)
2. Append to target file per scope rules (resolve absolute path from CWD + vault)
3. Atomic per-file append (per MEMORY-OQ-6 race-tolerant)
4. Log writes to chain progress chat (one line per write)
5. Failed writes logged but do NOT halt chain (memory is optional)

### Chain end

After last skill completes:

1. Final memory summary in chat: "Chain wrote N memory entries across scopes: user (X), project (Y), vault (Z)"
2. If pending suggestions accumulated (≥1 threshold crossed): announce "Mega-SDD has N pending learning suggestions. Review via `/mega-sdd:memory review`"

### Anti-halu rails

- Memory schema mismatch HALTS the chain (cannot continue with mixed schemas)
- Memory I/O failures (disk, perm) logged but do NOT halt (graceful degradation)
- Suggestions surfaced at chain end; NEVER auto-applied
- `--memory-off` propagates to all sub-skills automatically (passed as flag in handoff invocation args)
