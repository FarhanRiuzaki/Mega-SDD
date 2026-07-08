# Autonomy Layer — Iter 4

**Status**: Proposed (design only; execution sequenced AFTER Iter 1 validation + Iter 2/3 ship)
**Date**: 2026-05-20
**Author**: Farhan Riuzaki (via Claude collaboration)
**Builds on**: `2026-05-20-extract-intelligence-skill-design.md`, `2026-05-20-tech-oq-autoresolve-design.md`
**Targets**: `orchestrate-flow`, `using-mega-sdd`, every skill's handoff message format; new command `/mega-sdd:auto`
**Plugin versions affected**: 1.7.0 → 2.0.0 (major bump — new top-level entrypoint + cap-lift considered breaking-ish for users relying on 3-skill cap behavior)

---

## 1. Motivation (from user-stated vision)

> "secara pemahaman dan penggunaan, skill ini ingin di gunakan sebagai agent2 yang bisa jalan sesuai kebutuhan dan auto use agent yg diperlukan… secara flow itu nantinya gue bisa upload prd yang nanti akan di jadikan sebagai vault. dari vault itu bisa generate unit… lalu menurut gue legacy code bisa di jadikan sebagai vault juga… maksudnya pasti ujungnya dari hasil extract akan di jadikan project juga."

Decoded:

1. **Skills = agents** — Claude should pick the right one from context, not require user to memorize command sequences.
2. **PRD upload → vault → units** — happy path should feel like one motion, not three.
3. **Legacy code → eventually rebuild** — flow ergonomics from `extract-intelligence` to vault to units should be one motion.

The user explicitly accepted (during this design conversation) that **KB and Vault schemas stay separate** (KB = AS-IS / archaeologist audience; Vault = TO-BE / architect audience). What Iter 4 polishes is the **flow** between them — not the data shape.

## 2. Critical Assessment

### 2.1 Where the vision is right

- ✅ Skill-as-agent ergonomics — Claude Code already supports this via Skill tool + skill descriptions. The pieces exist; they just aren't fully connected end-to-end.
- ✅ "One motion" pipeline — the current 5-skill chain `extract → generate-intent → bind → generate-units → execute-bolts` is too many manual command invocations for a smooth UX. Even with `orchestrate-flow`, the 3-skill cap forces re-invocation mid-pipeline.
- ✅ Autonomous through clean paths — when no blockers exist, asking the user to confirm at every handoff is friction without value.

### 2.2 Where to push back

- ⚠️ **Autonomy ≠ no halts**. Anti-halu rails MUST still halt on:
  - CONFLICT in binding
  - Unresolved P0/P1 business OQs (post-Iter 2)
  - `dedup_ambiguous` / `hard_rule_violated` / `cross_squad_*` blockers
  - Mode-migration prompts
  - Destructive overwrite confirmations
  Iter 4 makes the **clean path** silent, NOT the broken path.
- ⚠️ **Confirmation-once vs confirmation-zero**. Even in autonomy mode, the user MUST confirm the initial plan (this chain WILL run; press y/n). Skipping that opens "I didn't realize you'd touch X files" territory. Confirm once = OK. Confirm zero = unsafe.
- ⚠️ **Schema collapse temptation**. User accepted "keep separate". Iter 4 MUST NOT merge KB into vault under the guise of "ergonomics". The flow is auto-chained; the documents stay distinct.

### 2.3 What this is NOT

- NOT a new pipeline (5-skill chain stays).
- NOT a relaxation of anti-halu rails (every existing halt-condition fires identically).
- NOT a way to bypass binding gate / OQ resolution / hard-rule violations.
- NOT a replacement for `orchestrate-flow` (which becomes the engine under Iter 4's hood).
- NOT a unified KB+Vault schema (decision locked: keep separate).

## 3. Goals + Non-goals

### Goals

1. User invokes ONE command (or natural-language prompt) and the full mega-sdd pipeline runs end-to-end where state is clean.
2. Skill-to-skill handoffs are auto-continued; no manual re-invocation between phases.
3. `using-mega-sdd` auto-routes to autonomous orchestration when CWD signals are strong (e.g., legacy codebase + intent to build).
4. Halt-protocol behavior unchanged. Every existing blocker still fires.
5. User can override autonomy at any point (`--manual`, `--step=<phase>`, `--stop-after=<phase>`).
6. Backward compatibility: existing 3-skill `orchestrate-flow` invocation still works exactly as today.

### Non-goals

- Replacing the 3-skill cap entirely (it stays as the DEFAULT; deep-chain is opt-in).
- Removing per-phase artifact inspection (user can still browse vault.json, binding.md, units/ between phases).
- Auto-deciding business OQs (they remain human-decided post-Iter 2).
- Schema-level collapse of KB + Vault (locked decision).

## 4. Design Pillars

Iter 4 lands as four coordinated changes. Each is small individually; together they realize the vision.

### Pillar 1 — Deep-chain mode in `orchestrate-flow`

Current behavior: chain capped at 3 sub-skills per single confirmation.

New behavior: `--deep` flag lifts the cap. Chain extends to pipeline-end (any number of skills) when state is clean.

#### Routing rules extension (`references/routing-rules.md`)

Add to the decision matrix:

| State | `--deep=false` (default) chain | `--deep=true` chain |
|---|---|---|
| Legacy + no PRD + no vault + rebuild intent | `extract-intelligence` → `generate-intent --kb` (2 skills, cap) | `extract-intelligence` → `generate-intent --kb` → `scan-codebase` → `bind-codebase` → `generate-units` → `execute-bolts` (6 skills) |
| PRD present + no vault | `generate-intent <prd>` → `scan-codebase` → `bind-codebase` (3 skills, cap) | `generate-intent <prd>` → `scan-codebase` → `bind-codebase` → `generate-units` → `execute-bolts` (5 skills) |
| Vault present, no bound-vault | `bind-codebase` → `generate-units` → `execute-bolts` (3 skills, cap, already at cap) | Same 3 skills (no change — pipeline tail) |

#### Confirmation behavior

Even in `--deep` mode, ONE upfront confirmation:

```
Proposed pipeline (--deep):
  1. extract-intelligence ./legacy-php/  → docs/knowledge-base/
  2. generate-intent --kb=./docs/knowledge-base/  → docs/mega-sdd/vaults/<slug>/
  3. scan-codebase                       → codebase-map.md
  4. bind-codebase ./vaults/<slug>/      → binding.md + bound-vault/
  5. generate-units ./vaults/<slug>-bound/  → units/U-*.md
  6. execute-bolts --all                 → bolts/U-*/bolt-report.md

Run all 6 phases end-to-end? Halts auto-fire on blockers (CONFLICT, OQ-business, hard-rule violations, mode-migration).

[Run] [Edit] [Cancel]
```

Edit options: same as today — `skip step N`, `stop after step N`. Plus new `step-mode` (revert to manual handoffs after step N).

#### Halt behavior in deep mode

Identical to current. Pipeline pauses on any blocker YAML. User resolves, then re-invokes `orchestrate-flow --deep --resume` to continue.

**Anti-halu invariants** (NOT relaxed):
- Binding CONFLICT → halt; bound-vault not produced
- Business OQ (post-Iter 2) → halt if `--strict` or P1; else recorded and flagged in chat
- `dedup_ambiguous` → halt
- `hard_rule_violated` (post-Iter 3) → halt
- Cross-squad ambiguity → halt
- Quality-gate failure (extract-intelligence) → halt

### Pillar 2 — Auto-continue handoffs

Currently each skill ends with a chat message like:
> "Generated 7 units. Suggested next: `/mega-sdd:execute-bolts --all`."

The user reads that and types the next command. In autonomy mode, that's friction.

#### Mechanism

Every skill emits a structured **handoff record** in its final output (markdown chat AND as a YAML block parseable by orchestrate-flow):

```yaml
handoff:
  emitted_by: <skill-name>
  status: completed | paused | halted
  artifacts:
    - <absolute path to primary output>
  next_action:
    suggested_skill: mega-sdd:<next-skill>
    suggested_args: ["--flag=value", "positional-arg"]
    rationale: "<1-sentence why this is next>"
  blockers: []   # empty when completed; populated when paused/halted (per halt-protocol)
```

`orchestrate-flow` running in deep mode reads this record and auto-invokes the next skill if `status: completed` AND `blockers: []`.

If invoked outside `orchestrate-flow` (user typed `/mega-sdd:generate-units` directly), handoff is informational only — same as today's chat hint.

#### Backward compatibility

Handoff record is additive — chat-side hints stay (humans still read them). Pre-Iter-4 callers that don't parse the YAML continue to work; they just don't get auto-continue.

### Pillar 3 — Sharper `using-mega-sdd` auto-trigger

Currently `using-mega-sdd` triggers Skill-tool invocation on:
- Explicit `/mega-sdd:<command>`
- Specific keywords (intent, vault, unit, bolt, …)
- CWD signals (docs/mega-sdd/, vaults/, codebase-map.md, knowledge-base/, …)

In autonomy mode, the trigger needs to be **more decisive**: when CWD signals say "clear next step", `using-mega-sdd` should invoke `orchestrate-flow --deep` (proposing the chain) WITHOUT requiring the user to mention any mega-sdd vocab.

#### Trigger upgrade rules

| CWD signal | Current behavior | Iter 4 behavior |
|---|---|---|
| Legacy codebase + user uploads a PRD or types a brief | Wait for explicit invocation | Auto-invoke `orchestrate-flow --deep` proposing the legacy-rebuild chain |
| Vault present but no units | Wait for explicit invocation | Auto-invoke `orchestrate-flow --deep` proposing the unit-generation chain |
| Bound-vault present + units present + no bolts | Wait for explicit invocation | Auto-propose `execute-bolts --all` (single-skill chain) |
| Codebase + no other signals + user mentions "rebuild" | Trigger on keyword | Auto-invoke `orchestrate-flow --deep` |
| User uploads a file matching `*PRD*.{md,pdf,docx}` | Wait for "/mega-sdd" command | Auto-detect, propose `generate-intent <file>` chain |

`using-mega-sdd` becomes a smarter front door — but each auto-invocation still triggers `orchestrate-flow`'s upfront confirmation. The user always sees "here's the chain I propose — Run / Edit / Cancel" before any work happens.

### Pillar 4 — One-shot `/mega-sdd:auto` entrypoint

A new top-level slash command that wraps the autonomy layer in a single invocation.

```
/mega-sdd:auto <input>
```

Where `<input>` can be:
- A path to a PRD file (.md / .pdf / .docx)
- A path to a legacy codebase directory
- A path to an existing vault (skips to binding/units/bolts)
- A free-text brief (quoted)
- Omitted → CWD inspection drives the chain

#### Input detection rules

```
1. Is <input> a path to a directory?
   - Does it contain code files (.{js,ts,php,py,rs,go,java,…})?
     - YES → legacy codebase → propose extract-intelligence chain
     - NO  → does it contain vault.json?
       - YES → existing vault → propose binding/units chain
       - NO → halt; ask user to clarify
2. Is <input> a path to a file?
   - Extension .{md,pdf,docx,txt}? → likely PRD → propose generate-intent chain
   - Extension .json with vault schema? → vault file directly → propose binding/units chain
   - Other → halt; ask user
3. Is <input> quoted free-text?
   - YES → Mode B brief → propose generate-intent --from-prompt chain
4. Is <input> empty?
   - YES → CWD inspection via orchestrate-flow's routing-rules → propose detected chain
```

After detection, `/mega-sdd:auto` invokes `orchestrate-flow --deep --auto` with the right starting point and arguments. ONE confirmation upfront, then end-to-end execution.

#### Flag surface

- `--deep` (default true for `auto`; can disable with `--shallow` to revert to 3-skill cap behavior)
- `--step-after=<phase>` — switch to manual handoffs after this phase (e.g., `--step-after=bind-codebase` to review binding before continuing)
- `--stop-after=<phase>` — halt after this phase even if no blocker
- `--resume` — continue a paused pipeline (read state from last skill's handoff YAML)
- `--manual` — disable autonomy entirely; revert to current per-skill explicit-command behavior

## 5. Halt Protocol — Preserved (mandatory)

Iter 4 makes the pipeline more autonomous BUT preserves every halt-condition. The structural list:

| Halt type | Emitted by | When | User action |
|---|---|---|---|
| `mode_migrate` | orchestrate-flow | CWD signals don't match vault.mode | Confirm mode then re-run |
| `bind_conflict` | bind-codebase | Vault claim contradicts code | Resolve via resolve-oq or edit vault |
| `dedup_ambiguous` | generate-units | Create unit targets existing files | Manually edit task_type or rename targets |
| `cross_squad_dep_invalid` | generate-units | Cross-squad direct depends_on | Route via interface notes |
| `interface_ref_missing` | generate-units | Dangling consumes/produces_interfaces | Author the interface file |
| `cross_squad_ambiguous` | generate-units | Two squads claim same artifact | Refine squads.yaml |
| `cross_squad_interface_draft` | execute-bolts | Consumer waits for producer to lock interface | Producer squad runs first |
| `hard_rule_violated` (post-Iter 3) | execute-bolts | Bolt pre/post scan detects rule violation | Revert or modify rule |
| `oq_business_p1_unresolved` (post-Iter 2) | bind-codebase | P1 business OQ blocks downstream | Resolve via resolve-oq |
| `quality_gate_failed` | extract-intelligence | Wave gate grep check fails twice | Re-dispatch agent or accept gap as [OPEN] |

In deep mode + autonomy mode, ANY of these halt-conditions pauses the chain immediately. Chat surfaces the blocker YAML verbatim. User resolves, then runs `/mega-sdd:auto --resume`.

## 6. CLI Surface

### New commands

```
/mega-sdd:auto [input] [--deep|--shallow] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual]
```

### Modified commands

```
/mega-sdd:orchestrate-flow [--from=<phase>] [--to=<phase>] [--dry-run]
  + [--deep] (NEW)        # lift 3-skill cap; chain to pipeline-end when clean
  + [--resume] (NEW)      # continue paused chain from last handoff
```

### Slash-command file

New: `plugins/mega-sdd/commands/auto.md`

```markdown
---
description: One-shot autonomous pipeline. Detects input shape (PRD / legacy / vault / brief), runs the full mega-sdd chain end-to-end with single upfront confirmation. Halts on blockers; resume via --resume.
argument-hint: [input] [--deep|--shallow] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual]
---

Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` flags + detected starting phase.

User arguments: $ARGUMENTS

Argument parsing per design spec §6 (input detection rules):
- Directory with code files → extract-intelligence chain
- Directory with vault.json → bind-codebase chain
- .md/.pdf/.docx file → generate-intent chain (Mode A)
- Quoted free-text → generate-intent --from-prompt chain (Mode B)
- Empty → CWD inspection drives chain

Follow `skills/orchestrate-flow/SKILL.md` procedure with `--deep` semantics from `references/routing-rules.md` §Deep-chain mode.

Hard rails:
- ONE upfront confirmation showing the full proposed chain (per skill, per arguments).
- All existing halt-protocol blockers fire identically.
- `--manual` flag disables autonomy entirely; reverts to per-skill explicit invocation.
- Anti-halu invariants preserved: binding gate non-negotiable, OQ-business stays human-decided, dedup_ambiguous halts on conflict.
```

## 7. Backward Compatibility

| Existing workflow | Iter 4 behavior |
|---|---|
| `/mega-sdd:orchestrate-flow` (no `--deep`) | Identical to today — 3-skill cap, same routing |
| `/mega-sdd:<specific-skill>` (direct invocation) | Identical to today — skill runs, prints chat hint for next step; no auto-continue (unless invoked under deep-mode orchestrate-flow) |
| Existing per-skill `--auto` flag | Unchanged behavior |
| Existing handoff messages | Preserved (chat-side); handoff YAML record added (additive, ignored if not parsed) |
| Trigger keywords in `using-mega-sdd` | Preserved; new auto-route signals are additive |
| CWD without mega-sdd artifacts | No auto-trigger; conversation behaves normally |

## 8. Test Coverage

New tests in Iter 4 execution PR (not part of this design):

- `tests/skill-triggering/auto.test.md` — input detection rules (E1-E5 trigger cases) + flag handling + halt-on-blocker behavior
- `tests/integration/e2e-autonomy-clean.test.md` — full pipeline (legacy → bolt) on a brownfield fixture with NO blockers; expect end-to-end execution with single confirmation
- `tests/integration/e2e-autonomy-halt.test.md` — pipeline halts on injected blocker; user runs `--resume` to continue
- `tests/skill-triggering/orchestrate-flow.test.md` (update) — add `--deep` case + `--resume` case
- `tests/skill-triggering/using-mega-sdd.test.md` (update) — add auto-trigger cases (PRD file upload detection, legacy-codebase signal, etc.)

## 9. Open Design Questions

These need user decision before Iter 4 execution kicks off. Marked [AUTONOMY-OQ].

- **[AUTONOMY-OQ-1] Confirmation granularity in `--deep` mode**: ONE upfront confirmation for the full chain is the default proposal. Alternative: also confirm before destructive phases (`execute-bolts` writes code). Recommendation: single upfront confirmation lists ALL phases (including bolts); bolts have their own existing safety (target_files whitelist, hard rules). User concur?

- **[AUTONOMY-OQ-2] Resume mechanics**: When chain halts on blocker, what state is persisted? Options: (a) infer from CWD artifacts (no state file — current orchestrate-flow philosophy); (b) write `.mega-sdd-autonomy-state.json` with the proposed chain + cursor position. Recommendation: (a) — pure CWD-driven. Resume re-runs CWD inspection; if same chain proposed, resumes from cursor.

- **[AUTONOMY-OQ-3] using-mega-sdd auto-invoke aggressiveness**: How "decisive" is too decisive? When user types "fix the bug" in a directory that happens to have a vault, do we trigger orchestrate-flow? Recommendation: trigger ONLY when the user prompt contains mega-sdd intent keywords (build/spec/units/vault/rebuild) OR is empty (e.g., "lanjut", "next", "ok"). General questions don't auto-trigger.

- **[AUTONOMY-OQ-4] Multi-phase progress indication**: In `--deep` mode the pipeline could take minutes to hours. Should there be incremental progress indication (e.g., emit "Phase 3 of 6 starting: bind-codebase…")? Recommendation: yes — emit a one-line phase header before each skill invocation; emit a one-line phase summary after.

- **[AUTONOMY-OQ-5] Skill-side handoff YAML emission**: Iter 4 requires every skill to emit the handoff YAML. That's 8 skills to update. Alternative: handoff YAML only required for `--auto`-invoked skills (called by orchestrator); standalone runs skip it. Recommendation: only required under `--auto` (avoids polluting standalone-invocation chat).

- **[AUTONOMY-OQ-6] Plugin version bump scope**: Iter 4 is a major version bump (2.0) per the design. Is that justifiable? Recommendation: yes — new top-level command + cap-lift + auto-invoke semantics in `using-mega-sdd` collectively justify a major bump. Lo OK?

- **[AUTONOMY-OQ-7] Legacy rebuild = always new project dir?**: When `/mega-sdd:auto ./legacy-php/` runs the chain, where does the new project go? Same dir? Sibling dir? `--out=<path>` flag? Recommendation: require explicit `--out=<path>` for legacy-rebuild chains (because conflating extract output + rebuild dir is dangerous). The `extract-intelligence` skill already writes to `docs/knowledge-base/` (configurable via `--out`); the rebuild project location is a separate decision. Lo confirm?

## 10. Validation Plan

When Iter 4 ships, validate against three scenarios:

### Scenario A — Legacy rebuild end-to-end
- Fixture: existing trade-finance legacy PHP at `./tradefinance/`; no PRD; intent to rebuild on Laravel
- Run: `/mega-sdd:auto ./tradefinance/ --out=./tradefinance-rebuild/`
- Expect: 6-phase chain proposed; user confirms; runs to bolts phase (or halts on quality-gate / OQ-business if any)
- Time bound: ~3-4 hours wall-clock for ~600-file legacy (per extract-intelligence validation)

### Scenario B — PRD upload → vault → units
- Fixture: `prd-leave-management.md` (PRD for a new feature in an existing app)
- Run: `/mega-sdd:auto ./prd-leave-management.md`
- Expect: 5-phase chain (generate-intent → scan → bind → units → bolts); single confirmation; runs through

### Scenario C — Resume after blocker
- Fixture: Scenario B's pipeline interrupted at bind-codebase by injected CONFLICT
- Run: blocker surfaces; user resolves via `/mega-sdd:resolve-oq`; runs `/mega-sdd:auto --resume`
- Expect: pipeline resumes from generate-units (next phase after bind-codebase) without re-running earlier phases

## 11. Execution Sequencing

This spec is design-only. Iter 4 execution depends on:

1. **Iter 1 (DONE 2026-05-20)** — Implementation-State Classification + task_type. Provides clean signal for "is this work already done".
2. **Iter 2 (designed, not executed)** — Tech-OQ auto-resolve via scan/recommend. Reduces noise so autonomy chain doesn't drown in tech OQs.
3. **Iter 3 (designed, not executed)** — Hard rules + bolt-time validation. Makes `execute-bolts` safe to run autonomously.
4. **Iter 4 (THIS spec)** — Autonomy layer. Builds on the foundation laid by Iters 1-3.

Iter 4 execution would happen as a separate PR after Iters 2+3 ship. Estimated 1-2 days of dev work (8 skills touched, 1 new command, 5 new tests).

Iter 4 CAN be partially shipped early — Pillars 1+4 (`--deep` mode + `/mega-sdd:auto` entrypoint) provide ~70% of the value and don't require Iters 2+3. Pillars 2+3 (handoff YAML + sharper auto-trigger) benefit from but don't require Iter 2/3 plumbing.

## 11.5 Amendment (2026-07-05): conflict-resolution recovery routing is ACTION-MIX, not a blanket re-bind

§5's halt protocol routes a `bind_conflict` halt to `resolve-oq` for recovery. The recovery hop AFTER resolution is **action-mix dependent** — a fact later established in `resolve-oq/references/binding-mode.md` Step 5 and the `convergence-loops.md` Cycle-eligible table, but never propagated to the surfaces that consume the recovery. A CONFLICT is resolved by one of four actions:

- **KEEP_CODE / SPLIT** — the vault was edited to match code → **re-run `bind-codebase`** (the edited claim now binds cleanly).
- **KEEP_VAULT / DEFER** — vault AND code unchanged (KEEP_VAULT records a pending code change; DEFER downgrades the CONFLICT to an OQ) → **proceed to `generate-units`**. A re-bind here re-derives verdicts from the *unchanged* vault-vs-code contradiction and **RE-RAISES the identical CONFLICT** (bind never consumes a prior resolution as evidence — memory only *suggests*). The resolution-marked `binding.md` already passes `validate-handoff-binding-units.sh`; `<vault>/bound/` is produced by a *future* re-bind after the code change lands.

**The bug (round-2 seam audit, Theme 1):** four consumer surfaces ignored this action-mix and unconditionally routed KEEP_VAULT/DEFER back to `bind-codebase` (or hard-blocked), so the two most common resolution actions could not complete the pipeline — the chain looped or walled:

1. **resolve-oq's handoff** (`resolve-oq/references/auto-memory-handoff.md`) hardcoded `next_action.suggested_skill: bind-codebase` for every `--binding` resolution → now emits the action-mix hop.
2. **the convergence-loop algorithm** (`convergence-loops.md`) blindly "re-ran the halted skill" on resolver success → now BRANCHES: a resolver routing BACK to the halted skill keeps the retry+check-clear model; a resolver routing FORWARD (KEEP_VAULT/DEFER → generate-units, `status: completed`) EXITS convergence for that halt and rejoins the normal chain (there is no "halt to clear").
3. **the stateless `--resume` routing** (`routing-rules.md`) routed to `bind-codebase` purely on `bound/` absence → now a `binding.md` with NO ACTIVE (unresolved) conflict AND every resolution action KEEP_VAULT/DEFER (zero KEEP_CODE/SPLIT) routes to `generate-units`; a MIXED / KEEP_CODE / SPLIT resolution (the vault WAS edited) falls through to the re-bind row, matching surfaces 1–2. Keyed on the resolution ACTION-MIX + active-conflict state, NOT bare `binding.md` existence (which is written even on the first halted bind — keying on existence would let an UNRESOLVED conflict skip the gate) and NOT "validator green" (which is RED by design for a KEEP_VAULT-only resolution until its code-patch unit exists — see surface 4).
4. **the binding→units validator** (`scripts/validate-handoff-binding-units.sh`) harvested a DEFER-resolved `CONFLICT-N` and demanded a unit citation the DEFER→OQ path never emits → `conflict_id_dropped` hard-blocked execute-bolts. Now Pass 3 is DEFER-resolution-aware: a DEFER-resolved uncited `CONFLICT-N` is an advisory `conflict_id_deferred_uncited` extra, not a blocking drop. **Invariant #2 preserved:** KEEP_VAULT keeps its un-droppable citation obligation; an UNRESOLVED conflict still fires `conflict_unresolved` (Pass 3b untouched); a resolved-but-unknown-action conflict stays fail-closed. The DEFER verdict is read per-conflict-ID, anchored to the resolution marker itself (the heading, else the dedicated `- **Resolution**:`/`- **Status**:` line — the two surfaces Pass 3b reads the marker from), never a free block scan, so a stray `RESOLVED (DEFER)` token in a rationale bullet or a sibling-conflict cross-reference cannot demote a KEEP_VAULT conflict; a same-ID multi-marker resolution is fail-closed (any non-DEFER wins).

Fixtures: `resolve-oq.test.md` BM4-BM6, `orchestrate-flow.test.md` R-FACTORY-4 + RES4, `moat/test-conflict-unresolved.sh` Cases 4-7. Rider (separate, settled): `auto.test.md` HP3 corrected `paused`→`halted` for `--strict` business OQs (bind SKILL.md §5 already halts; the fixture was stale). The `--strict`-business-OQ class is distinct from tech-OQ recommendations (v4.64.0 Batch 1).

## 12. References

- `2026-05-13-mega-sdd-revamp-design.md` — pipeline shape this layer wraps
- `2026-05-13-flow-orchestrator-design.md` — original orchestrate-flow design (Iter 4 extends this)
- `2026-05-20-extract-intelligence-skill-design.md` — KB integration this layer auto-chains
- `2026-05-20-tech-oq-autoresolve-design.md` — Iters 1-3 this layer sits atop
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — current orchestrator (becomes the deep-mode engine)
- `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` — current anchor (gets sharper auto-route rules)
- Superpowers patterns referenced: `dispatching-parallel-agents`, `executing-plans` (for the autonomous-execution mental model)


> **Amendment (2026-07-06, token-efficiency B2/M-04):** the per-hop handoff validation gate is executed by ONE `validate-handoff-yaml.sh --quiet` call per hop (exit code decides; `.handoff-validation-state.json` read only on FAIL) — the prose-executed b.0/b.i/b.ii–b.iii/b.vii checks in `handoff-consumption.md`, including the per-field "lookup TYPE annotation in handoff-contract §<field>" that forced a full contract load every hop, are retired (the orchestrator no longer loads handoff-contract.md to validate). b.iv (conditional-presence) + b.ix (cross-metric) + the confidence floor stay prose (script gaps). The `--legacy-type-bypass` migration flag is retired with the prose type-check; unknown un-annotated fields are warn-only per the validator, known annotations stay hard-checked. The duplicated orchestrator consumption loop in handoff-contract.md is collapsed to a pointer (handoff-consumption.md owns it).
>
> **Review-round follow-up (same date):** the initial rewrite validated only the FIRST `handoff:` block, silently re-opening D3-001 (a sub-skill quoting an upstream handoff before its own emission got the wrong block validated). The validator now extracts ALL blocks: >1 with CONFLICTING `emitted_by` FAILs `handoff_missing`, same-emitter duplicates validate the producer's LAST block. Nested-object **sub-field** types were the residual gap shared by the retired prose and the script; the load-bearing one is closed — `metrics.items_processed` is hard-checked as an int (a non-numeric value used to silently neutralize the downstream `bolt_artifacts_missing` gate). Remaining nested sub-fields stay unchecked (acknowledged residual gap).
