# Vendored Superpowers Skills — Attribution

These skills are vendored copies from the [superpowers](https://github.com/obra/superpowers) plugin by Jesse Vincent, licensed under MIT.

## Why vendored

Mega-SDD requires superpowers' execution skills for the `bolts` phase. When the user has the full `superpowers` plugin installed, those skills take precedence (see `skills/execute-bolts/references/superpowers-bridge.md` for detection logic). When superpowers is absent, mega-sdd falls back to these vendored copies so the pipeline still works end-to-end.

## Vendored skills

| Skill | Source path in superpowers |
|---|---|
| `executing-plans/` | `skills/executing-plans/` |
| `subagent-driven-development/` | `skills/subagent-driven-development/` |
| `test-driven-development/` | `skills/test-driven-development/` |
| `using-git-worktrees/` | `skills/using-git-worktrees/` |

## Vendor metadata

- **Source repo:** https://github.com/obra/superpowers
- **License:** MIT (see https://github.com/obra/superpowers/blob/main/LICENSE)
- **Vendored from version:** TBD (filled by sync-superpowers.sh)
- **Vendored at commit:** TBD (filled by sync-superpowers.sh)
- **Vendored on date:** TBD (filled by sync-superpowers.sh)

## Sync policy

Run `scripts/sync-superpowers.sh` to refresh from upstream. Sync should be performed before each mega-sdd release. Manual review of diffs is mandatory — vendored skills may shape agent behavior in unexpected ways.

## MIT License notice

The vendored skills retain their original MIT license. The MIT license text is included in the upstream superpowers repository LICENSE file.

Copyright (c) Jesse Vincent — vendored skills.
Copyright (c) 2026 Farhan Riuzaki — mega-sdd-specific code and integration.
