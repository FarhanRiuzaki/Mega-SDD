# Contributing to Mega-SDD

(See `plugins/mega-sdd/CLAUDE.md` for the AI-agent contributor protocol — read that first if you're an AI.)

## Repository layout

This is a Claude Code plugin marketplace + the plugin itself. Plugin code lives under `plugins/mega-sdd/`. Specs/plans live under `docs/superpowers/`.

## SDD invariants

These are the non-negotiable rails. Any PR violating them will be closed:

1. **Anti-hallucination at intent layer:** uncertain claims → Open Question, never guess.
2. **Binding gate is BLOCKING:** `bind-codebase` MUST NOT produce `bound-vault/` while conflicts exist.
3. **Unit grounding:** every unit has `target_files` whitelist + ≥1 acceptance test.
4. **Bolt isolation:** every bolt produces exactly one PR's worth of commits; no skipping pre-commit hooks.
5. **Drift surfaces, never silently:** detect-drift writes a report, even when clean.

## Skill changes

Skills are content-driven. Edit `SKILL.md` (the agent reads it) NOT supporting `references/*.md` (unless adding new contracts).

Before submitting:
- Bump skill `version:` in frontmatter
- Update relevant `tests/skill-triggering/<skill>.test.md` if behavior changes
- Add CHANGELOG.md entry

## Testing

Shell suites live in TWO trees — `plugins/mega-sdd/tests/` (plugin-local) and `<repo-root>/tests/` (repo-wide). CI discovers every `test-*.sh` / `*.test.sh` at any depth in BOTH trees (`.github/workflows/tests.yml`), so run both locally before claiming green. One suite at a time:

```bash
bash tests/hooks/session-start.test.sh
bash plugins/mega-sdd/tests/graph/test-vault-layout2.sh
```

The markdown fixtures under `tests/skill-triggering/` and `tests/integration/` are manual walkthroughs: read them and step through each case in a fresh Claude Code session.

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
- `mega-sdd`: 0.8.0 → 0.9.0 (referenced shared vault-contract.md, added OQ_BLOCKER self-check)
- `resolve-oq`: 0.2.0 → 0.3.0 (removed lock-vault forward-refs, added vault.json count-match self-check)
- `diff-vault`: 0.1.0 → 0.2.0 (added Step 6.5 vault.json refresh)
- `detect-drift`: unchanged (0.2.0) — boundary documentation only

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

Tags enable `git#vX.Y.Z` pin examples in the README. Tag every release.

## Adding a new skill

When adding a new skill to the plugin:

1. Create directory under `plugins/mega-sdd/skills/<skill-name>/`.
2. Add `SKILL.md` with frontmatter: `name`, `version: 0.1.0`, `description`.
3. **Do NOT add a `commands/<skill-name>.md` file.** The public command surface is three verbs (`/mega-sdd`, `/mega-sdd:sync`, `/mega-sdd:emit`) plus three maintenance one-timers (`migrate-paths`, `install-deps`, `update-plugin`) — exactly 6 command files, nothing else (the 5.x deprecation aliases were removed at 6.0.0, the `memory` one-timer in v7.3.0, `/mega-sdd:slice` in v7.4.0). A new skill is internal — it is reached through the `/mega-sdd` front door (state-based routing) or, for a document, the `/mega-sdd:emit` verb. Only a deliberate spec-level decision may extend the canonical surface (see `plugins/mega-sdd/CLAUDE.md` §Commands — `/mega-sdd:slice`, added 6.8.0 per spec `2026-08-12-playwright-embed-design.md` and removed in v7.4.0 by owner decision, is the worked example of that escape hatch in both directions).
4. Reference `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` for shared definitions instead of duplicating.
5. **Implement `--auto` flag handling (v0.14 convention)**: any new skill that has prompts must define a `## --auto flag` section near the top of its SKILL.md, listing what `--auto` skips (logistical) vs what stays interactive (substance). When blocked in `--auto`, emit a `blocker` artifact per `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol — pick the existing type (`oq_blocker`, `diff_conflict`, `drift_framework_mismatch`) or propose a new type as part of the contract bump.
6. Add a CHANGELOG entry that includes the new skill at version 0.1.0.

## Audit + spec workflow

For non-trivial work, follow the spec → plan → implementation pipeline used in this repo:

1. **Audit** existing state, write to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
2. **Plan** the implementation, write to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`.
3. **Execute** via the `superpowers:subagent-driven-development` or `superpowers:executing-plans` skill.

Each phase commits independently — the spec and plan stay as durable artifacts.
