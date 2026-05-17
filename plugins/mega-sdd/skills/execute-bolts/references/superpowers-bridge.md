# Superpowers Bridge

Specifies how `execute-bolts` dispatches each unit to superpowers skills, with vendored fallback.

## Detection order (which skills set to use)

1. **Installed superpowers** (preferred):
   - Detection: directory under `~/.claude/plugins/cache/**/superpowers/` exists
   - Use skills via their plugin namespace: `superpowers:executing-plans`, `superpowers:subagent-driven-development`, etc.

2. **Vendored fallback** (if superpowers not installed):
   - Detection: `${CLAUDE_PLUGIN_ROOT}/skills/_vendored/executing-plans/SKILL.md` exists
   - Use skills via local reference paths in `_vendored/`

3. **Neither**:
   - Halt. Print install instructions:
     ```
     ⚠️ execute-bolts requires superpowers OR vendored fallback.
     Install: /plugin install superpowers (from same marketplace)
     OR run: bash plugins/mega-sdd/scripts/sync-superpowers.sh
     ```

## Mapping unit → superpowers skills

Per unit's `superpowers_skills` frontmatter, dispatch in this order:

| Listed skill | Action |
|---|---|
| `test-driven-development` | Invoke first — write failing acceptance tests before implementation |
| `using-git-worktrees` | If `--worktree` flag set, create isolation worktree for this unit's bolt |
| `subagent-driven-development` | If `--parallel` and unit has no blocking deps in current batch, dispatch subagent |
| `executing-plans` | Default executor — runs implementation steps from unit body |

## Per-unit flow

```
load unit U-XXX
   │
   ▼
verify target_files exist or can be created (per unit's operation field)
   │
   ▼
if --worktree: spawn worktree via using-git-worktrees
   │
   ▼
invoke test-driven-development:
   - write tests from acceptance_test entries (type: test)
   - verify they fail
   │
   ▼
invoke executing-plans on unit body's "Implementation steps":
   - if --parallel and deps satisfied: dispatch via subagent-driven-development
   - else inline execution
   │
   ▼
re-run acceptance tests
   ├── pass → write bolt-report.md, commit, mark unit DONE
   └── fail → retry up to --max-retries (default 3)
         └── if still fail: halt, write bolt-report.md with failure analysis, surface to user
```

## Halt protocol

After max retries failed:
- DO NOT silently move to next unit
- Emit blocker YAML
- Bolt-report.md must include: last test output, files touched, what was attempted
- User decides: retry, edit unit, edit code manually, skip

## Whitelist enforcement

Before each implementation step, verify the step only touches files in unit's `target_files`. If a step would touch out-of-list file:
- Halt
- Surface message: "Unit U-XXX wants to modify <file> but it's not in target_files. Edit unit or restructure."

## bolt-report.md schema

Per unit, after execution:

```yaml
---
unit: U-XXX
status: success | failed | partial
attempted_at: <timestamp>
duration_seconds: N
commits: [<sha1>, <sha2>]
files_touched: [...]
tests_run: [...]
test_results: passed/failed counts
retries: N
---

# Bolt Report — U-XXX

## Summary
<one paragraph>

## Acceptance criteria status
- [ ] / [x] criterion 1
- [ ] / [x] criterion 2

## Failures (if any)
<test output, error messages, hypothesis>
```

## Squad-level fan-out (v1.1+)

When `execute-bolts --per-squad` is invoked, fan-out happens at the squad
level BEFORE the per-unit skill mapping above. See
`references/squad-subagent.md` for the dispatch protocol. Each squad's
subagent then independently follows the per-unit flow described in this
document.
