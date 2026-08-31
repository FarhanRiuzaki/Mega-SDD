# Architecture advisor — target-architecture consultation on top of a KB

Load this when the user asks what the TARGET architecture of a rebuild should be
and an extract-intelligence KB exists (offered at the extract-intelligence
hand-off; also loadable on demand). Spec: `docs/superpowers/specs/2026-08-31-architecture-advisor.md`.

> **THE RAIL (read first): the advisor proposes, the human decides — always.**
> Every recommendation claim MUST cite either a KB artifact (`file:line` /
> PRD-kontrak section) or a recorded census answer. A fact that is neither in
> the KB nor answered by the human is an OQ — never an assumption, never a
> free-floating "best practice". The advisor NEVER auto-writes an accepted ADR.

> **Output language (Tier-3):** consultation prose, options, and ADR narrative →
> Indonesian + English technical terms (precedence per
> `plugins/mega-sdd/references/output-language.md`). Tier-1 tokens stay English
> (`[LOCKED]`/`[INTENT]`/`[ARTIFACT]`, `Status:`, IDs, paths).

## Contents

- §Step 1 — Evidence digest (what the code CAN tell you)
- §Step 2 — Constraint census (what the code CANNOT tell you)
- §Step 3 — Options (2–3, evidence-scored, Mermaid mandatory)
- §Step 4 — Decision → ADR
- §ADR template
- §Downstream contract

## Step 1 — Evidence digest (what the code CAN tell you)

Derive, from the KB alone, the constraints that are VISIBLE in the legacy system.
Every bullet carries a citation. Cover at least:

| Constraint class | Where it hides in a KB |
|---|---|
| Module coupling | shared DB objects / cross-module calls named in the per-module PRDs (e.g. "AR and GL share 47 stored procedures") |
| Volume & load signals | batch sizes, table roles, pagination/queue patterns cited in flows |
| Batch windows | EOD/EOM jobs, ordering dependencies between them |
| External integrations | third-party endpoints, file drops, host/gateway calls |
| Regulatory surfaces | reporting flows, audit-trail rules — usually `[LOCKED]`-dense |
| `[LOCKED]` density map | which modules carry the most must-preserve-1:1 rules (they resist re-architecture the hardest) |

Output: a short **Evidence digest** table in chat (constraint → finding → citation).
No target-architecture talk yet — digest first, options later.

## Step 2 — Constraint census (what the code CANNOT tell you)

The other half of any architecture decision is invisible to extraction. Ask the
human — `AskUserQuestion`, batched, **keterangan per option in Indonesian**
(the OQ-keterangan contract: question text + why it matters + what each option
implies). Minimum census:

1. **Tim** — ukuran, skill stack saat ini, kapasitas belajar stack baru.
2. **Kematangan ops** — siapa yang jaga produksi? Ada on-call? Pengalaman container/k8s, atau VM+IIS klasik?
3. **Hosting & regulator** — on-prem wajib? Cloud yang diizinkan? Aturan data residency.
4. **Budget & timeline** — deadline keras? Anggaran infra berubah atau tetap?
5. **Koeksistensi** — sistem lama & baru jalan bareng (strangler, per-module cutover) atau big-bang? Berapa lama masa transisi yang bisa diterima ops?
6. **Target NFR** — latensi, volume growth, jam operasional, RTO/RPO — angka, atau jujur "belum tahu".

Record every answer verbatim. Unanswered → **OQ with `deferred`** in the ADR's
Open questions section — never silently filled in.

## Step 3 — Options (2–3, evidence-scored)

Present **2–3 named options** (e.g. "Modular monolith .NET 8", "Service split per
bounded context", "Rehost + refactor incremental"). For EACH option:

- **Topology** — a **Mermaid diagram** (mandatory — every generated flow/topology
  in this plugin is Mermaid, never ASCII/prose).
- **Stack candidates** — concrete, with the project-pack note: a stack outside the
  shipped framework packs needs a project pack at `.mega-sdd/packs/` (+ its
  `## Toolchain` block so the L0 gates are live from unit one).
- **Fit table** — one row per Step-1 finding AND per Step-2 census answer:
  how this option scores against it, with the citation. A constraint the option
  fights (e.g. heavy cross-module SP coupling vs a service split) is stated as a
  cost, not smoothed over.
- **Risks & migration path** — including the data/coexistence story.

A recommendation is allowed and useful — mark it explicitly as **Rekomendasi**
with its two or three decisive citations. Live research (context7 / web) may
sharpen stack candidates; it never substitutes for a census answer.

## Step 4 — Decision → ADR

Put the decision to the user (`AskUserQuestion`, one option per architecture,
keterangan = the fit-table summary). Then write
`<kb>/decisions/ADR-NNN-<slug>.md` (NNN = next free number):

- User picked → `Status: accepted`.
- User defers → `Status: proposed` + the blocking OQs listed. A `proposed` ADR
  is NOT a decision — downstream treats it as open.

## ADR template

```markdown
# ADR-001 — <judul keputusan>

Status: accepted | proposed
Tanggal: <YYYY-MM-DD>
Diputuskan oleh: <nama/peran manusia>

## Context (bersitasi)
<Temuan Step 1 + jawaban census Step 2 yang menentukan — tiap butir dengan
sitasi KB atau "census: <pertanyaan> → <jawaban>">

## Decision
<Arsitektur target terpilih, satu paragraf + diagram Mermaid>

## Options considered
<Tiap opsi yang ditolak: satu paragraf + alasan tolak bersitasi>

## Consequences
<Yang jadi lebih mudah, yang jadi lebih sulit, utang yang diterima secara sadar>

## Claims ([INTENT] — dikonsumsi generate-intent --kb)
- [INTENT] <klaim arsitektur target, mis. "Modul acquisition berjalan sebagai
  module dalam modular monolith .NET 8, boundary per bounded context"> [Source: ADR-001]
- [INTENT] ...

## Open questions
- <OQ census yang deferred, prioritas + siapa yang bisa jawab>
```

## Downstream contract

- `generate-intent --kb` consumes `decisions/ADR-*.md` with `Status: accepted`
  as a legitimate input document (a recorded human decision — same source class
  as a PRD); vault claims born from it cite the ADR. `Status: proposed` is never
  consumed as a decision — it surfaces as an OQ.
- The ADR lives in the KB dir so every downstream KB probe finds it; it is a
  decision record, NOT extraction output — the census gate does not count it.
