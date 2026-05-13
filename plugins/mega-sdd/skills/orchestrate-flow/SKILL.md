---
name: orchestrate-flow
version: 1.0.0
description: Multi-skill lifecycle orchestrator for mega-sdd. Inspects CWD, proposes a chain of sub-skills (generate-intent / scan-codebase / bind-codebase / generate-units / execute-bolts / resolve-oq / detect-drift / diff-vault), confirms once, then executes the chain in --auto mode. Triggers — "orchestrate", "run flow", "auto mega-sdd", "do the next thing", "what's next", or paraphrases.
---

# Orchestrate-Flow — Lifecycle Orchestrator

**Announce at start:** "I'm using the orchestrate-flow skill to inspect CWD and propose the next phases."

## When to use

- "run the flow" / "auto mega-sdd" / "do the next thing"
- "what's next" / "orchestrate"
- After completing one phase, user wants automatic transition

## Procedure

1. **Parse args.** Persist `WORK_DIR`, optional `--from=<phase>`, `--to=<phase>`.

2. **Deterministic CWD inspection** per `references/routing-rules.md` §CWD inspection. Output a state snapshot:
   ```
   prd: present | absent
   vault: present | absent (path: ...)
   bound_vault: present | absent
   units: N
   bolts: N
   codebase_map: present | absent
   git_repo: yes | no
   oq_p0_p1_count: N
   mode_inferred: greenfield | brownfield
   ```

3. **Build proposed chain** per `references/routing-rules.md` §Decision matrix. Hard cap 3 sub-skills.

4. **First-run pre-flight (only if chain includes execute-bolts):**
   - Check superpowers OR `_vendored/` availability
   - If neither → propose install command, halt chain proposal

5. **Present plan + single `AskUserQuestion`** (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only.

6. **Execute chain.** Dispatch sub-skills with `--auto` flag. Pause on blocker artifacts (any type) per `vault-contract.md` §halt-protocol. `resolve-oq` step is always interactive on per-OQ choices.

7. **Emit final summary** with completed/paused/skipped per step + verbatim blocker YAMLs if any.

## Hard rails

- No content generation by the orchestrator itself.
- No state file (resumption = re-invoke `orchestrate-flow`).
- No skill runs in parallel.
- Sub-skill substance prompts ALWAYS surface to human.
- Chain depth ≤ 3 (user can chain again after).

## Greenfield vs Brownfield routing

Per `references/routing-rules.md` §Greenfield vs brownfield detection.

## Mode-migration

If CWD signals say "brownfield" but vault says `mode: greenfield` (or vice versa):
- Halt
- Emit mode-migration prompt — user chooses to update vault or re-detect

## Flags

- `--from=<phase>`: resume from a specific phase (skip earlier phases even if state says they're needed)
- `--to=<phase>`: stop at a specific phase (do not chain beyond it)
- `--dry-run`: show proposed chain without executing
