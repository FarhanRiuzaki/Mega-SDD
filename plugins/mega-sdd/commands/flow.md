---
description: Multi-skill lifecycle orchestrator. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms once, then executes in --auto mode.
argument-hint: [optional vault-path or PRD-path]
---

Invoke the `grand-design-spec:flow` skill via the Skill tool to orchestrate a lifecycle round across the grand-design-spec sub-skills.

User arguments (vault-path, PRD-path, or empty for CWD auto-detect): $ARGUMENTS

Follow the skill exactly:

- Step 0: parse args, persist `WORK_DIR`, `EXPLICIT_VAULT_PATH`, `EXPLICIT_PRD_PATH`.
- Step 1: deterministic CWD inspection (vault detection, PRD detection, vault metadata, codebase signals, P1 count, mode-migration trigger, git state).
- Step 2: build proposed chain via the 7-rule decision matrix. Hard cap of 3 skills.
- Step 3: present plan + single `AskUserQuestion` (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only.
- Step 4: execute chain by dispatching sub-skills with `--auto` flag. Pause on `blocker` artifacts (any type) per vault-contract.md §halt-protocol. `resolve-oq` step is always interactive on per-OQ choices.
- Step 5: emit final summary with completed/paused/skipped per step + verbatim blocker YAMLs if any.

Hard rails:
- No content generation by the orchestrator itself.
- No state file (`.gds-state.json` is explicitly out of scope — resumption = re-invoke `flow`).
- No skill runs in parallel.
- Sub-skill substance prompts (per-OQ choices, conflict resolutions) ALWAYS surface to human.
