# Iter 44 — T2 Running Budget Tracker Design

**Status:** Approved (autonomous execution)
**Source:** Iter 38 audit Queue #4 (D1-003)
**Plugin:** v3.28.1 → v3.29.0 (MINOR — new tracker step + per-section truncation rules)
**Estimated effort:** ~2-3hr

---

## §1 — Problem

Current execute-bolts Step 4.5.d (v2.7.3+) has a SINGLE hard-halt at 10KB:
```
d. Size check:
   - If assembled prompt > 10KB → halt `dispatch_prompt_too_large` with re-tier guidance
```

Issues:
1. **No running budget tracker** — sections load opaque; nobody knows total size until the final size check
2. **Coarse cascade** — only starterkit slice has a defined truncation cascade (libs → idioms → halt). Other T2 sections have no defined truncation behavior
3. **Halt-or-pass binary** — at 9.9KB pass / 10.1KB halt. No graceful degradation for complex units
4. **T2 5KB soft cap is aspirational** — never actually enforced; the only enforcement is the 10KB hard cap

**Audit estimate:** 15-30% T2 size reduction for complex units once progressive truncation enforced.

---

## §2 — Design

### Running budget tracker (new — Step 4.5.budget-tracker)

Inserted between Step 4.5.a (TIER 1 load) and Step 4.5.b (TIER 2 load):

```
running_budget = {
  cap_hard: 10240        # 10KB hard cap (existing)
  cap_target: 7168       # 7KB target (existing)
  cap_t1: 2048           # 2KB T1 (existing)
  cap_t2: 5120           # 5KB T2 (existing — newly enforced)
  consumed_t1: <bytes>   # set after Step 4.5.a
  consumed_t2: 0         # accumulates during Step 4.5.b
  remaining: cap_t2      # decrements as T2 sections load
  warnings: []           # truncation events logged for provenance
}
```

After each T2 section loads (b1, b2, ..., b8), update tracker:
- `consumed_t2 += section_bytes`
- `remaining = cap_t2 - consumed_t2`
- If `remaining < next_section_min_viable_bytes` → apply progressive truncation per Priority Order (below) BEFORE attempting next section load

### Per-section truncation priority (lowest-first)

Ordered from MOST disposable to MOST critical. When budget tight, truncate top of list first.

| Priority | T2 Section | Default content | Truncation rule | Drop floor |
|---|---|---|---|---|
| 1 (most disposable) | validation_hints | test commands + expected output | drop expected-output patterns; keep commands only | drop section |
| 2 | historical_memory | last 5 similar bolts | last 3, then last 1, then drop | drop section |
| 3 | kb_anti_patterns | filtered by domain tags | top 3, then top 1, then drop | drop section |
| 4 | confidence_labels | HIGH/MEDIUM/LOW per claim | compress to "HIGH×N / MEDIUM×N / LOW×N" aggregate | drop |
| 5 | depends_on_summaries | 1-line per upstream | truncate to N most-recent-touched files | keep at least 1 |
| 6 | framework_pack_rules | filtered by path_glob | top 5, top 3, top 1 | keep top 1 |
| 7 | starterkit_slice | (existing Iter 32 cascade) | libs[]→top10, ui_ux.idioms[]→top3 | per Iter 32 |
| 8 (NEVER drop) | constitution_clauses | LOCKED — vault_source referenced | NEVER truncate; if budget exceeds here → halt | n/a |

### Truncation log → provenance

Each truncation event logs to `running_budget.warnings` as `{section, rule_applied, bytes_saved}`. Written to:
- bolt-dispatch-prompt.md `### T2 budget tracker` section (NEW) for provenance
- `<vault>/bolts/U-XXX/dispatch-prompt.md` (existing log; truncation visible to user)
- bolt-report.md `## Self-assessment` section (informs subagent: "I was working with truncated context for kb_anti_patterns")

### Halt path (preserved)

`dispatch_prompt_too_large` fires ONLY when:
- All truncation rules exhausted (every section truncated to drop floor)
- AND total still exceeds `cap_hard` (10KB)
- AND constitution_clauses section alone is non-truncatable

In practice: only fires for units with massive constitution_clauses references — true config issue requiring spec adjustment, not bolt-fixable. Iter 30 halt semantics preserved.

### Soft-budget warnings (NEW)

When `consumed_t2 > cap_t2` (5KB) but `total < cap_hard` (10KB):
- Log warning (not halt): "T2 exceeded soft cap (5KB target, actual XKB) — truncation applied per priority order"
- Truncation still applied to bring T2 back under target
- Bolt proceeds with truncated context + provenance trail

---

## §3 — Surface updates

| Surface | Change |
|---|---|
| `execute-bolts/SKILL.md` | + Step 4.5.budget-tracker (NEW) before 4.5.b; rewrite 4.5.d to surface truncation log; bump 2.7.3 → 2.8.0 |
| `execute-bolts/references/bolt-dispatch-prompt.md` | + `### T2 budget tracker` provenance section in template (consumed by bolt subagent for self-awareness) |

---

## §4 — Version bumps

- `plugin.json`: 3.28.1 → **3.29.0** (MINOR — new step + new self-assessment field)
- `execute-bolts` SKILL.md: 2.7.3 → **2.8.0** (MINOR — new Step 4.5.budget-tracker)

---

## §5 — Out of scope

- D1-005 prompt-caching cache_control wiring: separate iter; depends on Claude Code API capabilities
- D1-004 wave glossary dedup: extract-intelligence scope; separate iter (Queue #10)
- T1 truncation: NEVER — T1 is non-negotiable correctness foundation

---

## §6 — Standing directives applied

- **simplifikasi:** 1 audit finding → 1 iter; 1 new step + 1 reference doc update; no new files
- **flawless:** halt semantics preserved (cap_hard still fires); soft-budget enforcement added incrementally; self-assessment field gives bolt subagent visibility into truncation context
- **reuse-first:** extends existing Iter 30 tiered-context architecture + existing Iter 32 starterkit cascade pattern + existing halt envelope
