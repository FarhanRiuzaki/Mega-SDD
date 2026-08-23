---
name: orchestrate-flow
version: 2.28.0
description: Multi-skill lifecycle orchestrator — inspects CWD state, proposes a chain of mega-sdd sub-skills, confirms once, executes in --auto mode with halt-pauses; --deep chains to pipeline-end; --resume continues a paused chain; --sync runs the reconcile lane. Use when the user says "orchestrate", "run flow", "run the flow", "auto mega-sdd", "do the next thing", "what's next", "lanjut", "lanjutkan", "next", or paraphrases.
---

# Orchestrate-Flow — Lifecycle Orchestrator

**Announce at start:** "I'm using the orchestrate-flow skill to inspect CWD and propose the next phases. `mega-sdd-trace:orchestrate-flow`"

The orchestrator inspects the working directory, infers where you are in the mega-sdd pipeline, proposes a chain of sub-skills, confirms once, then dispatches them with `--auto`. It generates no content itself — it routes. Heavy detail (decision matrices, preflight catalogs, handoff validation, convergence, halt taxonomy) lives in the references below; this file is the router.

> **Instruction language:** this skill reasons in English. User triggers may be Indonesian ("lanjut", "lanjutkan", "next"). Narrate (the announce, proposed-chain prose, confirmations) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`).

## When to use

- "run the flow" / "run flow" / "auto mega-sdd" / "do the next thing"
- "what's next" / "orchestrate" / "lanjut" / "lanjutkan" / "next"
- After completing one phase, the user wants an automatic transition.

## Procedure (router skeleton)

1. **Parse args.** Persist `WORK_DIR`, optional `--from=<phase>`, `--to=<phase>`, `--deep`, `--resume`, `--auto`. Full flag list in [Flags](#flags).

2. **Deterministic CWD inspection** — `Run: scripts/derive-state.sh --cwd=<WORK_DIR>` (the ONE probe engine; shared library with `validate-preflight.sh` so probe sets never diverge), then read the printed digest + `<root>/.mega-sdd/state.json` — the engine has already applied the inspection order (its documented contract: `references/routing-rules.md §CWD inspection`; open it ONLY to audit a digest that looks wrong). Never re-probe by hand. Output a state snapshot (fields sourced from `state.json`):
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
     index_stamp_matches_head: yes | no | n/a # symbol-index head_commit vs git HEAD (express-born substrate)
   starterkit: detected | absent  # framework manifest probe (P2: manifests incl. *.csproj/*.sln globs)
     framework: <name|null>       # derived.framework_pack — the GROUND matcher's pick (e.g., laravel-base-26)
     pack_match: yes | no         # no == `_universal` fallback
     manifest_path: <path|null>   # derived.framework_pack_manifest
   spine: express | classic       # derived.spine — express is the P2 default
   ```

3. **Resolution preflight** (per `references/chain-execution.md`). Run in order; each is default-on and falls through silently when not applicable:
   - **Starterkit detection + mode classification** — starterkit is REQUIRED by default; greenfield only on explicit `--greenfield` (Mode A starterkit-first / Mode B framework-detected / Mode C greenfield). Starterkit absent AND no `--greenfield` → halt `no_starterkit_detected`.
   - **Model-tier override resolution** — resolve model tier per subagent role (CLI > project > user > catalog); emit into handoff metadata. Unknown role → SOFT halt `model_tier_unknown` (warn-only).
   - **Plan/Act gating** — `--plan` → Plan mode FIRST (write `.plan-pending`, STOP for user review); `--plan-then-act` → two-phase; default → Act. (The automatic PATCH|MINOR|MAJOR iter classifier is PARKED — not wired into the live chain; design note in `references/chain-execution.md` — so gating is flag-driven.)

4. **Build proposed chain.** `derived.proposed_next` (from the Step-2 digest) IS the default chain — the engine is authoritative and needs no table read. Open `references/routing-rules.md §Decision matrix` ONLY when an overlay applies: a routing flag (`--greenfield` / `--brownfield` / `--sync` / `--from` / `--to` / `--resume`), rebuild/adoption intent, multi-squad, or the user edits the proposal.
   - Default mode (no `--deep`): hard cap **3 sub-skills** (legacy behavior, backward-compatible).
   - **`--deep` mode:** cap LIFTED — the engine's proposal already extends to pipeline-end; `references/routing-rules.md §Deep-chain decision matrix` opens under the same overlay-only rule as Step 4. Auto-continue between phases via the handoff YAML protocol (consumed per `references/handoff-consumption.md` — per hop; `references/handoff-contract.md` opens at the b.iv conditional-field check — its schema owns the CONDITIONAL roster — on a validation failure, or for §Resume mechanics; never for the rest of a clean hop).
   - **Chain optimization:** if the chain includes `scan-codebase` but `binding.md` attests a verified, unchanged snapshot → skip scan-codebase (per `references/chain-execution.md §Chain optimization via binding provenance`).

5. **Predictive preflight** — `Run: bash <plugin-root>/scripts/validate-preflight.sh --predictive --cwd=<root> --chain=<skill,skill,…>` (the merged predictive mode — v7 Fase 2) BEFORE invoking any skill in the chain (the script owns each chained skill's checks + the §Cold-halt anticipation set whenever `execute-bolts` is chained; source-of-truth catalog: `references/predictive-checks.md` — open it ONLY to read an `on_fail` hint in full or to author checks, never to hand-run the loop). Read the JSON verdicts: exit 0 → surface any `warn` lines before chain start; exit 3 (≥1 `fatal`) → halt `predictive_check_failed`, STOP chain. Three flag-dependent checks stay MODEL-RUN when their trigger is present (the script skips them by design): `constitution_file_check` under `--strict-constitution`, `new_source_resolves_for_diff` with a positional source, `subagent_capacity_reasonable` with `--max-parallel` — run each from its catalog entry. Then the execute-bolts-specific **first-run pre-flight** runs (superpowers OR `_vendored/` availability; if neither → propose install, halt). Detail in `references/chain-execution.md`.

6. **Present plan + single `AskUserQuestion`** (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only. Include a "Halts may re-engage you" line so users have accurate expectations:
   ```
   Proposed pipeline (--deep, express spine):
     1. generate-intent ./prd.md       → vault (index/state-grounded)
     2. bind-codebase --express        → binding.md + bound-vault/
     3. generate-units                 → units/
     4. execute-bolts --all --parallel → bolts/
   (classic spine additionally opens with scan-codebase → codebase-map.md)

   Halts may re-engage you mid-chain (test failures, business OQ
   resolutions, hard-rule violations, dedup ambiguity, recommendation
   reviews). Otherwise runs end-to-end silently with progress indicators.

   [Run] [Edit] [Cancel]
   ```
   Per the keterangan contract (`plugins/mega-sdd/references/output-language.md §Prompt surfaces`) each option carries its description: `Run` **(recommended)** — jalankan semua N fase end-to-end, berhenti hanya di blocker nyata; `Edit` — hanya `skip step N` / `stop after step N` (bukan reorder); `Cancel` — tidak ada fase yang dijalankan. Confirmation is ONE-TIME for the chain proposal; halts are NOT additional confirmations — they're interventions on real issues.

7. **Execute chain.** Dispatch sub-skills with the `--auto` flag. Pause on blocker artifacts (any type) per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`. `resolve-oq` is always interactive on per-OQ choices.

   **Per sub-skill in chain (loop):**
   a. **Dispatch** with assembled flags. Propagate canonical top-level fields (scope, constitution, mutability, pbt, cycles, replay, starterkit_context) from the previous handoff.
   b. **Validation gate** — validate the received handoff against the schema (presence → type-check → schema → artifact existence → cross-metric consistency). Full gate ordering + halt envelopes (`handoff_missing`, `handoff_type_mismatch`, `invalid_handoff`, `artifact_missing`) in `references/handoff-consumption.md`.
   c. **Propagate** validated handoff metadata to the next skill.
   d. **Progress indicators** — before each invocation: `▶ Phase {current} of {total}: invoking {skill} ({args})`; after completion: `{✓|⏸|⛔} Phase {current} of {total}: {skill} → status: {status}, items: {n}, blocked: {n}`.
   e. **Halt-check** — `status==halted` → exit loop; proceed to the Emit-final-summary step.
   f. **Continue-loop** — `status==completed` → continue to next sub-skill.

   **Auto-integrated diagnostics + drift gate run transparently inside this loop** (lint-units `--changed-only`, analyze-parallelism, list-modules, emit-agents-md, optional emit-fsd, enrich-semantics PAUSE, and the DEFAULT-ON hybrid `detect-drift` gate after `execute-bolts`). User does NOT run these separately; opt-outs (`--no-lint`, `--no-drift-check`, etc.) and the full phase table are in `references/chain-execution.md`. **Diagnostics are LEAN-BY-DEFAULT on the express spine (P3):** the ADVISORY diagnostics in this loop (`lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`) are SKIPPED on express-spine chains — each re-runnable on demand; `--full` restores them for a run; classic-spine chains keep them (today's behavior verbatim). The Stop hook's auto-analyze aggregate fires only under `spine: classic` or an explicit `profile: full` in config. **`--lean` profile (tranche E):** active when the user passes `--lean` (this run) or `.mega-sdd/config.yaml` carries `profile: lean` (persistent — the Stop-hook aggregate skip engages; `--full` restores the diagnostics for a run but does NOT restore the config-governed Stop aggregate — remove the config key for that). Under lean: the ADVISORY diagnostics in this loop (`lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`) are SKIPPED (each re-runnable on demand), and the Stop hook's auto-analyze aggregate does not fire. The `detect-drift` gate keeps running. **Lean NEVER touches (rail 1 — speed cuts inventory, never verification):** the CONFLICT gate, binding verdicts, citation discipline, the halt taxonomy, no-fabrication, the B1–B4 artifact gates, anti-self-bypass, review-lens blindness, or the review-panel risk tiering — a lean run is a correct run that is less thorough, and the chain summary MUST name the profile (`profile: lean — advisory diagnostics skipped`).

8. **Emit final summary** — completed/paused/skipped per step + verbatim blocker YAMLs if any. **Deferred-OQ resurface (P3/A6, ALWAYS — deep or not):** when the vault carries `open_questions[] status == deferred` (incl. express auto-defers), append one line: `⏸ N OQ deferred — <tags>. Jawab kapan saja: resolve-oq` — the recorded defer's mandated resurface. In `--deep` mode, append the diagnostics summary, predictive-preflight metrics, and phase context (per `references/chain-execution.md §Final summary appendix`). (v7.3.0: the end-of-chain memory write + extract-learnings pass are REMOVED with the memory lane.)

9. **Resume support (`--resume`, CWD-driven, no state file).**
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
- `--to=<phase>`: stop at a specific phase (do not chain beyond it). The front door's `--step-after=<phase>` / `--stop-after=<phase>` are ALIASES that render to this flag (commands/mega-sdd.md §Flag handling) — this skill itself accepts only `--to=`.
- `--dry-run`: show the proposed chain without executing
- `--deep`: lift the 3-skill cap; chain to pipeline-end via handoff-YAML auto-continue
- `--resume`: re-enter a paused/halted chain; skip upfront confirmation; CWD inspection rebuilds cursor position; halts re-fire if blockers unresolved
- `--auto`: run the chain autonomously (sub-skills dispatched with `--auto`; substance prompts still surface)
- `--plan` / `--act` / `--plan-then-act`: Plan/Act gating — flag-driven (the automatic iter classifier is PARKED; see the Step-3 bullet)
- `--converge` / `--no-converge` / `--max-cycles=N`: auto-recovery cycling controls (default ON in `--deep`; see `references/convergence-loops.md`)
- `--greenfield` / `--brownfield`: override starterkit/mode inference
- `--with-fsd` / `--no-fsd`, `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md`, `--no-drift-check`, `--no-enrich-staging`: diagnostic opt-outs (see `references/chain-execution.md`)
- `--sync`: force the Mode D maintenance chain (changed-set derivation — incremental scan on map-bearing projects, `scripts/derive-changed-paths.sh` on express-born — → **`scripts/sync-intersect.sh` short-circuit gate (exit 0 = in-sync: stamp + one-line SYNC-REPORT + END; exit 2 or any other unexpected exit = fail-closed, full chain)** → drift → re-bind → unit reconcile) regardless of other inference — the `/mega-sdd:sync` front-door (per `references/routing-rules.md` §Mode D)
- `--factory` — enable state-driven factory routing: read the whole checkpoint ledger and route forward OR backward to re-run an unresolved phase, looping to convergence under the retry cap (`references/factory-routing.md`). Implied by `--deep`.
- `--express` / `--classic`: the spine switch — **express is the DEFAULT (P2)**. Express: the state engine renders chains WITHOUT a scan phase (GROUND ran as a script) and appends `--express` to every `bind-codebase` hop (bind enumerates claims from the script-derived `claims-ledger.json` PLUS a model completeness sweep of the vault docs, and retrieves evidence via symbol-index queries + targeted Reads, zero codebase-map load; honest fallback to the standard lane when the index/ledger is unavailable — `bind-codebase/references/express-bind.md`). `--classic` (this run) or `spine: classic` in `.mega-sdd/config.yaml` (persistent — the engine reads only the config; the FLAG is applied by the orchestrator at dispatch time, the `--lean` precedent) restores the scan-first chains verbatim. No gate or verdict-grammar change on either spine.
- `--strict-quality`: escalate advisory quality findings to chain-pausing
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
  next_action: "Confirm correct mode then re-run /mega-sdd"
```

When this prompt reaches the user (i.e. the C1 chain-time re-detect did not already fix it — e.g. the user passed an explicit mode flag), the recommended default is the CWD-detected mode (CWD signals are ground truth per halt-protocol) and each resolution carries its consequence: `update vault.mode to match CWD` **(recommended)** — `existing` mengaktifkan detect-drift + verifikasi terhadap code lama sebelum menyentuhnya, `greenfield` melewatinya; `re-detect by moving to clean dir` — pakai kalau CWD-nya memang salah (misal vault greenfield tersimpan di dalam repo lain).

## Convergence loops + checkpoints

- **Convergence** (`--deep`): cycle-eligible halts auto-resolve via grounded (KB/vault/codebase) recommendations and re-run, up to `--max-cycles`; all other halts stop the chain. Algorithm, per-cycle output, `convergence_max_reached` envelope, the propose-and-confirm bolt bridge, and anti-halu rails are in `references/convergence-loops.md`.
- **Checkpoints:** long-running skills emit per-step JSONL checkpoints enabling mid-skill resume (`--resume-from=<step-id>` per-skill; `/mega-sdd --resume` chain-wide finds the latest automatically). Granularity, rotation, and resume logic in `references/checkpoint-protocol.md`.

## Halt protocol

Every blocker a sub-skill emits is classified as **cycle-eligible** (auto-loop in `--deep`), **always-stop** (human required), or **soft** (warn-only, chain continues). The full classification of every halt type is in `references/halt-taxonomy.md`. Canonical envelope shapes: `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`.

## Specialist references (load on demand)

- `references/factory-ledger-contract.md` — the derived checkpoint ledger schema each phase appends to.
- `references/factory-routing.md` — read-whole-ledger forward/backward routing + convergence/cap termination (`--factory` / `--deep`).
- **`references/routing-rules.md`** — CWD inspection order, the default + `--deep` decision matrices, starterkit-first ordering, multi-squad detection, greenfield/brownfield detection, `--from`/`--to`/`--resume` mechanics. *Open ONLY on a Step-4 overlay (flag / rebuild-adoption intent / multi-squad / user edit) — the engine's `derived.proposed_next` is the default.*
- **`references/chain-execution.md`** — full resolution-preflight procedure (starterkit/mode classification, model-tier resolution, iter-classifier EP1/EP2 (PARKED), Plan/Act gating, chain optimization), predictive-preflight loop, first-run pre-flight, auto-integrated diagnostics table, hybrid drift gate, final-summary appendix.
- **`references/diagnostics-procedures.md`** — the operative procedures for the four auto-integrated diagnostics (`lint-units`, `analyze-parallelism`, `list-modules`, `enrich-semantics`) — relocated from their 5.x command files in the surface cull; load when a chain row or an on-demand phrase invokes one.
- **`references/predictive-checks.md`** — per-skill preflight check catalog consulted before chain start.
- **`references/handoff-consumption.md`** — orchestrator-side handoff validation gate (presence / type / schema / artifact / cross-metric) with halt envelopes, plus the consumption control loop.
- **`references/handoff-contract.md`** — producer-side handoff YAML schema, field TYPE annotations, per-skill expected emissions. *Open at the b.iv conditional-field check (its schema owns the CONDITIONAL roster), on a validation failure, or for §Resume mechanics — `handoff-consumption.md` owns the rest of the per-hop loop.*
- **`references/convergence-loops.md`** — auto-recovery cycling: eligible halts, algorithm, `--converge` flags, bolt propose-and-confirm bridge.
- **`references/halt-taxonomy.md`** — every halt type classified (cycle-eligible / always-stop / soft).
- **`references/checkpoint-protocol.md`** — per-step JSONL checkpoints + mid-skill resume.
- **`references/sync-digest.md`** — Mode D autonomous deferral contracts: `PENDING-SYNC.md` (deferred-decision queue) + `SYNC-REPORT.md` (run report with closing staleness verification).

## Related skills

Sub-skills orchestrated: `extract-intelligence`, `generate-intent`, `scan-codebase`, `bind-codebase`, `generate-units`, `execute-bolts`, `resolve-oq`, `detect-drift`, `diff-vault` — plus the auto-integrated diagnostics `enrich-semantics`, `lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`, `emit-fsd` (opt-in), and `install-deps` (each also emits a handoff YAML). Each emits a handoff YAML the orchestrator consumes (`plugins/mega-sdd/references/halt-protocol.md §halt-protocol` for canonical blocker envelopes).
