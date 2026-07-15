<div align="center">

# mega-sdd

### Spec-driven AI development pipeline. One command. Working code.

*PRD or idea → vault → atomic units → tested commits. With anti-hallucination at every handoff, persistent memory across sessions, and AST-precise grounding.*

**Plugin:** `mega-sdd` · **Version:** 4.70.0 · **License:** MIT

</div>

---

> **This page's job**: orient you and get you to a first successful run. Per-command reference + plugin internals → [`plugins/mega-sdd/README.md`](plugins/mega-sdd/README.md) · guided walkthroughs → [`tests/scenarios/`](tests/scenarios/README.md) · version history → [`CHANGELOG.md`](CHANGELOG.md).

## 30-second pitch

```bash
/mega-sdd:auto ./prd.md
```

That's it. Mega-sdd runs the full pipeline: parse PRD → scan codebase → bind claims → generate atomic units → execute bolts via TDD → commit code. Single upfront confirmation; auto-continues unless something needs human input.

And when the code moves on afterwards (manual hotfix, AI edit in any session, `git pull`) — `/mega-sdd:sync` catches everything up incrementally. Development never ends; neither does the pipeline.

**Never used Claude Code at all?** → [Start from zero](#start-from-zero-never-used-claude-code) (10 min).
**For the new user**: skip to [Quick start](#quick-start-5-minutes) below.
**For the technical reader**: see [Architecture deep dive](#architecture-deep-dive) collapsed below.

---

## Start from zero (never used Claude Code?)

Mega-sdd is a plugin for [Claude Code](https://claude.com/claude-code) — Anthropic's AI coding agent that runs in your terminal. If you've never installed or tried Claude Code, you only need three things before anything on this page applies:

1. **Install Claude Code** (one command in your terminal — official guide: <https://code.claude.com/docs/en/quickstart>):

   ```bash
   curl -fsSL https://claude.ai/install.sh | bash    # macOS / Linux / WSL
   # or: npm install -g @anthropic-ai/claude-code    # if you have Node.js 18+
   ```

2. **Start it in a project folder** — run `claude` inside any directory. First launch walks you through logging in with a Claude account (Pro/Max subscription or Console API billing).

3. **Know the one convention**: inside the Claude Code session, anything starting with `/` is a command. Every `/plugin …` and `/mega-sdd:…` snippet in this README is typed **inside the Claude Code chat**, not in your shell.

That's genuinely all the Claude Code knowledge mega-sdd assumes. For a hand-held, nothing-assumed walkthrough (install → login → plugin → first run, ~20 min), follow **[Scenario 0 — Zero to first run](tests/scenarios/scenario-0-zero-to-first-run.md)**.

<details>
<summary><b>📖 New to the jargon? Plain-language glossary</b></summary>

| Term | Plain meaning |
|---|---|
| **PRD** | A requirements document — "what we want built". Mega-sdd accepts one, or just a sentence. |
| **Vault** | The structured spec mega-sdd writes from your PRD/idea, every claim cited to its source. |
| **Open Question (OQ)** | Anything the spec can't prove becomes a question for you — never a silent guess. |
| **Binding** | Checking the spec against your *real* code before any task is generated (existing projects). |
| **Unit** | One small, well-defined task — about one pull request of work. |
| **Bolt** | An executed unit: code + passing tests, committed to git. |
| **Halt** | A deliberate safety pause when something genuinely needs a human; resume with `--resume`. |
| **Greenfield / brownfield** | New empty project / existing codebase. |

</details>

---

## Quick start (5 minutes)

### 1. Install

This is the canonical install reference — other docs link here.

```bash
# In Claude Code:
/plugin marketplace add https://scm.bankmegadev.com/ai-rnd/mega-sdd.git
/plugin install mega-sdd
/plugin install superpowers   # recommended companion (TDD discipline)
```

For higher precision (optional, recommended), let the OS-aware installer set up the native binaries for you:

```bash
/mega-sdd:install-deps
```

It detects your OS + package manager and installs `tree-sitter`, `ast-grep`, `ripgrep`, `jd`, `pandoc`, `tectonic` with safety rails (never auto-sudo, never `curl|bash`, always verify). Every tool is optional — mega-sdd has a graceful fallback for each. Tool-by-tool table: [plugin README](plugins/mega-sdd/README.md#optional-native-tools); manual per-platform one-liners (incl. Windows): [`tooling-install.md`](plugins/mega-sdd/references/tooling-install.md).

### 2. Keep it updated

```bash
/mega-sdd:update-plugin                          # pull the latest plugin from the marketplace repo (fast-forward only)
/plugin marketplace update mega-sdd              # rebuild the plugin cache to the new version
```

Then run `/reload-plugins` (or restart Claude Code) so new commands + skills register. `/mega-sdd:update-plugin` reports the before→after version, never touches your project, and tells you if you're already current. Your installed version shows in the header above and in `/plugin`.

To uninstall: `/plugin uninstall mega-sdd` (and optionally `/plugin marketplace remove mega-sdd`). Your `.mega-sdd/` outputs stay in your project — delete that folder if you want them gone too.

### 3. Try a guided scenario

The full scenario chooser (13 walkthroughs, each with copy-paste inputs, expected outputs, and pitfalls + recovery) lives in **[`tests/scenarios/README.md`](tests/scenarios/README.md)**. Three common entry points:

- Never used Claude Code → [Scenario 0 — Zero to first run](tests/scenarios/scenario-0-zero-to-first-run.md) (20 min)
- Want the minimum viable demo → [Scenario 1 — Greenfield from idea](tests/scenarios/scenario-1-greenfield-from-idea.md) (15 min)
- Have a PRD + an existing project → [Scenario 2 — PRD-driven feature](tests/scenarios/scenario-2-prd-driven-feature.md) (30 min)

A sample PRD to match expected outputs exactly: [`sample-prd-clinic.md`](tests/scenarios/sample-prd-clinic.md).

### 4. Common invocations

```bash
/mega-sdd:auto ./prd.md                   # PRD → working code (5 phases)
/mega-sdd:auto ./legacy-php/ --out=./new/ # Legacy KB → vault → code (6 phases)
/mega-sdd:auto "build a clinic system"    # Free-text brief → code (3 phases)
/mega-sdd:auto                            # CWD-driven (inspect state, propose chain)
/mega-sdd:auto --resume                   # Continue paused/halted chain
```

Single confirmation. Auto-continues clean phases. Halts surface YAML blockers with a `next_action` field — exactly what to run to recover.

---

## Why mega-sdd

> **Without it**: PRD → "build this" handoff → AI agent invents entities/files/patterns → drift cascades → expensive rework.
> **With it**: PRD → intent vault (cited claims) → bound to live codebase (AST precise) → atomic units shaped as polished prompts → bolts via TDD with pre/post-flight Hard Rule validation → memory accumulates across runs → drift detected early.

Every handoff is contracted and grounded. The six layers that matter most:

1. **Uncertain claims become Open Questions** — anything the spec can't prove from its sources is promoted to a question for you, never a guess.
2. **The binding gate blocks** — vault claims are validated against the live codebase; unresolved CONFLICTs stop the pipeline before any code is generated.
3. **Units are grounded** — `target_files` whitelist + a mandatory acceptance test + anchors citing real code patterns.
4. **Hard Rules are enforced, not suggested** — ast-grep validates constraints at bolt time, wired to deterministic hooks. The doctrine: *prose that says HALT enforces nothing.*
5. **Handoffs are typed contracts** — every cross-phase handoff YAML is schema- and type-validated at the producer side, so shape drift halts the moment it happens.
6. **Memory never acts alone** — learning across runs is suggestion-only (explicit ACCEPT), with a mandatory audit log + rollback; drift detection reconciles code vs spec early.

The full defense in depth (19 layers, including the code-delivery quality gates): [plugin README — How it prevents hallucination](plugins/mega-sdd/README.md#how-it-prevents-hallucination).

## What makes mega-sdd special

Most AI-dev tools take a PRD → spit code in one shot. **Mega-sdd inserts structured intermediate artifacts** (vault → binding → units → bolts) so every layer is auditable, every handoff is contracted, and the AI agent has explicit constraints to respect at each step.

- **One command, full pipeline** — `/mega-sdd:auto` runs PRD → vault → binding → units → tested commits with a single upfront confirmation; halts carry the exact recovery command.
- **Smart orchestrator** — memory-driven routing (after 3+ successful runs of your project shape it recommends the proven chain) + predictive preflight (catches `dep_missing` *before* the chain starts, not 8 minutes in).
- **Starterkit-aware** — auto-detects your stack's actual conventions (auth lib, RBAC, UI stack, layouts) and generates units that cite *your* patterns, so bolts match your codebase by default.
- **Memory that learns across sessions** — three scopes (user / project / vault), suggestion-only via `/mega-sdd:memory review`, mandatory audit log + rollback, `--memory-off` honored.
- **Audit-driven evolution** — every major version closes a structured, severity-classified audit; nothing hidden, nothing inflated. Full trail: [`CHANGELOG.md`](CHANGELOG.md) + [`plugins/mega-sdd/AUDIT.md`](plugins/mega-sdd/AUDIT.md) + [`docs/superpowers/audits/`](docs/superpowers/audits/).
- **A living pipeline, not a one-shot run** — out-of-pipeline changes (manual hotfix, AI edit, `git pull`) are captured ambiently and `/mega-sdd:sync` reconciles only what changed, queuing human-only decisions instead of guessing. Walkthrough: [scenario 12](tests/scenarios/scenario-12-continuous-sync.md).

**TL;DR**: if you've ever had an AI agent invent a function that doesn't exist, hallucinate a database column, or "implement" a feature that doesn't compile — mega-sdd's pipeline structure prevents those failure modes upstream. You get an AI development workflow that's been hardened against the actual ways AI agents drift.

---

## Pipeline overview

```mermaid
flowchart TD
    %% Inputs
    LEG([📦 Legacy codebase]):::input
    PRD([📄 PRD / brief / Figma]):::input
    CODE([💻 Existing code]):::input

    %% Optional KB extraction branch
    LEG -->|extract-intelligence| KB[(🧠 knowledge-base/<br/>tech-agnostic markers<br/>via domain-extractor agents)]:::artifact

    %% Intent generation
    KB -.->|--kb| INT
    PRD --> INT[generate-intent<br/>+ OQ auto-classifier]:::phase
    INT --> VAULT[(📚 vault/<br/>7 .md + vault.json<br/>OQs: business / tech)]:::artifact

    %% OQ gate
    VAULT --> OQGATE{P1 business<br/>OQs pending?}:::decision
    OQGATE -->|yes| RESOLVE[resolve-oq<br/>+ recommendations]:::phase
    RESOLVE -.-> VAULT
    OQGATE -->|no| MODE{brownfield<br/>or greenfield?}:::decision

    %% Brownfield path
    MODE -->|brownfield| SCAN
    CODE --> SCAN[scan-codebase<br/>🌲 tree-sitter AST<br/>+ deep-scan stage]:::phase
    SCAN --> MAP[(🗺️ codebase-map.md<br/>precision: ast)]:::artifact
    SCAN --> STARTERKIT[(📐 starterkit-context.yaml<br/>auth · authz · ui_ux · libs · reuse<br/>5 parallel subagents)]:::artifact
    MAP --> BIND[bind-codebase<br/>CONFIRMED / CONFLICT / OQ<br/>+ impl-state + Suggested Hard Rules]:::phase
    VAULT --> BIND
    BIND --> BGATE{CONFLICT?}:::decision
    BGATE -->|blocks units| RESOLVE
    BGATE -->|clean| BOUND[(🔒 bound/<br/>+ binding.md)]:::artifact
    BOUND --> GEN

    %% Greenfield path
    MODE -->|greenfield| GEN[generate-units<br/>+ PageRank symbol-graph<br/>+ defensive checks]:::phase

    %% starterkit context flows into consumers
    STARTERKIT -.Anchors + Hard Rules with citations.-> GEN
    STARTERKIT -.T2 starterkit slice.-> BOLTS

    %% Units → bolts
    GEN --> UNITS[(⚙️ units/U-*.md<br/>atomic + Anchors<br/>+ Hard Rules ast-grep<br/>+ starterkit citations)]:::artifact
    UNITS --> HGATE{{🛡️ PreToolUse gate<br/>binding · flow-coverage · render-test<br/>sibling · ui-quality · cross-cutting}}:::gate
    HGATE -->|fail| UNITS
    HGATE -->|pass| BOLTS[execute-bolts controller<br/>--per-squad --parallel<br/>+ pre/post-flight Hard Rules]:::phase
    BOLTS --> IMPL[bolt-implementer agent<br/>TDD · writes code + tests]:::agent
    IMPL --> SREV[spec-reviewer agent<br/>spec compliance]:::agent
    SREV --> QREV[code-quality-reviewer agent]:::agent
    QREV --> COMMITS([✅ atomic git commits<br/>tests passing]):::output

    %% End-of-chain emissions
    COMMITS --> AGENTS[emit-agents-md]:::phase
    AGENTS --> AGENTSMD([📋 AGENTS.md<br/>tool-agnostic interop]):::output

    %% Cross-cutting layers
    MEMORY[(🧩 Memory layer<br/>user / project / vault)]:::cross
    MEMORY -.suggests / records.-> INT
    MEMORY -.-> BIND
    MEMORY -.-> RESOLVE
    MEMORY -.-> BOLTS

    %% Intelligence layer (orchestrator = smart router)
    ROUTING[(🧭 routing-outcomes.md<br/>chain learning)]:::intel
    PREDICT[\\📋 predictive-checks.md<br/>preflight catalog\\]:::intel
    GATE{{🛡️ Handoff validation gate<br/>REQUIRED + TYPE checks}}:::gate

    %% Orchestrator with intelligence layer
    AUTO([🚀 /mega-sdd:auto --deep<br/>single confirm + auto-continue<br/>+ checkpoints + smart routing]):::primary
    AUTO <-.reads + writes.-> ROUTING
    AUTO -.consults pre-invoke.-> PREDICT
    AUTO -.validates every handoff.-> GATE
    GATE -.invalid_handoff halt.-> AUTO
    AUTO -.orchestrates.-> INT
    AUTO -.orchestrates.-> SCAN
    AUTO -.orchestrates.-> BIND
    AUTO -.orchestrates.-> GEN
    AUTO -.orchestrates.-> BOLTS
    AUTO -.orchestrates.-> AGENTS

    %% Periodic
    COMMITS -.detect-drift.-> VAULT
    PRD -.diff-vault.-> VAULT

    classDef input fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a8a
    classDef phase fill:#d4f1f4,stroke:#0a7e8c,stroke-width:1.5px,color:#0c4a52
    classDef artifact fill:#fef3c7,stroke:#d97706,stroke-width:1.5px,color:#78350f
    classDef output fill:#d1fae5,stroke:#059669,stroke-width:2px,color:#064e3b
    classDef decision fill:#fff7ed,stroke:#ea580c,stroke-width:1.5px,color:#7c2d12
    classDef cross fill:#fafafa,stroke:#525252,stroke-width:1px,color:#262626
    classDef primary fill:#fef2f2,stroke:#dc2626,stroke-width:3px,color:#7f1d1d
    classDef intel fill:#f3e8ff,stroke:#7c3aed,stroke-width:1.5px,color:#4c1d95
    classDef gate fill:#ecfeff,stroke:#0891b2,stroke-width:2px,color:#164e63
    classDef agent fill:#e0e7ff,stroke:#4f46e5,stroke-width:1.5px,color:#312e81
```

**Legend**:
- 🟦 inputs (PRD, code, legacy) · 🟨 artifacts produced · 🟩 outputs · 🟧 decisions · 🟫 cross-cutting (memory) · 🟥 orchestrator
- 🟪 **intelligence layer**: routing-outcomes, predictive-checks · 🟦 **validation gate** (schema + type-check)
- 📐 **starterkit-context**: auto-detected feature inventory feeding both generate-units (Anchors+Rules) + execute-bolts (T2 slice)
- **Solid arrows** = pipeline flow · **Dotted arrows** = orchestration + cross-cutting + intelligence-layer consults

All phases auto-chain via `/mega-sdd:auto`. Each phase emits typed handoff YAML that the orchestrator validates (schema + types) before continuing; the intelligence layer consults past routing outcomes at chain start, runs predictive preflight before each skill, and records the run's outcome at chain end. Halts only on real issues (CONFLICT, P1 business OQ, Hard Rule violation, invalid handoff); auto-continues otherwise.

---

## Commands

`/mega-sdd:auto` is the only command most users type. `/mega-sdd:sync` is the second — run it after any out-of-pipeline change (manual edit, AI edit, hotfix, `git pull`). Everything else is either a manual phase entry point or auto-invoked by `auto`.

**Full per-command reference (all 27): [plugin README — Commands](plugins/mega-sdd/README.md#commands-youll-actually-use).** Task → command quick lookup:

<details>
<summary><b>📝 Procedure cheat-sheet</b></summary>

| Scenario | Commands |
|---|---|
| **One-shot end-to-end** (recommended) | `/mega-sdd:auto ./prd.md` · `/mega-sdd:auto ./legacy/ --out=./new/` · `/mega-sdd:auto "brief"` |
| Phase-by-phase greenfield | `/mega-sdd:generate-intent "your idea"` then `/mega-sdd:orchestrate-flow` |
| Phase-by-phase brownfield | `/mega-sdd:generate-intent ./prd.md` then `/mega-sdd:orchestrate-flow` |
| Legacy rebuild | `/mega-sdd:auto ./legacy/ --out=./rebuild/` |
| Unresolved P1 business OQs | `/mega-sdd:resolve-oq` |
| Bolt halted on Hard Rule | Review `<vault>/bolts/U-XXX/postflight.json`; revert OR edit unit's Hard rules; re-run unit |
| Resume after halt | `/mega-sdd:auto --resume` |
| Module-filtered execution | `/mega-sdd:execute-bolts --module=M-auth` |
| Squad-filtered execution | `/mega-sdd:execute-bolts --squad=squad-be` (multi-squad mode) |
| Per-squad parallel | `/mega-sdd:execute-bolts --per-squad --parallel` |
| Inspect memory | `/mega-sdd:memory show <topic>` |
| Review pending learning suggestions | `/mega-sdd:memory review` |
| Generate AGENTS.md manually | `/mega-sdd:emit-agents-md` (auto-runs at chain end by default) |
| Generate Confluence FSD manually | `/mega-sdd:emit-fsd` (auto-runs at chain end) |
| Install missing native deps (pandoc, tectonic, etc.) | `/mega-sdd:install-deps` (auto-detect OS + pkg mgr) |
| Update mega-sdd to the latest version | `/mega-sdd:update-plugin` then `/plugin marketplace update mega-sdd` |
| Migrate vault layout (one-time) | `/mega-sdd:migrate-paths --dry-run` then `/mega-sdd:migrate-paths` |
| Migrate Hard Rules grammar (one-time) | `/mega-sdd:migrate-rules ./vault` |
| Privacy-sensitive run | `/mega-sdd:auto ./prd.md --memory-off` |
| Disable auto-diagnostic flags | `/mega-sdd:auto ./prd.md --no-lint --no-analyze --no-modules-summary --no-agents-md --no-fsd` |
| PRD revision arrived | `/mega-sdd:diff-vault ./new-prd.md` |
| Code drift periodic check | `/mega-sdd:detect-drift` |

</details>

---

<details>
<summary><b>🏗️ Architecture deep dive</b></summary>

### Who · What · When · Where · Why · How

| | |
|---|---|
| **What** | Multi-phase pipeline: extract → intent → scan → bind → units → bolts. **17 skills** (lean routers + progressive disclosure — each `SKILL.md` ≤500 lines, detail in on-demand `references/`) + **8 first-class subagents** (`agents/`: bolt-implementer, spec-reviewer, code-quality-reviewer, security-reviewer, standards-reviewer, design-reviewer, domain-extractor, phase-advisor) + **27 slash commands** (your manual `/mega-sdd:` CLI entry points, one per pipeline step). |
| **Who** | **Architects** produce intent without repo access. **Devs / AI** scan + bind with read-only repo access. **AI agents** ship bolts with write access via superpowers. |
| **When** | After PRD signed off, brief captured, OR legacy codebase available. Replaces ad-hoc "build this" handoff with a structured contract surviving all the way to working code. |
| **Where** | All outputs consolidated under `<project>/.mega-sdd/`. User memory at `~/.mega-sdd/`. Project source unchanged. |
| **Why** | The architect/dev hallucination boundary is the #1 source of AI-dev rework. Mega-sdd inserts a mandatory binding gate + per-claim implementation-state classification + AST-validated Hard Rules + memory-driven suggestions that learn from past patterns without auto-applying them. |
| **How** | Layered anti-hallucination defense; execution via first-class bolt agents (two-stage review: spec compliance then code quality), with superpowers TDD as optional technique; halt-on-blocker protocol; deterministic tech (tree-sitter + ast-grep + ripgrep + jd); markdown-driven memory with mandatory audit log + rollback. |

### Folder layout

```
<project>/
├── .mega-sdd/                              # ALL mega-sdd outputs
│   ├── config.yaml                          # project-level config
│   ├── vaults/<slug>/                       # vault per project
│   │   ├── 00-index.md ... 06-constraints.md, vault.json
│   │   ├── binding.md, bound/, units/, bolts/
│   │   ├── _meta/squads.yaml, modules.yaml  # multi-squad + modules
│   │   ├── interfaces/                      # cross-squad contracts
│   │   ├── .memory/                         # vault-scope memory
│   │   └── .internal/                       # checkpoints + symbol-graph
│   ├── knowledge-base/                      # legacy KB (extract-intelligence)
│   ├── codebase/codebase-map.md             # scan output
│   ├── memory/                              # project memory
│   └── exports/                             # future tool-agnostic exports
├── AGENTS.md                                 # tool-agnostic interop (root)
├── CLAUDE.md                                 # project AI context (optional)
└── (project source: app/, routes/, src/, etc.)
```

User-scope: `~/.mega-sdd/memory/` (cross-project preferences + patterns).

### Halt protocol

Mega-sdd halts on real issues; never silent failures. Common halt types:

- `bind_conflict` — vault claim contradicts code
- `dedup_ambiguous` — create unit targets existing files
- `hard_rule_violated` — bolt modified locked code
- `hard_rule_unparseable` — Hard Rule grammar invalid
- `cross_squad_interface_draft` — consumer waiting for producer to lock interface
- `module_blocked_by` — prerequisite module incomplete
- `quality_gate_failed` — extract-intelligence wave failed twice
- `oq_recommend_underspecified` — recommendation missing required fields
- `memory_schema_mismatch` — memory file version differs

Each halt emits a YAML `blocker` with a `next_action` field. Resume via `/mega-sdd:auto --resume`.

Full halt protocol + recovery: [Scenario 6](tests/scenarios/scenario-6-recovery-from-halt.md).

### Versioning

- **Plugin**: SemVer; `plugin.json` is the single source of truth (`marketplace.json` matches it; the version badge at the top of this README mirrors it). Major bump for breaking renames, rails changes, or marketplace incompatibility. History: [`CHANGELOG.md`](CHANGELOG.md).
- **Skills**: Per-skill `version:` in frontmatter. Bump on any content change.
- **Vault**: Internal `version` in `vault.json`, increments on `diff-vault` and `resolve-oq` events.
- **Unit IDs**: Zero-padded (`U-001`), stable across regenerations.
- **Memory schema**: `memory_schema: N` stamped per file; auto-migrate via memory skill.

</details>

<details>
<summary><b>🤖 Autonomy Layer</b></summary>

Single-confirm pipeline-end execution with auto-continue, progress indication, CWD + mid-skill-checkpoint resume.

```bash
/mega-sdd:auto ./prd.md                    # detect → propose chain → confirm once → run
/mega-sdd:auto --resume                    # continue paused chain (CWD + checkpoint driven)
/mega-sdd:auto --step-after=bind-codebase  # manual handoff after binding
/mega-sdd:auto --shallow                   # opt-out of --deep (cap-3 default)
/mega-sdd:auto --manual                    # disable autonomy entirely
/mega-sdd:auto --memory-off                # disable memory layer
/mega-sdd:auto --no-lint                   # skip auto lint-units pass
/mega-sdd:auto --no-analyze                # skip auto analyze-parallelism
/mega-sdd:auto --no-agents-md              # skip auto AGENTS.md emit
/mega-sdd:auto --no-fsd                    # skip auto FSD emit
```

ONE upfront confirmation. Halts may re-engage user mid-chain (test failures, conflict resolutions, hard-rule violations). Otherwise silent + auto-progresses.

</details>

<details>
<summary><b>📦 Repository structure</b></summary>

```
.
├── .claude-plugin/marketplace.json         # marketplace manifest
├── plugins/mega-sdd/                       # the plugin itself
│   ├── README.md                           # per-command reference + plugin internals
│   ├── skills/                             # 17 skills (lean routers + progressive disclosure) + _vendored/
│   ├── agents/                             # 8 first-class subagents (incl. the blind review panel)
│   ├── commands/                           # 27 slash commands (manual /mega-sdd: CLI entry points)
│   ├── references/                         # paths.md · tooling-install.md · framework-conventions/ (22 packs)
│   ├── hooks/                              # SessionStart anchor · Hybrid PreToolUse gate · PostToolUse validators · Stop
│   ├── scripts/                            # sync-superpowers + migrations + validators
│   └── CLAUDE.md                           # AI-agent contributor guidelines
├── docs/superpowers/{specs,audits}/        # design specs + honest audits
├── tests/
│   ├── scenarios/                          # USER-FACING walkthroughs (scenario-0 … scenario-12 + sample PRD)
│   ├── skill-triggering/                   # per-skill trigger fixtures
│   ├── integration/                        # E2E pipeline tests
│   └── pack-kit/  per-stack-packs/         # framework-pack linter + coverage gates
├── CHANGELOG.md                            # full version history
├── CONTRIBUTING.md
└── LICENSE
```

</details>

---

## Contributing

See [`plugins/mega-sdd/CLAUDE.md`](plugins/mega-sdd/CLAUDE.md) for AI-agent contributor protocol — anti-slop PR requirements, anti-hallucination rail enforcement, skill edit policy, release process.

For human contributors: [`CONTRIBUTING.md`](CONTRIBUTING.md) — SDD invariants, testing guidelines, repository layout.

## License

MIT — see [`LICENSE`](LICENSE).

Vendored superpowers skills retain their original MIT license; see [`plugins/mega-sdd/skills/_vendored/ATTRIBUTION.md`](plugins/mega-sdd/skills/_vendored/ATTRIBUTION.md). Acknowledges [superpowers](https://github.com/obra/superpowers) by Jesse Vincent for plugin pattern inspiration. Tree-sitter `.scm` query patterns adapted from [Aider](https://github.com/Aider-AI/aider) (Apache 2.0).
