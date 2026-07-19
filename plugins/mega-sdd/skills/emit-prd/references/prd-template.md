# PRD Template — Team-Readable Product Requirements Document

> **Canonical 6-section structure.** Consumed by `emit-prd/SKILL.md` Step 3 (assembly).
> Narrative is Indonesian + English technical terms; KB confidence markers
> `[VERIFIED]/[INFERRED]/[OPEN]` ride verbatim on claim lines (reverse mode).

## Contents

- Document control header
- Section 1 — Latar Belakang & Tujuan
- Section 2 — Aktor
- Section 3 — Kebutuhan Fungsional
- Section 4 — User Journey
- Section 5 — Kebutuhan Non-Fungsional
- Section 6 — Open Items
- Slot semantics
- Drift callout format

## Document control header (always emitted, not numbered)

```markdown
---
title: "{{project_name}} — Product Requirements Document (PRD)"
version: "{{source_version}}"
date: "{{generation_date_iso}}"
classification: "Internal"
mode: "{{emit_mode}}"          # forward | reverse
maturity: "draft-from-legacy"  # reviewed/final are HUMAN-set via refresh-doc-stamps.sh
mega_sdd_version: "{{plugin_version}}"
---

# {{project_name}} — PRD

**Mode:** {{emit_mode_label}} · **Maturity:** draft-from-legacy · **Tanggal:** {{generation_date_human}} · **Source:** `{{source_root}}` (sha256: `pending`)

---
```

The `pending` token on the `**Source vault:**`-class line is stamped by
`build-citation-map.sh --doc=prd`. The model fills NO sha256 slot anywhere.

**Marker legend (emit at top in reverse mode):**

```markdown
> **Legenda marker:** `[VERIFIED]` — terverifikasi di sumber legacy · `[INFERRED]` — inferensi dari kode, belum dikonfirmasi bisnis · `[OPEN]` — pertanyaan terbuka. Marker dibawa VERBATIM dari knowledge base; klaim `[INFERRED]/[OPEN]` bukan fakta yang sudah disepakati.
```

## Section 1 — Latar Belakang & Tujuan

```markdown
## 1. Latar Belakang & Tujuan

### 1.1 Latar Belakang
{{section-1-background}}

### 1.2 Tujuan
{{section-1-purpose}}

{{section-1-citations}}
```

## Section 2 — Aktor

```markdown
## 2. Aktor

| Aktor | Deskripsi | Sumber |
|---|---|---|
{{section-2-actors-table}}

{{section-2-citations}}
```

## Section 3 — Kebutuhan Fungsional

```markdown
## 3. Kebutuhan Fungsional

{{section-3-fr-content}}

{{section-3-citations}}
```

Reverse-mode requirement line format (marker VERBATIM + citation on the same line):

```markdown
- [INFERRED] <claim text> [Source: knowledge-base/<file>:L<n> (sha256: pending)]
```

## Section 4 — User Journey

```markdown
## 4. User Journey

{{section-4-journeys}}

{{section-4-citations}}
```

Per-journey format (MERMAID MANDATE — never prose-only, never ASCII):

```markdown
### UJ-<n> — <judul>

<1–2 kalimat pengantar>

<mermaid block — VERBATIM from source when a diagram exists>

[Source: <path> (sha256: pending)]
```

## Section 5 — Kebutuhan Non-Fungsional

```markdown
## 5. Kebutuhan Non-Fungsional

### 5.1 Performance
{{section-5-performance}}

### 5.2 Security
{{section-5-security}}

### 5.3 Availability
{{section-5-availability}}

### 5.4 Compliance & Lainnya
{{section-5-other}}

{{section-5-citations}}
```

## Section 6 — Open Items

```markdown
## 6. Open Items

> Bagian ini VIEW read-only — resolusi berjalan via `/mega-sdd:resolve-oq` (forward) atau Q&A `generate-intent --kb` (reverse); emisi berikutnya memantulkan hasilnya.

| ID | Pertanyaan / Item | Prioritas | Sumber |
|---|---|---|---|
{{section-6-open-items}}

{{section-6-citations}}
```

## Slot semantics

All `{{slot_name}}` markers MUST be filled OR explicitly stamped `[Pending — <source> not yet generated]`.
A leftover `{{slot}}` after assembly = halt `quality_gate_failed:template_slot_unfilled` (SKILL Step 4.5
in-skill grep — the PRD lane's slot scan; `validate-fsd-slots.sh` stays FSD-scoped per
`plugins/mega-sdd/references/emission-engine.md §P5 seams`).

Citation footers use the engine format:

```markdown
**Sources for this section:**
- [¹] `<source_path>:L<start>-L<end>` (sha256: `pending`)
```

## Drift callout format

```markdown
> ⚠ **Updated since last emit** — `<source_path>` was sha256 `<old-prefix>`, now `<new-prefix>`. Section regenerated.
```

Prefixes from `check-citation-drift.sh --doc=prd` output verbatim, never model-recalled.
