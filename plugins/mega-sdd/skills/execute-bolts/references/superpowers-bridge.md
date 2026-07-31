# Dispatch Bridge

How `execute-bolts` dispatches each unit — **first-class mega-sdd agents by default**, with superpowers (or its vendored copy) as optional technique skills + a legacy fallback.

## Contents

- [Dispatch order](#dispatch-order)
- [Per-unit flow (review panel)](#per-unit-flow-review-panel)
- [Halt protocol](#halt-protocol)
- [Whitelist enforcement](#whitelist-enforcement)
- [bolt-report.md schema](#bolt-reportmd-schema)
- [Summary](#summary)
- [Acceptance criteria status](#acceptance-criteria-status)
- [Failures (if any)](#failures-if-any)
- [Squad-level fan-out](#squad-level-fan-out)

## Dispatch order

0. **First-class mega-sdd agents (default).** The plugin ships its own subagents in `agents/`:
   - `mega-sdd:bolt-implementer` — implements the unit (writes target_files, writes + runs the acceptance test, commits).
   - `mega-sdd:spec-reviewer` — verifies spec compliance + Hard rules honored (read-only).
   - `mega-sdd:code-quality-reviewer` — reviews quality: duplication/reuse, tests, maintainability (read-only).
   - `mega-sdd:security-reviewer` — reviews security: input validation, authz vs spec, secrets, new deps, drift (read-only).
   - `mega-sdd:standards-reviewer` — reviews convention conformance vs pack + surrounding code (read-only).
   - `mega-sdd:design-reviewer` — reviews modern UI quality vs the vault design system (read-only; UI-bearing units only).

   `execute-bolts` runs in the **main thread as the controller** and dispatches these via the **Agent tool** — one fresh implementer per unit, then the **review panel** (parallel blind lenses per `references/review-panel.md`). Fully self-contained; no external plugin required. (Subagents cannot spawn subagents — that's why the controller stays in the main thread.)

1. **Superpowers technique skills (optional enhancement).** If superpowers is installed (`~/.claude/plugins/cache/**/superpowers/`), the implementer may additionally use its `test-driven-development`, `using-git-worktrees`, and `executing-plans` skills. They sharpen technique but are not required — the agents encode the same discipline in their own prompts. A legacy unit's optional `superpowers_skills` frontmatter is treated as a technique hint (no longer written; the agents encode the discipline regardless).

2. **Vendored fallback.** If superpowers is absent, the same technique skills are available under `$PLUGIN_ROOT/skills/_vendored/`, where `$PLUGIN_ROOT` resolves to the **LATEST cached version** (not whatever version path is in context — that may be stale; see `plugins/mega-sdd/references/plugin-root-resolution.md`):
   ```bash
   DERIVED="<this reference file's absolute path, truncated before /skills/>"
   RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
   PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
   [ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
   ```

3. **Legacy path — CLOSED 2026-07-31.** This used to read: *"If the first-class agents are somehow unavailable (older install), fall back to dispatching superpowers `subagent-driven-development` directly, as before."* That fallback is retired for `bolt-implementer`, because its premise is not reachable: **`scripts/build-dispatch-prompt.sh` and `agents/bolt-implementer.md` ship in the SAME plugin tree**, and the builder fills the version on its `## Contracts (agent-carried)` line from the very plugin root it resolved — so if the builder ran, the agent file exists at that root at that version. There is no state where the builder is present and the first-class agents are not.

   The path also could not be made honest cheaply: `bolt-dispatch-prompt.md` specified that on this path the prompt must inline the agent's §Halt vocabulary / §Self-report / §Rollback hints / §Provenance trailer verbatim, the builder has no flag for it and never did, and on that path the emitted contracts line asserts the executor's system prompt carries contracts it does not have — a bolt running with no halt vocabulary, no rollback hints and no provenance-trailer shape, silently. Neither the builder, the skill, nor the validator can detect the branch.

   **If the Agent tool genuinely cannot dispatch `mega-sdd:bolt-implementer`, that is a broken install: STOP and surface it to the human** (untyped blocker → pure-pause, per `agents/bolt-implementer.md §Halt vocabulary`). Never substitute a generic executor while telling it that its system prompt carries contracts it does not hold. Items 1 and 2 above are unaffected — superpowers *technique* skills remain an optional enhancement with a vendored fallback.

## Per-unit flow (review panel)

```
load unit U-XXX
   │  verify target_files (per each file's operation); if --worktree, isolate
   │  (superpowers using-git-worktrees if present, else a plain git branch)
   ▼
BUILD the dispatch prompt              (scripts/build-dispatch-prompt.sh — SKILL.md 4.5)
   writes <vault>/bolts/U-XXX/dispatch-prompt.md; returns inline_core on stdout
   ├─ exit 1 + a `halt` object on stdout → halt dispatch_prompt_too_large
   │            (prompt written deliberately = forensic evidence)
   ├─ exit 2 → usage / IO / no interpreter — nothing published, do NOT dispatch
   ├─ exit 4 (or exit 1 with no parseable stdout) → INTERNAL ERROR, not a budget
   │            halt — nothing published, nothing destroyed; a prior attempt's
   │            prompt may still be on disk INTACT. The EXIT CODE decides, not
   │            the file: do NOT dispatch
   ▼ exit 0 (never --quiet: it suppresses the JSON carrying inline_core
             and design_slice_path; always pass --plugin-root)
DISPATCH mega-sdd:bolt-implementer        (Agent tool)
   pass: inline_core VERBATIM (<=700B) — the pointer to the written prompt, which
   carries the full unit body + frontmatter (target_files, acceptance_test,
   ## Hard rules, ## Anchors, ## Anti-patterns, binding_refs) + tiered context.
   The implementer READS that file first, then writes the failing acceptance test (TDD), implements,
   runs the tests, COMMITS with the canonical message + trailers
   (bolt-contract.md §Commit message format) — the commit topology is
   detect-after: everything below runs against this landed commit.
   ▼
implementer reports  DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
   ├─ BLOCKED / NEEDS_CONTEXT → controller supplies context or halts — never silent-skip
   ▼ DONE
RUN L0 code gates                         (references/code-gates.md)
   repo-own format(-fix)/lint/typecheck → secret scan → SAST → new-dep existence
   ├─ secret_in_code / sast_critical_finding / dep_not_found → HALT
   │  (no panel; the flagged code is in the already-landed commit — remediation
   │  acts on that commit per code-gates.md)
   ▼ pass (findings + skips recorded, injected into lens prompts)
SELECT panel tier (risk-based)            (references/review-panel.md)
   minimal = spec · standard = spec+quality · full = +security +standards
   ▼
DISPATCH the selected lenses IN ONE MESSAGE (Agent tool, parallel, BLIND, read-only)
   each lens gets: a unit-body slice sized to the lens (spec = full verbatim;
   others = frontmatter + requirements + Hard rules + Anchors/Anti-patterns + Migration notes
   (+ Goal/Out-of-scope for the quality lens; the design slice unchanged),
   NOT the Implementation-steps narrative and NOT Goal/Context/Out-of-scope
   for security/standards — per `review-panel.md §Blind dispatch`)
   + base/head SHAs + its lens-specific context.
   NEVER the implementer's report, NEVER another lens's verdict.
   ▼
MERGE in the controller (main thread)
   evidence-or-drop (no file:line → discarded) → dedup, max severity → consensus marks
   ├─ spec ❌ OR any Critical → re-dispatch bolt-implementer with the merged
   │  issue list (shared cap: --max-retries, default 3); the re-dispatch
   │  RE-ENTERS at "RUN L0 code gates" (fresh scans against the new head;
   │  re-review prompts carry the NEW results); re-review stays blind, diff
   │  range keeps the ORIGINAL bolt base.
   │  Retries EXHAUSTED with a Critical still open OR spec still ❌
   │  → halt review_critical_unresolved
   ▼ clean (only Minor/Important remain — recorded in bolt-report ## Review panel)
run post-flight scan (run-postflight-scan.sh), write bolt-report.md, mark unit DONE
   └─ tests still failing after retries → halt, bolt-report with failure analysis, surface to user
```

The agent never inherits session history; it gets exactly what the controller passes. **Two different constructions:**

- **`bolt-implementer`** — the controller does NOT construct its prompt. It runs `scripts/build-dispatch-prompt.sh` (SKILL.md §Step 4.5), which writes the full tiered T1/T2 prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md`, and dispatches with the returned `inline_core` VERBATIM — a ≤700B pointer the implementer follows to Read that file. The controller never re-types or paraphrases the assembled prompt. Emitted shape → `references/bolt-dispatch-prompt.md`; spec → `references/context-enrichment.md`.
- **The review lenses** — still controller-constructed, per `references/review-panel.md §Blind dispatch` (per-lens unit-body slices + lens-specific context). They are NOT given `inline_core`, never read the implementer's report, and **are never given a path that reaches another lens's verdict or the implementer's self-report** — which forbids `<vault>/bolts/U-XXX/` (it holds `bolt-report.md`) and permits `<vault>/lens-inputs/U-XXX/` (controller-written lens inputs only). The design lens's rubric arrives as the builder's `design_slice_path`, pointing at `<vault>/lens-inputs/U-XXX/design-slice.md`.

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

Backstop (B3 — deterministic): `validate-bolt-artifacts.sh --whitelist-scan` (Stop-hook +
execute-bolts gate-time) diffs each bolted unit's COMMITTED paths against `target_files`
∪ sanctioned extras (vault/bolt artifacts, `.mega-sdd/`, test files); an escaped path
blocks the next `execute-bolts` with `whitelist_violation`. The prose rule above is the
first line; the observer is the contract.

## bolt-report.md schema

Per unit, after execution. This is the CANONICAL schema (single owner — other refs
describe pieces of it; on conflict this block wins):

```yaml
---
unit: U-XXX
status: success | failed | partial | halted_postflight | forced_pass
attempted_at: <timestamp>
duration_seconds: N
commits: [<sha1>]              # ONE commit per bolt (bolt-contract discipline);
                               # >1 only for sanctioned retry amend-chains
files_touched: [...]
tests_run: [...]
test_results: passed/failed counts
retries: N
target_hashes:                 # MANDATORY — sha256 of each target_files entry
  <repo-relative-path>: <sha256-hex>   # AT COMMIT TIME (living-vault staleness anchor)
scope: <scope-id>              # only when vault.json carries scope_metadata
---

# Bolt Report — U-XXX

## Summary
<one paragraph>

## Acceptance criteria status
- [ ] / [x] criterion 1
- [ ] / [x] criterion 2

## Review panel
<MANDATORY when a panel ran: tier used, lens list, finding table
(severity, file:line, lens), dropped-no-evidence count, and — when the run
HALTED review_critical_unresolved (an open Critical or a still-❌ spec lens at
cap exhaustion; the halt is terminal, the bolt never "proceeds" over it) — the
halt ref.
Also records design-lens skip reason for non-UI units, and L0 gate SKIPs.>

## Failures (if any)
<test output, error messages, hypothesis>
```

Statuses `halted_postflight` (post-flight Hard-rule violation recorded — see
hard-rule-scan.md) and `forced_pass` (`--force-skip-postflight` used — anti-bypass
policy applies) are first-class: consumers (compute-unit-staleness, the sync lane,
`_summary.md`) must not treat them as schema errors.

## Squad-level fan-out

When `execute-bolts --per-squad` is invoked, the **main-thread controller** loops over the declared squads and runs each squad's units through the per-unit flow above — dispatching the first-class agents at **depth-1**. There is **NO squad subagent**: a forked squad controller could not dispatch the bolt agents (that would be depth-2, which the runtime forbids), and would silently lose the review panel. Parallelism comes from the controller dispatching independent units (across squads) **concurrently**, not from nesting. See `references/squad-subagent.md` for the filter + consolidation protocol.
