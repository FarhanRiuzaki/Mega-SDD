# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-05-13

### Added — Source-code OQ deferral + structured halt protocol

- **resolve-oq 4-action menu** — Per OQ: Answer / Defer-to-binding / Out-of-scope / Skip. Defer option appears only in brownfield context (vault.mode=existing AND repo signals present).
- **resolve-oq `--binding` mode** — Procedure documented for walking CONFLICT + propagated deferred-OQ entries from `binding.md`. Per-conflict actions: KEEP_VAULT / KEEP_CODE / DEFER / SPLIT.
- **bind-codebase auto-resolution** — Deferred-binding OQs auto-resolve against codebase-map evidence (high-confidence single match); else propagate to `binding.md` Open Questions for user resolution via `resolve-oq --binding`.
- **vault-contract §halt-protocol** extended 3 → 8 structured types: + `bind_conflict`, `dep_missing`, `test_fail`, `cycle_detected`, `mode_migrate`.
- **routing-rules.md** intent gate excludes deferred OQs (`Vault has unresolved P0/P1 OQs with status != deferred` — deferred propagate to binding).

### Changed — Skill alignment

- **vault.json OQ schema** gains optional fields: `status` (pending|resolved|deferred|out-of-scope), `defer_to` (binding|stakeholder), `deferred_at`, `deferred_reason`, `out_of_scope_reason`. Backwards compatible — absent `status` treated as `pending`. Pre-v1.1 `defer_note` semantics now unified under `deferred_reason`.
- **bind-codebase SKILL.md** standardizes `<vault>-bound/` sibling naming throughout (was mixed with generic `bound-vault/`).
- **generate-intent SKILL.md** `--auto` default output path aligned to `docs/mega-sdd/vaults/<slug>/` (was `./<slug>-spec/`).
- **commands/detect-drift.md** output filename corrected to `DRIFT-REPORT.md` (matches skill SKILL.md).
- **bind-codebase, execute-bolts, generate-units, orchestrate-flow** emit structured halt YAML per §halt-protocol (was prose-only).
- **resolve-oq stakeholder-defer reconciliation** — Old Step 2c bespoke `defer_note` semantic merged into the new unified OQ schema (`defer_to: stakeholder` + `deferred_reason`).

### Fixed — README defects (audit findings F1-F8)

- Halt protocol section: 5 fabricated types replaced with the now-real 8-type list.
- `--chain` flag references removed (3 spots in cheat-sheet) — flag never existed.
- `update-plugin` moved from skills table to commands footnote (no backing SKILL.md).
- Skill count "11" corrected to "10 + 1 command-only".
- Plugin version aligned across `plugin.json`, marketplace.json, and both READMEs.
- Both diagrams add `{P0/P1 non-deferred OQs?}` intent-gate decision node visible in actor flow + detailed pipeline.
- Defense layer 4 wording: "runs post-bolt" → "suggested post-bolt; runs on demand".

### Migration

Fully backwards compatible. Existing v1.0.x vaults load without conversion. To benefit from new resolve-oq actions, re-invoke `resolve-oq` on existing vaults — 4-action menu appears for any pending OQ.

### Marketplace

- `mega-sdd@1.1.0` published
- `grand-design-spec@0.16.0` continues deprecated; removed at v1.2.0 per existing schedule

## [1.0.0] — 2026-05-13

### BREAKING — rename to mega-sdd

The plugin is renamed from `grand-design-spec` to `mega-sdd`. All skill, command, and namespace identifiers change. See migration table in `plugins/mega-sdd/README.md`.

### Added — Spec-Driven Development pipeline

- **`scan-codebase` skill** — heuristic repo mapping → `codebase-map.md` (brownfield prep)
- **`bind-codebase` skill** — vault validation gate; produces `bound-vault/` + `binding.md`; BLOCKS unit generation on conflicts (the keystone anti-hallucination layer)
- **`generate-units` skill** — bound-vault → atomic AI-executable unit specs with dependency graph
- **`execute-bolts` skill** — unit → code via superpowers integration; TDD discipline; halt protocol
- **`using-mega-sdd` anchor skill** — session-start injected for SDD-scoped sessions (scoped triggers)
- **SessionStart hook** — injects anchor when SDD signals detected in CWD; surfaces install hint if superpowers missing
- **Vendored superpowers fallback** — `_vendored/` namespace ensures bolts execute even when superpowers plugin not installed; `scripts/sync-superpowers.sh` automates refresh

### Changed

- `grand-design-spec` skill → `generate-intent` (absorbs `from-prompt` mode as `--from-prompt` flag)
- `flow` skill → `orchestrate-flow` (extended routing for new SDD phases; 3-skill chain cap preserved)
- `drift-detect` skill → `detect-drift`
- `vault-diff` skill → `diff-vault`
- `update` skill → `update-plugin` (now also runs dep-doctor)
- All version frontmatters → `1.0.0`

### Removed

- `from-prompt` skill (absorbed into `generate-intent`)
- `from-prompt` command (deprecated alias retained for back-compat, removed in v1.2)

### Deprecated

- `grand-design-spec` listing in marketplace (will be removed in 2 release cycles)
- `/mega-sdd:from-prompt` command alias (use `--from-prompt` flag instead)

### Marketplace

- Added `mega-sdd` entry (version 1.0.0)
- Marked `grand-design-spec` entry as deprecated, pointing to `mega-sdd`

### Documentation

- Plugin README rewritten with Mermaid flow diagram + ASCII fallback + procedure cheat-sheet
- New CLAUDE.md (contributor guidelines for AI agents)
- New tests/ tree with skill-triggering fixtures + hook + vendoring tests
- New `docs/mega-sdd/` output convention dirs

### Migration

Existing `grand-design-spec` users:
1. `/plugin install mega-sdd`
2. Replace `grand-design-spec:` → `mega-sdd:` in any scripts/docs (use rename table in plugin README)
3. Existing vaults are compatible — no manual conversion needed
4. To benefit from binding gate on existing vaults: run `/mega-sdd:scan-codebase` then `/mega-sdd:bind-codebase <vault>`

## [0.15.0] — 2026-05-10

The prompt-input release. Adds `/grand-design-spec:from-prompt` so users can start from a free-text brief instead of a PRD doc — eliminating the ChatGPT-to-Claude round-trip for prompt engineering. The orchestrator's `flow` chain becomes default-on across all rules: every invocation now walks the lifecycle to its natural endpoint without opt-in friction.

### Skill version moves

- `from-prompt`: **NEW at 0.1.0** (brief → seed-PRD elaborator)
- `flow`: 0.1.0 → **0.2.0** (Rule 0 + default-on chaining for Rules 1, 2, 4, 5, 6 + arg parsing extension for free-text prompts)
- `grand-design-spec`: unchanged at 0.10.0 (consumes seed-PRD.md as a normal source — no behavior change needed)
- `resolve-oq`: unchanged at 0.4.0
- `vault-diff`: unchanged at 0.3.0
- `drift-detect`: unchanged at 0.3.0

### Added

- **`/grand-design-spec:from-prompt`** — converts a free-text brief into `<output-dir>/source/seed-PRD.md`. Workflow: capture brief verbatim → adaptive Q&A across 10 fixed taxonomy topics (skip topics already covered in brief, hard cap at 10 questions) → compose seed-PRD with citation markers (`(brief)` / `(Q&A §N)` / `(unspecified)`) on every claim → write to disk. Substance prompts always interactive even with `--auto`. Halt protocol: emits `blocker` (type=`oq_blocker`, tag=`OQ-FROMPROMPT-0`) when brief is unparseable in `--auto` mode.
- **Rule 0 in `flow`'s decision matrix** — fires when no vault and no PRD file detected and prompt arg given. Auto-chains `from-prompt → grand-design-spec → resolve-oq (scope=p1-only)`. drift-detect not applicable (mode=new for prompt-input vaults).
- **Default-on chaining for `flow` Rules 1, 2, 4, 5, 6** — `resolve-oq` and `drift-detect` (when applicable) now chain automatically instead of being opt-in/conditional. User skips individual steps via `Edit plan: skip step N` in Step 3 confirmation. Plan-confirmation step still surfaces full chain before any skill runs.
- **Free-text arg parsing in `flow` Step 0** — args >20 chars without path-like characters are recognized as prompts (persisted as `EXPLICIT_PROMPT`). Borderline ambiguous args trigger `AskUserQuestion` clarification.
- **`seed-PRD` as a recognized `vault.json.source_documents[].type`** value — documented in `from-prompt/SKILL.md` references; `vault-contract.md` §schema treats `type` as free-form so no contract change required.

### Changed

- **`flow/SKILL.md`** Step 0 arg-parsing block extended to recognize free-text prompts; Decision matrix block fully replaced with v0.2 7-rule revision (adds Rule 0, marks Rules 1/2/4/5/6 as default-on); version 0.1.0 → 0.2.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.14.0 → 0.15.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:from-prompt` row, update lifecycle diagram (from-prompt as new entry point), update repo structure with `from-prompt/` skill dir, bump changelog footer.

### Backward compatibility

- v0.14 vaults continue to work unchanged. seed-PRD.md is just another source for `grand-design-spec` — no schema or vault structure changes.
- Direct invocation of `flow` with file/dir args works exactly as v0.14 (Rule 0 only fires when args are free text).
- Direct invocation of `flow` without args produces a Rule 7 STOP if WORK_DIR is empty — same as v0.14, with updated error message mentioning prompt option.
- Default-on chaining is a behavior change for users who relied on opt-in chains in v0.14. Mitigation: plan-confirmation step shows the full chain; user edits to skip steps they don't want. No anti-halu rail changes.
- Direct invocation of any sub-skill (`from-prompt`, `grand-design-spec`, etc.) without `flow` is unchanged — full interactive behavior when `--auto` is not passed.

### Notes

- The orchestrator stays **stateless by design**. Re-running `flow` re-inspects CWD; no `.gds-state.json` is written.
- **Hard cap of 3 skills per chain** stays at 3 (verified across all 7 rules including the new Rule 0).
- **`flow` does NOT run sub-skills in parallel** — sequential only.
- Audit findings deferred to v0.16+: vault evolution from a new prompt (`from-prompt → vault-diff` chain), multi-turn brief refinement, seed-PRD versioning across runs, voice-input briefs, reorder-and-edit-args plan editing in flow.

## [0.14.0] — 2026-05-10

The agentic upgrade. Adds `/grand-design-spec:flow`, a multi-skill lifecycle orchestrator that turns the plugin from "4 separate tools" into "one workflow." Inspects CWD, proposes a sub-skill chain (e.g., "vault-diff → resolve-oq for new P1s"), confirms once, executes in `--auto` mode. Anti-halu rails preserved by composition — every rail lives in a sub-skill, untouched.

### Skill version moves

- `flow`: **NEW at 0.1.0** (lifecycle orchestrator)
- `grand-design-spec`: 0.9.0 → **0.10.0** (added `--auto` flag for logistical prompts)
- `resolve-oq`: 0.3.0 → **0.4.0** (added `--auto` for logistics; per-OQ choices stay interactive)
- `vault-diff`: 0.2.0 → **0.3.0** (added `--auto` flag; conflicts emit `blocker` type=`diff_conflict`)
- `drift-detect`: 0.2.0 → **0.3.0** (added `--auto` flag; skips interactive walkthrough; framework mismatch emits `blocker` type=`drift_framework_mismatch`)

### Added

- **`/grand-design-spec:flow`** — the orchestrator command. Inspects WORK_DIR for vault, PRD, codebase signals, P1 count, mode-migration trigger, git state. Applies a 7-rule decision matrix to build a proposed chain (max 3 skills). Single user confirmation (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` in v0.1; reordering deferred. Stateless — resumption is just re-invoking. Pauses on `blocker` artifacts; surfaces YAML verbatim in chat.
- **`§halt-protocol`** in `references/vault-contract.md` — unified `blocker` envelope with three types: `oq_blocker` (per v0.11), `diff_conflict` (vault-diff conflicts), `drift_framework_mismatch` (drift-detect framework mismatches). Schema, field rules, type-specific guidance, multi-blocker array form, and v0.11 → v0.14 backward-compat note.
- **`--auto` convention** documented in CONTRIBUTING.md — required for any future skill with prompts. Skips logistical prompts (paths, modes, scopes); never skips substance prompts (stakeholder answers, conflict resolutions); emits `blocker` when halted autonomously.

### Changed

- **`00-index.md` template Halt protocol section** — emits `blocker: type: oq_blocker` (new unified envelope) instead of legacy `oq_blocker:` form. Backward-compat note appended for AI consumers reading v0.13 vaults.
- **`grand-design-spec/SKILL.md`** — adds `## --auto flag` section before Workflow describing how Step 0–0.7 prompts default in `--auto` mode (output folder slug-derived, mode inferred from codebase signals, PRD_STATUS=draft, OUTPUT_MODE=compact). Anti-halu rails (Figma "do you have screenshots?", destructive overwrite confirmation, OQ tagging, source citation) NEVER bypassed.
- **`resolve-oq/SKILL.md`** — adds `## --auto flag` section. Substance prompts (per-OQ Resolve/OOS/Defer/Skip choice, cross-cutting landing) ALWAYS interactive. Logistics (vault path, resume detection, scope, lock ack default) auto-defaulted.
- **`vault-diff/SKILL.md`** — adds `## --auto flag` section. Conflicts (Resolved-OQ, Decision) emit `blocker` (type=`diff_conflict`) and pause. Auto-applies non-conflict changes ≤ 50; emits `blocker` if change count exceeds cap (per OQ-FLOW-3 spec decision).
- **`drift-detect/SKILL.md`** — adds `## --auto flag` section. Skips Step 5 interactive walkthrough; writes `DRIFT-REPORT.md` only (no `DRIFT-ACTIONS.md` — deliberate human decision). Framework mismatch emits `blocker` (type=`drift_framework_mismatch`).
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.13.0 → 0.14.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:flow` to commands tables, update lifecycle diagram (flow as recommended entry point), update repo structure with `flow/` skill dir.

### Backward compatibility

- v0.13 vaults continue to work read-only.
- AI consumers reading vault halts should accept both `oq_blocker:` (legacy v0.11–v0.13 form) and `blocker: type: oq_blocker` (new v0.14 form) for one release cycle. v0.15+ may drop legacy support.
- Direct sub-skill invocation (without `flow`) is unchanged when `--auto` is not passed — full interactive behavior per v0.13.
- `flow` is opt-in. Users who prefer manual sub-skill invocation can ignore it entirely.

### Notes

- The orchestrator is **stateless by design**. No `.gds-state.json` is written. This simplifies the contract (every flow run re-inspects CWD) but means "did I forget drift-detect?" recall depends on user re-running flow.
- **Hard cap of 3 skills per chain** prevents runaway chains. Beyond 3, orchestrator surfaces and asks for explicit confirmation.
- **`flow` does NOT run sub-skills in parallel** — sequential only. Sub-skills modifying the same vault would race otherwise.
- Audit findings deferred to v0.15+: state file with lifecycle position tracking (Approach 2 from brainstorming), reorder-and-edit-args plan editing, scheduled-mode drift-detect via `schedule` skill, self-critiquing loops (Approach 4 from brainstorming).

## [0.13.0] — 2026-05-09

Driven by the ship-readiness audit at `docs/superpowers/specs/2026-05-09-plugin-audit-design.md`. Closes 3 HIGH and 4 MED audit findings. Acknowledges that v0.11 vault.json parity was incomplete (only `resolve-oq` got write-back; `vault-diff` was missed) and lands the fix.

### Skill version moves

- `grand-design-spec`: 0.8.0 → 0.9.0 (references shared `vault-contract.md`, adds OQ_BLOCKER halt-protocol self-check)
- `resolve-oq`: 0.2.0 → 0.3.0 (removes `lock-vault` forward-references, adds vault.json count-match self-check)
- `vault-diff`: 0.1.0 → 0.2.0 (**adds Step 6.5 vault.json refresh** — closes the v0.11 parity gap)
- `drift-detect`: unchanged at 0.2.0 (documentation-only change: explicit `vault.json` reconciliation boundary)

### Added

- **`references/vault-contract.md`** (M-1, L-8, L-9) — single source of truth for the `vault.json` schema, OQ tagging conventions, status marker semantics, ID stability rules, and "Skill instruction language" boilerplate. All 4 skills now reference it instead of duplicating content.
- **`vault-diff` Step 6.5 — Refresh `vault.json`** (H-1) — after applying approved changes in Step 6, regenerate the manifest from post-apply markdown so `entities[]`, `flows[]`, `adrs[]`, `open_questions[]`, and `open_questions_summary` reflect the new state. Step 8 self-check gains 4 vault.json invariants.
- **`drift-detect` `vault.json` reconciliation boundary** (H-2) — Step 6 now explicitly documents that drift-detect produces reports only and never regenerates `vault.json`. Vault.json regen happens via `resolve-oq` (for OQ-tagged actions) or manual edit + `grand-design-spec` re-run (for entity/flow/ADR additions). Per audit OQ-AUDIT-1 decision: explicit boundary, not auto-reconcile.
- **Template compact/full markers** (M-5) — `01-overview`, `02-architecture`, `03-data-model`, `04-flows`, `05-decisions` templates now carry `<!-- compact-skip -->` and `<!-- full-only -->` HTML comments around mode-conditional content. Replaces 5 memorized runtime transformation rules with mechanical markers. `00-index` and `06-constraints` have no compact-conditional content (unchanged).
- **`grand-design-spec` Step 4 self-check** (M-6) — verifies `00-index.md` contains the "Halt protocol for autonomous runs", "Parallel-work guidance", and "Companion skills for vault evolution" sub-sections per template.
- **`resolve-oq` Step 4 self-check** (M-8) — verifies `vault.json.open_questions_summary.total` matches markdown roll-up; verifies promoted ADRs appear in `vault.json.adrs[]`.
- **`CONTRIBUTING.md`** (M-3) — documents the versioning rule (independent semver per skill, with CHANGELOG enumerating per-skill moves), commit-message scopes, tagging discipline, new-skill checklist, and spec/plan workflow.

### Removed

- **`lock-vault` forward-references** (H-3) — `resolve-oq/SKILL.md` previously mentioned a `lock-vault` skill "(when available)" twice. Replaced with explicit manual-edit instructions for `00-index.md` Vault Lock Status. Building a real `lock-vault` skill is a v0.14+ candidate.

### Changed

- `plugin.json` and `marketplace.json` plugins[0].version bumped 0.12.1 → 0.13.0 (skill behavior changes + new file structure).
- `grand-design-spec/SKILL.md` body shrinks ~60 lines as the duplicated `vault.json` schema and OQ tagging convention move to `vault-contract.md`. Net change: smaller skill body + one new reference file.

### Backward compatibility

- Existing v0.12 vaults continue to work read-only.
- Re-running `vault-diff` against a v0.12 vault now produces an updated `vault.json` (previously skipped). If the v0.12 vault was created before vault.json was introduced (pre-v0.11), Step 6.5 generates a fresh manifest from the markdown.
- Skills that don't bump (drift-detect) maintain the same input/output contract.
- The new `references/vault-contract.md` is referenced by skills but loaded on-demand — no eager-load cost on existing flows that don't touch the schema.

### Notes

- The v0.11 CHANGELOG entry implied vault.json parity that didn't exist for `vault-diff`. v0.13 explicitly closes that gap and the CHANGELOG now enumerates per-skill version moves to prevent the same drift.
- Audit findings deferred to v0.14+: a real `lock-vault` skill (H-3 alternative), template footer extraction (L-10), trigger-phrase canonical source (L-11), OQ category enumeration (M-2), `grand-design-spec/SKILL.md` progressive disclosure (L-12), tag backfill for v0.7-v0.12 (L-7).

## [0.12.1] — 2026-05-09

### Added

- **`/grand-design-spec:update`** — convenience command that pulls the latest plugin from `origin/main` (fast-forward only), shows before/after versions, and instructs the user to finish with the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. Custom slash commands can't invoke built-ins, so the cache-refresh step stays explicit.

### Changed

- `plugin.json` and `marketplace.json` plugins[0].version bumped 0.12.0 → 0.12.1 (additive command).

## [0.12.0] — 2026-05-09

Surfacing companion skills as user-typeable slash commands.

### Added

- **`/grand-design-spec:grand-design-spec`** — main vault generator now invokable from autocomplete with optional `[prd-path] [figma-url]` arguments.
- **`/grand-design-spec:resolve-oq`** — interactive Open Questions resolver, callable directly with `[vault-path] [optional OQ tag]`.
- **`/grand-design-spec:vault-diff`** — vault ↔ revised PRD diff report, callable with `[old-vault] [new-prd]`.
- **`/grand-design-spec:drift-detect`** — vault ↔ codebase reconciliation, callable with `[vault-path] [codebase-root]`.

### Why

Until v0.11, the three companion skills (`resolve-oq`, `vault-diff`, `drift-detect`) were Claude-invoked only via the Skill tool — they did not appear in the `/` autocomplete menu, so users had to ask Claude in prose to trigger them. v0.12 adds explicit command files in `plugins/grand-design-spec/commands/` that mirror each skill, making the full lifecycle (generate → resolve → diff → drift) discoverable from the slash menu.

### Changed

- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.11.0 → 0.12.0 (additive feature: command surface).

### Backward compatibility

- No skill behavior changed — command files are thin wrappers that delegate to the existing skills.
- Users on v0.11 can keep invoking skills via prose; v0.12 simply exposes a faster discovery path.

## [0.11.0] — 2026-05-09

Driven by audit findings from the TimeOff smoke-test dogfood (commit `e6bada4`). Three Tier-1 refinements + two Tier-2 quick wins, focused on bridging vault generation to actual consumption by AI dev tools.

### Added

- **`vault.json` machine-readable manifest** (R1, generated alongside the 7 markdown files in Step 3). Structured index of entities, flows, ADRs, OQs (with state + priority + category + resolver_owner), source documents, and Step-2 design-system flags. Markdown stays human-authoritative; JSON optimizes machine consumption — AI dev tools load context in <1K tokens instead of brute-parsing 25K+ of prose. Schema documented inline in SKILL.md Step 3. Step 4 self-check verifies markdown ↔ JSON consistency on every regeneration.
- **`OQ_BLOCKER` halt artifact format** for autonomous AI consumers (R2). Defined in `00-index.md` template "Halt protocol for autonomous runs" sub-section. When an AI agent hits an unresolved P1 OQ in non-interactive mode, instead of silent halt it emits a structured YAML artifact with `tag`, `priority`, `blocking_task`, `resolver_owner`, `resolver_route`, `vault_version`. Agent runners can route this to ticketing / Slack / on-call pages reliably. Single-blocker and multi-blocker formats both defined.
- **Mode migration trigger** (R3) — new Vault Lock Status field `mode_migrate_after`. Captures the event that flips a `mode=new` vault to `mode=existing` (e.g., "first commit on main", "first prod deploy", "sprint-1 demo"). Step 0.5 of `grand-design-spec` now prompts for this when mode=new. After trigger fires, user manually flips mode + bumps version + adds Changelog, OR runs `vault-diff`. Once flipped, `drift-detect` becomes applicable.
- **Parallel-work guidance** in `00-index.md` template (R5) — when P1 OQs block a task, lists artifact types the dev/AI can still produce in parallel (test specs from DoD, scaffolded ORM models with TODO markers, UI stubs, OOS confirmations). Each parallel artifact must carry the OQ tag(s) it depends on so it's revisited on resolution.
- **Cross-cutting OQ multi-doc landing pattern** in `resolve-oq` Step 2c (R7). When a single OQ resolution legitimately affects 3+ docs (tech-stack, multi-tenancy, auth, compliance), skill writes the primary entry once and adds terse cross-reference lines in other affected docs (`> Resolves OQ-{tag}: see {primary-doc}.md#{anchor}`). All point back to the OQ tag for audit. Heuristic for "cross-cutting" documented inline.
- **`vault.json` write-back in `resolve-oq`** — every Resolve / Out-of-Scope / Defer outcome updates the manifest's `open_questions[]` status field, recomputes `open_questions_summary` counts, and (for promoted Resolve) appends new ADRs to `adrs[]`. Keeps machine-readable index in sync with markdown.
- **`drift-detect` mode-migration awareness** — when run on a `mode=new` vault, surfaces the `mode_migrate_after` trigger so the user knows what to do before re-running. Better failure mode than the previous flat "this skill doesn't apply".

### Changed

- **`grand-design-spec` SKILL.md** version bumped 0.7.0 → 0.8.0 (added `vault.json` generation in Step 3 + Step 4 self-check + Step 0.5 migration trigger + halt protocol section in template).
- **`resolve-oq` SKILL.md** version bumped 0.1.0 → 0.2.0 (cross-cutting OQ multi-doc landing + vault.json write-back).
- **`drift-detect` SKILL.md** version bumped 0.1.0 → 0.2.0 (mode-migration awareness in Step 0).
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.10.0 → 0.11.0 (skill behavior changes).
- **`00-index.md` template** — Vault Lock Status gains `mode_migrate_after` field; Implementation Notes section gains "Halt protocol for autonomous runs" + "Parallel-work guidance" sub-sections.

### Backward compatibility

- Existing v0.10 vaults continue to work read-only. Companion skills (`resolve-oq`, `vault-diff`, `drift-detect`) handle the absence of `vault.json` gracefully — they fall back to parsing markdown.
- To upgrade an existing v0.10 vault to v0.11: re-run `/grand-design-spec:vault-diff` against the same PRD; the diff session writes `vault.json` and adds `mode_migrate_after` to Vault Lock Status. Or edit `00-index.md` manually.
- Existing OQs resolved before v0.11 carry no `vault.json` entry; the next resolve-oq round repopulates the manifest from current markdown state.

### Notes

- The audit that drove this release: vault generation works (TimeOff smoke test, 1187 lines, 48 OQs, 95% anti-halu compliance), but AI dev consumption was the bottleneck — 25K+ tokens to load full markdown, no halt protocol for autonomous runs, no migration path for greenfield projects, fuzzy boundaries on cross-cutting OQ resolution. v0.11 directly addresses these.
- Tier 2 items deferred to v0.12+: `extract-context <flow-id>` skill (return min vault subset for a specific flow), DoD → test spec auto-conversion, pre-commit drift-detect integration, vault → tickets generator.
- Mega Rencana (`mode=existing`, mobile-app, ID) and TimeOff (`mode=new`, web-app, EN) smoke fixtures remain valid as v0.11 examples; regenerating them produces vault.json automatically.

## [0.10.0] — 2026-05-08

### Added
- **`drift-detect` skill (new, v0.1.0)** — detects drift between a `mode=existing` vault (target spec) and live codebase (current reality). Heuristic scan of entities, flows, endpoints, and decisions; produces a structured `DRIFT-REPORT.md` with confidence-rated findings. Closes the loop between vault generation and shipped code for revamp / extension projects. Invoke with `/grand-design-spec:drift-detect`.
- **Eight drift outcome categories**: Missing in code, Missing in vault, Name drift, Type drift, Behavior drift, Decision violation, Decision unwritten, Confirmed match.
- **Confidence ratings per finding** — `high` (exact name + type match found / not-found), `medium` (similar names but different signatures), `low` (heuristic keyword guess). Low-confidence findings carry explicit "verify manually" caveats.
- **Direction-neutral framing** — every finding presents vault state and code state side-by-side. The skill never says "code is wrong" or "vault is stale"; only "they disagree, here's where each lives".
- **Decision violations & unwritten ADRs surfaced PRIORITY-1** — these correspond to compliance / architectural debt and most often require stakeholder review.
- **Framework auto-detection** — skill identifies the codebase framework (Laravel, Rails, Spring, Express, Django, Flutter, etc.) via lockfile / manifest signatures and proposes default scope dirs. User confirms or overrides.
- **Drift scope selection** — `full` (default), `schema-only`, `flows-only`, `decisions-only`, or `single-doc`.
- **`DRIFT-ACTIONS.md` artifact** — captured user decisions per finding (split into Code-side actions and Vault-side actions). The skill never executes code changes; it produces an actionable list for engineering team follow-up.
- **OQ cross-reference scan** — detects when codebase mentions `OQ-{CODE}-{N}` tags and flags any references to still-open OQs as "code references unresolved OQ".

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.9.0 → 0.10.0 (new skill addition).

### Notes
- The skill is **heuristic**, not a static analyzer. False positives and false negatives both happen. Treat findings as triggers for human review, not verdicts.
- Decision compliance is the lowest-confidence axis — keyword-based detection only catches obvious cases. For comprehensive compliance, this skill complements (not replaces) code review and architecture review.
- The skill writes report artifacts but **never modifies the codebase or the vault directly**. All actions are captured for deliberate human follow-up.
- For `mode=new` projects there's no codebase to scan — the skill bails politely and points to `vault-diff` if the user is comparing PRD versions.
- The four skills now form a complete vault lifecycle: `grand-design-spec` (initial generation) → `resolve-oq` (interactive OQ resolution) → `vault-diff` (vault evolution across source revisions) → `drift-detect` (vault vs codebase reconciliation for `mode=existing`).

## [0.9.0] — 2026-05-08

### Added
- **`vault-diff` skill (new, v0.1.0)** — evolves an existing vault when the PRD/BRD/Figma source revisions, without losing resolved OQs, ADR provenance, or Changelog history. Invoke with `/grand-design-spec:vault-diff`. The naive alternative ("delete vault, regenerate") destroys every captured stakeholder decision and starts the OQ list from zero — this skill exists specifically to make vaults survive past sprint 1.
- **Eight diff outcome categories** with explicit handling rules: Auto-resolved OQ, New OQ, Added (entity/flow/decision/section), Changed, Removed (annotated, never deleted), Resolved-OQ conflict, Decision conflict, Unchanged.
- **`VAULT-DIFF.md` artifact** — the skill writes a structured diff report into the vault directory before applying changes. Persistent record the user reviews offline; conflicts surfaced at the top of the file so reviewers see them first.
- **Conflict-first walkthrough** — Step 5 prioritizes Resolved-OQ conflicts and Decision conflicts before any other category. User decision required for each (Supersede / Keep vault / Capture both / Skip). Skill never auto-decides on conflicts.
- **Diff scope selection** — `full` (default), `oq-only` (fast pass for minor PRD clarifications), or `specific-docs` (surgical update of named docs only).
- **Removed-content preservation** — entities/flows/decisions removed from new PRD are NOT deleted from vault; they get a `> **Removed in v{X.Y}**` banner. The vault retains history; the Changelog records the removal.
- **Identifier stability** — OQ tags, flow IDs, ADR D-XXX numbers all survive the diff. New entries get next-available IDs; existing IDs preserved in place.
- **Git safety check** — Step 0 runs `git status` and recommends commit-before-diff so the diff session is rollback-able. Doesn't refuse without git, but warns.

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.8.0 → 0.9.0 (new skill addition).

### Notes
- The skill never auto-resolves conflicts. "Auto-resolve all" requests are refused — conflicts (vault state vs new PRD) are exactly the cases requiring human judgment.
- Major scope shifts (>50% removed entities, >30% added, project name divergence) trigger a "this looks like a different project, are you sure?" prompt before proceeding.
- LOCKED vaults require explicit unlock confirmation before diff is applied (re-sign-off needed after).
- The three skills now form a complete vault lifecycle: `grand-design-spec` (initial generation) → `resolve-oq` (interactive OQ resolution) → `vault-diff` (evolution across source revisions).

## [0.8.0] — 2026-05-08

### Added
- **`resolve-oq` skill (new, v0.1.0)** — interactive resolver for Open Questions in an existing vault. Companion to the main `grand-design-spec` skill. Walks the OQ roll-up by priority (P1 → P2 → P3), captures stakeholder answers per OQ, updates the vault, and bumps version + Changelog. Invoke with `/grand-design-spec:resolve-oq`.
- **Four resolution outcomes per OQ**: `Resolve` (capture answer inline or promote to a target section like new ADR / field constraint), `Out of Scope` (move to OOS section with rationale), `Defer` (keep open with stakeholder + target date), `Skip` (no change, return next round).
- **Resume support** — re-running the skill on a partially-resolved vault detects prior rounds via Changelog entries and offers to continue from current state.
- **Resolution scope selection** — `p1-only` (focused first pass), `p1-then-p2`, `all-priorities`, `by-category` (group by roll-up category, useful when each category aligns with a different stakeholder), or `single-oq` (jump to a tag).
- **Auto-classification of resolution destination** by OQ code prefix (`OV-` → 01-overview, `AR-` → 02-architecture, `DM-` → 03-data-model, `FL-` → 04-flows, `DC-` → 05-decisions, `CN-` → 06-constraints), with explicit user override allowed.
- **OQ tag preservation** through resolution — every OQ identifier survives via `[x]` resolved markers, `[~]` out-of-scope markers, or stays `[ ]` with a Deferred annotation. Full audit trail of what was decided when.
- **Atomic per-OQ edits** — bail-out at any time preserves partial progress for the next run.

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.7.0 → 0.8.0 (new skill addition).

### Notes
- The new skill never auto-fills answers. Refusing "answer all OQs for me" is a hard guarantee — the skill exists to capture **stakeholder** input, not Claude's guesses. Offer Defer instead.
- Resolution density adapts to the parent vault's `OUTPUT_MODE`. Compact vaults get inline resolutions or 1-paragraph promoted ADRs; full vaults get multi-section promoted ADRs.
- The `grand-design-spec` skill itself remains at v0.7.0 — no changes to the main vault generator in this release.

## [0.7.0] — 2026-05-08

### Added
- **`OUTPUT_MODE=compact|full` flag (Step 0.7).** New mandatory step after PRD status flag. Captures the verbosity tier of vault output. Drives Step 3 generation rules per the Output mode policy table. Default: `compact`.
  - `compact` (default) — table-first, prose-cut, ~40% lighter token output. 1-line TL;DR header, API contracts as tabel (skip JSON example unless payload non-trivial), DBML-only entity descriptions, ADR as 1-paragraf format, OQ entries as 1-line, glossary skips generic IT terms.
  - `full` — verbose, prose-rich. 3-line TL;DR header, full request/response JSON per endpoint, prose entity descriptions alongside DBML, multi-bullet ✅⚠️ consequences per ADR. For audiences including non-technical reviewers (BO, legal, compliance).
- **Output mode policy table** in `## File-by-file content guide` mapping per-doc behavior (TL;DR, API contracts, entity descriptions, flow blocks, decision blocks, glossary, OQ entries) across both modes. Replaces the prior vague "as simple as possible" guidance with concrete, measurable rules.
- **Auto-default conditions** — skill picks `compact` without asking when user explicitly requested terse output or runs in autonomous / no-pause mode. Echoes auto-default with reason.
- **Hard invariants section** — explicit list of anti-hallucination guarantees preserved in BOTH modes (source citation, OQ tag + priority, DoD per flow, decision source, Out of Scope never empty). Compact mode never weakens grounding.
- **Step 4 self-check items** for output mode compliance — 8 new checks covering compact-mode formatting + 6 hard-invariant checks that apply regardless of mode.
- **`Output mode` field in `00-index.md > Vault Lock Status`.** Surfaced to downstream AI consumers + readers so they know which verbosity tier the vault was generated in.
- **Step 5 hint** — when `compact` mode used, summary mentions opt-in to `full` mode for re-run if needed.

### Changed
- **`## Length & simplicity policy`** renamed to **`## Output mode policy`** and rewritten from 4-bullet vague guidance to a 10-row aspect-by-mode tabel + invariants block + audience principle.
- **Per-doc TL;DR template** updated to show both 1-line (compact) and 3-line (full) format with mode markers.
- **`02-architecture.md` API contracts guidance** — adds explicit compact behavior (tabel default, JSON only for non-trivial payloads) vs full behavior (full JSON per endpoint).
- **`03-data-model.md` guidance** — compact = DBML + 1-line `Purpose:` per entity, skip prose section. Full = DBML + per-entity prose + field-level validation tabel.
- **`04-flows.md` guidance** — compact skips Preconditions/Postconditions blocks (derivable from steps + DoD), keeps Steps + DoD + cross-cutting handoffs. Full = all template sections.
- **`05-decisions.md` guidance** — compact = 1-paragraf ADR format, full = multi-section block with Status/Date/Context/Decision/Consequences/Source.
- **`00-index.md > Glossary` and `> Open Questions roll-up`** — compact mode cuts generic IT terms from glossary, OQ entries become single-line. Full mode preserves prior verbose format.
- **`SKILL.md` frontmatter** version bumped 0.6.0 → 0.7.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.6.0 → 0.7.0.

### Backward compatibility
- v0.6 vaults remain valid. No migration step.
- v0.7 with `OUTPUT_MODE=full` produces output **structurally identical to v0.6** (modulo the new `Output mode` line in Vault Lock Status). Use `full` to retain v0.6 verbosity verbatim.
- v0.7 with `OUTPUT_MODE=compact` (the new default) produces a leaner vault that preserves every source citation, every Open Question, every Definition of Done, every cross-cutting handoff — only narrative scaffolding is cut.
- The four v0.6 design-system detection flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) and conditional sections continue to work unchanged in v0.7. Output mode only controls verbosity per-section, not section presence.

### Notes
- Anti-halu invariants are **hard guarantees** in both modes. Compact mode trades narrative scaffolding for token efficiency, never grounding strength. A compact-mode vault and a full-mode vault generated from the same PRD will list the same OQs (with same tags + priorities), cite the same sources, and contain the same DoD checklists — only the prose density differs.
- The "audience principle" is documented inline: compact targets builders (architect, dev, QA) who can read tabel + DoD without prose hand-holding; full targets cross-functional reviewers (PM, BO, legal, compliance) who need narrative context.

## [0.6.0] — 2026-05-08

### Added
- **Optional design-system coverage for UI projects.** When source documents (PRD / Figma via MCP / uploaded tokens files) explicitly contain design-system content, the vault now emits two new sections:
  - **`02-architecture.md > UI components & patterns`** sub-section under each UI layer. Components table (spec voice) + Patterns prose (guide voice — when-to-use rules). Triggered by `HAS_UI_COMPONENTS=true` flag from Step 2 detection.
  - **`06-constraints.md > Design system`** top-level section alongside Technical / Business / NFR. Three sub-blocks (Tokens / Accessibility / Voice & brand), each independently conditional on its specific flag.
- **Step 2 design-system content detection.** Skill scans all sources for explicit mentions of UI components, design tokens, a11y standards, and voice/brand rules. Persists four flags: `HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`. Flags drive Step 3 conditional generation.
- **Source merge rules** when multiple design-system sources are provided (Figma + tokens.json, multiple Figma URLs, etc.). Higher priority wins for the same value (Figma > tokens file > PRD-stated). Equal-precedence disagreement → emit `OQ-CN-{N} [P1]` with both quoted values; never silent pick.
- **Conditional UI/UX or FE Dev reading path** in `00-index.md`. Appears only when at least one of the new design-system sections is present.
- **Conditional design-system glossary entries** in `00-index.md` (design tokens, design system, WCAG, a11y, semantic HTML). Appear only when terms are used elsewhere in the vault.
- **Six new Step 4 self-check items** for design-system grounding. Apply only when at least one design-system section is present in the vault.

### Changed
- **Anti-hallucination rule extended** from v0.5's "no invented content within sections" to v0.6's "no invented sections." Section presence is determined by source coverage alone — `PROJECT_SHAPE` is NOT a trigger. Vault never auto-creates design-system sections because shape inference suggests UI. Vault never defaults to industry standards (WCAG 2.1 AA, Material Design, iOS HIG, Tailwind defaults) when sources are silent.
- **Push-back rules** gain explicit "design-system absence is acceptable" sub-section. Skill MUST NOT prompt the user for missing design-system sources. PRD silent on FE → vault silent on FE. No exception, no questioning.
- **`SKILL.md` frontmatter** version bumped 0.5.0 → 0.6.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.5.0 → 0.6.0.

### Backward compatibility
- v0.5 vaults remain valid. No migration step.
- v0.6 for projects without design-system source coverage produces output **identical to v0.5**. The four detection flags simply stay `false` and no sections are added.
- v0.6 with full design-system coverage adds two sub-sections, one top-level section, one reading path, and up to five glossary entries — all conditional, all source-cited.

### Notes
- The four detection flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) are independent. A project might surface tokens but not components (e.g., PRD spells out brand colors but Figma is unavailable), and vice versa. Each flag is independently evaluated.
- Existing-codebase reconciliation for design system remains the downstream AI consumer's job. Vault generator never reads codebase, even when `IMPLEMENTATION_MODE=existing` and a design-system package exists in the repo.

## [0.5.0] — 2026-05-08

### Added
- **`PRD_STATUS=final|draft` flag (Step 0.6).** New mandatory step after implementation mode flag. Captures whether the source PRD/BRD is signed-off (`final`) or still in flux (`draft`). Drives gap-handling and push-back behavior throughout the workflow.
  - `final` → skill never pauses for clarification, even when gap count is large or PRD is contradictory. All ambiguities funnel into Open Questions roll-up. User triages OQ list with stakeholder offline, post-vault.
  - `draft` → existing behavior preserved. Skill pauses when gap count > 10, surfaces contradictions inline, asks for resolution before generating.
- **`PRD status` field in `00-index.md > Vault Lock Status`.** Surfaced to downstream AI consumers (Claude Code, Cursor) so they know the OQ list is the authoritative gap inventory under `final` mode.
- **PRD source file annotation.** `<filename> — FINAL | DRAFT` marker in Vault Lock Status PRD source line.

### Fixed
- **Tool name references for Claude Code distribution.** SKILL.md previously used Claude.ai sandbox API names that don't resolve under `/plugin install`:
  - `tool_search(query="figma")` → `ToolSearch` with `query: "figma"` or `query: "select:..."` syntax.
  - `ask_user_input_v0` → `AskUserQuestion`.
  - `present_files` → no tool needed in Claude Code (files already on disk after Step 3); fall back kept for Claude.ai sandbox.
  - `view` (template read) → `Read`.
- **Step 3 template path stale post-v0.4.0 restructure.** Plugin-installed skills no longer land at `~/.claude/skills/`. Updated to use `${CLAUDE_PLUGIN_ROOT}/skills/grand-design-spec/references/templates/` as the primary path. Manual-install and Claude.ai sandbox paths kept as fallbacks.
- **Push-back rules** restructured to clearly distinguish always-push-back cases (Figma missing, "just guess the rest", path mismatch) from `draft`-only cases (missing sections, contradictions, large gap count).
- **`03-data-model.md` template typo**: "follow project conventions Han already confirmed" → "follow project conventions you've already confirmed with the team".
- **`.gitignore`**: removed project-specific `mega-rencana-spec/` entry (test fixture leak).

### Changed
- **`marketplace.json`**: dropped redundant top-level `version` field. Marketplace itself isn't versioned; each plugin entry now owns its version (`plugins[].version: "0.5.0"`).
- **`plugin.json`** version bumped 0.4.0 → 0.5.0.
- **`SKILL.md` frontmatter** version bumped 0.4.0 → 0.5.0.
- **README "What happens next"** updated with the new PRD-status question.

### Notes
- `final` mode does NOT relax anti-hallucination guarantees. Skill still refuses "just guess the rest" — `final` only changes whether the skill pauses to ask stakeholder synchronously, not whether Claude can fill in blanks. Gaps remain Open Questions, never silently filled.
- For `final` mode contradictions, the skill writes OQ entries with both PRD quotes side-by-side so stakeholder can rule which is canonical without re-reading the original doc.

## [0.4.0] — 2026-05-08

### Changed
- **Repository restructured to Claude Code Plugin Marketplace format.** Added `.claude-plugin/marketplace.json` at repo root and `plugins/grand-design-spec/.claude-plugin/plugin.json` at plugin root. Skill files (`SKILL.md`, `references/templates/*.md`) moved to `plugins/grand-design-spec/skills/grand-design-spec/`. Marketplace catalog points to the plugin via relative path source `./plugins/grand-design-spec`.
- **Install flow.** Now installable via `/plugin marketplace add <gitlab-url>` + `/plugin install grand-design-spec@grand-design-spec` instead of manual `git clone` to `~/.claude/skills/`. Version pinning via `#v0.4.0` ref appended to the GitLab URL.
- **Plugin-level README** added at `plugins/grand-design-spec/README.md` (focused on what the plugin does + trigger phrases). Root `README.md` now describes the marketplace itself and installation across Claude Code, Claude.ai, and Claude API.
- **`SKILL.md` frontmatter** version bumped 0.3.0 → 0.4.0. No skill content changes — behavior identical to v0.3.0.

### Notes
- Existing users who installed via `git clone` to `~/.claude/skills/` should remove the old clone (`rm -rf ~/.claude/skills/grand-design-spec`) before installing via `/plugin install` to avoid duplicate skill registration.

## [0.3.0] — 2026-05-08

### Added
- **Project Shape Registry** in `SKILL.md`. 5 pre-templated shapes (`mobile-app`, `web-app`, `api-only`, `multi-platform`, `data-pipeline`) + `custom` fallback. Skill is now general-purpose, not biased toward mobile banking.
- **Step 2 — Project shape inference + confirmation**. Skill infers shape from PRD content using heuristics, presents reasoning to user, asks for confirm/override. Custom shape triggers user-described layers.
- **`PROJECT_SHAPE` flag** persisted alongside `IMPLEMENTATION_MODE`, drives sub-section structure in `02-architecture.md`, `04-flows.md`, and reading paths in `00-index.md`.
- **Project shape field** in `00-index.md > Vault Lock Status`.
- **Shape-aware Implementation Notes for AI Consumers** in `00-index.md` — instructs AI consumer to confirm both shape AND mode before code work, and to use the relevant layer section based on what's being implemented.

### Changed
- **`02-architecture.md` template** is now shape-agnostic. Layer sub-sections derived from `PROJECT_SHAPE`, not hardcoded "Mobile / Backend / Integrations".
- **`04-flows.md` template** is now shape-agnostic. Flow type sub-sections derived from `PROJECT_SHAPE`. Flow ID prefixes (`F-U-`, `F-S-`, `F-C-`, `F-P-`, `F-X-`) documented for use across shapes.
- **Reading paths in `00-index.md`** are now shape-conditional. Common patterns documented for each pre-templated shape.

### Fixed
- Removed mobile-banking bias. Skill no longer assumes UI exists, no longer hardcodes "Mobile" as a layer, no longer assumes user flows are mobile-facing.

## [0.2.0] — 2026-05-08

### Added
- **Step 0.5 — Implementation mode flag (simplified)**. Skill asks `new` vs `existing` — flag-only, no codebase reference. Mode is metadata that drives downstream AI consumer behavior.
- **`00-index.md > Vault Lock Status`**. Records vault version, lock timestamp, sign-off, status (DRAFT vs LOCKED), and PRD source. Vault locks against requirement, not codebase.
- **`00-index.md > Changelog`**. Tracks vault revisions per PRD update.
- **`00-index.md > Implementation Notes for AI Consumers`**. Explicit instructions for downstream AI dev tools (Claude Code, Cursor) on what to verify with user before writing/modifying code, especially in `existing` mode (cross-check entities/flows/decisions vs existing codebase).
- **Per-layer addressability in `02-architecture.md`**. Sub-sections `### Mobile / Frontend`, `### Backend`, `### Integrations` so each role can deep-link.
- **Per-type addressability in `04-flows.md`**. Sub-sections `### User flows (mobile-facing)`, `### Backend / system flows`, `### Cross-cutting flows`.
- **Deep-link reading paths in `00-index.md`**. Reading paths now use anchor links (e.g. `02-architecture.md#backend`).

### Changed
- Vault structure remains 7 files regardless of mode. Mode flag drives content of `00-index.md > Implementation Notes for AI Consumers`, not file count.
- Anti-halu rules clarified: vault locks **requirement**, not codebase. Codebase reconciliation is the AI consumer's job, instructed via Implementation Notes.

### Removed (vs 0.2.0-alpha conceptual draft, never released)
- `07-integration.md` was conceptually drafted in v0.2.0-alpha and dropped before stable release. Integration mapping to existing codebase belongs to AI consumer at consumption time, not to vault generator.
- Step 0.5 no longer asks for codebase reference (repo URL, local path).

## [0.1.0] — 2026-05-08

### Added
- Initial skill release.
- 7 file vault output: `00-index.md`, `01-overview.md`, `02-architecture.md`, `03-data-model.md`, `04-flows.md`, `05-decisions.md`, `06-constraints.md`.
- Anti-hallucination by construction: every claim must cite source, ambiguities flagged as Open Questions, Out of Scope explicit.
- Step 0 — Output path setup with cross-platform handling (sandbox detection, alien path warning, mkdir variants for Mac/Linux/WSL/Windows).
- Step 1 — Environment-aware input file detection (sandbox vs local Claude Code).
- Step 2 — Extract before writing with gap threshold (>10 → ask).
- Step 3 — Generate with template scaffolding from `references/templates/`.
- Step 4 — Self-check with grounding, readability, simplicity, output integrity verification.
- Step 5 — Present with top blocker surfacing.
- TL;DR header (3 lines: what / for whom / when to read) on every numbered doc.
- Open Question tagging: `OQ-{DOC_CODE}-{N}` with priority `[P1|P2|P3]`.
- 00-index sections: Executive Summary, Project Readiness Status, Reading paths by role, Glossary, OQ roll-up.
- Length & simplicity policy: simple by default; only `04-flows.md` may be complete-wajar.
- Readability standards: EN/ID convention (code EN, prose ID), anti-AI-tone read-aloud test, glossary mandate, cross-ref budget, date format convention.
- Push-back behavior: refuses "just guess the rest" requests, offers to mark as Open Questions instead.
- Templates for all 7 numbered docs.
- README.md with installation instructions for Claude Code (personal & project), Claude.ai/Desktop (zip upload), and Claude API.
- MIT License.
