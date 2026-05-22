# mega-sdd

Spec-driven AI development pipeline for [Claude Code](https://claude.com/claude-code). PRD or idea → vault → atomic units → tested commits with anti-hallucination at every handoff.

**Version:** 3.8.0 · **License:** MIT

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
├── .claude-plugin/plugin.json    # plugin manifest (v3.8.0)
├── skills/                       # 11 skills + _vendored/
│   ├── using-mega-sdd/           # anchor skill (auto-injected)
│   ├── memory/                   # memory + self-learning (v1.2)
│   ├── emit-agents-md/           # AGENTS.md flatten (v1.1)
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.2)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.7)
│   ├── scan-codebase/            # tree-sitter AST scan (v2.3)
│   ├── bind-codebase/            # validation gate + field diff (v1.7.1)
│   ├── generate-units/           # atomic decomposition (v2.3)
│   ├── execute-bolts/            # superpowers TDD bridge (v2.2)
│   ├── orchestrate-flow/         # lifecycle router (v2.2)
│   ├── resolve-oq/               # OQ resolver + recommendations (v0.7)
│   ├── detect-drift/             # code vs vault (v1.0)
│   ├── diff-vault/               # PRD revision + jd patches (v1.1)
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

## Anti-hallucination defense (10 layers)

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
