# Dispatch Bridge

How `execute-bolts` dispatches each unit — **first-class mega-sdd agents by default**, with superpowers (or its vendored copy) as optional technique skills + a legacy fallback.

## Dispatch order

0. **First-class mega-sdd agents (default).** The plugin ships its own subagents in `agents/`:
   - `mega-sdd:bolt-implementer` — implements the unit (writes target_files, writes + runs the acceptance test, commits).
   - `mega-sdd:spec-reviewer` — verifies spec compliance + Hard rules honored (read-only).
   - `mega-sdd:code-quality-reviewer` — reviews quality: duplication/reuse, tests, maintainability (read-only).
   - `mega-sdd:security-reviewer` — reviews security: input validation, authz vs spec, secrets, new deps, drift (read-only).
   - `mega-sdd:standards-reviewer` — reviews convention conformance vs pack + surrounding code (read-only).
   - `mega-sdd:design-reviewer` — reviews modern UI quality vs the vault design system (read-only; UI-bearing units only).

   `execute-bolts` runs in the **main thread as the controller** and dispatches these via the **Agent tool** — one fresh implementer per unit, then the **review panel** (parallel blind lenses per `references/review-panel.md`). Fully self-contained; no external plugin required. (Subagents cannot spawn subagents — that's why the controller stays in the main thread.)

1. **Superpowers technique skills (optional enhancement).** If superpowers is installed (`~/.claude/plugins/cache/**/superpowers/`), the implementer may additionally use its `test-driven-development`, `using-git-worktrees`, and `executing-plans` skills. They sharpen technique but are not required — the agents encode the same discipline in their own prompts. A unit's optional `superpowers_skills` frontmatter is treated as a technique hint.

2. **Vendored fallback.** If superpowers is absent, the same technique skills are available under `$PLUGIN_ROOT/skills/_vendored/`, where `$PLUGIN_ROOT` resolves to the **LATEST cached version** (not whatever version path is in context — that may be stale; see `plugins/mega-sdd/references/plugin-root-resolution.md`):
   ```bash
   DERIVED="<this reference file's absolute path, truncated before /skills/>"
   RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
   PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
   [ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
   ```

3. **Legacy path.** If the first-class agents are somehow unavailable (older install), fall back to dispatching superpowers `subagent-driven-development` directly, as before.

## Per-unit flow (review panel)

```
load unit U-XXX
   │  verify target_files (per each file's operation); if --worktree, isolate
   │  (superpowers using-git-worktrees if present, else a plain git branch)
   ▼
DISPATCH mega-sdd:bolt-implementer        (Agent tool)
   pass: the full unit body + frontmatter (target_files, acceptance_test,
   ## Hard rules, ## Anchors, ## Anti-patterns, binding_refs) + context.
   The implementer writes the failing acceptance test first (TDD), implements,
   runs the tests, commits with a provenance trailer.
   ▼
implementer reports  DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
   ├─ BLOCKED / NEEDS_CONTEXT → controller supplies context or halts — never silent-skip
   ▼ DONE
RUN L0 code gates                         (references/code-gates.md)
   repo-own format(-fix)/lint/typecheck → secret scan → SAST → new-dep existence
   ├─ secret_in_code / sast_critical_finding / dep_not_found → HALT (no panel, no commit)
   ▼ pass (findings + skips recorded, injected into lens prompts)
SELECT panel tier (risk-based)            (references/review-panel.md)
   minimal = spec · standard = spec+quality · full = +security +standards
   ▼
DISPATCH the selected lenses IN ONE MESSAGE (Agent tool, parallel, BLIND, read-only)
   each lens gets: unit body + base/head SHAs + its lens-specific context.
   NEVER the implementer's report, NEVER another lens's verdict.
   ▼
MERGE in the controller (main thread)
   evidence-or-drop (no file:line → discarded) → dedup, max severity → consensus marks
   ├─ spec ❌ OR any Critical → re-dispatch bolt-implementer with the merged
   │  issue list (shared cap: --max-retries, default 3); re-review stays blind
   ▼ clean (only Minor/Important remain — recorded in bolt-report ## Review panel)
write bolt-report.md, commit, mark unit DONE
   └─ tests still failing after retries → halt, bolt-report with failure analysis, surface to user
```

The controller constructs each agent's task prompt from the unit — see `references/bolt-dispatch-prompt.md` for the tiered-context (T1/T2) assembly. The agent never inherits session history; the controller passes exactly what it needs.

> Post-flight Hard Rule validation (ast-grep) still runs per `references/hard-rule-scan.md` regardless of dispatch path. The spec-reviewer's Hard-rule check is defense-in-depth, not a replacement for the deterministic scan + the PreToolUse gate.

## Halt protocol

After max retries failed:
- DO NOT silently move to the next unit.
- Emit the blocker YAML.
- `bolt-report.md` must include: last test output, files touched, what was attempted.
- User decides: retry, edit the unit, edit code manually, or skip.

## Whitelist enforcement

Before each implementation step, verify the step only touches files in the unit's `target_files`. If a step would touch an out-of-list file:
- Halt.
- Surface: "Unit U-XXX wants to modify <file> but it's not in target_files. Edit the unit or restructure."

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

## Squad-level fan-out

When `execute-bolts --per-squad` is invoked, the **main-thread controller** loops over the declared squads and runs each squad's units through the per-unit flow above — dispatching the first-class agents at **depth-1**. There is **NO squad subagent**: a forked squad controller could not dispatch the bolt agents (that would be depth-2, which the runtime forbids), and would silently lose the review panel. Parallelism comes from the controller dispatching independent units (across squads) **concurrently**, not from nesting. See `references/squad-subagent.md` for the filter + consolidation protocol.
