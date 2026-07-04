# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Pre-v3.65.0 history rotated to [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** (latest rotation 2026-06-24). Rotation rule: when this file exceeds 2,000 lines OR 30 versions, oldest 50% rotate to archive.

## [4.64.0] - 2026-07-03

Handoff-seam fix — **bind's advisory tech-OQ recommendations no longer stall the `--deep` chain** (cross-stage consistency sweep, Batch 1; the one survivor that broke a *live* pipeline). bind mapped "tech-OQ recommendations need review" to handoff `status: paused`, calling it "informational; downstream still runs" — but `paused` is **stop-and-wait** in the orchestrator loop (handoff-contract.md §"Orchestrator MUST NOT invoke `next_action.suggested_skill` if `paused`/`halted`"). So under `/mega-sdd:auto --deep` a brownfield bind that surfaced a recommendation **stalled before `generate-units`**, demanding a manual `--resume` the producer docs themselves said was unnecessary — directly contradicting the tech-OQ-autoresolve spec (recommendations are advisory, reviewed *post*-binding, "should not block humans").

### Fixed

- `skills/bind-codebase/references/auto-memory-handoff.md` + `skills/orchestrate-flow/references/handoff-contract.md` (bind index §) — a surfaced tech-OQ recommendation now keeps `status: completed`; bind auto-continues to `generate-units`. The recommendation stays in binding.md "## Tech-OQ Recommendations (review required)" and the OQ carries into `generate-units` as a **pending, ungrounded** OQ (never a baked-in decision — ACCEPT/OVERRIDE/REJECT still available anytime). `paused`/`halted` are reserved for genuinely blocking cases (CONFLICT, `oq_recommend_underspecified`/`_citation_invalid`, and business-OQ under `--strict`).
- `skills/orchestrate-flow/references/handoff-contract.md:248` — the generic `paused` definition dropped "tech-OQ recommendations needing review" from its example (kept "business OQs needing resolution", which stays live for generate-intent DC5).

### Changed

- `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` — **§11.5 amendment** records the corrected handoff-status mapping and *why* the `paused` mis-wire happened (the handoff-status contract postdated the Iter-1 design, so the status value was under-specified and later filled in wrong).
- Fixtures: `tests/skill-triggering/bind-codebase.test.md` TQ5 now pins the producer status (`completed`, not `paused`); new `orchestrate-flow.test.md` DC7 pins the consumer side (chain does NOT pause on an advisory recommendation).

> **Flagged for follow-up (not this fix):** `auto.test.md` HP3 expects bind to emit `status: paused` for business OQs under `--strict`, but `bind SKILL.md` §gate says `--strict AND oq>0` → `halted`. That `paused`-vs-`halted` reconciliation is a *separate* OQ class from tech-OQ recommendations and is deferred to the round-2 seam audit.

## [4.63.0] - 2026-07-03

Tooling — **fork-measurement driver (`measure-fork-ab.sh`)**, the friction-guarded scaffold for the detect-drift `context: fork` A/B (backlog #18; the precondition, per `plugins/mega-sdd/CLAUDE.md` + the `moat-token-tradeoff` memory, before extending fork to `scan-codebase`/`bind-codebase`). The A/B is two **manual** `/mega-sdd:detect-drift` runs and no script can automate them or close the real open blocker (the baseline confound is a *methodology* constraint, not a tooling gap). What the driver removes are the two **silent footguns** that would let a fresh operator record a phantom verdict.

### Added

- `scripts/measure-fork-ab.sh` — thin `capture <baseline|fork>` / `compare` / `status` / `reset` wrapper around `report-token-cost.sh` + `measure-fork-tokens.sh`, with:
  - **Arm-aware `subagent_turns` guard (the new catch).** A fork's cost is a `subagent_end_marker` (`subagent_turns>0`); an inline run has none. `capture baseline` REFUSES if a fork ran (`subagent_turns>0`) — the signature of the **wrong-plugin-instance** footgun (you stripped `context: fork` from the dev checkout but the session loaded the marketplace **cache**, so the "baseline" still forked → baseline==fork → phantom NO-WIN). `capture fork` REFUSES if `subagent_turns==0` (SubagentStop didn't fire, or the loaded instance lacks the fork). This verifies which instance the harness *actually loaded* by runtime behaviour, not a file checksum.
  - **Baseline-confound recorded, never judged.** Capture/compare surface the inline baseline's accumulated-context proxy (`cache_read` tokens) as raw numbers and write them to `.mega-sdd/.fork-ab/result.json` with `confound.judged: false` — the tool records so a future reader can trust-or-reject the delta; it never fabricates a representativeness verdict.
  - `compare` always passes `--require-subagent`; drops to `measure-fork-tokens.sh` as the documented escape hatch.
- `tests/fork-measurement/test-measure-fork-ab.sh` — 28-assertion contract test pinning both guards (wrong-instance refuse, uncaptured-fork refuse), the confound record, and `compare`/`status`/`reset` wiring, all from seeded telemetry (no live harness run).

### Changed

- `research/2026-06-26-fork-token-measurement-procedure.md` — added **Precondition 2** (the SKILL.md you edit must be the plugin the session loads; cache-vs-dev-checkout, verified on-machine 2026-07-03) and a **guarded fast-path runbook**. The one open blocker is unchanged (the baseline confound — a representative-session run).

## [4.62.0] - 2026-07-03

Moat hardening — **B1 recompute-at-gate** (closes the last artifact-trust gap in the execute-bolts moat). The v4.59.0 S6 amendment re-derived the SIX *derived* bolt-stage states from ground truth before the gate reads them, but B1's `postflight.json` was still the hold-out: the gate re-ran `--postflight-scan` in read-only mode, which only re-**read** the recorded `status`/`verdict` in the artifact — it never re-executed the rules. So B1's status was trust-based, protected only by the Write/Edit + Bash write-guards (a best-effort verb-enumeration deny, not a cryptographic guarantee). The gate now RECOMPUTES B1's mechanical evidence from git/fs ground truth, at parity with the other six states. Spec amendment: `2026-06-26-batch-suite-gate-and-bypass-guard.md § B1 recompute-at-gate`.

### Fixed
- **The execute-bolts gate recomputes B1 from ground truth.** New `validate-bolt-artifacts.sh --postflight-scan --recompute` (wired at pre-tool-use line ~423, immediately before the aggregator read at ~493 — verified the *sole* blocking reader of `.bolt-postflight-state.json`): for each committed Hard-rule bolt it re-executes the unit's mechanical rules (v1 productions + v2 ast-grep) from ground truth via the shared engine and **OVERWRITES** `postflight.json` before the state is derived. A forged/stale/absent artifact is regenerated — a hand-planted `{status:pass}` can no longer open the gate. Under `--recompute`, an *absent* artifact is *produced* from ground truth (not flagged `evidence_missing`); `postflight_evidence_missing` now means a **recomputed non-pass verdict**. This is a strengthening: failing rules block *more precisely*, and the gate re-verifies against current HEAD every run (catching a FILE_PRESENCE/SIGNATURE regression a stale-but-honest artifact would have hidden).
- **Read-only mode unchanged; two modes, two contracts.** Plain `--postflight-scan` (the Stop hook + `run-postflight-scan.sh`'s self-refresh) *retains* the evidence-present contract (absent artifact ⇒ `evidence_missing`). The gate (recompute) is authoritative — its overwrite lands before the read, so a transient between-turns `evidence_missing` self-heals at the next gate. The Stop hook stays read-only deliberately (a recompute on every turn-end vs once before a multi-minute bolt run).
- **The "run the scan" obligation is preserved where it matters.** A **directive** Hard rule still blocks under recompute (no prior artifact ⇒ no attestation carry-forward ⇒ `directive_unverified` ⇒ FAIL, forcing `run-postflight-scan.sh --attest-directives`); a **mechanical** rule is verified directly, so separately requiring the agent to run the scan was redundant paperwork. Directive attestation is carried forward from the prior artifact (`verdict==attested`) — no weaker than before, because directives were always human-trust-based. `scan_unit` reclassifies every rule by its **text** (STRICT v1 regexes first), so a mechanical rule cannot be relabelled a directive to dodge recompute. Obligation stickiness (EB-GATE-8) unchanged: rules are read from the unit text AT the bolt commit.
- **Shared engine + incidental monorepo fix.** The rule engine is factored into NEW `scripts/_lib/postflight_rules.py` (`walk_unit_commits` + `scan_unit`), imported by BOTH `run-postflight-scan.sh` (proven **byte-identical** to the pre-refactor inline engine — 0 diffs across 11 rule shapes) AND the gate's recompute, so an honest artifact can never false-block on engine drift. The shared walk uses the `-- .` pathspec (EB-VAL-5 form), which *also corrects* `run-postflight-scan.sh`'s previous `-- <PREFIX>` pathspec (matched nothing when the vault lived under a monorepo subproject).
- **Cost bound (measured).** One `git log -300 --name-status -- .` walk shared across all units, one `scan_unit` per Hard-rule unit — **no cache** (a cache file is itself a forge vector), **no parallelism** (overhead + Windows Git Bash fragility). On a pessimal 300-commit / 50-Hard-rule-unit fixture (SIGNATURE git-grep per unit): **~7.3s @ 50 units → ~15s @ 100**, within the hot-path budget. Fires only on `Skill(mega-sdd:execute-bolts)`, once per invocation. **Honest ceiling:** B1 *mechanical* rules recompute; directives stay `attested` via carry-forward; **B2** (the ~387s full suite) stays evidence-based — re-running a suite inside a PreToolUse hook is the inflation the doctrine forbids.
- **Tests**: NEW `tests/postflight-evidence/test-postflight-recompute.sh` (forged-pass→recomputed-fail overwrite, honest-pass kept, directive attestation carry-forward, obligation stickiness). `test-6a-gate-hooks.sh` upgraded — the forged-PASS-overwritten assertion now plants a forged `postflight.json` PASS for a unit whose Hard rule *genuinely* fails on recompute (FILE_PRESENCE for a file the bolt never creates), asserting the gate overwrites both the artifact and the state to a real FAIL; its nested-project isolation case (F3) now tests root-isolation against a *genuine* parent B1 FAIL. `test-postflight-scan.sh` (unchanged) pins the read-only evidence-present contract.

Versions: plugin/marketplace 4.62.0.

## [4.61.0] - 2026-07-03

Test reconciliation — **main CI green again** (red since v4.57.0). CI (`.github/workflows/tests.yml`) runs BOTH test trees, but local runs only exercised the top-level `tests/` tree (the "137 tests" canonical suite, always green), so 3 secondary-tree moat tests under `plugins/mega-sdd/tests/` shipped RED across v4.57→v4.60 unnoticed. Root cause: those tests hand-planted synthetic gate states (`echo '{"status":"FAIL"}' > .mega-sdd/.<gate>-state.json`) and assumed the aggregator reads them directly — but the S5/S6 hardening (v4.57–4.59) made the execute-bolts gate **re-derive every state from ground truth before reading it** (EB-GATE-1/5). So the planted FAIL was overwritten with the fixtures' real (clean) state before the aggregator saw it → the gate correctly did not block → the tests failed. **The product is correct and stronger; the tests were stale.** No product behavior change in this release — only the 3 tests were rewritten to assert against REAL violations that survive re-derivation (the same pattern the passing top-level suites already use).

### Fixed
- **`tests/moat/test-moat-corrupt-fail-closed.sh`** — its "fail-closed on a corrupt `.validation-blockers.json`" premise was superseded by moat re-derivation (a corrupt cache is regenerated, never trusted). Rewritten to pin the stronger contract in BOTH directions: a corrupt cache can neither HIDE a real unresolved CONFLICT (re-derives to FAIL → blocks) nor SPURIOUSLY block a clean tree (re-derives to PASS → allows). Uses a real `### CONFLICT-N` binding (ASCII hyphen — the moat reader lacks `errors="replace"`, so a non-ASCII em-dash was a latent codec dependency).
- **`tests/round3/test-moat-gates-wired.sh`** — B2 (flow-coverage) and B2c (verify-grounding) rewritten to use isolated fixtures with a REAL flow-coverage shortfall (a Laravel flow whose input steps have no matching Form-Request artifact) and a REAL verify+HIGH ungrounded unit — both survive gate-time re-derivation. The static wiring pins and B2a/B2b/B3/B4 are unchanged.
- **`tests/round3/test-pretooluse-shortcircuit.sh`** — SC2/SC3 rewritten to drive from a genuine subfolder (`src/module`) under a project whose gate FAILs on a REAL verify-grounding violation, so the walk-up moat-safety is exercised end-to-end (the SC0b static pin already confirmed the short-circuit uses `resolve_project_root`, so this was never a real bypass hole — only a stale-fixture failure).

Versions: plugin/marketplace 4.61.0.

## [4.60.0] - 2026-07-03

Perf — **framework-pack linter ~12× faster** (`scripts/validate-pack.sh`), no behavior change. Root cause: Check 4 (the hint-section YAML-fence validator) ran a per-line `printf | grep` pipeline — ~10 subshell forks **per line** of the pack — so a single 170-line pack lint forked ~1,700 processes and took ~7.6s (of which Check 4 alone was ~7.0s). The per-line matching was rewritten to fork-free bash builtins (`[[ == ]]` substring/prefix, `[[ =~ ^```[[:space:]]*$ ]]` for the fence-end — verified byte-for-byte equivalent to the former `grep -E '^```\s*$'` on macOS/BSD grep). Output is **byte-identical** (rc + every line) across all 26 packs incl. the violation-producing `_template.md` — verified by diffing old-vs-new on the full pack set; `_registry.md` is unchanged.

### Fixed
- **Pack lint ~7.6s → ~0.6s per pack** (11.8× measured across laravel/django/axum/gin/rails/express/spring-boot + `_template`). `validate-pack.sh --check-registry`: ~200s → ~24s. The full test suite (137 tests): **~2189s → 387s (5.7×)** — and `tests/per-stack-packs/run-all.sh` no longer exceeds the 600s per-test budget, so the suite goes **136/137 → 137/137** (the prior lone "failure" was that aggregator timing out, never a real assertion failure). No new state/cache surface added — the fix is the algorithmic root cause, not memoization.

Versions: plugin/marketplace 4.60.0.

## [4.59.0] - 2026-07-03

Fix — **execute-bolts hardening** (god-review of `execute-bolts`, stage 6 — the FINAL pipeline stage: bolt dispatch, TDD discipline, review panel, Hard-rule pre/post-flight, B1/B2 artifact gates). 37 verified findings (10 High / 19 Medium / 8 Low after refute-by-default verification; 3 refuted of 40; 50 agents), headline class: **the bolt stage's own "enforced, not prose" gates were prose in practice** — all three deterministic bolt-commit discoveries keyed on a `(bolt): U-XXX` grammar no producer contract ever emitted (every doc-conformant `feat(U-XXX):` bolt ran with B1/B2/orphan silently dormant, `bolt_commits_seen: 0` → PASS), the B1/B2 evidence artifacts were agent-writable while the gates trusted their self-reported status (and the deny texts literally coached writing `{status:green}`), a symbolic `head_sha: "HEAD"` voided the B2 freshness anchor forever, a python `open(...,'w')` slipped the anti-self-bypass verb net, and a state-litter `.mega-sdd/` under a sub-cwd forked gate truth entirely. Grounding doc: `research/2026-07-02-god-review-execute-bolts.md`. Spec amendment: `2026-06-26-batch-suite-gate-and-bypass-guard.md §S6` + review-panel design §models.

### Fixed
- **6A (High EB-GATE-1/4/5/6/8) — gate/hook truth restored.** The execute-bolts gate now **re-derives all six bolt-stage/quality states** (orphans, batch-suite, postflight, whitelist, ui-quality, cross-cutting, factory-ledger) before the aggregator reads them — a forged/stale/absent state is overwritten with current truth (neutralizes the python-write forge vector wholesale). The B1/B2 **evidence artifacts** (`postflight.json`, `_batch-suite.json`) joined the Write/Edit deny + Bash tamper guard; new Bash verbs covered (python open-for-write, `write_text`, `dd of=`, `install(1)`); every forgery-coaching remediation text replaced with the sanctioned-writer route. `resolve_project_root` returns the nearest **substantive** root (vaults/knowledge-base/codebase/config.yaml) so validator-minted state litter never shadows the true root, and read-side validators SKIP instead of mkdir-ing phantom roots. B1 reads the unit's `task_type`/`## Hard rules` **at the bolt commit** (`git show`) — a retroactive blank/flip cannot erase the obligation.
- **6B (High EB-GATE-2, EB-VAL-1/2/3/4 + Med VAL-5/6/8, EB-GATE-12, VAL-9/10, PHANTOM-3) — validators compute the truth they claim.** Commit identity widened to the CANONICAL contract: `<type>(U-XXX):` scope, `Unit:` trailer, legacy `(bolt): U-XXX` — one `git log --name-only` pass (replaces 300 per-commit `git show` subprocesses), pathspec-scoped to `git rev-parse --show-prefix` (a sibling monorepo project's bolts no longer activate/starve this project's gates; state-only commits no longer invalidate a pinned green suite). `covers()` requires a full 40-hex `head_sha`. Unit/report/postflight/_batch-suite lookups go through NEW `scripts/_lib/vault_layouts.py` (mirrors discover_units' 10 layouts; parity pinned by test — legacy `*-bound/` B1 obligations detected, legacy `_batch-suite.json` clears B2). factory-ledger type-coerces `attempt` (stringified numbers → FAIL CLOSED `phase_stuck`, not crash-open exit 2 over a stale PASS) and writes a FAIL state on ANY exception. cross-cutting-registration discovery signatures moved INTO the pack schema (`source_decl_regex`/`target_decl_regex` — Laravel hardcodes deleted; keyless concerns report `not_evaluable` + overall SKIP, never a 0-files-scanned PASS) and parses ALL yaml fences of the pack chain. ui-quality prunes wrapper dirs (backup/old/docs/fixtures). `has_hard_rules` skips `<`-prefixed lines (HTML-comment placeholders no longer create unpayable B1 obligations); unit-spec Check-2 heading regex tolerates the canonical template's parenthetical. PBT citation compare case-normalized; file-path state write atomic; `--strict-provenance` phantom deleted.
- **6A/6D (Med EB-GATE-11) — the B3 whitelist observer ships** (the v4.58 "stage-6 backlog" item): `validate-bolt-artifacts.sh --whitelist-scan` diffs each bolted unit's COMMITTED paths against `target_files` ∪ sanctioned extras (vault/bolt artifacts, `.mega-sdd/`, test-file shapes) → `.bolt-whitelist-state.json` (Stop-hook + gate-time re-derived + guard-protected); escapes block the next execute-bolts with `whitelist_violation`. Every whitelist-wording surface upgraded from "honored (no observer yet)" to the three-layer truth.
- **6A (High EB-GATE-4) — deterministic evidence writers.** NEW `scripts/run-full-suite.sh` (detects the project runner manifest-first — composer/pest/phpunit/artisan, yarn/pnpm/npm, pytest, go, cargo, rspec, mix — runs the FULL suite, records `_batch-suite.json` with the pinned 40-hex HEAD itself) and NEW `scripts/run-postflight-scan.sh` (executes the unit's Hard rules against real git/filesystem state: DO_NOT_MODIFY via commit-touch/preflight-sha, DO_NOT_ADD_DEPS via manifest dep-key diff, NAMING via added-file case check, SIGNATURE via decl compare, FILE_PRESENCE via probe, v2 via `ast-grep scan`; generic directives recorded `directive_unverified` unless `--attest-directives` — the `attested` verdict is accepted for directive-typed rules ONLY). Both artifacts are hook-guarded; the wrappers are the only sanctioned write path, and the B1 remediation heals through them (the old advice deadlocked against the gate).
- **6C (High EB-GATE-3, EB-HONEST-1 + the honesty/coherence set) — one truth per contract.** Commit topology unified everywhere to **detect-after** (the implementer commits after tests pass; L0/panel/post-flight run against that landed commit): "HALTS BEFORE COMMIT"/"left uncommitted" claims rewritten across SKILL.md, hard-rule-scan, code-gates, superpowers-bridge, review-panel, batch-and-fanout — incl. the `secret_in_code` halt, which now honestly demands rotate + history-purge (the old text claimed an already-committed secret never shipped). Canonical bolt-halt enum (28 types incl. NEW `review_critical_unresolved` — panel Critical surviving the retry budget is now a terminal halt with its own YAML) owned by halts-and-handoff; handoff-contract's two blocks regenerated from it. Canonical bolt-report schema gains mandatory `target_hashes`, the `halted_postflight`/`forced_pass` statuses, and the mandated `## Review panel` section. `migrate-v1-rules.sh` stopped fabricating: logs `detected (delegated to skill)` (never `migrated` over byte-identical files), accepts `--to=v2`/rejects `--to=v1` honestly, detects all 5 v1 productions, tty-guards its interactive prompt (no more `.tmp` litter). Phantom claims deleted: per-lens `model_tiers` override (frontmatter pins are the runtime truth; catalog↔frontmatter parity is a release obligation), `ast-grep test --validate` (parse-via-scan is the single owner), ui-deferral/dispatch-prompt "blocks execute-bolts" (advisory per the demotion list; post-tool-use comments fixed). spec-reviewer's body rewritten to the blind-panel input contract (base/head SHAs + diff; NEVER the implementer's report); all five lenses carry an explicit read-only rail. Dispatch prompt gains the reuse-index T1 line + T2 slice section Iron Rule 4 promised, the both-trailers commit scaffold, and the typed-blocker↔status mapping (`missing_dependency`→`dep_missing`). `--parallel` overlap rail (disjoint `target_files`) copied to batch-and-fanout + squad-subagent (cross-squad units have no depends_on edges — the rail is the only anti-clobber). `bolt_introduces_locked_drift` resolved to override-only everywhere. Pack→bolt Hard-rule translation table added (bind-codebase §2.9a; packs ship `rule_type` inventories, not ast-grep blocks); 12.4.5/12.5b reconciled to one-grammar-per-unit. Unit `risk:` frontmatter is now panel tier-selection signal 6 (high/critical forces `full`). CLI entry doc lists all real flags (`--review-panel`, `--no-code-gates`, `--no-full-suite` + newly declared `--no-empty-commits`, `--no-drift-check`); anchor-freshness probe documented at assembly time ("Anchors verified N/N" is only printed when probed; stale → `ANCHOR STALE` label, never a re-stamped bind-era HIGH).
- **6D — tests**: NEW `tests/god-review-s6/` (4 suites, real hooks + validators end-to-end): forged-PASS overwritten at gate time, evidence-artifact Write/Bash denies + sanctioned-writer pass-through, new tamper verbs, litter-root vs substantive-root resolution, 3-channel commit identity, symbolic-sha rejection, legacy-layout parity, factory-ledger fail-closed, monorepo scoping, retro-edit stickiness, layout-parity pin (vault_layouts ≡ discover_units), postflight/full-suite writer round-trips + B1 heal loop, B3 escape/declare/sanction, cross-cutting pack-schema + SKIP honesty, migrate-detector honesty, and the doc-coherence pin set (topology, trailers, enum sync, phantoms, read-only rails).
- **6E (fix-review hardening of the 6A–6D validators — blind 5-lens attacker panel + refute-by-default verifiers) — the walk-and-scan edge cases.** The commit-walk is subtree-scoped via `git log --name-only -- .` (repo-root-relative names) so a sub-cwd / monorepo project's B1/B2/B3/orphan gates scope to THIS project instead of matching nothing, with a git ≥ 2.23 probe falling back to a subject-only walk format on older git. Vault exclusion uses `_in_bound_vault()` (only real vault roots carrying `units/`|`bolts/`) so real code paths like `src/io-bound/` are never mistaken for a bound-vault. The B1 post-flight writer's SIGNATURE_RULE uses `[[:space:]]` (BSD/macOS `grep -E` does not honor `\s`) and excludes `.mega-sdd/`/`docs/mega-sdd/`/`.md` from the declaration scan; NAMING_RULE handles double-extension files (`user-profile.blade.php`) via `basename.split(".",1)[0]` + a `**`-recursive `_glob_match()`; DO_NOT_ADD_DEPS diffs against the empty-tree hash on a root commit (no parent). `resolve-project-root` counts a bound vault as a substantive marker; the pre-tool-use anti-bypass net covers `os.path.join` open-for-write and vault-anchors the FP guard so a user's own `bolts/` evidence isn't false-blocked; `validate-ui-quality` prunes only wrapper dirs (never shipping `docs/`/`examples/`); cross-cutting-registration PASSes only when every concern was actually evaluated. NEW pins: `tests/god-review-s6/test-6e-fixrev-regressions.sh` (monorepo scope, io-bound+B3, real-src signature, double-ext naming, root-commit deps, FP-guard vault anchor, os.path.join open-for-write).

Versions: plugin/marketplace 4.59.0 · execute-bolts 2.15.0 · bind-codebase 2.6.2 · generate-units 2.11.1 · orchestrate-flow 2.12.4.

## [4.58.0] - 2026-07-02

Fix — **generate-units hardening** (god-review of `generate-units`, stage 5 — the decomposer: task_type, DAG, anchors, acceptance tests, and the unit-stage quality gates). 32 verified findings (10 High / 11 Medium / 11 Low after refute-by-default verification; 5 refuted; 46 agents), headline class: **the unit-stage gate STATE was structurally incapable of holding the truth** — `.unit-spec-state.json` was a single slot overwritten on every unit write (last-writer-wins: only the LAST-written unit was ever gated, so a `verify`+HIGH unit certifying UNBUILT behavior sailed into execute-bolts whenever any clean sibling saved after it — empirically reproduced with a control run: identical disk state, opposite gate verdicts, decided purely by write ORDER), every quality-gate state file except the moat was one `rm`/forged-PASS `Write` away from cleared, and units written via Bash never triggered any validator. Grounding doc: `research/2026-07-02-god-review-generate-units.md`. Spec amendments: sharpen-code-delivery design §prologue + graph-layer design.

### Fixed
- **5A (High GU-HOOK-1/2/3 + Med HOOK-4 + Low HOOK-5) — the unit-stage gates are now real.** `validate-unit-spec.sh` merges EVERY unit (both layouts, all vaults, legacy `*-bound/`) into ONE project-wide state on every run — `--file-path` now selects the focal unit for stdout/exit only, never the state scope. The execute-bolts PreToolUse gate **re-derives** unit-spec (project mode) + flow-coverage + sibling-consistency before reading their states — closing the Bash-written-unit stale-PASS hole (dispatch was keyed exclusively to the Write|Edit tool path), the async-PostToolUse TOCTOU (gate read racing backgrounded validators), and making a deleted state harmless. All nine quality-gate state files joined the anti-self-bypass PROTECTED list (Bash rm/redirect/sed/tee) AND the Write/Edit deny (`.plan-pending`/`.iter-classifier.json` stay writable — documented orchestrate-flow paths). flow-coverage + sibling-consistency scan **ALL vaults** with vault-scoped matching (the most-units heuristic silently un-gated every smaller vault in a phased rebuild).
- **5B (High GU-TASKTYPE-ENUM-1 / GU-VUS-A1-DOC-ANCHOR-1 / GU-VUS-TF-SWALLOW-1 / GU-HR-GRAMMAR-1 + Med TTCONTRACT-1 / VUS-AT-PRESENCE-1 / SK-CITE-2 + Low GCONF-1) — validate-unit-spec judges what the schema mandates.** `task_type` is a CLOSED, case-normalized, quote-tolerant enum — `Verify`, `"verify"`, and `modify` all silently disarmed the A1 rail and every per-type contract before (one casing character opened the worst-class false-green path); `grounding_confidence` tolerates quoted scalars the same way. A1 rejects doc anchors (`.mega-sdd/**`, `*.md`) and line-less anchors — the vault/PRD markdown itself passed as "non-test source" grounding, the exact criteria-live-only-in-the-PRD class the rail was built to block. `_collect_target_files`' `\s*` matched the NEWLINE and swallowed the FIRST frontmatter item, so `render_test_missing` never fired when the detail view was the first/only target file (gate outcome depended on list ORDER). The "closed 5-production" Hard-rule grammar's undocumented catch-alls are replaced by an honest split — the 5 machine-checkable productions counted separately from generic `- MUST …` directive prose — and bullet-EVASION shapes (`* NEVER …`, `1. … MUST …`, bare directive lines: invisible to the bolt-time snapshot) are now `hard_rule_unparseable`, with Citation/Source annotation lines + fenced ast-grep YAML + indented continuations whitelisted. Per-task_type contracts check CONTENT: empty `## Anchors`/`## Migration notes` flagged; Migration notes missing any of ADD/KEEP/REMOVE flagged; a create/verify unit WITH Migration notes flagged (the 12.5.d MUST-NOT direction was unchecked). `acceptance_test` presence is machine-checked (the schema's "No exceptions" rail had NO deterministic observer while the validator's own header claimed coverage). The starterkit citation check accepts BOTH documented shapes (`Citation:` + lowercase `citation:` — the derivation template's own shape was false-flagged); starterkit-derivation's templates now render the machine-read shape and state the detection scope honestly.
- **5C (High GU-FC-FRONTMATTER / GU-FLOWCOV-1 + Med PACKLINT-GATES + Low SKC-INDENT / STATE-ATOMIC) — flow-coverage & pack gates.** flow-coverage reads FRONTMATTER `target_files` (union with the body block, mirroring unit-spec) — the canonical schema location was invisible, so every schema-conformant unit on an endpoint_kinds pack got a PERMANENT false FAIL (artifacts_listed always 0) whose remediation instructed adding a non-schema body block. Step derivation is **mermaid-first**: the v4.53.0 mermaid mandate made the col-0 `- [ ]` DoD checklist shadow the mermaid branch (dead code on every canonical vault — DoD prose reported as "steps", per-transition units false-FAILed, signal-free-DoD flows false-PASSed the gate's founding defect class); a mermaid fence whose edges carry input signals is now authoritative, with the DoD/numbered fallback kept for signal-free labels and legacy flows. `validate-pack.sh` lints gate-driving section headers (a typo'd `## Flow artifact derivation` silently downgraded TWO blocking gates to SKIP via the `_universal` fallback) and flags an unrewritten `extends: <other-pack-or-null>` scaffold placeholder (broken chain walk). starterkit-conformance's patterns parser is indentation-RELATIVE (the schema doc's own example shape parsed to ZERO patterns → silent SKIP disabled every conformance check) and fail-louds with ERROR when `patterns:` exists but nothing parses. fanout-parity + starterkit-conformance state writes are atomic (tmp+os.replace, the AUDIT-L4 convention their siblings already had).
- **5D (High GU-KEEPVAULT-1 + Med SPLIT-DEPS-4 / RISK-FIELD-1 / PBT-REJECT-5 / WHITELIST-6 / HANDOFF-DRIFT-1 / MODFLAG-1 + Low GRAPH-CONFLICT-1 / ATOMID-1 / GCONF-1 / SQUADREF-1 / HALT-TAXO-1 / PROBE-ANCHOR-3 / RECONCILE-MATCH-6 / FORCECREATE-DEDUP-7) — contract truth.** Resolved-KEEP_VAULT conflicts got their missing task_type route: `extend` TOWARD THE VAULT CLAIM (never a no-code `verify` — which validly discharged the code-update obligation before, certifying the vault-DIVERGING code as correct; the CONFIRMED+CONFLICT halt is scoped to UNRESOLVED so the documented resolve-oq→generate-units handoff no longer deadlocks; bind's hard-rules ref names the carrier). The mandated SPLIT chain edge is strict-deps evidence class (f) — Step 2.5 ordered an edge Step 4's whitelist forbade, so a rule-following agent dropped it and the verify/create pair parallelized. The `risk:` frontmatter field is schema-defined with a named producer (Step 2.5 stamps it per the adversarial-test-prompt risk signals) — the automatic adversarial-review escalation was keyed to a field NOTHING wrote. pbt-integration's "REJECTED at render pass" claim now names a real check (new 12.5.h properties-citation check, model-executed tier stated). The four `target_files` whitelist "enforced" claims state the honest tier (prompt-level rule + review panel; no deterministic post-hoc observer — stage-6 backlog). The generate-units handoff blocks sync (emitted_at, `unit_oq_trace_missing` + module/interface halts in BOTH enum lists, canonical nested paths — the operative example taught the banned legacy `-bound/` path that fails the artifact-existence check). Phantom recovery flags (`--derive-modules`/`--refresh-modules`) eradicated — recovery routes through Step 4.5's `modules.yaml.auto` + promotion (`mv`), and execute-bolts' `--module=` halt instructs the promotion. build-graph types CONFLICT-NNN binding_refs as `conflict` nodes (were permanently-pending mislabeled "claim" nodes on the impact lens) and claim nodes carry the v4.57.0 `state_reason`/`resolution` sidecar fields. Smaller: dotted split-ID grammar removed (sequential U-00N; content-hash ID-stability preserved); grounding_confidence semantics reconciled with the A1 gate (prescriptive for verify+HIGH); `squad-partition.md` refs use the cross-skill form; the emitterless `target_files_collision` alias renamed to `dedup_ambiguous`; the verify-without-anchor halt got its YAML + the SKILL parenthetical reconciled with the probe rule; `dedup_ambiguous`'s reconcile-lane second trigger documented with `binding_refs` as the primary match key; Step 12.6 honors the user's 7.6 force-create decision (no double-vote) and probes the FILESYSTEM first (codebase-map §1 is depth-limited); the `--force-overwrite (NOT YET IMPLEMENTED)` phantom removed.

An adversarial review round (5 attackers over the working-tree diff → refute-by-default verify; 22 confirmed/downgraded across ~14 unique defects, 3 refuted — the fifth consecutive stage where attacking my own fixes paid) then closed real holes INSIDE the first cut: the all-vault scan **double-counted the legacy `<vault>-bound/` sibling layout** (the sibling probe + the standalone candidate collected the same units twice, mis-tagged them, and flipped a real shortfall to PASS at the gate — a HEAD-blocked→NEW-open regression; the base vault now owns the pair, realpath-deduped, in BOTH flow-coverage and sibling-consistency); **one leading space defeated the Hard-rule evasion net** (the indented-continuation whitelist ran before every shape check — continuations now only shelter under an OPEN rule head, and dash rules validate stripped at any indent); the A1 doc-anchor rejection had a **`lstrip("./")` char-set bug** that let relative `.mega-sdd/` non-.md artifact anchors ground a verify+HIGH (prefix-strip fix), while the blanket `*.md` rejection over-blocked markdown-SOURCE projects (now scoped: mega-sdd artifacts + docs/spec dirs + spec-doc names; other .md grounds); `_section_body` required undecorated headings (`## Anchors (from binding)` false-flagged — HEAD-accepted suffixes tolerated again); the advertised machine-checkable/directive split was **dead locals** (now `hard_rules_machine_checkable`/`hard_rules_directive_prose` in the state); the project sweep missed `docs/mega-sdd/vaults/**` + nested `*-bound` layouts its own focal filter accepts (a project-mode re-derive ERASED their recorded FAILs — discovery widened); the gate re-derive was conditioned on `.mega-sdd/vaults` existing (root `*-bound` legacy skipped — now unconditional); `find -delete`/`truncate`/python-removal verbs joined the anti-self-bypass grep; the mermaid-first rule let ONE coarse summary edge suppress five signal-bearing NUMBERED steps (numbered enumeration now wins when it carries more signals; the DoD checklist still never overrides mermaid — that over-count was the original false-FAIL); the SKC parser locked onto the FIRST `patterns:`-shaped line anywhere (nested sub-keys shadowed the canonical block — every candidate is tried, first that parses wins) and extras: children clobbered category fields (field-indent lock); `scaffold-pack.sh` emitted the exact `extends:` placeholder the new lint rejects (skeleton now defaults `extends: _universal` and passes its own lint); and three command surfaces still claimed the whitelist "enforced" (honest-tier wording).

Pinned by `tests/god-review-s5/` (5A drives the REAL hooks: masked-order A1 deny, rm/forged-Write denies, deleted-state re-derive, Bash-written-unit gating, multi-vault block, clean-project pass; 5B empirical validator matrix over enum/A1-anchors/grammar-evasion/contract-content/acceptance-presence/citation-shapes/TF-first-item; 5C empirical canonical-vault PASS + signal-free-mermaid fallback FAIL + all-vault state + pack-lint typo/placeholder + SKC indentation/fail-loud + atomic-write pins; 5D contract pins + empirical build-graph node typing). `plugin` == `marketplace` 4.58.0; generate-units 2.10.0 → 2.11.0 (consumers: execute-bolts 2.14.3, orchestrate-flow 2.12.3, bind-codebase 2.6.1).

## [4.57.0] - 2026-07-02

Fix — **bind-codebase hardening** (god-review of `bind-codebase`, stage 4 — the moat's heart: CONFIRMED/CONFLICT/OQ + the CONFLICT gate). 22 verified findings (8 High / 8 Medium / 6 Low after refute-by-default verification; 5 refuted; 36 agents), headline class: **invariant #2 was deterministically violable** — the moat-state writer was keyed to the CONSUMER (unit) write path while CONFLICT truth is written on the PRODUCER (binding) path, so a re-bind/sync introducing fresh CONFLICTs left a stale PASS and `execute-bolts` sailed through an unresolved CONFLICT in the exact lane the docs attest is gate-equivalent ("sync never bypasses the moat"). Grounding doc: `research/2026-07-02-god-review-bind-codebase.md`. Spec amendment: `docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md` §4.

### Fixed
- **4A (High BC-GATE-1/BYPASS-1/BINDING-DELETE + Med BYPASS-2 + Low MSG-1) — the CONFLICT gate is now real end-to-end.** `validate-handoff-binding-units.sh` (sole writer of `.validation-blockers.json`) now ALSO dispatches on binding-doc writes (PostToolUse; canonical per-vault `binding-phase-*.md` paths included), AND the execute-bolts PreToolUse gate lazily re-validates whenever any binding doc or unit file is at-least-as-new as the moat state — or the state is ABSENT while binding docs exist ("absent = allow" no longer survives an existing binding surface). Empirically pinned with the real hooks: stale-PASS + fresh `### CONFLICT-1` → deny; absent-state → deny; structural resolution → gate re-opens. The anti-self-bypass guard now covers the sibling write tools — a `Write`/`Edit` of `.validation-blockers.json` (forged PASS) is denied, not just Bash mutations; the `tests/`-substring exemption applies only when the protected-file reference ITSELF is a test path (a `# cleanup for tests/` comment token no longer disables the guard — fail-closed on a python hiccup); `rm` of a binding doc under `.mega-sdd/vaults/` is denied; and the validator fails CLOSED (`binding_missing`) when units cite CONFLICT-IDs with zero binding docs present — deleting `binding.md` no longer flips FAIL→PASS one indirection later. Deny messages + the validator `next_action` are drop-type aware: conflict-class drops route to `/mega-sdd:resolve-oq --binding`, never to the OQ-frontmatter fix that cannot clear them.
- **4B (High BC-GATE-2/HANDOFF-1/HANDOFF-2 + Med VAL-6 + Low ADV-ID) — the handoff validator judges what bind actually writes.** Resolution markers are now STRUCTURAL: ✅/RESOLVED counts only in the conflict heading line or on a dedicated `- **Resolution**:`/`- **Status**:` line — the old whole-block substring match classified an ACTIVE `Verdict: CONFLICT (BLOCKING)` entry as resolved whenever its prose contained ordinary business vocabulary ("a ticket can be marked resolved") or a benign `✅ verified anchor` bullet (false-unblock of invariant #2); the advisory classification validator mirrors the rule. A `### C-NNN … — CONFLICT (BLOCKING)` claim-ID heading (the historical/phase-lane form the constitution reference models) is now an active conflict — verdict-text-keyed, so plain C-NNN claim headings can't false-positive. The OQ regex finally matches bind's own numeric fresh-OQ form (`OQ-001`/`OQ-12` per the template's Open Questions table — previously dropped OQs passed silently; same blind spot fixed in `validate-vault-oqs.sh`). OQ harvesting is section-aware: IDs confined to the Tech-OQ Auto-Resolved / Auto-Resolved Deferred / Recommendations sections are advisory extras (`oq_id_resolved_uncited`), not blocking drops — a clean brownfield bind with one auto-resolved tech-OQ no longer deterministically FAILs the moat with a rule the user never violated (live-section IDs keep the drop; an ID in both counts as live, fail-closed). `CONFLICT-ADV-N` (template-blessed advisor form) is now visible to `validate-conflict-classification.sh` (was SKIP/"no conflicts" on an all-advisor binding); SKILL Step 2.12 and the template agree both forms are canonical.
- **4C (High BC-PREFLIGHT-LEGACY/TRUNC-1 + Med STALE-1/MAPARG-1/STATE-2) — producer→consumer parity.** The predictive preflight probes the SAME map order bind does (canonical nested → legacy `<root>/codebase-map.md`) — a pre-migration project no longer gets a deterministic FATAL deny on every bind against a map the skill happily consumes. The v4.56.0 truncation protection now survives its first consumer: bind writes the reason onto the binding surface (`truncated §N` in the Anchor cell + `state_reason: truncated_section` in `binding.json`) and generate-units routes truncation-sourced UNKNOWN through a **direct repo probe** (found → `verify` with the probed anchor; not found → `create` with absence verified against the repo, not the capped map) — the old `Any UNKNOWN → create` row silently defeated the "never a create-type task from a truncated section" promise one hop downstream. The task_type table also gained its unmapped inputs: IMPLEMENTED at medium/low confidence → treated as UNKNOWN (a fuzzy anchor must not mint a false "already built" verify; `defensive-generation.md`'s contradicting unconditional IMPLEMENTED→verify row is qualified), PARTIAL_FIELDS_BOTH explicitly assigns `extend`, and row precedence is defined. `snapshot-verified` provenance now requires the map's `last_scanned_commit` == current HEAD in addition to the sha256 match (the sha alone proves the FILE is unchanged, not that the code hasn't moved — a bind after an unscanned refactor stamped "verified" over false CONFIRMEDs); the map schema's attestation now describes what bind actually does. The explicit second-positional map path no longer escapes the DEGENERATE-MAP gate: the hook extracts it from the Skill args and validates THAT file (`--file-path`) — a degenerate custom map blocks, and a valid custom map is no longer falsely blocked by an unrelated degenerate canonical shell.
- **4D (Med BC-RESOLVE-TOKEN/PARITY-5COL/ADVISOR-RO-1/ANCHOR-ATTEST-1 + Low RECOMMEND-CONF-1/ADV-ID-docs/HANDOFF-3/VAL-6-docs/RSOQ-LIVELOCK) — contract truth.** `resolve-oq --binding`'s write-back markers (`CONFIRMED_PENDING_CODE_UPDATE`, "vault patched") were defined in no enum, landed in the summary table the gate never parses, and contained neither ✅ nor RESOLVED — the official recovery channel could not clear the gate it exists for; it now writes the structural marker grammar (`### ✅ CONFLICT-N RESOLVED (<ACTION>) — …` + a `- **Resolution**:` line), updates the summary row, and sets `binding.json` `claims[].resolution` (new schema field, alongside `state_reason`). The KEEP_VAULT livelock is closed: the hand-off is action-mix dependent (KEEP_CODE/SPLIT → re-bind; KEEP_VAULT/DEFER-only → proceed to generate-units — a re-bind re-raises the same CONFLICT from the unchanged contradiction by design), and `conflict-resolution.md`'s unimplemented "generated units include an update-code prerequisite task" promise is replaced with the real carrier (the CONFLICT-N `binding_refs` citation the propagation drop enforces). `validate-binding-json.sh`: aligned separators (`|:---:|`) are no longer phantom claims, a <6-cell State-Map row is an ERROR instead of a silent skip (a divergent md/json pair could pass parity cleanly), and an id-less `claims[]` entry is a clean exit-2 FAIL instead of an uncaught traceback; the template pins "ALWAYS 6 columns" (Field diff = `n/a` off-ast) so regex-tier bindings stop churning. `phase-advisor` lost `Bash` from its tool list — its "read-only, never modifies artifacts" attestation is now delivered by tooling, not prompt compliance (a misbehaving advisor could previously `sed -i` a CONFLICT away). `binding-json-schema.md`'s "anchor accuracy is enforced at bind time" is replaced with the honest story (authoring obligation + advisor sampling; the only deterministic anchor check is the A1 verify+HIGH rail). The tech-OQ recommend gate matches generate-intent's shipped heuristics (which emit recommend at `medium`): surfacing fires at high+medium, `low` passes through UNCHANGED — the `oq-resolution.md`/`binding-contract.md` contradiction (one said "flow through as blocking", mutating resolution_mode) is reconciled and the unimplemented `--accept-recommendations` flag prose is gone. `handoff-contract.md`'s bind block uses the canonical `<vault>/bound/` path + `emitted_at` (the banned legacy `vault-bound/` sibling is gone); example conflict IDs align to the canonical `CONFLICT-N` form (constitution halt YAML, SKILL halt YAML, resolve-oq presentation).

An adversarial review round (5 attackers over the working-tree diff → refute-by-default verify; 15 confirmed, 2 refuted) then closed real holes INSIDE the first cut — the fourth consecutive stage where this pays: the widened OQ regex had CREATED a new deterministic false-block (bind's own template-canonical fresh `OQ-001` in `## Open Questions` has no resolution to cite, yet the gate demanded a citation and denied execute-bolts on the happy path — pending-section OQs are now advisory `oq_id_pending_uncited`; LIVE means evidence-woven); the heading resolution marker matched the domain word inside a TITLE ("vault says tickets are auto-resolved" resolved itself — `RESOLVED` now counts only immediately after the conflict ID) and a negated `- **Status**: NOT RESOLVED` line counted as resolved (value must now START with the marker); the C-NNN blocking rule fired on a mid-prose mention of "CONFLICT (BLOCKING)" (now heading-trailing or a structural Verdict line only); the new Write/Edit guard was silently DISABLED for any project living under a `tests/`/`examples/` path segment (exemption now evaluated relative to PROJECT_ROOT, both branches) and it BROKE orchestrate-flow's documented Plan-mode `.plan-pending` Write (deny re-scoped to the moat state only — the other guard files keep Bash-branch tamper protection); the custom-map `--file-path` validation POISONED the shared state in both directions (a valid-custom PASS opened the next plain bind over a degenerate canonical map; a degenerate-custom FAIL blocked the next valid plain bind — the gate now snapshots and restores the canonical state around the custom run), its tokenizer validated the FIRST `.md` token (a vault doc named positionally became "the map" — vault paths excluded, last candidate wins, shlex honors quoted space-containing paths); the moat self-heal's ls globs missed the nested `units/U-*/unit.md` layout and backdated mtimes (cp -p/rsync -a restores) defeated the whole mtime heuristic — the gate now re-validates UNCONDITIONALLY when a vaults dir exists (sub-second validator on the execute-bolts-only path; current truth beats a stale cache at a gate); and two stale docs contradicting the new rules were synced (convergence-loops' unconditional resolve→re-bind loop = the exact KEEP_VAULT livelock 4D closed; lint-units' `IMPLEMENTED → verify` rule vs the new medium/low-confidence exception).

Pinned by `tests/god-review-s4/` (4A drives the REAL hooks end-to-end: stale-PASS re-bind → deny, absent-state → deny, PostToolUse producer dispatch, forged-PASS Write/Edit deny, comment-token guard, examples/-path-project guard retention, Plan-mode `.plan-pending` Write allowed, binding-delete both rails, resolve-oq routing; 4B fixture matrix over the resolution-marker grammar incl. title-word/negated-status/prose-mention regressions, C-NNN verdict-keying, numeric-OQ forms, section-aware harvesting incl. pending-advisory + live-overlap fail-closed + evidence-woven-LIVE drop; 4C empirical preflight legacy-path + custom-map-arg gate both directions + BOTH poisoning directions + quoted-space paths + vault-doc positional + doc pins for the truncation probe chain and staleness truth; 4D empirical parity-validator separator/short-row/id-less cases + contract-truth pins incl. plugin-wide eradication of the undefined resolution markers). Suite green. `plugin` == `marketplace` 4.57.0; bind-codebase 2.5.4 → 2.6.0 (consumers: generate-units 2.10.0, resolve-oq 2.3.0, orchestrate-flow 2.12.2, scan-codebase 2.17.1).

## [4.56.0] - 2026-07-02

Fix — **scan-codebase hardening** (god-review of `scan-codebase`, stage 3). 34 confirmed findings (4 High / 18 Medium / 12 Low after refute-by-default verification; 4 rejected; 0 dead lenses), three dominant classes: a deterministic gate wired to a write path the skill's own procedure never uses; framework DETECTION outrunning route/model EXTRACTION (whole-ecosystem false-empty ground truth); and prose attesting enforcement/perf that nothing delivers. Grounding doc: `research/2026-07-02-god-review-scan-codebase.md`.

### Fixed
- **3A (High INT-1 + V1/V5/V6/V7) — the DEGENERATE-MAP gate + `validate-codebase-map.sh` now see what they claim to.** The gate's state file was refreshed only by the PostToolUse `Write|Edit` glob, but Step 10a MANDATES temp-file + `mv` — so the state was stale in BOTH directions (fail-open on a fresh degenerate map = the clinic empty-shell scenario; a stale FAIL never clearable by the re-scan its own message prescribes). The bind-codebase PreToolUse gate now lazily re-validates when the map is newer than its state (GateGuard pattern), the PostToolUse dispatch also fires for the legacy `<root>/codebase-map.md` (which bind-codebase probes and binds against — was never validated), Step 10a instructs an explicit post-`mv` validate, and the validator itself: strips fenced code blocks + line-anchors headings/frontmatter (a map echoing the schema's own fenced skeleton counted as "all 7 sections present"), runs the interface-depth heuristic on the Signature CELL located by header name (the mandated `file.ts:42` citation in the File column satisfied the typed-field regex → the ast→binary degradation check was dead on every conformant map), requires `engine` + WARNs `codebase_map_staleness_stamp_missing` in a git repo (a map silently disabling the whole sync lane got a clean PASS), and accepts `--file-path`.
- **3B (High ECO-1/ECO-2 + SP-1/SP-5/V8) — detection↔extraction parity.** Step 8.5 detects `aspnetcore`/`dotnet` but Steps 6/7 had NO .NET signature rows and the `_universal` fallback never fires for a MATCHED framework → §3/§4 "None detected" on every .NET repo handed to binding as ground truth. Added ASP.NET attribute-routing + minimal-API route rows and an EF Core model row; the fallback is re-keyed to also fire on a signature-row gap (parity rail: detection must not outrun extraction; Step 7 gained the same fallback). The regex engine (the guaranteed no-native-deps baseline) had NO C#/F#/Kotlin patterns — `VERSIONS.md` even *promised* "Kotlin extracts via regex" — and the existing patterns missed the dominant forms (`export default async function`, `export enum`, `final class`, `public static function`, `async def`, Go receiver methods, `pub async fn`/`pub(crate)`/`pub type`): all patterns widened + three new language rows, every form pinned empirically from the doc text itself. `@remix-run/`/`@sveltejs/kit` now precede `express`/`fastify` (a Remix express-adapter app ships both deps; first-match-wins misdetected it as Express and lost every file-based route). The three-way language-coverage drift (SKILL said 3 query languages, integration ref listed 8, disk ships 9) is synced; the C# grammar is pinned.
- **3C (High AH-1 + AH-6) — the secret-scan gate delivers what it attests.** `secret-scan.sh --redact`'s PEM pattern (`[^-]*` self-terminates at the header's own dashes) stripped ONLY the `BEGIN` line and shipped the base64 key body + END marker while reporting `redacted:true` exit 0 — and removing the BEGIN marker made the residue LESS detectable downstream. The pattern now spans the whole block (DOTALL to the END marker) with a header-only fallback for truncated blocks and span-dedup (one finding per block); pinned by a no-body-survives fixture. The deep-scan write algorithm (Step 10.5.3) never named the scrub — it now runs `--redact` on BOTH temp files (starterkit-context.yaml + reuse-index.yaml, the file likeliest to embed a default credential in first-party signatures) before their `mv`; the gate prose names reuse-index.yaml.
- **3D (ECO-3, DS-1, DS-2, DS-6) — deep-scan cache correctness.** `compute-lock-digests.sh` emitted empty digests for .NET ("tech-agnostic by construction") → the cache never invalidated on NuGet changes; it now folds packages.lock.json / Directory.Packages.props / `*.csproj` (root, depth-1, and the dominant `src/<Project>/` depth-2 layout) into a dotnet digest — a dependency edit provably changes it. Slice signatures were lock-digest-only while slice OUTPUTS are source-derived — a controller/policy/tailwind edit produced FULL CACHE HIT forever; each manifest-fed slice signature now folds a source component (the pack's domain file-hint dirs listing+mtimes for auth/authz/ui_ux; the reuse slice's first-party source listing for libs, whose usage_hint greps that same tree) + the detector version. A twice-failed slice got a fresh per-slice signature anyway → `partial: true` never self-healed; failed domains now get NO per_slice entry and the staleness diff unions `prior.partial_slices`. The documented remediation for `starterkit_metrics_inconsistent` was `--force-deep`, which serves the same partial cache — corrected to `--no-cache`. The canonical schema documented 4 per_slice entries while the stage writes 5 (reuse) — schema now carries all 5 + a /5 invalidation matrix.
- **3E (SP-3/4/6/7/8/9) — incremental/sync lane.** Fallback-to-full-scan now triggers whenever the git delta channel is unavailable REGARDLESS of journal state (pre-fix: stamp-missing + any journaled AI write → incremental proceeded blind to every manual/pulled change, then the restamp laundered the staleness permanently); journal-only incremental survives only for not-a-git-repo with an explicit stale-risk warning. The staleness stamp uses `git rev-parse --verify 'HEAD^{commit}'` (a zero-commit repo — the scan-first scaffold flow — stamped the literal string "HEAD"); a literal-HEAD stamp reads as missing. Step 0 gained a per-language **grammar smoke test** — a default `brew install tree-sitter` ships ZERO grammars, so binary presence stamped `precision_tier: ast` over failed extraction; `ast` is now a verified claim and `grammars_used` lists exactly the languages that passed. The unexecutable `RG_OPTS` block (quoting broke rg on bash AND zsh) is replaced; "truncate the journal" (data-losing verb, 3 surfaces) → the operative rotate-and-delete consume protocol; the flag catalog documents both `--shallow-scan` semantics.
- **3F (INT-3/4/6, V3/V4, AH-3/4, DS-3/4/5/7/8) — contract & prose truth.** The operative `--auto` handoff hardcoded `next_action: generate-intent` unconditionally (contradicting the contract mirror, SKILL.md, and Mode D) → now CWD-conditional (no vault → generate-intent; vault → bind-codebase; sync lane → detect-drift) in ALL copies, and reuse-index.yaml + the shared snapshot are listed in `artifacts:` (the phantom `reuse_index:` handoff field is gone). The §3(routes)/§4(data models) numbering was INVERTED in `implementation-state.md`, `oq-resolution.md`, and `tree-sitter-integration.md` — all three corrected to the schema. "Read-only enforced at dispatch" (enforcement fiction — the extractors are prompt-template dispatches with no `tools:` allowlist) → honest rules-tier wording. Cap-200 truncation now stamps a `truncated_sections` frontmatter marker and binding treats absence-in-a-truncated-section as UNKNOWN (never a duplicate-implementation `create`); the ghost "file scan log" pointer is deleted. The libs slice self-contradiction (drop rule demands `_source` the libs schema never defined) → libs entries carry `_source` under a manifest grammar on all four surfaces. The snapshot's fabricated payoff ("bind skips re-tokenization, ~30-50% I/O") is deleted — the consumer's own contract says it is a freshness attestation, NOT a parsing shortcut — and the write-only `source_files_sha256_map` is now written empty for the codebase-map type (per-file hashes already live in §2). The dangling "memory SKILL.md §file-lock" anchor cited by ~6 files now EXISTS (defines the lock semantics + points at `memory-write.sh` and vault-contract §Concurrency contract). A 4th cross-cutting deep-scan rail (untrusted-data fence) + a DATA-FENCE note on `<MANIFEST_FACTS>`; the ghost `<FILE_HINTS>` variable is gone; the deep-scan trigger is specified in the string-enum domain (`high/medium` run, `low/fallback` skip — "≥ 0.5" compared against values that never exist numerically); symbol-graph attribution corrected (scan does NOT persist reference captures; generate-units builds + caches the graph — paths.md owner row fixed).

An adversarial review round (7 attackers over the working-tree diff, 31 confirmed findings) then closed real holes the first cut left — the highest-value ones INSIDE the new fixes themselves: the validator's state write **failed silently on a true legacy layout** (root map, no `.mega-sdd/` dir yet — ENOENT swallowed by the stderr redirects, so the DEGENERATE gate read nothing; state dir now auto-created); an explicit `--file-path` that didn't exist **silently fell back to probing** and reported PASS about a different file (now exit 2, state untouched); the PreToolUse self-heal's `-nt` compare loses same-second ties on bash-3.2 (state must now be STRICTLY newer); the new PEM whole-block regex could **swallow innocent text between a truncated and a complete block** (now kind-backreferenced `\1` + no-BEGIN-crossing body) and the truncated-block fallback **shipped the key body** while reporting `redacted:true` (fallback now consumes the contiguous base64 run); the DS-4 untrusted-data fence lived only in the rails SECTION — **no dispatched subagent ever received it** (now inside all 5 templates' CONSTRAINTS + the dispatcher build step); the dotnet digest globs capped at depth 2 and missed per-project `packages.lock.json` entirely (now a bounded pruned walk — depth 6, vendored dirs excluded, locked-mode NuGet covered); the widened regex rows carried PCRE-only `\w` that is a LITERAL under the `grep -E` fallback (all rows now POSIX-ERE-safe, plus `override fun` / `record struct` / `final readonly class` / `pub(in crate::x)` forms); the libs slice kept a src_component exemption its own usage_hint grep contradicts (now folds the reuse slice's source listing); the §3/§4 inversion survived in a fourth file (`defensive-generation.md`); the AH-3 truncation rule was **one-sided** (now also in bind-codebase's own `binding-contract.md` + `implementation-state.md` — the references the binder actually loads); the literal-`HEAD` stamp the batch defined as poison PASSed the validator's own stamp check (now WARN, with zero-commit-repo suppression); smaller: not-a-git + empty journal → full scan (vacuous incremental laundered freshness), scaffold-only repos skip the grammar smoke test instead of "failing" it, `scan-secrets-code.sh` PEM kinds synced, the §file-lock/vault-contract stale-steal divergence honestly annotated, `task-typing.md` symbol-graph attribution, the sync-lane spec amended per the behavior-change policy, and the vault-contract remediation updated to the post-DS-2 truth.

Pinned by `tests/god-review-s3/` (3A validator/gate fixture matrix incl. both INT-1 directions + raw-legacy/missing-file-path/literal-HEAD; 3B doc-extracted regex assertions across 25 real symbol forms + a no-`\w` POSIX pin + table-order + list-parity; 3C no-body-survives + truncated-block-body + cross-block-innocent-text + family regressions; 3D empirical dotnet digests incl. depth-3/per-project-lock/vendored-exclusion + cache-rule pins; 3E stamp guard empirical + wording pins; 3F cross-doc contract pins incl. plugin-wide §3/§4 negative grep + fence-in-templates count + binder-side truncation rule). Suite green (two pre-existing stale fixture tests surfaced by the wider driver were repaired to the CURRENT shipped design: `iter77` §4 asserted a hook block that was deliberately demoted to advisory per the enforcement list; the `dispatch-prompt` good fixture predated the Design-system line its validator now requires). `plugin` == `marketplace` 4.56.0; scan-codebase 2.16.0 → 2.17.0 (touched-consumer patch bumps: bind-codebase 2.5.4, generate-units 2.9.3, memory 1.5.2, generate-intent 2.10.1, orchestrate-flow 2.12.1).

## [4.55.0] - 2026-07-01

Fix — **generate-intent hardening** (god-review of `generate-intent`, stage 2). Two Critical validator↔spec drifts, a language-axis generalization gap (the Batch-1 defect class, one axis over — the vault is emitted in the *input* language, so English-only detectors go inert on an Indonesian vault), and a cluster of smaller correctness fixes. All four vault validators here are advisory (surfaced via `/mega-sdd:analyze`; nothing in PreToolUse / orchestrate-flow / run-analyze hard-blocks on them). Grounding doc: `research/2026-07-01-god-review-generate-intent.md`. Two review lenses died on API stalls in the first pass and were re-run (the re-run surfaced the second Critical) — the partial-pass guard held.

### Fixed
- **2A (Critical) — `validate-vault-oqs.sh` OQ-schema arm keyed on a phantom grammar.** It grepped the markdown for `[tech]` / `mode:` / `scan_target:`, but generate-intent emits `[tech / scan]` inline + `resolution_mode` / `scan_query` / `scan_citations` / `fallback_if_wrong` in `vault.json`. Net: the three OQ-tagging halts (`oq_tech_missing_mode` / `oq_scan_missing_query` / `oq_recommend_underspecified`) **never fired on any real vault** (fail-open on the anti-halu tagging moat), AND `oq_misclassified_tech` **false-fired** on a correctly-tagged `[tech / scan]` OQ. Root cause was a self-contradiction inside `vault-contract.md` (§Halt-taxonomy said `mode`/`scan_target`/`citations`; §Updated OQ schema said `resolution_mode`/`scan_query`/`scan_citations`) — both the regexes and the stale doc half are reconciled. The arm now reads the emitted markdown bracket grammar (mis-tag check) + `vault.json open_questions[]` as the structured authority (mode-dependent halts). English schema keys → language-invariant.
- **2B (Critical) — constitution "every clause source-cited" rail was enforced by nothing.** `vault-contract.md`'s shipped schema example modelled ~17/20 clauses uncited, including invented NFRs (`median < 200ms`); no validator checked per-clause source; and a clause is injected into each unit's `## Hard rules` as a `severity:error` BLOCKING gate at execute-bolts — so a defaulted/invented clause enforced fabrication as ground truth (the moat inverting on the default run). Added a per-clause source-token check to `validate-constitution.sh` (a clause with no `§` / `(source:…)` / KB-PRD anchor / `file:line` / link → FAIL, advisory-surfaced), reusing Batch-B's `_lib` citation grammar; handles both `- A-001:` and bold `- **A-001**:` clause formats (the bold format silently fail-opened the check first pass). Rewrote the schema example to placeholder values with an inline `(source: …)` on every clause; added the constitution rail to the Step-4 self-check (it was scoped to the 7-file spec, dropping the 8th file). Clause-ID + source-token are language-invariant.
- **2C (High) — the operator-UX rails went inert on an Indonesian vault.** `DECISION_STEP_RE` / `MAKER_CHECKER_CHAIN_RE` / `OPERATOR_SURFACE_RE` matched English only (`approve/reject/review/confirm`, literal `maker`), so on an Indonesian maker→checker vault the whole operator-UX block silently PASSed — the exact vault the rails exist to protect. Detection now keys the fast-path off **language-invariant** structural markers the skill already emits (`stages:` + `stage_id:` + `actor_role:`, a Mermaid `stateDiagram`, ≥2 distinct `actor_role` values) with the English arms as backward-compat fallback, and returns a **tristate**: a workflow-shaped flow whose stage/role structure can't be parsed (likely non-English) escalates to an advisory `operator_surface_uncheckable` — **never silent-PASS, never a false `operator_surface_missing`** (an English-density gate decides missing vs uncheckable). **Rail 2 (`design_source_oq_missing`) decoupled** from the English workflow gate (its inputs — `design_system_flags` + frozen OQ-DESIGN tokens — are language-invariant, so it runs unconditionally). `validate-vault-flow-staging.sh`'s English decision-verb arm gained the `stateDiagram` signal so an Indonesian flattened workflow is caught.
- **2D (Med/Low) —** `validate-vault-oqs.sh` now positively detects a **defaulted design standard** (a WCAG level / Material / palette-token value shipped with no source citation and no Design-Source OQ → advisory `defaulted_standard_uncited`; Rail 2 only checked the inverse). `validate-vault-flows.sh`'s Mermaid mandate no longer keys solely on `### F-<prefix>-NNN` — a non-F-prefix flow heading (and a 04-flows.md with no F-prefixed heading at all) no longer escapes the render gate; structural headings (Sources/Notes/…) are excluded. `validate-vault-binding-coverage.sh` advisory findings now surface as **WARN/exit 0** (were FAIL/exit 1), aligning the sibling `PASS|SKIP|WARN)exit 0` contract. `generate-intent` announces a suppressed flag (`--kb` silently dropped a co-present `--from-prompt`). Stripped two version-archaeology leaks (`from-prompt-mode.md` leaked `v0.1.0` into a generated seed-PRD; `squad-partition.md` "matches v1.2").

An adversarial review pass then closed several more holes the first cut left, all in the newly-added checks: the H2 `WCAG` arm required a version number, so the bare canonical form `WCAG AA` (the plugin's own default phrasing) slipped — version is now optional and the Tailwind palette list is complete (`purple`/`teal`/… no longer escape); `Material 3` no longer false-fires on ERP/warehouse material-numbering (requires the design-system word); the H2 scan + the Design-Source-OQ escape hatch now include `05-decisions.md` + `06-constraints.md` (the canonical NFR home a defaulted standard actually lands in); the operator-workflow verdict now needs **≥2 distinct `actor_role` values** (a bare `stages:` block is a single-actor wizard, which no longer false-fires `operator_surface_missing`) and only escalates a `stateDiagram` to `uncheckable` when the flow reads **non-English** (a benign English order/session lifecycle stays quiet); the English-density gate dropped tech-noun loanwords (`user`/`system`) that let a bilingual vault cry-wolf; the constitution `SOURCE_TOKEN_RE` stopped accepting a bare `(see …)`/`(per …)` parenthetical (a casual gesture was passing as a citation) and its clause anchor now handles heading/table/blockquote clause formats (with a WARN — never a vacuous PASS — when clause IDs exist but no clause line matches).

Pinned by a multi-stack / **multi-language** fixture matrix under `tests/god-review-s2/` (2A OQ-schema regimes; 2B constitution across all source forms + Indonesian + casual-parenthetical + heading-format; 2C English-vs-Indonesian operator rails + Rail-2 decoupling + benign-lifecycle + single-actor-wizard + flow-staging; 2D H2 bare/versioned/ERP/05-06-corpus, M1, L1). Suite 92/92 green; `plugin` == `marketplace` 4.55.0; generate-intent 2.9.0 → 2.10.0.

## [4.54.0] - 2026-07-01

Fix — **tech-agnostic validator hardening** (god-review of `extract-intelligence`, Batch 1). Four advisory KB validators were tuned on one PHP trade-finance codebase and silently fail-open / no-op on every other stack + domain — a direct hit on the contract's "plugin behavior must generalize" clause. All fixes stay advisory (confirmed: nothing in PreToolUse / orchestrate-flow / run-analyze hard-blocks on these). Grounding doc: `research/2026-07-01-god-review-extract-intelligence.md`.

### Fixed
- **H1 — `validate-kb-citations.sh` fail-open extension whitelist.** The `php|js|py|…` allow-list had no `cs` (nor `cshtml`/`kt`/`tsx`/`scala`/`twig`/`xml`/`ini`/`sh`), so a C#/.NET/Kotlin/TSX §11 matched **zero** citations → silent `SKIP`-green, the anti-hallucination grounding check doing nothing for whole ecosystems. Now a generic letter-led extension (shared `_lib/citation_pattern.py`). A grounded KB (has `[VERIFIED]`) whose §11 yields 0 citations now emits **WARN** (not silent SKIP); a §11 marked `_None detected_`/N/A stays exempt.
- **M7 — `validate-kb-markers.sh` accepted non-file tokens.** `\\w+:\\d+` scored a regulation/version/time token (`23.2:2021`, `1.5:1`, `09.30:00`) as a citation. The shared pattern now requires a **letter-led** extension, so a `[VERIFIED]` claim citing only a regulation number is correctly flagged uncited. H1 + M7 share one grammar (`_lib/citation_pattern.py`) so they can't drift.
- **M5 — `audit-domain-rules.sh` no-op green.** Hardcoded Indonesian bank-regulator acronyms (PBI/POJK/OJK/…) meant a GDPR/HIPAA/PCI KB matched 0 rules → `PASS` "0/0" (false compliance assurance). Now: 0 rules parsed from a KB that carries regulatory content → **WARN** "supply a regulatory pack"; a genuinely non-regulatory domain still PASSes (no false WARN). Acronym set kept swappable.
- **M6 — `kb-leak-scan.sh` skipped three KB dirs.** `SCAN_DIRS` omitted `00-overview`, `40-business-rules`, `99-rebuild-architecture` (a `DbContext`/`@Entity`/`Eloquent`/`gorm` leak there passed clean). Added — **section-aware**: skips `## Departures from Legacy` (legitimate framework names) and blanks a table's Source / Mandated-by column (legacy paths), while still flagging a leak in a rule's text cell.
- **M4 — `validate-kb-citations.sh` project-specific legacy-root + fallback.** Manifest auto-detect gated only on `index.php/composer.json/package.json/Gemfile`; now probes every §8.5 ecosystem (`go.mod`/`Cargo.toml`/`*.csproj`/`*.sln`/`pom.xml`/`build.gradle`/`pyproject.toml`/…) and `_source/`. The hardcoded `input/report/generate/approval` subdir list → a **bounded** recursive basename walk (depth + file caps, skips `node_modules`/`vendor`/…); a basename resolving to **≥2 files is ambiguous, not a pass**.
- **L4 — `kb-leak-scan.sh`** UNIVERSAL DB tokens gained Oracle/DB2/MariaDB (`Oracle`, `VARCHAR2`, `NCLOB`, `NUMBER(`, `DB2`) — an Oracle-backed legacy no longer leaks clean.
- **L5 — `kb-leak-scan.sh` gates** call `--stack=all` (was `--stack=auto`, which narrowed to the legacy language and missed **target-stack** idiom leaks like `IServiceCollection`/`[HttpGet]` on a PHP→.NET rebuild). A tech-agnostic KB must be neutral to both stacks.

An adversarial review pass then closed four more real holes the first cut missed: the M7 grammar was defeated on the DOMINANT backtick-wrapped path by a leftover hand-rolled check (removed); the M6 table-column blanking hijacked a content column when a *data* row said "source of funds" (header detection now requires the `|---|` separator row, so a real leak in a later row isn't hidden); the M4 basename resolver re-walked the whole legacy tree per citation (now one indexed walk + a broader dep-dir skip set); the shared grammar rejected extensionless sources like `Gemfile:3`/`Dockerfile:5` (now supported alongside dotfiles, keeping the letter-led-ext rule so reg-tokens stay out). Plus: `audit-domain-rules` WARN keys on regulatory CONTENT not the always-emitted `regulatory-rules.md` stub; `run-analyze` delegates legacy-root detection to the validator and surfaces KB-grounding WARNs in the overall banner.

Pinned by a multi-stack fixture matrix (`tests/tech-agnostic/test-validator-hardening.sh` — C#/Go/Java/Rust/Python × GDPR/HIPAA/PCI + a non-regulatory clean domain, + the review-round regressions). Suite green; `plugin` == `marketplace` 4.54.0; extract-intelligence 1.13.0 → 1.14.0.

## [4.53.0] - 2026-07-01

Feature — **Mermaid-flows hard rule + render-correctness.** Every flow mega-sdd generates is a Mermaid diagram (never a prose Steps list or ASCII arrows), and — new — that diagram must actually **render**. Spec: `docs/superpowers/specs/2026-07-01-mermaid-flows-hard-rule.md`. All checks are advisory (never a hard block), consistent with every existing flow gate.

### The render-correctness gap (user-reported: "some generated Mermaid doesn't render")
A field scan against the real `mermaid.parse()` proved the Rule 1–3 quoting heuristic was only a *subset* of what renders. The #1 miss: a ` ```mermaid ` block with **no diagram-type header** (a header-less edge fragment or a `[placeholder]`) passes the quoting checks yet fails with mermaid's "No diagram type detected". Closed by two layers.

### Added
- **Shared tokenizer `scripts/_lib/mermaid_syntax.py`.** The Rule 1–3 syntax checker was extracted from `validate-kb-flows.sh` into one module both KB and vault flow gates import — never fork the checker per surface. Byte-behavior locked by `tests/mermaid-flows/test-kb-flows-syntax-lock.sh`.
- **Rule 0 — diagram-type required (`check_diagram_type`).** Every mermaid block must open with a recognized diagram type (`flowchart`/`stateDiagram-v2`/…), else `mermaid_no_diagram_type`; empty block → `mermaid_empty_block`. Ground-truthed against `mermaid.parse()`: catches the header-less class with **zero** false positives on 36 valid diagrams. Wired into `validate-kb-flows.sh` (§3+§8).
- **`validate-vault-flows.sh` (new) + hook wire.** Each `### F-<prefix>-NNN` flow in a vault `04-flows.md` must carry a Mermaid diagram; a prose-only flow → `vault_flow_not_mermaid`. Fires from PostToolUse on `04-flows.md` writes (advisory), reusing the shared tokenizer.
- **Opt-in real-parser ground truth `scripts/verify-mermaid.sh` + `_lib/mermaid_parse_oracle.mjs`.** Runs the actual mermaid grammar (`mermaid.parse()`, **headless — no Chromium**) over every block; catches reserved-word `end` nodes, unterminated shapes, bad transition labels — whatever the heuristic can't. Best-effort: SKIPs cleanly when Node/mermaid are absent. For CI / on-demand, not the per-write hook.

### Changed
- **`validate-kb-flows.sh` §8 State Machine — L7 fixed.** A non-N/A §8 with transition arrows but no ` ```mermaid ` fence now **FAILs** (`kb_flow_not_mermaid`), mirroring §3 — previously a silent PASS ("consider a fence"). Subsumes god-review finding L7 (`research/2026-07-01-god-review-extract-intelligence.md`). extract-intelligence 1.12.0 → 1.13.0.
- **Vault flow template + producer guidance = Mermaid.** `generate-intent`'s `templates/04-flows.md` replaces prose numbered `Steps:` with a mandatory `flowchart` per flow (metadata — Actor/DoD/Source, staged `stages:` block — untouched); `generation-guide.md` + `vault-contract.md` reworded so the flow body is a diagram, not a Steps list. generate-intent 2.8.0 → 2.9.0.
- **`references/mermaid-emission-rules.md`** widened to every flow surface + Rule 0, present-tense (dropped version-archaeology from the scope statement).
- **`detect-drift` (3.0.0 → 3.1.0) + `diff-vault` (2.0.0 → 2.1.0)** report-format notes: a flow written into `04-flows.md` is authored as Mermaid (inherited surfaces — LLM-read, no script parser to change).

Suite green (`tests/mermaid-flows/` — 4 new tests); no regression (shared-lib refactor byte-locked; hook wiring verified, 0 golden-fixture breakage); `plugin` == `marketplace` 4.53.0.

## [4.52.0] - 2026-06-29

Feature — **output-language L3 (Tier-3 artifact pointers)**, the final batch of the output-language feature (L1+L2 shipped in 4.51.0). **Collapsed from the scouted 6 skills to 2 + a doc-honesty fix** after a discriminating-test pass — this batch is intentionally small, not truncated.

### The discriminating test
*Does the skill author new prose into a plugin-owned standalone artifact, or write into vault content / machine structure?* Only the former gets a Tier-3 language pointer.

### Added (the 2 that pass the test)
- **`emit-fsd` (1.2.2 → 1.3.0) — the spine.** FSD body prose → Indonesian by default, **but quoted/flattened source excerpts (PRD, constitution, binding quotes) and every `[Source: sha256:…]` citation are reproduced in their source language, never translated.** This directly reinforces moat invariant #3 (citation discipline) and is now pinned by the test.
- **`analyze` (2.1.0 → 2.2.0).** `CONSISTENCY-REPORT.md` analysis/recommendation prose → Indonesian; boundary verdicts `PASS`/`FAIL`, validator IDs, paths stay English.

### Fixed (mandatory — "prose that lies" in the shipped census)
- **`references/output-language.md` Tier-3 row corrected.** The 4.51.0 row read *"Recommendations / analysis prose (analyze, lint, drift, bind recs) → Indonesian"* — which (a) claimed `detect-drift`/`bind-codebase` artifact recs are Indonesian while those skills are deliberately left vault-language, and (b) named `lint`, which is a command (`commands/lint-units.md`), not a prose-emitting skill. Reworded to a **surface split**: what these skills *say to the user* is Tier-2 chat (Indonesian via the anchor); what they *record into a vault artifact* (drift rationale, OQ resolution answers, verbatim `binding.md` claims) stays the vault's language.

### Deliberately NOT given a pointer
- `detect-drift`, `resolve-oq`, `bind-codebase` (write vault content — the "don't translate vault docs" boundary), `lint-units` (not a prose emitter), `generate-units` (machine specs; chat covered by anchor), `emit-agents-md` (AGENTS.md stays English).

Suite green + pack gates; `plugin` == `marketplace` 4.52.0.

## [4.51.0] - 2026-06-29

Feature — **runtime output defaults to Indonesian + English technical terms** (extensible to any language, zero new code). An Indonesian team gets native-language narration out of the box without each member relying on a personal `CLAUDE.md`; non-Indonesian users stay fully served. Batch **L1 (spine) + L2 (control seam)** of the output-language feature — shipped as one atomic unit (the default is not "live" until both land). Spec: `docs/superpowers/specs/2026-06-29-output-language-default-id.md`.

### Model — 3 tiers + strict precedence
- **Tier 1 (Frozen)** — structural/machine-parsed tokens stay **English always** (`CONFIRMED`/`CONFLICT`/`OQ`, enums, IDs, field names, paths, commands). **Tier 2 (Narration)** — chat/halts/recommendations default Indonesian-mix. **Tier 3 (Artifact)** — per-audience (FSD prose ID; `AGENTS.md`/`vault.json`/binding structure EN; **cited source content keeps its source language** — citation discipline).
- **Precedence (serves non-ID users by rule):** explicit request this session > the language the user writes in > Indonesian for short/ambiguous input (`gas`/`go`/`lanjut`). An English-writing user gets English by rule (2), never a wall of Indonesian.

### Added
- **`plugins/mega-sdd/references/output-language.md`** — the policy + precedence + the full Tier-1 do-not-translate census + the Tier-3 per-artifact table. Loaded on demand; itself an English directive doc.
- **`tests/output-language/test-output-language.sh`** (REQUIRED per the behavior-change contract) — pins (a) the anchor names Indonesian + the precedence order and lives in the injected core, (b) the census carries every Tier-1 enum family (drift = silent gate-break risk), (c) the canonical default+precedence+pointer is present in all seven carrier files (the 3 generate-intent output-clause files + the 4 greenfield entry-point skills: orchestrate-flow, extract-intelligence, scan-codebase, install-deps).

### Changed
- **`using-mega-sdd` anchor (`SKILL.md`, 2.4.0 → 2.5.0):** new terse `## Output language` block **above** the `ANCHOR-CORE` marker, so it re-injects on every session start + compaction (~82 tok on the hot path; the census stays on-demand).
- **L2 control seam — the 3 chat-output clauses flipped** from "adapt to the user's language" to the new default: `generate-intent/SKILL.md` (2.7.2 → 2.8.0) + its `references/{from-prompt-mode,vault-contract}.md`. "Reasons in English" and "generated docs match the input language" are unchanged.
- **Greenfield entry-point directives added** to the four skills that can be the *first* mega-sdd skill in a repo with no `.mega-sdd/` signal (no anchor → must carry the policy themselves): `orchestrate-flow/SKILL.md` (2.11.2 → 2.12.0), `extract-intelligence/SKILL.md` (1.11.2 → 1.12.0), `scan-codebase/SKILL.md` (2.15.1 → 2.16.0), `install-deps/SKILL.md` (1.3.3 → 1.4.0). `scan-codebase` + `install-deps` were caught in adversarial review — `scan-codebase` *creates* `codebase-map.md`, so on direct invocation (`scan codebase ini`, `init mega-sdd`) it runs anchorless, and `install-deps` (`pasang tools`) is the same anchorless class.
- **Census hardened (review finding):** the Tier-1 do-not-translate list now also covers **model-authored** enums that read like prose but are validator-pinned — extraction scorecard `COVERED|PARTIAL|MISSING` + `overall_status`, handoff `status`, and the lowercase bolt verdicts `pass|passed|ok`. The "script-emitted stays English" carve-out does not protect these (the model writes them), and the scorecard is authored by `extract-intelligence` — the skill this feature tells to narrate in Indonesian.
- **Deliberately NOT changed:** the bound-session artifact-content clauses (`bind-codebase`, `generate-units`, `execute-bolts`, `detect-drift`, `resolve-oq`, `diff-vault`) — "recorded in the vault's existing language" is the correct Tier-3 behavior, and these run only after a vault exists (anchor present). Adding pointers there would spend hot-path tokens for no gain.

### Safety
- Over-translating an enum **fails closed, loudly** — verified read-only that the artifact validators assert the English literals (`validate-unit-spec.sh:169` `task_type in ("verify","extend")`; `validate-conflict-classification.sh` `CONFLICT-N`/`C-NNN`; `validate-kb-markers.sh` `[VERIFIED]`/`[INFERRED]`). The validators are the real Tier-1 backstop; the only un-gated surface is Tier-2 chat, where a mistranslation is cosmetic. No CI-hard `.sh` pin asserts a localizable string (all assert Tier-1 tokens or script-emitted output, which stay English).

`plugin` == `marketplace` 4.51.0.

## [4.50.0] - 2026-06-29

Fix — SubagentStop hook never fired (candidate fix, pending live restart verification). Root-cause investigation of why the `SubagentStop` telemetry hook (the per-subagent token-cost capture that the fork-token measurement depends on, and that the bolt phase needs to escape its telemetry blind spot) had **never** emitted a single `subagent_end_marker` on any machine.

### Diagnosis (systematic, evidence-led)
- **The body and dispatcher are sound.** `run-hook.sh` routes `subagent-stop` correctly; the hook body reads the subagent transcript and sums per-turn usage; `tests/token-cost/test-subagent-stop-telemetry.sh` (which invokes the body directly) is green. So the gap is **upstream of the body** — the hook was never invoked.
- **Correlation isolates the matcher.** Every hook that *does* fire uses `matcher: ""` (`Stop`, 238× this session) or exact alternation tokens (`SessionStart` `startup|resume|…`, 47×; Pre/PostToolUse). The **only** hook configured with a regex wildcard `matcher: ".*"` was `SubagentStop` — the **only** one that was dark (0×). The plausible mechanism: the matcher for these events is treated as an exact/alternation token, not a full regex, so `".*"` only matches an agent type *literally* equal to `.*` → never matches → the hook entry never registers → `run-hook.sh subagent-stop` is never invoked → the body never runs (exactly the earlier "unconditional probe never wrote a line" finding).

### Fixed
- **`hooks/hooks.json`: `SubagentStop` matcher `".*"` → `""`** — mirrors the working `Stop` sibling (which the hook's own header comment pairs it with) and the repo's matcher convention. One-line, config-only; full suite 81/81 + pack gates green; no test pins the matcher value, so nothing regresses.

> **Verification is pending a restart.** `hooks.json` is snapshotted at session start, so this fix cannot be confirmed in the session that made it. After updating, restart, dispatch any subagent (e.g. a small `execute-bolts`), then `grep -c '"hook":"subagent-stop"' .mega-sdd/memory/hook-debug.log` — `> 0` confirms the fix. If it fires but `subagent_end_marker` stays 0, the secondary suspect is the payload field name (the hook reads `agent_transcript_path`; confirm against the real delivered payload — do not guess). Until the live grep is `> 0`, the fork-token measurement (task #18) stays blocked.



Audit batch A — correctness (C1–C7), closeout. A skeptical per-finding re-verification against **current** source (not the audit's snapshot) found **C1–C6 already remediated** by prior commits `28d497e` (v4.45.0 "reconcile prose-that-lies", which also shipped the audit doc itself + Batch B's PreToolUse hook fast-path + Batch C's dead-scaffold deletion) and `f547a54` (v4.46.0 "extract destructive core"). No fabricated rework — those findings get **no new edit**. The audit's **C7 was mischaracterized** (it claimed off-by-one numeric "Step N" mockup labels; the mockups carry no numeric labels, and the second cited location already matched its header). The one real residual:

### Fixed
- **`install-deps/SKILL.md` Step-4 mockup gerund.** The Step-4 ("Propose + confirm") chat mockup opened with `Building install plan…` — a verb that belongs to the preceding silent Step-3 ("Build install plan"). Relabeled to `Proposing install plan…` so the displayed action matches the step the user is in. Pure cosmetic chat-output wording; no behavior, no moat, no pinned test touched. `install-deps` 1.3.2 → 1.3.3.

### Audit status (2026-06-27 architecture audit — full closeout)
- **Batch A (C1–C7):** C1–C6 already shipped (v4.45.0/v4.46.0); C7 cosmetic relabel here. **Done.**
- **Batch B (F1 hook fast-path):** shipped in `28d497e` v4.45.0 (`hooks/pre-tool-use` negative-only short-circuit + `tests/round3/test-pretooluse-shortcircuit.sh`). **Done.**
- **Batch C (dead-scaffold cut):** shipped in `28d497e` v4.45.0 (deleted `references/3-tier-context-model.md` + `references/skill-tier-manifest.yaml`). **Done.**
- **Batch D (heavy-skill token dedup):** v4.48.0. **Done.**
- **Batch E (command shadow-logic extraction):** v4.47.0. **Done.**

## [4.48.0] - 2026-06-28

Audit batch D — heavy-skill token dedup (per `research/2026-06-27-architecture-audit-and-breadth-census.md` §Batch D). Deterministic duplication that lived in two places — most damagingly in always-loaded SKILL.md bodies — collapsed to **one source + a one-level-deep pointer**, per the authoring standard (progressive disclosure; SKILL.md is the router). **Behavior-preserving relocations, not deletions**: every candidate was adversarially verified against source, the destination ref enriched to a superset *before* the body was trimmed (the `(pointer + dest) ⊇ old body` invariant), and every applied change re-reviewed against source for info-drop / dropped rail / dangling pointer. Net **−195 lines** across 16 files; full suite 81/81 green; per-skill versions bumped (execute-bolts 2.14.2, extract-intelligence 1.11.2, orchestrate-flow 2.11.2, memory 1.5.1, install-deps 1.3.2, emit-fsd 1.2.2, generate-intent 2.7.2, generate-units 2.9.2).

### Hot-path token wins (always-loaded body → on-demand ref)
- **`extract-intelligence/SKILL.md` 410 → 329 lines.** Seven body blocks relocated into already-cited refs (each enriched first so nothing dropped): the output directory tree + the `## Handoff emission` YAML (→ `knowledge-base-schema.md` / `orchestrate-flow/references/handoff-contract.md`, the latter enriched with the `emitted_at`/`blockers`/`scope`/`mutability` fields it lacked); the per-wave model-tier list, the glossary pre-parse + reference-offset-hints, and the Wave-5 six-output list (→ `wave-dispatch-templates.md`, enriched with the 80-120 KB glossary nuance + the items-2/4 anti-corruption/sprint detail); the real-world-validation stats (→ the design spec §13); and the `## Common mistakes` table (cut — every row recapped doctrine already in the same body). **Every anti-halu rail kept in body** (`:190` "a stage you cannot anchor is `[OPEN]`", `:285` "never up-rank a principle to COVERED").

### Drift-prevention wins (one source of truth — marginal runtime tokens)
- **`execute-bolts/references/bolt-dispatch-prompt.md` 478 → 372 lines.** The Tier-loading algorithm (budget dict + priority order + `dispatch_prompt_too_large` halt + truncation cascade) was a hand-synced restatement of `context-enrichment.md` (the file literally admitted "the figures … MUST match that source") — and had already **drifted** (a stale 8-level priority order vs the canonical 9-level with `reuse_slice`/`constitution_clauses`). Collapsed to a pointer; the canonical owner is now the only copy. Also **cut** the self-labeled `DEPRECATED v1.0 algorithm` + `## Backward compatibility` archaeology (the `## Anti-halu rails` + `## Logging` sections between/after the cuts were preserved).
- **Lighter merges:** `memory` review-flow → `learning-rules.md §3`; `install-deps` Windows `scoop→winget→choco` archaeology → `os-detection.md §Fallback chain` (the "never a bare skip" UX rail kept); `emit-fsd` mode-detect fence → `section-mapping.md §Mode determination` (enriched to the precise `<vault>/bolts/…/U-*/bolt-report.md` wording); `generate-intent` setup-flow `--auto` table → the canonical `auto-and-handoff.md §--auto` table (the Figma "do you have screenshots?" rail kept).

### Bug found while deduping
- **`generate-units/references/defensive-generation.md:379`** labelled `bind-codebase/references/binding-contract.md` a "five-state classification table"; it defines **six** states (IMPLEMENTED / NEW / UNKNOWN / PARTIAL_FIELDS_{MISSING,SURPLUS,BOTH}). Corrected to "six-state". (The audit had predicted this bug at `SKILL.md:153` + `task-typing.md:31`; adversarial verification found those already read "six-state" — the lone stale label was `:379`.)

### Audit findings refuted against source (god-reviewer integrity)
The adversarial verify pass **rejected 6 of 24 candidates** — the audit's source line-numbers had drifted and several "duplications" were not. Recording them so the batch doesn't overclaim:
- **The entire D3 `generate-units` cluster was NO-GO.** The six-state map / field-diff / §7.6 collision-prompt / binding-state table in `defensive-generation.md` are **not** duplicates of `bind-codebase` — they are generate-units *application logic* (task_type→Migration-notes mapping, the interactive worked example, a body-unique login example) wrapped around a thin shared core, and `task-typing.md` already routes *into* them (collapsing would dangle the route and create a reference loop). The audit also **inverted** the §7.6 keep/drop direction.
- **`bolt-dispatch-prompt.md` provenance-trailer / `bolt_self_report` / halt-list "merge" was NO-GO** — direction inverted (`execute-bolts/SKILL.md:91` makes `halts-and-handoff.md` the owner), the copies legitimately co-locate for two consumers (T1 verbatim subagent prompt vs postflight enforcement), and the "halt lists" are different taxonomies, not a dup.
- **Two `extract-intelligence` blocks were NO-GO** — the stacked-marker `[VERIFIED][LOCKED]` examples are body-unique moat-#4 mutability vocabulary, and the `## Path resolution` block is an extract-intelligence specialization (its `--out` precedence + KB legacy-detection are not owned by the generic `paths.md`).

### Deferred (verified-safe but held for care; tracked)
The `extract-intelligence` deep-disciplines P-def bullets and the staged-input section are genuine ref-owned dups, but each embeds anti-halu rails and needs prose-coherence surgery beyond a token batch; the `using-mega-sdd` below-anchor lane line (session-start anchor skill) and the `scan-codebase` announce-string (a same-length pointer = token wash) were skipped as not worth the touch; the narrow `defensive-generation.md:280-306` collapse was deferred with the rest of D3.

## [4.47.0] - 2026-06-28

Audit batch E — command shadow-logic extraction. Three diagnostic commands (`analyze-parallelism`, `replay`, `list-modules`) inlined deterministic computation — DAG math, bolt-state capture+diff, per-module rollup — as prose the model re-improvised on every run; `lint-units` re-narrated checks an existing hook-wired validator already performs. Per the doctrine *"deterministic logic belongs in `scripts/`"* + the reuse-over-new-surface rule, that logic now lives in **exactly one place** — a tested script per diagnostic (or, for the overlap, the existing validator) — and each command delegates via the `${CLAUDE_PLUGIN_ROOT}/scripts/… --cwd="$(pwd)"` idiom, keeping only its judgment/interactive prose. **Behavior-preserving**; the four command bodies shrink 208 / 167 / 99 / 192 → 60 / 96 / 56 / 87 lines. Full suite 81/81 (the three new fixture suites — `parallelism`, `replay`, `list-modules` — discovered and green).

### Extraction — DAG analysis (`scripts/analyze-parallelism.sh`, new)
- Depth / max width / topological waves / critical path / forks / joins / per-squad + per-module sub-DAGs / cross-edge counts / over-coupling **candidates** — read-only (`set -u`), parses unit frontmatter directly. **Kept standalone, deliberately NOT folded into the graph layer**: `graph.json` carries the unit DAG but not `target_files` (the over-coupling basis), is a v2 *seam* (not the spine), and reachability-BFS ≠ topological-layering — so a "reuse" version would re-read frontmatter anyway (not the shadow-logic anti-pattern). The command keeps the over-coupling + hand-off SUGGESTIONS (judgment); the script emits only the deterministic basis (zero `target_files` overlap / cross-module edge) — the heuristic "no symbol cross-reference" sub-signal is dropped (it was never computed). Fixture suite `tests/parallelism/`.

### Extraction — bolt replay (`scripts/replay.sh`, new)
- Capture a bolt-state snapshot → diff vs the latest prior → classify by the fixed severity table. **Moat invariant #5 (no fabrication) hardened**: snapshot fields are sourced ONLY from artifacts execute-bolts actually writes (`bolt-report.md` `status` + `target_hashes`, target-file **live** sha256, `postflight.json` `status` + rule verdicts); fields the old command illustrated but no artifact records (`test_exit_code`, `git_sha_*`, `lines_changed`) are captured-if-present and compared only when present on BOTH snapshots — never invented. The command prose was corrected to match reality: the false "JSON Lines append" rail (snapshots are **per-run timestamped files**), the severity table's aspirational `test_exit_code` marquee row, and the Step-6 hand-off (the always-written artifact is `<unit>-divergence.json`; the `.patch` is the optional `jd` enrichment). **Latent bug fixed** — prior-snapshot selection swept in the `<unit>-divergence.json` diff artifact (shared `<unit>-` glob), corrupting diffs across repeated runs; now excluded, pinned by new regression scenario F in `tests/replay/`.

### Extraction — module rollup (`scripts/list-modules.sh`, new)
- Per-module unit completion (from `bolt-outcomes.json`), DoD marked-count, `blocked_by` resolution, status label — read-only. DoD-done detection tolerates BOTH the canonical plain-string `dod:` item AND the post-`--mark-dod` `[x]` form (the original `^\s*\[[xX]\]` draft matched neither). The command keeps the positional `[vault-path]` (parity), the `--mark-dod` AskUserQuestion flow, and the DoD test-command **re-execution** (state-mutating + shell-out — neither belongs in the read-only script). YAML parsing reuses `build-graph.sh`'s PyYAML-preferred + hand-rolled fallback (with the `MEGA_SDD_FORCE_YAML_FALLBACK` test hook). New fixture suite `tests/list-modules/`.

### Reuse, not new surface — unit lint (`commands/lint-units.md`)
- The unit-spec integrity checks lint-units re-narrated (required frontmatter, Anchors/Migration sections, per-AC grounding, Hard-Rule grammar, starterkit citation) are already owned by the hook-wired `scripts/validate-unit-spec.sh`. The command now **calls it per unit** and folds the verdict in — the same validator the PostToolUse hook runs, so the two can never drift — and **keeps** its unique value-add (dependency/binding resolution, module/squad assignment, codebase-map anchor verification, binding-state↔task_type consistency, prose quality). Not collapsed to a dispatcher. Also fixed a pre-existing dangling reference: `markdownlint-cli2 --config plugins/mega-sdd/references/markdownlint-config.jsonc` pointed at a file that never existed (would error at runtime) → now relies on markdownlint-cli2's own config discovery. And documented an honest limitation surfaced by the cutover: the shared validator (like its PostToolUse hook) only matches canonical `.mega-sdd/vaults/` + `*-bound/` unit paths, so on a **legacy** `docs/mega-sdd/vaults/` vault the delegated Step-2 integrity sweep no-ops — the command now says so and suggests `/mega-sdd:migrate-paths`, instead of reporting a legacy vault as "0 integrity issues" when the checks never ran (the inline Step-3 cross-unit checks still run regardless).

## [4.46.0] - 2026-06-28

Audit batch C6 — `migrate-paths` destructive-core extraction. The `migrate-paths` command inlined ~160 lines of destructive bash (`git mv` / `mv` move loops, the per-vault `.mega-sdd/`→`.internal/` rename, and `sed -i` reference rewrites) as prose the model re-improvised on every run. Per the plugin doctrine *"deterministic logic belongs in `scripts/`"*, that core is now a single **vetted** `scripts/migrate-paths.sh`; the command keeps the interactive confirm gate + the dirty-tree HALT and delegates execution to the script via the `${CLAUDE_PLUGIN_ROOT}/scripts/…  --cwd="$(pwd)"` idiom. **Behavior-preserving** (same canonical-layout outcome) **and hardened** — the script self-guards so it is safe even under `--auto-confirm`. Full suite 81/81 (the new fixture suite included).

### Extraction + safety hardening (`scripts/migrate-paths.sh`, new)
- **Idempotency guard precedes the dirty-tree guard** — a completed `git mv` migration leaves the tree dirty (staged renames + new `config.yaml`/`migration-log.md`), so a clean re-run detects "no legacy paths" and exits 0 **before** the dirty guard can falsely fire (the empty legacy vault parent is `rmdir`-tidied + detection ignores an empty leftover).
- **Dirty-tree refusal** (exit 2 unless `--dry-run`) — the script-level backstop that makes `--auto-confirm` / direct invocation safe.
- **Target-exists conflict** (exit 1 under `--from=auto`; `--from=legacy` confirms intent) and a **config.yaml clobber-guard** (an existing user config is never overwritten), both ported from the command's halt-conditions.
- **`--dry-run`** routes every mutation through a `run()` wrapper that echoes instead of executing; `git mv` preserves history (staged `R old -> new`), plain `mv` fallback outside git; `.bak` backups cleaned on success.
- New fixture suite `tests/migrate-paths/test-migrate-paths.sh` — a multi-vault legacy git repo whose `vault.json` carries every rewritten path pattern, asserting all five behaviors (dry-run no-op, full migration with the rename marker, idempotent re-run, dirty-tree refusal, target-exists conflict).

## [4.45.0] - 2026-06-27

Architecture audit follow-through — the conceptual audit + adversarially-verified breadth census (`research/2026-06-27-architecture-audit-and-breadth-census.md`: 77 verified findings, 12 refuted) surfaced live defects, a hot-path latency lever, and dead scaffold. This release ships the three lowest-risk batches; each fix was re-read against source and the full suite (80/80) is green. The heavy-skill token dedup + command shadow-logic extraction (Batches D/E) and the `migrate-paths` script extraction (C6) remain staged.

### Correctness fixes (found in the census wash)
- **Propose-and-confirm 5→4 option menu** — `execute-bolts/references/propose-and-confirm-prompt.md` rendered a 5-option `AskUserQuestion` (`[4] Cancel chain` + `[5] Override halt`) while the platform caps options at 4. Cancel now rides the built-in "Other"/Esc escape; Override is `[4]`; the downstream "option 5" handler is renumbered to "option 4". New regression pin **P7b2** (`tests/platform/test-platform-pins.sh`) — the existing P7b only guarded `halts-and-handoff.md`, missing this template. `execute-bolts` 2.14.0 → 2.14.1.
- **emit-agents-md stale/divergent template** — the `SKILL.md` body inlined an authoritative-looking AGENTS.md template that was a *stale, less-complete* copy of `references/agents-md-schema.md` (missing the `## Constitution` flattening — moat invariant #4 — and the `framework`/`framework_pack_path`/`mutability_summary` header fields); an agent rendering from the body produced a divergent file. The body is now an explicitly **illustrative skeleton** that defers to the schema as the single authoritative render source. The hardcoded generation-marker version (three stale literals: `v1.2.4` / `v1.0.0` / `v1.0`) is replaced by a `{{generator_version}}` token filled from `plugin.json` with an omit-fallback (idempotent re-emission keys on the `generated_by: mega-sdd:emit-agents-md` substring, never the version). `emit-agents-md` 1.4.0 → 1.5.0.
- **Five→six-state label drift** — `generate-units` called its Implementation State Map "five-state" in `SKILL.md` + `task-typing.md` while the actual table (`defensive-generation.md`) has **six** states; corrected. `generate-units` 2.9.0 → 2.9.1.
- **PARKED-status reconciliation** — `orchestrate-flow/references/chain-execution.md` instructed invoking `classify-iter.sh`, a script the project documents as never-wired (Fork-B-parked). The EP1/EP2 section now carries a **STATUS — PARKED** banner (no live-invoke claim; falls back to explicit `--iter-type`/`--plan`/`--act` flags); the script is preserved per its documented keep decision.
- **Broken in-file anchors** — 13 ToC anchors in `orchestrate-flow/references/predictive-checks.md` (9) and `handoff-contract.md` (3), plus `defensive-generation.md` (1), carried iter-archaeology suffixes (`-v3340-iter-50`, …) that no longer matched their clean `##` headers — the links were already dead. Suffixes stripped (fixes the links + removes archaeology). `orchestrate-flow` 2.11.0 → 2.11.1.
- **install-deps step labels** — chat progress mockups used a condensed "Step N" numbering that collided with and lagged the 8-step procedure headers; the colliding prefix is dropped from the progress lines. `install-deps` 1.3.0 → 1.3.1.

### Speed — PreToolUse fast negative short-circuit (hooks/pre-tool-use)
The blocking `PreToolUse` hook spawned `python3` to parse stdin **before** the `.mega-sdd` existence gate. Because the matcher is global (`Skill|Bash|Edit|Write`), every such tool call in **every** project — including non-mega-sdd repos that immediately no-op — paid a ~30–150ms python cold-start on the agent's critical path. A pure-shell negative short-circuit now exits 0 **before** the parse when there is no `.mega-sdd` ancestor. **Moat-neutral by construction:** it fires only when no `.mega-sdd` exists (mutually exclusive with the path that reaches the gates), uses the **same** sed-cwd extraction and the **same** `resolve_project_root` walk-up as the authoritative gate, and falls through untouched when the cwd can't be extracted or the resolver is absent. New pin `tests/round3/test-pretooluse-shortcircuit.sh` — **SC2** is the moat-breach guard (a cwd nested under a real `.mega-sdd` project must NOT short-circuit; the gate still fires). Existing moat-gate wiring confirmed intact.

### Dead-scaffold removal
Deleted `references/3-tier-context-model.md` (89 lines) + `references/skill-tier-manifest.yaml` (108 lines) — the Iter-64 lazy-loading scaffold whose enforcement was parked and never shipped; **zero live routes** (only each other), and the manifest was provably stale (pinned to plugin `3.44.0`, pointing at files that no longer exist). Carried no "preserve for Fork B" directive.

## [4.44.0] - 2026-06-27

Fork-measurement hardening — the live `detect-drift` `context: fork` token measurement was attempted in-session and **could not be completed faithfully here**, for two independent reasons (each forces the A/B onto a representative session on a real machine): (1) the no-fork baseline runs inline and inherits the measurement session's full context (~1M tokens), inflating the baseline; (2) `SubagentStop` did not fire for the harness `Agent`-tool dispatch — confirmed by an unconditional pre-bail probe in the hook that never ran, so a fork's entire cost (a `subagent_end_marker`) was uncapturable. The hook code is correct (pinned by `tests/token-cost/test-subagent-stop-telemetry.sh`); the gap is upstream event delivery. The decision to extend `context: fork` to `scan-codebase` / `bind-codebase` therefore **stays gated** on the live measurement — deciding it on the structural argument alone would override a written measurement gate with prose. This release turns the measurement kit's silent footgun into a hard, self-checking guard.

### `subagent_turns` capture signal (`report-token-cost.sh`)
The state JSON now carries `subagent_turns` — the count of `subagent_end_marker` events with usage. `0` means `SubagentStop` never captured subagent telemetry, so any fork-cost figure is invisible. Pinned by `tests/token-cost/test-token-cost-report.sh`.

### `--require-subagent` integrity guard (`measure-fork-tokens.sh`)
A real A/B must pass `--require-subagent`: the comparator **refuses a verdict** (exit 2, with remediation) when the **fork** snapshot has `subagent_turns == 0` — you can no longer read a WIN/NO-WIN off a run whose cost was never captured. Fails closed on legacy snapshots that predate the field. The no-fork baseline is exempt (it runs inline, so its `subagent_turns` may legitimately be 0). Contract `tests/fork-measurement/test-measure-fork-tokens.sh` (8 cases).

### Procedure precondition + diagnosis table
`research/2026-06-26-fork-token-measurement-procedure.md` gained a **SubagentStop precondition**: before trusting any A/B, read the hook-debug diagnostic count and the telemetry marker count *together* — a 3-case table distinguishes "never fired" (harness) from "fired but bailed" (a hook-side issue) from "healthy". Results log records the two blockers and the session-dependent magnitude (marginal → 50%+ at cache-read 0.1×), kept `_pending_` a representative-session run.

## [4.43.0] - 2026-06-26

Audit batch 4 — **token efficiency** (the "boros" follow-up). A measured sweep of what is *always-loaded* vs *per-run*, then three sharp cuts that do **not** dull the moat (the review-panel tiering, blind per-lens context, lean skill bodies, and trigger descriptions were measured and deliberately **kept** — they are already optimal). Audit + rationale: `research/2026-06-26-token-efficiency-audit.md`.

### Lean anchor injection (session-start diet)
`session-start` re-injects the `using-mega-sdd` anchor on **every session AND every compaction**. It now injects only the routing **core** (triggers + auto-trigger logic + the hard rule) — the pipeline diagram, phase-ownership table, multi-PRD lifecycle and red-flags moved below a `<!-- ANCHOR-CORE ends -->` marker and stay loadable on demand via the Skill tool. The YAML frontmatter (duplicated by the harness's own description load) is stripped. **~57% smaller per injection** (7839 → 3330 chars). **Fail-open:** an empty extraction (marker/frontmatter drift) falls back to the full skill, so a diet bug can never inject an empty anchor and break routing. Pin test `tests/anchor-diet/test-lean-anchor.sh` guards that every ID/EN + natural-language trigger and the hard rule survive in the core. `using-mega-sdd` 2.3.0 → 2.4.0.

### Deny-message diet (PreToolUse)
The 13 PreToolUse deny reasons were written for a human terminal; the model is the consumer. Trimmed the "why-it-matters" exposition from 10 of them, keeping the actionable fix recipe + state path + every `%s` placeholder (**~26% lighter per trip** across the trimmed set). The four phrases the wired tests assert (`flow-coverage`, `.batch-suite-gate-state.json`, `no passing postflight.json`, `grounding_confidence: HIGH`) are preserved.

### Fork token-measurement scaffold
The precondition for extending `context: fork` to `scan-codebase` / `bind-codebase` (CLAUDE.md + `moat-token-tradeoff` memory) is now runnable: comparator `scripts/measure-fork-tokens.sh` (A/B diff of two `report-token-cost.sh` snapshots — reuses existing telemetry, does not re-instrument) + procedure `research/2026-06-26-fork-token-measurement-procedure.md` + a results template. Contract test `tests/fork-measurement/test-measure-fork-tokens.sh`. The live run is on a real machine; until it lands, the extension stays in the backlog.

## [4.42.0] - 2026-06-26

Audit batch 3 — **correctness** (field-audit follow-up, the contained anti-hallucination fixes). Where batches 1–2 made cost visible and forked the diagnostic lane, this batch closes three enforcement gaps the field run exposed, each as a deterministic validator wired to a hook (never prose): **B2** a final full-suite gate so a cross-bolt or out-of-band regression can no longer ship green; **B1** the post-flight Hard-rule scan promoted from prose to an enforced evidence gate; **A1** per-acceptance-criterion source grounding so a `verify` unit can no longer be stamped HIGH over behavior that lives only in test stubs. Designs: `docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md` (B2+B1) · `docs/superpowers/specs/2026-06-26-per-ac-grounding-verify-units.md` (A1).

### Added — final full-suite gate at batch completion (B2; execute-bolts `v2.14.0`, orchestrate-flow `v2.11.0`)

- Every bolt's acceptance command is **scoped** to its unit and nothing re-runs the whole project suite — so a later bolt, or an out-of-band edit that bypassed the bolt flow, could silently break an earlier bolt's contract and the batch still reported `completed` (the field pipeline shipped a RED suite this way). `execute-bolts` now runs the project's **FULL** suite (runner from pre-flight 3.5, no per-unit scope filter) once after the last code-bearing bolt and writes `<vault>/bolts/_batch-suite.json`; RED → **halt `batch_suite_red`**.
- **Enforcement is a gate, not prose:** `scripts/validate-bolt-artifacts.sh --batch-suite-gate` (new 4th mode) checks that a green `_batch-suite.json` covers the newest code-bearing bolt commit (`git merge-base --is-ancestor` — a non-bolt commit never trips it, a bolt landing after the last gate does). The Stop hook writes the state each turn end; the PreToolUse execute-bolts aggregator **blocks the next run** on `batch_suite_gate_missing` (missing/stale) or `batch_suite_red`. The hook verifies the artifact; it never runs the suite (200s+ suites in a hook would cripple every turn).
- **Out-of-band bypass guard:** commits in the batch window (base SHA → HEAD, excluding this run's bolt commits) that touch a unit's `target_files` without an `SDD-PROVENANCE` trailer are recorded in `_batch-suite.json.bypass_commits[]` and force the suite to run. Bounded to the window so it never flags pre-SDD history.
- **Sync lane re-run:** `orchestrate-flow --sync` re-runs the full suite at HEAD after reconciling any code change and writes `_batch-suite.json` (`source: sync`) — the catch for the *post*-batch out-of-band edit the within-batch gate has already passed. SYNC-REPORT.md consumes the artifact; it does not re-run the suite.
- `--no-full-suite` DISCOURAGED escape hatch (broken/absent test command) — logged in `_summary.md` + handoff `notes.full_suite_skipped: true`; the next-run gate still applies. Never silent.

### Tests (B2)

- `tests/batch-suite-gate/test-batch-suite-gate.sh` — **behavioral** (exercises the validator, not prose): missing gate → `batch_suite_gate_missing`; red gate → `batch_suite_red`; green@HEAD → PASS; a non-bolt commit after a green gate stays PASS (not over-aggressive); a new bolt after a green gate → stale FAIL; no bolt commits → PASS; non-git dir → no-op.
- `tests/batch-suite-gate/test-gate-wired.sh` — pins the Stop-hook scan + PreToolUse aggregator wiring + validator arg + shell syntax of every edited surface.

### Added — post-flight Hard-rule evidence gate (B1; execute-bolts `v2.14.0`)

- The post-flight Hard-rule scan was **prose-only** — a committed `extend` bolt with non-empty `## Hard rules` shipped with no `postflight.json` and nothing caught it (the Stop hook checked bolt-report presence, never the post-flight evidence). Now `scripts/validate-bolt-artifacts.sh --postflight-scan` (new 5th mode) requires a committed `create`/`extend`/`modify` Hard-rule bolt to carry `<vault>/bolts/U-XXX/postflight.json` with `status: pass` + every `rules[].verdict: pass`; missing or non-passing → **`postflight_evidence_missing`**. Verify units are exempt (they skip post-flight).
- Same enforcement pattern as orphan-scan/batch-suite: Stop hook writes `.bolt-postflight-state.json` each turn end; the PreToolUse execute-bolts aggregator blocks the next run on FAIL. The `postflight.json` schema (previously prose-only) is now formalized in `execute-bolts/references/hard-rule-scan.md`.
- Tests: `tests/postflight-evidence/test-postflight-scan.sh` (behavioral — missing/violated/verify-exempt/empty-rules-exempt) + `test-postflight-wired.sh` (wiring).

### Added — per-acceptance-criterion source grounding for verify units (A1; generate-units `v2.9.0`)

- `grounding_confidence: HIGH` proved only that anchors *exist* (file + line valid), never that each acceptance criterion's *behavior* exists. A `task_type: verify` unit (the bolt skips code, runs only the acceptance tests) was stamped HIGH while several LOCKED criteria lived **only in test stubs / the PRD** — a green verify over **unbuilt** behavior. The defect is *partial* grounding, so an "are all anchors test files?" check structurally misses it (the field unit cited one real source anchor plus N ungrounded criteria). The unit of measurement is the **criterion**, not the anchor-set. Design: `docs/superpowers/specs/2026-06-26-per-ac-grounding-verify-units.md`.
- **Schema:** a verify unit's `## Acceptance criteria` may mark each criterion `- [grounded: <non-test path>:<line>] …` (behavior exists in source) or `- [ungrounded] …`. A test-file path is not grounding. Once any criterion is marked the unit opts in and every criterion must be `[grounded: …]`.
- **Enforcement is a gate, not prose:** `scripts/validate-unit-spec.sh` (PostToolUse on unit writes → `.unit-spec-state.json`) gains check 1b — a `verify` + `HIGH` opted-in unit with any `[ungrounded]`, test-path, or non-resolving criterion → **halt `verify_grounding_untrusted`**; the PreToolUse aggregator blocks the next `execute-bolts` (alongside `render_test_missing`). Remedy: ground each criterion, downgrade `grounding_confidence`, or split verify[built]+create[unbuilt]. **Block-on-HIGH only** (MEDIUM/LOW verify units are honest, not blocked); **legacy-tolerant** (units with no markers keep the old symbol-existence semantics, never retro-blocked).
- Tests: `tests/verify-grounding/test-verify-grounding.sh` — the discriminator is the **partial-grounding** case (one grounded + one ungrounded criterion → MUST flag), plus all-grounded→clean, test-only-anchor→flag, legacy→clean, MEDIUM→clean, non-resolving/out-of-range→flag. Wiring: `test-verify-grounding-wired.sh`.
- **Deferred (tracked, not dropped):** the post-bolt `it.todo()`/pending-test scan — the *test-time* backstop to this *unit-spec-time* gate (it empirically caught the field incident via 66 todo stubs). Lives in the audit backlog.

### Hardening — adversarial self-review of the B2/B1/A1 gates (before ship)

A 6-lens adversarial review of the three gates (each finding independently verified) surfaced **13 real defects in the gates' own implementation**, all fixed here — the gates now close their own incidents:
- **B1 critical — gate went inert on the canonical heading.** `has_hard_rules()` matched only the exact `## Hard rules`; the unit template emits `## Hard rules  (validated at bolt time …)` and units may use `## Hard Rules`, so a template-conformant Hard-rule bolt slipped through with no `postflight.json`. Now case-insensitive + tolerates trailing heading text. **B1 vacuous evidence** — an empty `{}` or empty `rules[]` no longer passes (positive evidence required). **B1 over-flag** — a wider curated "no rules" exempt set.
- **A1 fail-open → fail-closed.** A `verify`+HIGH unit with criteria as prose, under a drifted heading (`## Acceptance criteria:`, `### Acceptance tests`), or with no recognised heading at all used to pass CLEAN — the exact field-incident shape. Adoption is now detected body-wide; the heading match tolerates h2–h4 / synonyms / trailing colon; prose criteria are checked; an adopting unit with no parseable section fails closed. **A1 false-positive** — sub-bullets are detail of their parent criterion, not separate criteria. **A1** — PascalCase test classes (`UserTest.php`, `FooSpec.rb`) now classified as test paths.
- **B2 out-of-band half closed.** The freshness anchor tracked only `(bolt):` commits, so an out-of-band code commit (hotfix / manual edit / `git pull`) after a green suite still "covered" the older bolt and shipped green. The anchor is now the newest commit touching a code file (excluding pure-docs), regardless of subject.
- **Enforcement now behaviorally pinned.** The `*-wired` tests were grep-only; `test-moat-gates-wired.sh` now drives the PreToolUse hook with a FAIL state for all three gates and asserts it actually returns `deny` (this caught — and the fix verified — that postflight/verify-grounding genuinely block, not just appear wired). Spec §Enforcement reworded to match the commit-keyed validator; `plugins/mega-sdd/CLAUDE.md` "what is actually enforced" now lists all three gates.

## [4.41.0] - 2026-06-26

Token batch 2 — the first **structural** reduction: a `context: fork` pilot on detect-drift, plus the resolve-oq OQ-pass collapse. Forking is the contract's own re-evaluation trigger (`CLAUDE.md:69`); detect-drift is the one clean candidate (side-lane, non-moat). **Pilot status:** the deterministic fork-safety contract is pinned by tests; the live fork-firing + measured token reduction is validated on a real run. Decision record: `research/2026-06-26-context-reset-fork-feasibility.md`.

### Changed — detect-drift is a forked, non-interactive diagnostic (fork pilot, v3.0.0)

- Added `context: fork` frontmatter: detect-drift's body runs as a forked subagent (fresh context, no history), so a sync/drift scan no longer accumulates into the main-thread standing context (the field audit's token driver: 16.5K→325K × cache_read each turn).
- `context: fork` is unconditional, so detect-drift is now **non-interactive on every path** — it NEVER calls `AskUserQuestion`. Step 0 resolves inputs deterministically from `$ARGUMENTS`/CWD (unresolvable → new `drift_inputs_missing` blocker, never a prompt); Step 1.5 uses the detected framework (no confirm); Step 5 ALWAYS queues direction calls to `PENDING-SYNC.md`; Step 5.5 write-back is `--auto-apply=safe`-only.
- drift-history persists via a direct on-disk Bash append even when forked (a fork's `metadata.memory_writes` would land in invisible subagent chat and be lost).
- Blast radius verified: execute-bolts' per-bolt `bolt_introduces_locked_drift` gate is INLINE controller logic (not a detect-drift Skill invocation), so the fork leaves it untouched.
- **BREAKING (skill behavior):** standalone `/mega-sdd:detect-drift` no longer offers the interactive walkthrough / `DRIFT-ACTIONS.md` — it detects + reports + queues; resolution moves to `resolve-oq` / `sync`.

### Changed — resolve-oq OQ-pass collapse (S2, v2.2.0)

- Step 0.6 now recommends `all-priorities` (one ordered P1→P2→P3 walk) instead of `p1-only`, so the vault is read ONCE rather than re-entered for a separate P2 pass (the field audit's "Land OQ" + "Land P2 OQ" two-pass). P1 stays interactive — the collapse only saves the second vault read, never auto-resolves (no-fabrication rail intact). Both phase-advisor passes untouched (different axis).

### Contract / docs

- `plugins/mega-sdd/CLAUDE.md` capability-adoption ledger updated: `context: fork` is no longer "PILOT-GATED, not yet applied" — it records detect-drift as the **live pilot (v3.0.0)** with the non-interactivity constraint (no `AskUserQuestion`, no handoff-`metadata.memory_context` dependence), notes PreToolUse gates are preserved under fork (Skill call gated BEFORE the body forks) and that this is NOT Agent-tool offload (which bypasses the gates), and keeps the other chain skills as non-candidates. This keeps the contract from contradicting the shipped code.
- Behavior-faithful in-environment validation of the forked detect-drift (happy path + unresolvable-`--code` blocker) recorded in `research/2026-06-26-context-reset-fork-feasibility.md` — both graded on-disk; the live fork-firing + before/after token delta still validated on a real pipeline run.

### Tests

- `tests/drift/test-detect-drift-fork.sh` (10 assertions — context:fork, non-interactivity, drift_inputs_missing, drift-history disk-persist, deprecations).
- `tests/oq/test-oq-collapse.sh` (4 assertions — all-priorities recommended, no-fabrication preserved, p1-only retained, version bumped).
- `tests/roadmap/test-roadmap-pins.sh` pin updated: the `context: fork` capability decision in CLAUDE.md flipped from "PILOT-GATED" to "PILOT LIVE on detect-drift", so the pin grep was moved in lockstep (the decision is still recorded — the test's intent — just no longer gated).
- Full executable suite (71 suites, CI-faithful glob minus the 3 quarantined pack suites): **71/71 green** after the pin update (the contract flip was the one expected failure on the first complete run).

## [4.40.0] - 2026-06-26

Token batch 1 — observability & honest cost (field-audit follow-up). Raw token counts overstate real cost ~5–8× because cache_read bills ~0.1× (a full-pipeline field audit measured 176M raw ≈ ~37M cost-equivalent), and the entire bolt phase was invisible to telemetry (SubagentStop never fires the Stop hook). This batch makes spend **visible and price-faithful** — the measurement foundation for the structural token-reduction work that follows. No gate touched; report-only. Decision record: `research/2026-06-26-context-reset-fork-feasibility.md`.

### Added — cost-weighted token reporting (S4)

- New `scripts/report-token-cost.sh`: rolls up `telemetry.jsonl` `turn_end_marker` + `subagent_end_marker` usage into a **cost-weighted** total (input ×1, cache_creation ×1.25, cache_read ×0.1, output ×5 — Opus price ratios) with the raw/cost overstatement ratio and per-skill attribution. Writes `TOKEN-COST-REPORT.md` + `.token-cost-state.json`. Report-only; exit 0 always (a report can never block a chain).
- `/mega-sdd:analyze` (`run-analyze.sh`) now runs it and appends a **Token Cost (cost-weighted)** section to `CONSISTENCY-REPORT.md` — it can never flip the overall PASS/FAIL. `analyze` skill `v2.1.0`: adds token triggers ("token cost", "token usage", "berapa cost token") + guidance to present the cost-weighted number, not the raw count.
- **Attribution fix:** `turn_end_marker` carries a hardcoded emitter `"skill":"orchestrate-flow"`; cost is now attributed via the `skill_invoked` bracket (`payload.skill_full_name`), not the emitter field, so it lands on the real phase (a `subagent_end_marker` keeps its own agent identity).

### Added — subagent telemetry capture (S3)

- New `SubagentStop` hook (`hooks/subagent-stop`, registered in `hooks.json` with matcher `.*`): on subagent finish, reads the subagent's OWN transcript (stdin `agent_transcript_path`) and emits a `subagent_end_marker` with usage **summed across the subagent's turns**. SubagentStop fires once at the end, but the last message's usage is only the FINAL turn's context size (empirically ~7× under the cumulative cost), so every turn's usage is summed. Closes the field-audit blind spot where the bolt phase (bolt-implementer + the blind review panel) emitted ZERO telemetry.
- Observe-only (exit 0 — never blocks a subagent from stopping); mirrors the Stop hook's opt-out (`config.yaml telemetry:false`) + project-root resolution + telemetry-exists gate. No double-count — subagent turns live in a nested transcript disjoint from the main-session transcript the Stop hook reads.

### Tests

- `tests/token-cost/test-token-cost-report.sh` (13 assertions — cost-weighted math, per-skill bracketing, emitter-field regression guard, no-telemetry graceful path).
- `tests/token-cost/test-subagent-stop-telemetry.sh` (10 assertions — summed-not-last usage, agent_type attribution, telemetry-exists gate, observe-only exit, report-token-cost integration).

## [4.39.0] - 2026-06-26

Round-3 systematic gap audit — fixes for all 14 confirmed findings (0 S1, 7 S2, 7 S3). The plugin was structurally healthy (no moat bypass, no broken primary path); these close enforcement-vs-doc divergences, add regression pins to gates that worked but were untested, and broaden CI to the suites that pin them. Spec amendment: `docs/superpowers/specs/2026-06-25-factory-line-queryable-checkpoints-design.md` §11.

### Added — Factory Line backward-dispatch enforcement gate (R3-1, the one true enforcement gap)

- New PreToolUse gate (`hooks/pre-tool-use`, Branch 0-pre) on the upstream phase skills `extract-intelligence / generate-intent / scan-codebase / bind-codebase / generate-units`. When the factory ledger shows a phase in `phase_stuck` (cap breach) or `anti_spin`, re-dispatching **that** phase is blocked — closing the *backward* side of the "never loop forever" guarantee (the forward `execute-bolts` side was already enforced; the backward side was prose-only, contradicting `factory-routing.md`'s own claim).
- **Recompute-don't-trust-stale-state:** the gate runs `validate-factory-ledger.sh` fresh, then reads the derived state — so resetting the rebuildable `factory-ledger.json` self-clears the gate (no deadlock). **Per-phase precision:** a sibling phase (e.g. a re-`scan` to fix a stuck `bind`) stays allowed.
- **Recovery (documented behavior change):** a `phase_stuck`/`anti_spin` halt is cleared by resolving the underlying blocker, then RESETTING the rebuildable ledger (`rm .mega-sdd/factory-ledger.json` — it rebuilds from phase handoffs, clearing the stale attempt history) before `--resume`. The gate is breach-scoped, not a permanent ban — it releases once the phase's latest attempt is `completed`. Documented in the deny message, `factory-routing.md` §Termination, and spec §11.
- Tests: `tests/round3/test-factory-backward-gate.sh` (8 cases incl. recovery self-clear + before-preflight ordering).

### Fixed — enforcement / consistency

- **R3-11** — `run-analyze.sh` aggregate-only mode now mirrors FULL mode's discovery-gated SKIP (unit-spec, bolt-artifacts, fsd-slots, KB validators): a STALE `FAIL` left by a prior chain whose source files are gone is no longer reported as a live FAIL. The two modes now produce the same overall verdict on the same tree. Report-only path — the moat reads `.validation-blockers.json` directly, so this cannot weaken any gate. Test: `tests/round3/test-analyze-aggregate-parity.sh`.
- **R3-12** — `validate-fsd-slots.sh` no longer false-FAILs the plugin's own authoring files: the path filter dropped the over-broad `*fsd*.md` arm (which matched `emit-fsd/SKILL.md`) for `*FSD.md|*/fsd/*.md`, and now honors the code-fence exclusion its comment long promised. Test: `tests/round3/test-fsd-slots-glob.sh`.
- **R3-2** — dead recovery routes to the non-existent `/mega-sdd:act` / `/mega-sdd:plan` commands replaced with the working `--act` / `--plan` flag form (`/mega-sdd:auto --act`) at all four live sites (the PreToolUse guard recovery string, `commands/auto.md`, `orchestrate-flow/references/chain-execution.md`).

### Added — regression pins for gates that worked but were untested

- **R3-3 / R3-4 / R3-14** — `tests/round3/test-moat-gates-wired.sh`: static wiring pins for scope-flag, the 5 kept code-delivery gates (flow-coverage, render-test, sibling-consistency, ui-quality, cross-cutting), factory-ledger + preflight, and the anti-self-bypass protected-file list; plus behavioral deny/allow tests (a code-delivery gate FAIL blocks `execute-bolts`; `rm` of a protected guard state file is blocked while a benign `rm` is allowed).
- **R3-13** — CI now runs BOTH suite trees (`plugins/mega-sdd/tests/` and repo-root `tests/`) and both naming conventions (`test-*.sh`, `*.test.sh`) — ~50 enforcement-pinning suites were previously never run. Two genuine reds fixed: `aspnetcore.md` Security idioms gained the missing **SQL injection** + **Secrets** class bullets; the compaction advisor test's over-threshold fixture was re-calibrated for `claude-fable-5`'s 1M context window (a stale fixture, not a hook bug). Three redundant pack suites are quarantined (already covered by the dedicated `validate-pack.sh` CI steps).

### Fixed — documentation / contract drift (S3)

- **R3-5** — both READMEs corrected to 8 subagents (naming the review panel), 17 skills, 27 commands.
- **R3-6** — `plugins/mega-sdd/CLAUDE.md` enforced-hard-block list now names the Factory Line ledger gate in both directions (forward `execute-bolts` + backward re-dispatch).
- **R3-7** — `migrate-paths` dropped the unimplemented `--to=legacy` from its argument-hint (the reverse migration is explicitly marked not-yet-implemented).
- **R3-8 / R3-9** — non-canonical cross-skill / plugin-root refs fixed (`routing-rules.md` → `execute-bolts/references/squad-subagent.md`; `bind-codebase` + `emit-fsd` SKILL.md → `plugins/mega-sdd/references/paths.md`).
- **R3-10** — `execute-bolts/references/superpowers-bridge.md` (115 lines) gained the required `## Contents` ToC.

## [4.38.0] - 2026-06-25

### Fixed — pipeline skills now resolve `$PLUGIN_ROOT` to the LATEST cached version

- **Root cause:** Claude Code keeps every downloaded plugin version side-by-side under `~/.claude/plugins/cache/mega-sdd/mega-sdd/<version>/` and never garbage-collects them. `${CLAUDE_PLUGIN_ROOT}` is not substituted inside reference files nor exported to Bash, so skills derive a root from a path already in context — which, in a long session or a dispatched subagent, can point at a **stale** version dir whose files still exist (observed: a `generate-intent` subagent read `…/4.31.0/…/templates/04-flows.md` while the session was on 4.36.0). Silent stale read of templates AND bundled scripts.
- **`scripts/resolve-plugin-root.sh`** (new, deterministic): prints the highest-SemVer cached plugin root, with a fallback root for non-cache installs (manual / project-scoped / claude.ai / repo-dev). Portable numeric field sort (`sort -t. -k1,1n -k2,2n -k3,3n` — **not** `sort -V`, which macOS/BSD `sort` lacks); works on macOS, Linux, Git Bash.
- **All 7 pipeline path-resolution blocks** (across `scan-codebase`, `bind-codebase`, `extract-intelligence`, `generate-intent`, `execute-bolts`) now resolve `$PLUGIN_ROOT` via a **glob-anchored** invocation — keyed to the version-independent cache glob, never to the possibly-stale derived root — so a resolver from any cached version re-anchors to the true latest. Degrades to the derived root only when no cached resolver exists (never worse than before). Canonical rationale: `references/plugin-root-resolution.md`.
- **`session-start`** latest-version pick changed from a lexical `sorted(reverse=True)` (wrong for SemVer — `4.9.0` > `4.36.0` lexically) to a numeric SemVer key, matching the script.
- Tests: `tests/plugin-root/test-resolve-plugin-root.sh` (6 cases incl. the stale-anchor-defeat path). Skill patch bumps: scan-codebase 2.15.1, bind-codebase 2.5.2, extract-intelligence 1.11.1, generate-intent 2.7.1, execute-bolts 2.13.1.

## [4.37.0] - 2026-06-25

### Fixed — Windows hook dispatch (`'#!' is not recognized as an internal or external command`)

- **`run-hook.cmd` → `run-hook.sh`; `hooks.json` now invokes `bash "…/run-hook.sh" <name>`.** The dispatcher was a bash script wearing a `.cmd` extension: on macOS/Linux the shebang was honored, but on Windows cmd.exe ran the `.cmd` as a batch file and choked on line 1 (`#!/usr/bin/env bash`). Routing through `bash` means cmd.exe launches `bash.exe` (Git Bash) with the script as an *argument* — it never parses the file itself. **Consequence: the deterministic enforcement hooks (PreToolUse gate, journal, staleness) now actually run on Windows + Git Bash; previously the entire hook chain failed non-blocking there.**
- **Backslash-path hardening in the dispatcher:** `${CLAUDE_PLUGIN_ROOT}` can arrive with `\` separators on Windows; Git Bash's `dirname` only splits on `/`, which would collapse `SCRIPT_DIR` to the CWD and make every hook resolve as "not found". The dispatcher now normalizes `$0` (`${0//\\//}`) before resolving its directory.
- **Requires `bash` on PATH** (Git for Windows). WSL is not required and not assumed. Docs: `references/tooling-install.md` platform matrix updated.

## [4.36.0] - 2026-06-25

### Added — Factory Line: queryable checkpoint ledger + state-driven routing

- **`validate-factory-ledger.sh`** (new deterministic validator): ledger schema check (every `unresolved` must be anchored — `CONFLICT-N`/`OQ-N`/`file:line`), anti-spin retry cap (default 3 → `phase_stuck`), no-progress idempotency check (identical unresolved recurs → `anti_spin`), and convergence computation. Writes `.factory-ledger-state.json`.
- **State-driven router extension to `orchestrate-flow` (2.8.0 → 2.9.0):** reads the whole `.mega-sdd/factory-ledger.json` (derived, rebuildable) and routes forward OR backward to re-run an unresolved phase, looping to convergence or halting on the cap. New `--factory` flag (implied by `--deep`). References `factory-ledger-contract.md` + `factory-routing.md`.
- **Wiring (no new hook):** PostToolUse runs the validator on ledger write; the existing PreToolUse execute-bolts gate aggregator blocks on a ledger FAIL (a terminal backstop — the per-iteration loop is router-governed).
- **Vertical-only** — the blind reviewer panel is untouched. Fixtures + CI test under `tests/fixtures/factory-line/` + `plugins/mega-sdd/tests/factory-line/`.

## [4.35.0] - 2026-06-24

### Added — .NET framework-convention packs (gap audit #1 complete)

- **`dotnet.md`** (base, `extends: _universal`, `pack_tier: full`): general .NET / C# conventions for console apps, worker services, class libraries, and EF Core data layers — PascalCase methods, `I`-prefixed interfaces, `Async` suffix, `_camelCase` private fields, constructor DI, options pattern, `ILogger<T>`, nullable reference types. EF Core specifics are quarantined to the data-access section so a non-EF project still matches cleanly.
- **`aspnetcore.md`** (web, `extends: dotnet`, `pack_tier: full`): the web layer on top of `dotnet` — `[ApiController]` attribute routing / Minimal APIs, DTO boundaries, `ActionResult<T>`/`TypedResults`, the load-bearing `UseAuthentication` → `UseAuthorization` pipeline order, policy-based authz, Razor/Blazor UI detection, and `WebApplicationFactory` integration tests. Populated Deep-scan hints, Authz mapping, and UI detection.
- Both packs lint clean (`validate-pack.sh`), carry no cross-framework leak tokens, and are registered in `_registry.md`. **Closes gap #1** — a .NET repo now resolves to idiomatic .NET conventions instead of falling through to `_universal`.

### Fixed — CI was broken from birth (never green since 4.34.0)

- The 4.34.0 pack-validation CI step looped every pack through `validate-pack.sh` in **single (strict) mode**, which fails on the intentionally-incomplete untiered overlay `laravel-base-26.md` (it `extends: laravel` and omits 5 sections by design). CI exited 1 on its very first run. Switched the step to the script's documented tier-aware aggregate gate `validate-pack.sh --all` (full-tier packs still block on any violation; thin/untiered overlays block only on structural errors — invalid YAML / cross-framework leak).
- Added a `--check-registry` CI step so a stale `_registry.md` is caught in CI, not just by reviewers.

## [4.34.0] - 2026-06-24

### Added — CI + C# AST extraction (gap audit #2 + #1 cont.)

- **CI** (`.github/workflows/tests.yml`): runs every `tests/**/test-*.sh` (moat, graph, design-intelligence) and validates all framework-convention packs on push/PR to main. Closes gap #2 (no automated test runs).
- **C# AST query** (`scan-codebase/queries/tags-csharp.scm`): .NET repos now get AST-level symbol extraction (class/interface/struct/enum/record/method/constructor/**property**) instead of regex-only — properties captured as field definitions so .NET DTOs/entities get field-level binding. Upgrades gap #1 from "recognized" to "AST-extracted".
- Remaining for gap #1: a `.NET` framework-conventions pack (convention idioms) — deferred; `_universal` applies until then.

## [4.33.0] - 2026-06-24

### Added — .NET recognized by scanner (gap audit #1, partial)

- `scan-codebase` now detects .NET: `*.csproj`/`*.sln`/`*.fsproj` manifests, `dotnet test` (xunit/nunit/MSTest) test framework, and ASP.NET Core / EF Core framework fingerprints. A .NET repo is no longer invisible (was falling through to `_universal`). Regex-tier extraction; AST query (`tags-csharp.scm`) + a .NET framework-conventions pack remain (tracked in `research/2026-06-24-skills-gap-audit.md` #1).

## [4.32.0] - 2026-06-24

### Changed — router NL-routing for diagnostic/output skills (gap audit #3)

- `using-mega-sdd` now routes `analyze`, `graph`, `memory`, `emit-fsd`, `emit-agents-md`, `install-deps` on natural language (EN+ID triggers), not just explicit `/command`. Closes the 6-skill router-orphan gap surfaced by the 2026-06-24 skills gap audit (`research/2026-06-24-skills-gap-audit.md`).
- Added the gap audit itself as a durable artifact under `research/`.

## [4.31.0] - 2026-06-24

### Changed — anti-over-engineering discipline (ponytail-inspired), shift-left into the bolt panel

- `bolt-implementer` now climbs an explicit **build ladder** before writing (reuse → stdlib → native platform/framework → already-installed dep → minimum code) — over-engineering is avoided pre-write, not just caught in review (fewer reject loops). The ladder shortens the solution, never the reading.
- `code-quality-reviewer` over-engineering findings now carry a terse, actionable tag taxonomy (`delete:`/`stdlib:`/`native:`/`yagni:`/`shrink:`), one line per finding, with an optional `net: −N lines possible` on the Assessment. Severity grading and the panel contract are unchanged.
- No new agents, no per-pack duplication: mega-sdd already enforced reuse-first (Iron Rule #4) and YAGNI; this sharpens *when* (shift-left) and *how legibly* over-engineering is surfaced.

## [4.30.0] - 2026-06-24

### Added — derived graph layer (`mega-sdd:graph`)

- New project-scope derived graph `.mega-sdd/graph.json` over existing artifacts (vault.json, binding.json, units, modules.yaml, KB) — no code re-scan.
- New `/mega-sdd:graph --impact <id|file[:line]> [--upstream|--downstream]` blast-radius query, every edge citing its source artifact + field.
- `bind-codebase` now emits a structured `binding.json` sidecar (Step 4.5) guarded by `validate-binding-json.sh` parity gate.
- Freshness gate: lazy rebuild on source-glob path-set / hash change; binding-vs-HEAD staleness banner pointing to `/mega-sdd:sync`. Graph stays out of every chain; `sync` cache-warms it (non-blocking).
- Anti-hallucination preserved: no inferred edges; unresolved references become `[Pending]` nodes.

## [4.29.0] - 2026-06-15

### Added / Changed — extract-intelligence is now genuinely tech-agnostic (not PHP-tuned) + P6 dynamic-dispatch

extract-intelligence (EI) is the front gate for reverse-engineering legacy. Its reasoning *structure* was already stack-agnostic, but the agent-facing implementation carried PHP-only illustrative vocabulary and a PHP/SQL-only tech-leak gate — biasing extraction toward PHP idioms and silently missing C#/Java/Go/Rust cases, especially **dynamic** ones (DI, reflection, attribute-routing). This aligns EI with the long-standing plugin contract: *"the pipeline must work for ANY supported stack, not just PHP/JS."* Spec: `docs/superpowers/specs/2026-06-15-extract-intelligence-tech-agnostic.md`.

- **Concept-first disciplines + STACK IDIOM TABLE.** DEEP DISCIPLINES P1–P3 (`skills/extract-intelligence/references/wave-dispatch-templates.md`) rewritten stack-neutral, backed by a new per-stack idiom table (PHP / JS-TS / Python / C#-.NET / Java / Go / Ruby / Rust) so every wave subagent gets concrete anchors for whatever the legacy is written in. SKILL.md §Deep disciplines vocabulary kept in sync.
- **P6 — Dynamic dispatch & runtime wiring (new falsifiable principle).** Captures call sites resolved at runtime (DI-container resolution, reflection/`dynamic`, attribute/annotation/convention routing, interface → implementation dispatch, event/delegate/middleware wiring) — the inverse of P2 and the dominant silent-miss on DI/reflection-heavy stacks. New REPORT BACK fields `dynamic_seams_found/resolved/open` + self-check rail; unresolvable seam → `[OPEN]`, never an invented target.
- **Extraction Completeness Contract grows to six principles.** `P6_dynamic_dispatch` added to `scripts/validate-extraction-scorecard.sh` REQUIRED_PRINCIPLES, scorecard JSON (schema 1.1), and the SKILL.md §Step 5.6 derivation table. **Version-gated back-compat:** a scorecard from a pre-1.11.0 extractor (no P6) is NOT failed for missing P6 — it degrades to an advisory; P6 is required only from 1.11.0+.
- **Per-stack tech-leak gate — `scripts/kb-leak-scan.sh` (new).** Replaces the hardcoded `grep 'varchar\|int(11)\|MySQL\|MSSQL\|composer'` inline gate. Detects the legacy stack from `.scan-meta.json` (or `--stack=`), else applies the union of every stack's leak tokens; section-aware (skips `## 11.` bodies) and dir-aware (skips `50-integrations/`). Advisory by default (preserves the old non-blocking contract); `--strict` exits 1 on hits. Catches C#/Java/Go/Rust leaks the old grep let through.
- **Skill version:** `extract-intelligence` 1.10.0 → 1.11.0. No new runtime dependency; existing five-principle verdict logic and the scorecard SKIP-on-absent contract unchanged. scan-codebase/bind-codebase C# first-class support (tree-sitter grammar, `.csproj` detection, ASP.NET pack) is explicitly out of scope — a separate deterministic-engine effort.

## [4.28.1] - 2026-06-13

### Fixed — compaction advisor over-reported every 1M-context session ~5× (false `/compact` nag)

The phase-aware compaction advisor (`hooks/user-prompt-submit`, added 4.27.0 / relocated 4.27.1) detected the context window with `"[1m]" in model`. But `[1m]` is a Claude Code **display alias** — it never reaches the transcript's `message.model`, which records the wire id (`claude-opus-4-8`, `claude-fable-5`). So the window always fell back to the 200k default and every 1M-context session was scored ~5× too high — surfaced live in the clinic runtime test: a Fable-5 bolt session at a healthy 254k (25% of 1M) was reported as **127% of 200k**, triggering a `/compact` recommendation at ~16% of the real window → premature compaction, real context lost.

- **Window now resolved from three signals, biased to the larger window** (a false silence is harmless — PreCompact still snapshots; a false `/compact` nag burns real context): the `[1m]` marker if present; OR a current 1M-context model family (`claude-opus-4*` / `claude-sonnet-4*` / `claude-fable*`); OR an **empirical** override — a context that physically exceeded 200k proves a >200k window (a true 200k session would have auto-compacted first). The empirical signal is model-agnostic, so future 1M model ids need no allowlist edit.
- `<synthetic>` turns are skipped when capturing the model id (they carry no real model).
- Verified end-to-end: both real clinic transcripts (Opus @143k, Fable @254k) now stay silent; the 200k path still fires at 85% (`170k of 200k`); the 1M path fires at 85% (`850k of 1000k`); an unknown model with >200k observed context resolves to the 1M window. Single-site fix; no other hook does window detection.

## [4.28.0] - 2026-06-12

### Added — multi-PRD lifecycle: project index + shared constitution + explicit router

A project that grows PRD-by-PRD (PRD 1 ships, PRD 2 adds an epic; docs can be PRD/BRD/Figma/brief) had real multi-vault support but no first-class linking — ambiguous, and PRD 2 could silently contradict PRD 1. Spec `docs/superpowers/specs/2026-06-12-multi-prd-lifecycle-design.md`.

- **Project index** (`scripts/build-project-index.sh` → `.mega-sdd/project.md`): derived manifest of every vault (slug, title, source, version, status intent/units-ready/in-progress/shipped, unit+bolt counts, area). The vault sequence IS the PRD/epic history, so a new vault knows what PRD 1..N-1 shipped. Regenerated at chain end (wired into `run-analyze.sh`); pure-read, exit 0 always. (Surfaced a real case immediately: the test clinic already had a shipped vault + a started v2 vault.)
- **Project constitution** (`.mega-sdd/constitution.md`, inherited by every vault): `bind-codebase` reads it before binding a NEW vault — a claim contradicting a project-locked clause (e.g. PRD 2 proposing a different datastore than the project locks) is a CONFLICT at the binding gate, never silently accepted. Keeps PRD 2..N inline. Absent = unchanged.
- **Explicit lifecycle router** (`using-mega-sdd`, contract in `references/multi-prd-lifecycle.md`): a new doc routes by what changed — same source revised → `diff-vault`; new epic → new vault + brownfield bind; code moved → `sync`. Doc-type agnostic; **when unsure, ASK** (evolve-in-place vs new-epic diverge hard).
- `tests/multi-prd/` (index functional on a 2-vault fixture + empty/non-sdd safety + wiring pins). Advisory/navigational — the only enforcement is the project-constitution CONFLICT at the existing binding gate (reuses the moat, no new blocking surface).

## [4.27.1] - 2026-06-12

### Fixed — official-docs conformance audit (2 real gaps; `research/2026-06-12-official-docs-conformance-audit.md`)

Deep audit of every hook/agent surface against code.claude.com/docs (two parallel agents + direct WebFetch of contested claims). The moat surfaces were already conformant; two gaps from this sprint fixed:

- **Compaction advisor was invisible (4.27.0).** It printed to the **Stop** hook's stdout — but per docs, Stop stdout is debug-log-only (Stop is not one of the stdout→context events) and the hook is async, so the advisory reached no one. **Relocated to a new `UserPromptSubmit` hook**, where docs confirm *"stdout is added as context that Claude can see and act on."* Same threshold (80% of the window) and `compaction_notice:` opt-out; now actually surfaces so Claude can suggest `/compact` at a phase boundary.
- **`MultiEdit` matcher (4.25.0).** Not a current Claude Code tool name. Dropped from the PreToolUse matcher, GateGuard case label, and parse tuple — now `Edit|Write` (the documented file-mutating tools).
- Verified CONFORM (no change): SessionStart/UserPromptExpansion raw-stdout→context (sub-agent's "JSON-only" claim disproved by direct fetch + the live-session anchor injection), PreToolUse `permissionDecision: deny`, PreCompact side-effect-only, plugin-agent frontmatter (only hooks/mcpServers/permissionMode banned; none used).

## [4.27.0] - 2026-06-12

### Added — ECC-adoption Batch 2: phase-aware compaction advisor + PreCompact state snapshot

Long mega-sdd chains (the clinic sync ran 26 min) have two compaction failure modes — compacting mid-bolt loses the controller's whitelist/dispatch context, and harness auto-compaction loses which phase/unit was in flight. Adopted from ECC's strategic-compact + memory-persistence (spec `docs/superpowers/specs/2026-06-12-compaction-advisor-design.md`).

- **Compaction advisor** (Stop hook, advisory): sums the transcript's true context size (`input + cache_read + cache_creation`, reusing the existing usage extractor), window-scaled (200k, or 1M on the `[1m]` marker). Over 80% AND a mega-sdd chain active → one line: "context ~Nk of ~Wk — a phase boundary is the safe place to /compact." Silent under threshold / for non-mega-sdd projects. Opt-out `compaction_notice: false`.
- **PreCompact snapshot** (new `hooks/pre-compact` on the PreCompact event): before the harness compacts, writes `.mega-sdd/.compaction-snapshot.json` — HEAD, trigger, in-flight phase guess (newest vault: units total, bolts done, last bolt unit), open PENDING-SYNC count. Pure reads, exit 0 always (never blocks compaction). SessionStart then surfaces one "resumed after a compaction at phase [X] — N units, M bolts done" line so the next window re-orients instead of re-deriving. Shares the `telemetry: false` opt-out.
- Both are advisory context, not gates (compaction is the user's call; the snapshot is insurance). `tests/compaction/` — snapshot phase-guess + degenerate-vault-still-exits-0 + advisor over/under threshold + opt-out + resume line.

## [4.26.0] - 2026-06-12

### Fixed/Added — floor-vs-ceiling: live-app design judgment (UI was "basic", not "kuno")

Browser-verified field finding (clinic-project): the v4.24 design pipe shipped, the floor passed (tokens, page shell, states, WCAG), but the rendered UI was still generic — a lone centered card in whitespace, no branding/nav, no iconography, flat hierarchy. Root cause: 9 of `modern-baseline.md`'s 10 non-negotiables are binary floor checks provable from code; "distinctive, not generic" needs the RENDER and was the weakest-enforced.

- **`modern-baseline.md §Ceiling moves`**: a distinctiveness contract above the floor — page furniture (header/nav/footer, not a bare heading over a card), width-filling composition (two-column / hero / grid, not a lone 480px card on a 1280px page), iconography, layered hierarchy, a style signature, purposeful motion, product-fit density. Explicit framing: "the floor is NOT the goal." Injected into the implementer prompt (design slice) AND the design-lens rubric.
- **`design-reviewer` upgrade**: "floor met, ceiling absent" is an **Important** finding (generic/undesigned), not a pass; when rendered screenshots are provided it judges the actual render, with a hard rail never to imply a render it didn't see.
- **`scripts/capture-views.sh`** (live-app lens, ECC Batch 3 scoped to this gap): screenshots the unit's routes when a dev server is reachable (`preview_url` config / unit frontmatter / operator). **Stack-agnostic** — capture hits URLs so the app can be any stack (Laravel/Blade, Django, Rails, Spring, a Node/Next SPA); the screenshot driver tries a system Chrome/Chromium (zero Node — PHP/Python/Ruby/Go repos) then npx playwright. Every failure mode is a graceful SKIP; an un-captured render is never reported as fine. Config `preview_url:`.
- `tests/design-ceiling/` — baseline→slice→dispatch→lens wiring + capture-views graceful-skip + stack-agnostic-driver pins.

## [4.25.0] - 2026-06-12

### Added — ECC-adoption Batch 1: instincts (closed learning loop) + GateGuard (LOCKED investigation gate)

Adopted from the affaan-m/everything-claude-code review (spec `docs/superpowers/specs/2026-06-12-instincts-and-gateguard-design.md`); both mechanisms re-shaped to mega-sdd's doctrine.

- **Instincts** (`memory/references/instincts.md`): atomic trigger→action learnings with confidence 0.3–0.9 (birth 0.5, +0.1 reconfirm capped 0.9, −0.2 on user correction, −0.1 staleness, retire <0.3), mandatory evidence (no fabricated learnings), project scope with auto-promotion to global (same key from ≥2 projects at avg ≥0.8 via `_seen.jsonl` ledger). **The point: bounded re-injection** — SessionStart appends a `<learned-instincts>` block (top 6, conf ≥0.7, 1200-char budget, advisory-explicit); matching-domain instincts also ride the bolt T2 historical-memory slice. Emission owned by the existing chain-end learning pass (Step 7.6) — no mid-chain evaluation. Opt-out `instincts: false`.
- **GateGuard** (pre-tool-use `Edit|Write|MultiEdit` branch; matcher widened): the FIRST edit touching a file anchored to a **[LOCKED]** claim is denied with the exact investigation prescribed (read the claim + binding verdict, Grep the file's importers, name the covering acceptance test; behavior changes routed via sync/propose-and-confirm) — **the retry passes** (deny-once; session-scoped state, 30-min expiry, 500-entry cap). Converts the LOCKED rule into a pre-edit gate — today LOCKED violations are only caught post-hoc (bolt drift check / sync). Index (`scripts/build-locked-index.sh`) parses binding/vault docs for `[LOCKED]` anchors, lazily rebuilt by the hook; **no LOCKED markers (typical greenfield) → inert, zero false positives**. Opt-out `gateguard: false`; state file intentionally NOT bypass-protected (deleting it merely re-gates — fail-safe direction).
- `tests/instincts-gateguard/` — functional fixtures (deny→retry-allow→new-session-regates→opt-out→greenfield-inert; conf-0.8 injected / conf-0.5 + retired excluded / opt-out honored) + wiring pins.

### Fixed

- Platform pins back to ALL PASS: P6 exemption casing in `code-gates.md` ("is NOT substituted") and the long-standing P7d — plugin README now names the full activation chain (`/plugin marketplace update mega-sdd` + `/reload-plugins`).

## [4.24.0] - 2026-06-12

### Fixed/Added — UI/UX awareness: the greenfield design pipe + a design lens

Field finding (clinic-project, greenfield): generated UI was default-browser "kuno" DESPITE generate-intent having written a full `vault.json design_system` (medical-clinic profile from `design-intelligence/product-style-map.yaml`). Root cause: the ONLY injection path for design context lived inside the starterkit branch of `context-enrichment.md` — no starterkit-context.yaml (every greenfield) → UI bolts received zero design guidance.

- **Design slice (the pipe fix)**: built INDEPENDENTLY of starterkit for any UI-bearing unit (target_files match pack `view_glob` or universal frontend shapes). Greenfield: vault `design_system` + the matching `style-principles[style]` slice + ux-rules floor + the new modern-baseline digest. Starterkit template remains AUTHORITATIVE when present (unchanged precedence). New T2 dispatch-prompt section `## Design system (UI-bearing unit)` with palette/typography anti-halu rails ("never invent a second palette").
- **`design-intelligence/modern-baseline.md`** (new): the injectable modern-UI floor — 10 non-negotiables (token layer, 4/8px spacing, type scale, page shell, interactive states, loading/empty/error states, designed forms, WCAG AA, styled data tables, distinctive-not-generic) + the anti-kuno tells list. Distilled from the existing ui-ux-pro-max distillation + Anthropic frontend-design philosophy.
- **`design-reviewer` agent (new, sonnet)**: 5th review-panel lens — judges UI code against the SAME design slice the implementer received (one contract, two sides): token discipline, layout composition, states, a11y, style conformance. ADDITIVE join: any tier, only when the unit is UI-bearing — pure-backend bolts never pay for it.
- `tests/design-aware/` pins the pipe end-to-end (baseline digests → context-enrichment slice → dispatch section → lens wiring → model-tiers row 21).

## [4.23.1] - 2026-06-12

### Fixed — field-audit of a real intent→bolts run (clinic-project): 3 enforcement gaps closed

A full pipeline test run shipped 16 bolt commits with ZERO `<vault>/bolts/` artifacts, bound against a degenerate codebase-map, and left OQ/constitution propagation FAILs — none of it caught. Root causes + fixes:

- **Orphan-bolt-commit gate (the big one)**: the bolt-report obligation was prose (Procedure Step 0/5) + a Stop gate that only fires on `--auto` handoffs; a terse interactive controller skipped both, and the file-scoped artifact validator can't see a file that was never written. NEW: `validate-bolt-artifacts.sh --orphan-scan` — repo-wide deterministic check (bolt commit subject `(bolt): U-XXX` + unit exists + no `bolts/U-XXX/bolt-report.md` → FAIL `.bolt-orphans-state.json`). Runs unconditionally from the Stop hook every turn end + in `/mega-sdd:analyze` (`bolt_orphans` boundary); the PreToolUse execute-bolts aggregator **blocks the next run** until reports are backfilled or units re-run. False-positive safe: bounded history (200 commits), only flags units that still exist in a vault.
- **bind-codebase degenerate-map gate**: the run bound against a codebase-map.md missing ALL 7 content sections — false grounding for every downstream verdict (invariant #1). NEW PreToolUse gate blocks `bind-codebase` while the map validator attests the empty-shell shape (partial maps are NOT blocked); fix is re-running scan-codebase.
- **Retired-clause false positive**: constitution-propagation demanded unit citations for a clause the constitution itself marks `*(dropped …)*` (mentioned in binding only as supersession context). The validator now exempts dropped/retired/superseded clauses.
- `tests/bolt-orphans/` (functional fixture repo + wiring pins incl. `bash -n` on every edited hook/script). Field remediation applied to the test project: 16 retroactive bolt-reports backfilled (provenance from git, `retroactive: true`, no fabricated test results) + 5 dropped OQ-IDs and 4 constitution clauses attached to their owning units → binding-units PASS, constitution-propagation PASS, orphan-scan PASS.

## [4.23.0] - 2026-06-12

### Added — `## Security idioms` across all 22 framework packs (Phase 3)

Closes the review-panel trilogy (spec `docs/superpowers/specs/2026-06-12-review-panel-design.md`): every full-tier pack now carries a `## Security idioms` section — stack-correct, mechanism-named, with **the dangerous bypass spelled out next to each idiom** (e.g. Laravel `{!! !!}`, Django `mark_safe`, Rails `html_safe`, axum routes added after `.layer()`, Next.js `NEXT_PUBLIC_` client-bundle leak, Spring `csrf().disable()`).

- **Schema** (`_template.md`): 9 canonical classes per stack — input validation, SQLi, XSS/escaping, CSRF, authn/authz enforcement point, password hashing, mass assignment, secrets/config, file uploads (+ optional session posture). A class that genuinely doesn't apply gets an honest per-bullet opt-out, never silence. Mechanically-expressible idioms route through the existing `## Hard Rules emitted` machinery — no parallel rules channel.
- **Consumption**: the review-panel `security-reviewer` lens receives the section as its pack security slice; `bolt-implementer` receives it via T2 framework-pack rules — generated code is born with the stack's security idioms, not retrofitted.
- Authored via the plugin's own pattern: 3 parallel blind subagents (one per language family) against a canonical Laravel exemplar + the cross-framework token ban; verified independently by `tests/security-idioms/` (exactly-one section, ≥7 class bullets, key classes present, per-pack) + the pack lint + token-leak suites.

## [4.22.0] - 2026-06-12

### Added — L0 Code Gates: the deterministic floor under the review panel (Phase 2)

Deterministic-first, LLM-second (spec `docs/superpowers/specs/2026-06-12-review-panel-design.md` §Phase 2 addendum): machine checks run on every bolt diff between implementer DONE and the panel — an LLM lens never burns context on what a linter, scanner, or registry lookup decides for free.

- **Toolchain detection** (`scripts/detect-toolchain.sh`): finds the repo's OWN formatter/linter/typechecker from config evidence across 7 ecosystems — detect, NEVER impose (no config evidence → no command). Format failures auto-fix + re-check (machine territory, not findings). Optional pack `## Toolchain` override for project packs (`_template.md`).
- **Secret scan on the diff** (`scripts/scan-secrets-code.sh`): gitleaks preferred, plugin provider-shaped regex fallback when absent — secrets are ALWAYS scanned; values never echoed. Finding → halt `secret_in_code`, no override path exists.
- **SAST** (`scripts/run-code-scan.sh`): semgrep over changed files only; tool absence/failure = visible SKIP with reason, never fabricated "clean". ERROR severity → halt `sast_critical_finding`.
- **Anti-slopsquatting** (`scripts/validate-new-deps.sh`): every ADDED dependency (package.json/composer.json/pyproject/requirements/go.mod/Cargo.toml/Gemfile) verified to EXIST on its official registry; definite 404 → halt `dep_not_found` (hallucinated package — never install around it); offline → `unverified` warning.
- L0 results injected into every panel lens prompt (`## Deterministic scan results` — machine fact, blindness intact); SKIPs recorded in the bolt-report so an unscanned run is never mistaken for a clean scan.
- Opt-out per doctrine: `code_gates: false` config / `--no-code-gates` flag disable toolchain+SAST only; **secrets + dep-existence always run** (critical + un-promptable). install-deps matrix + tooling-install gain semgrep/gitleaks/osv-scanner. `tests/code-gates/` (functional fixtures: planted AWS key → exit 1 + value never echoed; hallucinated npm package → NOT_FOUND blocking; empty repo → no tools imposed). execute-bolts → 2.13.0.

## [4.21.0] - 2026-06-12

### Added — Review Panel: parallel blind reviewer lenses in execute-bolts (Phase 1)

Research-driven (`research/2026-06-12-review-panel-quality-security-standards.md`; spec `docs/superpowers/specs/2026-06-12-review-panel-design.md`): the serial two-stage review tail is now a **risk-tiered panel** of read-only lenses dispatched **in parallel and blind** (no lens sees the implementer's report or another lens's verdict — the measured anti-rubber-stamp rail), merged in the main-thread controller (depth-1 preserved).

- **New agents**: `security-reviewer` (opus — OWASP-keyed: input validation/injection, authz vs unit spec, secrets, hallucinated/unvetted new deps, fail-open error handling, architectural drift) and `standards-reviewer` (sonnet — convention conformance vs framework pack + surrounding code; forbidden from machine-fixable nits). Both read-only, evidence-or-drop (`file:line` mandatory).
- **`code-quality-reviewer` narrowed**: security moved to the security lens; priority shifted to the measured AI defects — duplication/failure-to-reuse (vs reuse-index), tautological tests, over-engineering; linter-covered findings out of lane.
- **Risk-tiered panel** (`execute-bolts/references/review-panel.md`): `minimal` (spec) / `standard` (spec+quality, default) / `full` (all 4 — fires on auth/authz-glob overlap, dep-manifest in target_files, ≥4 files, auth/payment/crypto keywords, constitution §B binding_refs). Override chain: `--review-panel=` flag > `.mega-sdd/config.yaml` `review_panel:` > auto. Models cited from `model-tiers.md` (rows 19–20), never hardcoded.
- **Merge + gate in the controller**: evidence-or-drop → dedup at max severity → 2+-lens consensus marks → spec ❌ or any Critical re-dispatches the implementer (shared `--max-retries`); Important/Minor recorded in bolt-report `## Review panel`. The deterministic post-flight Hard-rule scan is unchanged — panel is judgment, scan is the contract.
- execute-bolts → 2.12.0; squad/batch fan-out wording updated (panel replaces two-stage; depth-1 rationale intact); `tests/review-panel/` pin suite (agents read-only + no forbidden frontmatter, blind protocol, risk signals, catalog rows, no stale two-stage wording).

## [4.20.1] - 2026-06-11

### Fixed — adversarial bug hunt on the freshly-shipped surfaces (2 REAL + 2 LATENT, all verified by repro)

- **validate-handoff-yaml.sh parser collapsed 2-level nesting**: BLOCK-style `suggested_args:` items under `next_action:` clobbered the parent dict → the `scope_args_missing` check silently no-fired on block-style handoffs (false negative; inline form was unaffected). Parser now tracks the pending nested key; repro'd both directions + new pin D8d.
- **memory-write.sh stale-lock race**: the rmdir+mkdir steal let a second process rmdir the winner's FRESH lock — both then "held" it. Steal is now an atomic `mv` (exactly one winner).
- **secret-scan.sh --redact** now preserves the file's permission bits (0600 stayed 0600 in repro; was rewritten as default umask).
- **compute-unit-staleness.sh** tolerates unreadable paths (perm/NFS/overlong) as missing instead of crashing.
- **pre-tool-use emit_block no-python3 fallback** sanitizes quotes/backslashes/newlines so the deny JSON stays valid.
- Hunt discipline held: 2 agent claims REFUTED with evidence (stop-hook if/fi nesting — disproved by functional smoke + read; closure-binding concern — checked correct). Stdin-first stop path smoke-proved end-to-end (empty transcript → handoff from `last_assistant_message`, single-prefix skill name).

## [4.20.0] - 2026-06-11

### Fixed — platform-assumption sweep: 5 verified WRONGs against current Claude Code docs

The AGENTS.md/worktree bug class, hunted systematically (3 doc-verification agents + manual fetches; every fix doc-quoted):

- **MOAT: PreToolUse block format** — `{"continue": false}` is NOT processed for PreToolUse (it session-halts on other events); the gate now emits `hookSpecificOutput.permissionDecision: "deny"` + legacy `decision: "block"` rider. All moat/fmea tests updated and green.
- **MOAT: /command bypass closed** — typing `/mega-sdd:execute-bolts` expands without a PreToolUse Skill event; new `hooks/user-prompt-expansion` gate (UserPromptExpansion, `decision: "block"`) blocks the expansion itself when the blockers state isn't PASS (functional 2-state test).
- **pandoc failure detection was dead code** — PostToolUse fires on SUCCESS only and carries no `exit_code` field; failures route via the newly-wired `PostToolUseFailure` (matcher Bash) into the same handler.
- **stop-hook fossil removed** — a second, older handoff-validation block re-ran the validator AFTER the fixed one and overwrote its state with the pre-Iter-74 doubled-prefix skill name (re-introducing a fixed bug); now ONE pass, preferring the documented `last_assistant_message` stdin field over transcript parsing (transcript scan kept as fallback).
- **`${CLAUDE_PLUGIN_ROOT}` in references/** — substitution happens in skill/agent/hook content only; reference files are Read raw and the var is NOT exported to the Bash tool → 6 sites now use `<plugin-root>` + a derivation note (the `:-../..` fallback was CWD-relative and wrong).

Also: SessionStart matcher gains `resume` (guards + staleness notice re-fire on resumed sessions); propose-and-confirm AskUserQuestion trimmed to the platform's 4-option cap; AAIF link fixed (Agentic AI Foundation, aaif.io — old URL 404); `/reload-plugins` named as the canonical refresh; ghost `superpowers:reverse-engineering-legacy-codebase` reference removed; exit-code comment corrected (only exit 2 blocks); fork-a-recovery-map block-format prose corrected.

Tests: `tests/platform/test-platform-pins.sh` (15 pins incl. functional UPE gate).

## [4.19.0] - 2026-06-11

### Added — adopt-now roadmap executed (carefully): worktree-proofing, interop pair, CI recipe, EARS tier

Each item verified against the official docs before adoption; two items deliberately NOT flipped, with recorded evidence.

- **Worktree-proofing**: every git-state probe now uses `git rev-parse --git-path …` (rebase/merge state, client hook detection); scan walk-up tests `-e` not `-d` (in a linked worktree `.git` is a FILE). Fixed the v4.18 rails' own literal `.git/...` probes. execute-bolts → 2.11.0, scan-codebase → 2.13.0.
- **AGENTS.md interop pair**: emit-agents-md Step 6.5 offers the OFFICIAL Claude Code bridge — Claude Code does NOT read AGENTS.md natively; the sanctioned path is an `@AGENTS.md` import in CLAUDE.md. Stub creation/append is consent-gated (CLAUDE.md is user-owned). emit-agents-md → 1.4.0.
- **Headless/CI recipe** (`references/ci-recipe.md`): PR drift gate, sync-on-merge, pure-script exit-code gates; surface table (hooks fire under `-p`/action, NOT under `--bare` — script gates are the CI-stable layer); CI never auto-resolves PENDING-SYNC.md (the moat). Wired from README + project-config.
- **EARS structured-criteria tier** (optional, additive): `acceptance_test[].ears` — "WHEN <trigger> THE SYSTEM SHALL <response>"; when present the bolt's TDD test asserts exactly that statement (PBT may derive from it); absent → prose `expects:` unchanged, validators tolerate absence. generate-units → 2.8.0.
- **Capability decisions recorded** (CLAUDE.md §Capability-adoption, do not re-propose): `context: fork` PILOT-GATED — forked skills get NO conversation history, so chain skills lose their handoff `metadata.memory_context` and interactive steps lose AskUserQuestion; no clean candidate today. Skill-scoped `hooks:` NOT adopted for the moat — the global PreToolUse gate must also see Bash state-file tampering and user edits outside any skill lifecycle.
- Tests: `tests/roadmap/test-roadmap-pins.sh` (10 pins).

## [4.18.0] - 2026-06-11

### Added — FMEA rails + future roadmap (spec `2026-06-10-fmea-and-future-roadmap.md`)

Per-phase edge-case audit (4 parallel passes: upstream 62 cases / downstream 36 / environment / cited ecosystem research). 71% of stressed cases were already covered; the rails below close the verified HIGH-likelihood gaps. Every lead re-verified before shipping.

- **Moat fail-closed without python3** (the one verified moat hole): pre-tool-use shell fallback — when python3 is absent, execute-bolts is BLOCKED unless `.validation-blockers.json` attests PASS. Functionally tested in 3 states (FAIL→block, PASS→allow, non-gated→allow) under a no-python PATH harness.
- **extract-intelligence secret-scan gate** before every KB file write (legacy creds no longer ride into KB citations; artifact redacted, source never edited). extract-intelligence → 1.10.0.
- **scan-codebase rails**: never follow symlinked dirs (loop hang); >10MB files skip tree-sitter; monorepo with app-root manifests in multiple dirs → ask the PRIMARY app once. scan-codebase → 2.12.0.
- **binding.md REGENERATED banner** (manual verdict edits are lost on re-bind — resolutions belong in resolve-oq) + binding.md now written while HOLDING the vault.json lock (two concurrent binds can't interleave). bind-codebase → 2.5.0.
- **execute-bolts rails**: parallel waves never share intersecting `target_files` (serialize, don't race); pre-flight 3.5 probes the ecosystem's TEST RUNNER (absent → `dep_missing`; "TDD without a runner is fiction"); new `commit_rejected_by_hook` halt for husky/pre-commit/GPG rejection (`--no-verify` stays forbidden); mid-rebase/merge repo state → stop. execute-bolts → 2.10.0.
- **generate-units scale advisory**: >100 units warn, >500 confirm. generate-units → 2.7.0.
- **PENDING-SYNC.md lifecycle**: archive resolved rows at 100KB/50-resolved → `PENDING-SYNC.archive.md`; loud triage notice at >50 open; `⚠ stale?` marker when the vault moved since queueing. orchestrate-flow → 2.8.0.
- **sync git-state guard**: mid-rebase/merge → stop before scanning garbage.
- **Headless/CI section** in project-config.md (`--auto` everywhere; `--bare` bypasses hook gates — the script-form gates are the CI-stable surface) + **multi-dev note** in paths.md (vault.json/binding.md git-merge corruption; one-writer discipline or gitignore-the-derived).
- generate-intent → 2.7.0 (KB consumption hardening carried in).
- **Future roadmap** (cited): adopt-now = context-fork pilot, skill-scoped hooks for bolt guards, worktree-proof paths, AGENTS.md interop pair; prepare = unit-DAG-as-workflow-plan, CI recipe, optional EARS criteria tier; validated = lean-core does NOT expire at 1M context (description budgets tightened upstream); not-yet = ultracode rebuild, SDK port, MCP servers, shared-memory features.
- Tests: `tests/fmea/test-fmea-pins.sh` — 16 pins incl. the 3-state functional python3-absent gate test.

## [4.17.0] - 2026-06-10

### Changed — redundancy + process-waste audit: optimize without touching the moat

3-layer audit (execution redundancy / contract-prose duplication / hot-path overhead); every lead re-verified before acting — refuted leads NOT applied: glossary pre-parse already fully specified; constitution_hash/prd_sha256 recomputes are intentional fresh-vs-recorded safety comparisons; sync changed-paths already computed once; deep-scan manifest pre-parse already shared; vault.json design_system + phase fields already consumed.

**Hot path:**
- `pre-tool-use`: the 1-stat `.mega-sdd` existence check now runs BEFORE the config grep — fastest exit for every tool call in non-SDD projects; the moat gate path is unchanged (verified empirically + all moat tests green).
- `post-tool-use`: the 6 independent unit-write validators now run in PARALLEL (+`wait`) instead of 6 sequential spawns — each writes its own state file; PreToolUse stays the consumer.

**Execution redundancy:**
- detect-drift Step 1.5 REUSE FIRST: adopts codebase-map §7 framework (confidence ≥ medium + stamp == HEAD) instead of re-parsing manifests the scan already parsed; manifest detection remains the fallback + the vault-stack safety check. detect-drift → 2.7.0.
- generate-intent OQ classifier memoization: unchanged-text OQs reuse their existing classification on re-runs; human overrides never silently overwritten. generate-intent → 2.6.0.
- code-quality-reviewer agent aligned to the model-tiers catalog (sonnet → opus; the catalog's own example documents sonnet as the USER override, not the default).

**Anti-drift (duplicated contracts were already drifting — all verified):**
- Phantom vault filenames eradicated: `04-functional-spec.md` → `04-flows.md` (kb-submode ×2), `01-entities.md` → `03-data-model.md` (binding-contract). bind-codebase → 2.4.0.
- KB read-path priority unified to the 4-path order (paths.md was missing `docs/mega-sdd/knowledge-base/` while being cited as the authority).
- Manifest-detection membership fixed: scan-codebase Step 2 gains `Gemfile` + pointer to the owning table; detect-drift repo-probe gains Python manifests. scan-codebase → 2.11.0.
- install-deps handoff enum gains `choco` (support was claimed, enum omitted it). install-deps → 1.3.0.
- handoff-contract.md: scan-codebase block no longer contradicts the skill's own emission spec (bind-codebase → CWD-conditional generate-intent/bind-codebase, matching starterkit-first); NEW Precedence anti-drift rule — the skill's own handoff reference is the OPERATIVE spec; the contract's per-skill blocks are a consumer-side index. orchestrate-flow → 2.7.0.
- commands/sync.md safe write-back class now mirrors + cites its owner (detect-drift Step 5) instead of paraphrasing it.
- validate-ui-quality.sh SKIP_DIRS aligned with exclusions.md (adds dist/build/target/.next/.venv/coverage); stale "SKILL.md §Default exclusions" pointer fixed.

Tests: `tests/efficiency/test-efficiency-pins.sh` — 10 pins incl. functional non-SDD quick-exit run; full battery green.

## [4.16.0] - 2026-06-10

### Added — artifact delivery: every pipeline result lands somewhere (producer→consumer matrix audit)

4-agent matrix audit over every artifact + handoff field; all ORPHAN/DROPPED leads re-verified before fixing (two agent claims refuted by verification: vault.json `design_system` and `phase`/`phase_total` ARE consumed — left untouched).

- **KB extraction waste eliminated** — three `extract-intelligence` outputs had ZERO downstream consumers; all wired into `generate-intent --kb` (kb-submode §Rebuild-architecture + integrations consumption): `suggested-system-flow.md` → seeds 02-architecture components + 04-flows skeletons (peer of suggested-erd); `module-dependency-graph.md` → `kb_module_graph` pointer consumed by generate-units module auto-derivation as grouping/dependency SEED (evidence rule unchanged); `50-integrations/` → every external contract becomes a 06-constraints integration constraint (`[LOCKED]`) or a templated OQ — "never silently dropped". generate-intent → 2.5.0, generate-units → 2.6.0.
- **codebase-map §6 delivered to bolts** — when `starterkit-context.yaml` is absent (no deep scan), execute-bolts now injects §6 Pattern signatures as a `Codebase patterns:` dispatch line instead of letting the bolt re-invent generic defaults; §6 consumer note added to the map schema. execute-bolts → 2.9.0, scan-codebase → 2.10.0.
- **`scope_args_missing` validator halt (AUDIT L9 seam, deterministically enforced)** — a scoped `execute-bolts` handoff routing to detect-drift without `--scope=` in `suggested_args` now FAILS in `validate-handoff-yaml.sh` (was: contract said MUST, nothing checked; the scope died at the seam and drift full-scanned). Conservative no-fire when undeterminable. Functional 3-state test in `tests/delivery/`.
- **`next_action.confidence` finally consumed** — the typed field now demotes auto-continue to user review when `< confidence_minimum` (default 0.80) in the orchestrator consumption loop (closes the field's own documented F4 intent). orchestrate-flow → 2.6.0.
- **FSD `missing_sources[]` surfaced** — chain final summary reports "FSD emitted with N pending section(s)" (the field was populated but unread).
- **Drift scope observability** — detect-drift Step 0 logs `Scope hint received: …` / `Full scan (no scope hint)` so a dropped scope is visible in one line. detect-drift → 2.6.0.
- **Terminal artifacts documented as terminal** — `DRIFT-ACTIONS.md` is interactive-only (PENDING-SYNC.md is its autonomous counterpart) noted in routing-rules Mode D; `.obsidian/graph.json` marked external-interop terminal.
- Tests: `tests/delivery/test-delivery-pins.sh` — 13 pins (10 contract greps + 3 functional validator runs), all green.

## [4.15.0] - 2026-06-10

### Added — learning loop: pipeline outcomes feed memory; nothing is wasted (spec `2026-06-10-learning-loop-design.md`)

Doctrine: **capture automatic, behavior change suggestion-gated** (the suggestion-only lock is untouched).

- **L1 detect-drift learns** (was: zero memory participation): vault-scope `.memory/drift-history.md` — per-run summaries + fingerprinted direction calls (`<category>:<vault-section>:<normalized-name>` → `code_right|vault_stale|deferred`). Read side pre-fills a suggested direction after ≥3 same-direction calls on a fingerprint class; NEVER auto-resolves (under `--auto` the finding still queues to PENDING-SYNC.md). detect-drift → 2.5.0.
- **L2 sync runs learn**: Mode D appends one `kind: sync` row to project `outcomes.md` (channel mix, applied-vs-queued, safe-class accept/reject, closing staleness); after 3 consistently-ACCEPTed runs the chain-end pass MAY suggest defaulting `--auto-apply=safe` — applied only on explicit ACCEPT.
- **L3 Reflexion failure memory**: `bolt-outcomes.json` gains `failure_reflection` (one-line root-cause on every retry/halt); pre-execution reads surface reflections of the unit's past attempts AND same-module siblings as `## Prior failure context`. execute-bolts → 2.8.0.
- **L4 concerns persist**: per-bolt `acceptance_test_concerns` now ALSO land in `bolt-outcomes.json` (`concerns: [...]`) so recurrence can reach a threshold.
- **L5 extract-learnings is owned**: orchestrate-flow Step 7.6 runs the `learning-rules.md §1` threshold pass ONCE at chain end → appends crossers to `patterns.md ## Pending suggestions`; no skill evaluates thresholds mid-chain. New threshold rows: drift direction (3), sync write-back class (3), concern recurrence (3). orchestrate-flow → 2.5.0, memory → 1.5.0.
- **L6 scope `_index.md`**: derived (regenerated, the one non-append-only exception) per-scope index — row counts, last-entry dates, one-line current state, pending count, size flag; chain-start reads go index-first/just-in-time; a stale index is a hint, never the data.
- **L7 hygiene rails**: secret-scan (`scripts/secret-scan.sh --check`) on EVERY memory append with `[REDACTED-SECRET]` redaction; >256 KB → prune *suggestion* (never auto-prune); detector versioning on conventions (skip-re-detect only while the recorded scan-codebase version matches). scan-codebase → 2.9.0.
- Session-start staleness notice is now PENDING-SYNC-aware: open queue items → the notice points at the queue first ("resolve the queue first"), with the code-moved line appended when both signals fire (closes the sync-digest §consumers promise; hook tested in 3 states).
- Tests: `tests/learning-loop/test-contract-pins.sh` — 17 grep pins on the contract sentences above.

### Fixed — audit remediation (E2E skills audit, same day)

- **Ref hygiene**: 13 bare `references/X` forms → canonical `plugins/mega-sdd/references/X`; 8 `../../` forms → skill-name-relative; vault templates no longer emit dead `references/vault-contract.md` pointers into user vaults. The CLAUDE.md refs rule codified with the verified nuance: SKILL.md is the only router; sibling cross-pointers allowed ONLY when SKILL.md already routes the target.
- **ToCs**: `## Contents` added to 9 long plugin-root refs (paths, telemetry-schema, starterkit-context-schema, upgrade-from-old-version, shared-snapshot-schema, mermaid-emission-rules, model-tiers, tooling-install, reading-map). Exemptions codified: packs/lib-patterns catalogs, `templates/` scaffolds, generated do-not-hand-edit catalogs.
- **Version archaeology purged** from `references/paths.md` (title + ~20 Iter/v3.x comments), `commands/migrate-paths.md` description/body, and the 00-index template heading.
- **marketplace.json cleaned**: giant `version_note` blob removed (CHANGELOG.md is the history), long-overdue deprecated `grand-design-spec` alias entry removed (its own text said "removed after 2 release cycles"), marketplace `description` added, entry version synced — `claude plugin validate` now passes with ZERO warnings.
- **README**: missing v4.14.0 "What's new" entry added.
- **Config key truth**: `project-config.md` `layout:` values corrected to `new|legacy` (what `/mega-sdd:migrate-paths` actually writes) + `output_root` documented.

## [4.14.0] - 2026-06-10

### Added — per-project configuration surface (`.mega-sdd/config.yaml`)

Adopts the plugin-settings pattern (quick-exit, defaults-when-absent, validation, no secrets) on mega-sdd's EXISTING single config surface — deliberately NOT a second `.claude/*.local.md` file. New documented keys with hook-honored opt-outs:

- `dirty_journal: false` — living-vault journaling off for this project (git channel still drives `/mega-sdd:sync`); honored by the PostToolUse hook (quick-exit).
- `staleness_notice: false` — suppress the session-start "codebase moved" line; honored by the SessionStart hook.
- Existing keys (`telemetry`, `layout`) now documented in one place: NEW `references/project-config.md` (defaults, fail-open rules, user/project/vault scope table, commit-vs-gitignore guidance). README gains a "Per-project config" section.
- Both opt-outs empirically tested; full hook suites still pass.

## [4.13.0] - 2026-06-10

### Living Vault — never-ending development (spec `2026-06-10-living-vault-continuous-sync-design.md`)

The pipeline was one-shot (`intent → scan → bind → units → bolts → done`); real products never stop changing. This release ships slices S1–S3 of the continuous-sync architecture: the system now NOTICES code movement (however it happened — manual edit, AI-prompted change outside the pipeline, hotfix, git pull) and reconciles incrementally instead of requiring a cold full re-run. Tech-agnostic by construction (path/git-based; no framework assumptions).

#### Added — S1: ambient change capture (hooks)

- **Dirty-paths journal** — the existing async PostToolUse Write|Edit hook now appends `{ts, path, tool, session}` JSONL rows to `.mega-sdd/codebase/.dirty-paths.jsonl` for source writes in a MAPPED repo (codebase-map.md present). Captures in-session AI edits even before commit. Never journals `.mega-sdd/**` (anti-feedback-loop), never fires in unmapped repos, fail-silent, advisory-only — the hot-path PreToolUse surface does not grow. Pinned by new `tests/hooks/dirty-journal.test.sh` (3 cases, all empirically passing).
- **Session-start staleness notice** — one line of additional context when the journal is non-empty OR git HEAD ≠ the map's `last_scanned_commit`: counts only, suggests `/mega-sdd:sync`. Existing session-start test still passes.

#### Added — S2: incremental re-scan (scan-codebase 2.7.0)

- **`--changed-only`** — resolves `changed_paths` as the union of the journal + `git diff <last_scanned_commit>..HEAD` + uncommitted changes; re-extracts §2/§3/§4 entries ONLY for those paths; carries every other row forward byte-identical; drops vanished files; re-runs framework detection only when a manifest changed; truncates the journal after a successful write. Auto-falls back to full scan (no halt) when preconditions are missing or the delta exceeds 40% of the file census.

#### Added — S3: maintenance routing + front-door (orchestrate-flow 2.3.0, using-mega-sdd 2.1.0, detect-drift 2.2.0)

- **Mode D (maintenance/sync)** in the routing decision matrix: map+binding exist AND change signal present → `scan-codebase --changed-only` → `detect-drift` (scoped to changed paths) → `bind-codebase` → `generate-units` → `execute-bolts` (stale/new units only). P0/P1 OQ intent gate and new-PRD-revision routing still outrank it. CWD snapshot gains `change_signal:` probes.
- **`/mega-sdd:sync` command** — the user-facing entry (like `auto.md`, it invokes the orchestrate-flow skill with `--sync`); `--dry-run` shows the change summary + proposed chain; no change signal → reports "in sync" and stops (no vacuous re-runs). `tests/skill-triggering/sync.test.md` added (5 should-trigger incl. ID variants, 5 near-misses, contract checks).
- Anchor skill (`using-mega-sdd`) routes "sync", "kode berubah", "lanjutin dari kode sekarang", "continue from current code"; detect-drift accepts the changed-paths set as its scope hint.

#### Added — S7: autonomous sync (orchestrate-flow 2.4.0, detect-drift 2.4.0, scan-codebase 2.8.0, using-mega-sdd 2.2.0)

- **Decision deferral** — `/mega-sdd:sync --auto` runs the whole Mode D chain after ONE upfront confirmation and never asks a mid-chain question: safe operations run through (scan merge, claim-scoped re-bind, reconcile, gated bolt execution); human-required decisions (drift direction calls, write-back drafts, re-bind CONFLICTs) queue into `<vault>/PENDING-SYNC.md`. CONFLICTs still close the gate for affected units — handoff `status: paused` with the digest path, never completed-with-silence.
- **`--auto-apply=safe`** (opt-in, OFF by default) — auto-applies only the narrow write-back class: confidence HIGH + name/type-drift or missing-in-vault + claim NOT `[LOCKED]` + committed code (git provenance present). Everything else queues; plain `--auto` queues ALL write-backs.
- **`SYNC-REPORT.md`** — end-of-run report (per-phase outcomes, applied-vs-queued with provenance, conflicts, reconcile counts) with a MANDATORY closing staleness verification (`compute-unit-staleness.sh` re-run; stale=0 or explained). Contracts for both files: new `orchestrate-flow/references/sync-digest.md`.
- **Seamless entry** — the anchor skill treats "map+binding present + change signal" as a strong CWD signal: a continuation prompt proposes `/mega-sdd:sync --auto`. The session-start notice points to PENDING-SYNC.md when open items exist.
- **Flawless journal handling** — consumers rotate (`mv` to `.consumed-<ts>`) instead of truncating (concurrent-session appends survive; crashed-sync leftovers re-unioned next run); the hook stops appending past 1 MB (runaway guard; git channel still covers everything). Cap pinned empirically.

#### Added — S4: claim-scoped re-bind (bind-codebase 2.3.0)

- **`--paths=<csv|@file>`** — incremental re-bind via the binding-anchor reverse-index (file → claims): only affected claims get fresh Step 2 verdicts; the rest carry forward VERBATIM with `provenance: carried_forward`. **Moat unchanged:** every ACTIVE CONFLICT from the previous binding is re-validated regardless of path intersection (never carried on trust); counts recomputed over the full set; `binding.md` rewritten whole with canonical `### CONFLICT-N` headings, so the Step 5 gate and validators see exactly the same surface as a full re-bind. Full-re-bind fallbacks: prior binding unparseable, vault regenerated, >40% of anchored files changed, or any carried anchor vanished. Pinned by new `tests/moat/test-sync-conflict-revalidate.sh` (6 invariant pins, all passing).

#### Added — S5: drift write-back (detect-drift 2.3.0)

- **Step 5.5 vault write-back** — accepted `UPDATE_VAULT` actions become DRAFTED vault patches with mandatory git provenance (`<short-sha> "<subject>" — <author>, <date>` from `git log -1` on the anchor file); batch diff presented; applied ONLY on explicit user ACCEPT; then `00-index.md` changelog + minor version bump + `vault.json` regen under the advisory lock. Per-category patch shapes in `report-format.md §Vault write-back protocol`. Rails: never patch from inference (only the finding's cited code evidence); LOW-confidence findings report-only; `[LOCKED]`-tier claims NEVER patched from code (compliance escalation, not a sync); `FIX_CODE` actions remain out-of-band (the skill never edits app source). The old report-only behavior is preserved verbatim when the user declines.

#### Added — S6: unit lifecycle (generate-units 2.5.0, execute-bolts 2.7.0)

- **`status: implemented | stale | superseded`** optional unit frontmatter (absence = legacy). `bolt-report.md` frontmatter now MUST carry `target_hashes:` (sha256 per target file at commit time) — the deterministic staleness anchor.
- **`scripts/compute-unit-staleness.sh`** — compares bolt-report hashes to the working tree → `stale`/`implemented`/`unknown` JSON (legacy reports without hashes → `unknown`, never guessed). Empirically tested (3 cases).
- **`generate-units --reconcile`** — updates EXISTING unit IDs in place against the refreshed binding: task_type flips per the new Implementation State Map (`create→verify` when code landed out-of-pipeline; `→extend` on PARTIAL_FIELDS_* with Migration notes refreshed), status recomputed, vanished claims → `superseded` (kept, never deleted), new claims → new units through the NORMAL full pipeline. Ambiguous claim↔unit match → `dedup_ambiguous` halt, never a guess.
- **execute-bolts selection** — `superseded` units SKIPPED with a warning; `stale` units eligible for re-execution (the sync lane's "stale/new only" semantics); absent `status` = legacy behavior unchanged.


## [4.12.0] - 2026-06-10

### scan-codebase pipeline audit — drift fixes + research-driven hardening (skill 2.4.0 → 2.5.0)

Pipeline-by-pipeline gap audit (scan-codebase first), grounded in current Anthropic skill-authoring guidance (platform best-practices, agentskills.io spec, Claude Code skills/plugins/sub-agents docs) and community patterns (aider repo-map, GSD codebase mapper, spec-kit, superpowers).

#### Fixed — doc↔reality drift

- **Shipped the 3 missing tree-sitter query files** — `queries/tags-javascript.scm`, `tags-go.scm`, `tags-rust.scm` (adapted from Aider's tags.scm). `tree-sitter-integration.md` claimed 6 query files but only 3 existed; JS/Go/Rust silently fell back to regex while docs promised AST precision. Coverage table in `queries/VERSIONS.md` now lists the query file per language.
- **Deep-scan slice naming/count drift** — `halts-flags-handoff.md` still said `rbac` (renamed `authz`), `subagent_index: <1-4>` and "all 4 subagents" (there are 5 slices incl. `reuse`); `model-tiers.md` example list likewise. All corrected to the 5-slice reality.
- **Stale step numbering** — `deep-scan-prompts.md` referenced "Step 2.2/2.3"; corrected to 10.5.2/10.5.3.
- **libs-extractor prompt contradiction** — the template told the subagent to re-read `composer.json`/`package.json`, contradicting the `<MANIFEST_FACTS>` authoritative-injection rail. Template now consumes `<MANIFEST_FACTS>` directly; the "runtime dispatcher strips legacy entries" caveat removed.
- **Phantom flag** — `scan-procedure.md` Step 5 referred to a non-existent `--deep-scan` flag; rephrased to "default scan (no `--shallow-scan`)".
- **Inconsistent `generated_by` stamps** — examples pinned three different versions (v3.0.0 / @2.7.1 / skill 2.4.0); now derive from the SKILL.md frontmatter version.
- **Single-binary probe drift** — `tree-sitter-integration.md` showed `command -v tree-sitter` only; aligned with SKILL.md's two-binary probe (`tree-sitter || tree-sitter-cli`).
- **Grammar install claim** — `queries/VERSIONS.md` claimed grammars "download lazily"; corrected (the CLI does not auto-download; documented `parser-directories` setup).

#### Changed — authoring-standards conformance

- Stripped version archaeology (`Iter N`, `vN.N+`, internal OQ/closure IDs) from scan-codebase runtime prose (`codebase-map-schema.md`, `tree-sitter-integration.md`, `halts-flags-handoff.md`, `deep-scan-prompts.md`, `queries/VERSIONS.md`, `commands/scan-codebase.md`) per the v4 contract + Anthropic "no time-sensitive info" best practice.
- `commands/scan-codebase.md` `argument-hint` now carries the full flag set (`--engine`, `--shallow-scan`, `--force-deep`, `--no-cache`, `--memory-off`, `--no-default-excludes`) — command↔skill parity restored.

#### Fixed — 14 command files loaded with EMPTY frontmatter at runtime (`claude plugin validate` was failing)

Surfaced by running `claude plugin validate` during the audit: 14 `commands/*.md` frontmatter blocks failed YAML parse, so `description` + `argument-hint` were **silently dropped at load time**. Three root causes, all fixed; validation now passes:

- Unquoted `argument-hint` with multiple `[...]` groups parsed as a broken YAML flow-sequence (orchestrate-flow, auto, lint-units, emit-agents-md, analyze-parallelism, list-modules, diff-vault, detect-drift, resolve-oq, migrate-paths, scan-codebase, generate-intent) → values now quoted.
- `description` starting with `[ADVANCED / AUTO-INVOKED]` / `[USER-INVOKED]` parsed as a flow-sequence (lint-units, emit-agents-md, analyze-parallelism, list-modules, emit-fsd, install-deps) → bracket prefix rephrased to `ADVANCED / AUTO-INVOKED —` form.
- `auto.md` + `orchestrate-flow.md` had **markdown blockquotes inside the frontmatter block** (invalid YAML) plus `Per AUTONOMY-OQ-1 resolved:` colon-space breakage and Iter-N archaeology in descriptions → blockquote moved to the body, descriptions rewritten timeless.

#### Added — research-driven hardening

- **`last_scanned_commit` staleness stamp** in `codebase-map.md` frontmatter (git HEAD at scan time; optional outside git). Lets `detect-drift`/`bind-codebase` derive changed paths via `git diff --name-only <stamp>..HEAD` instead of re-walking the repo (GSD `last_mapped_commit` pattern).
- **Step 10a secret-scan gate** — assembled `codebase-map.md`/`starterkit-context.yaml` content is scanned for credential patterns (AWS keys, private-key blocks, GitHub/Slack/API tokens, JWT-shaped strings, `password=` literals) BEFORE write; matched values redacted as `[REDACTED-SECRET]` with a chat warning citing source `file:line`. Redacts scan outputs only — never edits repo source (GSD secret-gate pattern).
- **Refreshed `tests/skill-triggering/scan-codebase.test.md`** (repo-root suite): output path corrected to canonical `.mega-sdd/codebase/codebase-map.md` (was "repo root"), 6→7 required sections, new behavior checks for the `last_scanned_commit` stamp and the Step 10a secret-scan gate.

### bind-codebase pipeline audit — contract drift + validator-visibility fix (skill 2.1.0 → 2.2.0)

#### Fixed

- **`binding-md-template.md` Conflicts example was invisible to the validators** — the template showed a table with ID `X-001`, which matches NEITHER `validate-handoff-binding-units.sh` (`CONFLICT-\d+`) NOR `validate-conflict-classification.sh` (`CONFLICT-\d+ | C-\d{2,}`). A binding written strictly from the template could carry conflicts the resolution validator never sees. Template now emits the canonical `### CONFLICT-N` detail heading (with `conflict_class` + `resolution_complexity` enrichment) per conflict, plus the summary table with canonical IDs, and documents WHY the heading form is mandatory.
- **`binding-contract.md` described a retired 3-state model** — "only IMPLEMENTED / NEW / UNKNOWN; PARTIAL deferred to Iter 2" contradicted SKILL.md Step 2.5 and `implementation-state.md`, which implement 6 states (`PARTIAL_FIELDS_MISSING/SURPLUS/BOTH`). Contract table updated to the 6-state reality; per-claim probe rules deferred to the implementation-state reference; Implementation State Map example gains the `Field diff` column.
- **`--no-constitution` mis-attributed** — `constitution-and-oq.md` claimed it as a bind-codebase opt-out flag; it is a generate-intent flag. Clarified: absence of `constitution.md` IS the opt-out for binding.
- **Flag parity** — `--no-advisor` + `--memory-off` existed in SKILL.md/references but were missing from `commands/bind-codebase.md`; both added. SKILL.md flags list gains `--memory-off`.
- Stripped version archaeology (`v1.2+/Iter 1`, `Iter-79 X-1`, `DESIGN-OQ-1/3`, `v1.1+/v1.9+/Iter 20/23`) from `binding-contract.md` + `commands/bind-codebase.md`.

#### Added

- `tests/skill-triggering/bind-codebase.test.md` (repo-root suite) gains a behavior check pinning canonical `### CONFLICT-N` heading emission (the validator-readable token).


### generate-intent pipeline audit — vault-contract cleanup (skill 2.3.0 → 2.4.0)

#### Fixed

- **`vault-contract.md` (the shared cross-skill contract, 951 lines) carried 50+ version-archaeology fragments** (`v1.14+/Iter 35`, `Iter 41 sweep closure`, `Iter 58 enum closure`, `DESIGN-OQ-3 resolved`, `Sandbox-proven 2026-05-27`, per-halt `skill vX.Y+, Iter N:` prefixes) — all stripped to timeless prose per the v4 contract; canonical halt registry content unchanged.
- **Stale 4-slice deep-scan naming in the halt registry** — `deep_scan_subagent_failed` said "(auth/rbac/ui-ux/libs)" and `deep_scan_subagent_all_failed` said "ALL 4 subagents"; corrected to the 5-slice reality (auth/authz/ui-ux/libs/reuse), matching the scan-codebase fix.
- **Missing `## Contents` ToCs** on 4 references > 100 lines (`vault-contract.md`, `from-prompt-mode.md`, `legacy-retrofit-prompt.md`, `scope-picker.md`) — added per the >100-line ToC rule.
- Archaeology stripped from `from-prompt-mode.md`, `legacy-retrofit-prompt.md`, `scope-picker.md` headings; `legacy-retrofit-prompt.md` sibling-ref path normalized to the canonical `generate-intent/references/scope-picker.md` form.

#### Added

- (Correction during audit: the repo-root `tests/skill-triggering/` suite already covers all pipelines — an earlier duplicate seeded under `plugins/mega-sdd/tests/skill-triggering/` was removed; the `.gitignore` negation fix for `plugins/mega-sdd/tests/**/*.test.md` is kept so future plugin-level test fixtures aren't silently excluded.)


### execute-bolts pipeline audit — stale gate names + flag parity (skill 2.5.0 → 2.6.0)

#### Fixed

- **Stale PreToolUse "Branch 6/8" names** in SKILL.md Steps 2.5/3 — the named-branch architecture was consolidated into the unified gate aggregator in v4; gates are now referenced by name (ui-quality, render-test).
- **detect-drift hand-off contradiction** — SKILL.md said "After a clean batch: `/mega-sdd:detect-drift`" while `halts-and-handoff.md` documents the auto-gate (DEFAULT-ON, `--no-drift-check` opt-out); SKILL.md now states both accurately.
- **`commands/execute-bolts.md` argument-hint underdeclared 6 flags** (`--hard-rule-grammar`, `--no-pbt`, `--resume`, `--rollback`, `--memory-off`, `--force-skip-postflight`) — full parity restored; hint quoted; `(v2.2+)` markers stripped.
- Version archaeology stripped across `bolt-dispatch-prompt.md`, `hard-rule-grammar-v2.md`, `propose-and-confirm-prompt.md`, `partial-state-and-saga.md` (Iter 30/32/38/44/45/47/76 markers, audit-closure IDs); the deprecated v1.0 tier-loading algorithm stays as a clearly-marked historical section.
- **Missing `## Contents` ToCs** added to `bolt-dispatch-prompt.md` (433 lines), `hard-rule-grammar-v2.md`, `propose-and-confirm-prompt.md`.


### orchestrate-flow + extract-intelligence + side-lane audit — plugin-wide archaeology zero (8 skills bumped)

#### Fixed — orchestrate-flow (2.1.1 → 2.2.0)

- **CWD-snapshot field drift** — SKILL.md declared `oq_p0_p1_count` while `routing-rules.md` (the decision matrix) distinguishes `pending_p0_p1_count` (gates) vs `deferred_p0_p1_count` (informational); snapshot now carries both fields.
- **Broken schema path** — `chain-execution.md` cited `plugins/mega-sdd/references/memory/routing-outcomes.md` (doesn't exist); corrected to the mega-sdd:memory skill reference `memory/references/routing-outcomes.md` (2 spots).
- **Flags gap** — SKILL.md §Flags gains `--strict-quality` + `--no-telemetry` (present in command argument-hints but undocumented in the skill).
- **Related-skills list** now includes the auto-integrated diagnostics (`enrich-semantics`, `lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`, `emit-fsd`, `install-deps`) that also emit handoff YAML.

#### Fixed — extract-intelligence (1.8.0 → 1.9.0)

- **Wave-count drift** — prose said "5 sequential waves" while the table dispatches Wave 0–5 (six); command also claimed "≤5 parallel per wave (hard cap 8)" vs the documented soft-warn>5/hard-cap-8; both corrected.
- **Missing `## Contents` ToCs** added to `knowledge-base-schema.md` (441 lines) and `wave-dispatch-templates.md` (415 lines).
- Cross-skill ref normalized (`predictive-checks.md` → `orchestrate-flow/references/predictive-checks.md`); person-attribution ("Zylos 2026 empirical optimum") and audit-closure IDs removed from runtime prose.

#### Changed — plugin-wide version-archaeology ZERO

Every remaining `Iter N` / `vN.N+` / audit-closure-ID / dated-proof fragment stripped from runtime prose across `skills/` + `commands/` + `agents/` (handoff-contract.md, predictive-checks.md, routing-rules.md, checkpoint-protocol.md, knowledge-base-schema.md, wave-dispatch-templates.md, memory-schema.md, learning-rules.md, agents-md-schema.md, section-mapping.md, tool-matrix.yaml, commands auto/replay/orchestrate-flow/generate-intent/validate-handoff/analyze-parallelism/list-modules/memory/migrate-rules, and more). `migrate-paths` / `upgrade-from-old-version` keep their layout-version mentions — there they are functional (the migration is BETWEEN versions), not archaeology. Verified: `grep -rE "Iter [0-9]|vN.N+"` over skills/commands/agents (excl. _vendored + migrate-paths) returns ZERO.

`## Contents` ToCs also added to 9 further >100-line references (binding-contract, detect-drift auto-and-chain, agents-md-schema, fsd-template, section-mapping, os-detection, learning-rules, memory-schema, routing-outcomes).

Side-lane skill versions bumped: emit-agents-md 1.3.0, emit-fsd 1.2.0, install-deps 1.2.0, memory 1.4.0, resolve-oq 2.1.0, detect-drift 2.1.0.


### Tech-agnostic hardening — scan-codebase multi-ecosystem (skill 2.6.0)

The plugin is tech-agnostic by design, but the scan pipeline's low-level extraction carried a PHP/JS bias. All closed:

#### Fixed

- **Stale-cache bug for non-PHP/JS stacks** — deep-scan cache signatures hashed ONLY `composer.lock` + a JS lock, so dependency changes in Rust/Go/Ruby/Python/JVM apps NEVER invalidated the auth/authz/ui_ux/libs slices (perpetually stale starterkit-context). Cache schema v2.1: per-ecosystem `locks_sha256` map (php/js/rust/go/ruby/python/jvm) + `app_locks_digest` / `frontend_locks_digest` / `all_locks_digest` groups derived from the §7 Framework ecosystem. v2.0 caches self-heal (signature inputs changed → one full re-dispatch). Invalidation matrix rewritten ecosystem-relative (Rails+esbuild example instead of Laravel-only).
- **Manifest pre-parse was composer/package-only** — `manifest_facts` now parses EVERY detected manifest (Cargo.toml, go.mod, Gemfile, pyproject.toml/requirements/Pipfile, pom.xml/build.gradle) into per-ecosystem blocks; libs-extractor prompt inventories all ecosystems, not "composer.json + package.json".
- **Language probe missed Ruby** — `Gemfile` added to Step 2 (Rails/Sinatra were in the framework table but their repos detected as "no package manager").
- **Test-framework detection** extended: rspec/minitest (ruby), `*_test.go` + testify (go), JUnit (jvm), cypress (js), pyproject pytest config.
- **Route extraction covered 5 of 22 frameworks** — Step 6 now has signatures for every framework in the §8.5 table (Express/Fastify/NestJS/Next/Nuxt/SvelteKit/Remix/Laravel/Symfony/Slim/Rails/Sinatra/Django/FastAPI/Flask/Gin/Echo/Fiber/Actix/Axum/Rocket/Spring) + `_universal` best-effort fallback.
- **Model extraction covered 4 ORMs** — Step 7 now spans all ecosystems (Prisma/TypeORM/Sequelize/Drizzle, Eloquent/Doctrine, ActiveRecord, Django ORM/SQLAlchemy/Pydantic, GORM/ent, Diesel/SeaORM, JPA/Hibernate).

#### Added

- `queries/tags-ruby.scm` + `queries/tags-java.scm` — AST-precise extraction for Ruby (Rails/Sinatra) and Java (Spring) repos; regex fallback patterns for both added to Step 5; coverage tables updated (Kotlin/.erb noted as regex-tier gaps).
- `starterkit-context-schema.md` archaeology cleaned to zero as part of the cache v2.1 rewrite.


### Deterministic-script split + capability-adoption doctrine

#### Added

- **`scripts/compute-lock-digests.sh`** — deterministic per-ecosystem lock digests for the deep-scan cache v2.1 (probes php/js/rust/go/ruby/python/jvm locks; emits `locks_sha256` + app/frontend/all digest groups as JSON). The model no longer hand-composes sha256 inputs; deep-scan-stage Step 10.5.1 now says "RUN the script". Empirically tested (Rails+yarn fixture → distinct app vs frontend digests).
- **`scripts/secret-scan.sh`** — deterministic credential scrub backing the Step 10a gate (`--check` reports; `--redact` rewrites matched values to `[REDACTED-SECRET]` in place + JSON report that never echoes the full secret). Empirically tested (AWS key + password assignment redacted; clean rows untouched).
- **`CLAUDE.md` gains a Tech-agnosticism standard** ("does this work for a Rails/Gin/Axum repo too?") and a **Capability-adoption decisions** record: `disable-model-invocation` REJECTED (kills natural-language ID/EN routing), `when_to_use` not adopted (would duplicate description content into the always-loaded listing), deterministic logic → `scripts/` per Anthropic guidance.


## [4.11.0] - 2026-06-10

### Fixed — bolt folder not generated during execute-bolts

A reported bug: running `execute-bolts` (via `orchestrate-flow --auto`) implemented and committed the unit's code but produced **no `<vault>/bolts/U-XXX/` folder + `bolt-report.md`**. Root cause: bolt-folder creation was **prose-only** — the `bolt-implementer` agent writes code/tests/commit but never the bolt folder, and the controller's instruction to write `dispatch-prompt.md`/`bolt-report.md` into it had no deterministic `mkdir` and no end-of-run existence gate, so a terse `--auto` controller could skip it silently (violating the plugin's own "gates > rules > hooks" doctrine).

The fix is two layers — a **strengthened creation step** (still controller-run prose, but moved up and made mandatory) plus a **deterministic, hook-wired detection gate** that loudly catches the skip:

- **`execute-bolts` SKILL.md** — new per-unit **Procedure Step 0**: `mkdir -p <vault>/bolts/U-XXX/` is the literal first per-unit action, *before* pre-flight/dispatch; the folder + `bolt-report.md` are now MANDATORY per-unit outputs. (This is the creation layer — an instruction the controller runs, not a hook; the hook below is what actually enforces it.) (execute-bolts 2.4.0 → 2.5.0.)
- **`context-enrichment.md`** — the dispatch-prompt write step now `mkdir -p`s the bolt dir first (idempotent).
- **`validate-handoff-yaml.sh`** — new **deterministic** halt `bolt_artifacts_missing` (the real enforcement): an `emitted_by: execute-bolts` `status: completed` handoff that **executed units** (`metrics.items_processed > 0`) but lists no `bolts/` artifact now FAILS the Stop-hook handoff validation. This narrows the vacuous-pass hole in the prior `artifact_missing` check (which only verified *declared* paths exist — passing vacuously when none were declared) for any run that reports work. Scoped to avoid false positives — a `--dry-run` / no-op re-run (`items_processed == 0`) or an absent metrics block does NOT fire (a conscious false-negative-over-false-positive trade; the mandatory Step-0 `mkdir` is the primary mechanism, this gate the loud backstop). The execute-bolts handoff contract now requires `items_processed` to report units *actually* committed (0 for dry-run/no-op), so the exemption is contract-grounded. Registered in the halt taxonomy (`halts-and-handoff.md`, `handoff-contract.md`). (orchestrate-flow 2.1.0 → 2.1.1.)
- **Tests** — `tests/bolt-folder-fix/` gate suite (validator raises `bolt_artifacts_missing` on a units-executed no-bolts handoff, stays silent when a real bolts dir is listed, on a dry-run/no-op `items_processed:0` handoff, and on an absent metrics block; SKILL.md carries the mandatory `mkdir` step).

## [4.10.0] - 2026-06-10

### Added — per-stack packs wave 3: the long tail (full §8.5 coverage)

Full-pack coverage reaches **all 22 detectable frameworks** in the scan-codebase §8.5 table. Nine more `pack_tier: full`, lint-clean packs, authored to the 3b `_template` contract via parallel doc-grounded (context7) subagents.

- **`slim.md`** (PHP) — PSR-7/PSR-15, single-action invokables, PHP-DI, middleware authz.
- **`fastify.md`** (Node) — plugins + encapsulation, JSON Schema validation, hooks, `@fastify/jwt`.
- **`remix.md`** (React) — route modules, loaders/actions, `<Form>`, loader-guard authz (Remix v2; RR7 noted).
- **`sinatra.md`** (Ruby) — route DSL, classic/modular, `before` filters, ERB, Rack.
- **`echo.md`** (Go) — `echo.Context` handlers returning error, middleware authz.
- **`fiber.md`** (Go) — fasthttp-based `*fiber.Ctx`, `app.Test`, middleware authz.
- **`actix.md`** (Rust) — `App`/`.service()`, extractors, `.wrap()` middleware + FromRequest guards.
- **`axum.md`** (Rust) — `Router`, Tower `.layer()`, extractors + `FromRequestParts` guards.
- **`rocket.md`** (Rust) — attribute routes, `FromRequest` request guards, fairings, managed state.

### Changed

- **`_lint.md` leak map** — dropped generic `Gemfile` from rails tokens (it is generic Ruby, shared by sinatra; rails keeps `ActiveRecord`/`config/routes.rb`/`app/controllers`/`.html.erb`/`attr_accessible`).
- **`_registry.md`** regenerated — all 22 detectable frameworks show `ready`. `--all` + `--check-registry` + all suites green. The only non-`ready` row is the project-specific `laravel-base-26` starterkit (`unknown` — an open governance decision, not a coverage gap).

## [4.9.0] - 2026-06-10

### Added — per-stack packs wave 2: seven more full framework packs

Full-pack coverage extended from 5 → 12 frameworks. Seven `pack_tier: full`, lint-clean convention packs authored to the 3b `_template` contract via parallel doc-grounded (context7) subagents, each across the 9-section contract incl. the neutral 3a authz ontology.

- **`flask.md`** (Python) — app factory + Blueprints, Flask-SQLAlchemy `db.Model`, `@login_required`/`@roles_required`, Jinja2.
- **`symfony.md`** (PHP) — `#[Route]` attributes, Doctrine, Twig, Security voters + `#[IsGranted]`, `bin/console`.
- **`rails.md`** (Ruby) — ActiveRecord MVC, Pundit/CanCanCan authz, Devise, Hotwire.
- **`spring.md`** (Java) — layered controller/service/repository, Spring Data JPA, `@PreAuthorize`/SecurityFilterChain.
- **`nuxt.md`** (Vue) — file-based routing, Nitro `server/api`, route middleware, Nuxt 3/4 srcDir.
- **`sveltekit.md`** (Svelte) — `+page`/`+server` routing, load functions, form actions, `hooks.server.ts` auth.
- **`gin.md`** (Go) — router groups, middleware-based authz (JWT/casbin), `internal/` layout.

### Changed

- **`scan-codebase` §8.5 detection** — added the first JVM row (`pom.xml`/`build.gradle` → `spring-boot-starter` → `spring`); Spring projects were previously undetectable. (scan-codebase 2.3.0 → 2.4.0.)
- **`_lint.md` cross-framework leak map** — dropped non-distinctive tokens: generic PHP `composer.json` (symfony/slim use it) from laravel, and generic Jinja2 `{%extends`/`{%block` (Flask shares them) from django. Distinctive tokens retained.
- **`_registry.md`** regenerated — all 12 full packs show `ready`; `--all` + `--check-registry` green.
- **Tests** — added wave-proof `tests/per-stack-packs/test-all-full-ready.sh` (every `pack_tier: full` pack must lint clean AND register `ready`).

## [4.8.0] - 2026-06-10

### Added — per-stack packs: five full framework convention packs

Mega-SDD's deep-scan is now framework-accurate beyond Laravel. Five `pack_tier: full`, lint-clean convention packs were authored to the 3b `_template` contract (doc-grounded conventions across the 9-section contract, including the neutral 3a authz ontology). Content-only — no skill or pipeline behavior change.

- **`fastapi.md`** (new) — Python async API; OAuth2/`Security()`/`Depends()` scopes, API-only UI.
- **`next.md`** (new) — React/TS, App Router default (Pages Router noted); `middleware.ts` + NextAuth/Auth.js authz, RSC vs client components.
- **`express.md`** (new) — Node minimal; middleware-based authz (passport/jwt), layered routes→controllers→services, optional view engine.
- **`nestjs.md`** (new) — Node decorator/DI; Guards (`CanActivate`/`@UseGuards`)+`@Roles` authz, modules/providers, API-only UI.
- **`django.md`** — promoted thin proof-pack → full (added Naming standards, Idioms, Hard Rules emitted, Testing conventions; `framework_version_range` 4.2–5.x).
- **Registry:** `_registry.md` regenerated — all five show `ready`. `validate-pack.sh --all` and `--check-registry` exit 0.
- **`_lint.md`:** removed the generic `pyproject.toml` from django's cross-framework token list (it is not django-distinctive; FastAPI/Flask/Poetry use it too).
- **Tests:** new gate suite `tests/per-stack-packs/` (each-lints, five-ready, all-green); `tests/pack-kit/test-registry-fresh.sh` updated for django's promotion.

## [4.7.0] - 2026-06-09

### Added — pack-authoring kit: validate-pack/scaffold-pack/_registry; tier-aware --all CI gate

Pack-authoring kit ships three author-time tools that make adding a new framework convention pack safe and consistent. No runtime/pipeline behavior change; one new advisory scan note added to `scan-codebase`.

- **`scripts/validate-pack.sh`** — deterministic pack linter. Single-pack mode exits non-zero on any violation (missing section / bad YAML / cross-framework token leak). `--all` is tier-aware: `pack_tier: full` packs block on any violation; `thin`/untiered packs block only on structural errors (invalid YAML / cross-framework leak), keeping `--all` a green CI gate for in-progress thin proof-packs. `--registry` regenerates `_registry.md`. `--check-registry` gates freshness.
- **`references/framework-conventions/_lint.md`** — human-readable conformance checklist + cross-framework token map (data-driven; extensible without script edits).
- **`references/framework-conventions/_registry.md`** — auto-generated pack-readiness table (framework | detected? | pack file | status | lints_clean?). Never hand-edit; regenerate with `--registry`.
- **`scripts/scaffold-pack.sh`** — produces a linter-valid `<framework>.md` skeleton from `_template.md`; refuses to clobber; prints next steps.
- **`references/framework-conventions/_template.md`** — `## Reuse discovery` section added (reconciles the v4.5.0 gap: packs already carry this section; `_template.md` now documents it as the complete contract the linter validates against).
- **`scan-codebase`** — one advisory note added: when `_registry.md` reports `thin`/`none` coverage for the detected framework, scan output emits `pack coverage: <status> for <framework> — generic _universal fallback in use; see framework-conventions/_registry.md`. Advisory only; never halts; absent registry → silently skip.
- **README un-TBD** — `framework-conventions/README.md` "Adding a new pack" step 4 no longer says "TBD: pack linter". Updated to reference `validate-pack.sh`, `_lint.md`, tier-aware `--all`, and `scaffold-pack.sh` as step 1.
- **`tests/pack-kit/` suite** — 6 tests (`test-linter-not-a-hook.sh` added; all others shipped earlier in this branch).

Skills: scan-codebase 2.2.0 → 2.3.0.

## [4.3.0] - 2026-06-06

### Fixed — Round-2 end-to-end + subagent-decomposition audit (full trail in `plugins/mega-sdd/AUDIT.md`)

Deep flow-by-flow audit of the whole pipeline + how heavy skills decompose into subagents when one pass is too heavy. Linchpin settled empirically: **PostToolUse hooks fire on subagent writes** (3-sentinel telemetry probe), so the moat quality gates are NOT bypassed on fan-out. Decomposition verdict: extract-intelligence (6 waves) and scan-codebase (4 slices) are correct **depth-1** patterns (main-thread controller + read-only subagents with no Agent tool + bash gates between stages); execute-bolts' squad fan-out was the only structural break. Audit-first held — every finding surfaced + verified before any edit.

- **`execute-bolts --per-squad` was depth-2 broken → now a main-thread loop (L3/L5/L6).** The old design forked one subagent per squad and made it the per-unit controller — which would then have to dispatch the three bolt agents (depth-2; the runtime forbids subagent nesting), silently degrading to inline implementation and **losing the two-stage review** (the moat's quality enforcement). `--all --parallel` carried the same stale "subagent batch" framing, and orchestrate-flow **defaulted** every multi-squad vault into the broken path. Rewritten: the main-thread controller dispatches `bolt-implementer` Agent calls concurrently across independent units (incl. across squads) at depth-1, each unit still going `bolt-implementer → spec-reviewer → code-quality-reviewer`. Enforceable: `tests/moat/test-no-depth2-dispatch.sh` pins the depth-1 invariant across 7 files (PASS on fix, FAIL on every pre-fix phrase).
- **Gate-state hardening, shipped WITH the parallelism enablement (L4).** Enabling depth-1 parallelism activates concurrent state-file writes, so in the same change: (a) the binding→units moat file `.validation-blockers.json` now **fails closed** on a present-but-corrupt state in the PreToolUse aggregator (a torn/garbage write must not silently open the gate — invariant #2); the other 5 gates stay fail-open to avoid spurious transient blocks. (b) **atomic writes** (tmp + `os.replace`, pid-keyed) at every write-site of the 6 aggregator-read validators, so a concurrent reader never sees a torn JSON. TDD: `tests/moat/test-moat-corrupt-fail-closed.sh` (corrupt blocks, absent allows, valid FAIL blocks, valid PASS allows; discrimination proven vs the pre-fix hook).
- **execute-bolts → detect-drift seeds `--scope` (L9).** Resolves the 4.2.0-deferred handoff-seamlessness item: a scope-filtered bolt batch now propagates `--scope=<id>` into the chained drift check instead of falling back to a full scan.
- **generate-intent preserves the enriched stages form (L8).** extract-intelligence v3.72.0+ emits enriched `input_fields` objects + per-stage delta fields (progressive-disclosure intent); generate-intent only documented the bare-string form, risking a silent downgrade. The preservation rule + `04-flows.md` template now mandate carrying the enriched form through (no flatten) and cross-reference the ui-ux-design-intelligence integration design where the semantics are consumed.

### Fixed — doc / honesty (no behavior change)

- **False "subagents invisible to PostToolUse" premise corrected (L2).** The post-tool-use header, `references/telemetry-schema.md`, and the execute-bolts fan-out refs claimed subagent tool calls are invisible to the parent hook — disproven by the L1 probe. The `ref_loaded` under-count is real but caused by **lossy async emission** (async hook + best-effort `>> … 2>/dev/null || true`), not invisibility; re-attributed.
- **fan-out-parity enforcement overclaim dropped (L10).** Resolves the other 4.2.0-deferred item: the validator + post-tool-use comment claimed a blocking "PreToolUse Branch 12" gate that does not exist (the aggregator never reads `.fanout-parity-state.json`; it is advisory per CLAUDE.md). The check itself is sound — obligation-presence parity (`ui_contract` + `render_test` across view-bearing siblings), not a richness proxy.
- **Resume contract reconciled (L7).** orchestrate-flow's "no state file" (chain-level, CWD/artifact-driven phase selection) vs the per-skill checkpoint cursor (sub-step) are now documented as two non-conflicting granularities with explicit precedence.

Skills: execute-bolts 2.1.0 → 2.2.0, orchestrate-flow 2.0.0 → 2.1.0, generate-intent 2.1.0 → 2.2.0.

## [4.2.0] - 2026-06-05

### Changed — Moat hardening: the binding→units gate now enforces CONFLICT *resolution*

Deep advisor-guided audit of the mega-sdd skills (full trail in `plugins/mega-sdd/AUDIT.md`). Headline: the skills work correctly by design — the enforcement spine (every hard-block gate → validator → hook → state file) traces end-to-end, and command↔skill parity is healthy. One real moat gap was found and closed.

- **CONFLICT-resolution enforcement (was propagation-only).** Invariant #2 promises "unresolved CONFLICTs block downstream unit/bolt generation," but `scripts/validate-handoff-binding-units.sh` only verified CONFLICT-ID *propagation* (is the ID cited in some unit's frontmatter?), not *resolution status*. An unresolved-but-cited CONFLICT therefore produced no drop → `status: PASS` → `execute-bolts` not blocked. The validator now also scans structured `### CONFLICT-<id>` detail headings and **fail-closes**: an active heading (per `binding-contract.md`, one carrying `Verdict: CONFLICT (BLOCKING)` and lacking a `✅`/`RESOLVED` marker) emits a new `conflict_unresolved` drop → `status: FAIL`, blocking the existing execute-bolts PreToolUse gate. Resolve by re-running `bind-codebase` to `conflicts=0` or marking the entry resolved. Reuses `.validation-blockers.json` + the existing gate (no new hook, no new state file). TDD: `tests/moat/test-conflict-unresolved.sh` (active-but-cited blocks, resolved exempt, clean binding no-false-positive). OQ-drop + no-vault regressions green.

### Fixed — consistency (doc-only)

- **Dispatch-prompt budget caps** synced: `bolt-dispatch-prompt.md` carried stale 7KB/10KB/5KB figures while the canonical `context-enrichment.md` + `execute-bolts/SKILL.md` use target 9KB / hard 12KB / T2 10KB. Aligned all figures + added a "MUST match `context-enrichment.md`" pointer.
- `skills/analyze/SKILL.md` was missing a `version:` stamp → added `2.0.0` (matches its v4 lean-core sibling cohort).
- `README.md` release narrative was stuck at `v4.0.0 (current)` despite the 4.1.0 stamp → added the v4.1.0 and v4.2.0 narratives.
- `commands/replay.md` example used a non-canonical `vault_version: "1.2.0"` → corrected to `"1.1"`.

### Fixed — Windows install-deps (skill 1.0.0 → 1.1.0)

- **Some native deps could not install on Windows.** `tree-sitter`, `ast-grep`, `tectonic`, and `jd` had no `windows-bash` entry in `tool-matrix.yaml` — they only resolved through the `cargo`/`npm`/`go` fallback, so a Windows box with winget/scoop but no Rust/Node/Go reported them `unsupported` and skipped them. Added native **Scoop** matrix entries for all four (Scoop is their canonical Windows source per their own docs and `references/tooling-install.md`); now every tool has at least one Windows install path.
- **Fallback chain is now Windows-aware** (`os-detection.md`): a secondary native Windows manager that is installed but not the detected primary (scoop → winget → choco) is tried before the cargo/npm/go runtime fallbacks — so a winget-primary box reaches the scoop-only tools when Scoop is present.
- **No more silent skips on Windows:** a tool skipped purely for lack of a manager now surfaces the concrete remedy (install Scoop, or a runtime), instead of a bare "unsupported" line. Human guide `references/tooling-install.md` updated to match.

### Changed — example PRD reflects the canonical standard

- `tests/scenarios/sample-prd-clinic.md` (the first-run reference PRD) rewritten to the canonical `docs/templates/prd-template.md` standard: full required frontmatter (`type`/`version`/`status`/`date`/`authors`/`industry`/`stakeholders`), a single `CLINIC` scope, `universal_sections`, and the `§`-section convention (`§1`–`§9` universal + `§Clinic` scope sections). All original content preserved (flows F-U/F-S, data model, OQs re-tagged `OQ-CLINIC-NNN [P*]`).

### Noted — confirmed but deferred (advisory-layer, future iter)

- execute-bolts→detect-drift handoff carries `suggested_args: []`; the snapshot-reuse / `--auto-gate` coupling is prose-only (handoff seamlessness).
- `validate-fanout-parity.sh` checks spec obligations (`ui_contract`, `render_test`) but not `starterkit_relevance` consistency across siblings — divergent bolt context can still pass parity.

## [4.1.0] - 2026-06-05

### Added — UI/UX design intelligence (distilled ui-ux-pro-max)

Distilled `ui-ux-pro-max` v2.5.0 (MIT, nextlevelbuilder) design knowledge into `references/design-intelligence/` (product-style-map, style/palette/typography principles, ux-rules) via a sync-time distiller (`scripts/_lib/distill-ui-ux.py` + `scripts/sync-ui-ux.sh`). **No runtime dependency** — mega-sdd reads only the committed markdown/YAML.

- **Intent-time (template-first):** a scanned starterkit/template's design flow is authoritative; ui-ux-pro-max only gap-fills, never overrides. When there is no PRD design source AND no scanned template, the Design-Source OQ resolves as `resolution_mode: recommend` with a grounded `{style, palette, typography, a11y_level}` from `product-style-map.yaml` (rationale + citation + fallback + user confirmation). Anti-halu moat preserved — recommendation, never a silent default.
- **Vault:** new `design_system` block in `vault.json` (`vault_version` 1.0 → 1.1) carrying the resolved design system + `source` (`prd` | `scanned-template` | `design-intelligence-recommend`) + provenance.
- **Units:** `## UI contract` gains `design_system_ref` to propagate the choice to bolts.
- **Bolt-time:** `execute-bolts` Step 4.5 injects a `Design system:` line + the matching style-principles/ux-rules slice into ui_ux dispatch prompts; scanned-template tokens stay authoritative.
- **Enforcement:** `validate-dispatch-prompt.sh` now also asserts a non-placeholder `Design system:` line for ui_ux units (`design_system_not_injected`).

Skills bumped: `generate-intent`, `generate-units`, `execute-bolts` → 2.1.0.

## [4.0.0] - 2026-06-04

### v4 lean-core — radical modernization to current Claude Code / Anthropic guidance

A ground-up restructure (branch `v4-lean-core`) bringing the plugin in line with current Agent-Skills best practices and superpowers' "gates > rules > hooks" discipline — **without weakening the spec↔code grounding moat**. Driven by `research/2026-06-04-architecture-modernization-audit.md` + `docs/superpowers/specs/2026-06-04-v4-lean-core-design.md`.

**Skills — progressive disclosure.** Every one of the 16 `SKILL.md` bodies is now a lean router ≤500 lines (was up to 1,285); total skill-body prose dropped 8,758 → 2,574 lines (−70%), with detail relocated into 87 on-demand reference files. Descriptions stripped of version archaeology; all trigger keywords (EN + ID) preserved; the moat (binding verdicts, the CONFLICT gate, the anti-hallucination rail, the hard-rule commit gate) verified in-body.

**Enforcement — Hybrid.** `pre-tool-use` rewritten as a single data-driven gate aggregator (730 → 377 lines). Hard-blocks retained: the binding→units moat gate, predictive preflight, scope-flag, anti-self-bypass, and the high-value code-delivery gates (flow-coverage, render-test, sibling-consistency, ui-quality, cross-cutting-registration). Demoted to `/mega-sdd:analyze` advisory (non-blocking, surfaced read-only): dispatch-prompt, operator-UX, fan-out-parity, ui-deferral, vault-flow-staging. Fixture-tested (kept gates still block, demoted gates allow, anti-bypass fires).

**First-class subagents.** New `agents/`: `bolt-implementer`, `spec-reviewer`, `code-quality-reviewer`, `domain-extractor` — validated against the current Claude Code subagent spec. `execute-bolts` dispatches the bolt agents (two-stage review: spec compliance then code quality); `extract-intelligence` dispatches `domain-extractor` per wave. **All 25 `/mega-sdd:` pipeline commands preserved** (manual CLI entry points).

**Narrative reset.** `CLAUDE.md` rewritten 375 → ~95 lines (invariants + the enforcement doctrine kept; retracted-feature archaeology dropped to git). Version reconciled to a single source of truth — `plugin.json` and `marketplace.json` now both **4.0.0** (was 3.72.0 / 1.3.0).

Pre-v4 "Iter N" development history remains in `CHANGELOG-ARCHIVE.md` and git.

## [3.72.0] - 2026-06-02

### Extract-intelligence deepening — smarter reasoning, more cases caught, automatically

Makes `extract-intelligence` reason deeper and catch the cases a write-side-only read misses — *automatically*, every run. Distilled from a deep audit of `extract-intelligence` output against a real legacy trade-finance codebase (`new-tradefinance-import`, 22 findings). The bridging design proposed verbatim skill-body patches; on contact with the current plugin two facts reshaped the work: (a) the bridging "CRITICAL" item (multi-stage progressive disclosure) is **already shipped** as v3.71.0 staged-input → enriched the EXISTING §3a schema, not a parallel artifact; (b) Fork A doctrine — enforcement must be a validator, not prose that says "HALT". Priority reframe (user): **KB captures business intent + flow; rebuild owns implementation cleanliness — status-naming drift is NOT a gap.**

**Track 1 — P1–P4 deep disciplines wired to fire automatically (the core):**
- `wave-dispatch-templates.md`: the generic subagent prompt's **DEEP DISCIPLINES** block (received by EVERY Wave 1–5 subagent, so the reasoning fires automatically — not SKILL.md-only prose the subagents never read) — P1 state writer↔reader provenance + `INSERT…SELECT` clone-inheritance tracing (captured as a *business outcome*, never a pinned legacy value); P2 enumerate ALL rule/flow sites + entry-point dispatchers (distinct initial states stay distinguishable); P3 behaviour-as-EXECUTED (unconditional halts as `[ARTIFACT: debug-code-as-feature]`, rollback policy, test flags, silent-success); P4 structural file classification. REPORT BACK gains `provenance_pairs_checked`/`provenance_anomalies`/`rule_sites_multi` self-checks + a P1 self-check rail. Wave-3 gate adds **non-blocking** advisory `provenance_read_side_thin` (mirrors `kb_flow_staging_missing` — never fails the wave).
- `extract-intelligence/SKILL.md`: `### Deep extraction disciplines (P1–P4)` design-vocabulary section (authoritative copy = dispatch template) + §7.1 business-intent framing; skill 1.7.0→1.8.0.

**Track 2 — §3a staged-input schema enrichment (reuse-compliant, NOT a parallel artifact):**
- `knowledge-base-schema.md §3a`: `input_fields` accepts bare strings (back-compat) OR objects `{name, mutability ∈ required|optional|display-only|dual-key-re-entry, visibility ∈ shown|hidden|conditional, conditional}`; new per-stage OPTIONAL deltas `new_fields_vs_prior`/`hidden_fields_vs_prior`/`promoted_to_mutable_vs_prior` + `dynamic_disclosures` (within-stage show/hide). Captures the "fields A,B,C at maker; D,E,F at the next stage" case in depth. Best-effort/advisory — optional fields break no consumer (semantic-depth invariant #7).

**Track 3 — Extraction Completeness Contract + real validator (advisory, Fork-A):**
- NEW `scripts/validate-extraction-scorecard.sh` — runnable validator (bash+Python, modeled on `validate-kb-flows.sh`): **SKIP** when absent (back-compat), **PASS** when consistent, **FAIL** on internal inconsistency OR a hidden gap (a PARTIAL/MISSING principle with ZERO `[OPEN]` markers — the silent-drift failure mode). `extract-intelligence/SKILL.md §Step 5.6` — Wave 5 emits `.extraction-scorecard.json` + `EXTRACTION-SCORECARD.md` scoring P1–P4 + P5; anti-halu rail (an honest PARTIAL+`[OPEN]` is the passing state; never up-rank to hide a gap). `bind-codebase/SKILL.md`: scorecard **preflight advisory** consult (surfaces FAIL/absent, non-blocking this iter); skill 1.10.5→1.11.0.
- **Scoped Fork-B-future** (no prose pretending to HALT without a backing validator): B1 hard-block (promote the advisory to a blocking PreToolUse branch), and B2/B3/E1/E2/E3 handshake/post-flight gates — each needs its own `validate-*.sh` + fixtures; B2/B3 to verify the *business outcome* survives, not legacy status values (per the reframe). The bridging design's downstream generate-units/execute-bolts prose gates are DEFERRED (scope narrowed to making *extract* smarter).

**Track 4 — proof:** `tests/fixtures/iter80-extract-deepening/verify.sh` — Fork-A assertions (exit 0): P1–P4 + provenance self-checks reach the wave dispatch prompt; scorecard validator verdicts (PASS / FAIL-hidden_gap / PASS+advisory-when-[OPEN] / SKIP-absent); §3a enriched fields + bare-string back-compat. Fork-B (subagents ACTUALLY reasoning deeper; Wave 5 emitting an honest scorecard) documented as real-run-only, NOT script-asserted. No regressions: iter77 (16/16) + 19/19 code-delivery fixtures still green.

**Invariants honored:** advisories never flip a blocking `status` (Iter-78.1 #1 / Iter-79 #5); `stages:` sub-fields stay OPTIONAL (semantic-depth #7); no new PreToolUse branch this iter (protects Iter-78.1 / Iter-79 / semantic-depth #6/#7 hook invariants). Spec: `docs/superpowers/specs/2026-06-02-extract-intelligence-deepening-design.md`.

## [3.71.0] - 2026-06-02

### Semantic-depth — staged-input walking skeleton (regression: multi-step workflows flattened to single-form)

Fixes a semantic-depth regression surfaced from real legacy code: a multi-step workflow (wizard / maker→checker / multi-page form) stages its inputs (fields A,B,C at step 1; D,E,F at step 2), but the KB→vault→units→bolts handoff **flattened** it to one "Inputs: A,B,C,D,E,F" list — so the bolt built ONE form where the legacy had a multi-step wizard. Root cause: staging was structured *nowhere* and the handoff schema never required it. Walking-skeleton scope: the **staged-input** dimension only (conditional / role-matrix / transition-guard dimensions follow later). Consumer-audited first (`stages:` is an OPTIONAL field — breaks no existing consumer; execute-bolts multi-step is vertical decomposition, deferred Fork-B-future). Advisor-sharpened: deterministic `_kb_source` back-reference (the OQ-ID-class propagation the codebase already uses) instead of fuzzy title-matching.

**Track 1 — schema + contracts (deterministic propagation):**
- `knowledge-base-schema.md`: new `## 3a. Staged inputs` section + the `stages:` YAML block (`stage_id`/`stage_name`/`actor_role`/`input_fields`/`transitions`/`_source`), REQUIRED-when-multi-step (conditional → backward-compatible), per-stage `_source` anchor as anti-halu rail.
- `templates/04-flows.md`: `**Stages**` block (verbatim from KB §3a) + Mermaid `stateDiagram` + `_kb_source` back-reference.
- `vault-contract.md §stages-propagation` + `handoff-contract.md`: explicit KB→vault preservation rule; optional `metrics.flows_with_stages` (type-checked-when-present, never required-on-absence).

**Track 2 — skill bodies (paired with enforcing validators, no prose-only):**
- `extract-intelligence/SKILL.md`: staged-input detection guidance (4 source signals; MANDATORY per-stage anchor). `generate-intent/SKILL.md`: preserve `stages:` verbatim, never flatten.

**Track 3 — enforcement:**
- `validate-kb-flows.sh`: ADVISORY `kb_flow_staging_missing` on a separate `advisories[]` channel — multi-step workflow KB without a `stages:` block. NEVER flips status (Iter-78.1 #1).
- new `validate-vault-flow-staging.sh` (PreToolUse **Branch 14**): follows each flow's `_kb_source`; KB has `stages:` but vault dropped it → `vault_flow_staging_drop`, `status==FAIL` (blocking). Backward-compatible by construction (no KB / no `_kb_source` / KB had no stages → SKIP — pre-staging vaults never trip it). It ALSO carries an advisory arm (`vault_flow_staging_missing`, WARN-only, never status-flip) for the dominant flatten case — a flow showing the workflow signal but with NEITHER stages NOR `_kb_source` (the blocking arm can't see it). **Honest coverage:** the KB advisory + vault advisory are the broad detectors; the block is the narrow precise case (back-ref preserved, stages dropped).

**Track 4 — remediation:** new `/mega-sdd:enrich-semantics` (`scripts/enrich-workflows-staging.sh`) — two-phase (propose → `--apply`) retro-fit of staging onto an existing KB without a full re-extract; re-reads cited legacy `_source`, detects the wizard pattern, allocates fields per stage. Consumes the `kb_flow_staging_missing` advisory. **Auto-propose (wired into `/mega-sdd:auto`):** the orchestrator auto-runs the **propose** step whenever the advisory is present — `--legacy-root` is AUTO-DISCOVERED (KB README "source codebase path" + common legacy dirs), it writes `ENRICHMENT-PROPOSALS.md` and **PAUSES** for review; it NEVER auto-applies (apply stays manual — the best-effort field allocation needs a human; `--no-enrich-staging` opts out). It is the one auto-integrated diagnostic that pauses rather than running transparently.

**Track 5 — proof:** `tests/fixtures/iter77-semantic-depth/` — 16/16 Fork-A assertions incl. the advisor's non-negotiable **hook-fire gate** (PreToolUse Branch 14 emits `continue:false` on a real drop, falls through on preserved). Fork-B (LLM skill-body authoring/preservation) explicitly documented as NOT script-asserted. 19/19 code-delivery fixtures still pass; kb-flows-mermaid unaffected.

## [3.70.0] - 2026-06-02

### Iter 79 — End-to-end pipeline-intelligence audit + 11 enforceable fixes

Fresh end-to-end intelligence audit (`docs/superpowers/audits/2026-06-02-intelligence-e2e/` — 00-SYNTHESIS + 4 detail lanes) targeting per-phase reasoning, advisor-sharpened: every finding graded `enforceable: Y/N` (prose-only "reason harder" asks rejected — 0-for-4 track record), anchored to reproduced `new-tradefinance-import` failures, baselined against shipped machinery. All 11 enforceable findings fixed (each = validator + pack-declared tech-agnostic signature + hook wiring + bad/good fixture; 19/19 code-delivery fixtures pass).

**Tier 0 — real defect (a gate enforcing nothing):**
- **X-1:** `validate-conflict-classification.sh` was vacuous — wired to NO hook + greped for ` ```yaml binding_conflict``` ` blocks the producer never emits (it emits `### CONFLICT-N` markdown) → SKIPped on every real binding. Rewritten to detect the real markdown form (exempting resolved conflicts), wired PostToolUse on binding write, and `binding-contract.md` now templates `conflict_class` + `resolution_complexity`. WARN-not-FAIL (backward-compat).

**Tier 1 — decomposition/delivery (the survivor-bias cluster):**
- **A2 (fan-out parity):** new `validate-fanout-parity.sh` (PreToolUse Branch 12) — presence-parity of deliverable obligations (`## UI contract`, `type: render` test) across VIEW-BEARING siblings. Catches "LC is always the survivor"; relative-to-peers (no false-stop on legitimately-simpler siblings).
- **A1 (decomposition-altitude):** `validate-flow-coverage.sh` emits advisory `decomposition_altitude_high` when an N≥4-step flow is absorbed by a SINGLE unit (does NOT flip status — symptom gates already neutralize the damage).
- **B1 (UI-deferral):** new `validate-ui-deferral.sh` (PreToolUse Branch 13) — a bolt-report that defers a unit's `## UI contract` to a future polish unit ("scaffold kept; UI polish deferred") → `ui_obligation_deferred`.
- **N-1 (shared side-effect parity):** new `flow_step:<regex>` applies_when operator in `validate-sibling-consistency.sh` + pack-declared `inbox-surfacing` concern — closes the af49ede inbox-invisibility gap (amendment/doc_exam created zero `workflow_assignments` rows).

**Tier 2 — upstream transcription-vs-reasoning:**
- **U-GI:** `validate-vault-oqs.sh` re-applies the Auto-classifier heuristic table to EVERY OQ → `oq_misclassified_tech` (a tech-reading OQ lazily tagged business).
- **U-SC:** `validate-codebase-map.sh` depth check — `precision_tier: ast` but bare §2 rows → WARN (bind-codebase field-diff would silently degrade).
- **U-EI:** new `validate-kb-reengineering.sh` — the Wave-5 reengineering synthesis (`99-rebuild-architecture/`) is validated, not just transcription discipline.

**Tier 3 — orchestrator machinery:**
- **O-3/O-4:** `validate-handoff-yaml.sh` now type-checks CONDITIONAL fields when present + promotes `next_action.confidence` to a typed, validated field in `[0,1]` (the iter-33 F4/D5 foundation). Type-only, never required-on-absence — cannot break a live chain that omits an optional block.
- **O-1:** new `validate-preflight.sh` (PreToolUse Branch 0) — predictive halt detection (iter-33 F2 closure): fatal INPUT-precondition checks for the skill about to run (bind needs vault+map; bolts need units), self-clearing.

**Invariants preserved:** every new gate is tech-agnostic (signatures from the framework-convention pack; SKIP off-stack), `errors="replace"` on reads, and new issue types are non-blocking unless a dedicated single-purpose validator (status==FAIL precise) or an explicit COUNT-gated branch opts them in.

## [3.69.1] - 2026-06-02

### Iter 78.1 — E2E integration audit remediation (precision-soundness of the 8-gate stack)

The E2E audit (`docs/superpowers/audits/2026-06-02-e2e-integration-audit.md`) found the integrated 8-gate `execute-bolts` stack deadlock-safe but not precision-sound. Fixed (all fixture-verified; `tests/fixtures/code-delivery/regressions/`):

- **ADV-01 (CRITICAL fail-open):** bare `open()` in flow-coverage/sibling-consistency/unit-spec/vault-oqs crashed on non-UTF-8 bytes → PostToolUse `|| true` swallowed it → gate silently disabled. Added `errors="replace"` to every read.
- **TAE2E-01 (CRITICAL tech-agnostic breach):** sibling-consistency hardcoded the Eloquent paren-call accessor idiom → false-FAILed + BLOCKED any non-Laravel FK project. Accessor shape is now pack-declared (`accessor_form: any|call`); non-Laravel stacks pass.
- **FPP-2 (CRITICAL false-positive):** ui-quality `required_elements` blocked correct Blade partials/components. Now exempts partials (`is_partial()`); `scaffold_tells` still apply to all views.
- **FPP-4:** sibling `missing_relations` was absolute → now a cross-sibling divergence check (solo/convention units pass).
- **FPP-3:** cross-cutting flagged the scope-source `User` model → pack-declared `registration_exempt_glob`.
- **ADV-02/ADV-03:** flow-step parser was numbered-only → now format-aware (numbered / bullet / mermaid); decision verbs + flow_signal inflection-tolerant. Mermaid maker-checker flows (a real production format) are no longer silently passed.
- **ADV-04:** tightened evadable UI scaffold-tell regexes (multi-word/uppercase ID labels, array-access FK echoes, `*_amount`/`*_total` money).
- **ADV-05/ADV-06:** broadened FK-column detection (backticked); strip comments before the cross-cutting registration check (a commented-out registration no longer satisfies it).
- **CD-2/CD-3:** Branch 9 + Branch 10 recovery REASONs rewritten to lead with a non-circular deterministic escape (direct edit / `rm` state) instead of re-running the just-blocked skill.

Also fixed: **ADV-07** (render-test accepts inline-list `acceptance_test`; dispatch-prompt rejects placeholder tokens / bare `Pattern:` label — requires a view-glob `File:`), **IE-2** (execute-bolts parent-thread post-flight re-scan documented to close the `--parallel` subagent-blind window), **IE-5** (spec branch number), and the **CD-6/IE-4 + TAE2E-03 invariant docs** (halt_type-counting on extension gates; `_universal` stays principle-only; `errors="replace"` on reads).

**CD-4 (done in v3.69.2):** the execute-bolts path now precomputes a multi-gate failure summary; `emit_block` prepends it so the first block surfaces ALL failing gates at once (`[N execute-bolts gates are failing: …]`) instead of forcing serial one-gate-at-a-time round-trips. Additive prefix only — empty when ≤1 gate fails; no control-flow change; all 9 fixtures + the 9-branch smoke pass.

**Audit punch-list: CLEARED.** All 35 E2E-audit findings are resolved or were verified design strengths (CD-1/CD-5/CD-6 etc.).

## [3.69.0] - 2026-06-02

### Iter 78 — Sharpen code delivery: decomposition reasoning + UI/UX quality (tech-agnostic, fixture-verified)

**Trigger:** Deep audit (`docs/superpowers/audits/2026-06-01-code-delivery-uiux-deep-audit.md`) + the `new-tradefinance-import` Phase-2 real-run: code *delivery* was the weak link — UI/UX a coin-flip and flow→file decomposition shallow (module-altitude only). Root causes proven from the fixture's own post-generation repair commits: fan-out divergence (golden exemplar correct, siblings drift), zero UI/UX quality gate, capture missing the operator surface.

**Approach (per spec `docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md`):** validator-first (skill prose is defense-in-depth only — prose-only wire-ups failed 4× historically), tech-agnostic (universal validator core + framework-pack-declared signatures; add a stack = add a pack), and **fixture-verified DoD** — each validator must flag the real defect in the tradefinance git history and pass on the repaired state.

**Shipped (7 slices + shared helper, all [HOOK-VALIDATE] Fork-A):**
- `scripts/_lib/resolve-framework-pack.sh` — shared pack resolver (the tech-agnostic backbone; resolves the `extends` chain + merges `--section` bodies).
- **A** `validate-flow-coverage.sh` — flow-step→artifact derivation + scaffold-filter (flags missing per-stage Form Requests + dead `edit` view stubs). PreToolUse Branch 5.
- **B** `validate-sibling-consistency.sh` — cross-unit shared-concern coherence + FK→relation derivation (flags fan-out divergence). PreToolUse Branch 7.
- **C** `validate-cross-cutting-registration.sh` — per-sibling runtime-registration scan on generated source (flags the `2bdfc1b` BranchScoped-not-registered leak; migration-driven table detection). PreToolUse Branch 11.
- **D** render-test-per-view-bearing-unit gate (`render` acceptance_test kind + `validate-unit-spec.sh` extension). PreToolUse Branch 6.
- **E** `validate-ui-quality.sh` — UI scaffold-tells gate (pack-declared `scaffold_tells`/`required_elements`). PreToolUse Branch 8.
- **F** `validate-dispatch-prompt.sh` + execute-bolts enrichment — design tokens un-excluded, UI exemplar few-shot, frontend-design heuristics injected for UI units. PreToolUse Branch 9.
- **G** operator-workflow-UX capture + Design-Source OQ (generate-intent + `validate-vault-oqs.sh`; anti-hallucination rail preserved). PreToolUse Branch 10.
- Framework-pack schema (`_template.md`/`_universal.md`/`laravel.md`/`laravel-base-26.md`) extended with: Flow-artifact derivation, Conditional scaffold artifacts, Entity source globs, Entity matching tokens, Cross-cutting concerns, Relation derivation, Test patterns, UI quality signatures.
- Skill bumps: generate-units 2.8.0→2.12.0, execute-bolts →2.12.0, generate-intent + scan-codebase (per slice).
- Fixtures: `tests/fixtures/code-delivery/**` — every slice has a `{bad,good}/` + `verify.sh` proving FLAG-on-bad + PASS-on-good; 8/8 pass.

## [3.68.0] - 2026-05-30

### Iter 77 — Generalize range-shorthand expansion (`through` / `to` / `thru` / `…`)

**Trigger:** Post-Iter-76 ship, TF Import detect-drift blocked again. State file:

```yaml
missing_artifacts:
  - .mega-sdd/vaults/tradefinance-rebuild-phase-2/bolts/U-017/ through U-025/
```

All 9 directories (U-017..U-025) confirmed on disk. Iter 75 caught ` ... ` ellipsis shorthand; Iter 77 trigger reveals model invented a NEW natural-language range condensation (`through` instead of `...`). Class-bug shape continues: model gravitates to English range expressions when asked to enumerate filesystem paths.

**Root cause:** Iter 75 `expand_ellipsis_range` regex matched only literal `...`. Producer template `execute-bolts/SKILL.md:1062-1067` only listed `...` and `(N units)` as WRONG examples; never anticipated `through`, `to`, `thru`, Unicode ellipsis. Defense-in-depth (validator) AND producer-hardening (template) both had a narrow blind spot.

**Fix (two-track, both files):**

1. **`plugins/mega-sdd/scripts/validate-handoff-yaml.sh` — `expand_ellipsis_range` → `expand_range_shorthand`**
   - Generalized regex to match `(?:\.\.\.|…|through|thru|to)` (case-insensitive for word separators).
   - Backward-compat alias kept (`expand_ellipsis_range = expand_range_shorthand`) — Iter 75 name preserved for any external caller.
   - Fallback handler: if shorthand detected but couldn't expand (malformed U-NNN range), checks each known separator and uses the LEFT side as a literal path (defensive — at least verify the producer's start path; better than failing on a shorthand we can't parse).
   - Call site updated to use new name.

2. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md:1062-1077` handoff template anti-pattern comment**
   - Broadened from "NO '...' shorthand ranges" → "NO range shorthand of ANY kind".
   - Five explicit WRONG examples now listed (ellipsis / Unicode ellipsis / `through` / `to` / `thru`) so the model sees each variant called out by name.
   - Added explicit CORRECT example block showing one-per-line enumeration with absolute paths.
   - Reasoning: model invents new condensations specifically because the prior comment was narrow. Naming each forbidden separator individually makes the rule self-evident even when the model is searching for a "more natural" alternative.

**Why not also handle `-` (single dash) as separator:**
The dash-comment strip pattern `\s+-\s+.*$` would conflict — a path `U-001/ - U-016/` would be stripped to `U-001/` before range expansion. Single dash is excluded from the range-separator set for that reason. If the model ever invents `-` shorthand, the conflicting strip will be detected first; we'll handle that explicitly then.

**Logic-proof (6 scenarios, `tests/fixtures/iter77-range-shorthand/`):**

Fixture: 10 bolt dirs (U-001 + U-017..U-025) on disk.

| Scenario | Verdict |
|---|---|
| `farhan-through-bug` — Farhan's exact production input (U-001 + `U-017/ through U-025/`) | **PASS** ✓ (the bug, fixed) |
| `scenario-D-through` — lowercase `through` only | **PASS** ✓ |
| `scenario-E-to` — lowercase `to` separator | **PASS** ✓ |
| `scenario-F-uppercase` — `THROUGH` case-insensitive | **PASS** ✓ |
| `scenario-G-genuine-miss` — `through U-030/` but only U-017..U-025 on disk | **FAIL** ✓ (false-negative preserved; U-026..U-030 correctly flagged) |
| `scenario-H-iter75-regression` — original `...` ellipsis | **PASS** ✓ (defense intact) |

**Files changed (this iter):**

- `plugins/mega-sdd/scripts/validate-handoff-yaml.sh` — rename + regex generalization + call site update.
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — broadened anti-pattern comment with 5 WRONG examples + 1 CORRECT block.
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.67.0 → 3.68.0.
- `tests/fixtures/iter77-range-shorthand/` — NEW: 6 scenarios + bolt dir fixture + README.
- `CHANGELOG.md` — this entry.

**Logic-proven on fixtures; production live-firing pending `/mega-sdd:update-plugin` at TF Import.**

**Discipline:** authored in canonical, no TF Import touches.

**Classifier (EP2):** MINOR (5 files changed; no halt-enum diff; no new skill dir; no BREAKING marker; validator script + SKILL body modified). plugin.json 3.67.0 → 3.68.0 ✓.

**Class-bug iteration count:** This is the THIRD iter in the "model shorthand vs validator strict-check" class (Iter 73 = parenthetical annotations, Iter 75 = ellipsis, Iter 77 = English range words). Pattern: defense-in-depth strip/expand + producer template anti-pattern comments grow per-shape. Considered an alternative architecture (forbid all artifact field shapes with regex pre-emit), but that's higher complexity vs incremental shape coverage. Stay with current approach; revisit if Iter 78 surfaces a 4th shape — at that point it may indicate a deeper producer-side intervention is needed.

## [3.67.0] - 2026-05-29

### Iter 76 — Wire §patterns + controller code-slice into T2.3 (walking-skeleton)

**Trigger:** Post-Iter-68 regression discovered while tracing bolt output quality. scan-codebase v3.0 (Iter 68) produces a `patterns:` block in `<project>/.mega-sdd/codebase/starterkit-context.yaml` capturing pack-driven location + naming + extras + `_source` per generic category (controller / data_model / request_validator / business_logic / test / schema_migration / route). execute-bolts Step 4.5.b-starterkit.build (last touched Iter 32) injects 4 legacy slices (auth / rbac / ui_ux / libs) into T2.3 BUT NEVER reads the `patterns:` block — bolt subagent is told "follow starterkit conventions" without ever being told what those conventions ARE. Cross-skill producer/consumer split that no validator caught.

**Root cause:** Iter 32's slice builder was authored before §patterns existed; Iter 68 added the producer side (deep-read) but didn't update the consumer (execute-bolts). Classic shape: producer ships, consumer left stale. Same class-bug as Iter 75 (handoff template "..." comment guidance), Iter 73 (annotation tolerance), Iter 69 (next_action shape).

**Fix (two-part wire-up):**

1. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.b-starterkit.build.patterns (NEW)**
   - Iterates all 7 generic categories.
   - **Location-primary match:** if `unit.target_files[i]` starts with `pattern.location` (normalized to trailing slash), category enters slice.
   - **Naming-fallback (only when location is null):** for frameworks with file-based routing (Next.js, Express handlers-anywhere) where convention is naming-not-location. Compiles `{Model}<ext>` → `[A-Z]\w+\.<ext>$`, matches against basename only.
   - **Why not the user-spec OR-semantics:** in fixture testing, `data_model.naming = "{Model}<ext>"` with `.php` greedily matched ANY PascalCase `.php` basename — including `SampleController.php` — causing data_model false-positive injection alongside controller. Location-primary is conservative and avoids crowding T2. Decision logged in SKILL prose; revisit if Iter 77 telemetry shows missed null-location matches.

2. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.b-starterkit.build.code-slice (NEW; walking-skeleton: controller-only)**
   - When `slice.patterns.controller` matched, embed the FIRST `_source` file verbatim as a few-shot anchor.
   - File-size budget: `<3KB` → embed full; `≥3KB` → first 100 lines + `# ... (truncated)` marker.
   - `_source` path missing on disk → log + skip code embed (pattern metadata still injected; NOT a halt).
   - Walking-skeleton: controller-only this iter; extend to other 6 categories Iter 77+ after real-run validates the controller path.

3. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` Step 4.5.a.5 — T2 budget cap bump (Option A)**
   - `cap_t2`: 5120 → 10240 (5KB → 10KB; makes room for patterns + 1 code example).
   - `cap_hard`: 10240 → 12288 (10KB → 12KB; preserves ~2KB T1 headroom).
   - Rationale prose calls out Iter 77 telemetry as revisit gate; truncation cascade extended with `code_examples.controller.content` (100 → 50 lines) priority slot.

4. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` Step 4.5.b-starterkit.inject + `references/bolt-dispatch-prompt.md` §T2.3 — render templates**
   - Two new sections: `### Starterkit code patterns (follow these conventions)` + `### Reference code example (from starterkit)`.
   - Anti-halu rails for each: when patterns block present, bolt MUST honor location + naming + extension for new files in that category; when code example present, bolt MUST follow structural idioms (imports, base class, method shape).

**Logic-proof (3 scenarios, `tests/fixtures/iter76-patterns-injection/`):**

Fixture: Laravel-style starterkit with full §patterns block + `app/Http/Controllers/ExampleController.php` (~720 bytes). Unit with `target_files: [app/Http/Controllers/SampleController.php]`, `starterkit_relevance: [controller]`.

| Scenario | Verdict |
|---|---|
| A_match — unit matches `patterns.controller.location` | **PASS** ✓ — slice.patterns.controller populated, slice.code_examples.controller embeds ExampleController.php verbatim, T2.3 render shows both sections (rendered 1428 bytes). data_model NOT false-positively injected. |
| B_no_match — `target_files: [resources/views/random.blade.php]` matches no category | **PASS** ✓ — slice.patterns empty, no patterns/example render (rendered 47 bytes — header only). |
| C_missing_src — `patterns.controller._source[0]` points to nonexistent file | **PASS** ✓ — pattern metadata still rendered (preserves conventions), code_examples skipped (no halt). |

**Files changed (this iter):**

- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.a.5 caps bump; Step 4.5.b-starterkit.build extended with `.patterns` + `.code-slice` sub-blocks; Step 4.5.b-starterkit.inject render extended; truncation cascade extended (5 levels).
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — §T2.3 template extended with `### Starterkit code patterns` + `### Reference code example` sections + anti-halu rails per section.
- `plugins/mega-sdd/.claude-plugin/plugin.json` — version 3.66.0 → 3.67.0.
- `tests/fixtures/iter76-patterns-injection/` — NEW: simulate-build.py + Laravel-style starterkit fixture + README documenting 3 scenarios.
- `CHANGELOG.md` — this entry.

**Logic-proven on fixtures; production live-firing pending `/mega-sdd:update-plugin` at TF Import.** Walking-skeleton: controller-only this iter. Iter 77 extends to data_model + test categories after real-run telemetry confirms patterns reach bolts + budget stays manageable.

**Discipline:** authored in canonical (gitlab.com/airnd1/grand-design-spec), no TF Import touches.

**Classifier (EP2):** MINOR (4 files changed; no halt-enum diff; no new skill dir; no BREAKING marker; existing SKILL bodies modified). plugin.json 3.66.0 → 3.67.0 ✓.

## [3.66.0] - 2026-05-29

### Iter 75 — Handoff ellipsis range expansion (`U-001/ ... U-016/`)

**Trigger:** TF Import detect-drift block, post-3.65.1 ship. execute-bolts emitted:

```yaml
artifacts:
  - .mega-sdd/vaults/tradefinance-rebuild-phase-1/bolts/U-001/ ... U-016/
```

Validator strict-check `os.path.exists("<path>/U-001/ ... U-016/")` → False → `artifact_missing`. All 16 bolt directories actually exist on disk; the model condensed the enumeration into ellipsis shorthand.

**Root cause:** `execute-bolts/SKILL.md` handoff template had:
```yaml
artifacts:
  - <absolute path to vault/bolts/U-001/>
  - <absolute path to vault/bolts/U-002/>
  # ... one per unit executed     ← the "..." in the COMMENT cued the model to use "..." in OUTPUT
```

The trailing `# ... one per unit executed` comment was meant as instruction to the reader ("repeat for each unit"); the model interpreted "..." as a valid shorthand to emit verbatim.

**Two-track fix:**

### Track 1 — Producer template hardening

`plugins/mega-sdd/skills/execute-bolts/SKILL.md` line 943-948 — handoff `artifacts:` block now carries explicit anti-pattern comments:

```yaml
artifacts:                                                  # Enumerate ONE LINE per bolt dir actually written; NO "..." shorthand ranges; NO "(N units)" annotations
  - <absolute path to vault/bolts/U-001/>                   # e.g., /Users/.../.mega-sdd/vaults/<vault>/bolts/U-001
  - <absolute path to vault/bolts/U-002/>                   # one line per executed unit
  # WRONG: "/.../bolts/U-001/ ... U-016/"  ← validator expands ellipsis defensively (Iter 75), but producers SHOULD enumerate explicitly
  # WRONG: "/.../bolts/ (16 units)"        ← annotation will be stripped, but be explicit
  # Repeat "- <abs path to bolts/U-NNN/>" for EVERY unit you executed — no shortcuts.
```

### Track 2 — Validator defense-in-depth: ellipsis range expansion

`plugins/mega-sdd/scripts/validate-handoff-yaml.sh` Step 5 — new helper `expand_ellipsis_range(p)` detects `<prefix>U-<start>/ ... U-<end>/` pattern, parses start/end as integers, expands to explicit path list, checks each `os.path.exists()`. Sanity cap: max 1000 entries to bound pathological inputs.

Fallback: if path contains ` ... ` but doesn't match the U-NNN range pattern, treat the LEFT side as the actual path (defense: if start exists, producer at least got the location right).

Both Iter 73 strip patterns AND Iter 75 ellipsis expansion now apply to every artifact path defensively.

### Logic-proven via direct-invoke

Fixture at `/tmp/iter74-bolts/` with 16 bolt directories on disk (mirrors Farhan's TF Import disk state):

| Scenario | Handoff content | Verdict |
|---|---|---|
| A. Farhan's exact ellipsis bug | `artifacts: ["/bolts/U-001/ ... U-016/"]`, U-001..U-016 all exist | **PASS** ✓ (expansion + exists check) |
| B. Clean enumerated | 4 explicit paths | **PASS** ✓ |
| C. Ellipsis claims U-001..U-020 but disk only U-001..U-016 | range expands → U-017..U-020 don't exist | **FAIL** ✓ (detection preserved) |

Scenario C confirms the expansion correctly flags genuinely missing artifacts even when shorthand was used — defense doesn't introduce false negatives.

### Cross-skill scope

Validator-side fix applies to ANY skill emitting U-NNN ranges with ellipsis (execute-bolts, generate-units, list-modules, etc.). One defensive expansion covers the class. Generic-numeric patterns (non-U-NNN) currently fall back to the LEFT-side-as-path check — extension candidate if other patterns emerge in soak.

Plugin version 3.65.1 → 3.66.0 (MINOR per classifier: new validator capability + producer template hardening).

---

## [3.65.1] - 2026-05-29

### Iter 74 (patch) — Stop hook emitted_by regex tolerates `mega-sdd:` prefix

**Trigger:** TF Import detect-drift block message showed `upstream mega-sdd:mega-sdd emitted bad handoff` — doubled `mega-sdd:` prefix in the producer name.

**Root cause:** `hooks/stop` regex extracting `emitted_by` from handoff used `[\w-]+`, which stops at colon. When the producer emitted `emitted_by: mega-sdd:execute-bolts` (with full prefix — variant the wild produces despite handoff-contract.md saying bare form), the regex captured only `mega-sdd`, then the downstream code unconditionally prepended `mega-sdd:` → final `mega-sdd:mega-sdd` written to state file `skill_name` field.

**Side effects:**
- **Iter 70 producer-self-fix broken in this case**: `SKILL_NAME` being invoked is `mega-sdd:execute-bolts`, but `state.skill_name` is `mega-sdd:mega-sdd`. They don't match → producer-self-fix allow doesn't fire → producer can't retry to fix its own bad handoff (the deadlock Iter 70 was meant to prevent reappeared in a new shape).
- **Cosmetic**: PreToolUse block message displayed `upstream mega-sdd:mega-sdd` instead of the real producer name.

**Fix:** Extended regex to tolerate optional `mega-sdd:` prefix on the value: `^\s*emitted_by:\s*(?:mega-sdd:)?([\w-]+)`. Matches both forms — bare and prefixed — extracting just the skill identifier. Downstream prepend produces `mega-sdd:<skill>` consistently regardless of which form the producer emitted.

**Logic-proven via direct regex tests:**
| Producer wrote | Extracted |
|---|---|
| `emitted_by: extract-intelligence` | `extract-intelligence` |
| `emitted_by: mega-sdd:execute-bolts` | `execute-bolts` |
| `emitted_by:    mega-sdd:scan-codebase` (extra spaces) | `scan-codebase` |
| `emitted_by: mega-sdd:detect-drift` (inside YAML fence) | `detect-drift` |

PATCH bump 3.65.0 → 3.65.1 (regex tweak only, no semantic change to validator logic).

---

## [3.65.0] - 2026-05-29

### Iter 73 — Handoff artifact annotation tolerance (false-positive fix)

**Trigger:** TF Import production run, post-3.64.0 ship. User attempted `/mega-sdd:execute-bolts --all --auto` after successful KB → units chain; PreToolUse blocked with:

```
upstream mega-sdd:generate-units emitted bad handoff (artifact_missing, retry=2, escalate_c2=True)
missing_artifacts: [".mega-sdd/vaults/tradefinance-rebuild-phase-1/units/ (18 files)"]
```

Disk inspection: the path `.mega-sdd/vaults/tradefinance-rebuild-phase-1/units/` DOES exist with 18 entries (16 units + `_index.md` + `_dependency-graph.json`). The validator failed because the producer emitted the path with a `" (18 files)"` count annotation appended, and `os.path.exists("<path>/ (18 files)")` returns False.

**Root cause:** `generate-units/SKILL.md` handoff template placeholder reads `<absolute path to units/ directory>` — semantically ambiguous. The model interpreted "describe the units directory" and appended a count annotation. The template never explicitly forbade annotations; `validate-handoff-yaml.sh` walks artifacts strict-equal against `os.path.exists()`.

**Two-track fix:**

### Track 1 — Producer template hardening

`plugins/mega-sdd/skills/generate-units/SKILL.md` line 803-809 — handoff `artifacts:` block now carries inline comments explicitly forbidding annotations:

```yaml
artifacts:                                       # MUST be plain filesystem paths — NO annotations like "(N files)", "(latest)", or comments
  - <absolute path to units/ directory>          # e.g., /Users/.../.mega-sdd/vaults/<vault>-bound/units (or <vault>/units when --no-bind)
  - <absolute path to units/_index.md>           # e.g., /Users/.../.mega-sdd/vaults/<vault>-bound/units/_index.md
  # WRONG: "/Users/.../units/ (18 files)"        ← validator strips trailing " (...)" defensively, but producers SHOULD emit clean paths
  # WRONG: "/Users/.../units/ # latest"          ← inline comments invalid in YAML scalars
```

### Track 2 — Validator defense-in-depth

`plugins/mega-sdd/scripts/validate-handoff-yaml.sh` Step 5 (artifact existence check) — strips 3 trailing annotation patterns before `os.path.exists()`:

| Pattern | Example | Strip |
|---|---|---|
| `\s+\([^)]*\)\s*$` | `path/ (18 files)` | trailing parenthesized text |
| `\s+-\s+.*$` | `path/ - latest` | trailing dash-comment |
| `\s+#\s+.*$` | `path/ # note` | trailing hash-comment |

Plus a `rstrip("/")` to tolerate trailing slash on directory paths.

The ORIGINAL path is reported in `missing_artifacts` (so producer can see what they emitted) — only the existence check uses the cleaned form.

**Scope:** the strip applies to ALL skills' handoff artifacts (generate-units, bind-codebase, extract-intelligence, diff-vault, emit-fsd, execute-bolts, generate-intent, detect-drift, emit-agents-md) — all share the same `<absolute path to ...>` placeholder pattern and same potential failure mode. Validator-side fix covers the class.

### Logic-proven via direct-invoke

Built fixture at `/tmp/iter73-genunits/` matching Farhan's exact disk state (16 units + _index + _dependency-graph = 18 entries):

| Scenario | Handoff content | Verdict |
|---|---|---|
| A. Farhan's exact bug | `artifacts: ["/path/ (18 files)"]`, files exist | **PASS** ✓ (strip resolves to real dir) |
| B. Clean variant | `artifacts: ["/path/", "/path/_index.md"]`, files exist | **PASS** ✓ |
| C. Genuinely missing | `artifacts: ["/missing/", "/missing/ (50 files)"]`, files DO NOT exist | **FAIL** ✓ (detection signal preserved) |

Scenario C confirms the defense doesn't introduce false negatives — actual missing artifacts still surface, with the ORIGINAL annotated path reported.

### Files changed

| File | Change |
|---|---|
| `plugins/mega-sdd/skills/generate-units/SKILL.md` | Handoff template — inline comments forbidding annotations + WRONG examples |
| `plugins/mega-sdd/scripts/validate-handoff-yaml.sh` | Step 5 — defensive strip of trailing annotations before `os.path.exists()` |

Plugin version 3.64.0 → 3.65.0 (MINOR per classifier: producer template hardening + validator behavior change).

### Immediate workaround for affected installs

For projects already in the FAIL-state-with-retry-2-escalate (Farhan's case):

```bash
rm <project>/.mega-sdd/.handoff-validation-state.json
```

(File NOT in anti-self-bypass protected list.) Then re-run `/mega-sdd:execute-bolts --all --auto`. After v3.65.0 update lands, future runs do not need the manual rm — validator tolerates the annotation natively.

---
