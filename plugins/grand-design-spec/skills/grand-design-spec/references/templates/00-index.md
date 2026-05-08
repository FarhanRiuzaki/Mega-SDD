# <Project Name> — Grand Design

> 1-line product description (mirror dari 01-overview.md).

## Vault Lock Status

- **Vault version**: v1.0
- **Project shape**: `mobile-app` | `web-app` | `api-only` | `multi-platform` | `data-pipeline` | `custom: <description>`
- **Implementation mode**: `new` | `existing`
- **PRD status**: `final` (signed-off by stakeholder) | `draft` (still in flux)
- **Locked at**: YYYY-MM-DD HH:MM (TZ)
- **Locked by**: <PM name>, <Architect name>, <Tech Lead name>
- **PRD source**: <filename, version, date> — <FINAL | DRAFT>
- **Status**: 🔒 LOCKED for <scope, e.g. "sprint 1 implementation"> | ⚠️ DRAFT (not locked yet)

> **PRD status semantics**:
> - `final` → vault was generated under the assumption PRD is locked. All gaps captured as Open Questions; user triages OQ list with stakeholder offline.
> - `draft` → vault may have been paused mid-generation for clarification; some gaps may have been resolved inline before generation completed.

> Vault ini adalah **lock terhadap requirement** (PRD/BRD), bukan terhadap codebase. Setiap perubahan vault setelah lock = bump version + append Changelog + re-sign-off oleh stakeholder yang relevan. Dev/AI consumer WAJIB cek versi vault yang dipakai.

## Changelog

### v1.0 (YYYY-MM-DD)
- Initial vault generated from PRD <version> <date>.
- Mode: <new | existing>.

<!-- Tambahkan entry baru di atas saat vault revisi:
### v1.1 (YYYY-MM-DD)
- <changes>
-->

## Executive Summary

<3–4 kalimat: apa produknya, kenapa di-build, dan kondisi project saat ini. Ditulis dengan asumsi pembaca first-time, gak punya konteks. Bahasa natural, no jargon.>

## Project Readiness Status

| Item | Status |
|------|--------|
| PRD | ✅ Complete / 🟡 Draft / 🔴 Pending |
| Figma | ✅ Complete / 🟡 Pending review / ⚪ Not consumed |
| Tech stack | ✅ Defined / 🔴 TBD |
| Sign-off | X / Y stakeholders |
| Open Questions | P1: {n} · P2: {n} · P3: {n} |

> Status ini snapshot saat doc generate. Update tiap iterasi review.

## Reading paths by role

> Roles dan paths derived from `Project shape` (lihat Vault Lock Status di atas).
> Replace examples below dengan roles & anchors yang sesuai shape project ini.
>
> Common patterns:
> - **mobile-app**: Architect / Mobile Dev / BE Dev / QA / PM / UI/UX
> - **web-app**: Architect / FE Dev / BE Dev / QA / PM / UI/UX
> - **api-only**: Architect / BE Dev / QA / PM / External integrator
> - **multi-platform**: Architect / FE Dev / Mobile Dev / BE Dev / QA / PM / UI/UX
> - **data-pipeline**: Architect / Data Engineer / QA / PM / Data analyst
> - **custom**: roles per user description
>
> Anchor links bisa langsung jump ke section relevan tanpa baca seluruh doc.

Examples (sesuaikan dengan PROJECT_SHAPE):

- **IT Architect / Tech Lead**: `02-architecture.md` (full) → `03-data-model.md` → `05-decisions.md` → `06-constraints.md`
- **<Layer-specific Dev, e.g. "Backend Developer">**: `02-architecture.md#<layer-anchor>` → `03-data-model.md` → `04-flows.md#<flow-type-anchor>`
- **QA**: `04-flows.md` (semua section, focus Definition of Done per flow)
- **PM / Business Owner**: `00-index.md` → `01-overview.md` → `05-decisions.md`
- **<UI/UX or other UI-relevant role, kalau project punya UI>**: `01-overview.md` → `04-flows.md#<user-flow-anchor>`

- **UI/UX or FE Dev** (v0.6, conditional): `01-overview.md` → `02-architecture.md#ui-components-patterns` → `06-constraints.md#design-system` → `04-flows.md`

  > **Conditional**: muncul hanya kalau vault punya minimal salah satu dari `02-architecture.md#ui-components-patterns` atau `06-constraints.md#design-system` (i.e., Step 2 detection nemu source eksplisit). Kalau dua-duanya absent, hapus reading path ini.

## Reading order (full)

1. `01-overview.md` — apa, untuk siapa, kenapa, success metrics
2. `02-architecture.md` — komponen sistem (per layer), API contracts
3. `03-data-model.md` — entitas, relasi, constraint
4. `04-flows.md` — user flows, backend flows, cross-cutting flows + Definition of Done
5. `05-decisions.md` — keputusan teknis & alasannya (ADR-lite)
6. `06-constraints.md` — batasan teknis, bisnis, NFR

## Anti-hallucination rules untuk dev / dev AI

Dokumen ini adalah **single source of truth terhadap requirement**. Saat ngerjain:

1. **Kalau ada requirement yang TIDAK tertulis di sini → STOP, tanya ke human / PM. Jangan infer, jangan pakai "best practice default".**
2. **Kalau dua doc kelihatan conflicting → STOP, surface conflict-nya.**
3. **Kalau flow tidak punya Definition of Done → STOP, jangan tandai complete.**
4. **Open Questions di bawah adalah blocker.** Wajib dijawab oleh stakeholder sebelum kerjaan terkait dimulai.

## Implementation Notes for AI Consumers (Claude Code, Cursor, dst)

> Section ini khusus untuk AI dev tools yang baca vault ini sebagai source of truth saat write/modify code.

**Vault metadata**:
- Project shape: <set per Vault Lock Status di atas — drives which layers/flows exist>
- Implementation mode: <set per Vault Lock Status di atas>
- PRD status: <set per Vault Lock Status di atas — `final` means OQ list is the authoritative gap list, no synchronous stakeholder clarification expected>
- Vault version: <set per Vault Lock Status di atas>

### WAJIB sebelum write/modify code apapun

1. **Konfirmasi project shape & mode dengan user**:
   - Tanya: *"Vault ini bilang shape `<shape>` dan mode `<mode>`. Lo lagi work di project yang sesuai?"*
   - Kalau mismatch → STOP, eskalasi.

2. **Untuk mode `existing`** — tambahan WAJIB:
   - Tanya user: *"Kasih path/struktur singkat existing codebase (e.g. project root, framework, tabel utama yang relevan), atau confirm gue scan dulu sebelum lanjut."*
   - **Cross-check entities** (`03-data-model.md`) dengan existing schema:
     - Entity baru di vault, gak collide nama dengan existing → safe to create.
     - Entity vault yang nama-nya sama dengan existing → STOP, klarifikasi extend vs replace.
   - **Cross-check flows** (`04-flows.md`) dengan existing routes/handlers/cron:
     - Flow baru, gak collide → safe to add.
     - Flow yang touch existing endpoint/job → STOP, klarifikasi extend vs replace.
   - **Cross-check decisions** (`05-decisions.md`) dengan existing patterns:
     - Decision yang **conflict** dengan existing pattern → STOP, eskalasi ke architect untuk transition plan.

3. **Untuk mode `new`** — masih ada cek:
   - Konfirmasi tech stack dari vault dengan user (vault `02-architecture.md` mungkin masih ada Open Questions di stack).
   - Kalau Open Questions P1 belum di-resolve → STOP, jangan auto-pick stack default.

4. **Use the relevant layer section based on what you're implementing**:
   - Working on backend → fokus `02-architecture.md#backend` + `04-flows.md` backend section.
   - Working on UI (mobile/web) → fokus relevant UI layer in `02-architecture.md` + user flows in `04-flows.md`.
   - Cross-cutting feature → cek cross-cutting flows section + multiple layer sections.

### Selama implement

- **Gak boleh inject requirement** yang gak ada di vault. Kalau butuh requirement baru → STOP, append ke `## Open Questions` di doc relevan, ask user.
- **Gak boleh skip Definition of Done**. Setiap flow yang lo implement, validate DoD sebelum mark complete.
- **Cite vault** di commit message atau code comment kalau touch business logic — e.g. `// Per vault 04-flows.md F-U-001 step 5`.

### Saat encounter inconsistency

- Vault internal conflict (mis. doc 03 vs doc 04) → STOP, surface ke user dengan quote dari kedua side.
- Vault vs existing code conflict → STOP, ke user. Tunjukkan quote vault + existing code reference.
- Vault vs PRD asli (kalau user kasih akses PRD) → STOP, ke user. Vault should reflect PRD; kalau nggak, vault stale.

## Glossary

Istilah & singkatan yang dipakai lintas-doc:

| Term | Definisi |
|------|----------|
| ADR | Architecture Decision Record — catatan keputusan teknis dengan context, decision, consequences |
| DBML | Database Markup Language — text format untuk define schema database |
| DoD | Definition of Done — kriteria observable yang menandakan flow/task selesai |
| FK | Foreign Key |
| NFR | Non-Functional Requirement — performance, availability, security, dst |
| OQ | Open Question — ambiguity yang perlu dijawab stakeholder |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |
| SLO | Service Level Objective |
| design tokens (v0.6, cond.) | Named design values (color, typography, spacing) shared across components. Source-mirrored from Figma variables / tokens.json / PRD. |
| design system (v0.6, cond.) | Set of components + tokens + a11y + voice rules that constrain UI implementation. |
| WCAG (v0.6, cond.) | Web Content Accessibility Guidelines — international standard for a11y. Vault uses level only if source explicitly states. |
| a11y (v0.6, cond.) | Numeronym for "accessibility" (a + 11 letters + y). |
| semantic HTML (v0.6, cond.) | Use of meaningful HTML elements (`<button>`, `<nav>`, `<main>`, etc.) for accessibility and structure. |

> Tambahkan istilah produk-spesifik dari PRD di sini (misal: MPIN, CIF, OTP, parameterized, dll).

> **v0.6 conditional entries**: `design tokens`, `design system`, `WCAG`, `a11y`, `semantic HTML` muncul hanya kalau term-nya dipakai di vault lain (yaitu `02-architecture#ui-components-patterns` atau `06-constraints#design-system` muncul). Kalau gak dipakai, hapus baris-baris bertanda `(v0.6, cond.)`.

## Open Questions (roll-up)

> Total: **{N} Open Questions** dari 6 doc. Diurutkan per kategori (by topic, not by doc), sorted P1 → P2 → P3 within each.

### {Category 1 — e.g. Inkonsistensi PRD} (PRIORITY-1)

- [ ] **OQ-DM-1** [P1]: <text> `[03-data-model.md]`
- [ ] **OQ-FL-1** [P1]: <text> `[04-flows.md]`

### {Category 2 — e.g. Tech stack & arsitektur} (PRIORITY-1)

- [ ] **OQ-AR-1** [P1]: <text> `[02-architecture.md]`
- [ ] **OQ-AR-2** [P1]: <text> `[02-architecture.md]`

### {Category 3 — e.g. Data model details} (PRIORITY-2)

- [ ] **OQ-DM-2** [P2]: <text> `[03-data-model.md]`

> Add categories as needed. Suggested: Inkonsistensi PRD, Tech stack & arsitektur, Data model, Flow & timing, Decisions, Constraints/sign-off/NFR/compliance, Overview & metrics.

## Source documents

- **PRD**: <filename / version / date YYYY-MM>
- **BRD**: <filename / version / date YYYY-MM>
- **Figma**: <URL or frame set name>
- **Other**: <existing system docs, dll>

## Last updated

YYYY-MM-DD

> **Date format convention**: `Last updated` pakai `YYYY-MM-DD` (precision). Decision dates / PRD version refs di doc lain pakai `YYYY-MM` (sprint/version granularity).
