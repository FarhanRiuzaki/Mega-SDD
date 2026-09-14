═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-002
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-002

UNIT: U-002 "Add the static company-profile content config"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-002
title: Add the static company-profile content config
prd_source:
  - PRD/prd-company-profile.md#halaman-beranda
  - PRD/prd-company-profile.md#halaman-tentang-kami
context_source: context.md#Constraints
task_type: create
grounding_confidence: MEDIUM
module: M-default
depends_on: []
target_files:
  - path: src/configs/companyProfile/index.ts
    operation: create
  - path: src/configs/companyProfile/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:
  - type: test
    command: "pnpm test:run src/configs/companyProfile/index.test.ts"
    expects: "Test Files  1 passed (1)"
binding_refs: []
---

# Unit U-002 — Add the static company-profile content config

## Goal

Create the one placeholder config file that feeds the organisation name, tagline, three services, profile paragraphs and team list to the public pages.

## Context (read first)

The PRD says all page content is static and comes from a placeholder configuration file the team will replace later (PRD §Halaman Beranda, §Halaman Tentang Kami, §Open questions; context.md#Constraints). It lives beside `src/configs/themeConfig.ts` under the `@configs/*` alias, in folder form because it has its own test (constitution A-002).

## Claims

- C-U002-01 "no company-profile config exists yet" — expect: src/configs/companyProfile — must-not-exist
- C-U002-02 "src/configs is the existing config folder behind the @configs alias" — expect: src/configs/themeConfig.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Ref: CLAUDE.md §Stack & Commands — the existing stack (MUI, next/link, react-hook-form, zod, TanStack Query, MSW) covers this unit; allowed_new_deps is empty
- file src/configs/companyProfile/index.ts MUST exist after bolt
- NEVER add a photo or image field to team entries (constitution D-002)

## Implementation steps

1. Create `src/configs/companyProfile/index.ts` exporting a typed `CompanyProfile` type and a `companyProfile` constant with `name`, `tagline` (one sentence), `services` (exactly three `{ title, description }` entries, one paragraph each), `about` (two to three paragraphs) and `team` (`{ name, role }` entries only), all filled with clearly-marked Indonesian placeholder text.
2. Write `index.test.ts` asserting exactly three services with non-empty title and description, two or three non-empty `about` paragraphs, and at least one team entry whose only keys are `name` and `role`.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

```
Provenance values:
  unit_id: U-002
  vault_sha256: 8b2467da2b9428545b2658e275ec9b299e561fb17b564538eeb0bb97818e6edf
  claims: (none cited)
  anchors_consulted: (none)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/configs/companyProfile/index.ts MUST exist after bolt
    - NEVER add a photo or image field to team entries (constitution D-002)
```

## Acceptance-test provenance NOTE

> NOTE: acceptance_test authored same-pass (_authored_by: absent — legacy unit, treated as same-pass) — it may share
> the spec's blind spots. Mark `confidence` no higher than MEDIUM for behaviors
> not directly tested; record doubts as `acceptance_test_concern` in bolt-report.md.

## Anti-context (negative space = freedom + protection)

DO NOT WRITE:
  - Tables without `id` primary key (denormalized intermediate tables OK as composite PK)  (from _universal.md §Forbidden patterns)
  - Tables without `created_at` + `updated_at` timestamps (unless explicitly immutable like audit logs)  (from _universal.md §Forbidden patterns)
  - VARCHAR(255) used as default type for everything (use proper sized/typed columns)  (from _universal.md §Forbidden patterns)
  - Comma-delimited values in single columns (use junction tables)  (from _universal.md §Forbidden patterns)
  - Date/time stored as VARCHAR/INT (use proper TIMESTAMP/DATETIME types)  (from _universal.md §Forbidden patterns)
  - Foreign keys without explicit constraint (`ON DELETE`/`ON UPDATE` defined)  (from _universal.md §Forbidden patterns)
DO NOT COMMIT IF: any `acceptance_test` command in this unit fails; any `## Hard rules` line above is violated; a modified file is missing its provenance trailer

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §A-002: Modul yang punya test sendiri berada di folder bersama test-nya (`foo/index.ts` + `foo/index.test.ts`); file tanpa test tetap flat (source: CLAUDE.md §Stack & Commands)
- §D-002: NEVER menampilkan foto tim — daftar tim hanya nama + peran (source: PRD §Halaman Tentang Kami)

(selector: `\b[A-F]-\d{3}\b` cited in U-002.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 5287 bytes (cap 12288)
consumed_t2: 549 bytes (cap 10240, hard 12288)
total: 5836 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 8586     bytes  # whole file incl. the un-budgeted blocks
truncations_applied:
  - (none)
```

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/bolts/U-XXX/bolt-report.md`
- Full constitution: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/constitution.md`
- Full framework pack: `/Users/<user>/.claude/plugins/cache/mega-sdd/mega-sdd/7.37.1/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- absent inputs (keys only — full reasons on stdout sections_omitted / --explain): confidence_labels, depends_on_summaries, design_slice, design_slice_path, framework_pack_rules, map_patterns, reuse_slice, starterkit_slice, symbol_slice, t1.anti_context.do_not_modify, t1.anti_context.do_not_modify.data_mutation_policy, t1.reuse_index_line, t3.kb_pointer
- unit_tier_xs: payload cuts per size-weighted spec §1b (validation_hints) — unit body verbatim, constitution + every gate uncut; per-key reasons on stdout sections_omitted (--explain)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
