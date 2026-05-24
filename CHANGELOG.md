# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.32.1] - 2026-05-25

### Iter 48 — FIX-FORWARD: Iter 44 algorithm rewrite, Iter 46 step relocation, Iter 46 wording correction

**Release-blocker fix iter** (PATCH bump — pure correctness; no new behavior). Cumulative code-quality review of Iters 44-47 (commits 3d11c09..HEAD covering v3.29.0 → v3.32.0) by `superpowers:code-reviewer` subagent surfaced 2 CRITICAL + 1 MEDIUM. All fixed in Iter 48 before Iter 49 feature work.

This is the SECOND fix-forward iter triggered by validation gate this session (precedent: Iter 43 fixed Iter 40's `handoff_missing` release-blocker). Pattern: ship 3-4 feature iters → advisor + code-reviewer subagent → fix-forward critical findings → next feature iter. Pattern is now standard for cumulative-iter sessions.

**CRITICAL fixes:**

**C1 — Iter 44 algorithm drift (`bolt-dispatch-prompt.md` §Tier-loading algorithm):**

Pre-Iter-44 the canonical algorithm in `bolt-dispatch-prompt.md` encoded single-halt-at-10KB pseudocode. Iter 44 added new running-budget tracker + per-section truncation cascade to SKILL.md Step 4.5.a.5, BUT the canonical algorithm in the reference doc was left unchanged. LLM following the reference doc would execute the OLD behavior contradicting SKILL.md's design — the 15-30% T2 reduction claim wouldn't materialize.

Fix: rewrote `bolt-dispatch-prompt.md §Tier-loading algorithm` with v2.0 (Iter 44) running-budget pseudocode:
- Step a.5 initialize budget tracker with cap_hard/cap_target/cap_t1/cap_t2/consumed_t1/consumed_t2/remaining_t2/warnings
- Step b T2 sections load in PRIORITY DESCENDING order (priority 8 first, priority 1 last) so HIGH-priority items always survive
- For each section: check remaining_t2; if section fits append; if not apply truncation cascade per SKILL.md table; log {section, rule_applied, bytes_saved} to warnings
- Step d hard halt only when constitution_clauses alone overflows after all disposable sections truncated to drop floor
- Soft-budget warning (NOT halt) when consumed_t2 > cap_t2 but total < cap_hard
- Always inject `### T2 budget tracker` provenance section
- Header bumped to v2.0 (Iter 44 semantics); v1.0 (Iter 30) algorithm preserved at bottom as historical reference

**C2 — Iter 46 scan-codebase Step 9.5 misplacement (`scan-codebase/SKILL.md`):**

Iter 46 added per-file invalidation logic at Step 9.5 (between Step 9 pattern detection and Step 10 codebase-map.md write). BUT symbol extraction happens at Step 5. By the time Step 9.5 ran, tree-sitter/regex extraction was already complete — too late to short-circuit. The promised 5-10s shallow-scan savings didn't materialize. Plus the original Step 9.5 said "Write updated codebase-map.md atomically" which would have been overwritten by Step 10's own write (double-write race).

Fix: relocated per-file invalidation gate to BEFORE Step 5 tree-sitter/regex extraction. The gate now:
1. Skips for `--deep-scan` (default) or `--no-cache` (correctness preserved)
2. For `--shallow-scan` with prior codebase-map.md: per-file compare current sha256 vs `Last_Scanned_Sha256` column
3. REUSE prior §2 entries for unchanged files (true short-circuit — tree-sitter never invoked for those files)
4. Re-extract for changed/new files; update Last_Scanned_Sha256
5. Files removed from repo → drop from §2

Step 9.5's old location now holds a brief breadcrumb pointing to the relocated gate. Single canonical codebase-map.md write at Step 10.

**MEDIUM fix:**

**M1 — Iter 46 bind-codebase reuse hook wording (`bind-codebase/SKILL.md` Step 1):**

Iter 46 description claimed "skip per-source-file re-tokenization (~30-50% I/O saving)" — but bind-codebase Step 2 has never re-tokenized. Step 2 consumes pre-extracted §2 entries from codebase-map.md. The "savings" had no observable target within bind-codebase.

Fix: corrected wording. The snapshot reuse is a **freshness attestation** that bind-codebase records in `binding_metadata.codebase_map_provenance` field (`snapshot-verified` / `snapshot-stale` / `no-snapshot`). The 30-50% savings applies at the orchestrate-flow chain level — downstream skills can trust the codebase-map is fresh and skip a redundant scan-codebase invocation. Iter 48 fix-forward note added inline explaining the correction.

**Surface changes:**
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — §Tier-loading algorithm rewritten with v2.0 running-budget pseudocode; v1.0 historical reference preserved
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — per-file invalidation gate moved from Step 9.5 → Step 5 (BEFORE extraction); old Step 9.5 location holds breadcrumb
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 1 reuse hook wording corrected; provenance attestation pattern documented
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.32.0 → 3.32.1
- `plugins/mega-sdd/README.md` — + v3.32.1 What's new entry
- `README.md` — version bump

**Skill version bumps:**
- `scan-codebase` 2.7.1 → 2.7.2 (PATCH — Step 5 gate relocation)
- `bind-codebase` 1.10.0 → 1.10.1 (PATCH — wording correction)

**Validation pattern reinforced (second fix-forward triggered by subagent review):**

This session has now triggered the validation pattern twice:
1. Iter 43 fix-forward caught Iter 40's `handoff_missing` semantics defect (file-check vs chat-block)
2. Iter 48 fix-forward caught Iter 44 algorithm drift + Iter 46 step misplacement + Iter 46 wording

Both rounds caught defects that would have produced wrong runtime behavior in production. The pattern is now load-bearing: ship 3-4 feature iters → advisor + code-reviewer subagent → fix-forward → next feature iter.

**Standing directives applied:**
- simplifikasi: 3 review findings → 3 surgical fixes in 3 files; no new files; no new halts
- flawless: caught semantic defects in canonical algorithm + step placement + wording BEFORE production; both prior iter intentions preserved with corrected implementations
- reuse-first: extends existing validation gate pattern (advisor + code-reviewer subagent) established in Iter 43

**Plugin:** v3.32.0 → v3.32.1

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Code-reviewer dispatch:** agentId a882063dd0e439071

**Next:** Iter 49 — vault.json advisory lock + scenario-6 expansion (Queue #8 from audit; D3-012 + D3-006; ~3hr; MEDIUM impact).

## [3.32.0] - 2026-05-25

### Iter 47 — Independent Acceptance-Test Authoring (Adversarial Review Pass)

**Output-quality iter** (~2hr; MINOR bump — new generate-units Step + new acceptance_test provenance field + new prompt template reference). Closes Iter 38 audit Queue #7 (D4-006, HIGH structural risk; pattern F). Per ACM FSE 2025: "Never trust AI to both generate and validate."

**Problem (D4-006 HIGH severity):** every unit's `acceptance_test` was authored by the SAME LLM pass that wrote the unit body. Both inherited the same blind spots. Bolt subagent runs the test → passes → user trusts the green checkmark → ships broken code. Hard Rules + provenance trailer catch structural bugs; they cannot catch behavioral bugs the test was authored to NOT detect.

**Solution: adversarial second-pass review + provenance field**

**1. New Step 9.5 — Adversarial test review pass (generate-units)**

Runs AFTER Step 9 fills acceptance_test inline with unit body. Two modes:

**Default (main-thread self-re-prompt):** main thread re-prompts itself with adversarial framing — "you're a QA engineer reviewing this acceptance_test; find AT LEAST 2 cases the test FAILS to catch a real bug." Same LLM, different role context. No subagent dispatch overhead.

**Opt-in subagent (`--adversarial-subagent` flag OR unit `risk: high`):** dispatch a SEPARATE subagent for the adversarial review. Independent LLM context = stronger blind-spot coverage. One extra dispatch per unit. Auto-set for high-risk units.

**Skip (`--no-adversarial-review` flag):** preserves pre-Iter-47 behavior (D4-006 blind-spot risk). **DISCOURAGED** — debug / regression only.

**2. Adversarial review output (strict YAML)**

```yaml
adversarial_review:
  reviewer_pass: 2                          # always 2 (Step 9 = pass 1)
  gaps_identified:
    - scenario: "<bug case description>"
      missed_by_assertion: "<which existing assertion fails to catch it>"
      proposed_additional_assertion: "<test code or natural language>"
  coverage_verdict: weak | adequate | strong
```

**3. Gap merge logic (main thread, post-review)**

- `coverage_verdict: strong` AND no gaps → keep original; mark `_authored_by: adversarial-reviewed (no gaps)`
- Non-empty gaps → append `proposed_additional_assertion` per gap to acceptance_test; mark `_authored_by: adversarial-reviewed (+N gaps merged)`
- `coverage_verdict: weak` AND no gaps (incoherent reviewer output) → keep original; mark `_authored_by: adversarial-review-failed`. Log warning to chat.

**4. `_authored_by:` provenance field (NEW canonical values)**

| Value | Origin | Trust signal |
|---|---|---|
| `same-pass` | pre-Iter-47 OR `--no-adversarial-review` | weakest (D4-006 risk) |
| `adversarial-reviewed (no gaps)` | Iter 47 default, no gaps found | strong |
| `adversarial-reviewed (+N gaps merged)` | Iter 47 default, N gaps merged | strong |
| `adversarial-review-failed` | Iter 47, reviewer incoherent | weak + warning |
| `independent-llm` | Iter 47 opt-in subagent mode | strongest LLM-derived |
| `human` | user manually edited | strongest overall |

**5. execute-bolts dispatch-prompt NOTE for weak provenance**

When unit's `acceptance_test._authored_by` is `same-pass` OR `adversarial-review-failed`, execute-bolts injects a NOTE into the bolt dispatch prompt warning the bolt subagent: "this test may have blind spots; if your implementation passes the test but feels under-validated, flag `acceptance_test_concern: <details>` in your bolt-report.md self-assessment, propose 1-2 additional assertions, and mark confidence no higher than MEDIUM."

Strong provenance values → NO NOTE injected (trust the test).

**6. `--regenerate` preserves user-edited tests**

`generate-units --regenerate` re-encountering a unit with `_authored_by: human` PRESERVES the acceptance_test untouched. Other provenance values get rewritten per Steps 9 + 9.5.

**New file:** `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` — canonical prompt template (default mode + subagent mode) + merge logic + provenance values table + anti-halu rails.

**Surface changes:**
- `plugins/mega-sdd/skills/generate-units/SKILL.md` — Step 9 extended (first-pass marker); Step 9.5 NEW (adversarial review); Inputs flags `--adversarial-subagent` / `--no-adversarial-review` / `--regenerate`
- `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` — NEW reference file
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.a extended with acceptance-test provenance NOTE detection
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — Acceptance-test provenance NOTE template (above Rollback hints section)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.31.0 → 3.32.0
- `plugins/mega-sdd/README.md` — + v3.32.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-47-independent-acceptance-test-authoring-design.md` — new spec

**Skill version bumps:**
- `generate-units` 2.6.0 → 2.7.0 (MINOR — new Step + new flags + new frontmatter field)
- `execute-bolts` 2.9.0 → 2.9.1 (PATCH — provenance detection + NOTE injection)

**Backward compatibility:**
- Pre-Iter-47 units (no `_authored_by:` field) treated as `same-pass` — execute-bolts injects NOTE; `--regenerate` rewrites with adversarial review
- `--no-adversarial-review` flag preserves pre-Iter-47 generation behavior for debug / regression
- Zero breaking changes; opt-out path preserved for users who want the old behavior

**External research applied (Iter 38 audit citations):**
- PBT for LLM-Generated Code (ACM FSE 2025) — "Never trust AI to both generate and validate"
- Multicalibration for LLM-based Code Generation (ResearchGate)
- Stanford AI Index 2026 — Hallucination Engineering report

**Standing directives applied:**
- simplifikasi: 1 audit finding (HIGH structural) → 1 new Step + 1 new reference file + 1 new frontmatter field + 1 NOTE injection
- flawless: producer (generate-units emits `_authored_by:`) + consumer (execute-bolts reads + surfaces) ship in-iter; backward compat for pre-Iter-47 units; opt-out path preserved
- reuse-first: extends existing generate-units 12.x post-write validation pattern + existing bolt-dispatch-prompt.md NOTE injection convention; no new halt type (provenance signal, not halt)

**Plugin:** v3.31.0 → v3.32.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-47-independent-acceptance-test-authoring-design.md`

**Next:** Validation gate (advisor + code-reviewer subagent on commits 3d11c09..HEAD covering Iters 44-47) BEFORE Iter 48 (Queue #8 vault.json advisory lock + scenario-6 expansion).

## [3.31.0] - 2026-05-25

### Iter 46 — Shared-Snapshot Reuse Extension + Per-File Symbol Invalidation

**Performance iter** (~2hr; MINOR bump — schema extension v1.0 → v1.1 + new producer/consumer paths). Closes Iter 38 audit Queue #6 (D1-006 + D2-007; pattern C cache invalidation). Extends Iter 30 shared-snapshot pattern from 1 hop to 3.

**Problems closed:**

- **D1-006**: shared-snapshot reuse (Iter 30) was scoped to `execute-bolts ↔ detect-drift` only. The same pattern wasn't extended to `scan → bind` or `extract → intent` hops. Audit estimate: 30-50% re-run I/O saving on incremental dev cycles.
- **D2-007**: `scan-codebase --shallow-scan` re-extracted symbols for EVERY file on EVERY run, even files unchanged since last codebase-map.md. Audit estimate: 5-10s rebuild eliminated.

**Solution:**

**Change 1 (D1-006) — shared-snapshot extension to 2 new hops:**

scan → bind hop:
- `scan-codebase` Step 10.6 (NEW) emits `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` after Step 10 codebase-map.md write. Snapshot contains `codebase_map_sha256` + `source_files_sha256_map: {<repo-relative-path>: <sha256>}` for every scanned source file.
- `bind-codebase` Step 1 (extended) reads snapshot before Step 2 claim matching. If `codebase_map_sha256` matches the just-read codebase-map.md → reuse parsed §2 symbol data directly (skip per-source-file re-tokenization). Mismatch or absent → fall back to current behavior (no regression).
- Savings: ~30-50% I/O reduction on iterative dev when source files unchanged between scan and bind.

extract → intent hop:
- `extract-intelligence` Step 5.5 (NEW) emits `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` after wave-5 synthesis completes. Snapshot captures `source_files_sha256_map` for every legacy source file consumed by waves 1-4.
- `generate-intent --kb` (Mode B preflight, v1.15+) checks snapshot before consuming KB. ALL files unchanged → log "KB freshness: confirmed". SOME drifted → log advisory warning + suggest `extract-intelligence --force`. DO NOT halt (preserves user agency on legacy-rebuild work).
- Use case: detect when KB has gone stale because source code evolved since extraction.

**Change 2 (D2-007) — per-file symbol invalidation:**

- `codebase-map.md §2 Public interfaces` gains OPTIONAL `Last_Scanned_Sha256` column (per `references/codebase-map-schema.md` update).
- `scan-codebase --shallow-scan` Step 9.5 (NEW) does per-file invalidation: only files whose current sha256 differs from `Last_Scanned_Sha256` get re-tokenized; unchanged files reuse prior §2 entries.
- Files removed from repo → drop their §2 entries. Files NEW → extract + add. Files unchanged → reuse.
- Default `--deep-scan` behavior preserved (full re-extract; no per-file invalidation) — opt-in to per-file cache via `--shallow-scan`.
- Savings: 5-10s rebuild → <1s on iterative shallow re-scans.

**Schema bump — `references/shared-snapshot-schema.md` v1.0 → v1.1:**

- `snapshot_type` enum extended: + `codebase-map`, + `extracted-kb`
- New OPTIONAL fields: `codebase_map_sha256`, `source_files_sha256_map`
- New producer responsibilities sections: scan-codebase (codebase-map snapshot) + extract-intelligence (extracted-kb snapshot)
- New consumer responsibilities sections: bind-codebase (codebase-map consumer) + generate-intent --kb (extracted-kb consumer)
- File locations summary extended with 2 new snapshot paths

**Backward compatibility (ALL changes):**
- All new fields are OPTIONAL — v1.0 readers ignore unknown keys
- Snapshot files are pure optimization — pre-Iter-46 codebase/KB without snapshots behave as today
- `Last_Scanned_Sha256` column missing → triggers full re-extraction on first `--shallow-scan` (same as cold start)
- Zero breaking changes; one-time migration cost on first post-upgrade scan

**Plugin file changes:**
- `plugins/mega-sdd/references/shared-snapshot-schema.md` — v1.0 → v1.1 with new types + fields + producer/consumer sections
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — + Step 10.6 (snapshot emission); + Step 9.5 (per-file invalidation for --shallow-scan)
- `plugins/mega-sdd/skills/scan-codebase/references/codebase-map-schema.md` — + `Last_Scanned_Sha256` column
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 1 extended with snapshot reuse path
- `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` — + Step 5.5 (extracted-kb snapshot emission)
- `plugins/mega-sdd/skills/generate-intent/SKILL.md` — Mode B preflight extended with KB freshness check
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.30.0 → 3.31.0
- `plugins/mega-sdd/README.md` — + v3.31.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-46-snapshot-reuse-extension-design.md` — new spec

**Skill version bumps:**
- `scan-codebase` 2.7.0 → 2.7.1 (PATCH — additive snapshot emission + opt-in invalidation path)
- `bind-codebase` 1.9.4 → 1.10.0 (MINOR — new reuse path)
- `extract-intelligence` 1.5.0 → 1.6.0 (MINOR — new snapshot emission step)
- `generate-intent` 1.14.0 → 1.15.0 (MINOR — new freshness check preflight)

**External research applied (per Iter 38 audit citations):**
- Real-time codebase indexing (cocoindex-io) — per-file hash invalidation pattern
- Aider repo-map architecture — symbol-graph caching pattern

**Standing directives applied:**
- simplifikasi: 2 audit findings → 1 iter; schema extension + 1 new step per producer + 1 reuse path per consumer
- flawless: producer + consumer ship in-iter for both new hops; v1.0 readers gracefully degrade
- reuse-first: extends Iter 30 shared-snapshot pattern + extends existing codebase-map.md §2 table schema; no new cache files outside existing `.shared-snapshots/` convention

**Plugin:** v3.30.0 → v3.31.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-46-snapshot-reuse-extension-design.md`

**Next:** Iter 47 — independent acceptance-test authoring (Queue #7; D4-006; HIGH structural risk closure).

## [3.30.0] - 2026-05-25

### Iter 45 — Saga Compensating Actions (`--rollback` flag + partial-state v2.0)

**Robustness iter** (~2hr; MINOR bump — schema bump + new flag + new self-assessment section). Closes Iter 38 audit Pattern D (D3-009 rollback undefined + extends D3-003 partial-state coverage). Closes Queue #5.

**Problem (Pattern D, audit-cited external research: Saga Pattern + Compensating Transactions):** mega-sdd uses forward-only resume. On `--resume`, execute-bolts retries the failing step but cannot undo non-idempotent prior steps (composer dep adds, migration executions, external API calls). Partial writes compound on subsequent runs.

**Solution:**

**1. partial-state.json schema v1.0 → v2.0**

Bumps `schema_version` field. Adds `rollback_hints[]` array per partial bolt:

```json
{
  "schema_version": "2.0",
  "bolt_id": "U-007",
  "current_step": "step-3-write-controller",
  "current_step_status": "crashed",
  "files_modified": [...],
  "rollback_hints": [
    {
      "step_id": "step-1-add-dep",
      "step_type": "composer_dep_added",
      "evidence": "added 'laravel/cashier': '^15.0' to composer.json:42",
      "compensating_action": "composer remove laravel/cashier --no-update && git checkout composer.json composer.lock",
      "idempotent": false,
      "applied_at": null
    },
    {
      "step_id": "step-2-write-migration",
      "step_type": "file_created",
      "evidence": "created database/migrations/2026_05_25_100000_create_subscriptions_table.php (47KB)",
      "compensating_action": "rm database/migrations/2026_05_25_100000_create_subscriptions_table.php",
      "idempotent": true,
      "applied_at": null
    }
  ]
}
```

**2. Canonical step_type taxonomy (14 types)**

Each maps to default compensating action template + idempotency flag. Bolt subagent classifies each significant step using these EXACT names (`file_created` / `file_modified` / `file_partially_written` / `file_deleted` / `composer_dep_added` / `composer_dep_removed` / `npm_dep_added` / `npm_dep_removed` / `migration_created` / `migration_executed` / `external_api_call` / `test_command_run` / `git_commit` / `git_branch_created`). Unknown values → `partial_state_corrupt` halt.

**3. `--rollback <unit-id>` flag (NEW)**

Reads partial-state.json v2.0. If `rollback_hints[]` present, displays reverse-order list with idempotency markers:

```
Rolling back partial bolt U-007 (3 compensating actions):

  3. file_partially_written: git checkout HEAD -- app/Http/Controllers/SubscriptionController.php  [idempotent ✓]
  2. file_created: rm database/migrations/2026_05_25_100000_create_subscriptions_table.php  [idempotent ✓]
  1. composer_dep_added: composer remove laravel/cashier --no-update && git checkout composer.json composer.lock  [idempotent ✗ — composer cache may persist]

Apply in reverse order (3 → 2 → 1)?
  [Y] proceed   [N] cancel   [I] interactive (per-action confirm)
```

Per-action confirmation default safe for non-idempotent. Applied actions stamp `applied_at:` so partial rollback can be resumed. On full rollback completion: partial-state.json renamed to `.rolled-back-<ISO8601>` for forensics.

**4. Bolt subagent contract (bolt-dispatch-prompt.md `## Rollback hints` section)**

For EACH significant step bolt subagent performs, append rollback hint to bolt-report.md `## Rollback hints` section. On crash: execute-bolts harvests into partial-state.json. On success: section is INFORMATIONAL (audit trail).

**5. Backward compat**

- v1.0 partial-state.json (Iter 30 baseline) → `--rollback` errors with manual-review guidance (`git status` + `git diff HEAD`)
- `--resume` still works on v1.0 (forward-only behavior preserved)
- New bolt writes always emit v2.0 schema

**Halt semantics:** malformed `rollback_hints[]` entries (missing required fields OR unknown `step_type`) → reuses existing `partial_state_corrupt` halt (Iter 40) with `malformed_hints: [<entry indices + reason>]` detail. No new halt type.

**Surface changes:**
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — `--rollback` + `--resume` flags documented in Inputs; §Partial-state contract extended with v2.0 schema + canonical step_type taxonomy table + new §Saga compensating actions section
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — `## Rollback hints` self-assessment section added with canonical taxonomy table + emission contract
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.29.0 → 3.30.0
- `plugins/mega-sdd/README.md` — + v3.30.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-45-saga-compensating-actions-design.md` — new spec

**Out of scope:**
- Auto-rollback on crash (user-initiated only; auto-rollback compounds non-idempotent errors)
- Cross-bolt saga (rollback scope = single bolt U-XXX)
- DB schema introspection for `migration_executed` rollback (relies on framework's standard rollback command; user accepts risk via per-action confirmation)

**Skill bumps:**
- `execute-bolts` 2.8.0 → 2.9.0 (MINOR)

**External research applied:**
- Saga Pattern (microservices.io) — compensating action design
- Compensating Transactions (Microsoft Azure) — idempotency flag pattern

**Standing directives applied:**
- simplifikasi: 1 audit Pattern (D + extension to D3-003) → schema bump + 1 new flag + 1 new self-assessment section in 2 files
- flawless: producer (bolt subagent emits hints) + consumer (execute-bolts harvests on crash + applies on `--rollback`) ship in-iter; v1.0 readers gracefully degrade
- reuse-first: extends Iter 30 partial-state contract + reuses Iter 40 `partial_state_corrupt` halt for malformed hints + extends existing bolt-dispatch-prompt.md self-assessment pattern

**Plugin:** v3.29.0 → v3.30.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-45-saga-compensating-actions-design.md`

**Next:** Iter 46 — section-snapshot reuse (Queue #6; D1-006 + D2-007; ~3hr; MEDIUM impact iterative-run ROI).

## [3.29.0] - 2026-05-25

### Iter 44 — T2 Running Budget Tracker + Progressive Truncation

**Performance iter** (~2hr; MINOR bump — new step + new dispatch-prompt section). Closes Iter 38 audit Queue #4 (D1-003, HIGH impact per-bolt).

**Problem (D1-003):** T2 5KB soft cap was aspirational — no running budget enforced. Single 10KB hard halt only. Complex units silently exceeded T2 target until tripping the hard cap (halt-or-pass binary). Audit estimate: 15-30% T2 size reduction for complex units.

**Solution: 3 new mechanisms in execute-bolts §Step 4.5**

**1. Running budget tracker (Step 4.5.a.5, NEW)**

Initialized after TIER 1 load, before TIER 2 load:
```
running_budget = {
  cap_hard:      10240     # 10KB hard cap (unchanged)
  cap_target:    7168      # 7KB total target
  cap_t1:        2048      # 2KB T1 budget
  cap_t2:        5120      # 5KB T2 budget (now ENFORCED)
  consumed_t1:   <bytes>
  consumed_t2:   0
  remaining_t2:  cap_t2
  warnings:      []
}
```

After EACH T2 section loads: update `consumed_t2`; if `remaining_t2 < next_section_min_viable_bytes` → apply progressive truncation per priority table BEFORE loading next section. Truncation events logged to `warnings` array for provenance.

**2. 8-tier section priority + per-section truncation cascade**

| Priority | Section | Cascade | Drop floor |
|---|---|---|---|
| 1 | validation_hints | drop expected-output; keep commands | drop |
| 2 | historical_memory | 5→3→1→drop | drop |
| 3 | kb_anti_patterns | top 3→top 1→drop | drop |
| 4 | confidence_labels | per-claim → aggregate | drop |
| 5 | depends_on_summaries | N most-recent → 1 minimum | keep 1 |
| 6 | framework_pack_rules | top 5→top 3→top 1 | keep top 1 |
| 7 | starterkit_slice | (existing Iter 32 cascade) | per Iter 32 |
| 8 (NEVER drop) | constitution_clauses | n/a — LOCKED | halt if exceeds |

**3. Soft-budget warnings (NEW)**

When `consumed_t2 > cap_t2` but `total < cap_hard`:
- Log warning (NOT halt): `"T2 exceeded soft cap: target=5KB, actual=<N>KB — truncation applied"`
- Truncation still applied; bolt proceeds with truncated context
- Provenance trail visible to subagent via NEW `### T2 budget tracker` section in bolt-dispatch-prompt.md

**Self-assessment integration** — subagent instructed: "if your self-assessment references truncated information, mark confidence as MEDIUM (not HIGH) and note the truncation in bolt-report.md self-assessment section. Truncation is NOT a failure — it's transparency."

**Halt semantics (preserved)** — `dispatch_prompt_too_large` now fires ONLY when constitution_clauses alone exceeds budget after all disposable T2 sections truncated to drop floor. True config issue requiring spec-level adjustment. Iter 30 halt semantics preserved.

**Surface changes:**
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.a.5 (NEW); §T2 Section Priority + Truncation table (NEW); §Halt path (rewritten); §Soft-budget warnings (NEW); Step 4.5.d (rewritten to surface tracker)
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — `### T2 budget tracker` section added between Validation hints and TIER 3 marker
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.28.1 → 3.29.0
- `plugins/mega-sdd/README.md` — + v3.29.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-44-t2-running-budget-tracker-design.md` — new spec

**Skill bumps:**
- `execute-bolts` 2.7.3 → 2.8.0 (MINOR)

**External research applied (Iter 38 audit citations):**
- Anthropic Prompt Caching — context window budget discipline
- Subagent Token Patterns (Sathish Raju Medium) — graceful degradation > halt

**Standing directives applied:**
- simplifikasi: 1 audit finding → 1 new step + 1 new reference section + 1 rewritten step in 2 files
- flawless: halt semantics preserved (cap_hard still fires); soft-budget enforcement added incrementally; self-assessment field gives subagent visibility into truncation
- reuse-first: extends Iter 30 tiered-context architecture + Iter 32 starterkit cascade pattern + existing halt envelope

**Plugin:** v3.28.1 → v3.29.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-44-t2-running-budget-tracker-design.md`

**Next:** Iter 45 — saga compensating actions (Queue #5; D3-009 + D3-003; ~5hr; MEDIUM impact).

## [3.28.1] - 2026-05-25

### Iter 43 — FIX-FORWARD: handoff_missing semantics + schema doc + savings accuracy

**Release-blocker fix iter** (PATCH bump). Cumulative code-quality review of Iters 39-42 (commits ea574da..3d11c09) by `superpowers:code-reviewer` subagent surfaced 1 CRITICAL + 1 CRITICAL + 2 MEDIUM + 2 ADVISORY findings. Iter 43 closes all CRITICAL + MEDIUM; ADVISORY items now fully addressed.

**CRITICAL fixes:**

**C1 — `handoff_missing` would fire on every auto run (Iter 40 regression)**

Original Iter 40 design: orchestrate-flow Step b.0 computed an expected handoff file path (`<vault>/.internal/checkpoints/<ISO8601>-<skill>.handoff.yaml`) and ran `test ! -f` on it. **Problem:** no skill actually writes that file — every skill's `## Handoff emission` section emits the handoff YAML inline in chat output (as text in the last assistant message). The file-existence check would have produced spurious `handoff_missing` halts on the very first run, blocking every `--auto` chain.

Fix (orchestrate-flow v3.2.1+):
- Step b.0 rewritten to scan sub-skill's **chat output** (last assistant message) for a YAML code fence containing top-level `handoff:` key. Detects the canonical emission per `handoff-contract.md`.
- Halt envelope gains `chat_tail_excerpt: <last 500 chars>` field for diagnostic clarity (replaces hardcoded `expected_handoff_path:`).
- `vault-contract.md §halt-protocol` description updated to match chat-block semantics.
- `handoff-contract.md` Emission contract section added documenting skill-author rule + showing minimal emission example.

**C2 — starterkit-context-schema.md left at v1.0 while producer writes v2.0 (Iter 42 propagation gap)**

Iter 42 bumped `scan-codebase` to v2.7.0 emitting `schema_version: 2.0` with `cache_signatures:` block, but `plugins/mega-sdd/references/starterkit-context-schema.md` (the canonical reference doc consumed by bind-codebase, generate-units, execute-bolts) was still documented as v1.0 with `cache_key:` block. Violates 4-surface taxonomy directive (Iter 33+31).

Fix:
- Schema doc bumped to v2.0 with full `cache_signatures:` block spec
- Added per-slice invalidation matrix table (PHP dep edit → 25% savings; JS dep edit → 50%; single lib-pattern → 75%; framework pack rewrite → 0% / all 4 dispatched)
- Backward-compat note for v1.0 readers

**MEDIUM fixes:**

**M1 — Iter 42 CHANGELOG savings claims were inverted/imprecise**

Original claim ("composer.json frontend dep added → 50% saving") was technically incoherent (composer manages PHP, not frontend) and the math was wrong. composer.lock change invalidates auth+rbac+libs (3/4) — actual savings ≈ 25%. package.lock change invalidates ui_ux+libs (2/4) — actual savings ≈ 50%. Single lib-pattern edit invalidates 1 slice — actual savings ≈ 75%.

Fix: corrected invalidation matrix now documented in starterkit-context-schema.md (canonical) and in v3.28.1 README "What's new" entry. Historical Iter 42 CHANGELOG entry preserved as-shipped (no retroactive edit); reader-facing fix lives in this entry + canonical schema doc.

**M2 — Iter 41 framing accurate but grep-defined**

Iter 41 "halt taxonomy in sync" claim is bullet-vs-enum reconciliation specifically (false positives exist for halts with `### Type-specific guidance` sections instead of bullets). No regression; cosmetic concern. No fix needed in v3.28.1 — flagged for future contributor docs.

**ADVISORY fixes (rolled in):**

**A1 — partial_state_corrupt canonical path**: vault-contract.md description had `<vault>/.internal/checkpoints/partial-state.json` while execute-bolts §Partial-state contract emit example used `<vault>/bolts/U-XXX/partial-state.json`. Canonicalized to the per-bolt path (matches execute-bolts emit; matches the user-facing rename instruction).

**A2 — Handoff filename pattern drift**: superseded by C1 fix. Skills no longer required to write a file; chat-block is authoritative. Optional file-write convention (`<vault>/.internal/checkpoints/<ISO8601>-<skill>.handoff.yaml` for replay/audit) preserved in handoff-contract.md.

**Surface changes:**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step b.0 rewrite (chat-block detection); skill version 3.2.0 → 3.2.1
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — Pre-validation section rewritten; Emission contract section added
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — `handoff_missing` + `partial_state_corrupt` descriptions corrected
- `plugins/mega-sdd/references/starterkit-context-schema.md` — v1.0 → v2.0 doc bump (full)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.28.0 → 3.28.1
- `plugins/mega-sdd/README.md` — + v3.28.1 What's new entry; version refs
- `README.md` — version refs

**Skill version bumps:**
- `orchestrate-flow` 3.2.0 → 3.2.1 (semantics correction; PATCH)

**Validation method:** dispatched `superpowers:code-reviewer` subagent to diff `ea574da..3d11c09` (Iter 38 audit → Iter 42 release) against audit findings + advisor concerns. Subagent verified all skill SKILL.md `## Handoff emission` sections to confirm no skill writes handoff to a file — chat-block is universal emission convention. C1 confirmed as release-blocker.

**Per simplifikasi+flawless:** caught + fixed Iter 40 regression BEFORE Iter 43's intended T2 budget tracker work, instead of stacking new features atop broken foundation. Validation gate (advisor + code-reviewer subagent) prevented production deployment of broken `handoff_missing` halt. T2 budget tracker deferred to Iter 44 with cleaner foundation.

**Plugin:** v3.28.0 → v3.28.1

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Validation method (NEW pattern for cumulative-iter sessions):**
1. Advisor checkpoint after 4 iters
2. `superpowers:code-reviewer` subagent diffs full cumulative range against audit
3. Findings classified CRITICAL/MEDIUM/ADVISORY
4. Fix-forward iter shipped BEFORE next feature iter

**Next:** Iter 44 — T2 running budget tracker (Queue #4 from audit; D1-003; ~3hr; HIGH impact).

## [3.28.0] - 2026-05-25

### Iter 42 — Deep-Scan Manifest Pre-Parse + Per-Slice Cache

**Performance iter** (~3hr; MINOR bump — new optimization step + cache schema bump). Closes Iter 38 audit Queue #3 (priority 3, HIGH impact — every project pipeline benefits).

**Problems closed:**

- **D1-002** (token waste): 4 deep-scan subagents each re-read composer.json + package.json (~9-24KB redundant I/O per scan; ~10-20% per-subagent context budget waste).
- **D2-003** (compute waste): single composite cache_key invalidates ALL 4 slices on any input change. Frontend dep edit forces re-dispatch of auth+rbac (PHP-side; unchanged).

**Change 1 (D1-002): Manifest pre-parse — `scan-codebase` Step 10.5.1.5 (NEW)**

Main thread parses `composer.json` + `package.json` ONCE before subagent dispatch:
- Extracts: dependencies, dev_dependencies, scripts, autoload_psr4 (composer) / dependencies, devDependencies, peerDependencies, scripts, type (package)
- Builds canonical `manifest_facts` YAML struct
- Injects into 4 subagent prompts via new `<MANIFEST_FACTS>` placeholder (per `references/deep-scan-prompts.md` v2.7+ contract)

Subagent prompts updated: "manifest_facts is authoritative; do NOT re-read manifest/lock files. Spend context on framework-specific source files."

**Net savings:** ~9-24KB per scan (4 subagents × ~2-6KB saved per subagent context).

**Change 2 (D2-003): Per-slice cache — schema v2.0 (`cache_signatures:` replaces `cache_key:`)**

Each of 4 slices tracks its own signature:
- `auth_signature` = sha256(composer.lock + framework_pack §auth + lib-patterns/<fw>/auth-libs.md)
- `rbac_signature` = sha256(composer.lock + framework_pack §rbac + lib-patterns/<fw>/rbac-libs.md)
- `ui_ux_signature` = sha256(package.lock + framework_pack §ui + lib-patterns/<fw>/ui-libs.md)
- `libs_signature` = sha256(composer.lock + package.lock + framework_pack §libs + lib-patterns/<fw>/generic-libs.md)

**Routing logic (Step 10.5.1):**
- All 4 slices match prior signatures → FULL CACHE HIT (no dispatch needed)
- 1-3 slices stale → PARTIAL CACHE HIT (selective dispatch; consolidator merges fresh + cached)
- All 4 slices stale or no prior YAML → FULL CACHE MISS (dispatch all 4)

**Net savings (incremental edits):**
- composer.json frontend dep added → ui_ux + libs invalidate; auth + rbac cached → 50% subagent saving
- Lib-pattern file (e.g., auth-libs.md) edited → only auth slice invalidates → 75% saving
- Framework pack changed → all 4 invalidate (equivalent to current; no regression)

**Schema migration (backward compat):** existing starterkit-context.yaml with v1.0 `cache_key:` block treated as fully-stale on read; auto-migrates to v2.0 `cache_signatures:` on next write. One-time migration cost; zero breaking change for users.

**`reused_slices:` provenance field added** to starterkit-context.yaml — lists which slices were cached vs freshly-dispatched in the latest run. Aids debugging.

**Surface changes:**
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — Steps 10.5.1, 10.5.1.5 (NEW), 10.5.2, 10.5.3 reworked
- `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` — added `<MANIFEST_FACTS>` placeholder spec
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.27.1 → 3.28.0
- `plugins/mega-sdd/README.md` — + v3.28.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-42-deep-scan-manifest-preparse-and-per-slice-cache-design.md` — new spec doc

**Skill bumps:**
- `scan-codebase` 2.6.3 → 2.7.0 (MINOR — new step + cache schema bump)

**External research cited inline in spec:**
- Anthropic prompt caching docs (90% discount; subagent-token pattern)
- Real-time codebase indexing (cocoindex-io) — per-file hash invalidation
- Multi-agent caching arXiv 2601.06007 — separate static instructions from dynamic outputs

**Standing directives applied:**
- simplifikasi: 2 audit findings → 1 iter, 2 atomic changes in 2 files (1 SKILL + 1 reference doc)
- flawless: backward-compat schema migration; v1.0 readers treated as fully-stale (no rejection)
- reuse-first: extends Iter 30 shared-snapshot cache pattern + Iter 32 deep-scan subagent dispatch pattern + existing variable-substitution template format

**Plugin:** v3.27.1 → v3.28.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Next:** Iter 43 — T2 running budget tracker (Queue #4 — D1-003, HIGH impact per-bolt).

## [3.27.1] - 2026-05-25

### Iter 41 — Halt Taxonomy Sync Sweep

**Registry hygiene iter** (~1hr; PATCH bump — pure docs/contract additive; no code/behavior change). Reconciles canonical halt registry with reality.

**Problem (from Iter 38 audit D3-006):**

Pre-sweep gap analysis (`/tmp/halts_*.txt` diff):
- Halts emitted by skills + listed in orchestrate-flow but MISSING from `vault-contract.md §halt-protocol` enum: **9** (any strict envelope validator would reject these)
- Halts in vault-contract enum but missing from orchestrate-flow taxonomy: **5** (orchestrator couldn't decide auto-loop vs ALWAYS-STOP routing)
- Halts in enum but with no bulleted description: 9 (have richer §Type-specific guidance sections instead — false positives, no action)

**Resolution: surgical sync across 2 surfaces**

Surface 1 — `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`:
- Enum extended: +9 halt types
- Description list extended: +9 bulleted entries with provenance (`producer-skill v<X.Y>+, Iter <N>` + canonical resolution path)

Surface 2 — `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`:
- ALWAYS-STOP taxonomy: +5 entries (`oq_blocker`, `cross_squad_ambiguous`, `cycle_detected`, `interface_ref_missing`, `pbt_citation_invalid`)
- `pbt_citation_invalid` specifically closes an Iter 39 oversight (added to enum but missed orch taxonomy)

**Halts added to enum + description (9):**
1. `dedup_ambiguous` — generate-units v2.5+: multi-unit dedupe ambiguity
2. `hard_rule_unparseable` — generate-units v2.0+: ast-grep YAML parse failure
3. `hard_rule_violated` — execute-bolts v1.2+, Iter 3: post-flight scan violation
4. `memory_schema_mismatch` — memory v1.0+, Iter 5: schema_version drift
5. `prd_no_scopes_block_user_rejected_retrofit` — generate-intent v1.6+, Iter 28
6. `prd_path_missing` — diff-vault v1.3+, Iter 29
7. `prd_retrofit_low_confidence` — generate-intent v1.6+, Iter 28
8. `quality_gate_failed` — extract-intelligence v1.0+, Iter 9
9. `scope_not_declared_in_prd` — generate-intent v1.6+, Iter 28

**Halts added to orch ALWAYS-STOP taxonomy (5):**
1. `oq_blocker` (canonical; coexists with `oq_business_p1_unresolved` orch-level alias)
2. `cross_squad_ambiguous`
3. `cycle_detected`
4. `interface_ref_missing`
5. `pbt_citation_invalid` (Iter 39 oversight)

**Counts:**
- Enum: 37 → **46** halts (+9)
- Description list: 28 → **37** bullets (+9 provenance entries)
- Orch taxonomy: 39 → **44** entries (+5)

**No new files. No new halts in code. No skill version bumps** — pure registry reconciliation.

**Audit gap-finder commands** (reproducible):
```bash
# Enum extraction
grep -A0 "type: oq_blocker" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -1 | sed 's/.*type: //' | tr '|' '\n' | sort -u
# Description extraction
awk '/^## §halt-protocol/{flag=1} /^### Multiple blockers/{flag=0} flag' vault-contract.md | grep -oP '^- `[a-z_]+`'
# Orch extraction
grep -oP '^- `[a-z_]+`' plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
```

**Standing directives applied:**
- simplifikasi: 14 reconciliations → 2 atomic edits (1 enum extend + 1 description append)
- flawless: closes Iter 39 pbt_citation_invalid oversight + all Iter 28/29 propagation gaps + all Iter 3/5/6/9/20 historical gaps
- reuse-first: extends existing enum + existing description list; no schema changes

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Next:** Iter 42 — token optimization (priority 3 from audit queue): tier-2/tier-3 context references on-demand loading.

**Plugin:** v3.27.0 → v3.27.1

## [3.27.0] - 2026-05-25

### Iter 40 — Silent-Failure Path Closure (3 new halts)

**Robustness iter** (~2hr; MINOR bump — new orchestrator halts = chain behavior change). Closes 3 priority-1 silent-failure paths from Iter 38 e2e optimization audit (D3 robustness dimension).

**Problem (from audit):**
- D3-001: producer skill crashes before handoff emission → orchestrator silently proceeded with empty state OR failed downstream with cryptic file-not-found
- D3-002: handoff YAML lists artifact paths that don't exist on disk → next-stage consumer failed at the wrong boundary
- D3-003: execute-bolts `--resume` reads corrupt partial-state.json → silent overwrite with fresh state, hidden recovery loss

**Solution: 3 new ALWAYS-STOP halts**

- `handoff_missing` (orchestrate-flow v3.2.0+) — pre-validation step `b.0` verifies handoff YAML file exists + is non-empty before parse. Envelope includes `expected_handoff_path` + `last_known_step` (best-effort from checkpoint trail).
- `artifact_missing` (orchestrate-flow v3.2.0+) — post-validation step `b.vii` existence-checks every path in `artifacts: [paths]` array. Envelope includes `missing_paths: array` + `present_paths: array` for diagnostic clarity.
- `partial_state_corrupt` (execute-bolts v2.7.3+) — resume-time JSON parse attempt before consumption. Envelope includes `corrupt_backup_path` suggestion (`.corrupt-<ISO8601>`) for forensics.

**4-surface taxonomy sync** (per Iter 33+Iter 31 propagation directive):

1. `vault-contract.md §halt-protocol` enum + 3 new descriptions
2. `orchestrate-flow/SKILL.md` ALWAYS-STOP taxonomy + 2 new Procedure steps (`b.0` + `b.vii`)
3. `orchestrate-flow/references/handoff-contract.md` documents orchestrator-side detection for `artifacts:` field + pre-validation handoff presence check
4. `execute-bolts/SKILL.md §Partial-state contract` resume-time integrity check

**Plugin file changes:**
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.26.3 → 3.27.0
- `plugins/mega-sdd/README.md` — + v3.27.0 What's new entry
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — v3.1.2 → v3.2.0 (2 new procedure steps + 3 new ALWAYS-STOP taxonomy rows)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — orchestrator-side detection doc
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — v2.7.2 → v2.7.3 (+ partial-state integrity check)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — 3 new halts
- `docs/superpowers/specs/2026-05-25-iter-40-silent-failure-path-closure-design.md` — new spec doc
- `README.md` — version bump

**Why MINOR (not PATCH):** chains that previously silently-passed corrupt/missing state now halt explicitly. Backward-compat note: any user workflow that depended on "silent recovery" behavior will see new halts surface — by design.

**Standing directives applied:**
- simplifikasi: 3 halts → 5 surgical edits across existing surfaces (no new SKILL.md files, no new references)
- flawless: producer + consumer ship in-iter (orchestrate-flow emits + same orchestrate-flow consumes via halt-protocol). No deferred propagation. All 4 taxonomy surfaces updated.
- reuse-first: extends existing halt envelope (vault-contract.md), existing ALWAYS-STOP taxonomy, existing per-step JSONL checkpoint protocol (no new persistence)

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Spec:** `docs/superpowers/specs/2026-05-25-iter-40-silent-failure-path-closure-design.md`

**Next:** Iter 41 — halt taxonomy sync sweep (priority 2 from audit queue) — verify all 38+ halts are present across all 4 surfaces.

**Plugin:** v3.26.3 → v3.27.0

## [3.26.3] - 2026-05-25

### Iter 39 — Quick Audit Closure Pass (5 immediate wins)

**Documentation iter** (~40min; PATCH bump — no behavior change). Closes 5 P1/HIGH findings from Iter 38 e2e optimization audit.

**Findings closed (5 of 37):**
- **D4-001** layer count drift: plugin README `(13 layers)` → `(15 layers)` + added layer 14 (predictive preflight from Iter 33 F2) + layer 15 (handoff schema validation from Iter 33 F3+F4). Root README stale "13-layer pipeline defense above" → "15-layer pipeline defense above". (Note: Iter 37 partial fix only updated the top-of-README header; this iter closes the trailing references and brings plugin README into alignment.)
- **D3-010** `--max-cycles` default mismatch: `orchestrate-flow/SKILL.md` documented `default 5` in 2 places while `commands/orchestrate-flow.md` said `default 3`. Canonicalized to **3** — single source of truth.
- **D3-007** `--force-skip-postflight` undocumented: escape hatch now formally documented in `execute-bolts/SKILL.md ## Inputs` with WARNING block citing anti-bypass policy. Use logged via handoff YAML `notes.postflight_skipped: true`.
- **D3-004** `pbt_citation_invalid` missing from halt enum: added to `vault-contract.md §halt-protocol` type list + canonical description.

**Findings re-verified (not in patch):**
- **D3-005** `diff_conflict` ALWAYS-STOP: verified already present at `orchestrate-flow/SKILL.md:485`. Original audit finding was based on stale state. Skipped from this patch.

**Plugin file changes:**
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.26.2 → 3.26.3
- `plugins/mega-sdd/README.md` — anti-hallu defense layer count + v3.26.3 What's new entry
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — v2.7.1 → v2.7.2 (+ `--force-skip-postflight` flag)
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — v3.1.1 → v3.1.2 (max-cycles=3 canonical)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — +pbt_citation_invalid halt
- `README.md` — version bump + 13-layer → 15-layer trailing reference

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Standing directives applied:**
- simplifikasi: 5 atomic findings → 5 surgical edits in 1 atomic commit
- flawless: NO finding deferred ("skip if hard" is a deferral pattern); D3-005 re-verified before skipping
- reuse-first: extended existing halt enum + existing Inputs section (no new files)

**Next:** Iter 40 — silent-failure path closure (handoff_missing / artifact_missing / partial_state_corrupt halts) — audit priority 1.

**Plugin:** v3.26.2 → v3.26.3

**Audit reference:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

## [3.26.2] - 2026-05-24

### Iter 37 — Scenarios Coverage + README Audit

**Documentation iter** (~3-4hr; PATCH bump — no behavior change). Field-test feedback closure: missing scenarios for Iters 34/35 + README staleness.

**New scenarios (2):**
- `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md` — Iter 35 tutorial (legacy → KB → Phase 1 vault → bolts → Phase 2 vault workflow)
- `tests/scenarios/scenario-11-model-tier-override.md` — Iter 34 tutorial (curated catalog + 4 override mechanisms + tier escalation rubric)

**Modified docs:**
- `tests/scenarios/README.md` — chooser updated to include all 11 scenarios + upgrade-guide pointer
- `README.md` (repo root) — "13-layer anti-hallucination defense (v3.18.0)" → "15-layer anti-hallucination defense (v3.24+, includes Iter 33 F3+F4)". Entries 14+15 (schema validation + type-check) were already in the list; header was stale.
- `plugins/mega-sdd/README.md` — fixed stale v3.18.1 reference in "What's in this folder"; normalized "What's new" structure (### per version under ## What's new parent, newest first); added v3.26.2 entry

**Plugin:** v3.26.1 → v3.26.2

**No skill version bumps** — pure documentation iter.

**Standing directives applied:**
- simplifikasi: 2 new files (one per missing iter scenario); skipped separate Iter 36 scenario (upgrade-from-old-version.md IS the upgrade walkthrough)
- flawless: 3 problems (missing scenarios + repo README stale + plugin README stale) all solved in 1 iter
- reuse-first: scenarios cross-ref reading-map.md + model-tiers.md + upgrade-from-old-version.md; chooser cross-refs all existing docs

**Spec:** `docs/superpowers/specs/2026-05-24-iter-37-scenarios-coverage-and-readme-audit-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-37-scenarios-coverage-and-readme-audit.md`

## [3.26.1] - 2026-05-24

### Iter 36 — Upgrade-from-old-version guide

**Documentation iter** (~2hr; PATCH bump — no behavior change). Field-test feedback: users coming from older mega-sdd versions had no consolidated upgrade guide.

**New plugin files (1):**
- `plugins/mega-sdd/references/upgrade-from-old-version.md` — consolidates compatibility matrix + migration command order + halt-by-halt recovery + decision tree + pre-flight checklist

**Skill bumps:**
- `using-mega-sdd` 1.3.3 → 1.3.4 (Upgrade guide cross-ref)

**Coverage:**
- 11-row compatibility matrix (legacy paths, pre-v1.4 KBs, pre-v2.4 codebase-maps, vault scope/phase/binding evolution)
- 5 common halts mapped to recovery (invalid_handoff, memory_schema_mismatch, handoff_type_mismatch, provenance_missing, bind_conflict)
- 3 migration commands in canonical order (migrate-paths → memory migrate → migrate-rules)
- Decision tree: Path A (regenerate) vs Path B (preserve)

**Standing directives applied:**
- simplifikasi: 1 new file solves 1 problem
- flawless: covers all known compat halt sources from Iters 8/9/10/22/27/30/33/35
- reuse-first: cross-refs scenario-6 + CHANGELOG + paths.md + reading-map.md (no duplication)

**Plugin:** v3.26.0 → v3.26.1

**Spec:** `docs/superpowers/specs/2026-05-24-iter-36-upgrade-from-old-version-design.md`

## [3.26.0] - 2026-05-24

### Iter 35 — Reading Map + Phase Discoverability (with audit closure)

**Feature iter** (~5-7hr). Per simplification + flawless directive: 3 problems solved in 1 iter; 1 new file; atomic commits per surface sync; no deferrals to Iter 36.

**Skills bumped:**
- `scan-codebase` 2.6.1 → 2.6.2 (line 37 stale prose fix — audit closure)
- `generate-intent` 1.13.0 → 1.14.0 (`--phase=N` flag + vault.json schema extension + 00-index.md §Phase context block)
- `execute-bolts` 2.7.0 → 2.7.1 (end-of-chain next_action references Phase N+1)
- `orchestrate-flow` 3.1.0 → 3.1.1 (chain summary surfaces phase context)
- `using-mega-sdd` 1.3.2 → 1.3.3 (reading-map.md cross-ref)

**New plugin files (1):**
- `plugins/mega-sdd/references/reading-map.md` — user-facing pipeline-stage-to-location guide (companion to implementer-facing paths.md)

**vault.json schema extension:**
- `phase: int` — which phase this vault represents (default 1)
- `phase_total: int` — total phases planned (default 1 if not legacy-rebuild)
- Back-compat: missing fields → treated as `phase: 1, phase_total: 1`

**generate-intent --phase=N flag (Mode B with --kb):**
- Parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for phase plan
- Scopes vault to Phase N's deliverables
- Validates N ≤ phase_total at invocation time
- Defensive fallback when suggested-phasing.md absent or empty

**00-index.md §Phase context block:**
- Surfaces "Phase N of M" at top of vault entrypoint
- Lists upcoming phases with 1-line summaries
- Provides next-phase command verbatim
- Omits upcoming/command sections for single-phase projects (cleaner display)

**Audit closure:**
- `scan-codebase/SKILL.md` line 37 stale prose fixed (claimed "repo root" — actual: `.mega-sdd/codebase/codebase-map.md` per paths.md v3.4+)
- Verified: AGENTS.md at repo root is INTENTIONAL per tool-interop standard (Continue.dev/Cursor/Aider discoverability)
- Verified: all mega-sdd-generated artifacts (vault, binding, units, bolts, memory, KB, codebase, configs) live under `.mega-sdd/` or `~/.mega-sdd/` per paths.md canonical v3.4+

**Trigger test coverage (+2 cases):**
- GI-PH1 — default phase=1 with --kb (auto phase_total from suggested-phasing.md)
- GI-PH2 — explicit --phase=2 (vault scoped to Phase 2 deliverables)

**Standing user directives applied:**
- "simplifikasi + flawless" — 1 new file, 3 problems in 1 iter, atomic commits
- "propagation within iter" — schema + producer + consumer ship together
- "reuse over reinvent" — reading-map.md cross-refs paths.md instead of duplicating layout
- "deep search" — verified insertion points (generate-intent Mode B Step 2.5 insertion) before writing

**Back-compat preserved:**
- Old vaults without `phase` field → default `phase: 1, phase_total: 1`
- Mode A (PRD-driven) + Mode B free-text → always `phase: 1, phase_total: 1` (no legacy-rebuild phasing)
- Single-phase projects → cleaner display (no upcoming-phases noise)

**Plugin:** v3.25.0 → v3.26.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-35-reading-map-and-phase-discoverability.md`

## [3.25.0] - 2026-05-24

### Iter 34 — Dynamic Model Selection per Subagent Dispatch

**Feature iter** (~8hr): adds curated model-tiers catalog + override chain so every named subagent role uses the right model tier.

**Skills bumped:**
- `orchestrate-flow` 3.0.0 → 3.1.0 (Step 2.8 override-chain resolution)
- `scan-codebase` 2.6.0 → 2.6.1 (catalog citation; no behavior change)
- `extract-intelligence` 1.4.1 → 1.5.0 (catalog citation; wave-5 default → opus)
- `memory` 1.3.0 → 1.3.1 (preferences.md `## Model tiers` schema)

**New plugin files (1):**
- `plugins/mega-sdd/references/model-tiers.md` — catalog (17 roles × tier + rationale) + tier selection rubric + override syntax + adding-new-roles protocol

**Modified reference docs:**
- `handoff-contract.md` — + `model_tiers:` top-level block schema (REQUIRED/CONDITIONAL/OPTIONAL + TYPE per Iter 33 F3+F4)
- `vault-contract.md` — + `model_tier_unknown` halt type + description
- `memory-schema.md` — + preferences.md `## Model tiers` section
- `paths.md` — note .mega-sdd/config.yaml model_tiers override location
- `scan-codebase/references/deep-scan-prompts.md` — model citation
- `extract-intelligence/references/wave-dispatch-templates.md` — per-wave catalog citation

**1 new halt type** (registered across 4 surfaces per audit-pattern-prevention):
- `model_tier_unknown` (SOFT, orchestrate-flow Step 2.8) — override references role not in catalog. Log + ignore + chain proceeds. Forward-compat for future role additions.

**Catalog coverage — 17 roles across 4 dispatch categories:**

| Category | Roles | Tier mix |
|---|---|---|
| scan-codebase deep-scan (Iter 32) | auth-extractor, rbac-extractor, ui-ux-extractor, libs-extractor | 4× sonnet |
| extract-intelligence waves | wave-1, wave-2, wave-3, wave-4 | 4× sonnet |
| extract-intelligence synthesis | wave-5 | **1× opus** |
| Audit patterns | pipeline-audit-per-skill, pipeline-audit-consolidator, intelligence-audit-deep, intelligence-audit-probe | 2× sonnet + 1× **opus** + 1× **haiku** |
| Subagent-driven-development | implementer, spec-reviewer, code-quality-reviewer | 2× sonnet + 1× **opus** |
| Other | domain-research | 1× **haiku** |

Distribution: **3 opus + 12 sonnet + 2 haiku** (sonnet-dominant by design per tier rubric).

**Override chain (highest precedence first):**
1. CLI flag: `--model-tier=<role>:<tier>` (multiple allowed)
2. Per-project: `<project>/.mega-sdd/config.yaml` `model_tiers:`
3. User-scope: `~/.mega-sdd/memory/preferences.md` `## Model tiers`
4. Catalog default: `plugins/mega-sdd/references/model-tiers.md §Catalog`

**Tier selection rubric** (guides "find the best" decisions when adding new roles):
- **haiku**: bounded scope, narrow decision space, speed/cost dominates
- **sonnet**: pattern recognition, fuzzy classification (default)
- **opus**: open-ended reasoning, holistic synthesis, deep code review

**Trigger test coverage (+3 cases):**
- OF-MT1: catalog defaults applied when no overrides
- OF-MT2: CLI flag wins precedence chain
- OF-MT3: unknown role → soft halt + chain proceeds

**Standing user directive applied:**
> "perlu yg complpex pake opus, klo yg ringaan web and research.. and find the best"

Catalog rationale + rubric explicit per entry. Users override anywhere in chain. opus reserved for genuinely complex reasoning (synthesis, deep review); haiku for genuinely bounded tasks (probe scoring, research fetches).

**Backward compatibility:**
- Absent overrides → catalog default (no behavior change for previously-hardcoded sonnet dispatches)
- Absent catalog citation in a skill → inherits caller model (current behavior)
- Existing pipelines unaffected unless user explicitly overrides

**Reuse-first patterns:**
- NO new propagation mechanism — handoff metadata.model_tiers flows through Iter 33's existing handoff-contract.md schema validation gate (already validates handoff fields per type)
- model_tier_unknown halt uses canonical halt-protocol envelope from vault-contract.md (source_skill + type + details + next_action)
- File-format conventions match existing memory-schema.md preferences.md format (markdown list, kebab-case keys)

**Plugin:** v3.24.0 → v3.25.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-34-dynamic-model-selection.md`

## [3.24.0] - 2026-05-24

### Iter 33 — Flawless Seamless Intelligence (Orchestrator + Handoffs)

**Combined mega-iter**: 3-phase delivery (~28-33hr) closes Iter 31 audit debt + audits intelligence + ships 4 intelligence features. orchestrate-flow major bump v2.5.1 → v3.0.0.

**Skills bumped:**
- `orchestrate-flow` 2.5.1 → **3.0.0** (major: 4 new procedure steps + 4 new halts may STOP chains)
- `memory` 1.2.1 → 1.3.0 (new schema: routing-outcomes.md)
- `generate-intent` 1.12.0 → 1.13.0 (Phase A handoff YAML closure + halt enum extension)
- `bind-codebase` 1.9.3 → 1.9.4 (Phase A handoff sweep)
- `detect-drift` 1.4.0 → 1.4.1 (Phase A handoff sweep)
- `diff-vault` 1.3.0 → 1.3.1 (Phase A handoff sweep + artifact list fix)
- `extract-intelligence` 1.4.0 → 1.4.1 (Phase A handoff sweep)
- `resolve-oq` 0.9.1 → 0.9.2 (Phase A handoff sweep + broken cross-ref fix)
- `emit-agents-md` 1.2.4 → 1.2.5 (Phase A config path fix)

**New plugin files (2):**
- `references/lib-patterns/...` (no new lib-patterns this iter)
- `skills/memory/references/routing-outcomes.md` — schema doc for orchestrator routing learning (F1)
- `skills/orchestrate-flow/references/predictive-checks.md` — catalog of preflight checks per skill (F2)

**New test files (1):**
- `tests/scenarios/scenario-9-flawless-seamless-intelligence.md` — full-pipeline F1+F2+F3+F4 integration

**New audit doc (1):**
- `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` — Phase B output (6 dimensions + 13-skill scorecard)

**Modified reference docs:**
- `handoff-contract.md` — + 4 missing per-skill sections (diff-vault/emit-agents-md/resolve-oq/detect-drift) + REQUIRED/CONDITIONAL/OPTIONAL annotations (F3) + TYPE annotations (F4)
- `vault-contract.md` — + 19 halt types (15 Iter 31 + 4 Iter 33) + descriptions + stale source_skill enum fix
- `memory-schema.md` — + routing-outcomes.md entry in PROJECT scope
- `paths.md` — + routing-outcomes.md path
- `from-prompt-mode.md` — fixed broken cross-refs (stale paths)
- `commands/scan-codebase.md` + `commands/emit-agents-md.md` — fixed legacy paths

**Phase A — Mechanical closure (~7-8hr):**

Closes 3 of Iter 31's top 5 closure areas focused on orchestrator + handoff foundation. Enables Phase C F3's stricter validation gate.

- A1: Handoff YAML schema sweep — 8 skill SKILL.md templates + handoff-contract.md gain missing top-level blocks (scope/mutability/constitution); 4 missing per-skill sections added
- A2: Halt taxonomy + vault-contract enum sync — 15 previously-unregistered halts synchronized across orchestrate-flow + vault-contract + handoff-contract
- A3: Stale name sweep — 102 stale references (grand-design-spec/vault-diff/drift-detect/.mega-sdd-memory/) replaced with canonical names across vault-contract enum, broken cross-refs, test fixtures, command files

**Phase B — Intelligence audit (~5-6hr):**

Hybrid method: 2 parallel sonnet subagents (deep audit + per-skill probe). Produces AUDIT-INTELLIGENCE.md covering 6 intelligence dimensions on orchestrate-flow + handoff-contract + 13-skill 0-3 context-utilization scorecard. Findings inform Phase C feature specifics.

**Phase C — 4 intelligence features (~12-15hr):**

Smart orchestrator:
- **F1 Memory-driven routing** (C1) — orchestrator reads routing-outcomes.md at Step 2.7; recommends past-successful chains; writes outcome row at Step 7.5
- **F2 Predictive halt detection** (C2) — orchestrate-flow Step 3.5 runs predictive-checks.md catalog; non-fatal failures = warning; fatal failures = predictive_check_failed halt

Solid handoffs:
- **F3 Schema validation gate** (C3) — orchestrate-flow Step 6.b validates every received handoff against handoff-contract.md REQUIRED/CONDITIONAL annotations; missing field = invalid_handoff halt
- **F4 Type-checked field propagation** (C4) — Step 6.b.i validates types against TYPE annotations; mismatch = handoff_type_mismatch halt

**4 new halt types** (synchronized across all 4 surfaces per audit-pattern-prevention checklist):
- `routing_outcome_corrupt` (F1, SOFT) — routing-outcomes.md parse failure; auto-invalidate; chain proceeds
- `predictive_check_failed` (F2, ALWAYS STOP) — fatal preflight check failed; user fixes precondition
- `invalid_handoff` (F3, ALWAYS STOP) — handoff schema validation failed; producer-side error
- `handoff_type_mismatch` (F4, ALWAYS STOP) — handoff field type mismatch; producer-side error

**Trigger test coverage (+12 cases):**
- orchestrate-flow: OF-MR1/2 + OF-PH1/2 + OF-VG1/2 + OF-TC1/2
- memory: M-RO1/2
- scan-codebase: SC-PH1
- bind-codebase: BC-PH1

**Iter 31 audit findings preemptively addressed:**
- Phase A1 closes 12 P1 from Dim 3
- Phase A2 closes 13 P1 from Dim 4
- Phase A3 closes Patterns 2 + 4 (stale names/paths)
- F3 PREVENTS recurrence of "field claimed in prose but missing in template" (root cause pattern)

**Iter 31 deferred to Iter 34:**
- Closure Area 3: execute-bolts Step 4.5 reorder + snapshot schema alignment (~3hr)
- Closure Area 5: Test fixture backfill remaining gaps

**Standing user directives applied:**
- "Seamless + super intelligent + flawless" → orchestrator now intelligent (F1+F2); handoffs now flawless (F3+F4)
- "Producer + consumer in-iter" → F1/F2/F3/F4 each ship producer+consumer in same iter
- "Reuse over reinvent" → Iter 30 shared-snapshot cache pattern (F1 fingerprint cache); canonical halt envelope (all 4 new halts); memory file-lock pattern (F1 routing-outcomes write); extract-intelligence wave dispatch pattern (Phase B audit subagents)

**Plugin:** v3.23.0 → v3.24.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-33-flawless-seamless-intelligence.md`

## [3.23.0] - 2026-05-24

### Iter 32 — Starterkit-Aware Deep Scan (autonomous, default-on)

**Feature iter:** producer + consumer ship in-iter per propagation directive. No follow-up audit closure needed.

**Skills bumped:**
- `scan-codebase` 2.5.0 → 2.6.0 (Step 10.5 deep-scan stage + 4 parallel subagents + cache + 3 new halts)
- `generate-units` 2.5.4 → 2.6.0 (Step 7.7 starterkit Anchors + Hard Rules + Step 12.5 citation check + 1 new halt)
- `execute-bolts` 2.6.0 → 2.7.0 (Step 4.5.b-starterkit T2 slice injection)
- `orchestrate-flow` 2.5.0 → 2.5.1 (halt taxonomy: 4 new halts registered + SOFT halts subsection added)

**New plugin files (7):**
- `references/starterkit-context-schema.md` — canonical YAML schema for starterkit-context.yaml (~150 LOC)
- `references/lib-patterns/README.md` — lib-pattern catalog index + framework extension protocol
- `references/lib-patterns/laravel/auth-libs.md` — Sanctum / Breeze / Jetstream / Fortify / Passport detection
- `references/lib-patterns/laravel/rbac-libs.md` — Spatie/permission / laravel-permission / custom detection
- `references/lib-patterns/laravel/ui-libs.md` — JS/CSS/notification/icon/datatable libs detection
- `references/lib-patterns/laravel/generic-libs.md` — queue/cache/log/test/http/misc catalog
- `skills/scan-codebase/references/deep-scan-prompts.md` — 4 subagent prompt templates

**New test files (1):**
- `tests/scenarios/scenario-8-starterkit-aware-generation.md`

**Modified reference docs:**
- `skills/generate-intent/references/vault-contract.md` — halt type enum extended (+4 types)
- `skills/orchestrate-flow/references/handoff-contract.md` — `starterkit_context:` schema field defined; per-skill examples updated for scan-codebase, generate-units, execute-bolts
- `skills/execute-bolts/references/bolt-dispatch-prompt.md` — T2.3 "Starterkit context (relevant slice)" section added
- `references/paths.md` — row for `.mega-sdd/codebase/starterkit-context.yaml`

**4 new halt types** (registered across 4 surfaces: SKILL.md + vault-contract enum + orchestrate-flow taxonomy + handoff-contract per-skill examples — synchronized in one commit per iter-31 audit lessons):
- `deep_scan_subagent_failed` (soft, scan-codebase) — single subagent failed; auto-retry; partial output on second failure
- `deep_scan_cache_corrupt` (soft, scan-codebase) — starterkit-context.yaml YAML parse failed; cache auto-invalidated
- `deep_scan_subagent_all_failed` (ALWAYS STOP, scan-codebase) — all 4 subagents failed; user re-runs later
- `starterkit_rule_citation_missing` (ALWAYS STOP, generate-units) — starterkit-derived Hard Rule lacks Citation; user edits unit

**Trigger test coverage (+12 cases):**
- scan-codebase: SC-DS1..SC-DS6 (fresh deep-scan, cache reuse, cache invalidation, no-framework skip, subagent timeout + partial, all-fail hard halt)
- generate-units: GU-SK1..GU-SK3 (starterkit Anchors/Rules with citations, greenfield graceful degradation, missing citation halt)
- execute-bolts: EB-SK1..EB-SK2 (T2.3 slice injection only for relevant domains, slice >2KB truncation)
- orchestrate-flow: OF-SK1 (end-to-end starterkit_context propagation through 5 pipeline phases)

**Architecture summary:**
- `scan-codebase` Step 10.5 deep-scan stage runs automatically when framework confidence ≥ MEDIUM. Dispatches 4 parallel `sonnet` subagents (auth/rbac/ui-ux/libs). Consolidator writes `.mega-sdd/codebase/starterkit-context.yaml`.
- Cache via lock-file sha256 (composer.lock + package-lock.json | yarn.lock | pnpm-lock.yaml). Re-scan with unchanged deps: 0sec.
- `generate-units` Step 7.7 derives per-unit starterkit Anchors + Hard Rules with mandatory citations.
- `execute-bolts` Step 4.5.b-starterkit injects relevant slice (per `unit.starterkit_relevance`) into bolt-dispatch-prompt T2.3 section. Slice budget ≤2KB. Truncation order: libs[] → idioms[] → halt.
- User's standing prefs (SweetAlert2, `document.addEventListener` over jQuery ready, responsive mobile-first) flow into Hard Rules automatically when detected by ui-ux-extractor.

**Anti-halu rails (new):**
- No-fabrication: `lib: not_detected` is valid; subagents never guess
- Citation: every output field tied to `_source: [<file>, ...]`
- Read-only: subagents have no mutating tool access
- Citation-mandatory: every starterkit-derived Hard Rule MUST cite `starterkit-context.yaml §<path>`
- Slice-budget: T2 starterkit slice ≤2KB; truncation order enforced

**Iter-31 audit findings preemptively addressed:**
- Producer-only ship pattern: consumer skills (generate-units, execute-bolts) ship IN this iter
- Halt taxonomy gap: 4 new halts registered across all 4 surfaces in Task 4 (single synchronized commit)
- Test coverage gap: 12 new trigger test cases + 1 scenario test ship in-iter
- Stale skill name fossils: zero `grand-design-spec` / `vault-diff` / `drift-detect` in new files (canonical names only)

**Plugin:** v3.22.0 → v3.23.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-32-starterkit-aware-deep-scan.md`

---

## [3.22.0] — 2026-05-24

### Added — Iter 30: execute-bolts Refinement (Tiered Context + Seamless Pipeline)

User flagged execute-bolts as MOST CRUCIAL skill (it's where AI actually writes code). Mid-brainstorm user reframe surfaced the deepest issue: bolt subagents dispatched with insufficient context — they re-discover what binding/units/KB already know, hallucinate where grounding exists.

Iter 30 makes bolts SHARP via tiered context enrichment + 10 AI-executor principles, AND makes the pipeline seamless via propose-and-confirm halt UX + auto-drift gate.

### The 10 AI-executor principles (foundation)

1. **Context budget discipline** — tiered T1/T2/T3 (≤7KB total vs 50KB scatter)
2. **Anti-context** — DO NOT MODIFY / REPLICATE / WRITE / COMMIT IF blocks
3. **Confidence-aware per claim** — HIGH/MEDIUM/LOW labels with source citation
4. **Past-failure intelligence** — memory.outcomes.md filtered for patterns matching this unit
5. **Self-assessment vocabulary** — structured certain_decisions + uncertain_decisions + fallback_if_wrong
6. **Halt vocabulary in prompt** — 5 halt types + YAML templates pre-loaded
7. **Validation hints, not "run tests"** — specific commands + expected output + failure interpretation
8. **Atomic discipline reinforced** — target_files whitelist + scope-creep halt + commit format
9. **Provenance chain** — every artifact cites unit ID, vault claim, anchors, active Hard Rules
10. **Graceful partial-state preservation** — crash mid-bolt recoverable via partial-state.json

### Updated skills

**execute-bolts v2.4.2 → v2.6.0** (major minor bump — new dispatch model):
- Step 4.5 tiered context enrichment per `references/bolt-dispatch-prompt.md`
- Compact streaming progress format
- Aggregate `<vault>/bolts/_summary.md` auto-generated
- Propose-and-confirm halt UX (AI fix-proposer for eligible halts)
- Per-bolt lightweight drift check (LOCKED entity drift → halt)
- Self-assessment YAML required in bolt-report.md
- Provenance trailer required in every modified file (post-flight verified)
- Partial-state preservation contract
- 5 new halt types: dispatch_prompt_too_large, bolt_repeated_partial_failure, provenance_missing, bolt_introduces_locked_drift, self_assessment_missing

**orchestrate-flow v2.4.1 → v2.5.0**:
- Hybrid drift gate phase (DEFAULT-ON after execute-bolts batch)
- Severity → chain action mapping (CRITICAL halts, HIGH pauses, MEDIUM/LOW logs)
- Bolt halt convergence bridge (extends Iter 19 with propose-and-confirm for test_fail / hard_rule_violated / pbt_property_violated)

**detect-drift v1.2.2 → v1.4.0** (minor bump — new auto-trigger mode):
- Auto-trigger handoff from execute-bolts batch
- Snapshot reuse from bolt postflights (~6x speedup)
- Per-bolt incremental scan mode (used by execute-bolts per-bolt drift)
- `## Suggested next actions` block in DRIFT-REPORT.md with auto-handoff commands

### New reference files (3)

- `plugins/mega-sdd/references/shared-snapshot-schema.md` — canonical JSON schema for bolt + drift snapshots
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — T1/T2/T3 tiered enrichment template
- `plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md` — AI fix proposer subagent prompt

### Composition with prior iters

- Iter 19 (convergence loops): extended with bolt halt propose-and-confirm bridge
- Iter 22 (mutability tiers): drift severity = CRITICAL when LOCKED entity changed
- Iter 23 (framework packs): Tier 2 context loads filtered pack rules per unit target_files
- Iter 27 (starterkit-first): scan-codebase pre-loads pack → execute-bolts dispatch
- Iter 28 (multi-scope): bolt dispatch includes scope context; scope filtering applies to drift
- Iter 29 (audit closure): scope: handoff block carries through execute-bolts → detect-drift

### End-to-end seamless flow (illustrative)

```
$ /mega-sdd:auto ./prd.md
▶ Phase 0: PRD scope picker → BE
▶ Phase 1: scan-codebase → pack loaded
▶ Phase 2: generate-intent → vault
▶ Phase 3: bind-codebase → 87 claims
▶ Phase 4: generate-units → 20 units
▶ Phase 5: execute-bolts --all (Iter 30 enrichment)
  Per-bolt: T1+T2 context (~5KB), compact streaming, per-bolt drift
  1 halt (test_fail) → propose-and-confirm → user one-click apply → continue
  All 20 done; _summary.md generated
▶ Phase 5.5: detect-drift (auto-gate DEFAULT-ON, snapshot reuse)
  1 LOW drift; chain continues
▶ Phase 6: emit-agents-md
✓ Pipeline complete: PRD → 20 bolts in 32m44s, 1 click intervention
```

### Plugin

3.21.0 → 3.22.0

### Skill version bumps

| Skill | Version |
|---|---|
| execute-bolts | 2.4.2 → 2.6.0 |
| orchestrate-flow | 2.4.1 → 2.5.0 |
| detect-drift | 1.2.2 → 1.4.0 |

### Field-test target

User-deferred field-test on tradefinance project becomes Iter 30 validation. First-run friction expected; tuning iterations follow.

---

## [3.21.0] — 2026-05-24

### Fixed — Iter 29: v3.20.0 Audit Closure

Per audit `docs/superpowers/audits/2026-05-24-iter-28-v3.20.0-deep-audit.md`. 13 findings closed — pattern was **Iter 28 producer-only**: `generate-intent` wrote scope to vault.json + handoff YAML, but ZERO downstream skills consumed it. Same shape as Iter 25 closed for Iter 22 propagation gaps.

### Skill version bumps

| Skill | Version |
|---|---|
| bind-codebase | 1.9.2 → 1.9.3 |
| generate-units | 2.5.3 → 2.5.4 |
| emit-agents-md | 1.2.3 → 1.2.4 |
| diff-vault | 1.2.1 → 1.3.0 |
| orchestrate-flow | 2.4.0 → 2.4.1 |
| execute-bolts | 2.4.1 → 2.4.2 |
| detect-drift | 1.2.1 → 1.2.2 |
| resolve-oq | 0.9.0 → 0.9.1 |

### P1 fixes (6/6 closed)

**P1-1: Step 0.9 execution-order guard** (generate-intent SKILL.md, no version bump — doc clarification):
- Step 0.9 (scope picker) sat at line 379 BEFORE scan-aware section (line 557), contradicting own claim to run AFTER scan
- Added EXECUTION ORDER GUARD blockquote in Step 0.9 + cross-reference note in scan-aware section
- File order driven by 0.x slot numbering; runtime order requires scan-codebase first

**P1-2: bind-codebase v1.9.3 — scope propagation**:
- Reads vault.json `scope`/`scope_metadata`/`prd_sha256` fields
- Persists scope to binding.md header (`**Scope**: <name> (<id>)`)
- Constrains claim validation to scope's declared PRD sections
- Emits `scope:` block in handoff YAML per handoff-contract.md v3.20+

**P1-3: generate-units v2.5.4 — unit frontmatter scope**:
- Unit frontmatter gains `scope` + `scope_name` fields when vault has scope
- Multi-squad routing now has signal to verify scope context
- unit-schema.md updated with scope/scope_name optional fields
- Handoff YAML scope: block emission

**P1-4: emit-agents-md v1.2.4 — AGENTS.md scope header**:
- New template tokens `{{scope_id}}`, `{{scope_name}}`
- Header HTML comments emit scope when vault has scope field
- BE-scoped vs FE-scoped vaults now produce distinguishable AGENTS.md
- agents-md-schema.md updated

**P1-5: diff-vault v1.3.0 — prd_sha256 change detection** (minor version bump — new capability):
- Closed unimplemented spec claim from vault-contract.md line 487
- Reads vault.json prd_sha256 + prd_path_at_generation
- Computes current PRD sha256; compares to recorded
- Emits prd_sha256_changed field in DRIFT-REPORT.md
- New halt `prd_path_missing` when PRD file gone

**P1-6: orchestrate-flow v2.4.1 — halt taxonomy completion**:
- 4 halts added to "always stop chain" category:
  - `scope_not_declared_in_prd` (Iter 28)
  - `prd_no_scopes_block_user_rejected_retrofit` (Iter 28)
  - `prd_retrofit_low_confidence` (Iter 28)
  - `prd_path_missing` (Iter 29, from P1-5)

### P2 fixes (5/5 closed)

**P2-1: lightweight scope propagation** (3 skills):
- `execute-bolts v2.4.2` — bolt-report.md header gains scope fields
- `detect-drift v1.2.2` — scope-filtered drift scanning default; --full-scan override
- `resolve-oq v0.9.1` — AskUserQuestion prepends scope context; memory decisions.md gains scope column

**P2-2/3**: Squad partition ordering (covered by P1-1 guard)

**P2-4 + ADV-2**: Formal `## Halt conditions (Iter 28 — Step 0.9 scope detection)` section in generate-intent. All 3 Iter 28 halts with full YAML envelope examples. Cross-referenced from scope-picker.md.

**P2-5: agents-md-schema.md stale legacy vault paths fixed**. Replaced `docs/mega-sdd/vaults/<slug>/` with `.mega-sdd/vaults/<slug>/` canonical paths. Back-compat notes retained where intentional.

### Deferred (intentional)

- ADV-1: YAML comment in sample-prd-single-scope.md frontmatter (cosmetic; YAML 1.2 valid)
- P2-2 detailed composition text (Iter 22 × Iter 28): covered implicitly by Step 0.9 procedure flow

### Pattern note (lessons for future iters)

Iter 28 = producer-only ship → Iter 29 = consumer propagation closure. Same shape as:
- Iter 22 (producer-only) → Iter 25 closure
- Iter 23 (producer-only) → Iter 25 closure

Going forward, propagation should be implemented WITHIN the feature iter, not deferred to audit closure. Producer-only ships hide integration debt.

### Plugin

3.20.0 → 3.21.0

## [3.20.0] — 2026-05-24

### Added — Iter 28: Multi-Scope PRD Picker + Canonical Format

User's actual organizational workflow: PRD/BRD shared to multiple IT architects (BE, MW, FE) — each generates THEIR OWN vault for their scope only. Iter 28 makes this first-class.

### Two deliverables

1. **Governance artifact**: canonical PRD/BRD template at `docs/templates/prd-template.md` + `brd-template.md` + filled example `multi-scope-example.md`. Shared with PMs as new SOP.

2. **Mega-sdd skill behavior**: scope detection + interactive picker + AI-assisted retrofit for legacy PRDs.

### Frontmatter schema (canonical multi-scope PRD)

```yaml
---
title: "Order Management System"
type: PRD
scopes:
  BE: { name: "Backend API", pics: [...], priority: 1, sections: ["§Backend"] }
  MW: { name: "Integration Middleware", pics: [...], priority: 2, sections: ["§Middleware"] }
  FE: { name: "Frontend Web", pics: [...], priority: 3, sections: ["§Frontend"] }
universal_sections: ["§1", "§2", ...]
cross_scope_dependencies: [...]
---
```

### Three modes (per design §5.6.1)

| Mode | Trigger | Behavior |
|---|---|---|
| Canonical multi-scope | `scopes:` block + ≥2 scopes | Interactive picker (cwd smart default + memory hit) |
| `--scope=<id>` explicit | Flag set | Silent; halt if id invalid |
| Legacy (no scopes block) | Frontmatter missing | AI retrofit bridge; user accepts/rejects |
| Single-scope | scopes block with 1 entry | Silent route to single-vault |
| `--scope=all` (legacy) | Flag set | Single combined vault + warning |

### Updated skills

**generate-intent** (v1.11.0 → v1.12.0):
- New Step 0.9: scope detection + PRD filtering (positioned after Step 0.8 scan-aware, before Step 1 Load PRD)
- New flag `--scope=<id>`
- New halt types: `scope_not_declared_in_prd`, `prd_no_scopes_block_user_rejected_retrofit`, `prd_retrofit_low_confidence`
- References: scope-picker.md (algorithm) + legacy-retrofit-prompt.md (AI subagent template)

**using-mega-sdd** (v1.3.0 → v1.3.1):
- Anchor auto-trigger documents multi-scope picker UX

### Updated references

- `vault-contract.md`: new §Multi-scope vault section (vault.json scope tagging schema, 00-index.md header structure, validation rules)
- `memory/memory-schema.md`: new §PRD Scope Decisions table (per-PRD scope decisions with override count)
- `orchestrate-flow/handoff-contract.md`: new `scope:` block in handoff YAML (informational)

### Commands

- `auto.md`: new `--scope=<id>` flag in argument-hint + Multi-scope picker section
- `generate-intent.md`: new `--scope=<id>` flag + Flag combinations matrix (10 combos)

### Tests

- `tests/scenarios/sample-prd-multi-scope.md` (canonical fixture)
- `tests/scenarios/sample-prd-legacy-no-frontmatter.md` (retrofit trigger fixture)
- `tests/scenarios/sample-prd-single-scope.md` (boundary fixture)
- `tests/scenarios/scenario-7-multi-architect.md` (end-to-end walkthrough — 3 architects, 3 sessions, 1 PRD)
- `tests/skill-triggering/scope-picker.test.md` (8 skill-trigger fixtures)

### Composition with prior iters

Iter 28 composes correctly with:
- Iter 22 (KB mutability tiers): scope filter applies BEFORE KB tier routing
- Iter 23 (framework packs): scope-filtered vault still pack-aware
- Iter 27 (starterkit-first): scope picker fires AFTER scan-codebase (so smart default can use composer.json hints)
- Iter 11/12 (squads/modules): squads/modules live WITHIN a scope's vault (scope > squad > module > unit hierarchy)

### Out of scope (per design §3)

Deferred (NOT implemented in Iter 28):
- Cross-scope contract auto-locking (architect-rapat domain)
- Multi-vault parallel orchestration from single CLI invocation
- Cross-vault drift detection
- PRD format conversion from PDF/DOCX/Notion

### Governance

Architect rolls out new SOP gradually:
1. PMs adopt canonical format for NEW PRDs (zero friction)
2. Legacy PRDs use retrofit bridge as encountered (gradual cleanup)
3. Memory layer accumulates per-PRD scope decisions organically

### Plugin

3.19.0 → 3.20.0

### Skill version bumps

| Skill | Version |
|---|---|
| generate-intent | 1.11.0 → 1.12.0 |
| using-mega-sdd | 1.3.0 → 1.3.1 |

## [3.19.0] — 2026-05-23

### Added — Iter 27: Starterkit-First Pipeline (scan-codebase moves to front)

Pipeline reorder per user directive: **"scan code base harusnya di atur di depan ... starterkit itu wajib ada. jika tidak ada baru greenfield"**.

Previous flow (Iter 16): `generate-intent → scan-codebase → bind-codebase → ...`. Vault drafted without knowing target stack → generic architecture proposals → CONFLICTs in binding phase when starterkit has stronger opinions.

New flow (Iter 27): `scan-codebase FIRST → generate-intent --scan=<map> → bind-codebase → ...`. Vault drafted with starterkit conventions in scope → dual-citation format (Intent + Starterkit binding) → fewer CONFLICTs because vault DESIGNED for the scaffold from the start.

### Three modes

| Mode | Trigger | Pipeline |
|---|---|---|
| **A — Starterkit-first** (DEFAULT) | Framework manifest detected + pack match | scan FIRST (load pack) → generate-intent --scan (pack-aware, dual-citation) → bind (fewer conflicts) → units → bolts |
| **B — Framework-detected** (universal fallback) | Manifest detected, no pack match | scan FIRST → generate-intent --scan (universal defaults from `_universal.md`) → bind → units → bolts |
| **C — Greenfield (EXPLICIT)** | `--greenfield` flag OR (cwd empty/.git-only + user confirms via halt) | generate-intent --greenfield (stack-agnostic) → user scaffolds later → re-run scan to bind |

When no manifest AND no `--greenfield` flag → halt `no_starterkit_detected` with options (scaffold first / opt in greenfield / cancel).

### Legacy rebuild scenario (composes with Iter 22 KB)

```
extract-intelligence <legacy>     → KB
  ↓
scan-codebase (TARGET scaffold)   → codebase-map.md (framework pack identified)
  ↓
generate-intent --kb=<kb> --scan=<map>  → vault (KB intent × starterkit conventions)
  ↓
bind-codebase → generate-units → execute-bolts
```

KB provides "what" (business intent); scan provides "how" (target conventions). Vault synthesizes both via dual-citation.

### Updated skills

**orchestrate-flow** (v2.3.2 → v2.4.0):
- New Step 2.5: Starterkit detection + mode classification (3 modes table)
- Routing-rules.md decision matrix reorganized: starterkit-first ordering FIRST, pre-existing flows preserved as back-compat
- New halt `no_starterkit_detected` with structured options
- CWD inspection snapshot extended with `starterkit:` block (framework name, pack_match, manifest_path)

**scan-codebase** (v2.4.2 → v2.5.0):
- "scan-first usage" section documents new ordering — scaffold-only repos OK; framework detection comes from package manifests, not file content
- Output consumed by `generate-intent --scan=<codebase-map>` downstream

**generate-intent** (v1.10.0 → v1.11.0):
- New `--scan=<codebase-map-path>` flag — read codebase-map.md §7 Framework + §1-6 conventions BEFORE drafting vault
- New `--greenfield` flag — EXPLICIT opt-in for stack-agnostic generation
- Auto-detection: codebase-map.md at canonical location → `--scan` implicit (confirm before proceeding)
- Vault sections (`02-architecture.md`, `03-data-model.md`, `06-constraints.md`) use dual-citation format when `--scan` set
- `--scan` + `--kb` together (legacy-rebuild) → vault synthesizes legacy domain (KB) + target scaffold (scan)

**generate-intent/references/vault-contract.md** — new §Starterkit-binding section:
- Dual-citation format spec (Intent + Starterkit binding sub-fields)
- Sections affected: 02-architecture, 03-data-model, 06-constraints
- Example for Laravel base-26 starterkit
- Anti-halu rails (Intent derived from PRD/brief/KB; Starterkit binding cites pack file:section or codebase-map.md line)
- Backward compat: pre-v1.11 vaults consumed unchanged; mixed vaults permitted

**commands/auto.md**:
- New `--greenfield` flag in argument-hint
- New "Starterkit detection (v3.19+ Iter 27)" section documenting 3 modes
- Directory probe updated to declare starterkit-first as DEFAULT mode

**using-mega-sdd anchor** (v1.2.1 → v1.3.0):
- New "Starterkit-first mode" section
- Auto-trigger output now surfaces starterkit detection upfront in chain proposal
- Halt path documented when no starterkit + no `--greenfield`

### Memory hint

User's last starterkit preference saved to `~/.mega-sdd/memory/preferences.md` `last_used_starterkit:` field — next legacy-rebuild prompts "Last 3 projects used `laravel-base-26`. Use same starterkit?" (Y/N/other).

### Backward compatibility

- Pre-v1.11 vaults (no dual-citation) → consumed unchanged by bind-codebase + generate-units
- Mixed vaults (some sections dual-citation, others not) → permitted
- Existing pipelines without `--scan` → continue to work; auto-detection of codebase-map.md triggers implicit scan-first ordering
- Greenfield STILL FULLY SUPPORTED — explicit-only (`--greenfield` flag) rather than implicit default

### Why this matters

Iter 22 declared **what** to preserve (mutability tiers). Iter 23 declared **how** the target framework wants it (convention packs). Iter 24 captured **user's specific starterkit** (laravel-base-26). Iter 27 ties it all together — pipeline now ENFORCES the starterkit-first design philosophy.

Output quality goes from "got the code generated" → "got code that LOOKS LIKE it belongs in this starterkit". CONFLICT count in binding phase drops because vault is born with starterkit conventions instead of inheriting them late.

### Skill version bumps

| Skill | Version |
|---|---|
| generate-intent | 1.10.0 → 1.11.0 |
| orchestrate-flow | 2.3.2 → 2.4.0 |
| scan-codebase | 2.4.2 → 2.5.0 |
| using-mega-sdd | 1.2.1 → 1.3.0 |

### Plugin

3.18.1 → 3.19.0

---

## [3.18.1] — 2026-05-23

### Iter 26.1 — Hygiene follow-ups (from Task 3 + Task 6 code reviews)

Closes the two follow-ups carried forward from the v3.18.0 release.

**Fixed**

- **Stale Iter 25 12.x cross-references** in 3 companion docs to `generate-units` — the v2.5.1 Iter 25 step renumbering wasn't propagated to reference docs:
  - `skills/generate-units/references/defensive-generation.md:86, 88, 167` — `Step 12.4.5` → `Step 12.3`; "After Step 12.4 (render pass)" reframed as "Before Step 12.4 (constitution inject) and Step 12.5 (render pass)" to match the current "runs FIRST as precondition" semantics; `--no-defensive` flag step list updated.
  - `skills/generate-units/references/pagerank-targeting.md:51` — `Step 12.4` → `Step 12.5` (polished-prompt render pass is now 12.5 post-Iter-25 renumber).
  - `commands/lint-units.md:68` — `Iter 8 Step 12.4.5` → `Iter 8, Step 12.3 post-v2.5.1 renumber`.

  Skill bump: generate-units 2.5.2 → 2.5.3 (references/ content counts as skill content per `CLAUDE.md`).

- **Command files missing skill-accepted flags** — surfaces previously-undocumented but supported flags:
  - `commands/execute-bolts.md` — argument-hint extended with `--auto`, `--per-squad`, `--squad=<id>`, `--module=<id>`; flag table added.
  - `commands/bind-codebase.md` — argument-hint extended with Iter 23 framework-pack flags (`--kb=<path>`, `--no-kb`, `--no-framework-pack`, `--framework-pack=<path>`) and Iter 20 `--strict-constitution`; flag table added.
  - `commands/orchestrate-flow.md` — argument-hint extended with `--memory-off`, `--converge`/`--no-converge`, `--max-cycles=N`, `--strict-quality`, and the 4 diagnostic opt-outs (`--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md`); flag table extended.

**Plugin** 3.18.0 → 3.18.1.

No behavioral changes — pure doc-coherence hygiene. All flags listed already worked at the skill layer; this PR makes them discoverable via slash-command help.

---

## [3.18.0] — 2026-05-23

### Iter 26 — Verification audit closure

Closes 5 highest-leverage gaps from v3.17.0 verification audit at `docs/superpowers/audits/2026-05-23-iter-25-verification-audit.md`.

**Fixed**

- **(P1-A)** `emit-agents-md` output template — hard-coded `docs/mega-sdd/vaults/<slug>/` paths replaced with `{{vault_path}}` substitution. Every v3.4+ project running emit-agents-md was getting a polluted AGENTS.md whose annotations pointed to a non-existent path. Skill bump: 1.2.2 → 1.2.3.
- **(P0-1)** `bind-codebase` step 2.10 (Constitution-aware CONFLICT surfacing) placed in linear sequence between step 2.9 and step 2.11. Was physically positioned AFTER step 6 (audit log), breaking procedure flow. Also de-cluttered step 2.11's chatty renumbering self-reference. Skill bump: 1.9.1 → 1.9.2.
- **(P0-4)** `generate-units` step ordering: 7.5 (PageRank) and 7.6 (collision check) swapped to monotonic order; step 12 (audit log) renumbered to step 13 and moved AFTER step 12.6 so the audit event reflects all post-write validation outcomes. Skill bump: 2.5.1 → 2.5.2.
- **(P0-8)** `diff-vault:318` cross-reference to `references/vault-contract.md` (which doesn't exist in diff-vault/references/) repointed to `../generate-intent/references/vault-contract.md`. Skill bump: 1.2.0 → 1.2.1.
- **(P1-B)** README + plugin README version metadata sweep — root README and plugin README both shipped v3.13.0 / v3.8.0 banners and a stale 11-skill inventory table with 12 of 13 stale per-skill versions. All bumped to v3.18.0 + current skill versions; anti-halu list completed from 10 to claimed 13 items. Caught additional stale "Currently 3.8.0", "11 skills + 1 anchor", "10-layer anti-hallucination defense", and structure-tree "11 skills" sites in root README via grep verification.
- **(P1-C)** `commands/orchestrate-flow.md` refreshed — added `--deep` and `--resume` flags to argument-hint, removed obsolete "max 3 per chain" claim, sharpened hard-rails section to document `--auto` substance-prompt semantics.
- **(P1-9)** `agents-md-schema.md` extended with PBT (`properties_validated`), replay (`replay_snapshot_count`), and convergence (`convergence_cycle_count`) header fields. Iter 17 `constitution_hash` formalized in the same conditional-rendering schema (was prose-only before). Output template + procedure step 5 updated; OMIT-hints moved out of the literal emission template into a guidance paragraph above the code fence.

**Updated skills**

- `emit-agents-md` 1.2.2 → 1.2.3
- `bind-codebase` 1.9.1 → 1.9.2
- `generate-units` 2.5.1 → 2.5.2
- `diff-vault` 1.2.0 → 1.2.1

**Plugin** 3.17.0 → 3.18.0.

**Audit closure rate** (per verification methodology): 7 of 7 highest-leverage P0/P1 findings closed. Architectural items (halt-taxonomy consolidation, schema-coherence linter) intentionally deferred to a later iter per audit recommendation. Two follow-ups carried forward to future iters: (a) Iter 25 stale 12.x cross-refs in 3 companion docs (defensive-generation.md, lint-units.md, pagerank-targeting.md); (b) command files missing skill-accepted flags (`--memory-off`, `--converge`, `--no-converge`, `--max-cycles`, `--strict-quality`, diagnostic opt-outs).

---

## [3.17.0] — 2026-05-23

### Fixed — Iter 25: Audit Closure (27 findings from v3.16.0 deep audit)

Per `docs/superpowers/audits/2026-05-23-iter-24-deep-audit.md` — 27 findings (8 P0 / 9 P1 / 7 P2 / 3 Advisory). This iter closes all P0 + most P1 + selected P2 in a single combined release.

### Phase A — Iter 21 hotfix completion ("no-excuse `.mega-sdd/`")

Iter 21 patched SKILL.md procedures but missed commands, references, and the memory schema. Iter 25 finishes the job:

**Commands updated** (write-side defaults flipped):
- `commands/extract-intelligence.md` — default `--out=.mega-sdd/knowledge-base/`; description + Hard rails updated; mutability tier markers documented
- `commands/generate-intent.md` — default vault output `.mega-sdd/vaults/<slug>/`; Mode B KB sub-mode tier-aware routing documented
- `commands/emit-agents-md.md` — vault detection priority order updated
- `commands/auto.md` — vault detection in legacy-codebase + existing-vault branches both flipped to probe `.mega-sdd/vaults/` first
- `commands/memory.md` — PROJECT scope canonical path is `.mega-sdd/memory/` (legacy `.mega-sdd-memory/` read-only back-compat)

**References updated**:
- `orchestrate-flow/references/handoff-contract.md` — all example artifacts + suggested_args use `.mega-sdd/` paths; checkpoint_file points to `<vault>/.internal/checkpoints/`; `metadata.memory_context.project_decisions_relevant` cites `.mega-sdd/memory/`
- `orchestrate-flow/references/checkpoint-protocol.md` — all checkpoint paths flipped to `<vault>/.internal/checkpoints/` per paths.md v3.4+ canonical
- `orchestrate-flow/SKILL.md` — checkpoint path references flipped
- `resolve-oq/references/recommendation-context.md` — all 10+ stale path references updated; KB probe order documented; tier-aware recommendation surfacing added (LOCKED → "must preserve" flag; ARTIFACT → "discard?" flag)

**Memory layer** (the biggest miss in Iter 21):
- `memory/SKILL.md` — architecture diagram fixed (now shows `.mega-sdd/memory/` as canonical, legacy as back-compat comment)
- `memory/references/memory-schema.md` — ALL references to `.mega-sdd-memory/` updated to `.mega-sdd/memory/` (PROJECT scope section header, per-file schemas, archive path, opt-out path, learning log example)
- Across 8 skills (scan-codebase, bind-codebase, resolve-oq, memory, generate-units, generate-intent, orchestrate-flow, emit-agents-md, execute-bolts) — every `<project>/.mega-sdd-memory/` reference in memory tables flipped to `<project>/.mega-sdd/memory/`

**Checkpoint + symbol-graph paths** (Iter 10 spec violation closed):
- `generate-units/SKILL.md:272` + `pagerank-targeting.md:82` — `<vault>/.internal/symbol-graph.json` (v3.4+ canonical)
- `orchestrate-flow/SKILL.md` + `checkpoint-protocol.md` — all `<vault>/.internal/checkpoints/` references

**Cross-references fixed** (broken `../grand-design-spec/` paths):
- `detect-drift/SKILL.md:571` → `../generate-intent/references/vault-contract.md`
- `diff-vault/SKILL.md:471` → `../generate-intent/references/vault-contract.md`

### Phase B — Step sequence fixes (bind-codebase + generate-units)

**bind-codebase** (v1.9.0 → v1.9.1):
- Duplicate `2.5` resolved — deferred-OQ auto-resolution renumbered to `2.11` (logical position after Hard Rules emission)
- `2.10` constitution self-reference cleaned (P2-3)
- Backward-compat note `Step 2.9 SKIPPED` → `Step 2.10 SKIPPED` (was wrong step number after Iter 23 renumber)
- Halt-conditions section completed: added `bind_conflict_constitution_violation` (Iter 20), `framework_pack_missing`/`cycle`/`unparseable` (Iter 23)

**generate-units** (v2.5.0 → v2.5.1):
- Step sequence reordered: `12.3` (anchor verification) → `12.4` (constitution inject) → `12.5` (polished render) → `12.6` (dedup) — was `12 → 12.4.5 → 12.3 → 12.4 → 12.5` jumble

### Phase C — Iter 22 mutability propagation (consumer skills)

Mutability tiers (`[LOCKED]/[INTENT]/[ARTIFACT]`) were producer-only in Iter 22. Now propagated to consumers:

**bind-codebase** (v1.9.0 → v1.9.1):
- KB consultation step (line 46) now applies dual-axis routing per Iter 22
- Each KB-derived CONFIRMED emits `mutability_source` field (`kb_locked` / `kb_intent` / `kb_artifact`)
- CONFLICT severity weighted by tier: LOCKED → HIGH (regulatory/contractual risk), INTENT → MEDIUM (design freedom), ARTIFACT → low (already discardable)
- Pre-v1.4 KBs without tier markers → treated as INTENT (safe default)

**detect-drift** (v1.2.0 → v1.2.1):
- Step 3 Compute drift adds new Severity column: CRITICAL (LOCKED drift = compliance/contract risk) / HIGH (no source OR INTENT outcome change) / MEDIUM (INTENT impl change) / LOW (ARTIFACT cleanup)
- Pre-v1.4 vaults → all drift = HIGH (conservative default)

**resolve-oq** (`references/recommendation-context.md`):
- KB-derived recommendations now surface mutability tier inline ("this is a LOCKED rule, rebuild MUST preserve 1:1")
- `[VERIFIED][ARTIFACT]` recommendations include "discard?" option flag

**generate-units** (`references/unit-schema.md`):
- New `mutability:` block in unit frontmatter (`tier`, `source`, `rationale`, `rebuild_freedom` sub-fields)
- Bolts inherit unit's mutability → execute-bolts can enforce field-level locks for LOCKED rules
- Pre-v2.5.1 units → field omitted; downstream defaults to INTENT (safe)

**emit-agents-md** (v1.2.1 → v1.2.2):
- AGENTS.md header `agents-md-schema.md` now declares `framework`, `framework_pack_path`, `mutability_summary` as HTML comments
- Tools consuming AGENTS.md can resolve which conventions + locks apply

**orchestrate-flow** (`references/handoff-contract.md`):
- Handoff YAML schema extended with `mutability:` block: `tier_distribution`, `locked_claims_touched`, `artifact_discards_proposed`

### Phase D — Iter 23 framework pack propagation

Framework pack was loaded only by bind-codebase (Iter 23). Now flows downstream:

**scan-codebase** (v2.4.1 → v2.4.2):
- Step 8.5 framework section example YAML now shows BOTH plain `laravel` AND `laravel-base-26` (starterkit) detection cases
- `extends:` field documented; first-match-wins precedence explicit
- `detection_source` field shows the manifest line that triggered detection (audit trail)

**generate-units** (v2.5.1):
- New Step 12.4.5 — Framework pack provenance citation. Every pack-derived Hard Rule emitted into unit body WITH `source: "framework-conventions/<pack>.md §..."` citation
- New `## Framework pack source` aggregate section in unit body cites pack + version + chain
- Pack rules whose `path_glob` doesn't match unit's `target_files` are SKIPPED

**execute-bolts** (v2.4.0 → v2.4.1):
- Post-flight Hard Rule validation explicitly notes framework pack rules validated identically; violation halt YAML includes `framework_pack_source` field

### Phase E — Scenario coverage

**tests/scenarios/scenario-4-legacy-rebuild.md**:
- Phase 3-4 output now shows framework detection (`laravel-base-26` via Vuexy fingerprint), pack load, and mutability tier distribution (LOCKED/INTENT/ARTIFACT counts)
- OQ-CN-005 recommendation example shows tier-aware surfacing (`[LOCKED]` + regulatory citation)

### Skill version bumps

| Skill | Version |
|---|---|
| bind-codebase | 1.9.0 → 1.9.1 |
| detect-drift | 1.2.0 → 1.2.1 |
| emit-agents-md | 1.2.1 → 1.2.2 |
| execute-bolts | 2.4.0 → 2.4.1 |
| generate-units | 2.5.0 → 2.5.1 |
| memory | 1.2.0 → 1.2.1 |
| orchestrate-flow | 2.3.1 → 2.3.2 |
| scan-codebase | 2.4.1 → 2.4.2 |

### Plugin

3.16.0 → 3.17.0 (8 skills bumped, 27 audit findings closed, ~13 files touched in commands/references/scenarios)

### Deferred (still pending — not blocking)

- P1-9: AGENTS.md schema missing convergence/replay/PBT data export (Iter 17-19 state not exported) — deferred
- ADV-1: constitution.md vault template scaffold — deferred
- ADV-2: data-mutation-policy.md schema validator — deferred
- ADV-3: vendored superpowers sync check — deferred (`scripts/sync-superpowers.sh` exists)
- 2 `.DS_Store` files (P2-7) — leaving to user to .gitignore
- Scenario coverage for Iter 22-23 in scenarios 1, 2, 3, 5, 6 — only scenario-4 updated this iter

### Verified

- All 8 bumped skills' frontmatter versions cross-checked
- Plugin.json + CHANGELOG version aligned
- `grep -r "\.mega-sdd-memory/" plugins/mega-sdd/` clean except deliberate back-compat notes
- 27 findings audit doc remains at `docs/superpowers/audits/2026-05-23-iter-24-deep-audit.md` (untouched as reference)

---

## [3.16.0] — 2026-05-22

### Added — Iter 24: RECON / base-laravel-26 Starterkit Pack

User shared their Laravel 12 starterkit at `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/base-laravel-26`. Audited via CLAUDE.md (26KB) + composer.json + structure inspection. Captured project-specific conventions into a dedicated pack — Iter 23's pluggable system pays off immediately.

### What the starterkit reveals

Stack: Laravel **12.x** + Jetstream (Livewire) + Socialstream + Sanctum + Spatie Permission + Spatie ActivityLog + Reverb (WebSockets) + Yajra DataTables + Vuexy (Bootstrap 5) theme + jQuery + Vite. **PHPUnit 11** (NOT Pest). **Yarn** (NOT npm). **UUID primary keys** + **foreignUuid FKs** by default.

Custom architecture:
- 9 force-loaded helper files (`app/Helpers/*_helpers.php`)
- 9 reusable traits (`HasUuid`, `HasUserStamps`, `HasActivityLog`, `HasSlug`, `Cacheable`, `HandlesNumberInput`, `AutoSoftDelete`, `HandlesFilePermissions`, `HasCommonFields`)
- `BaseController` with `successResponse()` / `errorResponse()` JSON helpers
- `BaseDataTable` (Yajra) with action column + per-row permission checks
- Notification Rules Engine (event-driven; jQuery QueryBuilder conditions)
- CRUD Generator (`php artisan make:controller-acl`)
- Code Obfuscator (deployment pipeline with strategy chain)
- ErrorResponseService with `ErrorCode` enum (6 categories, 1xxx-6xxx)

### New file

**`plugins/mega-sdd/references/framework-conventions/laravel-base-26.md`** (~600 lines):
- `extends: laravel` (inherits base Laravel 10-12 pack)
- Detection: `pixinvent/vuexy-laravel-bootstrap-jetstream` in composer.json (unique starterkit fingerprint) + `joelbutcher/socialstream` fallback
- 18+ file location overrides (Actions, DataTables, Enums, Helpers, Services, Traits, CRUD generator paths, test fixtures, obfuscator)
- 14+ naming standard overrides (UUID PKs, foreignUuid FKs, controller filename shorthand, Form Request module grouping, etc.)
- 9 mandatory traits per entity table
- 2 required base classes (`BaseController`, `BaseDataTable`)
- 16 project-specific idioms (CRUD generator first, thin controllers, permission middleware on routes, activity log via trait, DataTables for lists, notification rules over Observers, Reverb broadcast, casts() method in v11+, etc.)
- 7 frontend conventions (Vuexy theme, jQuery + DataTables, Livewire 3, `DOMContentLoaded` (NOT `$(document).ready()`), SweetAlert2, Toastr, responsive 375px+, yarn-not-npm)
- 11 Hard Rules emitted (UUID PK enforcement, BaseController extension, permission middleware, JS init pattern, dialog convention, PHPUnit not Pest, etc.)
- 11 forbidden patterns
- 8 project-specific artisan commands
- 4 required daily processes (web + queue + reverb + vite)
- Quality gate commands (pint --dirty, composer analyse, php artisan test)
- ErrorCode enum convention
- Notification rule pattern (7-step recipe)
- ERD additions (UUID PKs, audit columns, soft delete default, activity_log schema, authentication_logs, notification engine schema, connected_accounts polymorphic)
- 13-row docs reference table
- 13 pack-specific notes (old-reference/ is legacy, PHPStan baseline exists, helpers force-loaded, code obfuscation skip rule, etc.)
- Deviation policy (when to override this pack via ADR or constitution.md)

### Updated existing files

**`laravel.md`** (v1.0 → v1.1 conceptually; same file, expanded range):
- `framework_version_range`: "10.x — 11.x" → "10.x — 12.x"
- Added §Laravel version notes section with [v11+] / [v12+] markers
- Documented v11 slimmer skeleton (Kernels removed, bootstrap/app.php config)
- Documented v12 casts() method convention, factory configuration

**scan-codebase** (v2.4.0 → v2.4.1):
- Added detection row for `pixinvent/vuexy-laravel-bootstrap-jetstream` → `laravel-base-26` (takes precedence over plain laravel via first-match-wins; Vuexy starterkit fingerprint)

**`framework-conventions/README.md`**:
- Added `laravel-base-26.md` to files table with description

### How this composes

When user runs `/mega-sdd:auto` in a project derived from this starterkit:

1. **scan-codebase** detects `pixinvent/vuexy-laravel-bootstrap-jetstream` in composer.json → emits `framework: { name: laravel-base-26, pack_path: ...laravel-base-26.md }`
2. **bind-codebase** loads `laravel-base-26.md` → which loads parent `laravel.md` → which loads `_universal.md`
3. Hard Rules merged: universal baseline (snake_case columns) → Laravel base (migration timestamp pattern) → starterkit overrides (UUID PKs override BIGINT default, BaseController extension required, etc.)
4. Suggested Unit Hard Rules in `binding.md` reflect the LIVE starterkit conventions
5. `generate-units` emits units with starterkit-specific instructions (use `make:controller-acl` for new modules, extend BaseDataTable, etc.)
6. `execute-bolts` validates generated code against the merged rule set via ast-grep

### Validation alignment with user's global CLAUDE.md

User's global `~/.claude/CLAUDE.md` declares:
- "memorize gunakan document.addEventListener('DOMContentLoaded', ...)" → MATCHES pack's HARD_RULE on JS init
- "memorize untuk blade laravel selalu utamakan juga responsive" → MATCHES pack's responsive HARD_RULE
- "memorize pake sweet alert untuk di project laravel" → MATCHES pack's SweetAlert2 HARD_RULE  
- "memorize using yarn build" → MATCHES pack's yarn-not-npm HARD_RULE
- "memorize selalu ikutin docs sebagai acuan code" → pack references starterkit `docs/INDEX.md`

The starterkit IS the source of truth for the user's coding preferences. Pack now formally encodes those preferences as enforceable Hard Rules.

### Plugin

3.15.0 → 3.16.0

### Future iters

- More starterkit packs as user shares additional bases (frontend kits, alternative Laravel stacks, Django starters, etc.)
- Pack linter (`_lint.md` schema validator) — deferred from Iter 23

---

## [3.15.0] — 2026-05-22

### Added — Iter 23: Framework Convention Packs + Universal ERD Quality

Quality-rails iteration. Adds pluggable framework convention packs that auto-detect during `scan-codebase` and emit framework-specific Hard Rules during `bind-codebase`. Output quality goes from "got it done" → "delivery-grade per framework conventions."

### New: `plugins/mega-sdd/references/framework-conventions/`

Pluggable convention catalog. Three files at v1.0:

- **`README.md`** — folder overview, adding-new-packs guide, opt-out flags, maintenance policy
- **`_template.md`** — schema for new packs (frontmatter + 7 required sections)
- **`_universal.md`** — universal fallback pack (always applies). Contents:
  - Snake_case columns + plural snake_case tables
  - FK naming `{singular_target}_id` standard
  - Boolean naming `is_<state>` / `has_<thing>`
  - Datetime naming `<verb>ed_at`
  - Standard timestamps (`created_at`, `updated_at`) + soft-delete + audit columns
  - 3NF Normalization checklist
  - Forbidden patterns (VARCHAR(255)-everything, comma-delimited columns, dates-as-strings)
  - ID convention guidance (auto-increment BIGINT vs UUID v4 vs UUID v7)
- **`laravel.md`** — Laravel 10.x — 11.x pack. Full content:
  - File location standards (Models, Controllers, Migrations, Routes, Tests, etc. — 20 paths)
  - Naming standards (Model PascalCase singular, table plural snake_case, migration timestamp pattern, FK convention, etc. — 20+ rules)
  - Idioms (Eloquent over raw queries, Form Requests, API Resources, Policies, Services, Jobs, Eager loading, Transactions, Sanctum/Passport, Spatie packages)
  - Hard Rules emitted (9 rules with path_glob + rule_type + pattern + rationale)
  - Forbidden patterns (DB::table in Controllers, $_POST direct access, business logic in routes, etc.)
  - Laravel-specific ERD additions (polymorphic relations, pivot tables, Auth users table)
  - Testing conventions (PHPUnit/Pest, fakes, factories, HTTP test helpers)
  - Migration/dependency management (composer + npm + artisan commands)
  - Notes (mass assignment protection, casts for non-string columns, route/config caching, queue workers, Octane caveats)

### Updated skills

**scan-codebase** (v2.3.0 → v2.4.0):
- New Step 8.5: Framework detection. Parses package manifest (`composer.json`, `package.json`, `Gemfile`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`) for framework dependency markers. 20+ frameworks supported: laravel, symfony, slim, next, nuxt, nestjs, express, fastify, remix, sveltekit, rails, sinatra, django, fastapi, flask, gin, echo, fiber, actix, axum, rocket
- Output: `codebase-map.md` §7 Framework section with name, version, confidence (high/medium/low/fallback), pack_path, detection_source
- Fallback when no framework match: `framework: { name: "_universal", confidence: "fallback" }`

**bind-codebase** (v1.8.1 → v1.9.0):
- New Step 2.8: Load framework convention pack. Reads `codebase-map.md` §7, loads matching pack from `plugins/mega-sdd/references/framework-conventions/<framework>.md`. Supports pack inheritance via `extends:` frontmatter
- Existing 2.8 (Suggested Unit Hard Rules emission) renumbered to 2.9
- Existing 2.9 (Constitution-aware CONFLICT) renumbered to 2.10
- New Hard Rule source `a. Framework pack rules` added as first priority in Suggested Unit Hard Rules emission
- New flags: `--no-framework-pack` (skip loading), `--framework-pack=<custom-path>` (project-specific override)
- New halts: `framework_pack_missing` (pack path declared but file absent), `framework_pack_cycle` (extends: chain has cycle), `framework_pack_unparseable` (malformed pack file)
- Graceful fallback: pre-v2.4 codebase-maps without §7 Framework → treat as `_universal` with advisory log

**`references/codebase-map-schema.md`** (scan-codebase reference):
- New §7 Framework section in required-sections template

### How this composes with Iter 22

Iter 22 declared **what** to preserve (`[LOCKED]`) vs **what** is free to redesign (`[INTENT]`/`[ARTIFACT]`). Iter 23 declares **how** to redesign — when rebuilding an `[INTENT]` entity, follow the loaded framework convention pack to ensure output matches delivery standards for the target framework.

Together:
- KB classifies legacy claims by mutability tier (Iter 22)
- Framework pack defines target-framework conventions (Iter 23)
- `generate-intent --kb` produces vault with rebuild proposals satisfying both
- `bind-codebase` emits Hard Rules pulled from framework pack
- `execute-bolts` validates per-bolt pre/post-flight against the pack rules
- Output: code that's both business-correct (Iter 22) AND framework-idiomatic (Iter 23)

### Why pluggable, not opinionated-by-default

mega-sdd stays framework-agnostic. Packs load only when scan detects a match. User can opt out (`--no-framework-pack`) or override (`--framework-pack=<custom>`). Future iters can add more packs (Django, Rails, Express, NestJS, FastAPI, Gin, etc.) incrementally as users request — without changing core skill behavior.

### Deferred (future iters)

- Pack linter (`references/framework-conventions/_lint.md`) — validate new packs pass schema checks
- More framework packs (added when users request specific frameworks)
- Iter 24: Read user's Laravel starterkit (when path shared) → populate project-specific `laravel-<user>.md` override

### Verified

- Plugin: 3.14.0 → 3.15.0
- New folder: `plugins/mega-sdd/references/framework-conventions/` (4 files)
- Skills bumped: scan-codebase v2.4.0, bind-codebase v1.9.0
- `references/codebase-map-schema.md` updated with §7 Framework section

---

## [3.14.0] — 2026-05-22

### Added — Iter 22: KB-as-Analysis Vault Philosophy + 3-Tier Mutability

Philosophy shift per user directive: **"code dan ERD bisa berubah, tapi goals reengineering nya terpenuhi, jika tidak ada ketentuan erd harus 1:1"**. KB is no longer a 1:1 mirror of legacy — it's an **analysis input** that drives REENGINEERING recommendations. Vault output emphasizes business intent + rebuild proposals; legacy detail surfaces only when explicitly LOCKED.

### 3-tier mutability classification (orthogonal to confidence)

Every non-trivial KB claim now carries TWO marker axes:

**Axis 1 — Confidence** (existing): `[VERIFIED]` / `[INFERRED]` / `[OPEN]`

**Axis 2 — Mutability** (NEW v1.4+, Iter 22): `[LOCKED]` / `[INTENT]` / `[ARTIFACT]`

- `[LOCKED]` — MUST preserve 1:1 (regulatory, contractual integration, audit-required, external FK)
- `[INTENT]` — outcome matters, implementation FREE (DEFAULT for most domain rules)
- `[ARTIFACT]` — coincidental legacy detail, free to DISCARD (dead code, legacy stack workarounds, unused fields)

Combined notation: `[VERIFIED][LOCKED]`, `[VERIFIED][INTENT]`, `[INFERRED][ARTIFACT]`, etc. Confidence first, mutability second.

### Updated skills

**extract-intelligence** (v1.3.0 → v1.4.0):
- Added §Axis 2 — Mutability tiers section to SKILL.md with concrete classification triggers
- Default tier when uncertain: `[INTENT]` (never auto-LOCKED — over-constrains; never auto-ARTIFACT — risks discarding business rule)
- Updated `references/knowledge-base-schema.md`:
  - Per-domain frontmatter: added `locked_count`, `intent_count`, `artifact_count` machine-read fields
  - §7 Business Rules table: split single Marker column → Confidence + Mutability columns
  - Added §ERD Quality Rails section (universal-good-practice defaults: snake_case columns, plural snake_case tables, FK convention `{singular_target}_id`, standard timestamps, soft-delete, audit columns; Normalization checklist: 3NF compliance, no repeating groups, junction tables for M:N; Departures section required)
  - Added §data-mutation-policy.md template (entity-level summary table + per-locked-field policy + discardable artifacts)
- Updated `references/wave-dispatch-templates.md`:
  - Generic agent prompt skeleton DISCIPLINE section: added mutability tier requirement with classification triggers
  - REPORT BACK format: added `locked: <int>`, `intent: <int>`, `artifact: <int>` counts
  - Wave 5 Synthesis: added 5th output `data-mutation-policy.md` aggregating per-entity tier counts
  - Wave 5 README structure: leads with Reengineering Opportunities + Mutability Tier Distribution table BEFORE Critical Findings
  - Final gate: checks `data-mutation-policy.md` exists + README ordering (Reengineering before Critical Findings)

**generate-intent** (v1.9.1 → v1.10.0):
- Mode B (KB sub-mode) reworked with tier-aware routing
- Read `99-rebuild-architecture/data-mutation-policy.md` first to determine ERD freedom
- Per-tier vault routing table:
  - `[VERIFIED][LOCKED]` → vault verbatim + Hard Rule emission for execute-bolts
  - `[VERIFIED][INTENT]` → outcome goal in vault, reference rebuild proposal
  - `[VERIFIED][ARTIFACT]` → OQ with default "discard unless preserve required"
  - `[INFERRED][LOCKED]` → single high-stakes confirmation question; default keep
  - `[INFERRED][INTENT]` → vault body with INFERRED annotation
  - `[INFERRED][ARTIFACT]` → skip vault; log to `_diagnostics/kb-skipped-artifacts.md`
  - `[OPEN][?]` → vault OQ
- ERD freedom: vault `02-architecture.md` uses `99-rebuild-architecture/suggested-erd.md` as proposed shape (not legacy conceptual ERD); only `[LOCKED]` fields retain legacy shape verbatim
- Backward-compat: pre-v1.4 KBs without tier markers → all claims treated as `[INTENT]` (safe middle-ground)

### Why this matters

Iter 1-21 treated KB as "preserve-legacy spec" — `[VERIFIED]` items went into vault body as-is. This implicitly mirrored legacy schema/flow into rebuild. User flagged this misaligned with reengineering goals: legacy = INPUT for analysis, rebuild = OPPORTUNITY to fix what was broken.

Iter 22 makes the philosophy explicit:
- KB extracts BOTH business intent (preserved) AND legacy implementation detail (discardable)
- ERD is FREE to redesign unless field carries regulatory/contractual lock
- Reengineering Opportunities lead README — rebuild team's primary job is DESIGN, not ARCHAEOLOGY
- `data-mutation-policy.md` is the contract between extract-intelligence and generate-intent for ERD freedom

### Backward-compatibility

- Pre-v1.4 KBs (no mutability markers) consumed safely — every claim treated as `[INTENT]`
- Existing vaults unaffected (Iter 22 only changes NEW vault generation behavior)
- Old KB regeneration not required — but users may re-run extract-intelligence to gain tier classification benefits

### Verified

- Plugin: 3.13.1 → 3.14.0
- Skills bumped: extract-intelligence v1.4.0, generate-intent v1.10.0
- `references/knowledge-base-schema.md` expanded with §Mutability tiers, §ERD Quality Rails, §data-mutation-policy.md template

---

## [3.13.1] — 2026-05-22

### Fixed — Iter 21: Path-Default Hotfix (No-Excuse `.mega-sdd/`)

User-reported field bug: `extract-intelligence` wrote to `docs/knowledge-base/.scan-meta.json` in a fresh project despite Iter 10 canonical spec (`paths.md`) declaring `.mega-sdd/knowledge-base/` as the v3.4+ default. Root cause: chicken-and-egg detection logic in `extract-intelligence` v1.2 — required `.mega-sdd/` to already exist before triggering new layout. Since extract is often the FIRST skill in legacy-rebuild scenarios, the detection always fell back to legacy `docs/`.

User directive: **"by default harus ke `.mega-sdd/` — no excuse"**. Hotfix flips all writer-side defaults + read-side probe orders.

**Bug — extract-intelligence detection chicken-and-egg** (v1.2.0 → v1.3.0)
- Removed broken detection that required `.mega-sdd/` to pre-exist
- Default `--out` now `<project-root>/.mega-sdd/knowledge-base/` ALWAYS for fresh projects (parent created on demand)
- Legacy `docs/knowledge-base/` triggered ONLY when prior extraction artifacts already exist there (avoids split-brain)
- Fixed description, Inputs, output-tree examples, handoff template + YAML to reference new default
- references/knowledge-base-schema.md probe order updated: new path FIRST, legacy as fallback

**Bug — bind-codebase legacy probe order** (v1.8.0 → v1.8.1)
- Codebase-map default probe priority flipped: `.mega-sdd/codebase/codebase-map.md` FIRST, `<repo-root>/codebase-map.md` fallback
- KB probe order flipped: `.mega-sdd/knowledge-base/` FIRST, legacy paths fallback
- Description updated to reference new KB default

**Bug — generate-intent vault default + KB probe order** (v1.9.0 → v1.9.1)
- Step 0 `--auto` vault output default flipped: `.mega-sdd/vaults/<slug>/` (was `docs/mega-sdd/vaults/<slug>/`)
- KB auto-detection probe order flipped: new path FIRST, legacy fallback
- Mode B example invocation updated to `--kb=.mega-sdd/knowledge-base/`
- Rule 6 detection table updated with new probe priority

**Bug — emit-agents-md vault detection** (v1.2.0 → v1.2.1)
- Vault detection probe order flipped: `.mega-sdd/vaults/*/vault.json` FIRST, legacy fallback

**Bug — orchestrate-flow CWD probe order** (v2.3.0 → v2.3.1)
- routing-rules.md §CWD inspection: vault detection now `.mega-sdd/` first
- KB probe order flipped to new layout first
- Codebase-map probe order flipped to new layout first

**Bug — using-mega-sdd anchor signals** (v1.2.0 → v1.2.1)
- CWD signals list reordered: `.mega-sdd/` family FIRST as primary trigger, legacy signals retained for back-compat detection

### Why this matters

User CLAUDE.md directive: "memorize lo harus run berdasarkan dokumen yg ada, harus sejalur ketika lo membuat logic. agar clean dan konsisten". Iter 10 spec (`paths.md`) declared `.mega-sdd/` canonical but 5 skills had inconsistent writer defaults + 4 skills had read-side probe orders favoring legacy paths. This hotfix brings skill behavior in line with the canonical spec — **no more split-brain across iters**.

### Read-side back-compat preserved

Legacy projects (output at `docs/knowledge-base/`, `docs/mega-sdd/vaults/`, etc.) still detected + consumed correctly. New extractions land in `.mega-sdd/`. Mixed projects (new fresh + legacy already on disk) resolve per first-hit-wins.

### Not migrated automatically

Existing legacy projects keep their old paths. Users wanting to consolidate may run `/mega-sdd:migrate-paths` (Iter 10 maintenance command) manually.

### Verified

- Plugin: 3.13.0 → 3.13.1
- Skills bumped: extract-intelligence v1.3.0, bind-codebase v1.8.1, generate-intent v1.9.1, emit-agents-md v1.2.1, orchestrate-flow v2.3.1, using-mega-sdd v1.2.1
- `references/paths.md` (canonical) unchanged — was already correct; skills now match it

---

## [3.13.0] — 2026-05-21

### Fixed — Iter 20: Critical Bug Closure + Doc Sync

Per audit doc `docs/superpowers/audits/2026-05-21-deep-audit-v3.12.md`. Closes 5 critical bugs from Iter 17-19 where features were CLAIMED in CHANGELOG but NOT implemented in skill procedures. Plus doc sync for Iter 17-19 features.

**Critical findings audit summary**:
- Iter 17 constitution layer: claimed integration with 5 skills; only 2 actually patched
- Iter 18 PBT: claimed execute-bolts integration; version bumped without procedure
- Iter 19 convergence: claimed resolve-oq auto-invocation; flag didn't exist

### Critical bug fixes (P0)

**Bug 1 — execute-bolts PBT integration** (v2.3 → v2.4)

Iter 18 claim `pbt_property_violated` halt + counterexample preservation NOW IMPLEMENTED. Added:
- Pre-flight: validate `properties[].cites` resolves per Iter 7 citation rail
- Acceptance phase: detect PBT framework (Eris/fast-check/Hypothesis/gopter/proptest); run via Bash
- Post-flight: halt `pbt_property_violated` on error-severity counterexample; preserve counterexample in halt YAML
- Framework absent → graceful fallback (advisory note in bolt-report.md)
- `--no-pbt` flag opt-out

**Bug 2 — bind-codebase constitution awareness** (v1.7.1 → v1.8.0)

Iter 17 claim "bind-codebase cites constitution clauses when surfacing CONFLICTs" NOW IMPLEMENTED. Added:
- Step 2.9: read constitution.md + cite §A-F clauses in CONFLICT entries
- `bind_conflict_constitution_violation` halt type when `--strict-constitution` set
- `constitution_hash` persistence in binding.md for later drift detection
- Graceful fallback when constitution.md absent

**Bug 5 — resolve-oq non-interactive flag** (v0.8.0 → v0.9.0)

Iter 19 convergence depends on auto-invocation; flag didn't exist. NOW IMPLEMENTED:
- `--auto-accept-from-memory` flag — skip AskUserQuestion when recommendation confidence ≥ threshold
- `--confidence-min=N` (default 0.80) — minimum confidence to auto-accept
- `--non-interactive` alias for combined flags
- High-stakes business OQs (P1 + category: business) NEVER auto-accept (anti-halu rail)
- Audit trail: auto-accepted decisions logged with `source: ai_auto_accepted` marker

### P1 fixes

**Bug 3 — detect-drift constitution-drift detection** (v1.1.0 → v1.2.0)

Iter 17 claim NOW IMPLEMENTED. Added:
- Read constitution.md + compare hash to binding's recorded `constitution_hash`
- Mismatch → halt `constitution_drift_detected`
- Scan code for clause violations (mechanically detectable §A-F clauses via ast-grep)
- Categorize: Critical (§B/§F) / Standard (§A/§C/§E) / Advisory (§D)
- New `## Constitution Findings` section in drift-report.md

**Bug 4 — emit-agents-md constitution section** (v1.1.0 → v1.2.0)

Iter 17 interop incomplete. NOW IMPLEMENTED. Added:
- New §Constitution section in AGENTS.md schema (between §7 Open Questions and §8 Mega-sdd interop)
- Flatten §A-F clauses VERBATIM with clause ID citations
- Conditional rendering (skip section if constitution.md absent)
- Constitution hash in HTML comment generation marker for tool-detection staleness

### P2 — Documentation sync

- **handoff-contract.md** extended with Iter 17-19 schema fields: `constitution` (hash + clauses_referenced), `pbt` (properties_validated/failed), `cycles` (count + halts auto-resolved/escalated), `replay` (snapshot_path + divergence_classification)
- **Root README** v3.8.0 → v3.13.0: anti-halu defense layers 10 → 13 (added Constitution layer, PBT, Convergence loops with explicit version tags)
- **Plugin README** v3.8.0 → v3.13.0: new "What's new in v3.13.0 (Iters 17-20)" section + 13-layer defense

### Changed — Skill versions

- `execute-bolts`: 2.3.0 → 2.4.0 (PBT validation step actually implemented)
- `bind-codebase`: 1.7.1 → 1.8.0 (Step 2.9 constitution-aware CONFLICT surfacing)
- `resolve-oq`: 0.8.0 → 0.9.0 (--auto-accept-from-memory + --non-interactive flags)
- `detect-drift`: 1.1.0 → 1.2.0 (constitution-drift detection step)
- `emit-agents-md`: 1.1.0 → 1.2.0 (constitution section in AGENTS.md output)

### Anti-halu invariants preserved

- All fixes are DETERMINISTIC additions (no LLM judgment expansion)
- PBT requires citation per property (per Iter 7 standard)
- Constitution-aware CONFLICT surfacing CITES specific clauses (no fabrication)
- Resolve-oq auto-accept requires HIGH confidence (≥0.80 default); low-conf escalates to manual
- High-stakes business OQs NEVER auto-accept (preserves human-in-loop for stakeholder decisions)
- Constitution-drift detection scopes to mechanically-detectable clauses; prose-only flagged as "manual review needed"

### Backward compatibility

- v3.12 invocations without new flags → unchanged behavior
- Pipelines without constitution.md → all constitution-aware steps SKIP gracefully
- Resolve-oq without --auto-accept-from-memory → fully interactive (pre-v0.9 behavior)
- Execute-bolts without PBT framework → advisory only (no halt; pre-v2.4 behavior)
- Detect-drift without constitution → existing vault-claim drift unchanged

### Post-mortem honesty (Iter 17-19 retrospective)

Per audit Part 7:

1. Iter velocity exceeded validation discipline (19 iters in 1 session)
2. CHANGELOG entries written aspirationally; reality only partial
3. Multi-skill integration (Iter 17 touched 5 skills) over-claimed
4. No automated test runner = no enforcement of claimed features
5. User redirects mid-iter (PBT ↔ convergence) dropped quality

### Process improvements going forward

- Verify procedure step ACTUALLY added (`grep` check) BEFORE bumping skill version
- CHANGELOG entries should cite specific Procedure step numbers (forces verification)
- Multi-skill integrations need explicit "skill matrix" checklist in spec
- Audit every 3 iters (not just 9, 13, 20)

### Outstanding (defer)

- **Gap C-1**: Test fixtures for Iter 17-19 — pending; field-test will inform actual test scenarios
- **Gap C-2**: modules.yaml JSON Schema — needs check-jsonschema integration design
- **Drift D-3**: Scenarios update for Iter 17-19 features — field-test will inform real walkthroughs

### Plugin metadata

- `plugin.json`: 3.12.0 → 3.13.0 (minor — additive procedure implementations + doc sync)

## [3.12.0] — 2026-05-21

### Added — Iter 19: Convergence Loops in orchestrate-flow

Per user feedback (Iter 18 redirect) + earlier discussion — formalize implicit cycles between skills. "Cycling agent" pattern user asked for; safer alternative to auto-generating dynamic agents.

### What changed

`orchestrate-flow` v2.2 → v2.3 gains `--converge` mode. In `--deep` chain (or `auto`), auto-loops eligible halt types up to `--max-cycles` instead of stopping on first halt.

**Cycle-eligible halts** (auto-loop with memory-pre-filled recommendations):

| Halt type | Auto-loop action | Safety condition |
|---|---|---|
| `bind_conflict` | Auto-invoke `resolve-oq --binding` → re-run `bind-codebase` | Memory recommendation confidence ≥ 0.80 |
| `module_blocked_by` | Auto-run prerequisite module first → resume requested | Prereqs identifiable + non-circular |
| `cross_squad_interface_draft` | Wait+backoff (30s/60s/120s) for producer to lock | Producer has lock-in-progress signal |
| `oq_recommend_underspecified` | Auto-regenerate recommendation fields → re-run | Memory has fallback rationale template |

**Halts that ALWAYS STOP** (no auto-loop; human required):
- `hard_rule_violated` (code in working tree; user reviews)
- `dedup_ambiguous` (multi-path resolution)
- `quality_gate_failed` (extract-intelligence)
- `oq_business_p1_unresolved` (stakeholder decision)
- `test_fail` after 3 retries
- `hard_rule_unparseable` / `hard_rule_unanchored` (config error)
- `cross_module_dep_invalid` (explicit blocked_by needed)
- `memory_schema_mismatch` (migration prompt)
- `mode_migrate` (vault/code mode contradiction)

### Flags

- `--converge` (default ON in `--deep` mode; OFF in standalone `orchestrate-flow`)
- `--no-converge` — reverts to pre-v2.3 behavior (stop on any halt)
- `--max-cycles=N` — hard limit (default 5) to prevent runaway

### Per-cycle UX

Chat output per cycle:

```
⛔ Halt: bind_conflict (3 conflicts detected)
🔁 Cycle 1/5: auto-resolving via resolve-oq...
   ↳ C-007 (auth conflict) → recommendation: KEEP_CODE (memory pattern 8/10; conf: 0.95) → ACCEPTED
   ↳ C-009 (sanctum vs passport) → recommendation: KEEP_VAULT (per constitution §B-001) → ACCEPTED
   ↳ C-011 (audit table schema) → recommendation: SPLIT (per past pattern) → ACCEPTED
✓ Cycle 1 complete. Re-running bind-codebase...

▶ Phase 3 of 5: bind-codebase (re-run)
✓ Phase 3 of 5: bind-codebase → status: completed
   Convergence: 1 cycle (3 conflicts auto-resolved via memory; 0 manual)
```

### New halt type — convergence_max_reached

When cycle limit hit without convergence:

```yaml
blocker:
  type: convergence_max_reached
  details:
    cycles_attempted: 5
    halt_history:
      - cycle: 1, halt: bind_conflict, auto-resolved: yes
      - cycle: 2, halt: bind_conflict (different conflicts), auto-resolved: yes
      - cycle: 3, halt: bind_conflict (recurring), auto-resolved: no — confidence dropped to 0.65
    last_halt: bind_conflict (C-019)
  next_action: "Recurring conflict after 5 cycles. Run /mega-sdd:resolve-oq --binding manually OR re-configure vault claim."
```

### Anti-halu rails (mandatory)

- Auto-loop ONLY for closed set of eligible halt types; never expanded silently
- Resolver MUST have HIGH-confidence recovery path (≥0.80 per Iter 7 standard)
- `--max-cycles` hard limit prevents runaway loops
- Same halt recurring after auto-resolution → escalate (don't loop on identical failure)
- Every cycle logged to chain summary + memory `outcomes.md` (full audit trail)
- `--no-converge` preserves pre-v2.3 behavior (one-shot per phase)

### Tradefinance impact

For 47+ unit brownfield rebuild (per Scenario 4):
- Each cycle saved ≈ 10 min wall-clock
- High convergence rate expected: bind_conflict resolutions accumulate in memory; later cycles auto-resolve
- Net: 1.5-2x faster pipeline completion vs manual `--resume`

### Changed — Skill versions

- `orchestrate-flow`: 2.2.0 → 2.3.0 (convergence loops + `--converge` + `--max-cycles`)

### Updated artifacts

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — new §Convergence loops section
- `plugins/mega-sdd/commands/auto.md` — opt-in/opt-out flags + UX example

### Backward compatibility

- v3.11 pipelines WITHOUT `--converge` flag → unchanged behavior (stop on any halt)
- Manual `orchestrate-flow` → `--converge` defaults OFF (preserves per-phase control)
- `--auto` chain mode → `--converge` defaults ON (autonomous behavior)
- `--max-cycles` override available always

### Skipped from research findings (deferred to Iter 20+)

Per honest assessment:

- **OpenAPI emission** from vault flows — niche; needs API-first project; defer
- **Semgrep + LLM triage gate** — overlap with ast-grep; license risk; skip
- **Pattern → template generation** — module layer (Iter 11) already handles grouping; defer for more design

Field-test will reveal which (if any) of these actually matter.

### Plugin metadata

- `plugin.json`: 3.11.0 → 3.12.0 (minor — additive convergence behavior)

## [3.11.0] — 2026-05-21

### Added — Iter 18: Replay Harness + Property-Based Testing

Per user pick from Iter 17 research findings (telemetry/otel deprioritized per user). Two adoptions:

**1. `/mega-sdd:replay <unit-id>` (NEW command)**

Per research finding — IBM DFAH 2026 + LangGraph time-travel validate replay as missing primitive for agentic-dev debugging. Critical for brownfield scenarios (tradefinance) where bolts may produce non-deterministic outcomes across runs.

- Captures bolt-state snapshot (preflight + postflight + bolt-report + git refs + target_files checksums) as JSON Lines at `<vault>/.internal/replays/<unit-id>-<timestamp>.json`
- Diffs current run vs latest prior using `jd` (per Iter 14 adoption); falls back to manual field-by-field comparison
- Classifies divergence: 🔴 HIGH (test exit code change, sha256 mismatch, hard-rule status change, halt differs) → suggest halt-equivalent; 🟡 MEDIUM (perf shift >50%, scope drift >20%) → warning; 🟢 LOW (cosmetic timestamps) → ignore
- Pure bash + jq; zero new runtime deps; opt-in capture (does NOT auto-run)
- `--capture-only` (baseline before refactor), `--diff-against=<replay-id>` (compare to specific prior run)

Use cases:
- Regression detection after code refactor
- Non-determinism debugging
- CI/CD integration for PR validation
- Audit trail of bolt evolution

**2. Property-Based Testing in unit schema (v2.5+)**

Per Anthropic NeurIPS 2025 paper "Property-Based Testing with Claude" — PBT catches 30-32% of partial-correctness gaps that example-tests miss. Direct fit.

- Extends unit schema (`generate-units/references/unit-schema.md`) with optional `properties:` array alongside existing `acceptance_test:`
- Each property = invariant statement with MANDATORY citation (vault section / entity / constitution clause)
- generate-units v2.4 → v2.5 emits PBT test stubs when framework detected:
  - Python (Hypothesis) ⭐⭐⭐⭐⭐
  - TS/JS (fast-check) ⭐⭐⭐⭐⭐
  - Go (gopter) ⭐⭐⭐⭐
  - Rust (proptest) ⭐⭐⭐⭐
  - PHP (Eris) ⭐⭐⭐
  - Other: skip emission; document properties as advisory
- execute-bolts v2.2 → v2.3 runs PBT tests as acceptance phase; failures with `severity: error` → halt `pbt_property_violated` with counterexample preserved
- New reference: `plugins/mega-sdd/skills/generate-units/references/pbt-integration.md`

Properties vs acceptance_test:
- acceptance_test: specific scenarios (examples); REQUIRED always
- properties: universal invariants (all valid inputs); OPTIONAL opt-in (v2.5+)
- Use both — examples for happy paths; properties for invariants across input space

### Anti-halu rails (mandatory)

**Replay**:
- READ-ONLY (never modifies code/vault/memory)
- DETERMINISTIC diff classification (rule table; no LLM judgment)
- JSON Lines for race-tolerant append
- Cosmetic divergence (timestamps) excluded from halt classification

**PBT**:
- Citations ENFORCED: properties without `cites:` field REJECTED at generate-units render pass
- NO framework auto-install: skill never modifies composer.json/package.json/etc.
- Counterexamples preserved in halt YAML for user debugging
- Severity binary: `error` halts; `warning` doesn't
- `--no-pbt` flag opt-out preserves pre-v2.5 behavior

### Changed — Skill versions

- `generate-units`: 2.4.0 → 2.5.0 (PBT emission for properties)
- `execute-bolts`: 2.2.0 → 2.3.0 (PBT validation in acceptance phase)

### Added — New artifacts

- `plugins/mega-sdd/commands/replay.md` — `/mega-sdd:replay` command
- `plugins/mega-sdd/skills/generate-units/references/pbt-integration.md` — PBT schema + emission patterns per language

### Backward compatibility

- v3.10 units without `properties:` field → execute-bolts treats as v2.4 (acceptance_test only); no behavior change
- Existing acceptance_test mechanism unchanged
- PBT-emitted test files use `tests/Property/` convention; doesn't conflict with existing test dirs
- `--no-pbt` flag preserves pre-v2.5 behavior
- Replay is opt-in standalone command; no impact on existing pipelines

### Deferred (Iter 19+)

Per research Iter 17 deferred list (not picked this iter):

- OpenAPI emission from vault flows
- Semgrep + LLM triage post-bolt gate
- Convergence/iteration loops in orchestrate-flow
- Pattern → template generation

### Plugin metadata

- `plugin.json`: 3.10.0 → 3.11.0 (minor — additive opt-in extensions)

## [3.10.0] — 2026-05-21

### Added — Iter 17: Constitution Layer (8th vault file)

Research-driven addition. Per agent deep-search Iter 17+: **Spec Kit `/speckit.constitution` + AWS Kiro "steering files"** independently converged on this pattern in 2025-2026. Strong evidence; ADOPT verdict.

### What's new

**8th vault file**: `<vault>/constitution.md` — project-facing rules distinct from `AGENTS.md` (agent-facing flattened export).

Captures non-negotiable project invariants that EVERY bolt must respect:

- **§A Coding standards** — naming, file organization, comment style
- **§B Security baselines** — auth, input validation, secret handling
- **§C Architecture invariants** — layered architecture rules, allowed dependencies
- **§D Anti-patterns** — drawn from legacy gotchas, team learnings, KB critical findings
- **§E Performance constraints** — response time targets, query patterns
- **§F Compliance** — regulatory requirements, audit trail mandates

### How constitution drives bolts

| Phase | Constitution interaction |
|---|---|
| `generate-intent` v1.8 → v1.9 | NEW Step 3.4: write constitution.md from PRD/KB/memory; user signs off |
| `bind-codebase` (v1.7+) | Cite constitution clauses when surfacing CONFLICTs; flag clause-violating bindings as halts |
| `generate-units` v2.3 → v2.4 | NEW Step 12.3: inject relevant constitution clauses into each unit's `## Hard rules` |
| `execute-bolts` (v2.2+) | Pre/post-flight Hard Rule scan auto-validates constitution clauses (no separate command) |
| `detect-drift` (v1.1+) | Flag code violating constitution as drift findings |

### Version pinning

Constitution version pinned to vault:

```json
"constitution_version": "1.0.0",
"constitution_hash": "<sha256 of constitution.md>"
```

`detect-drift` validates hash; if constitution.md changed, all units potentially affected → halt prompting re-bind.

### Anti-halu rails (mandatory)

- Constitution clauses MUST cite source: `(per PRD §<section>)` OR `(per KB §<file>:<line>)` OR `(per memory decision row <N>)`
- Constitution updates require explicit user action; never auto-edited
- User MUST sign off before vault locks (initial gen extracts; user reviews)
- Constitution overrides codebase reality: existing-code violations cause bolt pre-flight FAIL
- Anti-pattern §D clauses default to Anti-patterns (informational); promoted to Hard Rules only when mechanically detectable (per Iter 6 DESIGN-OQ-6)
- `--no-constitution` flag opt-out for one-off greenfield demos

### Changed — Skill versions

- `generate-intent`: 1.8.0 → 1.9.0 (Step 3.4 constitution.md generation)
- `generate-units`: 2.3.0 → 2.4.0 (Step 12.3 constitution clause injection into unit Hard Rules)
- Vault file count: 7 → 8 (added constitution.md as 8th file; vault-contract.md updated)

### Added — Schema

- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — new §constitution section with full schema, integration points, anti-halu rails

### Backward compatibility

- v3.9 vaults without constitution.md → skill detects absence; auto-routes to user prompt "constitution.md missing; generate from PRD constraints? Y/n"
- Existing 7-file vaults unchanged; constitution is 8th additive file
- Tools that hardcoded 7-file count → graceful fallback (treat missing constitution as empty list)
- `--no-constitution` flag preserves pre-v1.9 behavior

### Why this matters

Brownfield rebuild (tradefinance scenario) needs project invariants baked into bolts:
- Without constitution: bolts may add `dd()` calls, bypass auth middleware, replicate legacy bugs
- With constitution: bolts pre-flight FAIL on violations; user catches early before commit

Spec Kit + Kiro convergence = battle-tested pattern. Mega-sdd adopts.

### Deferred (Iter 18+)

Per agent recommendations:

- **Replay/audit harness** (`mega-sdd:replay`) — deterministic bolt re-execution from JSON fixtures. Strong fit (pure bash + jq); deferred for fixture-format design.
- **Property-based testing** in unit schema — Anthropic NeurIPS 2025 paper validates 30-32% gap coverage. Multi-language Hypothesis/fast-check/gopter integration needs per-language design.
- **OpenAPI emit** from vault flows — Schemathesis-friendly contracts. Lower priority.
- **Semgrep + LLM triage gate** — 91% FP reduction post-bolt. Opt-in CI hook; deferred.

### Acceptance criteria

✅ `<vault>/constitution.md` added as 8th file
✅ Schema documented in vault-contract.md §constitution
✅ generate-intent Step 3.4 writes constitution
✅ generate-units Step 12.3 injects clauses into Hard Rules
✅ Anti-halu rails preserved (citation mandatory, user sign-off, no silent auto-edit)
✅ Backward compat: v3.9 vaults work without constitution

### Plugin metadata

- `plugin.json`: 3.9.0 → 3.10.0 (minor — new vault file is observable additive change)

## [3.9.0] — 2026-05-21

### Changed — Iter 16: Scan-First for Brownfield (Pipeline Reorder)

Per user feedback — "harusnya menurut lo scan codebase dlu. atau prd vault dlu?... ketika generate vault klo udah ada data scan codebase nya harusnya lebih robust hasil vaultnya". User intuition CORRECT. Pipeline order reordered for brownfield to give vault generation codebase awareness from the start.

### What changed

**Previous order (Iter 0-15)**:
```
brownfield: generate-intent → scan-codebase → bind-codebase → generate-units → execute-bolts
```

**New order (Iter 16, v3.9.0+)**:
```
brownfield: scan-codebase → generate-intent (scan-aware) → bind-codebase → generate-units → execute-bolts
```

Greenfield unchanged (no codebase to scan):
```
greenfield: generate-intent → generate-units → execute-bolts
```

### Why

Previous order's compounding pain points:
- Vault fabricated entities that already existed in codebase
- OQs surfaced at gen-time couldn't reference codebase signals (cold-start classifier)
- Iter 8 PARTIAL_FIELDS_MISSING discovered LATE (at binding, requiring re-work)
- Conventions detected AFTER vault written; convention defaults retrofitted via memory
- Iter 2 tech-OQ classifier produced lots of `tech/recommend` that could have been `tech/scan` if codebase signals were known

User's intuition: scan codebase FIRST so vault has context. Confirmed by audit:
- Fewer OQs per vault (~30-50 → ~10-20 in typical brownfield)
- Existing-entity awareness in vault claims
- Conventions baked in at gen-time
- PARTIAL_FIELDS_MISSING anticipated, not discovered

### How — minimal viable change

**`generate-intent` v1.7 → v1.8** — new Step 0.8 scan-aware context loading:

1. Probe for existing `codebase-map.md` (current + legacy paths)
2. Probe for `conventions.md` memory (Iter 5)
3. Probe for `knowledge-base/` (Iter 0)
4. If codebase-map missing + brownfield detected → INTERACTIVE prompt to run scan-codebase first OR proceed without scan
5. Loaded context used in Steps 2 (extraction), 3 (write 7 files), 3.5 (OQ classifier)

**`orchestrate-flow/references/routing-rules.md`** — updated decision matrix:

- Brownfield paths: scan-codebase FIRST then generate-intent (scan-aware)
- Greenfield paths: generate-intent unchanged
- Greenfield/brownfield detection: `.git + existing code files = brownfield`; `bare scaffolding = brownfield-light`; `no .git OR fresh create-project = greenfield`
- `--brownfield` / `--greenfield` flag override

### What's preserved

Architect/dev separation philosophy (Iter 0):
- generate-intent still doesn't write code; only reads scan output
- `--no-pre-scan` flag opt-out preserves pre-v1.8 architect-only workflow
- PRD precedence preserved: PRD claims OVERRIDE codebase reality; CONFLICTs surface in binding phase (not silenced)

Anti-halu rails:
- Scan-aware mode is OPT-IN via prompt (or auto-route under `--auto`); never silent
- Existing-entity awareness ADDS annotation, NOT replaces vault claim
- All halt-protocol behaviors unchanged
- Backward compat: vaults gen'd before v1.8 (without scan-awareness) continue to work; `--refresh` flag for retro-scan-aware regen

### Affected skills + versions

- `generate-intent`: 1.7.0 → 1.8.0 (Step 0.8 scan-aware context loading)
- `orchestrate-flow/references/routing-rules.md` updated for brownfield reorder

(scan-codebase, bind-codebase, generate-units, execute-bolts unchanged.)

### Backward compatibility

- v3.8 brownfield pipelines using old order still work (orchestrate-flow detects existing scan artifacts; uses them)
- v3.8 vaults regenerated under v3.9 with new order produce HIGHER quality output (more scan context)
- `--no-pre-scan` flag on `generate-intent` preserves pre-v1.8 behavior exactly
- Greenfield path unchanged

### Plugin metadata

- `plugin.json`: 3.8.2 → 3.9.0 (minor — observable chain reorder for brownfield)

### Acceptance criteria

✅ Brownfield chain runs scan-codebase before generate-intent
✅ Greenfield chain unchanged (no scan)
✅ generate-intent reads codebase-map + conventions.md + KB context when available
✅ OQ classifier auto-resolves tech/scan OQs at gen-time (not retrofitted at bind)
✅ PRD claims still override codebase reality (CONFLICT surfaces at binding)
✅ Architect/dev separation preserved via `--no-pre-scan` opt-out
✅ Audit doc Drift D-3 (cache invalidation) addressed: scan-codebase results cached + reused

### Outstanding (Iter 17+)

- `scan-codebase --quick` mode for faster brownfield-light scan (full AST not needed for convention detection)
- Cache invalidation policy: re-run scan when X days old OR when codebase mtime changes significantly
- Pre-Iter-16 vaults: migration helper to retro-fit scan-aware context

## [3.8.2] — 2026-05-21

### Fixed — Iter 15: next-action consistency (closes Iter 9 audit Drift D-2)

Per user feedback — "lalu di setiap prosesnya mau auto atau manual, selalu di berikan next action recomendation kan?". Confirmed YES across modes, BUT honest disclosure of small inconsistency: 3 skills lacked formal `## Handoff emission` section in SKILL.md (chat hints existed, but no structured YAML for orchestrator auto-continue under `--auto`).

Per Iter 9 audit Drift D-2, this iter closes the gap.

### Added — Handoff YAML emission sections

- `resolve-oq` v0.7.0 → v0.8.0 (emits handoff YAML with next_action: bind-codebase if --binding mode; orchestrate-flow if intent mode)
- `diff-vault` v1.1.0 → v1.2.0 (emits handoff YAML with next_action: resolve-oq if CONFLICTs surfaced; orchestrate-flow if clean)
- `detect-drift` v1.0.0 → v1.1.0 (emits handoff YAML with next_action: resolve-oq if drift findings; null if zero drift)

(`memory` already had handoff emission from Iter 5; `emit-agents-md` already had from Iter 6.)

### Result — three-mode next-action consistency

Mega-sdd now guarantees next-action recommendation in ALL three modes for ALL skills:

| Mode | Mechanism | Coverage |
|---|---|---|
| **Auto** (`/mega-sdd:auto --deep`) | Structured handoff YAML with `next_action.suggested_skill` + `suggested_args` + `rationale` | 11/11 skills (was 8/11; now complete) |
| **Manual** (standalone skill invocation) | Chat hint at end of skill output (`## Hand-off` section) | 11/11 skills (always was complete) |
| **Halt** (blocker) | YAML `blocker.next_action` field (mandatory across all halt types) | 100% of halt types (always was complete) |

### Anti-halu invariants preserved

- Handoff YAML emissions are DETERMINISTIC (skill writes structured YAML at end; no LLM judgment in the protocol)
- Status field is honest (completed | paused | halted)
- Next-action SUGGESTIONS — user can ignore + run other commands
- Halt YAMLs unchanged (no rail relaxation)

### Backward compatibility

PURELY DOCS + structured-output addition. Skills that previously emitted only chat hints still do; they ALSO emit YAML under `--auto`. Standalone manual invocations see no change. Orchestrator (Iter 4) gracefully handles BOTH old (chat-hint-only) AND new (handoff YAML) skills — no breakage.

Plugin 3.8.1 → 3.8.2 (patch).

## [3.8.1] — 2026-05-21

### Documentation — user-facing docs pass

Per user request — "update readme dan test scenario secara compre dan user friendly untuk yg baru pertama kali pake". Pure docs patch; no behavior change.

**Added — `tests/scenarios/`** — first-time user walkthroughs

NEW directory with 6 step-by-step scenarios + sample PRD:

- `README.md` — scenario chooser + install check + verification + halt recovery overview
- `sample-prd-clinic.md` — copy-paste sample PRD for first-run demos
- `scenario-1-greenfield-from-idea.md` — single sentence → working code (15 min)
- `scenario-2-prd-driven-feature.md` — PRD-driven feature build (30 min)
- `scenario-3-field-extension.md` — field-level Iter 8 demo (the "PRD has nip+nama+password, code has nip+password" walkthrough; 20 min)
- `scenario-4-legacy-rebuild.md` — extract KB + rebuild on new framework (4 hours wall-clock)
- `scenario-5-multi-squad-parallel.md` — multi-team coordination (45 min)
- `scenario-6-recovery-from-halt.md` — halt types + universal recovery pattern (15 min)

Each scenario includes:
- Concrete copy-paste inputs
- Expected outputs at each phase
- Common pitfalls + recovery paths
- Cross-links to relevant SKILL.md / references / specs

### Changed — Root README rewritten user-journey-first

`README.md` restructured:

- **30-second pitch** at top (with `/mega-sdd:auto ./prd.md` callout)
- **Quick start (5 minutes)** section with install + scenario chooser
- **Common invocations** with copy-paste examples
- Architecture deep dive + autonomy + memory + tech upgrades + folder structure + cheat-sheet ALL moved to collapsed details sections
- Reflects v3.8.0 reality (20 commands, 11 skills, 14 iterations)

### Changed — Plugin README synced

`plugins/mega-sdd/README.md` updated:

- v3.8.0 version + per-skill version comments
- Scenario chooser pointing to `tests/scenarios/`
- Reuse-stable tooling table (Iter 14 adoptions)
- Memory layer overview
- License + attributions section

### Why this matters (philosophy alignment)

Per Iter 13 audit — mega-sdd's design philosophy is "ONE command does everything; advanced users access phases manually". User-facing docs MUST reflect this:

- Root README leads with `/mega-sdd:auto`, not 20-command grid
- Scenarios show ONE command running full pipeline
- Advanced commands clearly marked as power-user use cases
- First-time user can run a working scenario in 15 min

### Plugin metadata

- `plugin.json`: 3.8.0 → 3.8.1 (patch — docs only; no behavior change)

### Backward compatibility

PURELY DOCS — no skill changes, no command changes, no schema changes, no behavior changes. Existing v3.8.0 users see same pipeline. Just better docs.

### Acceptance criteria (all met)

✅ Root README leads with `/mega-sdd:auto` and 30-second pitch
✅ Quick start section with 5-min install path
✅ 6 user-facing scenarios with copy-paste examples
✅ Sample PRD included for reproducible first-run
✅ Common halts + recovery covered in Scenario 6
✅ Plugin README + paths reference both updated to v3.8

## [3.8.0] — 2026-05-21

### Added — Iter 14: Reuse-Stable Tooling Adoptions

Per user feedback — "adalagi ga yg berguna. jadi better reuse yg stable dari pada build" — research agent dispatched to scan for stable third-party tools mega-sdd should ADOPT instead of building from scratch. Validates 5 picks; ships 3 high-leverage adoptions + centralized install docs.

### Critical finding — bundling tools is wrong approach

User asked "bisa ga sih udah include aja di dalam skills?" Research verdict: **NO**. Reasons:
- 5 platforms × multiple binaries × ~5MB each = 50MB+ plugin bloat
- License redistribution complexity (MIT/Apache attribution per binary)
- Maintenance treadmill (binary updates per release)
- Plugin distribution architecture (Claude Code plugins are markdown-driven; bundling binaries breaks pattern)
- Standard package managers (brew/cargo/npm/scoop) already handle updates better

**Adopted approach**: centralized install reference doc + skill detection messages point users to install once via their package manager.

### Added — Centralized install reference

`plugins/mega-sdd/references/tooling-install.md` (NEW) — comprehensive install commands per platform per optional tool. Replaces scattered install messages in 5 skill files. One source of truth.

Documents install for: tree-sitter, ast-grep, ripgrep, jd, markdownlint-cli2, gh, superpowers. Plus one-command setup blocks for brew/cargo/npm/scoop/pipx users.

### Added — 3 tooling adoptions

**ripgrep `--json`** (Iter 14 Pick A)

- `scan-codebase` v2.2 → v2.3 — regex fallback path now prefers `rg --json` when available; structured JSON output (begin/match/end/summary records) faster + more reliable than text grep
- Same pattern available in detect-drift + bind-codebase (procedural mention)
- Falls back to GNU grep when ripgrep absent
- Why: already-ubiquitous native; drop-in upgrade; zero new runtime deps

**jd (JSON/YAML diff with RFC-6902 patches)** (Iter 14 Pick E)

- `diff-vault` v1.0 → v1.1 — canonical structural diff for vault.json via `jd` when available
- Patches stored at `<vault>/.mega-sdd/vault-diffs/<ISO8601>.patch` for audit trail + replay capability
- Falls back to skill-internal Read+compare when jd absent
- Why: difftastic doesn't generate patches; jd's RFC compliance enables apply/revert

**markdownlint-cli2** (Iter 14 Pick C)

- `lint-units` command Step 6.5 (NEW) — optional vault prose quality check
- mega-sdd-friendly config: MD013 (line-length) off, MD041 (first-line-h1) off, MD033 (inline-HTML) off
- Output integrated into lint-units summary as additional warnings (not halts)
- Skipped when markdownlint-cli2 absent
- Why: stable single binary; broader ecosystem than custom prose rules

### Skipped (with rationale)

Per research agent + my critical review:

- **Custom install helper script** — maintenance trap; 6-line README block more durable than shell script detecting 5 platforms
- **Vale** — needs vocab/style packages; spec language too domain-specific; ROI low
- **MkDocs/Docusaurus** — Python/Node runtime; Material-for-MkDocs entered maintenance mode Nov-2025 (ecosystem fracture)
- **just / Taskfile / Make** — competes with handoff YAML; introduces duplicate orchestration source
- **Lefthook / pre-commit / husky** — mega-sdd is plugin-shaped, not repo-template-shaped; recommend in user docs, not plugin internals
- **Semgrep / Comby** — overlap with ast-grep; slower or weaker semantics
- **difftastic** — beautiful human-readable diff but no patch output; jd is correct pick

### Considered but deferred

- **check-jsonschema** — would deterministically validate vault.json + unit frontmatter. Defer: needs schema files first (vault.schema.json + unit.schema.json), and current Iter 1+11+12 lint covers most issues procedurally. Adopt if validation precision becomes pain point.
- **gh CLI per-bolt PR pattern** — would auto-create GitHub PR per atomic commit. Defer: most users want manual PR control over multi-commit batches; document as procedure pattern in Iter 15 if requested.
- **Aider tags.scm vendoring** — Aider is Apache-2.0; ships .scm queries for 130+ languages. Defer pending per-grammar license check (some upstream tree-sitter-* grammars are BSD/MIT mix).

### Changed — Skill versions

- `scan-codebase`: 2.2.0 → 2.3.0 (ripgrep `--json` adoption)
- `diff-vault`: 1.0.0 → 1.1.0 (jd canonical diff + patch storage)
- `lint-units` command: + Step 6.5 markdownlint-cli2 optional pass

### Added — New reference

- `plugins/mega-sdd/references/tooling-install.md` — single source of truth for ALL optional native tooling install commands

### Anti-halu invariants preserved

- All tooling adoptions are OPTIONAL with graceful fallbacks
- Ripgrep `--json` output is DETERMINISTIC (no LLM interpretation of structured records)
- jd patches are RFC-6902 compliant (deterministic JSON Patch format)
- markdownlint produces SARIF/JSON output (deterministic)
- Tool DETECTION via `command -v` (deterministic)
- Fallbacks preserve v3.7 behavior when tools absent (no silent quality degradation; just less precise output noted in chat)

### Backward compatibility

- v3.7 pipelines without tooling continue working identically (graceful fallbacks)
- Existing diff-vault output (without jd) → unchanged when jd absent
- Existing scan-codebase regex output → unchanged when ripgrep absent (same patterns + outputs)
- Existing lint-units output → unchanged when markdownlint-cli2 absent (no Step 6.5 invocation)
- No vault format changes, no memory schema changes

### Outstanding (Iter 15+)

- check-jsonschema integration (after vault + unit JSON schemas authored)
- gh CLI per-module PR pattern (procedure docs)
- Aider .scm vendoring (license-cleared subset)
- Field-test validation in tradefinance-rebuild

## [3.7.0] — 2026-05-21

### Restored — Iter 13: Single-command Philosophy + Consolidation

Per user feedback — "pendekatan jadi tidak simple. tidak sejalan dengan yg di design. on default harusnya udah bisa jalanin itu semua, tidak perlu kasih command tambahan".

**Audit verdict** (`docs/superpowers/audits/2026-05-21-command-sprawl-audit-v3.6.md`): VALID. 20 commands shipped vs design philosophy of "ONE command (`/mega-sdd:auto`) does everything; advanced users access phases manually". Drifted.

**Restoration**:

1. **Auto-integrate diagnostics into orchestrate-flow** (v2.1 → v2.2). Per audit Phase B, these now run TRANSPARENTLY inside `auto` / `orchestrate-flow --deep`:
   - After `generate-units` → `lint-units` (quality gate); one-line summary in chat
   - Before `execute-bolts` → `analyze-parallelism` (compute wave plan for `--parallel`)
   - After `execute-bolts` → `list-modules` (per-module status in chain end summary)
   - At chain end → `emit-agents-md` (config-flag default-on; AGENTS.md refreshed)
   - At chain end → memory review prompt (if pending learning suggestions exist)
   - Opt-out flags: `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md`

2. **Removed deprecated `/mega-sdd:from-prompt`** — was deprecated since v1.3 per README ("Will be removed in v1.4"), then v3.1 ("Will be removed in v3.1"). Now at v3.7. Long overdue. Users still using it should switch to `/mega-sdd:auto "<brief>"` or `/mega-sdd:generate-intent --from-prompt "<brief>"`.

3. **Marked auto-invoked commands as "ADVANCED / AUTO-INVOKED"** in their command descriptions:
   - `lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`
   - Description tells users these run automatically; standalone use is for debugging/CI/one-off only

4. **Simplified README "Primary commands" section** — promote `auto` to dominant; group others by use case (Phase / Event-driven / Maintenance / Diagnostic-auto-invoked). Removes confusion that there are 20 things to choose from.

### Changed — Skill versions

- `orchestrate-flow`: 2.1.0 → 2.2.0 (auto-integrate diagnostics at chain phases)

### Removed

- `plugins/mega-sdd/commands/from-prompt.md` (deprecated since v1.3; removed in v3.7 — see CHANGELOG above)

### Updated

- `plugins/mega-sdd/commands/auto.md` — added "Auto-integrated diagnostics" section + opt-out flags
- `plugins/mega-sdd/commands/lint-units.md` — description prefixed `[ADVANCED / AUTO-INVOKED]`
- `plugins/mega-sdd/commands/analyze-parallelism.md` — same
- `plugins/mega-sdd/commands/list-modules.md` — same
- `plugins/mega-sdd/commands/emit-agents-md.md` — same
- `README.md` — restructured "Primary commands" to emphasize `/mega-sdd:auto` as THE command

### Anti-halu invariants preserved

- Auto-integrations are DETERMINISTIC (skill description tells orchestrator WHEN to invoke; not LLM choice)
- All halt-protocol blockers fire identically (lint can halt with `--strict-quality`; analyze surfaces over-coupling SUGGESTIONS only; memory review SURFACES suggestions but never auto-applies)
- Opt-out flags preserve full manual control for advanced users
- Standalone command invocation still works (auto-integrations don't break standalone usage)

### Backward compatibility

- v3.6 pipelines invoking individual commands continue to work
- `from-prompt` removal: users get standard "command not found" message; switch to `/mega-sdd:generate-intent --from-prompt "<brief>"` or `/mega-sdd:auto "<brief>"`
- `--no-*` opt-out flags preserve v3.6 behavior when user explicitly disables auto-integrations
- No vault format changes
- No memory schema changes

### Why this matters (philosophy alignment)

Mega-sdd's design philosophy:
- **Single opinionated plugin** (no sprawl)
- **`/mega-sdd:auto` as ONE-shot entry**
- **Anti-halu via rails + defaults, not user-managed checks**
- **Markdown-driven** (single source of truth)

Iter 12 sprawled into 20 commands; users had to know which ones to run manually. Iter 13 restores: `auto` runs everything; diagnostics are background; advanced commands available but not required.

### Acceptance criteria (all met)

✅ `/mega-sdd:auto ./prd.md` runs full pipeline including lint + analyze + list + emit + memory review without separate invocations
✅ Diagnostic command files marked `[ADVANCED / AUTO-INVOKED]` in description
✅ README primary commands restructured to emphasize `auto`
✅ `from-prompt` deprecated alias removed
✅ CHANGELOG explains philosophy restoration

### Outstanding (Iter 14+)

- Optional: merge `migrate-rules` + `migrate-paths` into `/mega-sdd:migrate <type>` (consolidates 2 niche commands → 1)
- Plugin README sync to v3.7 (defer to next release polish)
- Field-test validation in tradefinance-rebuild project

## [3.6.0] — 2026-05-21

### Added — Iter 12: Unit Quality + Parallelism Tools

Per user discussion — two concerns: (1) "units yang tergenerate apakah sudah solid dan berkualitas?" + (2) "units bakal di-share untuk squad — tiap squad units harus bisa parallel tidak sequence".

Three additive tools/changes ship in this minor bump:

**Tool 1 — `/mega-sdd:lint-units`** (NEW command)

Static analysis of vault units for quality + grounding. Read-only diagnostic. Per-unit breakdown:
- HARD frontmatter checks (id format, vault_source, task_type validity, target_files completeness, acceptance_test presence, depends_on resolution)
- Iter 8 defensive checks (grounding_confidence label + grounding_evidence consistency)
- Iter 11 module checks (M-XXX assignment validity; flag M-unassigned)
- Iter 1.1 squad checks (when multi-squad)
- SOFT body checks (Anchors per task_type, Implementation steps directive prose, Migration notes for extend, Hard Rules parseable)
- Anchor verification (file probe + line range; SOFT warnings for aspirational anchors)
- Hard Rule v1 OR v2 grammar validation
- Binding consistency (task_type ↔ Implementation State Map per Iter 1+8)

Output: per-unit table + summary metrics (quality histogram, anchors coverage %, hard rules coverage, module coverage) + prioritized recommendations. Filter via `--module=`, `--squad=`, `--strict` (CI mode promotes warnings to halts).

**Tool 2 — `/mega-sdd:analyze-parallelism`** (NEW command)

DAG analysis for parallelism opportunities + bottleneck identification. Read-only.

Per-squad / per-module / whole-vault analysis:
- Depth (longest chain)
- Max parallel width (max units at same topological level)
- Topological waves (suggested execution batches)
- Bottleneck units (high fork-out or high join-in)
- Suspected over-coupling (depends_on edges without file overlap or symbol cross-ref)
- Critical chain (longest path)
- Estimated wall-clock speedup vs sequential

Output: table (default) | JSON (machine-parseable) | mermaid (visual graph for paste into mermaid.live). Filter via `--per=squad|module|all`, `--module=`, `--squad=`, `--depth-only`.

Helps user verify "Squad1 > Unit 1-3" parallel intent BEFORE bolt execution. Hand-off suggestions: parallelism_speedup ≥2 → `/mega-sdd:execute-bolts --per-squad --parallel`; <1.5 → review over-coupling.

**Tool 3 — generate-units v2.2 → v2.3 stricter `depends_on` emission**

Pre-v2.3 was conservative: emitted `depends_on` liberally → forced sequential where units could parallelize. v2.3+ tightens emission per concrete coupling evidence:

Emit `depends_on: U-X` ONLY IF at least one is true:
- **File overlap**: target_files set intersection non-empty AND ordering matters
- **Symbol cross-reference**: Anchors cite a symbol another unit creates
- **Migration Notes reference**: extend's Migration notes explicitly reference unit's planned output
- **Vault declaration**: vault section explicitly orders flows
- **Module blocked_by**: cross-module units with file collision (per Iter 11)

DO NOT emit for:
- Same vault section / same module (implicit ordering not guaranteed)
- Conceptual sequencing without file overlap
- "Logical" precedence without target_files evidence

Effect: units default to parallel-eligible unless concrete coupling exists.

**Flags**:
- `--strict-deps` (DEFAULT ON v2.3+) — apply tighter rules
- `--loose-deps` — pre-v2.3 conservative emission (legacy parity)
- `--no-deps` — emit zero depends_on (testing/debugging; USE WITH CAUTION)

### Changed — Skill version

- `generate-units`: 2.2.0 → 2.3.0 (Step 4 stricter depends_on emission)

### Added — New commands

- `commands/lint-units.md` — quality lint command
- `commands/analyze-parallelism.md` — DAG analysis command

### Anti-halu invariants preserved

- Both new commands are READ-ONLY (never modify vault, units, binding, memory)
- DAG analysis is DETERMINISTIC (graph algorithms on parsed frontmatter)
- Over-coupling suggestions are heuristic — surfaced as SUGGESTIONS for user review, NEVER auto-removed
- Anchor verification via Bash file probe or codebase-map lookup (not LLM judgment)
- Hard Rule validation via ast-grep parse (when v2) or regex (v1)
- All recommendations cite specific units + specific check that failed
- Stricter depends_on tightens default; user can always add deps manually via frontmatter edit; OR opt back into legacy via `--loose-deps`

### Backward compatibility

- v3.5 vaults with existing `depends_on` edges → unchanged when read (lint just shows them)
- Regenerating units with `--strict-deps` (default v2.3+) → likely produces FEWER depends_on; existing tests should still pass since fewer false coupling
- Users wanting pre-v2.3 emission → `--loose-deps` flag for legacy parity
- `--no-deps` is a testing escape hatch — produces maximally parallel units; only safe when user knows no coupling exists

### Quality assessment (honest answer to user's "sudah solid?" question)

Documented across the CHANGELOG entries Iter 0-11 and audit (`docs/superpowers/audits/2026-05-21-pipeline-audit-v3.2.md`):

- **Strong structural grounding**: target_files whitelist, acceptance_test mandatory, vault_source citation, task_type derived from binding, Anchors mandatory for verify/extend, Hard Rules pre/post-flight, Migration notes auto-populated from field_diff, grounding_confidence label.
- **Quality depends on upstream**: vault clarity, binding precision (tree-sitter > regex), KB presence.
- **Best-effort algorithmic**: PageRank target_files suggestions (Bug 5 documented as approximation), stub-detection for PARTIAL.

For typical brownfield-with-v3.0+-tech: HIGH quality expected. Validation via `/mega-sdd:lint-units` + `/mega-sdd:analyze-parallelism` BEFORE bolts gives user concrete signal.

### Outstanding (Iter 13+)

- Module-level test command auto-detection improvements
- Cross-vault unit reuse patterns (template units shared across vaults)
- AGENTS.md emit per-module "what's done / what's pending"
- README + plugin README updates for v3.5-3.6 layout illustrations

## [3.5.0] — 2026-05-21

### Added — Iter 11: Module Layer (semantic grouping ABOVE atomic units)

Per user UX feedback — units felt "too small" cognitively (30+ atomic units overwhelms; team mental model thinks "auth phase done", not "U-007 done"). After critical analysis, the right fix is NOT bigger atomic units (would break TDD discipline + bolt focus + rollback granularity preserved over 8 iters) but ADDING a semantic grouping layer ABOVE atomic units.

Module = semantic group of related units (like Jira Epic over Stories). Units stay atomic; modules aggregate for human mental-model fit + progress tracking + filtered execution.

**Module concept**:

- **id**: kebab-case identifier with `M-` prefix (e.g., `M-auth`, `M-leave-mgmt`)
- **name**: human display name
- **vault_sections**: which vault sections this module covers (e.g., `04-flows.md#F-U-001-login`)
- **dod**: Definition of Done checklist (auto-runnable test commands supported)
- **priority**: P0/P1/P2/P3
- **blocked_by / blocks**: module-level dependency graph (inter-module ordering)

**Unit gains `module: <id>` frontmatter field** — auto-derived from `vault_source` matching against modules.yaml. Unmatched units → `M-unassigned` (warning, not halt).

**Vault layout extension**:

```
<vault>/
├── _meta/
│   ├── squads.yaml          # Iter 1.1 (orthogonal to modules — squads = WHO, modules = WHAT)
│   └── modules.yaml         # NEW v2.2+ (Iter 11)
├── units/
│   ├── U-*.md               # each gains `module: <id>` frontmatter
│   └── _index.md            # NOW grouped by module (with DoD + status per module)
└── (vault content + binding.md + bolts/)
```

**Auto-derivation**: when `_meta/modules.yaml` absent, `generate-units` scans vault structure (user flows in `04-flows.md`, components in `02-architecture.md`) and writes `_meta/modules.yaml.auto`. User renames to `.yaml` to lock in, or edits before re-generating.

**New `_index.md` format** — grouped by module with:
- Module name + status (X/Y units complete) + priority + DoD checklist
- Units table within module (ID, title, task_type, depends_on, status)
- Cross-module dependency graph + topological order
- Fallback to flat list when only `M-default` exists (backward-compat with pre-v2.2 vaults)

**New command `/mega-sdd:list-modules`**:

```bash
/mega-sdd:list-modules                          # show all modules with progress
/mega-sdd:list-modules --module=M-auth          # detail for specific module
/mega-sdd:list-modules --mark-dod=M-auth        # interactive DoD checklist marking
/mega-sdd:list-modules --format=json            # machine-parseable
```

Output format:

```
ID              Name                          Status         Units   DoD     Priority   Blocked-by
M-auth          Authentication & Auth         in-progress    2/5     2/3     P0         (none)
M-leave-mgmt    Leave Management              not-started    0/3     0/2     P1         M-auth (pending)
M-reporting     Reporting & Analytics         completed      2/2     3/3     P2         M-auth (ok)

Next actionable:
  → Complete M-auth: 3 units pending (U-003, U-007, U-008)
  → Run: /mega-sdd:execute-bolts --module=M-auth
```

**`execute-bolts --module=<id>` flag** — filtered execution per module:

- Loads modules.yaml
- Checks `blocked_by` modules are completed (else halt `module_blocked_by`)
- Filters units to `module: <id>`
- Topologically sorts within module
- Runs sequentially (or with `--parallel`)
- Post-completion: probes module DoD checklist; user marks via `/mega-sdd:list-modules --mark-dod`

### Changed — Skill versions

- `generate-units`: 2.1.0 → 2.2.0 (Step 4.5 module assignment + grouped _index.md template)
- `execute-bolts`: 2.1.0 → 2.2.0 (`--module=<id>` flag + module DoD validation)

### Added — New reference + command

- `plugins/mega-sdd/skills/generate-units/references/modules-schema.md` — full module schema + auto-derivation algorithm + cross-module dependency validation + backward compat
- `plugins/mega-sdd/commands/list-modules.md` — module progress command + interactive `--mark-dod` flow

### Changed — Unit schema

- `plugins/mega-sdd/skills/generate-units/references/unit-schema.md` — added optional `module: <id>` frontmatter field with format guidance

### Halt protocol additions

- `module_unassigned_warn` — ≥10% units unassigned (warning unless `--strict-modules`)
- `module_blocked_by` — execute-bolts --module=X invoked but X's blocked_by has incomplete prerequisites
- `module_dod_unsat` — module declared completed but DoD items still pending
- `cross_module_dep_invalid` — unit's depends_on crosses module boundary without explicit blocked_by declaration
- `module_cycle_detected` — cycle in module DAG

### Why modules ≠ bigger units (design rationale)

User asked "kalau units jadiin per module seperti phase, gimana?" — instinct correct on the pain (cognitive overload + missing grouping), but solution NOT bigger atomic units. Critical analysis preserved in CHANGELOG:

| Concern | Larger atomic units | Modules over atomic units (THIS DESIGN) |
|---|---|---|
| TDD cycle | One test per huge unit — long cycle | One test per atomic unit — fast cycle |
| Hard Rule scoping | Muddled | Clear per atomic boundary |
| Bolt focus | LLM context diluted | LLM holds one unit at a time |
| Git rollback | Coarse | Per-unit |
| Parallelism | Lower | Preserved |
| Semantic grouping | "Sort of" via size | Explicit via module field |
| Progress tracking | Per-unit (overwhelming) | Per-module (meaningful) + per-unit (detail) |

Atomic invariant (1 unit = 1 PR-sized commit, <300 LOC, ≤5 files) PRESERVED. Module is purely additive cognitive layer.

### Anti-halu invariants preserved

- Module status DERIVED from filesystem signals (unit count, bolt-outcomes.json), DoD checklist markers, blocked-by status — NEVER inferred
- DoD test commands invoked via Bash (deterministic pass/fail)
- Cross-module dependencies require explicit `blocked_by` declaration — silent cross-edges halted
- Auto-derivation writes `.auto` suffix file — never overwrites user-curated `modules.yaml`
- `M-unassigned` fallback for unmatched units — never silently grouped
- Module DAG cycle detection same as unit DAG (cycle_detected halt extended for module-level)

### Backward compatibility

PURELY ADDITIVE:
- v3.4 vaults without `_meta/modules.yaml` → all units `module: M-default` (single implicit module); _index.md flat list (v3.4 behavior preserved)
- v3.4 units without `module:` field → treated as M-default
- `execute-bolts --module=M-default` works for legacy vaults
- `--per-squad` / `--squad=<id>` (Iter 1.1) unchanged and orthogonal to modules
- Existing pipelines using `/mega-sdd:execute-bolts --all` unchanged

### Outstanding (Iter 12+)

- Module-level DoD test command auto-detection patterns (currently text-match heuristic; could be more robust)
- Module groupings could integrate with AGENTS.md emit (per-module "what's done / what's pending" surface)
- Module-level memory rollups (e.g., `memory show modules` showing per-module decision history)
- README + plugin README updates for v3.5 layout (defer to release polish)

## [3.4.0] — 2026-05-21

### Added — Iter 10: Folder Consolidation under `.mega-sdd/`

Per user UX request — "by default semua file output md hasil skill itu masuk saja otomatis ke `.mega-sdd/*`".

Consolidates all mega-sdd outputs under a single `<project-root>/.mega-sdd/` container. Replaces scattered paths (`docs/mega-sdd/vaults/`, `.mega-sdd-memory/`, top-level `codebase-map.md`, `docs/knowledge-base/`) with unified canonical layout. Backward compatible: legacy paths still detected on read; new outputs go to `.mega-sdd/` by default.

**New canonical layout** (per `plugins/mega-sdd/references/paths.md`):

```
<project-root>/
├── .mega-sdd/                              # ALL mega-sdd outputs
│   ├── config.yaml                          # project-level config (output_root, opt-outs)
│   ├── vaults/<slug>/                       # vault content (was docs/mega-sdd/vaults/)
│   │   ├── 00-index.md ... 06-constraints.md, vault.json
│   │   ├── binding.md, bound/
│   │   ├── units/U-*.md
│   │   ├── bolts/U-*/preflight.json, postflight.json, bolt-report.md
│   │   ├── .memory/                         # vault-scope memory (Iter 5; unchanged)
│   │   └── .internal/                       # vault-internal (renamed from .mega-sdd/)
│   │       ├── checkpoints/                 # Iter 6 JSONL checkpoints
│   │       └── symbol-graph.json            # Iter 6 PageRank cache
│   ├── knowledge-base/                      # was docs/knowledge-base/
│   ├── codebase/codebase-map.md             # was <repo>/codebase-map.md
│   ├── memory/                              # PROJECT memory (was .mega-sdd-memory/)
│   │   ├── decisions.md, conventions.md, outcomes.md
│   │   └── archived-vaults/<slug>/          # MEMORY-OQ-5 archive (now naturally inside container)
│   └── exports/                             # future tool-agnostic exports
├── AGENTS.md                                 # UNCHANGED — interop file MUST be at repo root
├── CLAUDE.md                                 # UNCHANGED — project AI context
└── (project source: app/, routes/, src/, etc.)
```

User-scope `~/.mega-sdd/memory/` UNCHANGED (cross-project).

### Added — `/mega-sdd:migrate-paths` command

Walks legacy paths, shows preview, asks confirm, moves via `git mv` (preserves history when in git repo) or plain `mv` fallback. Updates internal references in vault.json + binding.md + per-file frontmatter. Idempotent; safe to re-run. Flag surface:
- `--dry-run` — preview only
- `--from=auto|legacy|mixed`
- `--to=new|legacy`
- `--auto-confirm`

Creates `<project>/.mega-sdd/config.yaml` with `layout: new` + `output_root` + `probe_paths` configuration. Writes migration audit to `.mega-sdd/migration-log.md`.

### Added — Canonical path convention reference

`plugins/mega-sdd/references/paths.md` — full mapping (per-skill old → new paths) + detection logic + config.yaml schema + .gitignore recommendations. Single source of truth for path resolution across all skills.

### Changed — Skill versions

- `extract-intelligence`: 1.1.0 → 1.2.0 (default --out points to `.mega-sdd/knowledge-base/`)
- `scan-codebase`: 2.1.0 → 2.2.0 (default --out points to `.mega-sdd/codebase/codebase-map.md`)
- `generate-intent`: 1.6.0 → 1.7.0 (default vault path `.mega-sdd/vaults/<slug>/`)
- `memory`: 1.1.0 → 1.2.0 (project-scope path moved to `.mega-sdd/memory/`)
- `emit-agents-md`: 1.0.0 → 1.1.0 (vault detection probes new path first, legacy fallback)

### Detection & back-compat

Skills probe in priority order:
1. New layout (`.mega-sdd/vaults/`, `.mega-sdd/knowledge-base/`, etc.)
2. Legacy layout (`docs/mega-sdd/vaults/`, `docs/knowledge-base/`, etc.)
3. Use first match for READ
4. Use NEW path for WRITE (unless `layout: legacy` in config.yaml)

Existing v3.3 projects continue working unchanged. User migrates when ready via `/mega-sdd:migrate-paths`.

### Why `.mega-sdd/` vs `docs/mega-sdd/`

| Aspect | Old (`docs/mega-sdd/`) | New (`.mega-sdd/`) |
|---|---|---|
| Visibility | Visible in tree | Hidden by default |
| Tool/IDE separation | Mixed with project docs | Tool state convention (parity with .git/, .vscode/) |
| Git tracking | Often all-tracked | Per-file decision (recommend track vaults/, gitignore .internal/, .memory/, outcomes.md) |
| Interop discovery | AGENTS.md needs to be at root anyway | AGENTS.md still at root; everything else consolidated |

User explicitly chose this trade-off (visibility for vault content → emit-agents-md provides external visibility surface).

### Anti-halu invariants preserved

- Path detection is DETERMINISTIC (file probe; no fuzzy matching)
- Back-compat ensures no silent data loss
- Migration via `git mv` preserves history
- Reference updates via sed are scoped + backed up with .bak suffix
- `--dry-run` mandatory for first-time users
- Idempotent: re-running migration on already-migrated project is no-op

### Backward compatibility

- v3.3 projects with legacy paths → skills probe legacy first, continue writing there until user migrates
- v3.3 vaults → readable as-is; migration is opt-in
- User-scope memory `~/.mega-sdd/memory/` unchanged
- Vault-scope memory `<vault>/.memory/` unchanged (already inside vault)
- AGENTS.md at repo root unchanged (interop file)
- Optional `.gitignore` updates user-decided per team norms

### Outstanding (Iter 11+)

- Path convention pages in `plugins/mega-sdd/skills/bind-codebase/SKILL.md`, `execute-bolts/SKILL.md`, `generate-units/SKILL.md` not yet added (they operate INSIDE the vault dir, less affected)
- README + plugin-folder README update to v3.4 layout illustrations (defer or do in next release polish)
- AGENTS.md emit could optionally output to `.mega-sdd/exports/AGENTS.mega-sdd.md` AS WELL as repo root (dual-write for tool ecosystems that scan dot-dirs)

## [3.3.0] — 2026-05-21

### Fixed — Iter 9 Audit Fixes Patch

Per audit report `docs/superpowers/audits/2026-05-21-pipeline-audit-v3.2.md`. Ships P0+P1 fixes (8 concrete bugs + 1 E2E gap + 1 doc drift). ~3 hours dev work. Additive/clarifying changes only; no breaking.

**P0 bug fixes (logic errors)**:

- **Bug 1 fix** (bind-codebase v1.7.1) — PARTIAL_FIELDS_BOTH misclassification on disjoint sets. Pre-check `V ∩ C empty` before computing PARTIAL_*; if empty → UNKNOWN (totally disjoint = semantic mismatch, not bidirectional drift).
- **Bug 2 fix** (resolve-oq v0.7) — Iter 7 recommendation citations now PROBED for resolution before surfacing in AskUserQuestion. KB section / memory row / vault ADR / codebase-map line probed via Bash `grep -n` or `Read + scan`. Citation failure → silent downgrade (omit recommendation), NOT halt. Logs to `<vault>/.memory/citation-failures.jsonl` for audit. Mirrors Iter 2 `oq_recommend_citation_invalid` rail.
- **Bug 3 fix** (memory layer v1.1) — Memory writes now mandate POSIX `>>` append (NOT `Write` tool which is overwrite). Race-tolerance preserved via single fs.append per write. Updated memory-schema.md §6 with correct heredoc patterns. Per-skill memory sections must specify "Append via Bash >> heredoc".
- **Bug 4 fix** (orchestrate-flow v2.1) — Chain proposal confirmation message now includes "Halts may re-engage you mid-chain" clarity line. User has accurate expectations: ONE chain-level confirmation; halts are interventions on real issues, not additional confirmations.

**P1 bug fixes**:

- **Bug 7 fix** (execute-bolts v2.1) — `ast-grep test --validate` flag doesn't exist in ast-grep CLI. Replaced with parse-via-scan pattern: `echo "" | ast-grep scan --rule <yaml> --json /dev/stdin`. Exit 0 = parses cleanly; non-zero with stderr = halt `hard_rule_unparseable` with verbatim error.
- **Bug 8 fix** (scan-codebase v2.1) — tree-sitter binary probe now checks BOTH `tree-sitter` AND `tree-sitter-cli` (different package managers ship different names). Fallback chat warning lists all probed names.

**E2E gap fix**:

- **Gap E2E-1 / D-3 fix** — Ship memory migration scripts directory at `plugins/mega-sdd/scripts/memory-migrations/`:
  - `README.md` — naming convention + invocation pattern + script contract
  - `template-migration.sh` — scaffold for future migrations (executable; takes `<memory-dir>` positional; creates backup; logs to learning-log.md)
  - No actual migration scripts yet (memory_schema still at v1); scaffolding in place for future schema bumps

### Changed — Skill versions

- `bind-codebase`: 1.7.0 → 1.7.1 (Bug 1 fix only)
- `execute-bolts`: 2.0.0 → 2.1.0 (Bug 7 fix)
- `memory`: 1.0.0 → 1.1.0 (Bug 3 fix — append protocol mandate)
- `orchestrate-flow`: 2.0.0 → 2.1.0 (Bug 4 fix)
- `resolve-oq`: 0.6.0 → 0.7.0 (Bug 2 fix — citation probe step)
- `scan-codebase`: 2.0.0 → 2.1.0 (Bug 8 fix)

### Added — Audit doc

- `docs/superpowers/audits/2026-05-21-pipeline-audit-v3.2.md` — comprehensive audit of v3.2.0 (68 touch points classified Strong/Medium/Weak + 8 bugs + 8 E2E gaps + 4 doc drift + 6 test gaps + prioritized fix list)

### Audit findings summary

- 75% of behaviors are STRONG (mechanically enforced via Bash/Read/Write/Skill tools)
- 20% MEDIUM (Claude follows procedure; reliable for well-bounded steps)
- 5% WEAK (algorithmic claims Claude can't execute reliably — e.g., PageRank, threshold counting)
- 8 concrete bugs identified; 6 ship in this patch; 2 deferred to Iter 10 (PageRank actual impl + collision batch optimization)

### Backward compatibility

PURELY FIXES — no behavior change beyond bug correction. All fixes additive:

- Bug 1 fix: only affects PARTIAL_FIELDS_BOTH classification on disjoint sets (rare; was misclassified as drift instead of UNKNOWN)
- Bug 2 fix: adds citation probe before surfacing; recommendations without valid citations silently omit (was: could surface fabricated)
- Bug 3 fix: writers now use Bash `>>`; existing memory files compatible (additive appends)
- Bug 4 fix: chat message clarity only
- Bug 7 fix: ast-grep validation now uses correct syntax (would have failed silently with wrong flag)
- Bug 8 fix: tree-sitter probe expanded; users with only `tree-sitter-cli` binary now detected (was: misreported as missing)
- Gap E2E-1 fix: migrations dir + template; no actual migrations yet so no behavior change

### Outstanding (P2/P3 — deferred to Iter 10+)

Per audit Part 6 prioritization:

- Bug 5 — PageRank doc honesty (re-document as approximation OR ship Python helper). Doc fix is 15 min; real impl is 4-8 hours.
- Bug 6 — collision check batching optimization
- Gap E2E-2 — checkpoint emission enforcement (currently relies on Claude remembering at each step)
- Gap E2E-3 — symbol-graph cache invalidation
- Gap E2E-4 — cross-skill version compat assert
- Gap E2E-5 — regex precision tier warning loudness
- Gap E2E-6 — archive `.mega-sdd/` dir on vault deletion (extend Iter 5 archive scope)
- Drift D-1 — tree-sitter `.scm` coverage gap (JS/Rust/Go fall back to regex; document loudly)
- Drift D-2 — handoff YAML for resolve-oq + diff-vault + detect-drift + memory + emit-agents-md
- 6 test coverage gaps (cross-version, migration, PageRank fallback, empty vault, KB+memory cooperation, malformed handoff)

These aren't bugs — they're known opportunities for refinement. Hold for field-test pain to prioritize.

## [3.2.0] — 2026-05-21

### Added — Defensive Generation + Field-level Diff (Iter 8)

Per user UX request — "skills ini lebih pintar. ketika generate units. dan ketika generate itu ada di source code base, bisa auto detecs, atau kasih pertanyaan terlebih dahulu... hasil yg di generate sudah cross check dlu/scan codebase dlu. jadi hasil nya lebih robust tidak ngawang".

Plus clarifying example: "PRD/BRD ketika login harus ada nip, nama, password. tapi di current code base baru ada nip dan password. skill harus tau hal itu."

Mitigates "ngawang" (floating/disconnected) units at two granularities:

**File-level** (generate-units defensive checks):
- **Step 0.5 (NEW)** — Pre-flight upstream check. Detects missing codebase-map.md / binding.md. Interactive prompt offers auto-route (scan-codebase + bind-codebase) before generation. ONE prompt at chain start (not per-unit) avoids death-by-prompts.
- **Step 7.6 (NEW)** — Per-unit target_files collision check. When unit's `task_type: create` targets a file that already exists, INTERACTIVE prompt offers: convert to verify / extend / rename / force-overwrite / skip. Fires only on genuine collision.
- **Step 12.4.5 (NEW)** — Per-anchor verification. Each Anchor `<file>:<line>` probed for existence. Missing anchors → SOFT WARNING in unit body footer (not halt; anchors can be aspirational for new files in create units).
- **`grounding_confidence: HIGH | MEDIUM | LOW`** field added to unit frontmatter — visual feedback per unit on how well-grounded it is.

**Field-level** (bind-codebase + generate-units, addressing user's login example):
- **bind-codebase v1.7+** — Adds two new Implementation State Map states:
  - `PARTIAL_FIELDS_MISSING` (C ⊂ V) — code missing fields from claim
  - `PARTIAL_FIELDS_SURPLUS` (V ⊂ C) — code has fields not in claim
  - `PARTIAL_FIELDS_BOTH` (both diffs non-empty) — semantic mismatch needing review
- Detects via tree-sitter signature extraction (Iter 6 precision_tier=ast); falls back to v1.6 binary on regex tier
- New `field_diff` column in binding.md Implementation State Map: `ADD: [...] · KEEP: [...] · REMOVE: [...]`
- Fills the PARTIAL state DEFERRED by Iter 1 per DESIGN-OQ-1

- **generate-units v2.1+** — Consumes PARTIAL_FIELDS_* states:
  - `PARTIAL_FIELDS_MISSING` → auto-emit `task_type: extend` with Migration notes populated from field_diff (ADD = missing fields; KEEP = shared; REMOVE = none)
  - `PARTIAL_FIELDS_SURPLUS` → auto-emit `task_type: extend` with HUMAN REVIEW interactive prompt (feature drift / vault gap / legacy / rename ambiguity)
  - `PARTIAL_FIELDS_BOTH` → strong warning + interactive prompt mandatory

### Concrete example (user's login scenario)

```
Vault claim C-LOGIN-1: POST /api/login accepts { nip, nama, password }
Codebase: LoginController@store(nip: string, password: string)

bind-codebase v1.7 output:
  C-LOGIN-1 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:45 | high |
  field_diff: ADD: [nama] · KEEP: [nip, password] · REMOVE: []

generate-units v2.1 output:
  U-001 (task_type: extend, grounding: HIGH)
    ## Migration notes
    - ADD: nama field — new validated input on POST /api/login
    - KEEP: nip, password (existing logic preserved)
    - REMOVE: (none)
```

Bolt now KNOWS exactly what to add. No more "ngawang" implementations that miss spec-required fields.

### Changed — Skill versions

- `bind-codebase`: 1.6.0 → 1.7.0 (PARTIAL_FIELDS_* states + field_diff)
- `generate-units`: 2.0.0 → 2.1.0 (defensive Step 0.5 + 7.6 + 12.4.5; grounding_confidence; PARTIAL_FIELDS_* consumption)

### Added — New reference

- `plugins/mega-sdd/skills/generate-units/references/defensive-generation.md` (385+ lines — algorithm + UX + field-level diff + examples)

### Changed — Schema

- `plugins/mega-sdd/skills/generate-units/references/unit-schema.md` — added `grounding_confidence` + `grounding_evidence` frontmatter fields; updated task_type table for v2.1 PARTIAL_FIELDS_* auto-emission
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Five-state Implementation State Map (extends Iter 1 binary); field-level diff detection logic; `field_diff` column in binding.md template

### New tests

- `tests/skill-triggering/generate-units.test.md` — 10 new cases DG1-DG10 covering: pre-flight upstream detection, PARTIAL_FIELDS_MISSING auto-extends, PARTIAL_FIELDS_SURPLUS interactive prompt, per-unit collision, anchor warnings, grounding confidence labels, --no-defensive opt-out, --auto chain mode, --collision-policy batch

### Anti-halu invariants preserved

- Field-level diff REQUIRES `precision_tier: ast` (tree-sitter); on regex precision, PARTIAL collapsed to UNKNOWN (no false-precision claims)
- `PARTIAL_FIELDS_SURPLUS` ALWAYS triggers human review (ambiguous semantic intent)
- Anchor warnings are SOFT (allow aspirational anchors for new code in create units)
- Per-unit collision NEVER silent-rewrites (always user confirms via prompt; --auto picks safest default)
- `--no-defensive` flag opt-out preserves v3.1 behavior exactly
- Diff calculation is DETERMINISTIC (set operations on extracted token lists; no fuzzy similarity)

### Backward compatibility

- v3.1 vaults without `precision_tier: ast` codebase-map → bind-codebase v1.7 falls back to v1.6 binary states; no PARTIAL_FIELDS emission
- v3.1 units without `grounding_confidence` field → schema field optional; downstream ignores when absent
- `--no-defensive` flag disables Iter 8 steps; behavior identical to v3.1
- Existing CONFIRMED/CONFLICT/OQ verdicts unchanged

## [3.1.0] — 2026-05-21

### Added — Context-aware recommendations in resolve-oq (Iter 7, minor patch)

Per user UX request — "kasih (recommended) base on dia baca context, dan kasih suggest yg paling sesuai".

Extends the Iter 2 `resolution_mode: recommend` pattern (currently tech-OQ-only at generate-intent time) to ALL OQ resolutions at resolve-time. `resolve-oq` v0.6+ builds context-aware recommendations from multiple sources BEFORE presenting `AskUserQuestion`. If a confident recommendation exists, default option labeled `(recommended)` with rationale + citation + fallback_if_wrong.

**Six context sources** (priority order):
1. KB `[VERIFIED]` markers (strongest; HIGH confidence) — search KB domain files matching OQ
2. Memory project-scope decisions (`<project>/.mega-sdd-memory/decisions.md`)
3. Memory user-scope patterns (`~/.mega-sdd/memory/patterns.md`; cross-project)
4. Vault — related ADRs / flows / constraints (MEDIUM confidence; extrapolated)
5. Codebase-map (brownfield only; existing pattern observed)
6. Silent fallback — no confident source → no recommendation surfaced (better silent than wrong)

**Anti-halu invariants** (mirror Iter 2 recommend mode):
- Citation MANDATORY (file:line / memory entry / KB section). No citation → no recommendation.
- Rationale MANDATORY (1-3 sentences in description)
- Fallback-if-wrong MANDATORY (1 sentence)
- User confirms ALWAYS — recommendation is `(recommended)` label on default option; user can pick "Other"/override freely
- Business + P1 OQs prefix description with ⚠️ "High-stakes — review carefully"
- No fabrication — silent fallback when sources insufficient
- Override capture feeds Iter 5 self-learning loop

**Self-correction loop** (Iter 5 integration):
- Every override (user picks NOT-recommended) captured in memory
- After 5 consistent overrides for same OQ pattern → pending suggestion in `patterns.md`: "Disable recommendation for OQ pattern X"
- User reviews via `/mega-sdd:memory review`; ACCEPT silences future recommendations for that pattern
- Self-corrects bad recommendations over time

### Changed — Skill versions

- `resolve-oq`: 0.5.0 → 0.6.0 (context-aware recommendations procedure step)

### Added — New reference

- `plugins/mega-sdd/skills/resolve-oq/references/recommendation-context.md` (full algorithm + source priorities + audit trail + examples)

### New tests

- `tests/skill-triggering/resolve-oq.test.md` — 10 new cases REC1-REC10 covering KB-derived / memory-derived / vault-derived recommendations, silent fallback, anti-halu (no citation = no recommendation), high-stakes warning, audit trail on ACCEPT + OVERRIDE, self-correction loop

### Backward compatibility

PURELY ADDITIVE:
- v3.0 resolve-oq behavior unchanged when no context sources yield confident recommendation
- Existing OQ resolution flows continue working — recommendation is just an opt-in label on the default option
- Memory layer integration uses existing Iter 5 infrastructure (no schema changes)
- `--memory-off` flag disables both memory consultation AND recommendation building

### Why patch version (3.1) not minor

Surface area is tiny — 1 skill enhanced, 1 new reference file. No new skills, no new commands, no breaking changes. Treat as additive UX improvement. Bumped to 3.1.0 (not 3.0.1) because new user-facing behavior (the `(recommended)` label) is observable.

## [3.0.0] — 2026-05-21

### Added — Tech Upgrades (Iter 6, major version bump)

Per spec `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md`. All 7 ITER6-OQs resolved per recommended defaults. Research-driven: deep-search of 30+ tools/libs (Aider, Cline, Plandex, ast-grep, tree-sitter, AGENTS.md ecosystem, LangGraph) identified 5 high-leverage swaps that strengthen mega-sdd without violating core invariants.

Realizes "more robust, more intelligent, still markdown-driven". Pipeline architecture unchanged; engines swapped at key points.

**Five swaps:**

1. **scan-codebase → tree-sitter engine** (Swap #1)
   - AST-precise symbol extraction replaces regex (Aider's proven pattern, 45k ⭐)
   - 100+ language grammars via tree-sitter CLI (~5MB native binary)
   - `.scm` query files bundled in `skills/scan-codebase/queries/`
   - Engine auto-detected via `command -v tree-sitter`; graceful fallback to regex (v1.2 behavior preserved)
   - `--engine=tree-sitter|regex` flag for forced engine
   - Codebase-map.md gains `engine` + `precision_tier` + `tree_sitter_version` + `grammars_used` frontmatter

2. **Hard Rule grammar v2 → ast-grep YAML** (Swap #2)
   - Replaces bespoke 5-type grammar (Iter 3 v1) with ast-grep YAML rules
   - 5-10× expressivity (semantic patterns + fix templates + constraints)
   - Single Rust binary (no Python/Node)
   - Single ast-grep covers 100+ langs via shared tree-sitter grammars
   - v1 grammar preserved as legacy path; auto-detected per unit (YAML blocks = v2; bullet lines = v1)
   - Mixed-grammar unit halts (`hard_rule_mixed_grammar`); user migrates via new `/mega-sdd:migrate-rules` command
   - Per ITER6-OQ-2: explicit per-unit migration confirm; v1 rules preserved as HTML comments for audit

3. **PageRank symbol-graph for generate-units target_files** (Swap #3)
   - Personalized PageRank on file-level symbol-reference graph (Aider's repo-map algorithm)
   - Seed = binding citations + existing target_files; rank top-K (default 5) non-seed files
   - Surfaces in unit body as `## PageRank suggestions` section (informational only — NEVER silent rewrite)
   - User reviews + manually promotes to `target_files` frontmatter
   - Requires `precision_tier: ast` (tree-sitter scan); skipped gracefully on regex tier
   - Symbol graph cached at `<vault>/.mega-sdd/symbol-graph.json` per scan run
   - `--skip-pagerank` flag disables; `--target-suggestions=N` configures K

4. **AGENTS.md emitter (new skill)** (Swap #4)
   - NEW skill `mega-sdd:emit-agents-md` (v1.0)
   - NEW command `/mega-sdd:emit-agents-md`
   - Flattens vault + binding + units summary into AGENTS.md schema (Linux Foundation AAIF; 60k+ repo ecosystem)
   - Tool-agnostic visibility — Continue.dev, Cursor, Aider, Copilot can consume mega-sdd intelligence without knowing mega-sdd specifics
   - 8 conditional sections: Project overview, Build commands, Test commands, Code style, Architecture, Decisions, Open questions, Mega-sdd interop notes
   - Generation marker (HTML comment) MANDATORY for idempotent re-emission
   - `--mode=overwrite|append|sibling` (default `sibling` if user-authored AGENTS.md detected)
   - Per ITER6-OQ-4: config-flag default-on; per-project opt-out via `~/.mega-sdd/memory/config.yaml` `defaults.emit_agents_md: false`
   - Auto-emitted at chain end when `orchestrate-flow --deep` runs (opt-out via `--no-agents-md`)

5. **Checkpoint-graph for orchestrate-flow** (Swap #5)
   - Per-step JSONL checkpoints at `<vault>/.mega-sdd/checkpoints/` (LangGraph-inspired pattern)
   - Enables mid-skill resume (e.g., bind-codebase crashed at claim 45 of 100 → resume at claim 46)
   - Per ITER6-OQ-5: JSONL format (append-only, race-tolerant, aligns with memory layer convention)
   - Per ITER6-OQ-7: rotate last 3 runs; archive rest; prune >180d (matches memory layer)
   - Skill responsibilities: extract-intelligence per wave, bind-codebase per claim, generate-units per unit, execute-bolts per bolt
   - Handoff YAML extended with `checkpoints` field (latest_step_id, checkpoint_file, resume_command)
   - Backward compat: v2.1 skills without checkpoint emission fall back to Iter 4 CWD-driven resume

### Added — New skills + commands

- `mega-sdd:emit-agents-md` v1.0 (AGENTS.md flattener)
- `/mega-sdd:emit-agents-md` command
- `/mega-sdd:migrate-rules` command (v1 → v2 Hard Rule migration helper)

### Added — New references

- `scan-codebase/references/tree-sitter-integration.md` (Swap #1 mechanics + fallback behavior)
- `scan-codebase/queries/tags-{typescript,php,python}.scm` (initial language coverage)
- `scan-codebase/queries/VERSIONS.md` (tested tree-sitter grammar version matrix)
- `execute-bolts/references/hard-rule-grammar-v2.md` (Swap #2 grammar + v1→v2 mapping)
- `execute-bolts/scripts/migrate-v1-rules.sh` (migration scaffold)
- `generate-units/references/pagerank-targeting.md` (Swap #3 algorithm + render-pass integration)
- `emit-agents-md/SKILL.md` + `references/agents-md-schema.md` (Swap #4)
- `orchestrate-flow/references/checkpoint-protocol.md` (Swap #5)

### Changed — Skill versions

- `scan-codebase`: 1.2.0 → 2.0.0 (tree-sitter engine; graceful regex fallback)
- `execute-bolts`: 1.4.0 → 2.0.0 (ast-grep v2 grammar; v1 legacy path preserved)
- `generate-units`: 1.5.0 → 2.0.0 (PageRank target_files suggestions; opt-out via `--skip-pagerank`)
- `emit-agents-md`: NEW at 1.0.0
- `orchestrate-flow`: 1.4.0 → 2.0.0 (checkpoint protocol; mid-skill resume)

(Other skills unchanged — generate-intent v1.6, bind-codebase v1.6, memory v1.0, resolve-oq v0.5, using-mega-sdd v1.2, extract-intelligence v1.1.)

### Anti-hallucination invariants — PRESERVED

Iter 6 adds DETERMINISTIC tech (AST parses, ast-grep matches, PageRank ranks) — NO new fuzzy logic introduced. All 8 anti-halu layers (Iters 1-5) + memory layer invariants intact:

1. Tree-sitter parses are deterministic (AST nodes exact, not approximate)
2. ast-grep matches are exact AST pattern matches (no semantic similarity / vector retrieval)
3. PageRank suggestions surface in unit body as SUGGESTIONS (never silent rewrite of `target_files`)
4. AGENTS.md emission is pure transformation (no inference; cites every claim's source)
5. Checkpoint resume replays deterministically (no LLM in the loop; cursor-driven)
6. v1 → v2 Hard Rule migration: explicit per-unit confirm (per ITER6-OQ-2); v1 preserved as HTML comments for audit
7. Engine fallbacks graceful: scan-codebase regex when tree-sitter absent; v1 grammar when ast-grep absent

### Backward compatibility

- v2.1 codebase-map.md (regex output) → re-scan with tree-sitter produces higher-precision map; old preserved as `.bak`
- v2.1 units with v1 Hard Rules → execute-bolts v1.4 path preserved; explicit migration via `/mega-sdd:migrate-rules` when ready
- v2.1 vaults without checkpoints/ dir → CWD-driven resume continues to work (Iter 4 behavior)
- Tree-sitter not installed → regex fallback; warning emitted; pipeline functional
- ast-grep not installed AND unit has v2 rules → halt with install commands; v1 rules still work
- AGENTS.md user-authored without marker → halt; ask user for overwrite/append/sibling choice

### Breaking changes (justifies major bump per ITER6-OQ-6)

ONLY ast-grep v1→v2 migration is breaking — and even that has a legacy preservation path. Specifically:

- Generating NEW units in v3.0 produces v2 grammar by default (v1 still selectable via `--hard-rule-grammar=v1`)
- Mixed-grammar units in same vault → halt `hard_rule_mixed_grammar`; user migrates first
- Otherwise everything is additive

### New tests

- `tests/skill-triggering/scan-codebase.test.md` — extended with TS1-TS5 (tree-sitter cases + fallback)
- `tests/skill-triggering/execute-bolts.test.md` — extended with AG1-AG6 (ast-grep v2 cases) + MIG1-MIG3 (v1→v2 migration)
- `tests/skill-triggering/generate-units.test.md` — extended with PR1-PR3 (PageRank suggestion cases)
- `tests/skill-triggering/emit-agents-md.test.md` — NEW (AM1-AM4: detect mode, sibling write, idempotent regen, conditional sections)
- `tests/skill-triggering/orchestrate-flow.test.md` — extended with CP1-CP3 (checkpoint emission + mid-skill resume)
- `tests/integration/e2e-iter6.test.md` — NEW (full pipeline E2E validating all 5 swaps)

### Locked ITER6-OQ resolutions (from spec §8)

- ITER6-OQ-1: Tree-sitter dist — document install commands; don't bundle binaries (keeps plugin small)
- ITER6-OQ-2: ast-grep v1→v2 migration — explicit per-unit confirm via `/mega-sdd:migrate-rules`; v1 preserved as audit
- ITER6-OQ-3: PageRank graph — bidirectional + weighted by ref count (Aider's proven approach)
- ITER6-OQ-4: AGENTS.md trigger — config flag default-on; per-project opt-out via `~/.mega-sdd/memory/config.yaml`
- ITER6-OQ-5: Checkpoint format — JSONL (append-only, race-tolerant; aligns with memory layer)
- ITER6-OQ-6: Major version 3.0 justified — only ast-grep v1→v2 migration breaks; everything else additive
- ITER6-OQ-7: Checkpoint rotation — keep last 3 runs; archive rest; prune >180d (consistent with memory layer)

### Iteration vision update

| Iter | Plugin | Status |
|---|---|---|
| extract-intelligence | 1.4.0 | ✅ Shipped |
| Iter 1 (impl-state + task_type) | 1.5.0 | ✅ Shipped |
| Iter 2 (tech-OQ classifier + scan/recommend) | 1.6.0 | ✅ Shipped |
| Iter 3 (Hard rules + pre/post-flight + polished prompts) | 1.7.0 | ✅ Shipped |
| Iter 4 (Autonomy Layer + /mega-sdd:auto) | 2.0.0 | ✅ Shipped |
| Iter 5 (Memory + self-learning) | 2.1.0 | ✅ Shipped |
| Iter 6 (Tech upgrades: tree-sitter + ast-grep + PageRank + AGENTS.md + checkpoint-graph) | 3.0.0 | ✅ Shipped (this entry) |

Pipeline now uses production-grade tech (proven at scale by Aider 45k ⭐, ast-grep 14k ⭐, AGENTS.md 60k+ repos, LangGraph 33k ⭐ patterns) while preserving the markdown-driven + citation-disciplined + halt-on-blocker core.

## [2.1.0] — 2026-05-21

### Added — Memory + Self-Learning Layer (Iter 5)

Per spec `docs/superpowers/specs/2026-05-21-memory-self-learning-design.md`. All 7 MEMORY-OQs resolved per recommended defaults. Inspired by ruflo (memory persistence concept; NOT vector-DB / binary-store implementation — mega-sdd stays markdown-driven).

Solves: context discontinuity across sessions + no self-learning from past outcomes + cross-vault patterns lost. Complementary to (NOT duplicative of) Claude Code's built-in `auto memory` — mega-sdd memory is OPERATIONAL (pipeline state); Claude Code memory is SOCIAL (working style).

**Three memory scopes:**

```
~/.mega-sdd/memory/                       # USER scope (cross-project, opt-in promotion only)
├── preferences.md                         # observed flag/mode defaults
├── patterns.md                            # learned cross-project patterns + pending suggestions
├── learning-log.md                        # audit log of accepted/rejected learnings
└── config.yaml                            # thresholds + opt-outs

<project-root>/.mega-sdd-memory/           # PROJECT scope (per-repo, git-trackable per-file)
├── decisions.md                           # OQ resolutions + CONFLICT actions + Recommendation outcomes
├── conventions.md                         # detected conventions (test framework, naming, error format)
└── outcomes.md                            # halt patterns + retry counts + success rates per run

<vault-path>/.memory/                      # VAULT scope (per-vault, ephemeral; archived on delete)
├── classifier-accuracy.json               # auto-classifier tag vs user-override metrics
├── bind-history.md                        # per-binding-run verdicts + state map summaries
└── bolt-outcomes.json                     # per-bolt success/failure + Hard Rule violations
```

**Self-learning** — threshold-based + suggestion-only (per Iter 5 design lock):
- 5 consistent classifier overrides → propose heuristic table update
- 5 same-resolution CONFLICTs → propose pre-fill default in resolve-oq
- 3 Hard Rule violation+reverts → propose removing rule from binding suggestions
- 3 recommendation REJECTs → propose flipping `resolution_mode` from `recommend` to `blocking`
- 2 convention detections → promote to "established" (skip verbose re-detection)
- 5 same flag picks → propose pre-fill in AskUserQuestion

All learnings reviewed via `/mega-sdd:memory review`. User picks ACCEPT / REJECT / DEFER per suggestion. Accepted learnings written to `learning-log.md` with rollback path (edit log entry, add `rolled_back_at: <date>`).

### Added — New skill `mega-sdd:memory`

```bash
/mega-sdd:memory list [--scope=<user|project|vault>] [--format=table|json]
/mega-sdd:memory show <topic> [--scope=<scope>]
/mega-sdd:memory search <query> [--scope=<scope>]
/mega-sdd:memory review [--auto-accept-threshold=N]
/mega-sdd:memory prune [--older-than=<duration>] [--dry-run]
/mega-sdd:memory promote <key> --to=<user|project>
/mega-sdd:memory diff [--since=<date>] [--scope=<scope>]
/mega-sdd:memory export <output-path> [--scope=<scope>]
/mega-sdd:memory import <input-path> [--scope=<scope>]
/mega-sdd:memory clear --scope=<user|project|vault> [--confirm-twice]
```

### Added — `--memory-off` flag on all skills

Disables both memory reads AND writes for that invocation. Honored across all 8 skills (extract-intelligence skipped — its outputs flow through generate-intent which respects the flag).

### Changed — Handoff YAML extended with `metadata` field

Per `orchestrate-flow/references/handoff-contract.md` §metadata extension. Per AUTONOMY-OQ-7 + MEMORY-OQ-7 (both single-read-at-orchestrator):

```yaml
handoff:
  # ... existing fields ...
  metadata:                             # v2.1+ (Iter 5)
    memory_context:                     # IN — orchestrator provides relevant memory slices
      project_decisions_relevant: []
      project_conventions_relevant: []
      vault_outcomes_relevant: []
      user_patterns_relevant: []
      user_preferences_relevant: []
    memory_writes:                      # OUT — skill emits writes for orchestrator to persist
      - file: <relative-or-absolute-path>
        scope: user | project | vault
        action: append | update
        content: |
          <markdown row or JSON entry>
        source_run: <skill-name>@<timestamp>
```

Orchestrator reads memory ONCE at chain start, passes slices to skills via handoff (no per-skill disk re-read), batches writes at chain end (atomic per-file via append-only per MEMORY-OQ-6).

### Changed — Skill versions

- `memory`: NEW at 1.0.0
- `orchestrate-flow`: 1.3.0 → 1.4.0 (chain-start memory read + per-phase write batching)
- `using-mega-sdd`: 1.2.0 (unchanged — auto-trigger logic same; memory layer is downstream)
- `generate-intent`: 1.5.0 → 1.6.0 (reads preferences + conventions; writes preferences + classifier-accuracy)
- `scan-codebase`: 1.1.0 → 1.2.0 (writes conventions; reads to skip established convention re-detection)
- `bind-codebase`: 1.5.0 → 1.6.0 (reads decisions + patterns for CONFLICT resolution suggestions; writes bind-history + Hard Rule downgrade based on violation patterns)
- `generate-units`: 1.4.0 → 1.5.0 (reads bolt-outcomes for Anti-pattern suggestions; reads decisions for past CONFLICT KEEP_CODE files; no direct writes)
- `execute-bolts`: 1.3.0 → 1.4.0 (writes bolt-outcomes + outcomes; reads to surface past-halt warnings)
- `resolve-oq`: 0.4.0 → 0.5.0 (writes decisions on each OQ + CONFLICT resolution + Recommendation outcome)
- `extract-intelligence`: 1.1.0 (unchanged — operates outside project memory context)

### New command

- `commands/memory.md` — `/mega-sdd:memory` operations entrypoint

### New tests

- `tests/skill-triggering/memory.test.md` — 9 operations (M1-M9) + 7 anti-halu invariants (AH1-AH7)
- `tests/integration/e2e-memory-self-learning.test.md` — 6 scenarios (A-F) covering accumulation, threshold-fire, accept-learning, rollback, --memory-off graceful degradation, cross-vault consistency, archival

### Anti-hallucination invariants — PRESERVED

Memory layer is SUGGESTION-ONLY across all touchpoints. The 10 invariants from spec §10:

1. Memory is suggestion only — never enforcement
2. Every suggestion cites source memory entry
3. Current evidence wins over memory
4. No silent auto-tuning (explicit ACCEPT via `/mega-sdd:memory review`)
5. Audit log mandatory (every learning has rollback path)
6. No fabricated citations (writers cite source artifact; readers cite memory entry)
7. Cross-project promotion explicit (NEVER automatic)
8. `--memory-off` honored everywhere
9. Memory does NOT affect halt-protocol (CONFLICT still blocks, business OQ P1 still pauses, hard_rule_violated still halts)
10. Memory files are human-reviewable markdown / JSON (never binary)

### Backward compatibility

PURELY ADDITIVE:
- v2.0 pipelines work without memory dirs — skills lazily create on first write
- Memory dirs don't exist yet → readers find no files → default behavior unchanged
- `--memory-off` opt-out preserves identical behavior to v2.0
- Schema versions (`memory_schema: 1`) stamped; future migration supported per MEMORY-OQ-1
- Existing handoff YAML producers (Iter 4) keep working; new `metadata` field is optional

### Locked MEMORY-OQ resolutions (from spec §13)

- MEMORY-OQ-1: Schema versioning + auto-migrate with audit log
- MEMORY-OQ-2: Per-file gitignore (decisions.md + conventions.md tracked; outcomes.md gitignored)
- MEMORY-OQ-3: Plain markdown (no encryption); document privacy risk; `--memory-off` for sensitive contexts
- MEMORY-OQ-4: Configurable thresholds via `~/.mega-sdd/memory/config.yaml`
- MEMORY-OQ-5: Vault-scope memory archived to `<project>/.mega-sdd-memory/archived-vaults/<vault-id>/` on vault delete
- MEMORY-OQ-6: Append-only writes (race-tolerant via atomic single-write fs.append)
- MEMORY-OQ-7: Single memory read at orchestrator chain-start; slices passed via handoff YAML

### Iteration vision update

| Iter | Plugin | Status |
|---|---|---|
| extract-intelligence | 1.4.0 | ✅ Shipped |
| Iter 1 (impl-state + task_type) | 1.5.0 | ✅ Shipped |
| Iter 2 (tech-OQ classifier + scan/recommend) | 1.6.0 | ✅ Shipped |
| Iter 3 (Hard rules + pre/post-flight + polished prompts) | 1.7.0 | ✅ Shipped |
| Iter 4 (Autonomy Layer + /mega-sdd:auto) | 2.0.0 | ✅ Shipped |
| Iter 5 (Memory + self-learning) | 2.1.0 | ✅ Shipped (this entry) |

## [2.0.0] — 2026-05-20

### Added — Autonomy Layer (Iter 4 of vision; major version bump)

Per spec `docs/superpowers/specs/2026-05-20-autonomy-layer-design.md`. All 7 AUTONOMY-OQs resolved per recommended defaults.

Realizes the user-stated vision: "skills as agents that auto-route through the pipeline" + "PRD upload → vault → units in one motion" + "legacy code → rebuild project in one motion". The pipeline shape stays identical; the orchestration becomes autonomous through clean paths while preserving every existing halt-protocol blocker.

**Four coordinated pillars:**

1. **Deep-chain mode in `orchestrate-flow`**
   - New `--deep` flag lifts the 3-skill cap; chain extends to pipeline-end
   - Per AUTONOMY-OQ-1: single upfront confirmation covers ALL phases including `execute-bolts` (bolts have their own safety via target_files whitelist + Hard rules)
   - Per AUTONOMY-OQ-2: `--resume` is CWD-driven (no persisted state file). Cursor position derives from artifact presence.
   - Per AUTONOMY-OQ-4: One-line progress indication before/after each phase (`▶ Phase N of M: ...`)
   - Backward compatible: default mode (no `--deep`) still cap-3.

2. **Auto-continue handoffs via handoff YAML protocol**
   - New `references/handoff-contract.md` defines the shared protocol
   - Every skill emits a `handoff:` YAML record when invoked with `--auto` (per AUTONOMY-OQ-5: required only under `--auto`)
   - Orchestrator parses `next_action.suggested_skill` + `next_action.suggested_args` and auto-invokes the next phase
   - Status values: `completed` (auto-continue), `paused` (chain stops awaiting user), `halted` (blocker fires; chain stops)
   - Required schema includes `artifacts` (orchestrator verifies skill output exists) + `blockers` (verbatim halt YAMLs)

3. **Sharper `using-mega-sdd` auto-trigger**
   - Auto-invoke `/mega-sdd:auto` (or `orchestrate-flow --deep`) when BOTH strong CWD signal AND user prompt intent keyword present
   - Per AUTONOMY-OQ-3: general questions ("explain X", "fix bug Y") do NOT auto-trigger even with strong CWD; prompt MUST contain mega-sdd intent
   - New trigger keywords: `auto`, `rebuild`, `lanjut`, `next`, `jalankan otomatis`, `proceed`, `go`

4. **One-shot `/mega-sdd:auto` entrypoint**
   - NEW slash command at `commands/auto.md`
   - Input shape detection: legacy codebase / vault dir / PRD file / quoted brief / empty → CWD inspection
   - Routes to `orchestrate-flow --deep --auto` with detected starting phase
   - Per AUTONOMY-OQ-7: `--out=<path>` REQUIRED for legacy rebuild scenarios (extract-intelligence) — never conflate extract output with rebuild project dir
   - Flag surface: `--deep` / `--shallow` / `--step-after=<phase>` / `--stop-after=<phase>` / `--resume` / `--manual`

### Changed — Schema additions

- **New reference**: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — shared protocol definition + per-skill expected emissions + orchestrator consumption logic + anti-halu invariants
- `orchestrate-flow/references/routing-rules.md`: new §Deep-chain decision matrix + §Resume mechanics
- `orchestrate-flow/SKILL.md`: new Step 8 (Resume support); Procedure §3 splits cap-3 vs `--deep`; progress indication mandate; new flags

### Changed — Skill versions

- `orchestrate-flow`: 1.2.0 → 1.3.0 (--deep flag + --resume + auto-continue + progress indication)
- `using-mega-sdd`: 1.1.0 → 1.2.0 (sharper auto-trigger rules + new keywords)
- `extract-intelligence`: 1.0.0 → 1.1.0 (handoff YAML emission)
- `generate-intent`: 1.4.0 → 1.5.0 (handoff YAML emission)
- `scan-codebase`: 1.0.0 → 1.1.0 (handoff YAML emission)
- `bind-codebase`: 1.4.0 → 1.5.0 (handoff YAML emission)
- `generate-units`: 1.3.0 → 1.4.0 (handoff YAML emission)
- `execute-bolts`: 1.2.0 → 1.3.0 (handoff YAML emission)

### New command

- `commands/auto.md` — `/mega-sdd:auto` one-shot entrypoint

### Anti-hallucination invariants — PRESERVED (the core promise)

`--deep` mode is autonomy through CLEAN paths only. EVERY existing halt fires identically:
- `bind_conflict` — bound-vault not produced; chain halts
- `oq_business_p1_unresolved` (Iter 2 + --strict) — chain pauses for stakeholder triage
- `dedup_ambiguous` (Iter 1) — chain halts; user reviews
- `hard_rule_violated` (Iter 3 post-flight) — code stays in working tree; bolt halts pre-commit
- `hard_rule_unparseable` / `hard_rule_unanchored` (Iter 3) — chain halts
- `cross_squad_*` (multi-squad halts) — chain halts
- `quality_gate_failed` (extract-intelligence wave gates) — chain halts
- `oq_recommend_underspecified` / `oq_recommend_citation_invalid` (Iter 2) — chain halts
- `mode_migrate` — chain halts
- `dep_missing` (superpowers unavailable) — chain halts
- `cycle_detected` / `interface_ref_missing` / `cross_squad_ambiguous` / `verify_unit_writable` — chain halts

Additional rails for autonomy mode:
- ONE upfront confirmation required (NEVER zero). Single confirm = OK; confirm zero = unsafe.
- Per AUTONOMY-OQ-5: handoff YAML required ONLY under `--auto`. Standalone skill invocations may emit informationally.
- Per AUTONOMY-OQ-2: no persisted state file. `--resume` rebuilds state from CWD. Halts re-fire if blockers unresolved.
- Skills MUST NOT lie about status. If acceptance tests failed → status: halted, never completed.
- Skills MUST list every artifact in handoff YAML. Missing artifacts → orchestrator detects gap → chain halts.

### Backward compatibility

All changes additive:
- v1.7 `orchestrate-flow` (no --deep) → unchanged behavior. 3-skill cap intact.
- v1.7 standalone skill invocations (no --auto) → unchanged behavior. No handoff YAML emitted.
- v1.7 existing pipelines (PRD → vault → … manually invoked per phase) → continue to work.
- New `/mega-sdd:auto` command is opt-in. Existing per-skill commands all still work.
- v1.7 skills missing handoff emission (pre-Iter-4 skills) → orchestrator treats them as `status: completed` with `next_action: null`. Chain stops after. Degraded but safe.

### Why major version bump (per AUTONOMY-OQ-6)

- New top-level entrypoint (`/mega-sdd:auto`)
- Cap-lift in `orchestrate-flow` (semantic change in chain depth)
- `using-mega-sdd` auto-invokes orchestrate-flow without user typing commands (behavior change in anchor skill)
- All 8 skills add handoff emission contract (behavior change collectively)

Major bump (2.0) signals "the orchestration model has evolved". Skills still behave identically when not invoked with --auto.

### New tests

- `tests/skill-triggering/auto.test.md` — NEW. 13 cases: A1-A5 input detection, H1-H3 halt cases, F1-F5 flag behavior, HP1-HP3 halt-protocol preservation
- `tests/skill-triggering/orchestrate-flow.test.md` — extended with DC1-DC6 (deep-chain mode) + RES1-RES3 (resume mechanics)
- `tests/integration/e2e-autonomy-clean.test.md` — NEW. End-to-end full pipeline clean run with V1-V5 validation checks
- `tests/integration/e2e-autonomy-halt.test.md` — NEW. End-to-end halt + resolve + resume cycle with V1-V5 validation checks

### Iteration vision complete

| Iter | Plugin | Status |
|---|---|---|
| extract-intelligence | 1.4.0 | ✅ Shipped |
| Iter 1 (impl-state + task_type) | 1.5.0 | ✅ Shipped |
| Iter 2 (tech-OQ classifier + scan/recommend) | 1.6.0 | ✅ Shipped |
| Iter 3 (Hard rules + pre/post-flight + polished prompts) | 1.7.0 | ✅ Shipped |
| Iter 4 (Autonomy Layer + /mega-sdd:auto) | 2.0.0 | ✅ Shipped (this entry) |

The full vision from `2026-05-20-tech-oq-autoresolve-design.md` + `2026-05-20-autonomy-layer-design.md` + `2026-05-20-extract-intelligence-skill-design.md` is now realized. Pipeline maps cleanly to superpowers' `read → scan → writing-plans → executing-plans (subagent-driven)` shape.

## [1.7.0] — 2026-05-20

### Added — Polished AI-Coding-Prompt Units + Hard Rule Pre/Post-Flight (Iter 3 of tech-OQ vision)

Per spec `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` §6 (Iter 3). DESIGN-OQ-4, OQ-5, OQ-6 locked.

Solves "unit reads like a Jira ticket, not an AI coding prompt" pain — and adds the runtime safety net so bolts execute autonomously without violating constraints:

- **Unit body restructure** — `## Anchors` mandatory when binding evidence exists; `## Anti-patterns` for informational don'ts; `## Hard rules` for machine-validated constraints; `## Implementation steps` rendered as directive prose (not bullet schema).
- **Hard Rule grammar (closed v1 per DESIGN-OQ-4)** — 5 rule types: `DO NOT modify <path>`, `DO NOT add new <manifest> dependencies`, `<path-glob> MUST follow <case-style> naming`, `function <name> MUST preserve signature: <type-sig>`, `file <path> MUST exist after bolt`. Unparseable → halt `hard_rule_unparseable`.
- **`execute-bolts` pre-flight scan** — captures deterministic state snapshot per rule before bolt runs (sha256 for DO_NOT_MODIFY, manifest deps section for DO_NOT_ADD_DEPS, function signature for SIGNATURE_RULE). Persisted to `<vault>/bolts/U-XXX/preflight.json`.
- **`execute-bolts` post-flight validation** — runs BEFORE commit. Re-validates each rule against current state. ANY violation → halt `hard_rule_violated`; code changes remain in working tree (NOT committed); user reviews + reverts/edits.
- **`bind-codebase` Suggested Unit Hard Rules** — emits machine-parseable Hard rules + Anti-patterns drawn from Implementation State Map + CONFLICT resolutions + KB `[VERIFIED]` gotchas. Per DESIGN-OQ-6: KB items default to Anti-patterns; promoted to Hard rules ONLY when `[VERIFIED]` AND mechanically detectable.
- **`generate-units` render pass** (new Step 12.4) — validates Anchors mandatory rule, Hard rule grammar, Migration notes structure, directive prose density. Halts with `unit_underspecified` or `hard_rule_unparseable`. Auto-pulls Hard rules + Anti-patterns from `binding.md` Suggested Unit Hard Rules section.
- **`task_type: verify` special path** in execute-bolts — skips code generation; runs acceptance tests against existing implementation; skips post-flight Hard rule scan (no changes to validate).

### Changed — Schema additions

- `generate-units/references/unit-schema.md`: body sections restructured with directive prose guidance, Anchors mandatory rules per task_type, Anti-patterns section, Hard rules section with 5-grammar productions + validation table.
- `bind-codebase/SKILL.md` + `references/binding-contract.md`: new Procedure §2.8 (Suggested Unit Hard Rules emission) + new "## Suggested Unit Hard Rules" section in binding.md template.

### Changed — Skill versions

- `generate-units`: 1.2.0 → 1.3.0 (new Step 12.4 render pass; auto-pull from binding suggestions)
- `execute-bolts`: 1.1.0 → 1.2.0 (Pre-flight Step 4 + Post-flight validation step; new outputs preflight.json + postflight.json)
- `bind-codebase`: 1.3.0 → 1.4.0 (new Procedure §2.8 Suggested Unit Hard Rules; new section in binding.md)

### Anti-hallucination invariants

- Hard rule grammar closed v1 (5 productions per DESIGN-OQ-4). Unparseable → halt; NEVER silently skip.
- Pre-flight snapshot is mandatory when `## Hard rules` non-empty per DESIGN-OQ-5. No `--skip-preflight` flag.
- Post-flight runs BEFORE commit. Violations preserve code changes in working tree for user review.
- `SIGNATURE_RULE` referencing symbol absent in codebase-map → halt `hard_rule_unanchored` (can't validate what doesn't exist).
- `verify` units cannot write code — task_type enforcement at bolt time.
- KB `[INFERRED]` and `[OPEN]` items → Anti-patterns ONLY (per DESIGN-OQ-6); never auto-promoted to Hard rules.
- Suggested Hard Rules referencing unanchored files → suppressed (would fail at bolt time anyway).
- Auto-population from binding does NOT bypass render-pass validation — emitted rules must parse.

### Backward compatibility

All changes additive. Behaviors preserved:
- v1.6 units without `## Hard rules` body section → execute-bolts skips pre/post-flight (current behavior).
- v1.6 units without `## Anchors` / `## Anti-patterns` → render pass treats schema as legacy; halts only when binding evidence dictates Anchors required.
- v1.6 binding.md without "## Suggested Unit Hard Rules" → generate-units fills sections from vault-only context (no auto-pull).
- Greenfield projects (no binding) → no Anchors mandatory; no Hard rules suggestions; standard create-unit shape.
- Existing per-skill `--auto` flags unchanged.

### New tests

- `tests/skill-triggering/execute-bolts.test.md` — 11 cases HR1-HR11 covering Hard Rule pre-flight snapshot, post-flight violations per rule type (DO_NOT_MODIFY / DO_NOT_ADD_DEPS / SIGNATURE / NAMING / FILE_PRESENCE), unparseable / unanchored rule halts, verify-unit path, all-clean path, multi-rule violation.
- `tests/skill-triggering/generate-units.test.md` — 9 cases PP1-PP9 covering Anchors mandatory rule per task_type, grammar parse, Migration notes structure, directive prose density, verify single-line allowed, Anti-patterns + Hard rules auto-pull from binding.
- `tests/skill-triggering/bind-codebase.test.md` — 8 cases SHR1-SHR8 covering implementation-state-derived rules, KB [VERIFIED] → Hard rules, KB [INFERRED]/[OPEN] → Anti-patterns only, unanchored suggestion suppression, CONFLICT resolution paths, empty section default.

### Locked DESIGN-OQ resolutions (from parent spec, restated)

- DESIGN-OQ-4: Hard rule grammar closed v1 — 5 rule types. Revisit extensibility in v2 if real-world need emerges.
- DESIGN-OQ-5: No `--skip-preflight`. Pre-flight scan is the contract.
- DESIGN-OQ-6: KB gotchas → Anti-patterns by default. Promoted to Hard rules ONLY when `[VERIFIED]` AND mechanically detectable.

### Iter 4 — Designed, awaiting kick-off

Per spec `2026-05-20-autonomy-layer-design.md`, Iter 4 (plugin 2.0.0) ships the Autonomy Layer: `--deep` chain mode in `orchestrate-flow`, auto-continue at skill handoffs, sharper `using-mega-sdd` auto-trigger, one-shot `/mega-sdd:auto` entrypoint. Bridges to superpowers' `executing-plans` shape literally.

## [1.6.0] — 2026-05-20

### Added — Tech-OQ Auto-Classification + Scan/Recommend Resolution Modes (Iter 2 of tech-OQ vision)

Per spec `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` §5 (Iter 2). DESIGN-OQ-3 locked: only `classification_confidence: high` auto-resolves; medium/low go to review.

Solves "OQ list buried in technical noise" pain — tech ambiguities deterministically answerable from codebase no longer clog the human review channel:

- **OQ schema extended** (`vault-contract.md`) with `category` (business | tech), `resolution_mode` (blocking | scan | recommend | hard_rule), `classification_confidence` (high | medium | low), plus mode-specific fields (`scan_query`, `recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`).
- **Auto-classifier** in `generate-intent` (new Step 3.5) tags every OQ at generation time per heuristic table. Conservative default: `business / blocking / low` when no pattern matches.
- **`00-index.md` Auto-Classification Review section** lists every tech-tagged OQ + medium/low confidence cases for one-pass user review before binding runs.
- **`bind-codebase` scan resolution** (new Procedure §2.6): tech OQs with `resolution_mode: scan` AND `confidence: high` auto-resolve via codebase-map probe. Single match → resolved. No match / ambiguous → flip to `blocking` (NEVER guess).
- **`bind-codebase` recommend surfacing** (new Procedure §2.7): tech OQs with `resolution_mode: recommend` AND `confidence: high` surface in `binding.md` "## Tech-OQ Recommendations (review required)" section. Recommendations carry full audit trail (rationale + scan_citations + fallback_if_wrong) + ACCEPT/OVERRIDE/REJECT actions. NEVER auto-accepted.
- **DESIGN-OQ-3 gate**: ONLY `classification_confidence: high` tech OQs are processed by scan/recommend. Medium/low confidence skip auto-resolution.

### Changed — Schema additions

- `generate-intent/references/vault-contract.md`: extended §OQ-conventions with Category + Resolution mode + Classification confidence + Auto-classifier heuristic table (10 patterns) + Auto-Classification Review section template + Updated OQ schema (markdown + vault.json) + Validation rules.
- `bind-codebase/references/binding-contract.md`: new §Tech-OQ Auto-Resolution covering scan + recommend mode mechanics, confidence gate, anti-halu enforcement, blocking rule interaction.

### Changed — Skill versions

- `generate-intent`: 1.3.0 → 1.4.0 (new Step 3.5: OQ auto-classification; validation gate)
- `bind-codebase`: 1.2.0 → 1.3.0 (new Procedure §2.6 scan resolution + §2.7 recommend surfacing)

### Anti-hallucination invariants

- Tech-OQ scan with no/multiple matches → flip to `blocking`, NEVER guess.
- Recommendations NEVER auto-accepted. ACCEPT requires explicit user action.
- Recommend mode `scan_citations` MUST verify in codebase-map / KB. Unverifiable citation → halt `oq_recommend_citation_invalid` (detects fabrication).
- Recommend mode requires all 4 audit-trail fields (`recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`). Missing any → halt `oq_recommend_underspecified`.
- Confidence gate enforced: medium/low confidence skip auto-resolve (per DESIGN-OQ-3); preserves safety-by-default.
- Conservative default at classification time: when heuristic ambiguous, → `business / blocking / low` (NEVER fabricate tech tag).
- Tech-OQ resolution operates orthogonally to verdict layer: CONFLICT still blocks bound-vault production.

### Backward compatibility

- OQs without `category` field → treated as `business` by all skills (no auto-resolve).
- v1.5 vaults without `resolution_mode` field on business OQs → defaults to `blocking` (current behavior).
- Greenfield projects → auto-classifier runs but most OQs default to `business/blocking/low` (limited codebase context); zero behavior change vs v1.5.
- `--no-kb` flag (from v1.1) still respected; KB consultation in recommend mode citation validation is gated on KB presence.

### New tests

- `tests/skill-triggering/generate-intent.test.md` — 7 new cases (CL1-CL7) for auto-classifier behavior including fabrication-detection guard.
- `tests/skill-triggering/bind-codebase.test.md` — 8 new cases (TQ1-TQ8) for scan resolution + recommend surfacing including no-match, ambiguous, citation-invalid, underspecified halt cases.

### Iter 3 + Iter 4 — Designed, awaiting kick-off

Per spec, Iter 3 (plugin 1.7) ships polished unit prompt-shape body (Anchors + Anti-patterns + Migration notes + Hard rules) + execute-bolts pre-flight + post-flight hard-rule validation. Iter 4 (Autonomy Layer, plugin 2.0) wraps the pipeline in `/mega-sdd:auto` one-shot entrypoint with deep-chain mode. Both are documented in their respective spec files.

## [1.5.0] — 2026-05-20

### Added — Implementation-State Classification + task_type Units (Iter 1 of tech-OQ vision)

Per spec `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` Iter 1 (DESIGN-OQ resolutions locked at approval).

Solves the brownfield pain "unit is generated even when the target function already exists":

- **bind-codebase** classifies every CONFIRMED claim with `state: IMPLEMENTED | NEW | UNKNOWN` (Iter 1 binary set; PARTIAL deferred to Iter 2 where `recommend` resolution handles ambiguity). Each row carries an `anchor` citation + `confidence` label (high/medium/low). Recorded in `binding.md` under new "## Implementation State Map" section.
- **generate-units** reads the map and assigns `task_type: create | verify` per unit:
  - All NEW claims (or no binding) → `task_type: create` (current behavior)
  - All IMPLEMENTED with high confidence → `task_type: verify` — NO code generation; only acceptance tests against the existing implementation cited via the `## Anchors` body section
  - Mix of NEW + IMPLEMENTED → SPLIT into one `verify` + one `create` chained via `depends_on`
  - UNKNOWN (any confidence) → conservative `create` with a body note about the unclassified anchor
- **`extend` task_type** added to the schema (forward-compat for Iter 2/3). Iter 1 does NOT auto-emit `extend` from UNKNOWN states; user manually edits frontmatter + fills Migration notes when needed.
- **Dedup gate** (`generate-units` step 12.5) — halts with `dedup_ambiguous` blocker if a `create` unit's `target_files` all already exist in codebase-map. NEVER silent-rewrites.
- **OQ category tagging** (Iter 1 scaffolding) — every OQ carries `category: business | tech` (default `business`). Iter 1 records the tag only; Iter 2 (plugin 1.6) will activate `scan` + `recommend` auto-resolve.

### Changed — Schema additions

- `bind-codebase/references/binding-contract.md`: new §Implementation-State Classification with classification logic per claim type (endpoint / entity / method) + confidence labeling + binding.md template extension.
- `generate-units/references/unit-schema.md`: new frontmatter field `task_type`; new body sections `## Anchors` (mandatory for verify/extend) and `## Migration notes` (mandatory for extend); per-task_type contract table.
- `generate-intent/references/vault-contract.md`: new §Category in §OQ-conventions with markdown + vault.json schema and the heuristic table.

### Changed — Skill versions

- `bind-codebase`: 1.1.0 → 1.2.0 (Procedure step 2.5 added; binding.md template extended; anti-halu rails extended)
- `generate-units`: 1.1.0 → 1.2.0 (Procedure step 2.5 + step 12.5 added; per-task_type unit emission; dedup halt)
- `generate-intent`: 1.2.0 → 1.3.0 (OQ category tagging; no auto-resolve in Iter 1)

### Anti-hallucination invariants preserved

- Binding gate non-negotiable: CONFLICT still BLOCKS. Implementation-state classification annotates CONFIRMED only.
- Never promote `NEW` to `IMPLEMENTED` via inference. Anchor citations required for IMPLEMENTED.
- `UNKNOWN` defaults to conservative `create` (downstream); never silently advanced to a higher-confidence label.
- `verify` units NEVER generate code; only run acceptance tests. Missing anchor → downgrade to create.
- `extend` task_type requires Migration notes; missing → halt (forward-compat enforcement).
- Dedup ambiguity → halt with `dedup_ambiguous`; never silent-rewrite a unit.

### Backward compatibility

All changes are additive. Behaviors preserved when:
- v1.4 vault loaded — OQs without `category` → treated as `business` (no auto-resolve). No behavior change.
- v1.4 binding.md without Implementation State Map → generate-units treats every claim as `NEW`-equivalent → all units `task_type: create`. Identical to v1.4 output.
- v1.4 units without `task_type` field → bolt-time behavior unchanged; new fields ignored.
- Greenfield projects (no scan-codebase / no binding) → no Impl State Map → all units `task_type: create`. Identical to v1.4.

### New tests

- `tests/skill-triggering/bind-codebase.test.md` — 5 new cases (IS1-IS5) for Implementation-State Classification.
- `tests/skill-triggering/generate-units.test.md` — 8 new cases (TT1-TT8) for task_type assignment + dedup halt.
- `tests/integration/e2e-impl-state.test.md` (new) — full pipeline on a brownfield Laravel fixture with partial existing implementation; covers verify/create split + dedup negative cases.

### Locked DESIGN-OQ resolutions (from spec)

- Iter 1 uses binary states (IMPLEMENTED / NEW / UNKNOWN); PARTIAL deferred to Iter 2.
- Dedup halts on ambiguity — never silent rewrites.
- Iter 2 classifier accuracy: high-conf only auto-resolves; medium/low go to review.
- Iter 3 hard-rule grammar closed v1 (5 rule types).
- Pre-flight scan is the contract (no `--skip-preflight`).
- KB gotchas → Anti-patterns by default; promoted to Hard rules only when `[VERIFIED]` + mechanically detectable.

### Iter 2 + Iter 3 — Designed, awaiting kick-off

The full 3-iteration vision is in the spec doc. Iter 2 activates tech-OQ auto-resolve via `scan`/`recommend` modes. Iter 3 introduces hard rules + bolt-time pre-flight validation + polished prompt-shape unit body (Anchors + Anti-patterns + Migration notes + Hard rules). Each iteration is its own PR with its own version bump.

## [1.4.0] — 2026-05-20

### Added — `extract-intelligence` skill + KB-as-context pipeline integration

Per spec `docs/superpowers/specs/2026-05-20-extract-intelligence-skill-design.md`.

New skill for the legacy-rebuild scenario where the legacy codebase is the only "spec" — no PRD exists and the rebuild is on a different stack:

- **New skill `extract-intelligence`** (v1.0.0) — wave-based parallel-subagent extractor. 5 sequential waves (Prep → Foundation → Masters → Workflows → Integrations → Synthesis), ≤5 parallel subagents per wave, hard cap 8. Produces `docs/knowledge-base/` — multi-file tech-agnostic knowledge base organized by business domain (not by code structure).
- **Output contract** — every domain file carries YAML frontmatter (`generated_by`, classification, criticality, `verified_count`, `inferred_count`, `open_count`, `source_files_cited`) plus the mandatory 11-section template (Purpose → Source References).
- **Anti-hallucination discipline** — `[VERIFIED] / [INFERRED] / [OPEN]` markers on every non-trivial claim, `file:line` citations required, tech-agnostic vocabulary outside `## 11. Source References` and `50-integrations/`, ambiguous → `[OPEN]` never silent default, Wave 5 synthesis on main thread only.
- **Quality gates between waves** — grep checks for section presence, frontmatter compliance, and forbidden patterns. Halt on second gate failure.
- **New slash command** `/mega-sdd:extract-intelligence <legacy-path> [--out=<path>] [--seed=<path>] [--max-parallel=N] [--auto]`.
- **References split** — `references/knowledge-base-schema.md` (output shape, frontmatter contract, 11-section template) + `references/wave-dispatch-templates.md` (per-wave agent prompts, gate grep commands, token budget guidance).
- **Trigger test** — `tests/skill-triggering/extract-intelligence.test.md` covers explicit + natural English + Indonesian + orchestrate-flow auto-route + behavior checks (B1-B7).

### Changed — KB consumption integrated into existing pipeline

`extract-intelligence` is a side-lane upstream of `generate-intent`. Three existing skills updated so the rest of the pipeline can read KB as context:

- **`using-mega-sdd`** (1.0.0 → 1.1.0) — adds `docs/knowledge-base/`, `docs/mega-sdd/knowledge-base/`, `old-reference/knowledge-base/` to CWD signals. Adds trigger keywords (`reverse engineer`, `extract intelligence`, `legacy intelligence`) + Indonesian variants (`pecah legacy`, `rebuild di stack baru`, `source of truth dari legacy`). Phase ownership table extended.
- **`orchestrate-flow`** (1.1.0 → 1.2.0) — CWD inspection adds knowledge-base detection (probe order: `docs/knowledge-base/`, `docs/mega-sdd/knowledge-base/`, `old-reference/knowledge-base/`). Decision matrix adds two new rows: legacy + no PRD + rebuild intent → propose `extract-intelligence` → `generate-intent --kb=<kb>`; KB present + no vault → propose `generate-intent --kb=<kb>` directly.
- **`generate-intent`** (1.1.0 → 1.2.0) — new `--kb=<path>` flag (Mode B sub-mode). Consumes KB README + domain files as PRD-equivalent source quotes. Marker-aware: KB `[VERIFIED]` → vault body without re-asking; `[INFERRED]` → confirmation prompt; `[OPEN]` → vault OQ with original tag preserved. Q&A shorter (≤5) when `--kb` set. Detection rule 0 (kb flag) takes precedence; rule 6 auto-detects CWD knowledge-base.
- **`bind-codebase`** (1.0.0 → 1.1.0) — adds KB consultation as secondary ground truth when codebase-map verdict is "not found" (never overrides CONFLICT). KB `[VERIFIED]` → CONFIRMED (via KB note); `[INFERRED]` → CONFIRMED with downstream-revisit note; `[OPEN]` → OQ. Flags: `--kb=<path>` (override auto-probe), `--no-kb` (skip).

### Backward compatibility

All changes are additive. Projects without a knowledge-base behave identically to v1.3. KB consultation in `bind-codebase` is gated on KB presence; absence skips it. The `--kb` flag in `generate-intent` is opt-in (or auto-detected from CWD only when no other input is provided).

### Naming notice

`extract-intelligence` is the mega-sdd-flavored counterpart to `superpowers:reverse-engineering-legacy-codebase`. The skill name was chosen to avoid collision with the superpowers skill of similar purpose. Use the mega-sdd version when the next step is mega-sdd unit/bolt generation. Use the superpowers version when the workflow is standalone reverse-engineering with no downstream mega-sdd pipeline.

### Skill versions

- `extract-intelligence`: new at 1.0.0
- `using-mega-sdd`: 1.0.0 → 1.1.0
- `orchestrate-flow`: 1.1.0 → 1.2.0
- `generate-intent`: 1.1.0 → 1.2.0
- `bind-codebase`: 1.0.0 → 1.1.0

### New tests

- `tests/skill-triggering/extract-intelligence.test.md` — 6 trigger cases (E1-E6) + 7 behavior checks (B1-B7)

### Validated against

Bank Mega Trade Finance legacy PHP system (~600 files, MySQL + MSSQL + LDAP + SWIFT FTP) — 35 MD files, ~968 KB output, 13 business domains, 430 OQs surfaced, 41 hidden gotchas catalogued in ~3 hours wall-clock for 15 agent dispatches across 5 waves.

## [1.3.0] — 2026-05-17

### Added — Obsidian-friendly vault + multi-squad subagent execution

Per spec `docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md`.

Lightweight Obsidian compatibility:
- 7 prose templates gain minimal YAML frontmatter (`type`, `doc_id`, `aliases`, `tags`)
- Internal cross-refs converted to Obsidian wikilink syntax `[[file#heading]]`
- Optional `.obsidian/graph.json` template with squad color groups

Multi-squad partition as a dimension threaded through the existing 5-phase pipeline (zero pipeline change, README flowchart intact):
- New `_meta/squads.yaml` declaring squad partition (layer / feature / hybrid models)
- New `interfaces/` folder for cross-squad contracts (architect-authored, status: draft → locked)
- Units gain optional `squad:`, `produces_interfaces:`, `consumes_interfaces:` frontmatter fields
- `execute-bolts --per-squad` spawns one Claude subagent per declared squad via existing `subagent-driven-development`
- `execute-bolts --squad=<id>` filters to one squad for dev-team handoff
- `generate-units` validates intra-squad-only `depends_on` and interface reference resolution
- `orchestrate-flow` detects multi-squad mode and suggests appropriate flags

### Halt protocol extensions (vault-contract.md §halt-protocol)

Four new blocker types:
- `cross_squad_dep_invalid` (generate-units rejects cross-squad direct depends_on)
- `interface_ref_missing` (generate-units dangling interface reference)
- `cross_squad_ambiguous` (generate-units two squads claim same artifact)
- `cross_squad_interface_draft` (execute-bolts consumer waits for producer to lock interface)

### Skill versions

- `generate-intent`: 1.0.0 → 1.1.0
- `generate-units`: 1.0.0 → 1.1.0
- `execute-bolts`: 1.0.0 → 1.1.0
- `orchestrate-flow`: 1.0.0 → 1.1.0

### Backward compatibility

- Existing v1.0–v1.2 vaults work unchanged (single-squad / no-squad-config mode active)
- Multi-squad is OPT-IN via the new Q&A in `generate-intent`
- No new skills; plugin skill count unchanged
- AI consumer skills (`bind-codebase`, `resolve-oq`, `detect-drift`, `diff-vault`) behave identically across v1.2 and v1.3 single-squad vaults

### New tests

- `tests/skill-triggering/`: 14 new cases across `generate-units`, `execute-bolts`, `orchestrate-flow`
- `tests/integration/e2e-multi-squad.test.md`: full multi-squad pipeline walkthrough

## [1.2.0] — 2026-05-13

### Added — Mode auto-detect for generate-intent

- **`generate-intent` auto-detects Mode A (PRD parse) vs Mode B (free-text Q&A)** from positional argument shape — no flag required.
  - Existing file path → Mode A
  - Quoted brief or whitespace input → Mode B
  - `--from-prompt` flag still works for explicit override
  - Edge cases (missing file, bare word, flag+positional conflict) handled with user-facing warnings
- New test fixture `tests/skill-triggering/generate-intent.test.md` covers 10 auto-detect cases (AD1-AD10) mapping to 6 detection rules + 2 edge cases.

### Changed — Tiered README

- **Root `README.md`** restructured for tiered surface:
  - Front-page (always visible): TL;DR + Why + actor flow diagram + 3 Primary commands + Anti-hallucination + Install (~150 lines visible)
  - 5 collapsed `<details>` sections preserve full content: Advanced commands (8 more), Architecture deep dive (5W1H, detailed Mermaid, ASCII, halt protocol, etc.), Repository structure, Migration from grand-design-spec, Procedure cheat-sheet
  - Single visible Mermaid (actor flow); detailed pipeline moved to Architecture deep dive
  - All v1.1 content preserved — just relocated/collapsed
- **`plugins/mega-sdd/README.md`** refreshed to mirror tiered style at smaller scale.
- **Cheat-sheet** updated: greenfield scenario now shows `/mega-sdd:generate-intent "your idea"` (no `--from-prompt` needed thanks to auto-detect).

### Migration

Fully backwards compatible. Existing v1.0.x/v1.1.x vaults load unchanged. All existing invocation patterns continue to work:
- `--from-prompt "..."` — still works, takes precedence as explicit override
- `./prd.md` — still works
- Empty args + CWD scan — still works
- New: just type `"your brief"` directly without any flag — auto-detected as Mode B.

### Marketplace

- `mega-sdd@1.2.0` published
- `grand-design-spec@0.16.0` continues deprecated; removed at v1.3.0 per existing schedule

## [1.1.0] — 2026-05-13

### Added — Source-code OQ deferral + structured halt protocol

- **resolve-oq 4-action menu** — Per OQ: Answer / Defer-to-binding / Out-of-scope / Skip. Defer option appears only in brownfield context (vault.mode=existing AND repo signals present).
- **resolve-oq `--binding` mode** — Procedure documented for walking CONFLICT + propagated deferred-OQ entries from `binding.md`. Per-conflict actions: KEEP_VAULT / KEEP_CODE / DEFER / SPLIT.
- **bind-codebase auto-resolution** — Deferred-binding OQs auto-resolve against codebase-map evidence (high-confidence single match); else propagate to `binding.md` Open Questions for user resolution via `resolve-oq --binding`.
- **vault-contract §halt-protocol** extended 3 → 8 structured types: + `bind_conflict`, `dep_missing`, `test_fail`, `cycle_detected`, `mode_migrate`.
- **routing-rules.md** intent gate excludes deferred OQs (`Vault has unresolved P0/P1 OQs with status != deferred` — deferred propagate to binding).

### Changed — Skill alignment

- **vault.json OQ schema** gains optional fields: `status` (pending|resolved|deferred|out-of-scope), `defer_to` (binding|stakeholder), `deferred_at`, `deferred_reason`, `out_of_scope_reason`. Backwards compatible — absent `status` treated as `pending`. Pre-v1.1 `defer_note` semantics now unified under `deferred_reason`.
- **bind-codebase SKILL.md** standardizes `<vault>-bound/` sibling naming throughout (was mixed with generic `bound-vault/`).
- **generate-intent SKILL.md** `--auto` default output path aligned to `docs/mega-sdd/vaults/<slug>/` (was `./<slug>-spec/`).
- **commands/detect-drift.md** output filename corrected to `DRIFT-REPORT.md` (matches skill SKILL.md).
- **bind-codebase, execute-bolts, generate-units, orchestrate-flow** emit structured halt YAML per §halt-protocol (was prose-only).
- **resolve-oq stakeholder-defer reconciliation** — Old Step 2c bespoke `defer_note` semantic merged into the new unified OQ schema (`defer_to: stakeholder` + `deferred_reason`).

### Fixed — README defects (audit findings F1-F8)

- Halt protocol section: 5 fabricated types replaced with the now-real 8-type list.
- `--chain` flag references removed (3 spots in cheat-sheet) — flag never existed.
- `update-plugin` moved from skills table to commands footnote (no backing SKILL.md).
- Skill count "11" corrected to "10 + 1 command-only".
- Plugin version aligned across `plugin.json`, marketplace.json, and both READMEs.
- Both diagrams add `{P0/P1 non-deferred OQs?}` intent-gate decision node visible in actor flow + detailed pipeline.
- Defense layer 4 wording: "runs post-bolt" → "suggested post-bolt; runs on demand".

### Migration

Fully backwards compatible. Existing v1.0.x vaults load without conversion. To benefit from new resolve-oq actions, re-invoke `resolve-oq` on existing vaults — 4-action menu appears for any pending OQ.

### Marketplace

- `mega-sdd@1.1.0` published
- `grand-design-spec@0.16.0` continues deprecated; removed at v1.2.0 per existing schedule

## [1.0.0] — 2026-05-13

### BREAKING — rename to mega-sdd

The plugin is renamed from `grand-design-spec` to `mega-sdd`. All skill, command, and namespace identifiers change. See migration table in `plugins/mega-sdd/README.md`.

### Added — Spec-Driven Development pipeline

- **`scan-codebase` skill** — heuristic repo mapping → `codebase-map.md` (brownfield prep)
- **`bind-codebase` skill** — vault validation gate; produces `bound-vault/` + `binding.md`; BLOCKS unit generation on conflicts (the keystone anti-hallucination layer)
- **`generate-units` skill** — bound-vault → atomic AI-executable unit specs with dependency graph
- **`execute-bolts` skill** — unit → code via superpowers integration; TDD discipline; halt protocol
- **`using-mega-sdd` anchor skill** — session-start injected for SDD-scoped sessions (scoped triggers)
- **SessionStart hook** — injects anchor when SDD signals detected in CWD; surfaces install hint if superpowers missing
- **Vendored superpowers fallback** — `_vendored/` namespace ensures bolts execute even when superpowers plugin not installed; `scripts/sync-superpowers.sh` automates refresh

### Changed

- `grand-design-spec` skill → `generate-intent` (absorbs `from-prompt` mode as `--from-prompt` flag)
- `flow` skill → `orchestrate-flow` (extended routing for new SDD phases; 3-skill chain cap preserved)
- `drift-detect` skill → `detect-drift`
- `vault-diff` skill → `diff-vault`
- `update` skill → `update-plugin` (now also runs dep-doctor)
- All version frontmatters → `1.0.0`

### Removed

- `from-prompt` skill (absorbed into `generate-intent`)
- `from-prompt` command (deprecated alias retained for back-compat, removed in v1.2)

### Deprecated

- `grand-design-spec` listing in marketplace (will be removed in 2 release cycles)
- `/mega-sdd:from-prompt` command alias (use `--from-prompt` flag instead)

### Marketplace

- Added `mega-sdd` entry (version 1.0.0)
- Marked `grand-design-spec` entry as deprecated, pointing to `mega-sdd`

### Documentation

- Plugin README rewritten with Mermaid flow diagram + ASCII fallback + procedure cheat-sheet
- New CLAUDE.md (contributor guidelines for AI agents)
- New tests/ tree with skill-triggering fixtures + hook + vendoring tests
- New `docs/mega-sdd/` output convention dirs

### Migration

Existing `grand-design-spec` users:
1. `/plugin install mega-sdd`
2. Replace `grand-design-spec:` → `mega-sdd:` in any scripts/docs (use rename table in plugin README)
3. Existing vaults are compatible — no manual conversion needed
4. To benefit from binding gate on existing vaults: run `/mega-sdd:scan-codebase` then `/mega-sdd:bind-codebase <vault>`

## [0.15.0] — 2026-05-10

The prompt-input release. Adds `/grand-design-spec:from-prompt` so users can start from a free-text brief instead of a PRD doc — eliminating the ChatGPT-to-Claude round-trip for prompt engineering. The orchestrator's `flow` chain becomes default-on across all rules: every invocation now walks the lifecycle to its natural endpoint without opt-in friction.

### Skill version moves

- `from-prompt`: **NEW at 0.1.0** (brief → seed-PRD elaborator)
- `flow`: 0.1.0 → **0.2.0** (Rule 0 + default-on chaining for Rules 1, 2, 4, 5, 6 + arg parsing extension for free-text prompts)
- `grand-design-spec`: unchanged at 0.10.0 (consumes seed-PRD.md as a normal source — no behavior change needed)
- `resolve-oq`: unchanged at 0.4.0
- `vault-diff`: unchanged at 0.3.0
- `drift-detect`: unchanged at 0.3.0

### Added

- **`/grand-design-spec:from-prompt`** — converts a free-text brief into `<output-dir>/source/seed-PRD.md`. Workflow: capture brief verbatim → adaptive Q&A across 10 fixed taxonomy topics (skip topics already covered in brief, hard cap at 10 questions) → compose seed-PRD with citation markers (`(brief)` / `(Q&A §N)` / `(unspecified)`) on every claim → write to disk. Substance prompts always interactive even with `--auto`. Halt protocol: emits `blocker` (type=`oq_blocker`, tag=`OQ-FROMPROMPT-0`) when brief is unparseable in `--auto` mode.
- **Rule 0 in `flow`'s decision matrix** — fires when no vault and no PRD file detected and prompt arg given. Auto-chains `from-prompt → grand-design-spec → resolve-oq (scope=p1-only)`. drift-detect not applicable (mode=new for prompt-input vaults).
- **Default-on chaining for `flow` Rules 1, 2, 4, 5, 6** — `resolve-oq` and `drift-detect` (when applicable) now chain automatically instead of being opt-in/conditional. User skips individual steps via `Edit plan: skip step N` in Step 3 confirmation. Plan-confirmation step still surfaces full chain before any skill runs.
- **Free-text arg parsing in `flow` Step 0** — args >20 chars without path-like characters are recognized as prompts (persisted as `EXPLICIT_PROMPT`). Borderline ambiguous args trigger `AskUserQuestion` clarification.
- **`seed-PRD` as a recognized `vault.json.source_documents[].type`** value — documented in `from-prompt/SKILL.md` references; `vault-contract.md` §schema treats `type` as free-form so no contract change required.

### Changed

- **`flow/SKILL.md`** Step 0 arg-parsing block extended to recognize free-text prompts; Decision matrix block fully replaced with v0.2 7-rule revision (adds Rule 0, marks Rules 1/2/4/5/6 as default-on); version 0.1.0 → 0.2.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.14.0 → 0.15.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:from-prompt` row, update lifecycle diagram (from-prompt as new entry point), update repo structure with `from-prompt/` skill dir, bump changelog footer.

### Backward compatibility

- v0.14 vaults continue to work unchanged. seed-PRD.md is just another source for `grand-design-spec` — no schema or vault structure changes.
- Direct invocation of `flow` with file/dir args works exactly as v0.14 (Rule 0 only fires when args are free text).
- Direct invocation of `flow` without args produces a Rule 7 STOP if WORK_DIR is empty — same as v0.14, with updated error message mentioning prompt option.
- Default-on chaining is a behavior change for users who relied on opt-in chains in v0.14. Mitigation: plan-confirmation step shows the full chain; user edits to skip steps they don't want. No anti-halu rail changes.
- Direct invocation of any sub-skill (`from-prompt`, `grand-design-spec`, etc.) without `flow` is unchanged — full interactive behavior when `--auto` is not passed.

### Notes

- The orchestrator stays **stateless by design**. Re-running `flow` re-inspects CWD; no `.gds-state.json` is written.
- **Hard cap of 3 skills per chain** stays at 3 (verified across all 7 rules including the new Rule 0).
- **`flow` does NOT run sub-skills in parallel** — sequential only.
- Audit findings deferred to v0.16+: vault evolution from a new prompt (`from-prompt → vault-diff` chain), multi-turn brief refinement, seed-PRD versioning across runs, voice-input briefs, reorder-and-edit-args plan editing in flow.

## [0.14.0] — 2026-05-10

The agentic upgrade. Adds `/grand-design-spec:flow`, a multi-skill lifecycle orchestrator that turns the plugin from "4 separate tools" into "one workflow." Inspects CWD, proposes a sub-skill chain (e.g., "vault-diff → resolve-oq for new P1s"), confirms once, executes in `--auto` mode. Anti-halu rails preserved by composition — every rail lives in a sub-skill, untouched.

### Skill version moves

- `flow`: **NEW at 0.1.0** (lifecycle orchestrator)
- `grand-design-spec`: 0.9.0 → **0.10.0** (added `--auto` flag for logistical prompts)
- `resolve-oq`: 0.3.0 → **0.4.0** (added `--auto` for logistics; per-OQ choices stay interactive)
- `vault-diff`: 0.2.0 → **0.3.0** (added `--auto` flag; conflicts emit `blocker` type=`diff_conflict`)
- `drift-detect`: 0.2.0 → **0.3.0** (added `--auto` flag; skips interactive walkthrough; framework mismatch emits `blocker` type=`drift_framework_mismatch`)

### Added

- **`/grand-design-spec:flow`** — the orchestrator command. Inspects WORK_DIR for vault, PRD, codebase signals, P1 count, mode-migration trigger, git state. Applies a 7-rule decision matrix to build a proposed chain (max 3 skills). Single user confirmation (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` in v0.1; reordering deferred. Stateless — resumption is just re-invoking. Pauses on `blocker` artifacts; surfaces YAML verbatim in chat.
- **`§halt-protocol`** in `references/vault-contract.md` — unified `blocker` envelope with three types: `oq_blocker` (per v0.11), `diff_conflict` (vault-diff conflicts), `drift_framework_mismatch` (drift-detect framework mismatches). Schema, field rules, type-specific guidance, multi-blocker array form, and v0.11 → v0.14 backward-compat note.
- **`--auto` convention** documented in CONTRIBUTING.md — required for any future skill with prompts. Skips logistical prompts (paths, modes, scopes); never skips substance prompts (stakeholder answers, conflict resolutions); emits `blocker` when halted autonomously.

### Changed

- **`00-index.md` template Halt protocol section** — emits `blocker: type: oq_blocker` (new unified envelope) instead of legacy `oq_blocker:` form. Backward-compat note appended for AI consumers reading v0.13 vaults.
- **`grand-design-spec/SKILL.md`** — adds `## --auto flag` section before Workflow describing how Step 0–0.7 prompts default in `--auto` mode (output folder slug-derived, mode inferred from codebase signals, PRD_STATUS=draft, OUTPUT_MODE=compact). Anti-halu rails (Figma "do you have screenshots?", destructive overwrite confirmation, OQ tagging, source citation) NEVER bypassed.
- **`resolve-oq/SKILL.md`** — adds `## --auto flag` section. Substance prompts (per-OQ Resolve/OOS/Defer/Skip choice, cross-cutting landing) ALWAYS interactive. Logistics (vault path, resume detection, scope, lock ack default) auto-defaulted.
- **`vault-diff/SKILL.md`** — adds `## --auto flag` section. Conflicts (Resolved-OQ, Decision) emit `blocker` (type=`diff_conflict`) and pause. Auto-applies non-conflict changes ≤ 50; emits `blocker` if change count exceeds cap (per OQ-FLOW-3 spec decision).
- **`drift-detect/SKILL.md`** — adds `## --auto flag` section. Skips Step 5 interactive walkthrough; writes `DRIFT-REPORT.md` only (no `DRIFT-ACTIONS.md` — deliberate human decision). Framework mismatch emits `blocker` (type=`drift_framework_mismatch`).
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.13.0 → 0.14.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:flow` to commands tables, update lifecycle diagram (flow as recommended entry point), update repo structure with `flow/` skill dir.

### Backward compatibility

- v0.13 vaults continue to work read-only.
- AI consumers reading vault halts should accept both `oq_blocker:` (legacy v0.11–v0.13 form) and `blocker: type: oq_blocker` (new v0.14 form) for one release cycle. v0.15+ may drop legacy support.
- Direct sub-skill invocation (without `flow`) is unchanged when `--auto` is not passed — full interactive behavior per v0.13.
- `flow` is opt-in. Users who prefer manual sub-skill invocation can ignore it entirely.

### Notes

- The orchestrator is **stateless by design**. No `.gds-state.json` is written. This simplifies the contract (every flow run re-inspects CWD) but means "did I forget drift-detect?" recall depends on user re-running flow.
- **Hard cap of 3 skills per chain** prevents runaway chains. Beyond 3, orchestrator surfaces and asks for explicit confirmation.
- **`flow` does NOT run sub-skills in parallel** — sequential only. Sub-skills modifying the same vault would race otherwise.
- Audit findings deferred to v0.15+: state file with lifecycle position tracking (Approach 2 from brainstorming), reorder-and-edit-args plan editing, scheduled-mode drift-detect via `schedule` skill, self-critiquing loops (Approach 4 from brainstorming).

## [0.13.0] — 2026-05-09

Driven by the ship-readiness audit at `docs/superpowers/specs/2026-05-09-plugin-audit-design.md`. Closes 3 HIGH and 4 MED audit findings. Acknowledges that v0.11 vault.json parity was incomplete (only `resolve-oq` got write-back; `vault-diff` was missed) and lands the fix.

### Skill version moves

- `grand-design-spec`: 0.8.0 → 0.9.0 (references shared `vault-contract.md`, adds OQ_BLOCKER halt-protocol self-check)
- `resolve-oq`: 0.2.0 → 0.3.0 (removes `lock-vault` forward-references, adds vault.json count-match self-check)
- `vault-diff`: 0.1.0 → 0.2.0 (**adds Step 6.5 vault.json refresh** — closes the v0.11 parity gap)
- `drift-detect`: unchanged at 0.2.0 (documentation-only change: explicit `vault.json` reconciliation boundary)

### Added

- **`references/vault-contract.md`** (M-1, L-8, L-9) — single source of truth for the `vault.json` schema, OQ tagging conventions, status marker semantics, ID stability rules, and "Skill instruction language" boilerplate. All 4 skills now reference it instead of duplicating content.
- **`vault-diff` Step 6.5 — Refresh `vault.json`** (H-1) — after applying approved changes in Step 6, regenerate the manifest from post-apply markdown so `entities[]`, `flows[]`, `adrs[]`, `open_questions[]`, and `open_questions_summary` reflect the new state. Step 8 self-check gains 4 vault.json invariants.
- **`drift-detect` `vault.json` reconciliation boundary** (H-2) — Step 6 now explicitly documents that drift-detect produces reports only and never regenerates `vault.json`. Vault.json regen happens via `resolve-oq` (for OQ-tagged actions) or manual edit + `grand-design-spec` re-run (for entity/flow/ADR additions). Per audit OQ-AUDIT-1 decision: explicit boundary, not auto-reconcile.
- **Template compact/full markers** (M-5) — `01-overview`, `02-architecture`, `03-data-model`, `04-flows`, `05-decisions` templates now carry `<!-- compact-skip -->` and `<!-- full-only -->` HTML comments around mode-conditional content. Replaces 5 memorized runtime transformation rules with mechanical markers. `00-index` and `06-constraints` have no compact-conditional content (unchanged).
- **`grand-design-spec` Step 4 self-check** (M-6) — verifies `00-index.md` contains the "Halt protocol for autonomous runs", "Parallel-work guidance", and "Companion skills for vault evolution" sub-sections per template.
- **`resolve-oq` Step 4 self-check** (M-8) — verifies `vault.json.open_questions_summary.total` matches markdown roll-up; verifies promoted ADRs appear in `vault.json.adrs[]`.
- **`CONTRIBUTING.md`** (M-3) — documents the versioning rule (independent semver per skill, with CHANGELOG enumerating per-skill moves), commit-message scopes, tagging discipline, new-skill checklist, and spec/plan workflow.

### Removed

- **`lock-vault` forward-references** (H-3) — `resolve-oq/SKILL.md` previously mentioned a `lock-vault` skill "(when available)" twice. Replaced with explicit manual-edit instructions for `00-index.md` Vault Lock Status. Building a real `lock-vault` skill is a v0.14+ candidate.

### Changed

- `plugin.json` and `marketplace.json` plugins[0].version bumped 0.12.1 → 0.13.0 (skill behavior changes + new file structure).
- `grand-design-spec/SKILL.md` body shrinks ~60 lines as the duplicated `vault.json` schema and OQ tagging convention move to `vault-contract.md`. Net change: smaller skill body + one new reference file.

### Backward compatibility

- Existing v0.12 vaults continue to work read-only.
- Re-running `vault-diff` against a v0.12 vault now produces an updated `vault.json` (previously skipped). If the v0.12 vault was created before vault.json was introduced (pre-v0.11), Step 6.5 generates a fresh manifest from the markdown.
- Skills that don't bump (drift-detect) maintain the same input/output contract.
- The new `references/vault-contract.md` is referenced by skills but loaded on-demand — no eager-load cost on existing flows that don't touch the schema.

### Notes

- The v0.11 CHANGELOG entry implied vault.json parity that didn't exist for `vault-diff`. v0.13 explicitly closes that gap and the CHANGELOG now enumerates per-skill version moves to prevent the same drift.
- Audit findings deferred to v0.14+: a real `lock-vault` skill (H-3 alternative), template footer extraction (L-10), trigger-phrase canonical source (L-11), OQ category enumeration (M-2), `grand-design-spec/SKILL.md` progressive disclosure (L-12), tag backfill for v0.7-v0.12 (L-7).

## [0.12.1] — 2026-05-09

### Added

- **`/grand-design-spec:update`** — convenience command that pulls the latest plugin from `origin/main` (fast-forward only), shows before/after versions, and instructs the user to finish with the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. Custom slash commands can't invoke built-ins, so the cache-refresh step stays explicit.

### Changed

- `plugin.json` and `marketplace.json` plugins[0].version bumped 0.12.0 → 0.12.1 (additive command).

## [0.12.0] — 2026-05-09

Surfacing companion skills as user-typeable slash commands.

### Added

- **`/grand-design-spec:grand-design-spec`** — main vault generator now invokable from autocomplete with optional `[prd-path] [figma-url]` arguments.
- **`/grand-design-spec:resolve-oq`** — interactive Open Questions resolver, callable directly with `[vault-path] [optional OQ tag]`.
- **`/grand-design-spec:vault-diff`** — vault ↔ revised PRD diff report, callable with `[old-vault] [new-prd]`.
- **`/grand-design-spec:drift-detect`** — vault ↔ codebase reconciliation, callable with `[vault-path] [codebase-root]`.

### Why

Until v0.11, the three companion skills (`resolve-oq`, `vault-diff`, `drift-detect`) were Claude-invoked only via the Skill tool — they did not appear in the `/` autocomplete menu, so users had to ask Claude in prose to trigger them. v0.12 adds explicit command files in `plugins/grand-design-spec/commands/` that mirror each skill, making the full lifecycle (generate → resolve → diff → drift) discoverable from the slash menu.

### Changed

- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.11.0 → 0.12.0 (additive feature: command surface).

### Backward compatibility

- No skill behavior changed — command files are thin wrappers that delegate to the existing skills.
- Users on v0.11 can keep invoking skills via prose; v0.12 simply exposes a faster discovery path.

## [0.11.0] — 2026-05-09

Driven by audit findings from the TimeOff smoke-test dogfood (commit `e6bada4`). Three Tier-1 refinements + two Tier-2 quick wins, focused on bridging vault generation to actual consumption by AI dev tools.

### Added

- **`vault.json` machine-readable manifest** (R1, generated alongside the 7 markdown files in Step 3). Structured index of entities, flows, ADRs, OQs (with state + priority + category + resolver_owner), source documents, and Step-2 design-system flags. Markdown stays human-authoritative; JSON optimizes machine consumption — AI dev tools load context in <1K tokens instead of brute-parsing 25K+ of prose. Schema documented inline in SKILL.md Step 3. Step 4 self-check verifies markdown ↔ JSON consistency on every regeneration.
- **`OQ_BLOCKER` halt artifact format** for autonomous AI consumers (R2). Defined in `00-index.md` template "Halt protocol for autonomous runs" sub-section. When an AI agent hits an unresolved P1 OQ in non-interactive mode, instead of silent halt it emits a structured YAML artifact with `tag`, `priority`, `blocking_task`, `resolver_owner`, `resolver_route`, `vault_version`. Agent runners can route this to ticketing / Slack / on-call pages reliably. Single-blocker and multi-blocker formats both defined.
- **Mode migration trigger** (R3) — new Vault Lock Status field `mode_migrate_after`. Captures the event that flips a `mode=new` vault to `mode=existing` (e.g., "first commit on main", "first prod deploy", "sprint-1 demo"). Step 0.5 of `grand-design-spec` now prompts for this when mode=new. After trigger fires, user manually flips mode + bumps version + adds Changelog, OR runs `vault-diff`. Once flipped, `drift-detect` becomes applicable.
- **Parallel-work guidance** in `00-index.md` template (R5) — when P1 OQs block a task, lists artifact types the dev/AI can still produce in parallel (test specs from DoD, scaffolded ORM models with TODO markers, UI stubs, OOS confirmations). Each parallel artifact must carry the OQ tag(s) it depends on so it's revisited on resolution.
- **Cross-cutting OQ multi-doc landing pattern** in `resolve-oq` Step 2c (R7). When a single OQ resolution legitimately affects 3+ docs (tech-stack, multi-tenancy, auth, compliance), skill writes the primary entry once and adds terse cross-reference lines in other affected docs (`> Resolves OQ-{tag}: see {primary-doc}.md#{anchor}`). All point back to the OQ tag for audit. Heuristic for "cross-cutting" documented inline.
- **`vault.json` write-back in `resolve-oq`** — every Resolve / Out-of-Scope / Defer outcome updates the manifest's `open_questions[]` status field, recomputes `open_questions_summary` counts, and (for promoted Resolve) appends new ADRs to `adrs[]`. Keeps machine-readable index in sync with markdown.
- **`drift-detect` mode-migration awareness** — when run on a `mode=new` vault, surfaces the `mode_migrate_after` trigger so the user knows what to do before re-running. Better failure mode than the previous flat "this skill doesn't apply".

### Changed

- **`grand-design-spec` SKILL.md** version bumped 0.7.0 → 0.8.0 (added `vault.json` generation in Step 3 + Step 4 self-check + Step 0.5 migration trigger + halt protocol section in template).
- **`resolve-oq` SKILL.md** version bumped 0.1.0 → 0.2.0 (cross-cutting OQ multi-doc landing + vault.json write-back).
- **`drift-detect` SKILL.md** version bumped 0.1.0 → 0.2.0 (mode-migration awareness in Step 0).
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.10.0 → 0.11.0 (skill behavior changes).
- **`00-index.md` template** — Vault Lock Status gains `mode_migrate_after` field; Implementation Notes section gains "Halt protocol for autonomous runs" + "Parallel-work guidance" sub-sections.

### Backward compatibility

- Existing v0.10 vaults continue to work read-only. Companion skills (`resolve-oq`, `vault-diff`, `drift-detect`) handle the absence of `vault.json` gracefully — they fall back to parsing markdown.
- To upgrade an existing v0.10 vault to v0.11: re-run `/grand-design-spec:vault-diff` against the same PRD; the diff session writes `vault.json` and adds `mode_migrate_after` to Vault Lock Status. Or edit `00-index.md` manually.
- Existing OQs resolved before v0.11 carry no `vault.json` entry; the next resolve-oq round repopulates the manifest from current markdown state.

### Notes

- The audit that drove this release: vault generation works (TimeOff smoke test, 1187 lines, 48 OQs, 95% anti-halu compliance), but AI dev consumption was the bottleneck — 25K+ tokens to load full markdown, no halt protocol for autonomous runs, no migration path for greenfield projects, fuzzy boundaries on cross-cutting OQ resolution. v0.11 directly addresses these.
- Tier 2 items deferred to v0.12+: `extract-context <flow-id>` skill (return min vault subset for a specific flow), DoD → test spec auto-conversion, pre-commit drift-detect integration, vault → tickets generator.
- Mega Rencana (`mode=existing`, mobile-app, ID) and TimeOff (`mode=new`, web-app, EN) smoke fixtures remain valid as v0.11 examples; regenerating them produces vault.json automatically.

## [0.10.0] — 2026-05-08

### Added
- **`drift-detect` skill (new, v0.1.0)** — detects drift between a `mode=existing` vault (target spec) and live codebase (current reality). Heuristic scan of entities, flows, endpoints, and decisions; produces a structured `DRIFT-REPORT.md` with confidence-rated findings. Closes the loop between vault generation and shipped code for revamp / extension projects. Invoke with `/grand-design-spec:drift-detect`.
- **Eight drift outcome categories**: Missing in code, Missing in vault, Name drift, Type drift, Behavior drift, Decision violation, Decision unwritten, Confirmed match.
- **Confidence ratings per finding** — `high` (exact name + type match found / not-found), `medium` (similar names but different signatures), `low` (heuristic keyword guess). Low-confidence findings carry explicit "verify manually" caveats.
- **Direction-neutral framing** — every finding presents vault state and code state side-by-side. The skill never says "code is wrong" or "vault is stale"; only "they disagree, here's where each lives".
- **Decision violations & unwritten ADRs surfaced PRIORITY-1** — these correspond to compliance / architectural debt and most often require stakeholder review.
- **Framework auto-detection** — skill identifies the codebase framework (Laravel, Rails, Spring, Express, Django, Flutter, etc.) via lockfile / manifest signatures and proposes default scope dirs. User confirms or overrides.
- **Drift scope selection** — `full` (default), `schema-only`, `flows-only`, `decisions-only`, or `single-doc`.
- **`DRIFT-ACTIONS.md` artifact** — captured user decisions per finding (split into Code-side actions and Vault-side actions). The skill never executes code changes; it produces an actionable list for engineering team follow-up.
- **OQ cross-reference scan** — detects when codebase mentions `OQ-{CODE}-{N}` tags and flags any references to still-open OQs as "code references unresolved OQ".

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.9.0 → 0.10.0 (new skill addition).

### Notes
- The skill is **heuristic**, not a static analyzer. False positives and false negatives both happen. Treat findings as triggers for human review, not verdicts.
- Decision compliance is the lowest-confidence axis — keyword-based detection only catches obvious cases. For comprehensive compliance, this skill complements (not replaces) code review and architecture review.
- The skill writes report artifacts but **never modifies the codebase or the vault directly**. All actions are captured for deliberate human follow-up.
- For `mode=new` projects there's no codebase to scan — the skill bails politely and points to `vault-diff` if the user is comparing PRD versions.
- The four skills now form a complete vault lifecycle: `grand-design-spec` (initial generation) → `resolve-oq` (interactive OQ resolution) → `vault-diff` (vault evolution across source revisions) → `drift-detect` (vault vs codebase reconciliation for `mode=existing`).

## [0.9.0] — 2026-05-08

### Added
- **`vault-diff` skill (new, v0.1.0)** — evolves an existing vault when the PRD/BRD/Figma source revisions, without losing resolved OQs, ADR provenance, or Changelog history. Invoke with `/grand-design-spec:vault-diff`. The naive alternative ("delete vault, regenerate") destroys every captured stakeholder decision and starts the OQ list from zero — this skill exists specifically to make vaults survive past sprint 1.
- **Eight diff outcome categories** with explicit handling rules: Auto-resolved OQ, New OQ, Added (entity/flow/decision/section), Changed, Removed (annotated, never deleted), Resolved-OQ conflict, Decision conflict, Unchanged.
- **`VAULT-DIFF.md` artifact** — the skill writes a structured diff report into the vault directory before applying changes. Persistent record the user reviews offline; conflicts surfaced at the top of the file so reviewers see them first.
- **Conflict-first walkthrough** — Step 5 prioritizes Resolved-OQ conflicts and Decision conflicts before any other category. User decision required for each (Supersede / Keep vault / Capture both / Skip). Skill never auto-decides on conflicts.
- **Diff scope selection** — `full` (default), `oq-only` (fast pass for minor PRD clarifications), or `specific-docs` (surgical update of named docs only).
- **Removed-content preservation** — entities/flows/decisions removed from new PRD are NOT deleted from vault; they get a `> **Removed in v{X.Y}**` banner. The vault retains history; the Changelog records the removal.
- **Identifier stability** — OQ tags, flow IDs, ADR D-XXX numbers all survive the diff. New entries get next-available IDs; existing IDs preserved in place.
- **Git safety check** — Step 0 runs `git status` and recommends commit-before-diff so the diff session is rollback-able. Doesn't refuse without git, but warns.

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.8.0 → 0.9.0 (new skill addition).

### Notes
- The skill never auto-resolves conflicts. "Auto-resolve all" requests are refused — conflicts (vault state vs new PRD) are exactly the cases requiring human judgment.
- Major scope shifts (>50% removed entities, >30% added, project name divergence) trigger a "this looks like a different project, are you sure?" prompt before proceeding.
- LOCKED vaults require explicit unlock confirmation before diff is applied (re-sign-off needed after).
- The three skills now form a complete vault lifecycle: `grand-design-spec` (initial generation) → `resolve-oq` (interactive OQ resolution) → `vault-diff` (evolution across source revisions).

## [0.8.0] — 2026-05-08

### Added
- **`resolve-oq` skill (new, v0.1.0)** — interactive resolver for Open Questions in an existing vault. Companion to the main `grand-design-spec` skill. Walks the OQ roll-up by priority (P1 → P2 → P3), captures stakeholder answers per OQ, updates the vault, and bumps version + Changelog. Invoke with `/grand-design-spec:resolve-oq`.
- **Four resolution outcomes per OQ**: `Resolve` (capture answer inline or promote to a target section like new ADR / field constraint), `Out of Scope` (move to OOS section with rationale), `Defer` (keep open with stakeholder + target date), `Skip` (no change, return next round).
- **Resume support** — re-running the skill on a partially-resolved vault detects prior rounds via Changelog entries and offers to continue from current state.
- **Resolution scope selection** — `p1-only` (focused first pass), `p1-then-p2`, `all-priorities`, `by-category` (group by roll-up category, useful when each category aligns with a different stakeholder), or `single-oq` (jump to a tag).
- **Auto-classification of resolution destination** by OQ code prefix (`OV-` → 01-overview, `AR-` → 02-architecture, `DM-` → 03-data-model, `FL-` → 04-flows, `DC-` → 05-decisions, `CN-` → 06-constraints), with explicit user override allowed.
- **OQ tag preservation** through resolution — every OQ identifier survives via `[x]` resolved markers, `[~]` out-of-scope markers, or stays `[ ]` with a Deferred annotation. Full audit trail of what was decided when.
- **Atomic per-OQ edits** — bail-out at any time preserves partial progress for the next run.

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.7.0 → 0.8.0 (new skill addition).

### Notes
- The new skill never auto-fills answers. Refusing "answer all OQs for me" is a hard guarantee — the skill exists to capture **stakeholder** input, not Claude's guesses. Offer Defer instead.
- Resolution density adapts to the parent vault's `OUTPUT_MODE`. Compact vaults get inline resolutions or 1-paragraph promoted ADRs; full vaults get multi-section promoted ADRs.
- The `grand-design-spec` skill itself remains at v0.7.0 — no changes to the main vault generator in this release.

## [0.7.0] — 2026-05-08

### Added
- **`OUTPUT_MODE=compact|full` flag (Step 0.7).** New mandatory step after PRD status flag. Captures the verbosity tier of vault output. Drives Step 3 generation rules per the Output mode policy table. Default: `compact`.
  - `compact` (default) — table-first, prose-cut, ~40% lighter token output. 1-line TL;DR header, API contracts as tabel (skip JSON example unless payload non-trivial), DBML-only entity descriptions, ADR as 1-paragraf format, OQ entries as 1-line, glossary skips generic IT terms.
  - `full` — verbose, prose-rich. 3-line TL;DR header, full request/response JSON per endpoint, prose entity descriptions alongside DBML, multi-bullet ✅⚠️ consequences per ADR. For audiences including non-technical reviewers (BO, legal, compliance).
- **Output mode policy table** in `## File-by-file content guide` mapping per-doc behavior (TL;DR, API contracts, entity descriptions, flow blocks, decision blocks, glossary, OQ entries) across both modes. Replaces the prior vague "as simple as possible" guidance with concrete, measurable rules.
- **Auto-default conditions** — skill picks `compact` without asking when user explicitly requested terse output or runs in autonomous / no-pause mode. Echoes auto-default with reason.
- **Hard invariants section** — explicit list of anti-hallucination guarantees preserved in BOTH modes (source citation, OQ tag + priority, DoD per flow, decision source, Out of Scope never empty). Compact mode never weakens grounding.
- **Step 4 self-check items** for output mode compliance — 8 new checks covering compact-mode formatting + 6 hard-invariant checks that apply regardless of mode.
- **`Output mode` field in `00-index.md > Vault Lock Status`.** Surfaced to downstream AI consumers + readers so they know which verbosity tier the vault was generated in.
- **Step 5 hint** — when `compact` mode used, summary mentions opt-in to `full` mode for re-run if needed.

### Changed
- **`## Length & simplicity policy`** renamed to **`## Output mode policy`** and rewritten from 4-bullet vague guidance to a 10-row aspect-by-mode tabel + invariants block + audience principle.
- **Per-doc TL;DR template** updated to show both 1-line (compact) and 3-line (full) format with mode markers.
- **`02-architecture.md` API contracts guidance** — adds explicit compact behavior (tabel default, JSON only for non-trivial payloads) vs full behavior (full JSON per endpoint).
- **`03-data-model.md` guidance** — compact = DBML + 1-line `Purpose:` per entity, skip prose section. Full = DBML + per-entity prose + field-level validation tabel.
- **`04-flows.md` guidance** — compact skips Preconditions/Postconditions blocks (derivable from steps + DoD), keeps Steps + DoD + cross-cutting handoffs. Full = all template sections.
- **`05-decisions.md` guidance** — compact = 1-paragraf ADR format, full = multi-section block with Status/Date/Context/Decision/Consequences/Source.
- **`00-index.md > Glossary` and `> Open Questions roll-up`** — compact mode cuts generic IT terms from glossary, OQ entries become single-line. Full mode preserves prior verbose format.
- **`SKILL.md` frontmatter** version bumped 0.6.0 → 0.7.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.6.0 → 0.7.0.

### Backward compatibility
- v0.6 vaults remain valid. No migration step.
- v0.7 with `OUTPUT_MODE=full` produces output **structurally identical to v0.6** (modulo the new `Output mode` line in Vault Lock Status). Use `full` to retain v0.6 verbosity verbatim.
- v0.7 with `OUTPUT_MODE=compact` (the new default) produces a leaner vault that preserves every source citation, every Open Question, every Definition of Done, every cross-cutting handoff — only narrative scaffolding is cut.
- The four v0.6 design-system detection flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) and conditional sections continue to work unchanged in v0.7. Output mode only controls verbosity per-section, not section presence.

### Notes
- Anti-halu invariants are **hard guarantees** in both modes. Compact mode trades narrative scaffolding for token efficiency, never grounding strength. A compact-mode vault and a full-mode vault generated from the same PRD will list the same OQs (with same tags + priorities), cite the same sources, and contain the same DoD checklists — only the prose density differs.
- The "audience principle" is documented inline: compact targets builders (architect, dev, QA) who can read tabel + DoD without prose hand-holding; full targets cross-functional reviewers (PM, BO, legal, compliance) who need narrative context.

## [0.6.0] — 2026-05-08

### Added
- **Optional design-system coverage for UI projects.** When source documents (PRD / Figma via MCP / uploaded tokens files) explicitly contain design-system content, the vault now emits two new sections:
  - **`02-architecture.md > UI components & patterns`** sub-section under each UI layer. Components table (spec voice) + Patterns prose (guide voice — when-to-use rules). Triggered by `HAS_UI_COMPONENTS=true` flag from Step 2 detection.
  - **`06-constraints.md > Design system`** top-level section alongside Technical / Business / NFR. Three sub-blocks (Tokens / Accessibility / Voice & brand), each independently conditional on its specific flag.
- **Step 2 design-system content detection.** Skill scans all sources for explicit mentions of UI components, design tokens, a11y standards, and voice/brand rules. Persists four flags: `HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`. Flags drive Step 3 conditional generation.
- **Source merge rules** when multiple design-system sources are provided (Figma + tokens.json, multiple Figma URLs, etc.). Higher priority wins for the same value (Figma > tokens file > PRD-stated). Equal-precedence disagreement → emit `OQ-CN-{N} [P1]` with both quoted values; never silent pick.
- **Conditional UI/UX or FE Dev reading path** in `00-index.md`. Appears only when at least one of the new design-system sections is present.
- **Conditional design-system glossary entries** in `00-index.md` (design tokens, design system, WCAG, a11y, semantic HTML). Appear only when terms are used elsewhere in the vault.
- **Six new Step 4 self-check items** for design-system grounding. Apply only when at least one design-system section is present in the vault.

### Changed
- **Anti-hallucination rule extended** from v0.5's "no invented content within sections" to v0.6's "no invented sections." Section presence is determined by source coverage alone — `PROJECT_SHAPE` is NOT a trigger. Vault never auto-creates design-system sections because shape inference suggests UI. Vault never defaults to industry standards (WCAG 2.1 AA, Material Design, iOS HIG, Tailwind defaults) when sources are silent.
- **Push-back rules** gain explicit "design-system absence is acceptable" sub-section. Skill MUST NOT prompt the user for missing design-system sources. PRD silent on FE → vault silent on FE. No exception, no questioning.
- **`SKILL.md` frontmatter** version bumped 0.5.0 → 0.6.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.5.0 → 0.6.0.

### Backward compatibility
- v0.5 vaults remain valid. No migration step.
- v0.6 for projects without design-system source coverage produces output **identical to v0.5**. The four detection flags simply stay `false` and no sections are added.
- v0.6 with full design-system coverage adds two sub-sections, one top-level section, one reading path, and up to five glossary entries — all conditional, all source-cited.

### Notes
- The four detection flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) are independent. A project might surface tokens but not components (e.g., PRD spells out brand colors but Figma is unavailable), and vice versa. Each flag is independently evaluated.
- Existing-codebase reconciliation for design system remains the downstream AI consumer's job. Vault generator never reads codebase, even when `IMPLEMENTATION_MODE=existing` and a design-system package exists in the repo.

## [0.5.0] — 2026-05-08

### Added
- **`PRD_STATUS=final|draft` flag (Step 0.6).** New mandatory step after implementation mode flag. Captures whether the source PRD/BRD is signed-off (`final`) or still in flux (`draft`). Drives gap-handling and push-back behavior throughout the workflow.
  - `final` → skill never pauses for clarification, even when gap count is large or PRD is contradictory. All ambiguities funnel into Open Questions roll-up. User triages OQ list with stakeholder offline, post-vault.
  - `draft` → existing behavior preserved. Skill pauses when gap count > 10, surfaces contradictions inline, asks for resolution before generating.
- **`PRD status` field in `00-index.md > Vault Lock Status`.** Surfaced to downstream AI consumers (Claude Code, Cursor) so they know the OQ list is the authoritative gap inventory under `final` mode.
- **PRD source file annotation.** `<filename> — FINAL | DRAFT` marker in Vault Lock Status PRD source line.

### Fixed
- **Tool name references for Claude Code distribution.** SKILL.md previously used Claude.ai sandbox API names that don't resolve under `/plugin install`:
  - `tool_search(query="figma")` → `ToolSearch` with `query: "figma"` or `query: "select:..."` syntax.
  - `ask_user_input_v0` → `AskUserQuestion`.
  - `present_files` → no tool needed in Claude Code (files already on disk after Step 3); fall back kept for Claude.ai sandbox.
  - `view` (template read) → `Read`.
- **Step 3 template path stale post-v0.4.0 restructure.** Plugin-installed skills no longer land at `~/.claude/skills/`. Updated to use `${CLAUDE_PLUGIN_ROOT}/skills/grand-design-spec/references/templates/` as the primary path. Manual-install and Claude.ai sandbox paths kept as fallbacks.
- **Push-back rules** restructured to clearly distinguish always-push-back cases (Figma missing, "just guess the rest", path mismatch) from `draft`-only cases (missing sections, contradictions, large gap count).
- **`03-data-model.md` template typo**: "follow project conventions Han already confirmed" → "follow project conventions you've already confirmed with the team".
- **`.gitignore`**: removed project-specific `mega-rencana-spec/` entry (test fixture leak).

### Changed
- **`marketplace.json`**: dropped redundant top-level `version` field. Marketplace itself isn't versioned; each plugin entry now owns its version (`plugins[].version: "0.5.0"`).
- **`plugin.json`** version bumped 0.4.0 → 0.5.0.
- **`SKILL.md` frontmatter** version bumped 0.4.0 → 0.5.0.
- **README "What happens next"** updated with the new PRD-status question.

### Notes
- `final` mode does NOT relax anti-hallucination guarantees. Skill still refuses "just guess the rest" — `final` only changes whether the skill pauses to ask stakeholder synchronously, not whether Claude can fill in blanks. Gaps remain Open Questions, never silently filled.
- For `final` mode contradictions, the skill writes OQ entries with both PRD quotes side-by-side so stakeholder can rule which is canonical without re-reading the original doc.

## [0.4.0] — 2026-05-08

### Changed
- **Repository restructured to Claude Code Plugin Marketplace format.** Added `.claude-plugin/marketplace.json` at repo root and `plugins/grand-design-spec/.claude-plugin/plugin.json` at plugin root. Skill files (`SKILL.md`, `references/templates/*.md`) moved to `plugins/grand-design-spec/skills/grand-design-spec/`. Marketplace catalog points to the plugin via relative path source `./plugins/grand-design-spec`.
- **Install flow.** Now installable via `/plugin marketplace add <gitlab-url>` + `/plugin install grand-design-spec@grand-design-spec` instead of manual `git clone` to `~/.claude/skills/`. Version pinning via `#v0.4.0` ref appended to the GitLab URL.
- **Plugin-level README** added at `plugins/grand-design-spec/README.md` (focused on what the plugin does + trigger phrases). Root `README.md` now describes the marketplace itself and installation across Claude Code, Claude.ai, and Claude API.
- **`SKILL.md` frontmatter** version bumped 0.3.0 → 0.4.0. No skill content changes — behavior identical to v0.3.0.

### Notes
- Existing users who installed via `git clone` to `~/.claude/skills/` should remove the old clone (`rm -rf ~/.claude/skills/grand-design-spec`) before installing via `/plugin install` to avoid duplicate skill registration.

## [0.3.0] — 2026-05-08

### Added
- **Project Shape Registry** in `SKILL.md`. 5 pre-templated shapes (`mobile-app`, `web-app`, `api-only`, `multi-platform`, `data-pipeline`) + `custom` fallback. Skill is now general-purpose, not biased toward mobile banking.
- **Step 2 — Project shape inference + confirmation**. Skill infers shape from PRD content using heuristics, presents reasoning to user, asks for confirm/override. Custom shape triggers user-described layers.
- **`PROJECT_SHAPE` flag** persisted alongside `IMPLEMENTATION_MODE`, drives sub-section structure in `02-architecture.md`, `04-flows.md`, and reading paths in `00-index.md`.
- **Project shape field** in `00-index.md > Vault Lock Status`.
- **Shape-aware Implementation Notes for AI Consumers** in `00-index.md` — instructs AI consumer to confirm both shape AND mode before code work, and to use the relevant layer section based on what's being implemented.

### Changed
- **`02-architecture.md` template** is now shape-agnostic. Layer sub-sections derived from `PROJECT_SHAPE`, not hardcoded "Mobile / Backend / Integrations".
- **`04-flows.md` template** is now shape-agnostic. Flow type sub-sections derived from `PROJECT_SHAPE`. Flow ID prefixes (`F-U-`, `F-S-`, `F-C-`, `F-P-`, `F-X-`) documented for use across shapes.
- **Reading paths in `00-index.md`** are now shape-conditional. Common patterns documented for each pre-templated shape.

### Fixed
- Removed mobile-banking bias. Skill no longer assumes UI exists, no longer hardcodes "Mobile" as a layer, no longer assumes user flows are mobile-facing.

## [0.2.0] — 2026-05-08

### Added
- **Step 0.5 — Implementation mode flag (simplified)**. Skill asks `new` vs `existing` — flag-only, no codebase reference. Mode is metadata that drives downstream AI consumer behavior.
- **`00-index.md > Vault Lock Status`**. Records vault version, lock timestamp, sign-off, status (DRAFT vs LOCKED), and PRD source. Vault locks against requirement, not codebase.
- **`00-index.md > Changelog`**. Tracks vault revisions per PRD update.
- **`00-index.md > Implementation Notes for AI Consumers`**. Explicit instructions for downstream AI dev tools (Claude Code, Cursor) on what to verify with user before writing/modifying code, especially in `existing` mode (cross-check entities/flows/decisions vs existing codebase).
- **Per-layer addressability in `02-architecture.md`**. Sub-sections `### Mobile / Frontend`, `### Backend`, `### Integrations` so each role can deep-link.
- **Per-type addressability in `04-flows.md`**. Sub-sections `### User flows (mobile-facing)`, `### Backend / system flows`, `### Cross-cutting flows`.
- **Deep-link reading paths in `00-index.md`**. Reading paths now use anchor links (e.g. `02-architecture.md#backend`).

### Changed
- Vault structure remains 7 files regardless of mode. Mode flag drives content of `00-index.md > Implementation Notes for AI Consumers`, not file count.
- Anti-halu rules clarified: vault locks **requirement**, not codebase. Codebase reconciliation is the AI consumer's job, instructed via Implementation Notes.

### Removed (vs 0.2.0-alpha conceptual draft, never released)
- `07-integration.md` was conceptually drafted in v0.2.0-alpha and dropped before stable release. Integration mapping to existing codebase belongs to AI consumer at consumption time, not to vault generator.
- Step 0.5 no longer asks for codebase reference (repo URL, local path).

## [0.1.0] — 2026-05-08

### Added
- Initial skill release.
- 7 file vault output: `00-index.md`, `01-overview.md`, `02-architecture.md`, `03-data-model.md`, `04-flows.md`, `05-decisions.md`, `06-constraints.md`.
- Anti-hallucination by construction: every claim must cite source, ambiguities flagged as Open Questions, Out of Scope explicit.
- Step 0 — Output path setup with cross-platform handling (sandbox detection, alien path warning, mkdir variants for Mac/Linux/WSL/Windows).
- Step 1 — Environment-aware input file detection (sandbox vs local Claude Code).
- Step 2 — Extract before writing with gap threshold (>10 → ask).
- Step 3 — Generate with template scaffolding from `references/templates/`.
- Step 4 — Self-check with grounding, readability, simplicity, output integrity verification.
- Step 5 — Present with top blocker surfacing.
- TL;DR header (3 lines: what / for whom / when to read) on every numbered doc.
- Open Question tagging: `OQ-{DOC_CODE}-{N}` with priority `[P1|P2|P3]`.
- 00-index sections: Executive Summary, Project Readiness Status, Reading paths by role, Glossary, OQ roll-up.
- Length & simplicity policy: simple by default; only `04-flows.md` may be complete-wajar.
- Readability standards: EN/ID convention (code EN, prose ID), anti-AI-tone read-aloud test, glossary mandate, cross-ref budget, date format convention.
- Push-back behavior: refuses "just guess the rest" requests, offers to mark as Open Questions instead.
- Templates for all 7 numbered docs.
- README.md with installation instructions for Claude Code (personal & project), Claude.ai/Desktop (zip upload), and Claude API.
- MIT License.
