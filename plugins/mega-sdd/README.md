# mega-sdd

Spec-Driven Development plugin for [Claude Code](https://claude.com/claude-code). Intent → Unit → Bolt pipeline with anti-hallucination at every handoff, persistent memory across sessions, AST-precise codebase analysis (tree-sitter), and AST-validated Hard Rules (ast-grep). Plus the Autonomy Layer (`/mega-sdd:auto`) that runs end-to-end with single upfront confirmation.

**Version:** 3.0.0 · **License:** MIT

> 📖 **Full documentation lives at the repo root.** See [`../../README.md`](../../README.md) for TL;DR, 5W1H, full command reference, 10-layer anti-hallucination defense, Autonomy Layer + Memory Layer + Tech Upgrades details, migration guide, halt protocol, and architecture deep dive.

## Quick start

```bash
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended companion

# Optional native binaries for v3.0 tech upgrades (graceful regex/v1 fallback if absent):
brew install tree-sitter ast-grep
# OR
cargo install tree-sitter-cli ast-grep
```

Then in any project:

```bash
/mega-sdd:auto ./prd.md                   # one-shot end-to-end (recommended)
# OR
/mega-sdd:orchestrate-flow                # phase-by-phase router (cap-3 default)
```

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest (v3.0.0)
├── skills/                       # 12 skills + _vendored/
│   ├── using-mega-sdd/           # anchor skill (v1.2; sharper auto-trigger)
│   ├── memory/                   # NEW v1.0 — memory + self-learning operations (Iter 5)
│   ├── emit-agents-md/           # NEW v1.0 — AGENTS.md emitter (Iter 6)
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.1)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.6; OQ auto-classifier + memory reader)
│   ├── scan-codebase/            # brownfield repo mapper (v2.0; tree-sitter AST engine + queries/)
│   ├── bind-codebase/            # vault ↔ code validation gate (v1.6; impl-state + tech-OQ + Suggested Hard Rules + memory)
│   ├── generate-units/           # vault → atomic AI prompts (v2.0; task_type + PageRank symbol-graph suggestions)
│   ├── execute-bolts/            # units → code commits via superpowers (v2.0; ast-grep v2 Hard Rules + checkpoints)
│   │   └── scripts/              # migrate-v1-rules.sh
│   ├── orchestrate-flow/         # lifecycle auto-router (v2.0; --deep mode + --resume + per-step checkpoints)
│   ├── resolve-oq/               # Open Question walker (v0.5; memory writer)
│   ├── detect-drift/             # code vs vault reconciliation (v1.0)
│   ├── diff-vault/               # handle PRD revisions (v1.0)
│   └── _vendored/                # vendored superpowers skills (fallback)
├── commands/                     # 15 slash commands (13 skill + 2 helpers)
│   ├── auto.md                   # NEW v2.0 — one-shot end-to-end
│   ├── memory.md                 # NEW v2.1 — memory operations
│   ├── emit-agents-md.md         # NEW v3.0 — AGENTS.md emitter
│   ├── migrate-rules.md          # NEW v3.0 — Hard Rule v1 → v2 migration helper
│   └── extract-intelligence.md   # NEW v1.4 — legacy KB extraction
├── hooks/                        # SessionStart hook (anchor injection)
├── scripts/sync-superpowers.sh   # vendor sync automation
├── CLAUDE.md                     # AI-agent contributor guidelines
└── LICENSE
```

## Pipeline (one-line)

```
[legacy → extract-intelligence] → brief/PRD → generate-intent → (scan + bind for brownfield) → generate-units → execute-bolts → emit-agents-md
```

Wrapped by **`/mega-sdd:auto`** (v2.0) for autonomous end-to-end execution with single upfront confirmation. v3.0 adds tree-sitter AST scan + ast-grep Hard Rules + PageRank target_files suggestions + AGENTS.md interop + mid-skill JSONL checkpoints. Halt-protocol preserved across all iters.

## Memory layer (v2.1+)

Three scopes of markdown + JSON memory files persist context across sessions:

- `~/.mega-sdd/memory/` — USER scope (opt-in, cross-project)
- `<project>/.mega-sdd-memory/` — PROJECT scope (per-repo, git-trackable per-file)
- `<vault>/.memory/` + `<vault>/.mega-sdd/checkpoints/` — VAULT scope (per-vault, ephemeral)

Self-learning via threshold-based suggestions reviewed through `/mega-sdd:memory review`. Never auto-applied. Mandatory audit log + rollback path. Complementary to (NOT duplicative of) Claude Code's `auto memory`.

## Tech upgrades (v3.0+)

| Subsystem | Engine | Fallback |
|---|---|---|
| scan-codebase | tree-sitter (Aider pattern, 45k ⭐) | regex (v1.2 behavior) |
| Hard Rules | ast-grep YAML v2 (5-10× expressivity) | bespoke v1 grammar (preserved) |
| target_files | Personalized PageRank symbol-graph | binding citations only |
| Tool interop | AGENTS.md (Linux Foundation AAIF, 60k+ repos) | mega-sdd-only (v2.1 behavior) |
| Resume | Per-step JSONL checkpoints (LangGraph pattern) | CWD-driven (Iter 4 behavior) |

Both `tree-sitter` and `ast-grep` are single native binaries. Plugin works without them but falls back to v1 behavior with warnings.

See the [root README](../../README.md) for diagrams, full command table, trigger phrases, 10-layer anti-hallucination defense, Autonomy + Memory + Tech Upgrades mechanics, and migration from `grand-design-spec`.

## Contributing

Read [`CLAUDE.md`](./CLAUDE.md) first if you're an AI agent submitting a PR — anti-slop protocol applies. Every behavior change traces back to a spec doc in [`../../docs/superpowers/specs/`](../../docs/superpowers/specs/).

For human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md). Tree-sitter `.scm` query patterns adapted from [Aider](https://github.com/Aider-AI/aider) (Apache 2.0) — see `skills/scan-codebase/queries/`.
