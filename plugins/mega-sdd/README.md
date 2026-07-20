# mega-sdd

Spec-driven AI development pipeline for [Claude Code](https://claude.com/claude-code). PRD or idea → vault → atomic units → tested commits, with anti-hallucination at every handoff.

**Version:** 5.2.1 · **License:** MIT

> **This page's job**: per-command reference + plugin internals (defense layers, memory, config, native tools). Install/update + orientation → root [`../../README.md`](../../README.md) · walkthroughs → [`../../tests/scenarios/`](../../tests/scenarios/) · version history → [`../../CHANGELOG.md`](../../CHANGELOG.md).

## Install / update

Canonical install, update, and uninstall instructions live in the **[root README — Quick start](../../README.md#quick-start-5-minutes)**. TL;DR (typed inside the Claude Code chat, not your shell): add the marketplace, `/plugin install mega-sdd`, optionally `/mega-sdd:install-deps` — then in any project:

```
/mega-sdd ./prd.md
```

Never used Claude Code itself? Start with [Scenario 0 — Zero to first run](../../tests/scenarios/scenario-0-zero-to-first-run.md).

## Commands you'll actually use

`/mega-sdd` is the headline — it runs the whole pipeline autonomously with one upfront confirmation (no arg = status view + proposed next chain). `/mega-sdd:sync` reconciles after out-of-pipeline changes; `/mega-sdd:emit <prd|fsd|sit>` emits the three team documents. The pre-v5 stage commands below still resolve as 5.x deprecation aliases.

| Command | What it does |
|---|---|
| `/mega-sdd <input>` | **The one command** — routes a PRD / idea / legacy path through the full pipeline end-to-end |
| `/mega-sdd:sync` | **The other one** — after ANY out-of-pipeline change (manual edit, AI edit, hotfix, `git pull`): incremental re-scan → drift → re-bind → unit reconcile. `--auto` = one confirmation, zero mid-chain questions |
| `/mega-sdd:emit <prd\|fsd\|sit>` | The three team documents (PRD / Confluence FSD / SIT) emitted from vault/units/bolts state; no arg lists them with maturity |
| `/mega-sdd:install-deps` | OS-aware install of the optional native tools |
| `/mega-sdd:update-plugin` | Pull the latest plugin version (then `/plugin marketplace update mega-sdd` + `/reload-plugins` to activate) |
| `/mega-sdd:memory review` | Review what mega-sdd learned across runs (accept / reject) |
| **Manual stage entry points — 5.x deprecation aliases (keep resolving; print a one-line notice)** | |
| `/mega-sdd:generate-intent <prd>` | PRD or idea → vault (entities, flows, decisions, open questions) |
| `/mega-sdd:scan-codebase [path]` | AST-scan an existing repo → `codebase-map.md` |
| `/mega-sdd:bind-codebase <vault>` | Validate vault claims against the real code → CONFIRMED / CONFLICT / OQ |
| `/mega-sdd:generate-units <vault>` | Vault → atomic, grounded work units |
| `/mega-sdd:execute-bolts --all` | Units → tested commits (fresh subagent + spec & code review per unit) |
| `/mega-sdd:resolve-oq <vault>` | Walk the open questions interactively |
| `/mega-sdd:detect-drift` | Compare committed code against the vault |
| `/mega-sdd:analyze` | One consistency report across all artifacts |
| `/mega-sdd:extract-intelligence <legacy>` | Legacy codebase → knowledge base (the rebuild lane) |

Full surface: **3 public verbs + 4 maintenance one-timers**; the other 24 files in [`commands/`](./commands/) are deprecation aliases that keep resolving through the whole 5.x cycle. Run any command with no args to see its usage.

## First time? Start with a scenario

The full chooser table (13 guided walkthroughs with copy-paste inputs + expected outputs) lives in **[`tests/scenarios/README.md`](../../tests/scenarios/README.md)**. Most common entry points: [Scenario 0 — Zero to first run](../../tests/scenarios/scenario-0-zero-to-first-run.md) (never used Claude Code) · [Scenario 1 — Greenfield from idea](../../tests/scenarios/scenario-1-greenfield-from-idea.md) · [Scenario 12 — Continuous sync](../../tests/scenarios/scenario-12-continuous-sync.md) (code changed after "done").

A canonical example PRD (the standard frontmatter + `§`-section format) lives at [`../../tests/scenarios/sample-prd-clinic.md`](../../tests/scenarios/sample-prd-clinic.md); the blank template is [`../../docs/templates/prd-template.md`](../../docs/templates/prd-template.md).

## The pipeline

```
[legacy → extract-intelligence] → PRD/idea → generate-intent → (scan + bind, brownfield) → generate-units → execute-bolts → emit-agents-md / emit-fsd
```

`/mega-sdd` wraps all of it: single upfront confirmation, diagnostics (lint / analyze / drift) auto-invoked at the right phases, halt-protocol preserved throughout. Brownfield runs insert `scan-codebase` + `bind-codebase`; the legacy-rebuild lane starts from `extract-intelligence`.

**And it loops.** Development never actually ends — so after the pipeline "finishes", every out-of-pipeline change (a manual hotfix, an AI-prompted edit in any session, a `git pull`) is captured ambiently (a PostToolUse journal + the map's git stamp), surfaced as a one-line session-start notice, and reconciled by `/mega-sdd:sync`:

```
code moves (any way) → system notices → /mega-sdd:sync [--auto]
  → scan --changed-only → drift (scoped) → bind --paths → units --reconcile → bolts (stale/new only)
  → SYNC-REPORT.md (+ PENDING-SYNC.md queue for the decisions only a human may make) → repeat forever
```

Under `--auto`: one upfront confirmation, zero mid-chain questions — human-required decisions (drift direction calls, vault patches, CONFLICTs) are QUEUED, never auto-resolved. Walkthrough: [scenario 12](../../tests/scenarios/scenario-12-continuous-sync.md) · design: [`living-vault spec`](../../docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md).

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest (version SSOT)
├── skills/                       # 19 skills — lean routers + progressive disclosure (each SKILL.md ≤500 lines)
│   ├── using-mega-sdd/           # anchor skill (auto-injected at session start)
│   ├── extract-intelligence/  generate-intent/  scan-codebase/  bind-codebase/
│   ├── generate-units/  execute-bolts/          # the core pipeline
│   ├── orchestrate-flow/  resolve-oq/  detect-drift/  diff-vault/  analyze/  graph/
│   ├── memory/  emit-agents-md/  emit-prd/  emit-fsd/  emit-sit/  install-deps/
│   └── _vendored/                # superpowers fallback (optional technique skills)
├── agents/                       # 8 first-class subagents
│   ├── bolt-implementer.md       # execute-bolts implementer
│   ├── spec-reviewer.md, code-quality-reviewer.md, security-reviewer.md, standards-reviewer.md, design-reviewer.md
│   │                             #   ↳ the execute-bolts review panel (parallel blind lenses, risk-tiered; design joins for UI-bearing units)
│   ├── domain-extractor.md       # extract-intelligence wave worker
│   └── phase-advisor.md          # adversarial second-opinion at the bind/intent gates
├── commands/                     # 3 public verbs (mega-sdd · sync · emit) + 4 maintenance one-timers + 24 deprecation aliases (resolve through 5.x)
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
3. **Binding gate** — unresolved CONFLICTs (and CONFLICT *resolution*) block downstream generation
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
19. **Living-vault sync invariants** — incremental re-bind NEVER carries an active CONFLICT forward silently (always re-validated; moat-test-pinned); autonomous sync defers human decisions to a queue instead of deciding them; drift write-back requires git provenance + explicit ACCEPT, and `[LOCKED]` claims are never patched from code

> The doctrine: **a blocking gate is a deterministic validator wired to a hook — prose that says "HALT" enforces nothing.** Which gates hard-block vs. advise is defined in [`CLAUDE.md`](./CLAUDE.md); `/mega-sdd:analyze` surfaces the advisory ones.

## Memory

Three scopes of markdown + JSON memory persist context across sessions (complementary to Claude Code's own memory):

- `~/.mega-sdd/memory/` — **USER** (opt-in, cross-project)
- `<project>/.mega-sdd/memory/` — **PROJECT** (per-repo, git-trackable per file)
- `<vault>/.memory/` — **VAULT** (per-vault, ephemeral)

Self-learning via threshold-based suggestions, reviewed through `/mega-sdd:memory review`. **Never auto-applied** — mandatory audit log + rollback path. Disable with `--memory-off`.

## Per-project config

Optional `.mega-sdd/config.yaml` at the project root — every key has a default (missing file = all defaults, never an error):

```yaml
telemetry: true          # false → PostToolUse hook fully off for this project
dirty_journal: true      # false → living-vault journaling off (git channel still covers sync)
staleness_notice: true   # false → suppress the session-start "codebase moved" line
layout: canonical        # legacy → pre-v3.4 output paths
```

Full key reference + scope table (user / project / vault): [`references/project-config.md`](./references/project-config.md). Safe to commit (no secrets by design) or gitignore for per-developer preferences.

## Optional native tools

Mega-sdd adopts stable native binaries instead of reinventing them — all optional, each with a graceful fallback. `/mega-sdd:install-deps` installs them for you (see [Install / update](#install--update)).

| Tool | Used by | Fallback |
|---|---|---|
| `tree-sitter` | scan-codebase (AST extraction) | regex engine (lower precision) |
| `ast-grep` | execute-bolts / generate-units (Hard Rules v2) | v1 5-type grammar |
| `ripgrep` (`rg`) | scan-codebase (structured JSON grep) | GNU grep |
| `jd` | diff-vault (canonical JSON/YAML patches) | manual Read+compare |
| `pandoc` | emit-fsd / emit-prd / emit-sit (PDF rendering) | Markdown-only output |
| `mmdc` | emit lanes — mermaid→SVG for the md2pdf PDF (Chrome-print, GitHub style) | mermaid stays code |
| Google Chrome | emit lanes — the PDF printer (detect-only, not installed) | GitHub-styled HTML fallback |
| `markdownlint-cli2` | lint-units (vault prose) | skill-internal heuristics |
| `semgrep` | execute-bolts L0 code gate 4 (SAST on bolt diffs) | gate SKIPs with a note |
| `gitleaks` | execute-bolts L0 code gate 3 (secret scan) | plugin regex fallback (always scanned) |

Full per-platform install matrix + **platform support table** (macOS/Linux/WSL = full; Git Bash = works with a `python3` shim; native cmd = prose-only, not recommended): [`references/tooling-install.md`](./references/tooling-install.md). Running the gates in CI / headless (`claude -p`, claude-code-action, pure-script exit-code gates): [`references/ci-recipe.md`](./references/ci-recipe.md).

## What's new

**v5.2.1** — *Hook recovery + fork headless caveat:* an interrupted run's hook-driven recovery now routes to `/mega-sdd --resume` (the front door); the `context: fork` headless caveat is documented — under `claude -p` a forked skill silently runs inline (no token win, telemetry dark), while PreToolUse gates + SessionStart still fire, so scripted/CI usage stays gate-safe.
**v5.2.0** — *Dependency authorization:* execute-bolts code gate 6 — a bolt that adds a dependency the unit's `allowed_new_deps` did not sanction is flagged `dep_unauthorized` (advisory-first, deterministic).
**v5.0.0** — *Surface collapse:* the public surface became three verbs (`/mega-sdd` · `/mega-sdd:sync` · `/mega-sdd:emit`); the 24 former stage commands became deprecation aliases that keep resolving through the whole 5.x cycle.

Everything older → [`../../CHANGELOG.md`](../../CHANGELOG.md) (the single source of release history).

## Contributing

If you're an AI agent submitting a PR, read [`CLAUDE.md`](./CLAUDE.md) first — the anti-slop protocol applies and every behavior change must trace to a spec in [`../../docs/superpowers/specs/`](../../docs/superpowers/specs/). Human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md). Tree-sitter `.scm` query patterns adapted from [Aider](https://github.com/Aider-AI/aider) (Apache 2.0) — see `skills/scan-codebase/queries/`.
