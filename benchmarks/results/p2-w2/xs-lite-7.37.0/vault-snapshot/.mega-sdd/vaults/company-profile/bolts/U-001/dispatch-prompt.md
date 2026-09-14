═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-001
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-001

UNIT: U-001 "Loloskan halaman profil publik di route guard proxy"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)

---

id: U-001
title: Loloskan halaman profil publik di route guard proxy
prd_source: [PRD/prd-company-profile.md#latar-belakang, PRD/prd-company-profile.md#ruang-lingkup]
context_source: context.md#Constraints
task_type: extend
grounding_confidence: MEDIUM
module: M-default
depends_on: []
target_files:

- path: src/proxy.ts
  operation: modify
- path: src/proxy.test.ts
  operation: create
  existing_interfaces:
- file: src/proxy.ts
  symbol: proxy
  note: "tetap `export async function proxy(request: Request)` + `export const config` (matcher) tidak berubah"
  allowed_new_deps: []
  acceptance_test:
- type: test
  command: "pnpm test:run src/proxy.test.ts"
  expects: "passed"
  binding_refs: [OQ-AR-2]

---

# Unit U-001 — Loloskan halaman profil publik di route guard proxy

## Goal

`/beranda`, `/tentang-kami`, `/kontak` bisa dibuka tanpa sesi dan tidak membounce user yang sudah login.

## Context (read first)

PRD menyatakan halaman profil publik tanpa login (context.md#Constraints), tetapi `proxy()` saat ini mengalihkan semua route selain `/login` dan `/register` ke `/login`. Path mengikuti rekomendasi OQ-AR-2.

## Anchors

- src/proxy.ts:11 — daftar `publicRoutes` yang sekarang hanya `/login`, `/register`
- src/proxy.ts:24 — user login di route publik dibounce ke `/home` (perilaku ini khusus halaman auth)
- src/proxy.ts:28 — user tanpa sesi di route non-publik dialihkan ke `/login`

## Claims

- C-U001-01 "proxy() hanya meloloskan /login dan /register tanpa sesi" — expect: src/proxy.ts:proxy
- C-U001-02 "belum ada test untuk proxy" — expect: src/proxy.test.ts — must-not-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md#Constraints — stack existing (package.json); allowed_new_deps: []
- DO NOT modify next.config.ts
  Source: OQ-AR-2 recommendation — redirect / → /home tidak diubah
- file src/proxy.test.ts MUST exist after bolt
  Source: frontmatter acceptance_test; constitution.md §A-003
- ALWAYS keep src/proxy.test.ts beside src/proxy.ts because proxy.ts is a reserved Next.js 16 filename
  Source: constitution.md §A-002

## Implementation steps

1. Di `src/proxy.ts`, tambahkan daftar terpisah untuk halaman profil publik (`/beranda`, `/tentang-kami`, `/kontak`) yang lolos baik dengan maupun tanpa sesi, sehingga cabang bounce `/home` di baris 24 tetap hanya berlaku untuk `/login` dan `/register`.
2. Tulis `src/proxy.test.ts` (Vitest, `// @vitest-environment node`) yang me-mock `getServerSession` dari `next-auth`: tanpa sesi → tiga halaman publik lolos, `/users` dialihkan ke `/login`; dengan sesi → tiga halaman publik lolos, `/login` dialihkan ke `/home`.

## Migration notes

- **REMOVE**: tidak ada.
- **KEEP**: `publicRoutes` `/login` + `/register` beserta bounce ke `/home` untuk user login; cabang `RefreshTokenError` (hapus cookie + redirect); `export const config` matcher.
- **ADD**: daftar halaman profil publik `/beranda`, `/tentang-kami`, `/kontak` yang dilewati guard tanpa bounce.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.0)

## Provenance values (per-dispatch)

```
Provenance values:
  unit_id: U-001
  vault_sha256: c41836e0b3f24c9d00828b99f03dc0569b5f77cdf5cdb3e190d15946c4df9b8e
  claims: (none cited)
  anchors_consulted:
    - src/proxy.ts:11
    - src/proxy.ts:24
    - src/proxy.ts:28
  anchors_verified: 3/3 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify next.config.ts
    - file src/proxy.test.ts MUST exist after bolt
    - ALWAYS keep src/proxy.test.ts beside src/proxy.ts because proxy.ts is a reserved Next.js 16 filename
```

## Acceptance-test provenance NOTE

> NOTE: acceptance_test authored same-pass (\_authored_by: absent — legacy unit, treated as same-pass) — it may share
> the spec's blind spots. Mark `confidence` no higher than MEDIUM for behaviors
> not directly tested; record doubts as `acceptance_test_concern` in bolt-report.md.

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY:

- next.config.ts (source: U-001.md `## Hard rules`)
  DO NOT WRITE:
- Tables without `id` primary key (denormalized intermediate tables OK as composite PK) (from \_universal.md §Forbidden patterns)
- Tables without `created_at` + `updated_at` timestamps (unless explicitly immutable like audit logs) (from \_universal.md §Forbidden patterns)
- VARCHAR(255) used as default type for everything (use proper sized/typed columns) (from \_universal.md §Forbidden patterns)
- Comma-delimited values in single columns (use junction tables) (from \_universal.md §Forbidden patterns)
- Date/time stored as VARCHAR/INT (use proper TIMESTAMP/DATETIME types) (from \_universal.md §Forbidden patterns)
- Foreign keys without explicit constraint (`ON DELETE`/`ON UPDATE` defined) (from \_universal.md §Forbidden patterns)
  DO NOT COMMIT IF: any `acceptance_test` command in this unit fails; any `## Hard rules` line above is violated; a modified file is missing its provenance trailer

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §A-002: Modul yang punya test hidup di folder bersama test-nya (`foo/index.ts` + `foo/index.test.ts`); file tanpa test tetap flat; nama file reserved Next.js (`page.tsx`, `route.ts`, `proxy.ts`) tetap di tempatnya (source: CLAUDE.md §Stack & Commands)
- §A-003: Test memakai Vitest + React Testing Library + MSW dari harness `src/test/`; `pnpm test:run` harus lulus (source: CLAUDE.md §Stack & Commands)

(selector: `\b[A-F]-\d{3}\b` cited in U-001.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

### Existing symbols (REUSE — extend, don't recreate)

index@3d4b9265 · 592 symbols · built by scripts/build-symbol-index.sh

- src/proxy.ts:7 typescript-function `proxy` — async function proxy(request: Request) {

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 6075 bytes (cap 12288)
consumed_t2: 889 bytes (cap 10240, hard 12288)
total: 6964 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 9669     bytes  # whole file incl. the un-budgeted blocks
truncations_applied:
  - (none)
```

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/bolts/U-XXX/bolt-report.md`
- Full constitution: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/constitution.md`
- Full framework pack: `/Users/<user>/.claude/plugins/cache/mega-sdd/mega-sdd/7.37.0/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- absent inputs (keys only — full reasons on stdout sections_omitted / --explain): confidence_labels, depends_on_summaries, design_slice, design_slice_path, framework_pack_rules, map_patterns, reuse_slice, starterkit_slice, t1.anti_context.do_not_modify.data_mutation_policy, t1.reuse_index_line, t3.kb_pointer
- unit_tier_xs: payload cuts per size-weighted spec §1b (validation_hints) — unit body verbatim, constitution + every gate uncut; per-key reasons on stdout sections_omitted (--explain)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
