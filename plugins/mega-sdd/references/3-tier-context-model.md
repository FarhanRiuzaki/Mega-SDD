# 3-Tier Context Model — Iter 64+ (v3.44.0)

> Codified per Iter 63 spec §4.0 + post-Iter-63.5 reframe (§4.3 — Iter 66 as MAIN lever for hot-context reduction).
>
> **Iter 64 (this iter):** declarations + initial conservative classifications via `skill-tier-manifest.yaml`.
> **Iter 66 (after soak):** lazy-loading enforcement based on telemetry-validated tiers.

## The 3 tiers

### HOT — always loaded when skill body loads

Content required by EVERY invocation of the skill. No conditional load.

**Examples (conservative initial classification):**
- `vault-contract.md` halt enum + canonical envelope schema — used by every skill that can emit halts
- `handoff-contract.md` field schema — used by every skill emitting handoffs under `--auto`
- Skill body itself (the SKILL.md file)

**Cost model:** loaded on session start via anchor skill (using-mega-sdd) when skill is detected as relevant. Loaded per session, not per turn.

### SPECIALIST — loaded only when specific procedure step requires it

Content needed by a specific subset of invocations or flag combinations. Conditional load triggered by procedure step or input shape.

**Examples (conservative initial classification):**
- `t2-budget-tracker.md` — loaded by execute-bolts ONLY when Step 4.5.a.5 fires (T2 context assembly)
- `saga-rollback.md` — loaded by execute-bolts ONLY when `--rollback` flag set
- `phase-context.md` — loaded by generate-intent ONLY when `--phase=N` flag set
- `os-detection.md` — loaded by install-deps ONLY when Step 1 (detect env) runs
- `tool-matrix.yaml` — loaded by install-deps ONLY in Step 3 (build install plan)

**Cost model:** loaded on-demand during skill execution. Not loaded if procedure path doesn't trigger.

### COLD — loaded only via explicit grep/RAG when user request matches

Content rarely needed in normal flow. Loaded only when user explicitly asks for it OR halt fires that needs the recovery content.

**Examples (conservative initial classification):**
- `tests/scenarios/scenario-6-recovery-from-halt.md` — loaded ONLY when user asks "how to recover from <halt>?"
- `CHANGELOG-ARCHIVE.md` — loaded ONLY when user asks about pre-v3.27.0 history
- Individual scenario walkthroughs — loaded ONLY when user references specific scenario
- `bind-codebase/references/conflict-resolution.md` — loaded ONLY when `bind_conflict` halt fires AND user invokes recovery flow

**Cost model:** loaded via grep/RAG, not via skill body cross-reference. Not loaded on normal flow.

## Decision tree (conservative defaults — Iter 64 baseline)

When in doubt about a ref's tier:

```
1. Does EVERY invocation of the parent skill need this content?
   YES → HOT
   NO  → continue

2. Is this content gated by a flag, a step condition, or input shape?
   YES → SPECIALIST
   NO  → continue

3. Is this content typically only loaded when user explicitly asks for it,
   OR when a halt fires that needs recovery content?
   YES → COLD
   NO  → SPECIALIST (conservative default when uncertain)
```

**Iter 64 directive:** when uncertain between HOT and SPECIALIST, default to SPECIALIST. When uncertain between SPECIALIST and COLD, default to SPECIALIST. Conservative defaults avoid the lazy-loading false-positive risk (relocating content to COLD that's actually HOT = extra latency on every turn).

## Tier validation strategy (Iter 64 → Iter 66 pipeline)

1. **Iter 64 (this iter):** declares initial tier per ref in `skill-tier-manifest.yaml`. Conservative bias toward SPECIALIST.
2. **Soak window (3-4 weeks):** telemetry logs `tier_classification_decision` events per ref load. `loaded_this_session: true|false` captured.
3. **Iter 68 analysis:** aggregates load frequency per ref. Flags tier mismatches:
   - Declared HOT but loaded <50% of sessions → reclassify SPECIALIST
   - Declared SPECIALIST but loaded >95% of sessions → reclassify HOT
   - Declared COLD but never loaded in 14-day window → confirm COLD
4. **Iter 66 enforcement:** updates manifest with empirically-validated tiers. Skill body cross-refs updated to load-conditional pattern.

## What this iter does NOT enforce yet

Iter 64 ships the DECLARATIONS only. Skill bodies in Iter 64 still load all refs unconditionally as before. Lazy-loading enforcement = Iter 66 (after soak data).

**No hot-context win claims at Iter 64.** Iter 64 = data collection foundation.

## Cross-references

- `plugins/mega-sdd/references/telemetry-schema.md` — telemetry event schema (consumes tier_classification_decision)
- `plugins/mega-sdd/references/skill-tier-manifest.yaml` — per-skill tier classifications (Iter 64 baseline)
- `plugins/mega-sdd/CLAUDE.md` — process integration (when skills should log tier_classification_decision events)
- spec §4.3 (Iter 66) — lazy-loading enforcement design (deferred to post-soak)
- spec §9.4 (NEW metric) — `lines_loaded_per_turn` / `tokens_loaded_per_turn` consumes tier data
