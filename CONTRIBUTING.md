# Contributing to grand-design-spec

## Versioning rules

This repository contains two version axes that move independently:

### Plugin version (`plugin.json` + `marketplace.json`)

Tracks the **distribution unit**. Bumped on every release that ships to users via `/plugin marketplace update`.

- **Major** (1.0.0): breaking change to plugin install/uninstall behavior, command names, or marketplace structure.
- **Minor** (0.X.0): new commands, new skills, new feature areas. Examples: v0.7 added compact mode, v0.11 added vault.json, v0.12 added slash commands.
- **Patch** (0.X.Y): bug fixes, doc updates, version-pin examples.

### Skill version (`SKILL.md` frontmatter)

Tracks the **individual skill's behavior contract**. Bumped only when *that specific skill* changes.

- **Major**: breaking change to skill inputs/outputs (e.g., new mandatory question, removed step).
- **Minor**: new behavior, new self-check, new field written to vault. Bump on first release that adds it.
- **Patch**: bugfix or wording cleanup that doesn't change observable behavior.

**Rule**: skill versions and plugin versions are independent. Do NOT auto-bump every skill on a plugin release — only the skills that actually changed.

### CHANGELOG discipline

Every plugin release entry MUST enumerate per-skill version moves:

```markdown
## [0.13.0] — 2026-05-09

### Skill version moves
- `grand-design-spec`: 0.8.0 → 0.9.0 (referenced shared vault-contract.md, added OQ_BLOCKER self-check)
- `resolve-oq`: 0.2.0 → 0.3.0 (removed lock-vault forward-refs, added vault.json count-match self-check)
- `vault-diff`: 0.1.0 → 0.2.0 (added Step 6.5 vault.json refresh)
- `drift-detect`: unchanged (0.2.0) — boundary documentation only

### Added
...
```

This makes it obvious which skills are different vs the prior release. Without it, contributors and downstream tooling can't tell whether re-running the same skill on the new plugin will behave the same.

## Commit message convention

Use [conventional commits](https://www.conventionalcommits.org/) with version-tagged scopes when the change targets a specific release:

- `feat(v0.13): ...` — new feature for v0.13
- `fix(v0.13): ...` — bugfix for v0.13
- `docs: ...` — documentation only
- `chore: ...` — meta / tooling

## Tagging releases

After merging release commits to `main`:

```bash
git tag v0.13.0
git push origin v0.13.0
```

Tags enable `git#vX.Y.Z` pin examples in the README. Tagging is currently spotty (only v0.3-v0.6 exist on the remote); aim to tag every release going forward.

## Adding a new skill

When adding a new skill to the plugin:

1. Create directory under `plugins/grand-design-spec/skills/<skill-name>/`.
2. Add `SKILL.md` with frontmatter: `name`, `version: 0.1.0`, `description`.
3. Add a corresponding command at `plugins/grand-design-spec/commands/<skill-name>.md` so it appears in slash autocomplete.
4. Reference `references/vault-contract.md` for shared definitions instead of duplicating.
5. **Implement `--auto` flag handling (v0.14 convention)**: any new skill that has prompts must define a `## --auto flag` section near the top of its SKILL.md, listing what `--auto` skips (logistical) vs what stays interactive (substance). When blocked in `--auto`, emit a `blocker` artifact per `vault-contract.md` §halt-protocol — pick the existing type (`oq_blocker`, `diff_conflict`, `drift_framework_mismatch`) or propose a new type as part of the contract bump.
6. Add a CHANGELOG entry that includes the new skill at version 0.1.0.

## Audit + spec workflow

For non-trivial work, follow the spec → plan → implementation pipeline used in this repo:

1. **Audit** existing state, write to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
2. **Plan** the implementation, write to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`.
3. **Execute** via the `superpowers:subagent-driven-development` or `superpowers:executing-plans` skill.

Each phase commits independently — the spec and plan stay as durable artifacts.
