# mega-sdd

Spec-Driven Development plugin for [Claude Code](https://claude.com/claude-code). Intent → Unit → Bolt pipeline with anti-hallucination at every handoff, plus an Autonomy Layer (`/mega-sdd:auto`) that runs the full pipeline end-to-end with single upfront confirmation.

**Version:** 2.0.0 · **License:** MIT

> 📖 **Full documentation lives at the repo root.** See [`../../README.md`](../../README.md) for TL;DR, 5W1H, full command reference, 8-layer anti-hallucination defense, Autonomy Layer details, migration guide, halt protocol, and architecture deep dive.

## Quick start

```bash
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended companion
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
├── .claude-plugin/plugin.json    # plugin manifest (v2.0.0)
├── skills/                       # 11 skills + _vendored/
│   ├── using-mega-sdd/           # anchor skill (v1.2; sharper auto-trigger)
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.1)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.5; OQ auto-classifier)
│   ├── scan-codebase/            # brownfield repo mapper (v1.1)
│   ├── bind-codebase/            # vault ↔ code validation gate (v1.5; impl-state + tech-OQ + Suggested Hard Rules)
│   ├── generate-units/           # vault → atomic AI prompts (v1.4; task_type + polished prompt-shape)
│   ├── execute-bolts/            # units → code commits via superpowers (v1.3; Hard Rule pre/post-flight)
│   ├── orchestrate-flow/         # lifecycle auto-router (v1.3; --deep mode + --resume)
│   ├── resolve-oq/               # Open Question walker (v1.0)
│   ├── detect-drift/             # code vs vault reconciliation (v1.0)
│   ├── diff-vault/               # handle PRD revisions (v1.0)
│   └── _vendored/                # vendored superpowers skills (fallback)
├── commands/                     # 12 slash commands (11 skill + 1 command-only update-plugin)
│   ├── auto.md                   # NEW v2.0 — one-shot end-to-end
│   └── extract-intelligence.md   # NEW v1.4 — legacy KB extraction
├── hooks/                        # SessionStart hook (anchor injection)
├── scripts/sync-superpowers.sh   # vendor sync automation
├── CLAUDE.md                     # AI-agent contributor guidelines
└── LICENSE
```

## Pipeline (one-line)

```
[legacy → extract-intelligence] → brief/PRD → generate-intent → (scan + bind for brownfield) → generate-units → execute-bolts
```

Wrapped by **`/mega-sdd:auto`** (v2.0) for autonomous end-to-end execution with single upfront confirmation. Halt-protocol preserved — every blocker (binding conflict, business OQ, Hard Rule violation, dedup ambiguity, cross-squad halts, quality-gate failure) still fires.

See the [root README](../../README.md) for diagrams, full command table, trigger phrases, 8-layer anti-hallucination defense, Autonomy Layer mechanics, and migration from `grand-design-spec`.

## Contributing

Read [`CLAUDE.md`](./CLAUDE.md) first if you're an AI agent submitting a PR — anti-slop protocol applies. Every behavior change traces back to a spec doc in [`../../docs/superpowers/specs/`](../../docs/superpowers/specs/).

For human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md).
