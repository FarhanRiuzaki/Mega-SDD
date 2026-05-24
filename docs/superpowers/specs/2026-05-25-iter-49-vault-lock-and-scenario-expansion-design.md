# Iter 49 — vault.json Advisory Lock + Scenario-6 Expansion Design

**Status:** Approved (autonomous execution)
**Source:** Iter 38 audit Queue #8 (D3-012 + D3-006)
**Plugin:** v3.32.1 → v3.33.0 (MINOR — vault.json lock contract + scenario walkthroughs)
**Estimated effort:** ~2hr

---

## §1 — Problems

### D3-012: vault.json concurrent-write safety
Multi-tab / multi-session writes to `<vault>/vault.json` can race. Writers include:
- `bind-codebase` Step 6 (audit log append)
- `diff-vault` Step 7-8 (regen from markdown)
- `generate-intent` Step 11 (initial write)
- Memory subsystem (Iter 5) has file-lock pattern; vault.json doesn't

### D3-006: scenario-6 recovery walkthroughs incomplete
Current `tests/scenarios/scenario-6-recovery-from-halt.md` covers 3 halts (hard_rule_violated, bind_conflict, quality_gate_failed). Plugin now has 46+ halts (per Iter 41 sweep). Users hitting other halts have no walkthrough.

---

## §2 — Design

### Change 1: vault.json advisory lock — reuse Iter 5 file-lock pattern

Apply the existing memory file-lock pattern (per `mega-sdd:memory` SKILL.md §file-lock: backoff + retry 3x) to `vault.json` writes. **Reuse existing `memory_in_use` halt** — no new halt type. Per reuse-first directive.

**Document in canonical contract (`generate-intent/references/vault-contract.md` §schema):**

Add concurrency section:
- All vault.json writers (bind-codebase, diff-vault, generate-intent) MUST acquire exclusive file lock before write
- Lock backoff + retry 3x; fail with `memory_in_use` blocker if all retries fail
- detect-drift NEVER writes vault.json (existing convention — preserved)

**Per-writer updates:**
- `bind-codebase` Step 6: "Acquire vault.json lock per memory file-lock pattern" before audit log append
- `diff-vault` Step 8: "Acquire vault.json lock before vault.json write"
- `generate-intent` Step 11: "Acquire vault.json lock before initial vault.json write"

### Change 2: scenario-6 expansion — add 10 halt walkthroughs

Append 10 new walkthroughs to `tests/scenarios/scenario-6-recovery-from-halt.md`. Each walkthrough: brief setup + halt example + recovery options + cross-reference.

Selected halts (10 highest-frequency from Iter 40+41+45 additions + universal halts):

1. `handoff_missing` (Iter 40 + 43 fix-forward) — producer skill crashed before emitting handoff YAML in chat
2. `artifact_missing` (Iter 40) — handoff lists files but they don't exist
3. `partial_state_corrupt` (Iter 40) — partial-state.json corrupt; saga rollback option (Iter 45)
4. `oq_blocker` (universal) — P1 OQ blocks downstream work
5. `diff_conflict` (Iter 3) — vault revision conflict
6. `dispatch_prompt_too_large` (Iter 30 + 44) — T2 budget exhausted; truncation hints
7. `provenance_missing` (Iter 30) — bolt modified file lacks provenance trailer
8. `bind_conflict_constitution_violation` (Iter 20) — claim conflicts with constitution security clause
9. `cross_squad_dep_invalid` (Iter 25) — cross-squad interface missing or stale
10. `memory_schema_mismatch` (Iter 5) — memory file schema_version drift

Format per walkthrough (~30-40 lines each, ~400 LOC total addition):
```markdown
## Scenario walkthrough — `<halt_type>`

### When you'll see it
<1-2 sentence trigger description>

### Example halt envelope
```yaml
<canonical envelope example>
```

### Recovery options

**Option A: <most common>**
<step-by-step>

**Option B: <alternative>**
<step-by-step>

### Cross-references
- Halt registry: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md §halt-protocol §<halt_type>`
- Emitter: `<skill path>`
- Related: `<related halts>`
```

---

## §3 — Surface updates

| Surface | Change |
|---|---|
| `generate-intent/references/vault-contract.md` | + §Concurrency section under §schema documenting vault.json lock contract |
| `bind-codebase/SKILL.md` Step 6 | + lock acquisition step |
| `diff-vault/SKILL.md` Step 8 | + lock acquisition step |
| `generate-intent/SKILL.md` Step 11 | + lock acquisition step |
| `tests/scenarios/scenario-6-recovery-from-halt.md` | + 10 walkthrough sections (~400 LOC) |

---

## §4 — Version bumps

- `plugin.json`: 3.32.1 → **3.33.0** (MINOR — vault.json lock contract is new behavior; concurrent writes now halt instead of silently racing)
- `bind-codebase`, `diff-vault`, `generate-intent`: PATCH bumps (one-line additions each)

---

## §5 — Out of scope

- Lock implementation details (relies on existing memory subsystem file-lock semantics — Iter 5)
- All 46+ halt walkthroughs (per simplifikasi: 10 highest-frequency only; future iter can expand)
- Lock granularity (file-level for v1; per-section locks deferred)

---

## §6 — Standing directives applied

- **simplifikasi:** 2 audit findings → contract documentation + 10 walkthrough sections
- **flawless:** lock contract applied to ALL 3 vault.json writers in-iter; halt envelope reused (no new halt type per reuse-first)
- **reuse-first:** reuses existing Iter 5 memory file-lock pattern + existing `memory_in_use` halt envelope; no new mechanism
