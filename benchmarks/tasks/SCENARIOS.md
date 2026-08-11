# Benchmark context-trace scenarios (shared spec — BOTH arms use this verbatim)

## Trace rules (binding)

1. **Count MAIN-session commanded instruction loads only**: every plugin file the loading contract COMMANDS the model to Read in the scenario's state path — SKILL.md of each skill in the chain, plus references whose load is UNCONDITIONAL in that SKILL, plus references whose load-condition is TRUE given the scenario state below. Repo-relative paths.
2. **Conditional refs**: if the SKILL says "read X WHEN <condition>" and the condition is FALSE in the scenario state → EXCLUDE, and list it under EXCLUDED with the condition. If the arm has NO condition (unconditional command) → INCLUDE.
3. **Scripts executed via Bash** (`scripts/*.sh`, hooks) are NOT context loads — exclude them (their few output lines are noted but not counted). This is deliberate: script-ification moves instruction bytes out of context.
4. **Subagent-dispatched content** (fresh-context reviewers/implementers) lands in the SUBAGENT window — exclude from the main-session trace. The dispatch POINTER mechanism is identical in both arms (predates baseline).
5. **Partial/section reads**: if the contract commands reading only a named § of a file, include the file with marker `[SECTION:<name>]` — the harness will count the whole file as UPPER BOUND and note the section; do NOT estimate section sizes yourself.
6. **Router overhead** (using-mega-sdd / orchestrate-flow SKILL) counts once per scenario when the scenario enters through it.
7. When genuinely uncertain whether a file is commanded, list it under UNCERTAIN with the ambiguous sentence quoted — do NOT guess silently.
8. Cite for every INCLUDED file the commanding line: `path:line` + a ≤15-word quote fragment.

## Scenario states (identical for both arms)

**T01 greenfield-full-chain (to first bolt dispatch).** New Laravel 11 project, PRD.md exists at repo root. User: `/mega-sdd:auto`. Express spine default (both arms have it). State: no starterkit, single scope, zero OQ halts (all auto-answerable), zero CONFLICT, constitution absent, no --classic, no design-system content (HAS_UI=false). Chain: orchestrate-flow → generate-intent → GROUND → generate-units → execute-bolts UNTIL the first bolt dispatch file is built (stop before implementer runs).

**T02 brownfield-adopt-bind.** Existing Laravel codebase, teammate's vault pulled via git (vault exists, valid, in_sync stamp absent). User: "bind codebase ke vault". Chain: orchestrate-flow → bind-codebase FULL bind (not --paths), zero CONFLICT results, binding.md + binding.json written. No resolve-oq (no conflicts).

**T03 sync-hotfix-no-intersection.** Teammate hotfix changed 2 files; NEITHER intersects any binding claim anchor nor unit target_files. User: `/mega-sdd:sync` (orchestrate-flow --sync). Baseline arm: whatever the 6.1.1 sync lane commands (full reconcile hop chain as written). Optimized arm: scan §Incremental → sync-intersect short-circuit path (exit 0 in_sync → stamp + END).

**T04 sync-with-intersection.** Same entry as T03, but 1 changed file DOES match a binding claim anchor → both arms proceed into the reconcile chain: scan (incremental) → detect-drift (sync lane) → bind-codebase claim-scoped re-bind (--paths). Zero CONFLICT results. Chain ends at re-bind complete.

**T05 resolve-oq-walk-3.** Vault has 3 open `[ ]` OQs (intent mode, not --binding). User: "resolve OQ". Chain: orchestrate-flow → resolve-oq, full walk of 3 OQs, recommendations rendered, no halts.

**T06 emit-fsd (control).** Complete vault, user: "emit FSD". Chain: orchestrate-flow → emit-fsd, PDF renders OK. Expect ≈0 delta — the emission lane was NOT a P1–P4 target (control task; honesty check).

**T07 chat-delta (negative control).** User free-text: "tambah kolom npwp di form nasabah". No cheap delta lane exists in EITHER arm (the known gap — proposals doc). Trace the arm's actual commanded path for this input: full re-vault (generate-intent on existing vault → diff-vault or bind, per each arm's routing). Expect ≈0 delta — proves what was NOT fixed.

**T08 post-bolt-drift-gate.** execute-bolts just finished bolt 1 of 3; the automatic post-bolt drift gate fires. Chain: detect-drift with drift-axis --scope (standalone gate, NOT sync lane), zero drift found, next_action null. Count only the detect-drift segment (execute-bolts context already counted in T01-class runs).

## Output format (per scenario, machine-parsable)

```
=== T01 ===
INCLUDED:
<repo-relative-path> | <cite path:line> | "<quote fragment>"
...
EXCLUDED:
<repo-relative-path> | condition: "<quote>" | false because: <scenario state>
UNCERTAIN:
<repo-relative-path> | "<ambiguous sentence>"
CHAIN-END: <one line: where the trace stops and why>
```
