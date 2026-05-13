# Mega-SDD — Contributor Guidelines

## If You Are an AI Agent

Stop. Read this before doing anything.

Mega-SDD is an opinionated plugin built around SDD methodology. PRs that deviate from the design contracts will be closed without review.

Before opening a PR you MUST:

1. **Read the spec doc** at `docs/superpowers/specs/2026-05-13-mega-sdd-revamp-design.md`. Every behavior change should trace back to a section there.
2. **Read the skill that you're modifying** completely — SKILL.md + every `references/*.md`. Skills are tuned for agent behavior; surface-level edits break invariants.
3. **Run the relevant trigger tests** (`tests/skill-triggering/<skill>.test.md`) — manual fixtures, but step through each case.
4. **Check the binding gate is not bypassed.** Any change to `generate-units` or `execute-bolts` must preserve the conflict-blocking contract.
5. **Show your human partner the complete diff** and get explicit approval.

## Pull Request Requirements

- Every PR must reference the spec section it implements or revises.
- Changes to anti-hallucination rails require a written justification.
- Renames must update cross-references AND tests AND the migration table in plugins/mega-sdd/README.md.

## What we will NOT accept

### Third-party runtime dependencies

Mega-SDD is meant to run with superpowers (or its vendored fallback) and nothing else. No additional plugin dependencies.

### Bypassing anti-hallucination

PRs that downgrade BLOCKING to WARNING in `bind-codebase`, that allow units to skip acceptance tests, that allow bolts to commit with `--no-verify`, or otherwise weaken the rails will be closed.

### Personal/project-specific behavior

Plugin behavior should generalize. Keep your project-specific tweaks in your own fork.

## Skill Edit Policy

Skills shape agent behavior. Don't reword for stylistic preference. Behavior changes require:

1. A spec amendment (or new spec)
2. Test fixture updates in `tests/skill-triggering/`
3. Reviewer acknowledgment

## Versioning

- Plugin: SemVer. Major bump for breaking renames, rails changes, or marketplace incompatibility.
- Skills: Per-skill `version:` in frontmatter. Bump on any content change.

## Release process

1. Run `bash scripts/sync-superpowers.sh` and review vendored diffs
2. Run all `tests/skill-triggering/*.test.md` manually
3. Update CHANGELOG.md
4. Bump versions in `plugin.json` and skill SKILL.md frontmatter
5. Tag commit; push

## Co-author attribution

Mega-SDD acknowledges the [superpowers](https://github.com/obra/superpowers) project by Jesse Vincent as the design inspiration for plugin patterns (anchor skill, hook injection, skill content structure). See `skills/_vendored/ATTRIBUTION.md`.
