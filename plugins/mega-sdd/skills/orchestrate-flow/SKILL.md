---
name: orchestrate-flow
version: 1.0.0
description: Multi-skill lifecycle orchestrator for grand-design-spec. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms with user once, then executes the chain in --auto mode. Triggers — "run the flow", "orchestrate vault lifecycle", "auto vault", "do the next thing", or paraphrases.
---

# Flow — Lifecycle Orchestrator

Multi-skill orchestrator for `grand-design-spec`. Inspects CWD, builds a proposed chain of sub-skill invocations, confirms with the user once, then executes the chain with sub-skills in `--auto` mode. Removes the friction of remembering which skill to invoke for which lifecycle event while preserving every anti-hallucination rail in the sub-skills.

> **Skill instruction language**: this skill is written in English for reasoning quality. Chat prompts (proposed plan, final summary) adapt to the user's language at runtime. Per `references/vault-contract.md` §boilerplate.

## When to use this skill

Trigger this skill for:

- "run the flow" / "auto vault" / "run grand-design-spec end to end"
- "do the next thing" / "what's next?" (ambiguous lifecycle position)
- "orchestrate" / "chain the skills" / "lifecycle round"
- The user has just received a new PRD revision and wants the natural next steps to happen automatically.
- The user has finished a stakeholder meeting and wants OQ resolution + downstream impact checks in one shot.

Do NOT use this skill when:

- Only one specific skill is needed (e.g., "just resolve OQs"). Prefer the direct invocation.
- The vault is in an unusual state the user wants to handle manually.
- The user explicitly wants to walk through a step interactively without `--auto` shortcuts.

## Core principle

> **The orchestrator routes; sub-skills produce content. Never the other way around.**

The orchestrator inspects state, proposes a plan, dispatches sub-skills with `--auto` flags. It does NOT:

- Generate vault content.
- Auto-answer Open Questions.
- Auto-resolve diff conflicts.
- Auto-fill anything stakeholders need to decide.

Anti-halu rails live in the sub-skills, untouched. The orchestrator's job is sequencing — nothing more.

## Workflow

### Step 0: Inputs

Accept arguments:

- **No args** → operate on CWD.
- **One arg = directory path** → operate on this vault.
- **One arg = file path** (`.pdf`/`.docx`/`.md`) → bias toward "vault-diff this PRD against the closest vault in CWD".
- **One arg = free text** (>20 chars, no path-like characters such as `/`, `.`, or starting with `~`) → treat as prompt for Rule 0 chain.
- **Borderline ambiguous arg** (e.g., 15-char input, or contains both file-like and prose-like content) → ask user via `AskUserQuestion`: "Treat this as a prompt or look for it as a file path?".

Persist:

- `WORK_DIR=<resolved CWD>`
- `EXPLICIT_VAULT_PATH=<path or null>`
- `EXPLICIT_PRD_PATH=<path or null>`
- `EXPLICIT_PROMPT=<text or null>` (v0.2+)

If WORK_DIR is empty (no files at all) and no args, STOP and tell the user: *"No vault, no PRD, no prompt detected. Point me at one: `/mega-sdd:orchestrate-flow ./vault-dir/`, `/mega-sdd:orchestrate-flow PRD-v2.pdf`, or `/mega-sdd:orchestrate-flow \"<your brief>\"`."*

### Step 1: CWD inspection

Run deterministic state reading. No LLM judgment in this step.

| Signal | How detected | What it tells us |
|--------|--------------|------------------|
| Vault present? | Look for a directory in WORK_DIR (or EXPLICIT_VAULT_PATH) containing all 7 files (`00-index.md` through `06-constraints.md`) | Generate vs evolve |
| `vault.json` present? | File next to the 7 .md files | Pre- or post-v0.11 vault |
| Vault metadata | Parse `00-index.md` Vault Lock Status: `Implementation mode`, `PRD source` filename + version, last `Vault version`, `mode_migrate_after` | Lifecycle position |
| PRD/source files | PDF/DOCX/MD files in WORK_DIR or EXPLICIT_PRD_PATH. Compare filename/version to vault's `PRD source` | New PRD revision? |
| Codebase signals | `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod` / `requirements.txt` / `pubspec.yaml` in WORK_DIR or vault parent | Is `mode=existing` actionable? |
| Unresolved P1 count | `vault.json.open_questions_summary.by_priority.P1` (or grep `[ ] **OQ-...** [P1]` across docs 01-06 if vault.json missing) | Resolve-oq needed? |
| Mode migration trigger fired? | `mode_migrate_after` from Vault Lock Status. Auto-detectable: `"first commit on main"` (check `git log --reverse | head -1`). Not auto-detectable: `"first prod deploy"` / `"sprint-1 demo"` (require human knowledge — note as such in plan) | mode=new vault about to flip? |
| Git state | `git log --oneline -1` and `git status` in WORK_DIR | Safety nudges in summary |

Persist findings as a structured state object that Step 2 reads.

### Step 2: Build proposed chain

Apply the decision matrix in order. First match wins; chains include all applicable downstream skills by default. User can skip individual steps via `Edit plan: skip step N` in Step 3 confirmation.

```
RULE 0 (NEW v0.2) — IF no vault AND no PRD file detected AND prompt arg given:
    → chain: from-prompt → grand-design-spec → resolve-oq (scope=p1-only)
    → drift-detect not applicable (mode=new vault, no codebase yet)

RULE 1 (default-on v0.2) — IF no vault AND PRD detected:
    → chain: grand-design-spec → resolve-oq (scope=p1-only)
    → drift-detect chained ONLY IF user selected mode=existing during gds

RULE 2 (default-on v0.2) — IF vault exists AND new PRD detected
    (filename or version differs from vault's PRD source):
    → chain: vault-diff → resolve-oq (scope=p1-only, only if new P1s introduced)
    → drift-detect chained ONLY IF mode=existing AND codebase available in CWD

RULE 3 (unchanged) — IF vault exists AND vault.json missing:
    → chain: grand-design-spec re-run with vault's existing flags (regenerates manifest only)

RULE 4 (default-on v0.2) — IF vault exists AND P1 count > 0 AND no new PRD:
    → chain: resolve-oq (scope=p1-only)
    → drift-detect chained ONLY IF mode=existing AND codebase available

RULE 5 (default-on v0.2) — IF vault exists AND mode=existing AND codebase detected:
    → chain: drift-detect → resolve-oq (scope=p1-only, only if vault-side actions queued)

RULE 6 (default-on v0.2) — IF vault exists AND mode=new AND mode_migrate_after trigger has fired:
    → chain: vault-diff with mode flip prompt OR manual edit instruction → resolve-oq (only if new P1s introduced)
      (only if trigger is auto-detectable — e.g., "first commit on main")

RULE 7 (unchanged) — IF nothing matched:
    → STOP, surface "no vault or PRD found, or no actionable state — point me at a PRD or vault dir"
```

**Default-on behavior change** (v0.1 → v0.2): Rules 1, 2, 4, 5, 6 previously had opt-in / conditional chaining for `resolve-oq` and `drift-detect`. v0.2 makes those chains default-on. User skips via `Edit plan: skip N` in the Step 3 confirmation. Friction shifts from "remember to opt in" to "edit out if not wanted." Plan-confirmation step still surfaces full chain before any skill runs.

**Hard cap**: max 3 skills per chain. If the matrix produces more than 3, surface and ask for explicit confirmation before proceeding.

**Lifecycle order is fixed**: generate → diff → resolve → drift. Never out of order.

### Step 3: Present plan + single confirmation

Format the plan per this template (placeholders filled from Step 1 findings):

```
mega-sdd:orchestrate-flow — proposed chain

Detected state:
  • Vault: <path> (v<version>, mode=<new|existing>, output_mode=<compact|full>, prd_status=<draft|final>)
  • PRD source on file: <filename> (vault was generated from this)
  • New PRD candidate: <filename> (<reason: different filename → new revision | same filename, different version | etc.>)
  • vault.json: <present (in sync) | missing (will regenerate) | stale (vault older than json)>
  • Unresolved P1 OQs: <count>
  • Codebase: <detected (<framework>) | not detected (mode=<x>, no codebase signals in CWD)>

Plan (<N> steps):
  [1] <skill-name> <args>
        Why: <rule-derived reason>
        --auto mode: <yes | NO (always interactive — captures stakeholder answers)>
        <skill-specific note>

  [2] <skill-name> ...
        Why: <conditional rationale>
        ...

  [3] <skill-name> — SKIPPED
        Why: <why this rule didn't fire>

Proceed? [y / edit / cancel]
```

Use a single `AskUserQuestion` with three options:

- **`Run as proposed`** (default) — execute the chain.
- **`Edit plan`** — accept free-text input. v0.1 supports only `skip step N` and `stop after step N`. Anything else → ask for clarification, then re-confirm.
- **`Cancel`** — exit, no actions taken.

If user picks **Edit plan** with valid syntax (`skip 2` / `stop after 1`), apply the edit silently and re-display the modified plan with another single `AskUserQuestion` (`Run / Edit again / Cancel`).

### Step 4: Execute chain

For each confirmed step, in order:

1. Echo the step header: `[Step N/M] <skill name> — starting`
2. Dispatch the sub-skill via the `Skill` tool, passing args + `--auto` flag where applicable. **Sub-skills that don't have `--auto` (`resolve-oq` for substance, but `--auto` still skips its logistical prompts) are dispatched with the same flag — each sub-skill decides what `--auto` means for itself.**
3. Capture sub-skill outcome:
   - **DONE** → log one-line summary, move to next step.
   - **DONE_WITH_CONCERNS** → log summary + concerns, continue.
   - **BLOCKED** → log error, stop chain.
   - **`blocker` artifact emitted** (any `type`) → log summary, pause chain, capture YAML for the final summary.
4. After each step, append a one-line summary for the final report.

**No re-prompts between steps.** Sub-skills handle their own substance prompts.

**Two exceptions where the chain pauses for human input:**

- **`resolve-oq` step**: this skill is *always* interactive on per-OQ choices (substance prompts). Orchestrator hands off; resolve-oq prompts as normal; control returns when resolve-oq's Step 5 finishes. The chain continues from there.
- **Sub-skill emits `blocker` (any type) in `--auto`**: orchestrator catches it, surfaces the YAML in chat verbatim (don't paraphrase, don't drop fields), pauses chain at this step. Final summary marks the step ⏸. User can resume by re-invoking `flow` after manual fix.

### Step 5: Final summary

**Always emit, regardless of completion or pause.**

```
flow <complete | paused | failed>

Steps executed:
  ✓ [1] <skill-name>: <one-line outcome>
  ⏸ [2] <skill-name>: <partial outcome — paused on blocker / user exit>
  – [3] <skill-name>: skipped (<reason>)

Vault state: <path> (v<version>)
Unpushed commits: <count>
Pending blockers: <count + summary, e.g. "3 P1 OQs unresolved · 1 DIFF_CONFLICT in 05-decisions">
Next suggested step: <heuristic-only suggestion>
```

The "Next suggested step" line is a heuristic — **never auto-executed**. It's a hint for the user to act on if they want.

If any blockers were emitted during the chain, append the verbatim YAML(s) below the summary:

```
Blockers surfaced:

blocker:
  type: ...
  tag: ...
  ...

(repeat for each blocker)
```

## Decision matrix (deterministic — Step 2 detail)

The 7 rules above are the canonical statement. Implementation notes:

- **Rule precedence**: rules are checked top-to-bottom; first match builds the base step. Conditional chains (Rule 2's "+ resolve-oq if new P1s", Rule 5's "+ resolve-oq if vault-side actions") add subsequent steps to the base.
- **Inference must be cheap**: Step 1 reads files, runs grep, runs `git log` once. Don't run sub-skills speculatively to predict their output.
- **Estimates are best-effort**: "vault-diff likely introduces N new P1 OQs" is a heuristic from PRD-content delta inspection. Surface the estimate but don't block on its accuracy.
- **Rule 7 is the safety net**: if no rule fires, STOP cleanly. Don't propose nothing — surface the empty state.

## --auto dispatch semantics

When `flow` dispatches a sub-skill, it passes the `--auto` flag along with skill-specific args. Each sub-skill defines its own `--auto` semantics — see each skill's §--auto-flag section. Common contract:

- `--auto` skips **logistical** prompts (paths, modes, scopes, format choices that have a defensible default).
- `--auto` NEVER skips **substance** prompts (stakeholder answers, conflict resolutions, content-affecting choices).
- `--auto` NEVER auto-fills content (no inventing answers, no auto-resolving conflicts).
- `--auto` HALTS with structured `blocker` artifact when blocked.

`flow` is the canonical caller of `--auto`. Other autonomous callers (CI tasks, agent runners) can also pass `--auto`; the contract is uniform.

## Halt handling

The orchestrator catches `blocker` artifacts (per `references/vault-contract.md` §halt-protocol). Three types:

- **`oq_blocker`** — sub-skill hit an unresolved P1 OQ that blocks downstream work.
- **`diff_conflict`** — `vault-diff` hit a Resolved-OQ or Decision conflict needing user input.
- **`drift_framework_mismatch`** — `drift-detect` found a framework mismatch needing user confirmation.

When caught:

1. Pause chain at the step that emitted.
2. Surface the YAML in chat **verbatim** (don't paraphrase, don't drop fields, don't reformat).
3. In Step 5 final summary, mark the step ⏸ (paused) and append the YAML in the "Blockers surfaced" section.
4. Suggest the appropriate resolution path:
   - `oq_blocker` → re-invoke `flow` after stakeholder follow-up; `resolve-oq` will pick up the OQ.
   - `diff_conflict` → re-invoke `vault-diff` directly (without `--auto`) to walk the conflict interactively.
   - `drift_framework_mismatch` → manual investigation; vault may have been generated against a different repo.

## Quality bar

- **Inspectability**: user sees the proposed chain before any sub-skill runs. No silent multi-skill execution.
- **Stateless**: no `.gds-state.json`. Resumption = re-invoke `flow`. Each call re-inspects CWD.
- **Hands-off mid-chain**: once a chain is confirmed, orchestrator only pauses for substance prompts (resolve-oq's per-OQ choices) or `blocker` artifacts. Logistical prompts never fire.
- **No content invention**: orchestrator emits no vault content. Routing only.
- **Anti-halu preserved by composition**: every anti-halu rail lives in a sub-skill. Orchestrator is a thin layer over them.

## What `flow` does NOT do

- ❌ Auto-resolve OQs (`resolve-oq` stays fully interactive on substance).
- ❌ Auto-pick a side on conflicts (`vault-diff` emits `blocker`; orchestrator pauses).
- ❌ Generate content of any kind.
- ❌ Modify the vault directly — only sub-skills do that.
- ❌ Persist state (no `.gds-state.json`). Resumption = re-running `flow`.
- ❌ Push to remote.
- ❌ Run skills in parallel (sequential only — sub-skills may race on the vault otherwise).
- ❌ Override an existing skill's substance behavior — `--auto` is a skip-logistics flag, not a bypass.

## When to push back on the user

### Always

- **No vault and no PRD detected** → STOP, ask for an explicit path. Don't guess.
- **User says "auto-resolve all conflicts"** → refuse. The orchestrator routes; conflicts halt; humans decide.
- **User picks Edit plan with malformed syntax** → ask for clarification, then re-confirm. Don't apply ambiguous edits.
- **More than 3 skills in proposed chain** → surface and ask for explicit confirmation. Hard cap.

### Conditional

- **mode=new vault and `mode_migrate_after` trigger appears to have fired but flag is ambiguous (e.g., "sprint-1 demo")** → ask the user, don't auto-flip.
- **Multiple new PRD candidates in WORK_DIR** → surface them in the plan, ask user which one is canonical.
- **Vault is LOCKED** → refuse to proceed in `--auto` for any step that would unlock it. Sub-skills handle this individually; orchestrator just doesn't override.

## References

- Schema, OQ conventions, halt protocol: `../grand-design-spec/references/vault-contract.md` (§schema, §OQ-conventions, §halt-protocol).
- Sub-skill behavior contracts:
  - `../grand-design-spec/SKILL.md` (vault generation + §--auto-flag)
  - `../resolve-oq/SKILL.md` (OQ resolution + §--auto-flag)
  - `../vault-diff/SKILL.md` (vault evolution + §--auto-flag + diff_conflict blocker)
  - `../drift-detect/SKILL.md` (drift detection + §--auto-flag + drift_framework_mismatch blocker)
