# PRD Section Mapping — Source Artifact → PRD Section

> **Per-section: source artifact(s) per mode, extraction rules, citation format, missing-source placeholders.**
> Consumed by `emit-prd/SKILL.md` Steps 2–3. **The MECHANICAL rules below are EXECUTED BY
> `scripts/build-prd-core.sh`** (tranche 5e) — it pre-fills those slots and leaves the
> genuinely-synthetic ones (`section-1-*` narrative, reverse-mode `section-2-actors-table`,
> diagram-less `journey-<slug>` slots) as `{{…}}` markers for the model. Editing a mechanical rule
> here MUST be mirrored in the builder — the two are one contract. This file is the PRD doc-pack's
> **section map** for the shared emission engine
> (`plugins/mega-sdd/references/emission-engine.md §What a doc-pack supplies`).

## Contents

- Mode determination (Step 0)
- Marker-preservation rule (reverse mode, binding)
- Section 1 — Latar Belakang & Tujuan
- Section 2 — Aktor
- Section 3 — Kebutuhan Fungsional
- Section 4 — User Journey
- Section 5 — Kebutuhan Non-Fungsional
- Section 6 — Open Items
- Citation map notes
- Maturity ladder

## Mode determination (Step 0)

```
IF a vault is present (vault.json OR 0[0-6]-*.md docs)     → mode = forward  (out-root = <vault>)
ELIF knowledge-base/README.md present (canonical → legacy) → mode = reverse  (out-root = <project>/.mega-sdd)
ELSE                                                        → halt dep_missing
```

`--mode=forward|reverse` overrides. KB path priority: `.mega-sdd/knowledge-base` →
`docs/knowledge-base` → `docs/mega-sdd/knowledge-base` → `old-reference/knowledge-base`.

## Marker-preservation rule (reverse mode, binding)

Every claim extracted from the KB carries its confidence marker **verbatim, on the same PRD line**,
with the KB citation:

```markdown
- [INFERRED] Approval berjalan dua level (maker-checker) — dua level ditemukan di kode, kebijakan tertulis tidak ditemukan. [Source: knowledge-base/10-domain/approval.md:L12 (sha256: pending)]
```

- `[VERIFIED]` claims may be narrated as fact (marker still shown).
- `[INFERRED]` / `[OPEN]` claims MUST read as inference/question — never as established requirement;
  the marker may not be dropped, merged into prose, or upgraded.
- Enforced deterministically by `scripts/check-prd-markers.sh` (SKILL Step 4.7): a PRD line citing a
  KB claim without that claim's marker → `MARKER_STRIPPED`; a marker the KB line does not carry →
  `MARKER_UPGRADED`; a file-level citation with no marker at all → `MARKER_MISSING`. Exit 1 → halt
  `quality_gate_failed:marker_stripped`.
- Mutability tiers (`[LOCKED]/[INTENT]/[ARTIFACT]`) are NOT carried into the PRD (they are rebuild
  vocabulary, not requirement confidence) — mentioning one in narrative is allowed, required nowhere.

## Section 1 — Latar Belakang & Tujuan

**Slots:** `{{section-1-background}}`, `{{section-1-purpose}}`
**Forward source:** `<vault>/01-overview.md` §Purpose + §Scope (+ §Goals for tujuan)
**Reverse source:** KB `README.md` (domain summary) + `00-overview/` or the KB's overview doc; system purpose claims with markers
**Extraction:** narasi Indonesia yang menganyam klaim sumber; reverse mode: claim lines keep markers per the rule above.
**Citation:** per-paragraph `[Source: <path>[:Ln] (sha256: pending)]`
**Missing:** `[Pending — vault/01-overview.md not yet generated]` / `[Pending — KB overview belum ada]`

## Section 2 — Aktor

**Slot:** `{{section-2-actors-table}}`
**Forward source:** `<vault>/01-overview.md` actors/roles + `<vault>/04-flows.md` flow participants; `_meta/squads.yaml` when present
**Reverse source:** KB domain files' actor/role claims (roles named in workflows, auth models)
**Extraction:** table `| Aktor | Deskripsi | Sumber |` — one row per actor actually named in a source; reverse rows carry markers in the Deskripsi cell.
**Missing:** `[Pending — belum ada aktor teridentifikasi di sumber]` (never invent an actor).

## Section 3 — Kebutuhan Fungsional

**Slot:** `{{section-3-fr-content}}`
**Forward source:** `<vault>/02-functional.md` FR-NNN headings (verbatim ids) + `04-flows.md` flow inventory
**Reverse source:** KB domain claim lists (per domain file) — requirement-shaped claims WITH markers
**Extraction:**
- Forward: per FR — id + title + 1–3 kalimat ringkas; per flow — id + judul (bukan diagram; §4 punya diagram).
- Reverse: grouped per KB domain (`### <domain>`); each requirement bullet = marker + claim text (source language kept for quoted fragments) + citation. `[OPEN]` claims land BOTH here (as open requirement) AND in §6.
**Citation:** per FR/claim line.
**Missing:** `[Pending — vault/02-functional.md not yet generated]` / `[Pending — KB domain files belum ada]`

## Section 4 — User Journey

**Slot:** `{{section-4-journeys}}`
**Forward source:** `<vault>/04-flows.md` — user-type flows (`F-U-*` first, then others)
**Reverse source:** KB workflow files (`stages:` blocks, mermaid diagrams)
**Extraction (MERMAID MANDATE — the Mermaid-flows hard rule):**
- A source diagram exists (vault flow body / KB workflow mermaid) → carry it **VERBATIM** — never redrawn.
- KB workflow WITHOUT a diagram → draw a NEW Mermaid flowchart strictly from the workflow's recorded steps/stages, cited to that file; steps not in the KB may not appear.
- NO journey may be prose-only or ASCII — every journey is a Mermaid block + 1–2 kalimat pengantar.
**Citation:** per-journey `[Source: <path> (sha256: pending)]`
**Missing:** `[Pending — belum ada flow/workflow di sumber]`

## Section 5 — Kebutuhan Non-Fungsional

**Slots:** `{{section-5-performance}}`, `{{section-5-security}}`, `{{section-5-availability}}`, `{{section-5-other}}` (the four category slots — template + builder)
**Forward source:** `<vault>/02-functional.md` §NFR + `_meta/constitution.md` LOCKED clauses
**Reverse source:** KB NFR/constraint claims (performance, security, compliance observations — usually `[INFERRED]` from code)
**Extraction:** per kategori (Performance / Security / Availability / Compliance); reverse rows keep markers.
**Missing:** per kategori `(belum terspesifikasi di sumber)` — do NOT halt.

## Section 6 — Open Items

**Slot:** `{{section-6-open-items}}`
**Forward source:** `<vault>/03-open-questions.md` / `vault.json.open_questions[]` — unresolved only
**Reverse source:** every KB `[OPEN]` claim + KB open-questions section
**Extraction:** table `| ID | Pertanyaan / Item | Prioritas | Sumber |`. **READ-ONLY VIEW** — the PRD is an output, never a decision surface: resolution happens via `/mega-sdd:resolve-oq` (forward) or during `generate-intent --kb` Q&A (reverse); the next emission reflects it.
**Missing:** `_(tidak ada open item di sumber)_`

## Citation map notes

`build-citation-map.sh --doc=prd` writes `<out-root>/prd/.citation-map.json` (schema 2.0 — the
`fsd_section` key name is schema-pinned across doc lanes). Resolution order vault/-prefix → vault
(out-root) → project → codebase-map; in reverse mode `knowledge-base/…` citations resolve under
`.mega-sdd/`. `[Pending — …]` markers land in `missing_sources[]`.

## Maturity ladder

`draft-from-legacy → reviewed → final` (engine registry). The emitter ALWAYS stamps
`draft-from-legacy` (the machine-draft rung — both modes; SKILL Step 6 via `refresh-doc-stamps.sh`).
`reviewed` and `final` are **human-set slots**: the user (or their reviewer) explicitly asks for the
bump / runs `refresh-doc-stamps.sh --doc=prd --maturity=reviewed|final` — the model never initiates
those rungs (a self-reviewed PRD would be a fabricated approval state, same class as a filled SIT
sign-off row).
