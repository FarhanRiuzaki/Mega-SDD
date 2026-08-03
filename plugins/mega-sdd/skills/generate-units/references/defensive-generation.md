# Defensive Generation

`generate-units` is defensively grounded — auto-detects missing upstream signals, cross-checks per unit before writing, and surfaces a `grounding_confidence` label so users instantly see how well-anchored each unit is.

Mitigates "ngawang" (floating/disconnected) units. User UX request:

> "ketika generate units. dan ketika generate itu ada di source code base, bisa auto detecs, atau kasih pertanyaan terlebih dahulu... nanti hasil yg di generate sudah cross check dlu/scan codebase dlu. jadi hasil nya lebih robust tidak ngawang"

## Contents
- Design principle
- Step 0.5 — Pre-flight upstream check
- Step 7.6 — pointer to task-typing.md (single owner)
- Step 12.3 — Per-anchor verification
- Grounding confidence labels
- Halt vs warning matrix
- Anti-halu rails preserved
- Backward compatibility
- References

## Design principle

**Auto-detect first, ask only when genuinely ambiguous.** Avoid death-by-prompts.

- Missing upstream artifacts → auto-detect + offer to run (1 prompt, not per-unit)
- Per-unit collision (file exists vs task_type) → INTERACTIVE prompt only when ambiguous
- Anchor unresolved → WARNING in unit body (not halt; anchors can be aspirational)
- Confidence label HIGH/MEDIUM/LOW visible in unit frontmatter + chat output

## Step 0.5 — Pre-flight upstream check (NEW)

Before vault parsing (Step 1), detect missing upstream signals:

```
1. Probe for codebase-map.md (current dir OR repo root OR vault parent dir)
2. Probe for binding.md (vault-bound/ OR vault parent dir)
3. Build state snapshot:
   - codebase_map: present | absent
   - binding: present | absent
   - vault_mode: greenfield | existing (from vault.json)
```

### Decision matrix

| codebase_map | binding | vault_mode | Action |
|---|---|---|---|
| present | present | any | ✅ Proceed (current behavior; HIGH confidence) |
| any | present with `binding_metadata.retrieval` (EXPRESS binding — P2 default) | any | ✅ **Proceed (HIGH confidence)** — an express binding was produced WITHOUT a map by design (claim-scoped retrieval, read-evidence anchors); a missing map beside it is NOT a missing artifact and MUST NOT demote confidence, prompt, or auto-run scan-codebase |
| absent | absent | greenfield | ✅ Proceed (no codebase context expected; MEDIUM confidence labeled) |
| absent | absent | existing | ⚠️ INTERACTIVE prompt — "Brownfield vault but no codebase-map/binding. Options: (1) auto-run bind-codebase --express first (recommended — needs no map), (2) classic: scan-codebase + bind-codebase, (3) proceed with reduced precision (LOW confidence), (4) cancel" |
| present | absent | existing | ⚠️ INTERACTIVE prompt — "Codebase-map present but no binding. Options: (1) run bind-codebase first (recommended), (2) proceed with file-existence checks only (MEDIUM confidence), (3) cancel" |
| absent | present WITHOUT the retrieval key (classic binding, map deleted) | any | Warn — binding exists but its map is gone (likely stale or mismatched); proceed with MEDIUM confidence |

### Auto-route action

If user picks "auto-run upstream":
- Default (express): invoke `mega-sdd:bind-codebase <vault> --express` — no scan needed
- Classic spine only, map missing: invoke `mega-sdd:scan-codebase` first (per orchestrate-flow's auto-route pattern), then `mega-sdd:bind-codebase <vault>`
- After auto-routes complete, return to generate-units Step 1

Both routes can short-circuit on halt (CONFLICT in binding, etc.) — same protocol as orchestrate-flow.

## Step 7.6 — Per-unit target_files cross-check

Single owner: `references/task-typing.md §Step 7.6` — full probe logic, BOTH prompt branches (IMPLEMENTED→verify recommended; PARTIAL/NEW/UNKNOWN→extend recommended), prompt-frequency control, and the `--auto` / `--collision-policy` semantics live there.

## Step 12.3 — Per-anchor verification (precondition check)

Before Step 12.4 (constitution inject) and Step 12.5 (polished-prompt render pass), verify each unit's `## Anchors`:

```
For each Anchor entry "<file>:<line-range> — <description>":
  1. Probe file existence (fs OR codebase-map)
  2. If file MISSING:
     - For greenfield units: WARNING (anchor likely aspirational/template)
     - For brownfield units: WARNING with stronger note "Anchor points to non-existent file; verify before bolt"
  3. If file EXISTS but line-range out of bounds:
     - WARNING "Anchor line-range may have drifted; codebase-map shows file has N lines"
  4. If file EXISTS and line-range valid:
     - ✓ Verified
```

Warnings surface in unit body as a footer `<!-- ⚠️ Anchor warnings: ... -->` HTML comment. NOT a halt — anchors can be aspirational (e.g., "this new file SHOULD follow the pattern at <future location>").

## Grounding confidence labels (NEW)

Every generated unit gets a `grounding_confidence` field in frontmatter:

```yaml
---
id: U-007
title: ...
task_type: create
grounding_confidence: HIGH | MEDIUM | LOW
---
```

The anchor tally and collision outcome surface in the per-unit chat summary line (below) and the anchor-warning body footer — no frontmatter block needed.

### Confidence levels

| Level | Criteria |
|---|---|
| **HIGH** | binding present + all anchors verified + no target collisions + binding state all HIGH-conf |
| **MEDIUM** | binding present BUT some anchors aspirational OR some UNKNOWN state OR codebase-map precision: regex |
| **LOW** | no binding (standalone generate-units) OR no codebase-map OR significant unverified anchors |

### verify + HIGH: per-acceptance-criterion source grounding (A1)

`anchors_verified: N/M` proves the unit's `## Anchors` *symbols* exist (file exists + line valid). It does **not** prove each acceptance criterion's *behavior* exists — a verify unit could cite one real anchor (e.g. a `MIN_GRAM` constant) yet carry five LOCKED criteria whose behavior lives only in a test stub or the PRD, and still be stamped HIGH. That certifies UNBUILT behavior green. The defect is **partial** grounding, so "are all anchors test files?" misses it — the unit of measure is the **criterion**.

For a `task_type: verify` unit you intend to stamp `grounding_confidence: HIGH`, ground each acceptance criterion individually before writing:

1. For each criterion, locate the **non-test** source that already implements the asserted behavior (grep the codebase-map / binding anchors, not the test files). A test asserting the behavior is NOT proof the behavior exists.
2. Found → prefix the criterion `- [grounded: <non-test path>:<line>] <criterion>`.
3. Not found (behavior only in a test stub, the PRD, or nowhere) → `- [ungrounded] <criterion>`, and the unit is **not** verify+HIGH:
   - downgrade `grounding_confidence` (MEDIUM/LOW — honest), OR
   - **split**: a `verify` unit over the grounded criteria (built) + a `create`/`extend` unit over the ungrounded ones (unbuilt). This is the correct fix — it stops the bolt from skipping code for behavior that was never implemented.

Once any criterion carries a marker the unit opts in and **every** criterion must be `[grounded: …]`; a HIGH verify unit with an `[ungrounded]` (or test-only, or non-resolving) criterion is blocked by `validate-unit-spec.sh` → `verify_grounding_untrusted` (the next `execute-bolts` halts). Legacy verify units with no markers at all are tolerated (treated as the old symbol-existence semantics) — only newly stamped HIGH verify units are held to per-AC grounding. Grammar + examples: `generate-units/references/unit-schema.md` § Acceptance criteria.

### Chat output enhancement

After each unit written, emit one summary line:

```
✓ U-007 generated (task_type: extend, grounding: HIGH, anchors: 3/3 verified, target_files: 2 modify + 0 create)
⚠️ U-013 generated (task_type: create, grounding: LOW, anchors: 1/3 verified — 2 aspirational, target_files: 4 create)
```

Visual feedback so user instantly sees which units are well-grounded vs which need review.

## Halt vs warning matrix

Defensive generation introduces NEW signals but FEW new halts. Most checks are warnings (preserves pipeline flow):

| Check | Outcome | Severity |
|---|---|---|
| Pre-flight: brownfield + no codebase-map/binding | INTERACTIVE prompt (Step 0.5) | Soft halt (user decides) |
| Per-unit: file exists + task_type=create + IMPLEMENTED state | INTERACTIVE prompt (Step 7.6) | Soft halt (user decides) |
| Per-unit: file exists + task_type=create + UNKNOWN state | INTERACTIVE prompt | Soft halt |
| Per-anchor: file missing | WARNING in unit body | Soft (proceeds) |
| Per-anchor: line-range out of bounds | WARNING in unit body | Soft (proceeds) |
| All target_files collision + no path to resolve | HALT `dedup_ambiguous` (Step 12.6 — canonical name; there is no separate target_files_collision halt) | Hard halt |
| Force-create on existing file via option 4 | WARNING + proceed (user accepted risk) | Soft (proceeds) |

## Anti-halu rails preserved

- Pre-flight auto-route uses existing scan-codebase + bind-codebase (no new code paths)
- Per-unit cross-check NEVER silent-rewrites task_type — always user confirms via prompt
- Anchor warnings DON'T fabricate citations; flag missing references for user review
- `grounding_confidence` is descriptive for `create`/`extend` and for MEDIUM/LOW values; for `verify`+HIGH it is PRESCRIPTIVE — the A1 rail (`verify_grounding_untrusted`, this file §verify-grounding) hard-blocks execute-bolts on ungrounded criteria. (`grounding_evidence` is no longer written; legacy units carrying it are tolerated.)
- `--auto` mode picks safest defaults (extend over create on collision; never force overwrite)

## Backward compatibility

- v3.1 vaults without upstream artifacts → trigger Step 0.5 prompts; user can decline to keep v3.1 behavior
- v3.1 units without `grounding_confidence` → treated as v3.1 schema; new field optional in frontmatter
- `--no-defensive` flag disables Steps 0.5 + 7.6 + 12.3 entirely (back to v3.1 behavior)
- `--auto` flag in chain mode (orchestrate-flow --deep) → defaults safest (no death by prompts in autonomous chains)

## Moved content (pointers)

- The chat-transcript Examples walkthrough (pre-flight auto-route, collision prompt, anchor warning, LOW-confidence run) was cut — the operative behavior each example illustrated lives in §Step 0.5 (decision matrix + auto-route), `task-typing.md §Step 7.6` (collision prompt text), §Step 12.3 (anchor warnings), and §Grounding confidence labels (chat output lines).
- The Six-state Implementation State Map + the new-state task_type mapping moved to `references/task-typing.md` (§Six-state Implementation State Map / §task_type for the six states) — task-typing is the single owner of task_type assignment.
- The bind-codebase field-diff narration (PARTIAL_FIELDS derivation, binding.md `Field diff` column, the login worked example) is owned by `bind-codebase/references/binding-contract.md §Implementation-State Classification` + its implementation-state reference.

## References

- tree-sitter scan extracts signature details (leveraged for field diff)
- `bind-codebase/SKILL.md` — Implementation State Map (which Step 7.6 reads to decide prompt content)
- `bind-codebase/references/binding-contract.md` — six-state classification table
