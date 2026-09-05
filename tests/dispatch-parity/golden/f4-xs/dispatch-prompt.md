═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-005
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-005

UNIT: U-005 "Tambah kolom keterangan di tabel laporan harian"
SCOPE: S-01 (Laporan) — framework: _universal.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-005
title: Tambah kolom keterangan di tabel laporan harian
task_type: create
scope: S-01
scope_name: Laporan
module: laporan
risk: low
status: pending
target_files:
  - path: app/Views/laporan/harian.php
    operation: modify
acceptance_test:
  - command: "php tests/laporan/harian_keterangan_test.php"
    expects: "OK"
    _authored_by: same-pass
---

## Goal

Tambah kolom `keterangan` di tabel laporan harian.

## Context (read first)

Tabel laporan harian di app/Views/laporan/harian.php menampilkan kolom tanggal,
nominal, dan status. Kolom keterangan sudah tersedia di query (C-014); hanya
render yang belum ada. Tidak ada perubahan skema atau query.

## Implementation steps

1. Tambah header kolom `Keterangan` setelah kolom Status.
2. Render field `keterangan` per baris dengan escape HTML.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Out of scope

- Filter/sort berdasarkan keterangan.

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v@VER@)

## Provenance values (per-dispatch)

```
Provenance values:
  unit_id: U-005
  claims: (none cited)
  anchors_consulted: (none)
  hard_rules_active: (none)
```

## Acceptance-test provenance NOTE

> NOTE: acceptance_test authored same-pass (_authored_by: same-pass) — it may share
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
DO NOT COMMIT IF: any `acceptance_test` command in this unit fails; a modified file is missing its provenance trailer

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Design system (UI-bearing unit — per context-enrichment.md §Design slice)


No design_system in this vault — raise it as an OQ at chain end; do not invent a palette or a type pairing.

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: @N@ bytes (cap 12288)
consumed_t2: 191 bytes (cap 10240, hard 12288)
total: @N@ bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: @N@     bytes  # whole file incl. the un-budgeted blocks
truncations_applied:
  - (none)
```

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `@PROJ@/.mega-sdd/vaults/v1/bolts/U-XXX/bolt-report.md`
- Full constitution: `@PROJ@/.mega-sdd/vaults/v1/constitution.md`
- Full framework pack: `@PLUGIN@/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- absent inputs (keys only — full reasons on stdout sections_omitted / --explain): confidence_labels, constitution_clauses, depends_on_summaries, design_slice.system, framework_pack_rules, map_patterns, provenance.vault_sha256, reuse_slice, starterkit_slice, symbol_slice, t1.anti_context.do_not_modify, t1.anti_context.do_not_modify.data_mutation_policy, t1.reuse_index_line, t3.kb_pointer
- unit_tier_xs: payload cuts per size-weighted spec §1b (design_slice->floor, validation_hints) — unit body verbatim, constitution + every gate uncut; per-key reasons on stdout sections_omitted (--explain)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
