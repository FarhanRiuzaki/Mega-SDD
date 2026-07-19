---
name: orchestrate-flow
version: 2.15.0
description: Multi-skill lifecycle orchestrator for mega-sdd. Inspects CWD, proposes a chain of sub-skills (extract-intelligence / generate-intent / scan-codebase / bind-codebase / generate-units / execute-bolts / resolve-oq / detect-drift / diff-vault), confirms once, then executes the chain in --auto mode. `--deep` lifts the 3-skill cap and chains to pipeline-end via handoff-YAML auto-continue; `--resume` resumes a paused chain from CWD state; `--auto` runs autonomously. Use when the user says "orchestrate", "run flow", "run the flow", "auto mega-sdd", "do the next thing", "what's next", "lanjut", "lanjutkan", "next", or paraphrases.
---

# Orchestrate-Flow — Lifecycle Orchestrator

**Announce at start:** "I'm using the orchestrate-flow skill to inspect CWD and propose the next phases."

The orchestrator inspects the working directory, infers where you are in the mega-sdd pipeline, proposes a chain of sub-skills, confirms once, then dispatches them with `--auto`. It generates no content itself — it routes. Heavy detail (decision matrices, preflight catalogs, handoff validation, convergence, halt taxonomy) lives in the references below; this file is the router.

> **Instruction language:** this skill reasons in English. User triggers may be Indonesian ("lanjut", "lanjutkan", "next"). Narrate (the announce, proposed-chain prose, confirmations) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`).

## When to use

- "run the flow" / "run flow" / "auto mega-sdd" / "do the next thing"
- "what's next" / "orchestrate" / "lanjut" / "lanjutkan" / "next"
- After completing one phase, the user wants an automatic transition.

## Procedure (router skeleton)

1. **Parse args.** Persist `WORK_DIR`, optional `--from=<phase>`, `--to=<phase>`, `--deep`, `--resume`, `--auto`. Full flag list in [Flags](#flags).

2. **Deterministic CWD inspection** per `references/routing-rules.md §CWD inspection`. Output a state snapshot:
   ```
   prd: present | absent
   vault: present | absent (path: ...)
   bound_vault: present | absent
   units: N
   bolts: N
   codebase_map: present | absent
   knowledge_base: present | absent (path: ...)  # priority: .mega-sdd/knowledge-base → docs/knowledge-base → docs/mega-sdd/knowledge-base → old-reference/knowledge-base
   git_repo: yes | no
   pending_p0_p1_count: N    # status: open (or absent) P0/P1 OQs — these gate
   deferred_p0_p1_count: N   # status: deferred P0/P1 OQs — informational, do not gate
   mode_inferred: greenfield | brownfield | legacy-rebuild
   squad_count: N        # from <vault>/_meta/squads.yaml; 0 if absent or single squad
   interfaces_count: N   # count of files in <vault>/interfaces/ (excluding _index.md); 0 if folder absent
   change_signal:        # Mode D probes (living-vault sync)
     dirty_journal_rows: N            # grep -c . .mega-sdd/codebase/.dirty-paths.jsonl
     map_stamp_matches_head: yes | no | n/a   # last_scanned_commit vs git HEAD
   starterkit: detected | absent  # framework manifest probe
     framework: <name|null>       # e.g., laravel-base-26 (pack match), laravel (universal), null
     pack_match: yes | no         # yes if framework-conventions/<framework>.md exists; no if universal fallback
     manifest_path: <path|null>   # e.g., composer.json, package.json, Gemfile, pyproject.toml, go.mod, Cargo.toml
   ```

3. **Resolution preflight** (per `references/chain-execution.md`). Run in order; each is default-on and falls through silently when not applicable:
   - **Starterkit detection + mode classification** — starterkit is REQUIRED by default; greenfield only on explicit `--greenfield` (Mode A starterkit-first / Mode B framework-detected / Mode C greenfield). Starterkit absent AND no `--greenfield` → halt `no_starterkit_detected`.
   - **Memory-informed routing preflight** — fingerprint CWD; if past-run history converges, recommend that chain; if it failed, warn. Falls through to routing-rules default otherwise.
   - **Model-tier override resolution** — resolve model tier per subagent role (CLI > project > user > catalog); emit into handoff metadata. Unknown role → SOFT halt `model_tier_unknown` (warn-only).
   - **Iter classifier EP1** — classify iter as PATCH | MINOR | MAJOR for downstream complexity gating.
   - **Plan/Act gating** — PATCH/MINOR → Act; MAJOR → Plan mode FIRST (write `.plan-pending`, STOP for user review). `--act` / `--plan-then-act` override.

4. **Build proposed chain** per `references/routing-rules.md §Decision matrix`.
   - Default mode (no `--deep`): hard cap **3 sub-skills** (legacy behavior, backward-compatible).
   - **`--deep` mode:** cap LIFTED — chain extends to pipeline-end per `references/routing-rules.md §Deep-chain decision matrix`. Auto-continue between phases via the handoff YAML protocol (consumed per `references/handoff-consumption.md`; producer schema in `references/handoff-contract.md`).
   - **Chain optimization:** if the chain includes `scan-codebase` but `binding.md` attests a verified, unchanged snapshot → skip scan-codebase (per `references/chain-execution.md §Chain optimization via binding provenance`).

5. **Predictive preflight** per `references/predictive-checks.md` catalog — runs BEFORE invoking any skill in the proposed chain. For each chained skill, run its lightweight checks: `fatal: no` mismatch → accumulate warning (surfaced before chain start); `fatal: yes` mismatch → halt `predictive_check_failed`, STOP chain. Then the execute-bolts-specific **first-run pre-flight** runs (superpowers OR `_vendored/` availability; if neither → propose install, halt). Detail in `references/chain-execution.md`.

6. **Present plan + single `AskUserQuestion`** (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only. Include a "Halts may re-engage you" line so users have accurate expectations:
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
   Per the keterangan contract (`plugins/mega-sdd/references/output-language.md §Prompt surfaces`) each option carries its description: `Run` **(recommended)** — jalankan semua N fase end-to-end, berhenti hanya di blocker nyata; `Edit` — hanya `skip step N` / `stop after step N` (bukan reorder); `Cancel` — tidak ada fase yang dijalankan. Confirmation is ONE-TIME for the chain proposal; halts are NOT additional confirmations — they're interventions on real issues.

7. **Execute chain.** Dispatch sub-skills with the `--auto` flag. Pause on blocker artifacts (any type) per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`. `resolve-oq` is always interactive on per-OQ choices.

   **Per sub-skill in chain (loop):**
   a. **Dispatch** with assembled flags + memory POINTER slice (file path + row keys + one-line digest, never row text) via `metadata.memory_context`. Propagate canonical top-level fields (scope, constitution, mutability, pbt, cycles, replay, starterkit_context) from the previous handoff.
   b. **Validation gate** — validate the received handoff against the schema (presence → type-check → schema → artifact existence → cross-metric consistency). Full gate ordering + halt envelopes (`handoff_missing`, `handoff_type_mismatch`, `invalid_handoff`, `artifact_missing`) in `references/handoff-consumption.md`.
   c. **Propagate** validated handoff metadata to the next skill.
   d. **Progress indicators** — before each invocation: `▶ Phase {current} of {total}: invoking {skill} ({args})`; after completion: `{✓|⏸|⛔} Phase {current} of {total}: {skill} → status: {status}, items: {n}, blocked: {n}`.
   e. **Halt-check** — `status==halted` → exit loop; proceed to Step 9.
   f. **Continue-loop** — `status==completed` → continue to next sub-skill.

   **Auto-integrated diagnostics + drift gate run transparently inside this loop** (lint-units, analyze-parallelism, list-modules, emit-agents-md, optional emit-fsd, enrich-semantics PAUSE, and the DEFAULT-ON hybrid `detect-drift` gate after `execute-bolts`). User does NOT run these separately; opt-outs (`--no-lint`, `--no-drift-check`, etc.) and the full phase table are in `references/chain-execution.md`.

8. **Iter classifier EP2** — after the chain completes, classify again and compare to EP1; surface scope drift in the summary (per `references/chain-execution.md`).

9. **Emit final summary** — completed/paused/skipped per step + verbatim blocker YAMLs if any. In `--deep` mode, append the diagnostics summary, predictive-preflight metrics, and phase context (per `references/chain-execution.md §Final summary appendix`). Then (skipped if `--memory-off`): write the end-of-chain routing-outcomes memory entry; run the **extract-learnings pass** (Step 7.6 — the ONE owned threshold evaluation over rows touched this chain, appending threshold-crossers to `## Pending suggestions`, nothing applied); regenerate touched scopes' `_index.md`. Mode D additionally appends the `kind: sync` outcomes row. Protocol: `references/memory-layer.md §Chain end`.

10. **Resume support (`--resume`, CWD-driven, no state file).**
    - Skip the upfront confirmation (chain was already approved last run).
    - Re-run CWD inspection (Step 2) — fresh state snapshot.
    - Build chain per routing-rules; skip phases whose artifacts already exist; cursor lands on the next un-done phase.
    - Execute from the cursor onward.
    - If a previously-halted phase still has its blocker unresolved → the halt fires again identically. User MUST resolve the blocker BEFORE re-running `--resume`.

## Hard rails

- No content generation by the orchestrator itself.
- No **chain-level** state file: `orchestrate-flow --resume` rebuilds chain state by CWD/artifact inspection (which *phase* to resume). A phase skill MAY keep its own sub-step checkpoint (`references/checkpoint-protocol.md`) that resumes *within* the re-entered phase — a different granularity that never conflicts with phase selection (precedence table → `references/handoff-contract.md` §Resume mechanics).
- No skill runs in parallel.
- Sub-skill substance prompts ALWAYS surface to the human (per-OQ choices, conflict resolutions) regardless of `--auto`.
- Chain depth ≤ 3 by default; `--deep` lifts the cap with auto-continue via handoff YAML.
- `--deep` does NOT relax any halt-condition. Every blocker still fires identically. Auto-continue happens ONLY when a skill reports `status: completed` with empty `blockers: []`.

## Flags

- `--from=<phase>`: resume from a specific phase (skip earlier phases even if state says they're needed)
- `--to=<phase>`: stop at a specific phase (do not chain beyond it)
- `--dry-run`: show the proposed chain without executing
- `--deep`: lift the 3-skill cap; chain to pipeline-end via handoff-YAML auto-continue
- `--resume`: re-enter a paused/halted chain; skip upfront confirmation; CWD inspection rebuilds cursor position; halts re-fire if blockers unresolved
- `--auto`: run the chain autonomously (sub-skills dispatched with `--auto`; substance prompts still surface)
- `--converge` / `--no-converge` / `--max-cycles=N`: auto-recovery cycling controls (default ON in `--deep`; see `references/convergence-loops.md`)
- `--memory-off`: disable the memory layer (no reads, no writes) for this chain
- `--greenfield` / `--brownfield`: override starterkit/mode inference
- `--with-fsd` / `--no-fsd`, `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md`, `--no-drift-check`, `--no-enrich-staging`: diagnostic opt-outs (see `references/chain-execution.md`)
- `--sync`: force the Mode D maintenance chain (incremental scan → drift → re-bind → unit reconcile) regardless of other inference — the `/mega-sdd:sync` front-door (per `references/routing-rules.md` §Mode D)
- `--factory` — enable state-driven factory routing: read the whole checkpoint ledger and route forward OR backward to re-run an unresolved phase, looping to convergence under the retry cap (`references/factory-routing.md`). Implied by `--deep`.
- `--strict-quality`: escalate advisory quality findings to chain-pausing
- `--no-telemetry`: disable telemetry event emission for this chain
- Checkpoint protocol auto-emits per-step JSONL files at `<vault>/.internal/checkpoints/` (per `references/checkpoint-protocol.md`); enables mid-skill resume

## Greenfield vs brownfield routing

Per `references/routing-rules.md §Greenfield vs brownfield detection`. If CWD signals say "brownfield" but the vault says `mode: greenfield` (or vice versa) → halt with a mode-migration prompt; the user chooses to update the vault or re-detect.

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

When this prompt reaches the user (i.e. the C1 chain-time re-detect did not already fix it — e.g. the user passed an explicit mode flag), the recommended default is the CWD-detected mode (CWD signals are ground truth per halt-protocol) and each resolution carries its consequence: `update vault.mode to match CWD` **(recommended)** — `existing` mengaktifkan detect-drift + verifikasi terhadap code lama sebelum menyentuhnya, `greenfield` melewatinya; `re-detect by moving to clean dir` — pakai kalau CWD-nya memang salah (misal vault greenfield tersimpan di dalam repo lain).

## Convergence loops + checkpoints

- **Convergence** (`--deep`): cycle-eligible halts auto-resolve via memory-pre-filled recommendations and re-run, up to `--max-cycles`; all other halts stop the chain. Algorithm, per-cycle output, `convergence_max_reached` envelope, the propose-and-confirm bolt bridge, and anti-halu rails are in `references/convergence-loops.md`.
- **Checkpoints:** long-running skills emit per-step JSONL checkpoints enabling mid-skill resume (`--resume-from=<step-id>` per-skill; `/mega-sdd:auto --resume` chain-wide finds the latest automatically). Granularity, rotation, and resume logic in `references/checkpoint-protocol.md`.

## Halt protocol

Every blocker a sub-skill emits is classified as **cycle-eligible** (auto-loop in `--deep`), **always-stop** (human required), or **soft** (warn-only, chain continues). The full classification of every halt type is in `references/halt-taxonomy.md`. Canonical envelope shapes: `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`.

## Memory layer

When memory is enabled (default; opt-out `--memory-off`), the orchestrator does the chain's ONE memory read at chain start (index-first, just-in-time; rows enter session context there); handoffs carry POINTER slices, skills append their own rows via `scripts/memory-write.sh` at emission time (the script secret-scans at write time), handoffs return a write receipt (`files_written` paths + `rows_appended`), and the owned extract-learnings threshold pass + `_index.md` regeneration run at chain end via targeted reads of the receipt paths. Schema mismatch halts the chain; I/O failures degrade gracefully. Suggestions are NEVER auto-applied. Full read/write protocol in `references/memory-layer.md`.

## Specialist references (load on demand)

- `references/factory-ledger-contract.md` — the derived checkpoint ledger schema each phase appends to.
- `references/factory-routing.md` — read-whole-ledger forward/backward routing + convergence/cap termination (`--factory` / `--deep`).
- **`references/routing-rules.md`** — CWD inspection order, the default + `--deep` decision matrices, starterkit-first ordering, multi-squad detection, greenfield/brownfield detection, `--from`/`--to`/`--resume` mechanics.
- **`references/chain-execution.md`** — full resolution-preflight procedure (starterkit/mode classification, memory-informed routing, model-tier resolution, iter-classifier EP1/EP2, Plan/Act gating, chain optimization), predictive-preflight loop, first-run pre-flight, auto-integrated diagnostics table, hybrid drift gate, end-of-chain memory write, final-summary appendix.
- **`references/predictive-checks.md`** — per-skill preflight check catalog consulted before chain start.
- **`references/handoff-consumption.md`** — orchestrator-side handoff validation gate (presence / type / schema / artifact / cross-metric) with halt envelopes, plus the consumption control loop.
- **`references/handoff-contract.md`** — producer-side handoff YAML schema, field TYPE annotations, per-skill expected emissions, memory-layer integration.
- **`references/convergence-loops.md`** — auto-recovery cycling: eligible halts, algorithm, `--converge` flags, bolt propose-and-confirm bridge.
- **`references/halt-taxonomy.md`** — every halt type classified (cycle-eligible / always-stop / soft).
- **`references/memory-layer.md`** — single-memory-I/O-point read/write batching across the chain.
- **`references/checkpoint-protocol.md`** — per-step JSONL checkpoints + mid-skill resume.
- **`references/sync-digest.md`** — Mode D autonomous deferral contracts: `PENDING-SYNC.md` (deferred-decision queue) + `SYNC-REPORT.md` (run report with closing staleness verification).

## Related skills

Sub-skills orchestrated: `extract-intelligence`, `generate-intent`, `scan-codebase`, `bind-codebase`, `generate-units`, `execute-bolts`, `resolve-oq`, `detect-drift`, `diff-vault` — plus the auto-integrated diagnostics `enrich-semantics`, `lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`, `emit-fsd` (opt-in), and `install-deps` (each also emits a handoff YAML). Each emits a handoff YAML the orchestrator consumes (`plugins/mega-sdd/references/halt-protocol.md §halt-protocol` for canonical blocker envelopes).
