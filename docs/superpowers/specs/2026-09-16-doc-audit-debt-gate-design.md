# Doc-audit v8 debt gate — design spec (8.4.0)

**Status:** BUILT in the 8.4.0 cycle (this spec + the commits it names). Source: `research/2026-09-16-doc-audit-v8.md` §7 (20 code findings), §8 (`[OPEN]`), §10 (anchor byte pin), plus the test/fixture findings listed under §7. Owner call 2026-09-16: "gas semua beresin" — every debt item gets a resolution here: FIX (code + test), DECIDE (owner-decision recorded and applied), or WONTFIX (by design, reason stated). Nothing is left as a bare TODO.

Rules carried from the audit runbook and the repo contract: code at HEAD is the source of truth; no test is deleted or loosened (a pin whose PREMISE this spec changes is re-pinned to the new measured/spec'd value with the reason in its comment); one commit per file-set; CHANGELOG + both manifests bump together; the scm leg is not pushed from here (VPN).

## 1. Code findings → fixes

| # | Finding (audit §7) | Root cause at HEAD | Fix | Pin |
|---|---|---|---|---|
| 1 | RESOLUTIONS column order (agent prompt vs parser) | `merge-panel-findings.sh` reads `id \| file:line \| verdict \| note` only; a verifier that emits `id \| verdict \| file:line \| note` never closes a finding | parser accepts BOTH orders: when column 2 is a verdict word and column 3 parses as `file:line`, swap. Same evidence rule (a `resolved` without `file:line` is still recorded, never applied) | `tests/round-discipline/test-merge-panel-findings.sh` +1 case (swapped order resolves; swapped order without anchor still refused) |
| 2 | `validate-unit-spec.sh` has no `--vault=` (LIVE rc=2 in 5 xs runs) | strict arg parse; the docs now say `--cwd` only, but a controller still types `--vault=` | accept `--vault=<name\|dir>` as an EXIT-CODE scope: the state stays project-wide (S5 GU-HOOK-1 invariant), the exit reflects only units under that vault; reported as `vault_filter` | `tests/v8-plan/test-unit-spec-vault-scope.sh` (new): `--vault=` no longer a usage error, scope narrows the exit, state still lists every unit. `validate-sibling-consistency.sh` stays strict (its pin `test-plan-validator-args.sh` untouched) |
| 3 | `_layout3_vault_present()` project-wide | any `vaults/*/context.md` folds bind/units for EVERY vault | fold only when the TARGET vault is layout-3: `--vault=` on the args → that vault; else all vault dirs → folded iff every one carries `context.md` (single vault keeps today's behavior) | `tests/v8-layout3/test-alias-folded.sh` +2 cases (mixed vaults: no fold without `--vault=`; `--vault=<layout-3>` folds) |
| 4 | `build-fsd-core.sh:236` / `build-prd-core.sh:353,370` read `<vault>/_meta/constitution.md` | every producer writes `<vault>/constitution.md` | read `<vault>/constitution.md` first, keep `_meta/` as a fallback for hand-made vaults; citation text becomes `vault/constitution.md` | `tests/token-efficiency/test-5e-doc-builders.sh` +1 (a LOCKED clause in `constitution.md` reaches FSD §6 / PRD §5) |
| 5 | `ground.sh` flags `model_tiers.bolt_implementer` | catalog roles are hyphenated, the documented config key is underscored, no normalization | compare with `_`→`-` normalization on both sides | `tests/express-default/…` reuse: new `tests/state/test-ground-model-tier-norm.sh` (underscore key → no notice; unknown role → notice) |
| 6 | `ground.sh:91-95` skips a corrupt `vault.json` silently | "future slice" comment | Guard 1 emits a `[self-resolved] vault_json_corrupt` notice naming the file (registered as a C1 self-resolve detection in the flow family — the mode guard skips it, the chain continues, the user sees the line) | same new test file: corrupt vault.json → notice line |
| 7 | `validate-scope-flag.sh` misses the MAP form of `scopes:` and blocks on stdin | parser knows inline list, block scalars, block dicts; the canonical template + 3 sample PRDs use `scopes:\n  BE:\n    name:` | shape (d) MAP: 2-space-indented `KEY:` children; without `--user-message-file` and with a TTY stdin → empty message (never block) | `tests/round3/test-scope-flag-map.sh` (new): MAP form declares scopes; `--scope=XX` FAILs; unknown arg still tolerated |
| 8 | publisher never ships `bolts/U-*/binding.json` | per-vault pattern list predates the 8.0.0 re-key | add `vaults/<v>/bolts/U-*/binding.json` to the per-vault patterns | `tests/publisher/test-publish-artifacts.sh` a2 asserts the file is in the manifest |
| 9 | ast-grep TIMEOUT → exit 3 (`hard_rule_unparseable`) | deliberate reuse, reasoning in the code comment (same epistemic state: rule NOT validated; the halt enum is closed) | **WONTFIX** — the message text already distinguishes TIMEOUT and names the remedy | none |
| 10 | `validate-handoff-yaml.sh` never checks a blocker `type` against the registry | shape-only validator | ADVISORY membership check: unknown `blockers[].type` → a `warnings[]` entry `halt_type_unregistered` in the state file (never a FAIL — the registry is prose; fail-closed here would deadlock a chain on a typo) | `tests/handoff/test-blockers-shape.sh` +1 |
| 11 | `write-unit-binding.sh --resolve` refuses DEFER | regex `KEEP_VAULT\|KEEP_CODE\|SPLIT` | accept `DEFER` (resolution `{action: DEFER, by, at}`; the gate's open-CONFLICT rule already treats a resolved claim as closed, so the unit's gate opens carrying its OQ — the lite form of binding-mode `[D]`) | `tests/jit-bind/test-derive-and-write-binding.sh` +1 |
| 12 | dead hints in code (`generate-intent --refresh`, `enrich-semantics`) | v7 removals | reword: `--refresh` → "re-run generate-intent on the PRD"; `enrich-semantics` → "author the Stages block per vault-core.md §stages-propagation" | grep pin in `tests/leftover-sweep` style: `tests/surface/test-dead-mechanism-names.sh` (new; also pins `run-hook.sh`, `PostToolUse validator`, `tree-sitter engine` absent from scripts/hooks messages) |
| 13a | pack key `accessor_template` unread (laravel/slim/symfony) | validator reads `accessor_form` only; the three packs also declare `accessor_form` | delete the dead `accessor_template` line from the 3 packs + the 4 cached fixture `.out` copies; `_lint.md` names `accessor_form` as the only accessor key | `validate-pack.sh --all` green; `test-lens-wired` untouched |
| 13b | `## Security idioms` never reaches `build-dispatch-prompt.sh` | **by design** — `_template.md §Security idioms`: the implementer receives only idioms that also carry a `HARD_RULE` row (T2 pack rules); the section itself feeds the security lens | **WONTFIX** (already the documented mechanism; wiring the section would add ~0.5 KB per dispatch with no field evidence — evidence-first rule) | none |
| 14 | B3 sanctioned-extras regex narrower than the old implementer instruction | doc already equals the regex | **WONTFIX** — widening the sanctioned set loosens a gate; dir-based patterns (`tests?/`, `spec/`) already cover Java/Ruby/C# conventions | none |
| 15 | `state_probes.probe_prd_candidates` never sees `<vault>/source/seed-PRD.md` | from-prompt writes the seed under `.mega-sdd/vaults/<slug>/source/` | probe also lists `.mega-sdd/vaults/*/source/seed-PRD.md` (prefixed relname); `validate-scope-flag.sh` PRD search gets the same glob | `tests/state/test-derive-state.sh` +1 |
| 16 | `binding_present_for_drift` FATAL on a lite vault | `c_binding_confirmed` reads `binding.md` only | layout-3 (`context.md` present): satisfied when any `bolts/U-*/binding.json` exists; hint names `execute-bolts --all --lite` / `rebind-units.sh` | `tests/scripts/test-predictive-preflight.sh` +1 |
| 17 | `resolution_source` / `recommendation_citation` documented, "no writer" | the writer EXISTS: `derive-vault-json.sh --patch` carries non-derived per-OQ keys | resolve-oq SKILL derive rule shows the `--patch` form beside `--event` (doc fix only; `test-derive-vault-json` +1 proves the patch lane keeps the two keys) | `tests/v8-layout3/…` no; `plugins/mega-sdd/tests/oq/` +1 |
| 18 | `bypass_commits[]` has no writer | `run-full-suite.sh` writes `_batch-suite.json`; the audit moved the doc to `_summary.md` (controller-written) | `run-full-suite.sh --base=<sha>` computes the out-of-band list (commits in `<base>..HEAD` touching a `target_files` path without an `SDD-PROVENANCE` trailer, excluding the run's own bolt commits) and writes `bypass_commits[]` into `_batch-suite.json`; docs point there (the `_summary.md` line becomes a mirror) | `tests/batch-suite-gate/test-batch-suite-gate.sh` +1 |
| 19 | PBT `Cites: §D-NNN` resolver only reads `decisions/D-*.md` | layout-2/3 keep ADRs inline as `### D-NNN: title` in `vault.md` / `context.md` | inventory also scans the vault docs for `^###\s+(D-[A-Z0-9-]*\d+)` headings (all layouts, legacy `04-decisions.md` included) | `tests/…pbt` via `plugins/mega-sdd/tests/moat/` +1 |
| 20 | ci-recipe Recipe 3 `grep stale=0` | doc fixed in 8.3.1 | done (no code) | — |

## 2. Test / fixture debt (audit §7 tail)

- `tests/skill-triggering/plan.test.md` — NEW (mirrors the other `*.test.md`: trigger cases, negative cases, lane rail, `--reconcile`, sibling validator with `--cwd`).
- `execute-bolts.test.md` BH5/BH8 — expectations rewritten to the main-thread depth-1 squad loop + cross-squad concurrent dispatch bounded by `parallel_max` (per `batch-and-fanout.md §--per-squad`).
- `seed-playground.sh` — prints `/mega-sdd` (the front door), not the removed `/mega-sdd:auto` alias.
- Golden `f2-ui` — the "see CLAUDE.md Fork A" pointer in `references/ui-design-heuristics.md` (a corpus-frozen doc) is dead → reworded; `GOLDEN_REGEN=1` for f2 only, reason in the commit. Same dead pointer in two script comments.
- `scope-picker.test.md` + `scenario-7` — the "default after 5s" timeout does not exist (AskUserQuestion has no timer) → confirm-once with Enter = default.
- `resolve-oq.test.md` REC7/REC8/REC10b — keep; the writer is the `--patch` lane (§1 #17).
- Fixture `.cache/pack-resolver/*.out` ×4 — the dead `accessor_template` line removed alongside the packs (§1 #13a). `pack-kit/bad-pack.md` untouched (negative fixture).

## 3. Owner decisions (audit §8) — decided here

| Item | Decision | Applied as |
|---|---|---|
| 6 skill-emitted halts unregistered (`drift_inputs_missing`, `scan_spawn_budget_exceeded`, `scan_repo_too_large`, `scan_primary_app_ambiguous`, `codebase_map_derive_failed`, `codebase_map_invalid`) | REGISTER — each has a live emitter in a skill body | index rows + family sections (flow ×1, scan ×5); taxonomy: `drift_inputs_missing` + scan STOPs → always-stop; `codebase_map_*` → always-stop |
| 4 emit-agents-md halts (`user_authored_conflict`, `vault_not_found`, `vault_corrupt`, `greenfield_no_bind_context`) | REGISTER (emitted under `--auto`) | emit family ×4; taxonomy always-stop |
| `scope_args_missing` (script-emitted by `validate-handoff-yaml.sh`) | REGISTER | flow family; taxonomy always-stop |
| subtype `claim_verify_failed` | REGISTER as `quality_gate_failed` subtype (extract) | subtype row + enum; `test-family-split d2c` re-pinned 7 → 8 (live set grew) |
| `vault_json_corrupt` (new, §1 #6) | REGISTER as C1 self-resolve detection | flow family; taxonomy self-resolve |
| `path_stale_pending_restart` | NOT a halt type — a `note` value on `install_failed` | no row; wording already says "note" |
| `routing_outcome_corrupt` | DEAD (no emitter anywhere; removed 7.3.0) | nothing to register |
| hook-gate validator codes (`binding_missing`, `conflict_unresolved`, …) | NOT halt types — they are validator DROP codes that map to a halt per the emitting skill (`conflict_unresolved` ⇒ `binding_conflict`) | one sentence in the registry index preamble |
| registry byte cap | 34 000 → 36 000 (`test-family-split b1`; +11 terse rows + preamble sentence) — same lift pattern as 8.0.0 | test comment states the reason |
| `next_action.type` enum: 9 of 12 values without emitter | PRUNE to the values with a user: `re_run_producer`, `user_review`, `chain_complete` (script-emitted) + `invoke_skill`, `inspect_subskill_logs` (handoff fixtures / scenario-6) | the other 7 removed from the enum; `hint` stays free text |
| `partial_state_corrupt`: registry C1 vs saga "ALWAYS STOP" | registry wins (C1, script-enforced via ground.sh) | saga doc reworded |
| `.mega-sdd/project.md` (no producer) | REWORD — the vault list lives in the front-door status view (`/mega-sdd` no-arg, derive-state) | `using-mega-sdd/SKILL.md:75` (outside the anchor core) |
| `_diagnostics/kb-skipped-artifacts.md`, `<vault>/.mega-sdd/vault-diffs/*.patch` | DOCUMENT in `paths.md` (diagnostics outputs, no reader by design) | two rows |
| `halt_auto_propose`, `emit_agents_md` | `emit_agents_md` added to `project-config.md` yaml block; `halt_auto_propose` already there (user-scope) | one yaml line |
| `benchmarks/tasks/T01/files.lite.txt` STALE | REPLACE with the 8.x plan → bolts list derived in the audit (33 entries) | header states the derivation; results/ untouched |
| anchor `using-mega-sdd` Hard-gate line classic-only (byte pin 3844) | RE-BASELINE — the lane qualifier goes back in; pins move to the new measured length (≤ 4030 cap) | `tests/extras` + `tests/playwright-embed` comments carry the reason |
| version archaeology in skill/reference bodies | DIET — remove release/round/iteration tags that carry no consumer (`(7.21.0)`, `(v8 P1.e …)`, `(round B1)`, `Iter 71 —`, `S5 GU-HOOK-1`) from prose; KEEP tool versions, model IDs, `CHANGELOG x.y.z` pointers, spec dates, byte-pinned surfaces (anchor core, f2 corpus docs, golden inputs), frontmatter | measured before/after in the CHANGELOG entry |

## 4. Out of scope here (still owner budget / office)

Clinic levers measurement (paid xs runs), P4 office field run, extras live run, the scm push (VPN). Listed so the debt ledger is complete, not because this cycle touches them.

## 5. Follow-up (8.4.1) — heading / ToC archaeology + model-tiers rationale cells

The 8.4.0 diet left headings untouched (renaming a heading moves its `§` anchor and its `## Contents` mirror). This follow-up renames the headings that carried only provenance and moves every mirror with them, in one script with assert-once replacements:

| Heading (before → after) | Mirrors moved |
|---|---|
| `## KB mode (7.21.0 — spec …)` → `## KB mode (spec …)` | none |
| `## Adversarial test review pass (Step 9.5 — closes audit D4-006)` → `(Step 9.5)` | SKILL.md step 9.5 prose |
| `## Lite lane exemption (v8 P2)` → `## Lite lane exemption` | `tests/v8-plan/test-lite-2hop.sh` re-pinned to the prefix (the pin is about the section existing) |
| `## Rotation policy (per ITER6-OQ-7 resolved)` → `## Rotation policy` | ToC anchor |
| `### Concurrency contract (closes audit D3-012)` → `### Concurrency contract` | none (`§Concurrency contract` cites keep matching) |
| `## Migration command (per ITER6-OQ-2 resolved explicit)` → `## Migration command` | ToC |
| `## One-screen halt (W1 zero-idle, v8 P1.e — spec …)` → `(W1 zero-idle — spec …)` | none |
| `### XS emission (… §1b, approved 2026-09-05)` → `(… §1b)` | none |
| `## Specialist references (… — v7 R4 loading contract)` (execute-bolts) → `(load on the stated condition)` | none |
| `# Shared Snapshot Schema (v1.1, Iter 30 → extended Iter 46)` + 4 producer/consumer sub-headings | intro paragraph reworded |
| `## Register — natural, bukan baku (mandat …, 2026-08-31; ronde 3 …)` → `(mandat user + tim: bahasa apa pun)`; `## OQ authoring — human-first (mandat tim, 2026-09-02)` → `(mandat tim)` | test pins the prefix only |
| `## v7.1 office rollout runbook (…)` → `## Office rollout runbook (…)`; rationale cells `(scan-codebase Iter 32)` ×4, `Claim-verify lane (7.25.0)` | first two table cells untouched (`ground.sh` parses `\| N \| \`role\` \|` only) |
| `## P5 seams (declared in P3 — resolved in P5)` → `## Doc-pack seams (declared, deliberately not generalized)`; `### Doc-pack sidecar scripts (P5 — …)` → `(doc-specific, not engine spine)` | ToC + 5 `§P5 seams` citations (3 templates, emit-prd, emit-sit) |
| `## Vault layout (v7 layout-2 ↔ legacy 7-file)`, `### Layout-3 (v8, … ; 8.0)` | ToC |
| `## §halt-protocol — Unified \`blocker\` envelope (v0.14, extended v1.1)`, `### Type-specific schemas (v1.1 additions)`, `pre-v0.15` ×2 | `§halt-protocol` / `§Type-specific schemas` cites keep matching; registry shrinks |
| `## Vault write-back protocol (Step 5.5 — living-vault S5)` → `(Step 5.5)` | detect-drift SKILL prose |
| `## Step 0.5 — Pre-flight upstream check (NEW)` → drop `(NEW)` | ToC already bare |
| `## enrich-semantics` tombstone section + its ToC line REMOVED (diagnostics-procedures) | chain-execution pointer reworded |
| ToC anchor `#multi-squad-detection-v11` → `#multi-squad-detection` | heading was already bare |

Kept on purpose: `## AMENDMENT 2026-07-31` / `## Re-decided amendments (2026-07-31)` (dated measurement records, test-pinned), W1/W2 feature names, schema-version headings in `starterkit-context-schema.md` (runtime discriminators), `queries/VERSIONS.md` (pinned catalog), spec-file pointers.

Audit-driven hardening T2/T3 (listed as "spec'd, not built" in the session memory) were verified SHIPPED in 7.10.0 / 7.11.0 / 7.12.0 (`docs/superpowers/specs/2026-08-30-audit-driven-hardening.md` §2.4, §3.5, §6) — nothing to build; the memory note was stale.

## 6. Verification

Both test trees (`find plugins/mega-sdd/tests tests -name 'test-*.sh' -o -name '*.test.sh'`, stdin `/dev/null`), `validate-pack.sh --all` + `--check-registry`, `claude plugin validate`, manifest = CHANGELOG tag, GitHub CI on the pushed HEAD. Dispatch golden regen limited to f2 with the reason in the commit.
