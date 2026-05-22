# Mega-SDD Command Sprawl Audit (v3.6.0)

**Date**: 2026-05-21
**Trigger**: User feedback — "menurut gue pendekatan jadi tidak simple. tidak sejalan dengan yg di design. on default harusnya udah bisa jalanin itu semua, tidak perlu kasih command tambahan"
**Verdict**: VALID. Mega-sdd shipped 20 slash commands; design philosophy was "ONE command (`/mega-sdd:auto`) does everything; advanced users access phases manually". Drifted.

---

## Current command inventory (20 total)

| # | Command | Iter | User-facing usage | Honest assessment |
|---|---|---|---|---|
| 1 | `/mega-sdd:auto` | 4 | Primary entry point | ✅ KEEP — this is THE command |
| 2 | `/mega-sdd:orchestrate-flow` | 0 | Phase-by-phase router | ✅ KEEP — advanced manual |
| 3 | `/mega-sdd:generate-intent` | 0 | Vault generation phase | ✅ KEEP — phase command |
| 4 | `/mega-sdd:scan-codebase` | 0 | Brownfield scan phase | ✅ KEEP — phase command |
| 5 | `/mega-sdd:bind-codebase` | 0 | Binding gate phase | ✅ KEEP — phase command |
| 6 | `/mega-sdd:generate-units` | 0 | Unit decomposition phase | ✅ KEEP — phase command |
| 7 | `/mega-sdd:execute-bolts` | 0 | Execution phase | ✅ KEEP — phase command |
| 8 | `/mega-sdd:resolve-oq` | 0 | Interactive OQ resolution | ✅ KEEP — event-driven from halts |
| 9 | `/mega-sdd:extract-intelligence` | 0 | Legacy KB extraction | ✅ KEEP — specific use case |
| 10 | `/mega-sdd:diff-vault` | 0 | PRD revision handler | ✅ KEEP — event-driven |
| 11 | `/mega-sdd:detect-drift` | 0 | Periodic code-vs-vault check | ✅ KEEP — event-driven |
| 12 | `/mega-sdd:update-plugin` | meta | Plugin self-update | ✅ KEEP — meta |
| 13 | `/mega-sdd:lint-units` | 12 | Unit quality check | ⚠️ AUTO-INTEGRATE — should fire after generate-units in chain |
| 14 | `/mega-sdd:analyze-parallelism` | 12 | DAG analysis | ⚠️ AUTO-INTEGRATE — should fire before execute-bolts --parallel |
| 15 | `/mega-sdd:list-modules` | 11 | Module progress display | ⚠️ AUTO-INTEGRATE — should be in chain end summary |
| 16 | `/mega-sdd:emit-agents-md` | 6 | AGENTS.md flatten | ⚠️ AUTO-INTEGRATE — should fire at chain end (already config-flag default-on; just ensure firing) |
| 17 | `/mega-sdd:memory` | 5 | Memory inspection + curate | 🟢 KEEP but de-emphasize — useful for `memory review` after chain |
| 18 | `/mega-sdd:migrate-rules` | 6 | One-time v1→v2 grammar | 🟢 KEEP — rare, niche |
| 19 | `/mega-sdd:migrate-paths` | 10 | One-time legacy→new layout | 🟢 KEEP — rare, niche |
| 20 | `/mega-sdd:from-prompt` | 0 | DEPRECATED ALIAS | 🔴 REMOVE — overdue (README said v1.4; now at v3.6) |

---

## Sprawl analysis

### Categories

| Category | Count | Verdict |
|---|---|---|
| Primary (use this every day) | 1 (`auto`) | ✅ Correct |
| Phase commands (advanced manual) | 10 | ✅ Correct |
| Should be auto-invoked (not standalone) | 4 | ⚠️ FIX |
| Maintenance/one-off | 4 | ✅ Keep but de-emphasize |
| Deprecated | 1 | 🔴 REMOVE |

**Real "use this" commands** = 1 (`auto`) + occasional phase commands. Other 8 should not surface in normal user workflow.

### Discoverability problem

When user types `/mega-sdd:` to see autocomplete, 20 commands appear. Mental model: "which one do I run?" — overwhelming.

Should appear as PRIMARY (always available, high signal):
1. `/mega-sdd:auto` ⭐
2. Phase commands when needed

Should fade into background (auto-invoked OR rare):
- lint-units, analyze-parallelism, list-modules, emit-agents-md → auto-run, NOT separately
- memory, migrate-rules, migrate-paths → maintenance; not in daily flow

### Documentation drift

The README primary commands table lists 7 commands (Iter 6 update). Reality is 20 invocable commands. README is honest but understates sprawl.

### "Auto-integrate" details

These should run AUTOMATICALLY at appropriate phases of `auto` / `orchestrate-flow --deep`:

| Skill/command | Should fire | Trigger condition |
|---|---|---|
| lint-units | After `generate-units` | Always (quality gate); summarize in chain output |
| analyze-parallelism | Before `execute-bolts` | When `--parallel` flag set OR --deep --auto chain |
| list-modules | At chain end | When `_meta/modules.yaml` exists; include in final summary |
| emit-agents-md | At chain end | Per Iter 6 config-flag default-on (already designed; ensure firing) |
| memory review prompt | At chain end | When `<vault>/.memory/patterns.md` has ≥1 pending suggestion |

Effect: user runs `/mega-sdd:auto ./prd.md` and gets ALL of this automatically. No extra commands needed.

---

## Consolidation plan (Iter 13)

### Phase A — Remove deprecated

1. Delete `plugins/mega-sdd/commands/from-prompt.md` (deprecated since v1.3; never removed)
2. Update README + CHANGELOG explaining the long-overdue removal

### Phase B — Auto-integrate diagnostic commands

3. Patch `orchestrate-flow` Step 6 (chain execution) to add auto-runs:
   - After `generate-units` skill completes → invoke `lint-units` logic; embed summary in chain output
   - Before `execute-bolts --parallel` → invoke `analyze-parallelism` logic; use wave plan
   - After last skill → invoke `emit-agents-md` (if config flag enabled) + `list-modules` summary + check memory pending suggestions
4. Update `auto` command documentation to mention these auto-runs

### Phase C — Mark standalone commands as advanced

5. Update standalone command docs (lint-units, analyze-parallelism, list-modules, emit-agents-md, memory) with "Advanced — auto-invoked by default in `/mega-sdd:auto`; run standalone only for debugging or one-off diagnostic" header

### Phase D — Update README

6. Simplify Primary commands table:
   - `auto` ⭐ (THE command)
   - Phase commands (when manual control needed): generate-intent, extract-intelligence, scan-codebase, bind-codebase, generate-units, execute-bolts
   - Event-driven: resolve-oq, diff-vault, detect-drift
   - Advanced/maintenance: memory, lint-units, analyze-parallelism, list-modules, emit-agents-md, migrate-rules, migrate-paths, update-plugin
7. Add prominent "Just run `/mega-sdd:auto`" callout

### Phase E — Plugin metadata

8. Plugin 3.6.0 → 3.7.0
9. CHANGELOG explicitly notes from-prompt removal + consolidation philosophy restoration

---

## Why this matters (philosophy alignment)

Mega-sdd's core design philosophy:
- **Single opinionated plugin** (no sprawl)
- **`/mega-sdd:auto` as ONE-shot entry** (Iter 4)
- **Anti-halu via rails + defaults, not user-managed checks**
- **Markdown-driven** (single source of truth)

Sprawling diagnostic commands violate principle #1 + principle #2. Users shouldn't think "do I need to run lint-units before bolts?" — that should be automatic.

This audit restores alignment.

---

## Outstanding (defer or Iter 14)

- Merge `migrate-rules` + `migrate-paths` into single `/mega-sdd:migrate <type>` (consolidates 2 → 1 command; trade-off: less specific name)
- Consolidate `memory` ops as sub-commands clearly (already done; just emphasize less in primary docs)
- README v3.7 polish: single "happy path" diagram showing default flow

These are improvements but not critical. Iter 13 focuses on the high-impact restoration.

---

## Acceptance criteria for Iter 13

1. User types `/mega-sdd:` → sees primary commands at top of list (or marked); secondary clearly de-emphasized
2. `/mega-sdd:auto ./prd.md` runs full pipeline including: lint after gen-units, analyze before bolts, list-modules + emit-agents-md + memory review prompt at chain end — WITHOUT user invoking those separately
3. README primary commands section reflects "just use auto" as the dominant path
4. `from-prompt` deprecated alias is removed
5. CHANGELOG explains restoration of simplification philosophy
