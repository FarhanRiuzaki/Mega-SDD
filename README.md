# Mega-SDD Plugin Repository

> Spec-Driven Development plugin for [Claude Code](https://claude.com/claude-code).

This repo hosts the `mega-sdd` Claude Code plugin and its marketplace listing.

## Quick start

```bash
/plugin marketplace add farhanriuzaki/mega-sdd
/plugin install mega-sdd
/plugin install superpowers   # recommended companion
```

Then in any project directory:
```bash
/mega-sdd:orchestrate-flow
```

For the full plugin documentation, flow diagram, and command reference, see [`plugins/mega-sdd/README.md`](plugins/mega-sdd/README.md).

## Repository structure

```
.
├── .claude-plugin/marketplace.json     # marketplace manifest
├── plugins/mega-sdd/                   # the plugin itself
│   ├── README.md                       # full plugin docs (start here)
│   ├── skills/                         # 11 skills (4 new SDD phases + renames + anchor)
│   ├── commands/                       # 10 slash commands
│   ├── hooks/                          # SessionStart hook for anchor injection
│   ├── scripts/                        # sync-superpowers + version bump
│   └── CLAUDE.md                       # contributor guidelines
├── docs/
│   ├── superpowers/specs/              # design specs (gold reference)
│   ├── superpowers/plans/              # implementation plans
│   └── mega-sdd/                       # default output dir for generated vaults
├── tests/
│   ├── skill-triggering/               # per-skill manual fixtures
│   ├── hooks/                          # automated hook tests
│   ├── vendoring/                      # vendor sync tests
│   └── integration/                    # E2E pipeline tests
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

## Migration from `grand-design-spec`

If you previously installed `grand-design-spec`, see `plugins/mega-sdd/README.md` §Migrating for a full rename table. Existing vaults remain compatible — only skill/command names change.

## License

MIT — see LICENSE.

Acknowledges [superpowers](https://github.com/obra/superpowers) by Jesse Vincent — vendored skills under `plugins/mega-sdd/skills/_vendored/` retain their original MIT license per `ATTRIBUTION.md`.
