# Upgrading from an older mega-sdd version

> Field-test feedback: users with old mega-sdd projects need a clear "what works / what migrates / what halts" guide. This doc consolidates the answer.

**Companion docs:** `reading-map.md` (where to read), `paths.md` (canonical layout), `CHANGELOG.md` (per-iter behavior changes), `tests/scenarios/scenario-6-recovery-from-halt.md` (generic halt recovery walkthrough).

## Contents

- Upgrading to 9.0 (one pipeline: the four classic skills removed)
- Upgrading to 8.0.0 (the v8 lite lane + layout-3 major)
- Upgrading to 7.0.0 (the vault layout-2 major)
- Upgrading to 7.3–7.5 (observability removal, surface cull, direct dispatch)
- Upgrading to 7.6 (extraction revamp: census → PRD-kontrak)
- Upgrading to 7.7–7.29 (gate hardening, KB accuracy, size-weighted)
- Upgrading to 6.0.0 (the alias-removal major)
- TL;DR — two paths
- Per-iter behavior changes (Iter 36-62, added Iter 62 per F-E-4)
- Recommended upgrade paths
- Compatibility matrix
- Migration commands — run in this order
- Common halts after upgrade + recovery
- Decision tree
- Per-iter behavior changes (what changed between iters affects you)
- Pre-flight checklist before upgrade
- See also

## Upgrading to 9.0 (one pipeline: the four classic skills removed)

**Why (measured, n=3 clean runs per arm, vanilla Claude Code as control):**
- Greenfield xs + clinic — the pipeline (lite and classic) was 2.3–12× slower and 9–22× costlier than vanilla, with equal or lower quality: commit `cf8d3df3`.
- Lane router — the routed direct/assisted lanes are on par with vanilla on the same two PRDs: commit `d447a6d2`.
- Brownfield with seeded spec traps — the guarded pipeline surfaced the same 5/5 traps as vanilla at ~6× the cost; its CONFLICT gate fired 3× in 3 runs, all false positives on its own anchors: commit `5d880e8b`.
- Lite vs classic (xs) — lite was faster and cheaper, quality overlapped: `benchmarks/results/vanilla-ab/REPORT.md`.

Design, component verdicts and the P1 decisions: `docs/superpowers/specs/2026-09-27-v9-simplification-design.md`; the release entry is `CHANGELOG.md` `## [9.0.0]`. No speed, cost or quality gain over plain Claude Code is claimed for any lane. The guarded pipeline is kept for what vanilla does not leave behind: the vault, the units, per-unit binding evidence and the team documents (traceability and audit).

**What changed:** `/mega-sdd <prd|brief>` runs `scripts/route-lane.sh` first and picks a lane:
- `direct` — a clear task. The main session builds it like plain Claude Code: no vault, no units, no subagents, no `.mega-sdd/` writes.
- `assisted` — open business items, a security surface, a multi-flow product, or an existing app. Direct + ONE batched ask before coding + ONE blind review.
- `guarded` — an existing vault, or `--guarded` (`--lite` implies it). The ONE spec pipeline: `plan` (a PRD, a seed PRD written from a brief, or `plan --kb=<kb>`) → `execute-bolts` (JIT bind per unit, CONFLICT gate at dispatch) → `delivery-check.sh`.

Procedure for direct/assisted: `plugins/mega-sdd/references/direct-lane.md`. Every lane ends with the same result contract: an acceptance-criterion → test table, `scripts/delivery-check.sh` `VERDICT: PASS` on the final commit, and the list of assumptions and decisions made.

**What was removed, and what replaces it:**

| Removed in 9.0 | Use instead |
|---|---|
| `generate-intent` | `plan <prd>` (PRD/BRD) · `plan --kb=<kb-dir>` (extract-intelligence KB). A brief goes to direct/assisted; under `--guarded` the front door writes it to a seed PRD first (`skills/plan/references/brief-input.md`) and `plan` asks once |
| `generate-units` | `plan` — units are written in the same phase (since 8.0); `plan --regenerate` rebuilds them, `plan --reconcile` flips task_type/status after code moved |
| `bind-codebase` | the JIT bind per unit inside `execute-bolts` (pre-flight 3.9: `derive-unit-claims.sh` → `write-unit-binding.sh` → `validate-handoff-binding-units.sh`) → `bolts/U-XXX/binding.json`. Whole-vault audit: `/mega-sdd:sync --full-bind` (= `scripts/rebind-units.sh --units=all`). A CONFLICT still blocks (the unit is quarantined at run start) |
| `scan-codebase` | GROUND — `scripts/ground.sh` + the symbol index (`.mega-sdd/codebase/symbol-index.json`). No `codebase-map.md` writer is left; an existing map is still read |
| The classic chain + the scan-first classic spine | the one pipeline above |
| `scripts/compute-lock-digests.sh` | nothing — its only callers were the removed skills |
| `ripgrep` in `install-deps` | nothing — only scan-codebase used it (`ast-grep` stays) |

The old phrases still route: "pecah PRD ini" / "spec out this feature" / "generate units" → `plan`; "scan codebase" / "init mega-sdd" → the `/mega-sdd` status view (GROUND is the codebase context); "bind vault to code" / "binding gate" → a proposed `/mega-sdd:sync --full-bind` (on a layout-3 vault with units; a layout-2 vault gets the migration proposal first).

**Retired flags and config:** `--classic`, `spine: classic` and `lane: standard` (in `.mega-sdd/config.yaml`) no longer select anything. The front door names the retirement in one line and carries on with the one pipeline. `--express` is accepted as a no-op and means `--guarded`.

**Layout-2 vaults (classic-born, 7.x–8.x):** still READ — the status view and `/mega-sdd:emit` keep working. To build or sync on one, migrate it; `/mega-sdd` proposes this itself (state position `layout2_needs_migration`) and never runs it silently:
1. `/mega-sdd:migrate-paths --vault-layout=3 --vault=<vault-dir>` — dry-run preview. A legacy 7-file vault is refused: run `--vault-layout` (7-file → layout-2) first.
2. Commit, then re-run with `--apply` (dirty tree refused). The four docs + `binding.md` / `binding.json` / `claims-ledger.json` are archived verbatim under `<vault>/_meta/archive/layout2/`; `binding.md` is split per unit into `bolts/U-XXX/binding-migrated.json` (human RESOLUTIONs preserved); `vault.json` is regenerated.
3. **MANDATORY: full JIT re-bind** — `bash <plugin-root>/scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=all` (or `/mega-sdd:sync --full-bind`, or let `execute-bolts --all --lite` bind each unit at dispatch). A CONFLICT carried over without a recorded human resolution keeps blocking until the re-bind re-verdicts it; live ones come back as `binding_conflict` → `resolve-oq --binding`.

`plan` refuses a layout-2 target vault (`plan_layout2_vault`): migrate it first, or pass `--vault=<new-dir>` for a separate plan-born vault. A migrated vault is exempt from the plan-coverage rail (classic-born units carry no `prd_source`), and `plan --regenerate` is allowed on it.

**Plan-coverage rail on an existing plan-born vault:** the gate is DECLARED coverage — every PRD anchor needs a unit `prd_source`, an OQ carrying `[covers: <prd>#<slug>]` (a quoted heading or a `§` in an OQ decides nothing any more) or a `context.md ## Coverage exclusions` line with a real reason. A pre-9.0.x state file with no `vaults` entry reads as missing. Re-run `validate-plan-coverage.sh --cwd=<root> --prd=<prd_path_at_generation> --vault=<vault>` per plan-born vault before the next `execute-bolts`: expect FAIL naming the title / background / goals / scope / open-questions headings, then paste the `next_action` lines with a reason each (measured on the 11 plan-born benchmark vaults: 9 FAIL with 1–10 lines each, 2 PASS unchanged; layout-2 vaults are exempt). A non-markdown PRD needs its `.mega-sdd/sources/<name>.md` rendition first (the gate reads markdown only).

**KB users (legacy rebuild):** `extract-intelligence` stays. Its hand-off is now `plan --kb=<kb-dir>` (was `generate-intent --kb`): `plan` reads `README.md` + `modules/*.prd.md`, one module per slice, then `execute-bolts --all --lite`. A KB-born vault pins `prd_path` = `<kb>/README.md` and `prd_sha256` = the sha256 of `<kb>/census.json`. Legacy numbered-tree KBs keep `--phase=N`. Pinned by `tests/v9/test-kb-to-plan.sh`.

**Paused 8.x chains:** a `--resume` (or a direct dispatch) that names a removed skill fails FATAL `skill_removed_in_9` with one line naming the replacement. Run `/mega-sdd` with no argument: the chain is re-derived from what is on disk.

**Where the relocated contracts live** (about 2,900 of the ~9,550 classic lines survived, moved; the tuned text is kept verbatim):
- `plugins/mega-sdd/skills/plan/references/` — `unit-schema.md`, `unit-procedure.md`, `decomposition-rails.md`, `validation-passes.md`, `task-typing.md`, `adversarial-test-prompt.md`, `pbt-integration.md`, `kb-input.md`, `context-authoring.md`, `scope-flow.md`, `brief-input.md`, plus `templates/unit.md` and `templates/ai-consumer-guide.md`.
- `plugins/mega-sdd/references/` — `vault-core.md` (§schema / §OQ-conventions / §constitution / §id-stability), `modules-schema.md`. The ast-grep queries moved to `plugins/mega-sdd/assets/astgrep-queries/`.
- `plugins/mega-sdd/skills/execute-bolts/references/jit-bind-and-quarantine.md` §E3 (the text-claim ladder) and `plugins/mega-sdd/references/halt-families/units.md`.
- Not relocated, because nothing produces them any more: the starterkit deep-scan steps and multi-squad authoring (`plan` never writes `squads.yaml` / `interfaces/`; the unit-side squad rules still apply to vaults that have them). The layout-2 binding grammar is owned by the code (`scripts/_lib/binding_md.py`).

**What did NOT break:** the six command files (`/mega-sdd`, `/mega-sdd:sync`, `/mega-sdd:emit <prd|fsd|sit|uat|html|summary>`, `migrate-paths`, `install-deps`, `update-plugin`); the moat — binding verdicts + the CONFLICT gate at dispatch, citation discipline, the halt taxonomy, no fabrication; every hook event (the predictive preflight now guards only `plan` + `execute-bolts`); reading layout-2 and legacy 7-file vaults; `extract-intelligence`, the emit lanes, `resolve-oq`, `diff-vault`, `detect-drift`, `analyze`, `graph`.

## Upgrading to 8.0.0 (the v8 lite lane + layout-3 major)

> 9.0 made this lane the only pipeline and removed the classic chain — see above. The 8.x FATAL check ids named below (`intent_folded_into_plan`, `bind_folded_into_bolts`, `units_folded_into_plan`) were replaced by `skill_removed_in_9`.

**What changed:** a second lane (opt-in at 8.0.0; since 2026-09-27 the default for a new PRD on the guarded lane). `--lite` (or `lane: lite` in `.mega-sdd/config.yaml`) turns a PRD into a layout-3 vault (`context.md` + `constitution.md` + `vault.json` + `units/`) in ONE `plan` phase, then `execute-bolts --all --lite` binds each unit just-in-time at dispatch (`bolts/U-XXX/binding.json`, sole writer `scripts/write-unit-binding.sh`; a CONFLICT still closes the gate). Under lite the three classic phases are FATAL in `validate-preflight.sh` with the replacement hop named (`intent_folded_into_plan`, `bind_folded_into_bolts`, `units_folded_into_plan`). Sync on a lite/layout-3 vault re-binds via `scripts/rebind-units.sh --paths=@…` → `plan --reconcile` → `execute-bolts --all --lite`; `sync --full-bind` (= `rebind-units.sh --units=all`) is the whole-vault audit. Also: comments explain WHY not WHAT (8.0.1, a style rule) and the file provenance trailer is TWO lines (8.0.2/8.0.3) — the commit trailer `SDD-PROVENANCE:` is unchanged.

**What did NOT break:** the classic chain stays the DEFAULT for all of 8.x and is byte-identical on layout-2 vaults; every gate and hook contract; legacy 7-file vaults stay readable (read-only). No migration is required to keep working.

**Migrating a layout-2 vault to layout-3 (optional):**
1. `/mega-sdd:migrate-paths --vault-layout=3 --vault=<vault-dir>` — dry-run preview (a legacy 7-file vault is refused: run `--vault-layout` first).
2. Commit, then re-run with `--apply` (dirty tree refused). The four docs + `binding.md` / `binding.json` / `claims-ledger.json` are archived verbatim under `<vault>/_meta/archive/layout2/`; `binding.md` is split per unit into `bolts/U-XXX/binding-migrated.json` (human RESOLUTIONs preserved); `derive-vault-json.sh` regenerates `vault.json`.
3. **MANDATORY: full JIT re-bind** — `bash <plugin-root>/scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=all` (or let `execute-bolts --all --lite` bind each unit at dispatch). The rung never writes `bolts/U-XXX/binding.json` itself.

**Deliberate degradation (plan-born vaults):** a layout-3 vault without `## Architecture` reports Architecture-prose drift as `n/a` (migrated vaults keep the section).

## Upgrading to 7.0.0 (the vault layout-2 major)

**What changed:** `generate-intent` now emits the **4-file layout-2 vault** (`vault.md` / `model.md` / `flows.md` / `constraints.md` + `vault.json`) instead of the 7-file `00-index.md … 06-constraints.md` set. The six Vault Lock values live as `vault.md` YAML frontmatter; ALL Open Questions live in `constraints.md ## Open Questions` (per-line `[origin: <file>#<anchor>]` keeps locality; the 00-index roll-up is retired); `## Overview` / `## Architecture` / `## Decisions` are EXACT hard-header anchors (deriver + claims-ledger exit 2 when missing). Mapping table: `references/paths.md §Vault layout`.

**What did NOT break:** every EXISTING 7-file vault keeps working — every reader (deriver, ledger, validators, hook dispatch, emission builders, skills) is **dual-layout for one minor cycle** (probes the layout-2 file first, falls back to the legacy name; floor v5.9.0). Binding, units, bolts, gates: untouched.

**Migrating an existing vault (optional, recommended):**
1. `bash $PLUGIN_ROOT/scripts/migrate-paths.sh --vault-layout --cwd=<project>` — DRY-RUN preview (names what moves and what ceremony drops).
2. Commit your tree, then re-run with `--apply` (dirty tree is refused). The rung concatenates verbatim, stamps `[origin:]` on moved OQs, rewrites unit doc-name refs, runs `derive-vault-json`.
3. **MANDATORY next step: full re-bind** — the merge shifted line numbers, so `binding.md`/`binding.json`/`.citation-map.json` anchors are stale; they are REGENERATED (run bind again), never patched. Graph + emissions self-heal on the next run. On 9.0 there is no whole-vault bind to re-run: continue with `--vault-layout=3` and its JIT re-bind (§Upgrading to 9.0).

## Upgrading to 7.3–7.5 (observability removal, surface cull, direct dispatch)

**v7.3.0 — observability/memory removed (pipeline-only).** The whole memory/telemetry/advisor lane is gone: `/mega-sdd:memory` no longer registers, there is no token-cost report, no compaction advisor, no PreCompact/SubagentStop hooks. Old `.mega-sdd/memory/` and `~/.mega-sdd/memory/` dirs are inert — delete when convenient; user defaults moved to `~/.mega-sdd/config.yaml`. The only observability artifact left is the `mega-sdd-trace:*` gateway tag family (`docs/gateway-contract.md`) — since 8.7.0 joined by one `mega-sdd-note:` repo/branch line per gateway-routed session (same doc; git facts only, no token or cost counting came back).

**v7.4.0 — surface cull.** `/mega-sdd:slice` + the slice-design skill are removed (owner decision), the vendored superpowers tree is removed (first-class `agents/` are the only path), and the tree-sitter slice engine is removed (`ast-grep → regex` is the scan ladder). Surface = 3 verbs + 3 one-timers.

**v7.5.x — direct dispatch + auto-aware.** Hooks dispatch DIRECTLY from `hooks.json` — `run-hook.sh` is deleted (a local fork of it is dead code); the PostToolUse matcher narrowed to `Write|Edit` and its validator fan-out is deleted (every gate-read state re-derives at its own gate). New ambient behaviors: a LOCKED-edit context notice, a "selesai" census → one-line sync OFFER, and opt-in `auto_verify_on_edit` (default false). The bare-verb wrapper is v2 (version-aware resolution) and refreshes itself at session start.

**What did NOT break:** every artifact and every gate/hook contract. No migration commands needed for 7.3→7.5 — update the plugin and reload.

## Upgrading to 7.6 (extraction revamp: census → PRD-kontrak)

**What changed:** `extract-intelligence` is census-contracted. `derive-extract-census.sh` writes `census.json` (code files + sha256 + stacks + entry points + module proposal), extraction runs per module (1 module = main thread, no subagents; >1 = one extractor agent per module), and the output grammar is `modules/<domain>.prd.md` — ONE 6-section PRD-kontrak per module (Mermaid flow mandatory) — plus `README.md` (module quick-reference = recommended rebuild order) and a conditional `data-mutation-policy.md`, all closed by the `validate-extract-census.sh` completeness gate. Retired for NEW extractions: the numbered tree (`00-overview/ … 99-rebuild-architecture/`), waves, the extraction scorecard, and `--phase=N` (the module is the phasing unit).

**What did NOT break:** pre-existing numbered-tree KBs stay readable everywhere (dual grammar) and keep their `--phase` lane. `generate-intent --kb=<kb>` (9.0: `plan --kb=<kb>`) detects the grammar (census.json present → PRD-kontrak lane; else legacy tree lane); the chain, the output home (`<out>/knowledge-base/`), the mutability tiers, and every downstream gate are unchanged. No migration commands — update the plugin and reload; re-extract only when you want a KB on the new grammar.

## Upgrading to 7.7–7.29 (gate hardening, KB accuracy, size-weighted)

**What changed (user-visible, in order):**
- **7.7–7.8 — sprint/wave scheduling + contract-scoped review routing.** execute-bolts schedules waves by default; the review-tier router scopes its risk signals to the unit's contract (the field misroutes were fixed here).
- **7.9.0 — Agent-tool dispatch is gated.** A hand-dispatched `bolt-implementer` Agent call now hits the execute-bolts PreToolUse gate (F-09), and the wave rail DENIES `git add -A` / `stash` / `reset --hard` while a bolt is in flight (F-16). Expect a block where an older version silently let a hand dispatch through. (Both removed in P3 with the per-unit path.)
- **7.10–7.11 — evidence obligations.** Directive-typed Hard rules are ADVISORY (never fail B1); a bolt dispatched with `review-tier.json` MUST carry a panel `findings.json` + `l0-results.json` (`panel_evidence_missing` / `l0_evidence_missing`); a `type: test` acceptance entry needs `expects` (`acceptance_expects_missing`, per unit at its own dispatch). (The panel and per-dispatch parts were removed in P3.)
- **7.12–7.13 — project packs + L0 advisory.** `.mega-sdd/packs/<framework>.md` resolves (beats a same-named plugin pack); a repo with zero linter/formatter gets a ONE-TIME `l0_toolchain_vacuous` advisory (decision file `.mega-sdd/l0-toolchain-decision.json`).
- **7.16 — `/mega-sdd:emit html <file|dir>`** renders any mega-sdd md into one self-contained offline HTML.
- **7.20–7.23 — team-feedback round.** `--max-complexity=large` / config `unit_granularity: coarse`; resolve-oq walks the extraction KB (§6); every OQ prompt opens with Konteks + Maksudnya; the natural-register writing contract applies to every emitted doc.
- **7.24–7.27 — KB accuracy pack.** KB validators recognise the `modules/*.prd.md` grammar (a post-7.6 KB no longer SKIPs silently — `kb_discovery` MISCONFIGURED backstops it); the claim-verify lane (`claim-verifier` per module) runs after extraction; counts are script-derived; `rebuild_after` DAG + AC golden-master for `[LOCKED]` rules.
- **7.28–7.29 — size-weighted.** `unit_tier: xs` shrinks the dispatch payload of small units (−65% measured); `project_scale: xs` (derived from PRD structure) omits the vault Glossary (its tech-OQ auto-defer was superseded in 8.5: technical OQs are decided by the AI at every scale).

**What did NOT break:** every artifact, every gate/hook contract, both vault layouts, both KB grammars. **No migration commands** for 7.6 → 7.29 — update the plugin (`claude plugin marketplace update` + `claude plugin update`, or `/mega-sdd:update-plugin`) and reload. Neither 7.11 evidence halt fires after P3: the panel, its writer and the gate that checked both were removed.

## Upgrading to 6.0.0 (the alias-removal major)

**What broke (the ONLY break):** the 24 `/mega-sdd:<stage>` typed deprecation aliases no longer register as slash commands (`generate-intent`, `scan-codebase`, `bind-codebase`, `generate-units`, `execute-bolts`, `resolve-oq`, `detect-drift`, `diff-vault`, `analyze`, `graph`, `lint-units`, `list-modules`, `replay`, `migrate-rules`, `validate-handoff`, `enrich-semantics`, `analyze-parallelism`, `extract-intelligence`, `orchestrate-flow`, `auto`, `emit-fsd`, `emit-prd`, `emit-sit`, `emit-agents-md`). Removal per policy: demoted at 5.0.0, removable the following major after telemetry review (performed 2026-08-04; honest scope: the telemetry corpus records skill events + ref-loads and has NO channel that logs typed command invocations, so it can attest no alias usage — the review is discharged procedurally, and the field floor is covered by this guide, not by the corpus).

**What did NOT break:** every artifact (vault, binding.md, units, bolts), every gate and hook contract, the classic spine (`--classic` / `spine: classic`; retired in 9.0), all legacy read-side paths (`docs/mega-sdd/…`, `.mega-sdd-memory/` — deliberately KEPT, they cost one glob each), and all four maintenance one-timers. **Typing an old form still works in practice:** an unregistered legacy form (say, the old typed analyze alias) arrives as plain text and routes to the matching skill — you lose only the registered slash-command autocompletion.

**The 6.0.0 surface:** `/mega-sdd` (front door) · `/mega-sdd:sync` · `/mega-sdd:emit <prd|fsd|sit|uat>` + one-timers `install-deps` / `update-plugin` / `memory` / `migrate-paths` (v7.3.0 removed `memory` → three one-timers; v7.4.0 removed `/mega-sdd:slice` → three public verbs). Everything else: natural-language phrase ("cek konsistensi", "lint units", "cek drift", "blast radius"). The old-form → new-way map: every removed stage command routes by phrase through the front door — `generate-intent`→"pecah PRD ini" / `/mega-sdd ./prd.md` · `scan-codebase`→"scan codebase ini" · `bind-codebase`→"bind vault ini ke code" · `generate-units`→"generate units" · `execute-bolts`→"eksekusi bolt" · `resolve-oq`→"walk open questions" · `detect-drift`→"cek code vs vault" · `analyze`→"cek konsistensi" · `extract-intelligence`→`/mega-sdd <legacy-dir>` · `emit-*`→`/mega-sdd:emit <prd|fsd|sit|uat>` · `lint-units`/`list-modules`/`graph`→by phrase ("lint units", "status module", "blast radius"). (9.0 removed four of those skills: the generate-intent / generate-units phrases now reach `plan`, "scan codebase" reaches the status view, and "bind vault" proposes `/mega-sdd:sync --full-bind` — §Upgrading to 9.0.)

**Where the alias content went (nothing was deleted blind):** `lint-units`/`analyze-parallelism`/`list-modules`/`enrich-semantics` procedures → `skills/orchestrate-flow/references/diagnostics-procedures.md`; `validate-handoff` → `skills/bind-codebase/references/handoff-validation.md` (deleted with bind-codebase in 9.0; the validator itself, `scripts/validate-handoff-binding-units.sh`, is the CONFLICT gate at dispatch); `migrate-rules` → `skills/execute-bolts/references/` (the relocated `replay` lane was later removed entirely in v7 — git history); `analyze` modes → `skills/analyze/SKILL.md`.

**Office-floor path (v5.9.0 laptops):** `/mega-sdd:update-plugin` → `/plugin marketplace update mega-sdd` → restart/`/reload-plugins`. No project migration needed — 6.0.0 changes the COMMAND surface only; a 5.x vault/binding/units tree is consumed unchanged, and the express spine has been the default since 5.35.0.

**Also in 6.0.0:** the on-demand doc pack now derives fully from the modern vault generation (FSD §5 from `04-flows.md` when `02-functional.md` is absent, §6 from `06-constraints.md`, §10/PRD §6 accept the `tag`/`text` vault.json OQ shape) — older vaults keep their legacy sources via first-hit-wins.

## TL;DR — two paths

**Path A (easiest, recommended): Regenerate from inputs**
Keep your original PRD or KB; regenerate a fresh layout-3 vault + units with `plan` (`/mega-sdd <prd> --guarded`, or `plan --kb=<kb>`); binding happens per unit when `execute-bolts` dispatches. `plan` refuses to write into a layout-2 vault, so point it at a new one (`--vault=<new-dir>`) or migrate first. Skips most compat issues. ~5 min.

**Path B (preserve existing vault + binding + bolts):**
Run migrations (paths, then the vault layout rungs to layout-3, then the mandatory JIT re-bind) → expect 1-2 schema halts → recover via halt envelope hints. ~15-30 min.

> **v3.41.0+ Iter 62 update (per F-E-4):** target version refreshed from v3.26.1 (Iter 36 doc baseline) to v3.41.0; the CURRENT target is 9.0.x — see the 9.0 through 7.7–7.29 sections above, which apply on top of everything below. Per-iter behavior summary covers Iter 36-62 (table below). Existing migration commands + recovery sections still valid; new sections cover Iter 54+ (emit-fsd), Iter 55+ (install-deps), Iter 60 (F4 bypass tightening).

## Per-iter behavior changes (Iter 36-62, added Iter 62 per F-E-4)

| Iter | Plugin version | What changed | Migration impact |
|---|---|---|---|
| 36 | v3.26.1 | Upgrade guide consolidation (this doc origin) | none (doc-only) |
| 37 | v3.26.2 | Scenarios coverage + README audit | none |
| 38 | (audit) | E2E pipeline audit (37 findings) | none |
| 39-52 | v3.26.3 → v3.35.1 | Iter 38 audit closure | mostly compatible; some skill schemas refined |
| 43, 48, 52 | (fix-forward) | Caught 4 release-blocker regressions | run `--resume` after patches |
| 53 | v3.36.0 | Consumer wiring closure (3 PARTIAL → USED) | new `quality_gate_failed:starterkit_metrics_inconsistent` subtype |
| 54 | v3.37.0 | **NEW skill `emit-fsd`** (Confluence FSD generator) | optional opt-out via `--no-fsd` |
| 55 | v3.38.0 | **NEW skill `install-deps`** (OS-aware auto-installer) | user-explicit invocation; not auto-triggered |
| 56 | (audit) | Deep audit of v3.38.0 (38 findings) | none |
| 57 | v3.38.1 | CRITICAL fix-forward (B-P1 + D1 + F-E-2) | binding.md gains `binding_metadata:` block (additive); `--rollback` menu default flipped to `[I] interactive` (safer) |
| 58 | v3.39.0 | Halt taxonomy: +9 enum entries + `quality_gate_failed` subtypes | downstream consumers branch on `details.subtype` for `quality_gate_failed` |
| 59 | v3.39.1 | Contract sweep: emit-fsd + install-deps Per-skill blocks | adds TYPE annotations (advisory until Iter 60) |
| 60 | v3.40.0 | **F4 bypass tightening — anti-halu rail behavior change** | fields without TYPE annotation halt-against-author; migration via `--legacy-type-bypass` (RETIRED in v4.75.0 — un-annotated fields are warn-only under the deterministic validator; no migration flag needed) for one chain run |
| 61 | v3.40.1 | Catch-all P2/P3 closure | emit-fsd citation slot extraction wired (Iter 54 dead-code fixed); test fixtures added |
| 62 | v3.41.0 | Remaining Iter 56 audit closure (scenario sweep + doc bulk) | scenario-6 +8 walkthroughs; predictive-check coverage extended; `next_action` canonical shape documented |

## Recommended upgrade paths

- **v3.0-v3.25 → 9.0.x:** use Path A (regenerate from PRD/KB). Many schema + behavior changes accumulated; regen is faster than migrating each artifact.
- **v3.26-v6.x → 9.0.x:** use Path B — no flag needed (`--legacy-type-bypass` was RETIRED in v4.75.0; un-annotated fields are warn-only under the deterministic validator). A 7-file vault takes two rungs: `--vault-layout` (→ layout-2), then `--vault-layout=3`, then the JIT re-bind.
- **7.x-8.x classic (layout-2 vault) → 9.0.x:** reading keeps working as is; to build or sync, one rung (`--vault-layout=3`) + the JIT re-bind (§Upgrading to 9.0).
- **8.x `--lite` / `plan`-born or already-migrated (layout-3) vault → 9.0.x:** seamless — it is the one pipeline.

## Compatibility matrix

| Old artifact | Works on 9.0.x? | What to do |
|---|---|---|
| Layout-3 vault (8.x `--lite` / `plan`-born, or migrated) | Yes — the one pipeline | None |
| Layout-2 vault (7.x–8.x classic) | Read OK (status view, `/mega-sdd:emit`); build/sync is proposed as a migration first (`layout2_needs_migration`); `plan` refuses it as a target (`plan_layout2_vault`) | `/mega-sdd:migrate-paths --vault-layout=3 --vault=<dir>` (dry-run → `--apply`), then the MANDATORY full JIT re-bind (`rebind-units.sh --units=all`) |
| Legacy 7-file vault (`00-index.md … 06-constraints.md`) | Read OK | `--vault-layout` (→ layout-2) first, then as the row above |
| `lane: standard` / `spine: classic` in `.mega-sdd/config.yaml`, `--classic` | Ignored with a one-line note — no classic chain exists | Delete the key when convenient |
| Paused 8.x chain naming a removed skill | FATAL `skill_removed_in_9` (one line naming the replacement) | Re-run `/mega-sdd` (no argument) — the chain is re-derived from disk |
| `docs/mega-sdd/vaults/<slug>/` legacy path | Read OK (back-compat probe) | Optional: `/mega-sdd:migrate-paths` |
| `.mega-sdd-memory/` legacy path | Read OK (back-compat probe) | Same |
| `codebase-map.md` (any pre-9.0 version, canonical or `<repo-root>/` location) | Read when present (emit-*, detect-drift); no 9.0 writer — GROUND's `symbol-index.json` is the codebase context | None; optional `/mega-sdd:migrate-paths` moves a root-level map to `.mega-sdd/codebase/` |
| Pre-v1.4 KB without `[LOCKED]/[INTENT]/[ARTIFACT]` markers | Yes — all claims default to `[INTENT]` (safe middle-ground) | None (auto-fallback) |
| Vault without `scope_metadata` (legacy single-scope) | Yes — treated as legacy single-vault; `scope:` blocks omitted | None |
| Vault without `phase`/`phase_total` fields (pre-Iter-35) | Yes — defaults to `phase: 1, phase_total: 1` | None |
| Any pre-9.0 whole-vault `binding.md` (incl. pre-Iter-8 without `PARTIAL_FIELDS_*` states) | Read-only; archived by `--vault-layout=3` and split per unit into `bolts/U-XXX/binding-migrated.json` | The mandatory JIT re-bind after migration re-verdicts every unit (`bolts/U-XXX/binding.json`) |
| Old `.mega-sdd/memory/` data | Ignored — the memory lane was removed in v7.3.0 | Delete the dir when convenient |
| Pre-Iter-30 bolt-reports without provenance trailer | New bolts OK; re-running old bolts halts | Skip re-runs OR add trailer manually |
| Pre-Iter-33 handoff YAML missing `scope:`/`mutability:` blocks | Halt `invalid_handoff` on re-run via the handoff validation gate (`orchestrate-flow/references/handoff-consumption.md`; re-checked by PreToolUse at gate time) | Edit handoff template OR regenerate vault (Path A) |
| Pre-Iter-60 skill handoffs with fields lacking TYPE annotation | Halt `handoff_type_mismatch` (strict default v3.40.0+) | No flag needed (`--legacy-type-bypass` RETIRED v4.75.0 — warn-only now); fix handoff-contract.md TYPE annotations at leisure |
| Pre-Iter-58 chain emitting halt names from the 9 newly-enumerated orphans | Now accepted (Iter 58 closed enum gap) | None — no action needed |

## Migration commands — run in this order

```bash
# 1. Canonicalize paths (legacy → .mega-sdd/)
/mega-sdd:migrate-paths --dry-run        # preview only
/mega-sdd:migrate-paths                  # actual move via git mv (preserves history)

# 2. Vault layout → layout-3 (9.0 builds and syncs only on layout-3)
#    a 7-file vault first takes the layout-2 rung: --vault-layout[=<vault-dir>]
/mega-sdd:migrate-paths --vault-layout=3 --vault=<vault-dir>           # dry-run preview
/mega-sdd:migrate-paths --vault-layout=3 --vault=<vault-dir> --apply   # after committing

# 3. MANDATORY full JIT re-bind (the layout-3 rung never writes binding.json)
bash <plugin-root>/scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=all
#    (or /mega-sdd:sync --full-bind)

# 4. Migrate Hard Rules v1 grammar → v2 ast-grep YAML (per-unit confirm)
#    (not a slash command since 6.0.0 — ask by phrase:)
#    "/mega-sdd" → "migrate hard rules <vault-path>"
```

All are idempotent — safe to re-run (a layout-3 vault is a no-op for step 2). (The old "migrate memory schema" step is gone — the memory lane was removed in v7.3.0.)

## Common halts after upgrade + recovery

### `postflight_evidence_missing` / `hard_rule_violated` on PREVIOUSLY-GREEN bolts (v4.79.0 Hard-rule engine hardening)

**Cause:** the B1 gate RECOMPUTES each committed Hard-rule bolt's postflight scan from git/fs ground truth, and v4.79.0 fixed several engine holes — so a bolt that passed under the old engine can flip to fail at the next `execute-bolts` gate purely from upgrading. Expected flips (each means the lock was previously being dodged, not a false alarm): `*`/`+`/numbered-bullet locks now execute; v2 ast-grep rules with relative `files:` globs were silently INERT and now actually scan; `MUST NOT modify <path>` / `NEVER add new <manifest> dependencies` (path-shaped object) recompute as MECHANICAL past old attestations; SIGNATURE_RULE now requires exact parameter-list equality (added params fail). Also: a wrapped directive bullet is now lexed JOINED with its continuation lines, so its attest carry-forward key changes — a previously attested directive downgrades to `directive_unverified` once.

**Recovery:** fix the violating code forward (or `git revert` the bolt commit) and re-run `scripts/run-postflight-scan.sh --cwd=<root> --unit=U-XXX`; re-attest re-keyed directives with `--attest-directives="<who/why>"`. If the RULE text is wrong, edit the unit's `## Hard rules` and COMMIT the edit as `fix(U-XXX): correct hard rule` — the gate recomputes against the unit text at the newest unit commit.

### `whitelist_violation` / new B-gate blocks on legacy layouts / suite refusals (v4.80.0 validator hardening)

**Cause:** three v4.80.0 hardenings surface on upgrade. (i) **B3 anchored matching** — the whitelist observer no longer honors suffix/fnmatch tolerances, so a past bolt commit (within the 300-commit walk) that relied on them (`legacy/app/config.py` for target `app/config.py`; `src/a/b/x.py` for `src/*.py`) now flips `whitelist_violation`. That commit DID escape its declared scope — review it; if the change is right, add the escaped paths to the unit's `target_files` and re-save. (ii) **Legacy-layout activation** — a project whose vault lives under `docs/mega-sdd/` or a `*-bound/` sibling (pre-`migrate-paths`, no `.mega-sdd/` dir) previously got ZERO B1/B2/B3/orphan coverage; on upgrade the gates activate at once (a `.mega-sdd/` dir is created for state) and `bolt_artifacts_missing` / `postflight_evidence_missing` / `batch_suite_gate_missing` are likely on the first `execute-bolts` — the dormant gates never forced those artifacts. Follow each halt's remediation (backfill or re-run); this is coverage arriving, not breakage. (iii) **run-full-suite refusals** — the wrapper now exits 2 on a dirty CODE tree, an empty repo, or a non-substantive `--vault`: commit or stash code changes first (add untracked litter like `.env`/caches to `.gitignore` — never commit secrets to clear a gate).

### `invalid_handoff` (Iter 33 F3 schema validation gate)

**Cause:** old skill body emits handoff YAML missing `scope:` / `mutability:` / `constitution:` blocks; the orchestrate-flow handoff validation (`references/handoff-consumption.md`, `scripts/validate-handoff-yaml.sh`) checks it against handoff-contract.md REQUIRED/CONDITIONAL/OPTIONAL annotations.

**Halt envelope shows:** `details.failing_skill` + `details.missing_field` + `details.field_severity` + `next_action.hint` (the exact skill template to edit).

**Recovery — two options:**
- **Easy (Path A):** regenerate vault — `plan --kb=<KB>` (or `plan <prd>`) → fresh layout-3 vault + units. ~5 min.
- **Surgical (Path B):** manually add the missing block to your skill's handoff template per `handoff-contract.md §schema`. Re-run chain.

### `memory_schema_mismatch`

**Cause:** memory file has older `memory_schema:` stamp than current version expects.

**Recovery:** not needed since v7.3.0 — the memory subsystem is removed; old memory files are inert and can be deleted.

### `handoff_type_mismatch` (Iter 33 F4 type-check)

**Cause:** old handoff field has wrong type (e.g., `scope.id` as object instead of string enum).

**Recovery:** halt envelope shows `expected_type` + `actual_type` + `actual_value`. Either fix the skill template OR regenerate via Path A.

### `provenance_missing` (Iter 30)

**Cause:** old bolt-report lacks provenance trailer (introduced Iter 30).

**Recovery:** only fires on RE-running old bolts. New bolts emit trailer automatically. Options:
- Skip the re-run (use existing bolt outputs)
- Add provenance trailer to old file manually
- Full bolt re-run via `execute-bolts U-XXX` (regenerates everything)

### `binding_conflict` (legacy name `bind_conflict`)

**Cause:** a unit's claim contradicts existing code (PRD says X, code does Y). 9.0 raises it at `execute-bolts` pre-flight 3.9 from `bolts/U-XXX/binding.json`; `bind_conflict` is the layout-2 `binding.md` name. After `--vault-layout=3`, the mandatory JIT re-bind re-verdicts each unit's own claims and raises any CONFLICT it finds as `binding_conflict`; a carried-over CONFLICT that no human resolved and the unit's claims do not cover stays visible as the advisory `conflict_migrated_rebound` — review its block in `bolts/U-XXX/binding-migrated.json`.

**Recovery:** `resolve-oq --binding` → per claim `KEEP_VAULT` | `KEEP_CODE` | `DEFER` | `SPLIT` (recorded by `write-unit-binding.sh --resolve`, never by hand); or fix the code/unit and re-run pre-flight 3.9. Only the listed units stop (their dependents skip, with the reason); the others proceed.

### `skill_removed_in_9` / `plan_layout2_vault` (9.0)

**Cause:** `skill_removed_in_9` — a paused 8.x chain (`--resume`) or a direct dispatch names `generate-intent`, `generate-units`, `bind-codebase` or `scan-codebase`. `plan_layout2_vault` — `plan` was pointed at a layout-2 vault; it writes layout-3 only.

**Recovery:** the FATAL line names the replacement. For a stale chain, re-run `/mega-sdd` (no argument) and take the re-derived proposal. For a layout-2 target, run `/mega-sdd:migrate-paths --vault-layout=3 --vault=<dir>` first (then the mandatory JIT re-bind), or pass `--vault=<new-dir>` for a separate plan-born vault.

For full halt taxonomy + recovery walkthrough: `tests/scenarios/scenario-6-recovery-from-halt.md`.

## Decision tree

```
Start: I have an old mega-sdd project on v3.26.1+

  Q: Do I still have the original PRD / KB / brief that generated the vault?

  ├── YES + I want fresh modern artifacts (Path A — RECOMMENDED)
  │     → /mega-sdd <original-input> --guarded   (KB: plan --kb=<kb>)
  │     → plan writes a fresh layout-3 vault + units (--vault=<new-dir>
  │       when the old layout-2 vault sits at the default path);
  │       execute-bolts binds each unit at dispatch
  │     → 5 min; minimal friction
  │
  └── NO + I want to preserve existing work (Path B — preservation mode)
        ↓
        /mega-sdd:migrate-paths           # canonicalize legacy paths
        ↓
        /mega-sdd:migrate-paths --vault-layout=3 --vault=<dir>   # dry-run, commit, --apply
        ↓                                 # (7-file vault: --vault-layout first)
        rebind-units.sh --units=all       # MANDATORY full JIT re-bind
        ↓
        /mega-sdd                         # re-derives the chain from disk; halts on real gaps
        ↓
        For each halt: read halt envelope next_action.hint; apply suggested fix
        ↓
        If halt persists after 2 fix attempts → fall back to Path A
```

## Per-iter behavior changes (what changed between iters affects you)

For full per-iter detail, see `CHANGELOG.md`. Highlights of iters that introduce migration-relevant changes:

- **Iter 8 (v3.x)** — Implementation-State Map adds `PARTIAL_FIELDS_*` states; old binding.md still parses (unknown states → `create`)
- **Iter 9 (v3.x)** — memory schema stamping; auto-migrate via `memory migrate` (the whole memory lane was later removed in v7.3.0)
- **Iter 10 (v3.4+)** — path consolidation under `.mega-sdd/`; `migrate-paths` command introduced
- **Iter 22 (v3.14+)** — KB mutability tiers `[LOCKED]/[INTENT]/[ARTIFACT]`; pre-Iter-22 KBs default all claims to `[INTENT]`
- **Iter 27 (v3.19+)** — starterkit-first pipeline reorder (scan-codebase runs FIRST in brownfield); old chains still work via routing-rules.md back-compat (9.0 removed scan-codebase: a stale chain naming it fails `skill_removed_in_9`)
- **Iter 30 (v3.22+)** — provenance trailer mandatory in bolts; old bolt-reports lack trailer; re-runs halt `provenance_missing`
- **Iter 33 (v3.24+)** — handoff schema validation gate (REQUIRED/CONDITIONAL/OPTIONAL + TYPE annotations); old handoffs may halt `invalid_handoff` / `handoff_type_mismatch`
- **Iter 35 (v3.26+)** — `phase`/`phase_total` fields in vault.json; old vaults default to `phase: 1, phase_total: 1`

## Pre-flight checklist before upgrade

1. ✅ Commit your current work (`git status`; commit any uncommitted changes)
2. ✅ Note current plugin version (compare against the latest in `CHANGELOG.md` after)
3. ✅ Decide: Path A (regenerate) OR Path B (preserve)
4. ✅ If Path B: nothing to back up for memory — the lane was removed in v7.3.0; old `.mega-sdd/memory/` dirs are inert and deletable
5. ✅ Update plugin: `/mega-sdd:update-plugin` → `/plugin marketplace update mega-sdd` → restart / `/reload-plugins`
6. ✅ Run the migration sequence per above

## See also

- `docs/mega-sdd/reading-map.md` — where to read at each stage (Iter 35; 9.0 reading order)
- `docs/superpowers/specs/2026-09-27-v9-simplification-design.md` — the 9.0 design, component verdicts and P1 decisions
- `plugins/mega-sdd/references/direct-lane.md` — the direct/assisted procedure + the result contract
- `plugins/mega-sdd/references/paths.md` — canonical write paths (v3.4+ Iter 10)
- `CHANGELOG.md` — per-iter behavior changes
- `tests/scenarios/scenario-6-recovery-from-halt.md` — generic halt recovery walkthrough
- `plugins/mega-sdd/commands/migrate-paths.md` — path migration command details
- `plugins/mega-sdd/skills/execute-bolts/references/migrate-rules.md` — Hard Rules grammar migration
