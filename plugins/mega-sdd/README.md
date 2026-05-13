# mega-sdd

Spec-Driven Development plugin for [Claude Code](https://claude.com/claude-code). Intent → Unit → Bolt pipeline with anti-hallucination at every handoff.

**Version:** 1.2.0 · **License:** MIT

> 📖 **Full documentation lives at the repo root.** See [`../../README.md`](../../README.md) for TL;DR, 5W1H, full command reference, anti-hallucination layers, migration guide, halt protocol, and architecture deep dive.

## Quick start

```bash
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended companion
```

Then in any project:

```bash
/mega-sdd:orchestrate-flow
```

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest
├── skills/                       # 10 skills + _vendored/
│   ├── using-mega-sdd/           # anchor skill (injected at session start)
│   ├── generate-intent/          # PRD/brief → vault (auto-detect Mode A/B since v1.2)
│   ├── scan-codebase/            # brownfield repo mapper
│   ├── bind-codebase/            # vault ↔ code validation gate (BLOCKING)
│   ├── generate-units/           # vault → atomic AI prompts
│   ├── execute-bolts/            # units → code commits (via superpowers)
│   ├── orchestrate-flow/         # lifecycle auto-router
│   ├── resolve-oq/               # Open Question walker
│   ├── detect-drift/             # code vs vault reconciliation
│   ├── diff-vault/               # handle PRD revisions
│   └── _vendored/                # vendored superpowers skills (fallback)
├── commands/                     # 11 slash commands (10 skill + 1 command-only update-plugin)
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
