# mega-sdd

Spec-driven AI development pipeline for [Claude Code](https://claude.com/claude-code). PRD or idea → vault → atomic units → tested commits, with anti-hallucination at every handoff.

**Version:** 4.2.0 · **License:** MIT

> 📖 Deeper docs + walkthroughs: root [`../../README.md`](../../README.md) · scenarios [`../../tests/scenarios/`](../../tests/scenarios/) · full version history [`../../CHANGELOG.md`](../../CHANGELOG.md).

## Install

```
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers     # recommended companion (optional)
```

Then install the optional native binaries that boost precision — the skill does it for you, OS-aware:

```
/mega-sdd:install-deps
```

That detects your OS + package manager (brew / apt / dnf / pacman / winget / scoop / cargo / npm / go) and installs `tree-sitter`, `ast-grep`, `ripgrep`, `jd`, `pandoc`, `tectonic` with safety rails (never sudo-auto, never `curl|bash`, always verify). Every tool is **optional** — mega-sdd has a graceful fallback for each. Manual one-liners per platform: [`references/tooling-install.md`](./references/tooling-install.md).

Then, in any project:

```
/mega-sdd:auto ./prd.md
```

## Update

```
/mega-sdd:update-plugin                          # pull the latest plugin from the marketplace repo (fast-forward only)
/plugin marketplace update grand-design-spec     # rebuild the plugin cache to the new version
```

Then restart Claude Code (or reload the plugin) so the new commands + skills register. `/mega-sdd:update-plugin` reports the before→after version, never touches your project, and tells you if you're already current. Your installed version is shown in this header and in `/plugin`.

## Commands you'll actually use

`/mega-sdd:auto` is the headline — it runs the whole pipeline autonomously with one upfront confirmation. The rest are the same stages, drivable by hand.

| Command | What it does |
|---|---|
| `/mega-sdd:auto <input>` | **The one command** — routes a PRD / idea / legacy path through the full pipeline end-to-end |
| `/mega-sdd:generate-intent <prd>` | PRD or idea → vault (entities, flows, decisions, open questions) |
| `/mega-sdd:scan-codebase [path]` | AST-scan an existing repo → `codebase-map.md` |
| `/mega-sdd:bind-codebase <vault>` | Validate vault claims against the real code → CONFIRMED / CONFLICT / OQ |
| `/mega-sdd:generate-units <vault>` | Vault → atomic, grounded work units |
| `/mega-sdd:execute-bolts --all` | Units → tested commits (fresh subagent + spec & code review per unit) |
| `/mega-sdd:resolve-oq <vault>` | Walk the open questions interactively |
| `/mega-sdd:detect-drift` | Compare committed code against the vault |
| `/mega-sdd:analyze` | One consistency report across all artifacts |
| `/mega-sdd:extract-intelligence <legacy>` | Legacy codebase → knowledge base (the rebuild lane) |
| `/mega-sdd:emit-fsd` | Confluence-style FSD (PDF) generated from the vault |
| `/mega-sdd:install-deps` | OS-aware install of the optional native tools |
| `/mega-sdd:update-plugin` | Pull the latest plugin version |
| `/mega-sdd:memory review` | Review what mega-sdd learned across runs (accept / reject) |

Full set: **25 commands** in [`commands/`](./commands/) — one per pipeline step, each with an `argument-hint`. Run any of them with no args to see its usage.

## First time? Start with a scenario

| Scenario | When | Time |
|---|---|---|
| [Greenfield from idea](../../tests/scenarios/scenario-1-greenfield-from-idea.md) | Brand new; minimum viable demo | 15 min |
| [PRD-driven feature](../../tests/scenarios/scenario-2-prd-driven-feature.md) | Have a PRD; existing project | 30 min |
| [Field-level extension](../../tests/scenarios/scenario-3-field-extension.md) | Add a field to an existing model | 20 min |
| [Legacy rebuild](../../tests/scenarios/scenario-4-legacy-rebuild.md) | Legacy → new framework | 4 hours |
| [Multi-squad parallel](../../tests/scenarios/scenario-5-multi-squad-parallel.md) | Multi-team coordination | 45 min |
| [Recovery from halt](../../tests/scenarios/scenario-6-recovery-from-halt.md) | A bolt halted; recover cleanly | 15 min |

A canonical example PRD (the standard frontmatter + `§`-section format) lives at [`../../tests/scenarios/sample-prd-clinic.md`](../../tests/scenarios/sample-prd-clinic.md); the blank template is [`../../docs/templates/prd-template.md`](../../docs/templates/prd-template.md).

## The pipeline

```
[legacy → extract-intelligence] → PRD/idea → generate-intent → (scan + bind, brownfield) → generate-units → execute-bolts → emit-agents-md / emit-fsd
```

`/mega-sdd:auto` wraps all of it: single upfront confirmation, diagnostics (lint / analyze / drift) auto-invoked at the right phases, halt-protocol preserved throughout. Brownfield runs insert `scan-codebase` + `bind-codebase`; the legacy-rebuild lane starts from `extract-intelligence`.

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest (v4.2.0)
├── skills/                       # 16 skills — lean routers + progressive disclosure (each SKILL.md ≤500 lines)
│   ├── using-mega-sdd/           # anchor skill (auto-injected at session start)
│   ├── extract-intelligence/  generate-intent/  scan-codebase/  bind-codebase/
│   ├── generate-units/  execute-bolts/          # the core pipeline
│   ├── orchestrate-flow/  resolve-oq/  detect-drift/  diff-vault/  analyze/
│   ├── memory/  emit-agents-md/  emit-fsd/  install-deps/
│   └── _vendored/                # superpowers fallback (optional technique skills)
├── agents/                       # 4 first-class subagents
│   ├── bolt-implementer.md, spec-reviewer.md, code-quality-reviewer.md   # execute-bolts two-stage review
│   └── domain-extractor.md       # extract-intelligence wave worker
├── commands/                     # 25 slash commands — your manual /mega-sdd: CLI entry points
├── references/                   # paths.md (canonical layout), framework-conventions/, tooling-install.md, …
├── hooks/                        # SessionStart anchor · Hybrid PreToolUse gate · PostToolUse validators · Stop
├── scripts/                      # /analyze engine (run-analyze.sh) + validators + sync scripts
├── CLAUDE.md                     # AI-agent contributor guide (contracts + invariants)
└── LICENSE
```

## How it prevents hallucination

Mega-sdd's reason for existing is that it **won't let an agent invent what isn't grounded**. Defense is layered across every handoff — uncertain claims become Open Questions, never guesses; the binding gate blocks on unresolved CONFLICTs; units carry a `target_files` whitelist + acceptance test + cited anchors; Hard Rules are AST-validated at bolt time. The full defense in depth:

1. **Intent** — uncertain claims promote to Open Questions
2. **OQ classification** — business vs tech; tech auto-resolves with cited evidence
3. **Binding gate** — unresolved CONFLICTs (and CONFLICT *resolution*, v4.2) block downstream generation
4. **Implementation state** — IMPLEMENTED / NEW / PARTIAL_FIELDS_MISSING / UNKNOWN per claim
5. **Unit grounding** — `target_files` whitelist + acceptance_test + cited Anchors
6. **Hard Rules pre/post-flight** — ast-grep validates constraints at bolt time
7. **AST-precise extraction** — tree-sitter (no regex guessing of structure)
8. **Memory** — suggestion-only, with a mandatory audit log
9. **Drift detection** — committed code reconciled against the vault
10. **Interface lock** — cross-squad consumed interfaces must be locked
11. **Mutability tiers** — `[LOCKED]/[INTENT]/[ARTIFACT]`, orthogonal to confidence
12. **Constitution layer** — project invariants enforced as Hard Rules at bolt time
13. **Framework convention packs** — stack conventions inject into Suggested Unit Hard Rules
14. **Predictive preflight** — upcoming halts surfaced *before* a skill runs
15. **Handoff schema validation** — handoff YAML type-checked at emission
16. **Code-delivery quality gates** — tech-agnostic validators (flow-coverage, sibling-consistency, cross-cutting registration, render-test, ui-quality) hard-block `execute-bolts`; signatures from the framework pack, SKIP off-stack
17. **Pipeline-intelligence gates** — fan-out parity, UI-deferral, the de-vacuoused conflict-classification gate, a typed `next_action.confidence`
18. **Semantic-depth fidelity** — a multi-step workflow's staged inputs must survive the KB→vault handoff, or `execute-bolts` is blocked

> The doctrine: **a blocking gate is a deterministic validator wired to a hook — prose that says "HALT" enforces nothing.** Which gates hard-block vs. advise is defined in [`CLAUDE.md`](./CLAUDE.md); `/mega-sdd:analyze` surfaces the advisory ones.

## Memory

Three scopes of markdown + JSON memory persist context across sessions (complementary to Claude Code's own memory):

- `~/.mega-sdd/memory/` — **USER** (opt-in, cross-project)
- `<project>/.mega-sdd/memory/` — **PROJECT** (per-repo, git-trackable per file)
- `<vault>/.memory/` — **VAULT** (per-vault, ephemeral)

Self-learning via threshold-based suggestions, reviewed through `/mega-sdd:memory review`. **Never auto-applied** — mandatory audit log + rollback path. Disable with `--memory-off`.

## Optional native tools

Mega-sdd adopts stable native binaries instead of reinventing them — all optional, each with a graceful fallback. `/mega-sdd:install-deps` installs them for you (see [Install](#install)).

| Tool | Used by | Fallback |
|---|---|---|
| `tree-sitter` | scan-codebase (AST extraction) | regex engine (lower precision) |
| `ast-grep` | execute-bolts / generate-units (Hard Rules v2) | v1 5-type grammar |
| `ripgrep` (`rg`) | scan-codebase / bind-codebase / detect-drift / lint-units | GNU grep |
| `jd` | diff-vault (canonical JSON/YAML patches) | manual Read+compare |
| `pandoc` | emit-fsd (FSD PDF rendering) | Markdown-only output |
| `tectonic` | emit-fsd (LaTeX engine for PDF) | HTML → browser print-to-PDF |
| `markdownlint-cli2` | lint-units (vault prose) | skill-internal heuristics |
| `gh` | execute-bolts (optional PR automation) | manual PR by user |

Full per-platform install matrix (incl. Windows): [`references/tooling-install.md`](./references/tooling-install.md).

## What's new

**v4.2.0** — *Moat audit:* the binding→units gate now enforces CONFLICT **resolution**, not just ID propagation (an unresolved-but-cited CONFLICT no longer slips the gate); audit trail in [`AUDIT.md`](./AUDIT.md). Plus Windows `install-deps` coverage for scoop-native tools.
**v4.1.0** — UI/UX design intelligence distilled into the pipeline (grounded design recommendation at intent-time, design-system injection at bolt-time).
**v4.0.0** — lean-core: skills slimmed to routers + progressive disclosure, Hybrid hook enforcement, first-class `agents/`.

**Full version history → [`../../CHANGELOG.md`](../../CHANGELOG.md).**

## Contributing

If you're an AI agent submitting a PR, read [`CLAUDE.md`](./CLAUDE.md) first — the anti-slop protocol applies and every behavior change must trace to a spec in [`../../docs/superpowers/specs/`](../../docs/superpowers/specs/). Human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md). Tree-sitter `.scm` query patterns adapted from [Aider](https://github.com/Aider-AI/aider) (Apache 2.0) — see `skills/scan-codebase/queries/`.
