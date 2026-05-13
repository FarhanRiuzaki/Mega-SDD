# mega-sdd

Spec-Driven Development plugin for [Claude Code](https://claude.com/claude-code). Intent → Unit → Bolt pipeline with anti-hallucination guarantees.

**Version:** 1.1.0 · **License:** MIT

> 📖 **The full documentation lives at the repo root.** See [`../../README.md`](../../README.md) for the comprehensive overview — 5W1H, actor flowchart, full command reference, anti-hallucination layers, migration guide, halt protocol.

## Quick start

```bash
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended companion
```

Then:

```bash
/mega-sdd:orchestrate-flow
```

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest
├── skills/                       # 11 skills
│   ├── using-mega-sdd/           # anchor skill (injected at session start)
│   ├── generate-intent/          # PRD/brief → vault
│   ├── scan-codebase/            # brownfield repo mapper
│   ├── bind-codebase/            # vault ↔ code validation gate (BLOCKING)
│   ├── generate-units/           # vault → atomic AI prompts
│   ├── execute-bolts/            # units → code commits (via superpowers)
│   ├── orchestrate-flow/         # lifecycle auto-router
│   ├── resolve-oq/               # Open Question walker
│   ├── detect-drift/             # code vs vault reconciliation
│   ├── diff-vault/               # handle PRD revisions
│   ├── update-plugin/            # maintenance + dep doctor
│   └── _vendored/                # vendored superpowers skills (fallback)
├── commands/                     # 11 slash commands
├── hooks/                        # SessionStart hook (anchor injection)
├── scripts/sync-superpowers.sh   # vendor sync automation
├── CLAUDE.md                     # AI-agent contributor guidelines
└── LICENSE
```

## Pipeline (one-line)

```
brief/PRD → generate-intent → (scan + bind for brownfield) → generate-units → execute-bolts
```

See the [root README](../../README.md) for diagrams, full command table, trigger phrases, anti-hallucination layers, and migration from `grand-design-spec`.

## Contributing

Read [`CLAUDE.md`](./CLAUDE.md) first if you're an AI agent submitting a PR — anti-slop protocol applies.

For human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md).
