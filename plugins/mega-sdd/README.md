# mega-sdd

Spec-driven AI development pipeline for [Claude Code](https://claude.com/claude-code). PRD or idea → vault → atomic units → tested commits with anti-hallucination at every handoff.

**Version:** 3.18.1 · **License:** MIT

> 📖 Full documentation + user-facing scenarios at the repo root. See [`../../README.md`](../../README.md) + [`../../tests/scenarios/`](../../tests/scenarios/).

## Quick start

```bash
# Install
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended

# Optional native binaries (precision boost):
brew install tree-sitter ast-grep ripgrep jd
# OR
cargo install tree-sitter-cli ast-grep ripgrep
go install github.com/josephburnett/jd@latest

# Then in any project:
/mega-sdd:auto ./prd.md
```

That's it. Full install matrix: [`references/tooling-install.md`](./references/tooling-install.md).

## First-time user? Start with a scenario

| Scenario | When | Time |
|---|---|---|
| [Greenfield from idea](../../tests/scenarios/scenario-1-greenfield-from-idea.md) | Brand new; minimum viable demo | 15 min |
| [PRD-driven feature](../../tests/scenarios/scenario-2-prd-driven-feature.md) | Have PRD; existing project | 30 min |
| [Field-level extension](../../tests/scenarios/scenario-3-field-extension.md) | Add field to existing model | 20 min |
| [Legacy rebuild](../../tests/scenarios/scenario-4-legacy-rebuild.md) | Legacy → new framework | 4 hours |
| [Multi-squad parallel](../../tests/scenarios/scenario-5-multi-squad-parallel.md) | Multi-team coordination | 45 min |
| [Recovery from halt](../../tests/scenarios/scenario-6-recovery-from-halt.md) | Bolt halted; need to recover | 15 min |

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest (v3.18.1)
├── skills/                       # 13 skills + _vendored/
│   ├── using-mega-sdd/           # anchor skill (auto-injected) (v1.2.1)
│   ├── memory/                   # memory + self-learning (v1.2.1)
│   ├── emit-agents-md/           # AGENTS.md flatten (v1.2.3)
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.4.0)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.10.0)
│   ├── scan-codebase/            # tree-sitter AST scan (v2.4.2)
│   ├── bind-codebase/            # validation gate + field diff (v1.9.2)
│   ├── generate-units/           # atomic decomposition (v2.5.3)
│   ├── execute-bolts/            # superpowers TDD bridge (v2.4.1)
│   ├── orchestrate-flow/         # lifecycle router (v2.3.2)
│   ├── resolve-oq/               # OQ resolver + recommendations (v0.9.0)
│   ├── detect-drift/             # code vs vault (v1.2.1)
│   ├── diff-vault/               # PRD revision + jd patches (v1.2.1)
│   └── _vendored/                # superpowers fallback
├── commands/                     # 20 slash commands (1 primary + 19 advanced)
│   ├── auto.md                   # ⭐ THE command
│   ├── generate-intent.md, scan-codebase.md, bind-codebase.md, generate-units.md, execute-bolts.md
│   ├── extract-intelligence.md, orchestrate-flow.md, resolve-oq.md, diff-vault.md, detect-drift.md
│   ├── memory.md, emit-agents-md.md
│   ├── lint-units.md, analyze-parallelism.md, list-modules.md    # [auto-invoked by /mega-sdd:auto]
│   ├── migrate-rules.md, migrate-paths.md                         # one-off maintenance
│   └── update-plugin.md
├── references/
│   ├── paths.md                  # canonical folder layout (Iter 10)
│   └── tooling-install.md        # optional native binaries install matrix (Iter 14)
├── hooks/                        # SessionStart hook
├── scripts/                      # sync-superpowers + memory-migrations/
├── CLAUDE.md                     # AI-agent contributor guidelines
└── LICENSE
```

## Pipeline (one-line)

```
[legacy → extract-intelligence] → brief/PRD → generate-intent → (scan + bind for brownfield) → generate-units → execute-bolts → emit-agents-md
```

Wrapped by `/mega-sdd:auto` for autonomous end-to-end execution with single upfront confirmation. Diagnostics (lint, analyze, modules, emit) AUTO-INVOKED at appropriate phases per Iter 13 consolidation. Halt-protocol preserved across all iters.

## What's new in v3.23.0 (Iter 32) — Starterkit-Aware Deep Scan

### v3.23.0 (Iter 32) — Starterkit-Aware Deep Scan

mega-sdd now **automatically** captures your starterkit's actual auth/RBAC/UI-UX/library patterns and feeds them through the pipeline — no flags, no config.

**What changed:**
- `scan-codebase` v2.6.0+ runs a deep-scan stage automatically when a framework is detected. 4 parallel subagents read your manifests + actual code to extract: which auth lib (Sanctum/Breeze/Jetstream/Fortify/Passport), which RBAC lib (Spatie/permission/custom), which UI stack (Alpine/Livewire/Inertia + Tailwind/Bootstrap + SweetAlert/Toastr), and your full library inventory with usage hints.
- Output: `.mega-sdd/codebase/starterkit-context.yaml` — canonical structured context, cached via lock-file hashing (re-scan with unchanged deps is 0sec).
- `generate-units` v2.6.0+ reads the context and adds starterkit-specific Anchors and Hard Rules to each unit with mandatory citations. Your unit specs now know about `layouts.app`, `User` model FQCN, your Spatie middleware names, your SweetAlert2 component path.
- `execute-bolts` v2.7.0+ injects a relevant slice (≤2KB, per-unit) into the bolt-dispatch-prompt T2 tier. Bolts generate code that matches your starterkit by default — uses your layout, your notification lib, your auth guard.

**Why this matters:**
- Before: generated units used framework defaults; bolts produced code that didn't always match your starterkit's libs.
- After: your starterkit's choices propagate automatically. Standing prefs like SweetAlert2 + `document.addEventListener` over `$(document).ready` + responsive mobile-first flow into Hard Rules with citations — no per-session reminder needed.

**Autonomous by design:**
- Zero user flags. Zero config. Triggers automatically when `scan-codebase` detects a framework at MEDIUM+ confidence.
- Graceful degradation: subagent timeouts → partial output; all-fail → preserve prior cache + halt for retry; no framework detected → skip silently.

See [docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md](../../docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md) for the full design.

---

## What's new in v3.22.0 (Iters 17-30)

- **Iter 17 Constitution layer** — 8th vault file (`constitution.md`) with project-facing rules; clauses inject into bolt Hard Rules
- **Iter 18 Replay + PBT** — `/mega-sdd:replay <unit>` for regression detection; `properties:` field for invariant testing
- **Iter 19 Convergence loops** — `/mega-sdd:auto --converge` auto-recovers eligible halts using memory recommendations
- **Iter 20 Audit fixes** — closed 5 claim-vs-implementation gaps from Iter 17-19
- **Iter 21 Path-default hotfix** — all writer-side defaults flip to `.mega-sdd/` (no excuse); read-side back-compat preserved
- **Iter 22 KB-as-analysis philosophy** — 3-tier mutability classification (`[LOCKED]/[INTENT]/[ARTIFACT]`) orthogonal to existing confidence markers. KB drives reengineering recommendations, not 1:1 legacy mirror. `data-mutation-policy.md` + ERD Quality Rails. `generate-intent --kb` routes claims to vault per tier
- **Iter 23 Framework Convention Packs** — pluggable convention catalog at `references/framework-conventions/`. scan-codebase detects framework (Laravel/Django/Rails/Express/NestJS/FastAPI/etc.) → bind-codebase loads matching pack → framework-specific Hard Rules merged into Suggested Unit Hard Rules. Universal-good-practice fallback. v1.0 ships with `_universal.md` + `laravel.md` + `_template.md` for adding more
- **Iter 24 RECON / base-laravel-26 starterkit pack** — extracted user's Laravel 12 starterkit conventions (Vuexy + Jetstream + Spatie + Reverb + custom helpers/traits + CRUD generator + notification rule engine) into `laravel-base-26.md` (~600 lines, extends `laravel.md`). 11 Hard Rules + 11 forbidden patterns + project-specific idioms encoded as enforceable conventions. scan-codebase detects via Vuexy fingerprint
- **Iter 25 Audit closure** — closed 27 findings from v3.16.0 deep audit: completed Iter 21 hotfix across 6 commands + handoff-contract + memory schema + recommendation-context + checkpoint paths; fixed bind-codebase step sequence (duplicate 2.5 + dangling 2.10) + halt-conditions completion; fixed generate-units step jumble; propagated Iter 22 mutability to 6 consumer skills (bind, drift, resolve-oq, generate-units, agents-md, handoff); propagated Iter 23 framework pack to generate-units (provenance citation) + execute-bolts + AGENTS.md header; fixed 2 broken cross-references; updated scenario-4 to demo tier flow + starterkit detection
- **Iter 26 Verification closure** — closed 5 highest-leverage gaps from v3.17.0 verification audit: emit-agents-md output template now uses `{{vault_path}}` substitution (no more legacy paths in every AGENTS.md emitted); bind-codebase step 2.10 placed in linear sequence; generate-units 7.5/7.6 swap + audit log → step 13; diff-vault:318 cross-ref fixed; commands/orchestrate-flow.md refreshed for `--deep` + `--resume`; AGENTS.md schema gains PBT/replay/convergence header fields (P1-9)
- **Iter 27 Starterkit-first pipeline** — scan-codebase moves to FIRST phase when starterkit detected; vault generation becomes pack-aware via dual-citation format (Intent + Starterkit binding). Three modes: A (starterkit-first DEFAULT), B (framework universal fallback), C (explicit `--greenfield`). New halt `no_starterkit_detected` enforces opinion. Per user directive "starterkit itu wajib ada, jika tidak ada baru greenfield"
- **Iter 28 Multi-scope PRD picker** — canonical PRD/BRD format with `scopes:` frontmatter block enables deterministic scope detection. Each architect (BE/MW/FE) generates a vault scoped to ONLY their content. Interactive picker (cwd smart default + memory-driven recall + confirm-once). Legacy PRDs without frontmatter trigger AI-assisted retrofit bridge. No cross-scope orchestration — coordination remains human-driven (rapat antar arsitek). New `--scope=<id>` flag in `/mega-sdd:auto` + `/mega-sdd:generate-intent`. Governance artifact: `docs/templates/prd-template.md` for sharing with PMs as new SOP
- **Iter 29 v3.20.0 audit closure** — 13 findings closed from post-Iter-28 deep audit (`docs/superpowers/audits/2026-05-24-iter-28-v3.20.0-deep-audit.md`). Pattern was Iter 28 producer-only: generate-intent wrote scope to vault.json + handoff YAML, but ZERO downstream skills consumed it. Fix: scope propagation to 6 consumer skills (bind-codebase v1.9.3, generate-units v2.5.4, emit-agents-md v1.2.4, execute-bolts v2.4.2, detect-drift v1.2.2, resolve-oq v0.9.1). Also: diff-vault v1.3.0 implements prd_sha256 change detection (closed unimplemented spec claim). Orchestrate-flow v2.4.1 halt taxonomy gains 4 new entries (3 Iter 28 + 1 Iter 29). Generate-intent gains formal §Halt conditions section with full YAML envelope examples. Step 0.9 execution-order guard added (file order ≠ runtime order). agents-md-schema.md stale legacy vault paths fixed
- **Iter 30 execute-bolts seamless pipeline** — bolt subagent dispatched via tiered context enrichment (T1 always ≤2KB / T2 conditional ≤5KB / T3 reference-on-demand) per `references/bolt-dispatch-prompt.md`. Implements 10 AI-executor principles from spec (anti-context, confidence labels, past-failure intelligence, self-assessment vocabulary, halt vocabulary, validation hints, atomic discipline, provenance trailers, graceful partial-state). Plus seamless pipeline: compact streaming progress + aggregate `<vault>/bolts/_summary.md` + propose-and-confirm halt UX (AI fix proposer for test_fail / hard_rule_violated / pbt_property_violated; user single-click approve) + auto-drift gate DEFAULT-ON after batch (~6x faster via shared snapshot reuse) + DRIFT-REPORT.md `## Suggested next actions` with auto-handoff commands + convergence loops bridge bolt halts. New halts: dispatch_prompt_too_large, bolt_repeated_partial_failure, provenance_missing, self_assessment_missing, bolt_introduces_locked_drift

## Anti-hallucination defense (13 layers)

1. **Intent** — uncertain claims promote to Open Questions
2. **OQ classification** — business vs tech; tech auto-resolves
3. **Binding gate** — CONFLICT blocks
4. **Implementation state** — IMPLEMENTED / NEW / PARTIAL_FIELDS_MISSING / UNKNOWN
5. **Unit grounding** — target_files whitelist + acceptance_test + Anchors
6. **Hard Rules pre/post-flight** — ast-grep validates at bolt time
7. **AST-precise extraction** — tree-sitter (Aider pattern)
8. **Memory** — suggestion-only with audit log
9. **Drift detection** — code vs vault reconciliation
10. **Interface lock** — cross-squad consumed interfaces must be locked
11. **Mutability tier classification** — [LOCKED]/[INTENT]/[ARTIFACT] orthogonal to confidence (Iter 22)
12. **Constitution layer** — project invariants enforced as Hard Rules at bolt time (Iter 17)
13. **Framework convention packs** — laravel/django/rails/etc. conventions inject into Suggested Unit Hard Rules (Iter 23)

## Memory layer (v2.1+)

Three scopes of markdown + JSON memory persist context across sessions:

- `~/.mega-sdd/memory/` — USER (opt-in, cross-project)
- `<project>/.mega-sdd/memory/` — PROJECT (per-repo, git-trackable per-file)
- `<vault>/.memory/` + `<vault>/.internal/checkpoints/` — VAULT (per-vault, ephemeral)

Self-learning via threshold-based suggestions reviewed through `/mega-sdd:memory review`. Never auto-applied. Mandatory audit log + rollback path. Complementary to Claude Code's `auto memory`.

## Reuse-stable tooling (Iter 14)

Mega-sdd ADOPTS stable native binaries instead of building from scratch (all OPTIONAL with graceful fallback):

| Tool | Used by | Fallback |
|---|---|---|
| `tree-sitter` | scan-codebase (AST extraction) | regex |
| `ast-grep` | execute-bolts (Hard Rules v2) | v1 5-type grammar |
| `ripgrep` (`rg`) | scan-codebase / detect-drift / bind-codebase / lint-units | GNU grep |
| `jd` | diff-vault (canonical JSON/YAML patches) | manual Read+compare |
| `markdownlint-cli2` | lint-units (vault prose) | skill-internal heuristics |
| `gh` (GitHub CLI) | optional PR automation | manual PR by user |

See [`references/tooling-install.md`](./references/tooling-install.md) for one-command install per platform.

See the [root README](../../README.md) for diagrams, full command table, halt protocol, autonomy mechanics, migration guide.

## Contributing

Read [`CLAUDE.md`](./CLAUDE.md) first if you're an AI agent submitting a PR — anti-slop protocol applies. Every behavior change traces back to a spec doc in [`../../docs/superpowers/specs/`](../../docs/superpowers/specs/).

For human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md). Tree-sitter `.scm` query patterns adapted from [Aider](https://github.com/Aider-AI/aider) (Apache 2.0) — see `skills/scan-codebase/queries/`.
