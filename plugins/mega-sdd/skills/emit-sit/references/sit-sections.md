# SIT Section Mapping — Source Artifact → SIT Section

> **Per-section: source artifact(s), extraction rules, citation format, missing-source placeholders.**
> Consumed by `emit-sit/SKILL.md` Step 2 (per-section emission loop). This file is the SIT doc-pack's
> **section map** for the shared emission engine (`plugins/mega-sdd/references/emission-engine.md`
> §What a doc-pack supplies).
>
> **The prime directive:** every table, TS scenario block, evidence row, and sign-off table is
> produced by `scripts/build-sit-evidence.sh` into `<vault>/sit/.sit-evidence.md` and included
> **VERBATIM** (delimiters `<!-- sit-evidence:§N -->` … `<!-- /sit-evidence:§N -->`). The model
> contributes ONLY the per-section Indonesian narrative paragraph. This is what makes SIT §4
> unfakeable: the evidence never passes through model text generation.

## Contents

- Maturity determination (Step 0)
- Multi-scope rules (decision 10)
- Section 1 — Ruang Lingkup Uji
- Section 2 — Skenario Uji
- Section 3 — Matriks Test Case
- Section 4 — Bukti Eksekusi
- Section 5 — Sign-off
- Citation notes
- Drift callouts

## Maturity determination (Step 0)

Script-computed by `build-sit-evidence.sh` (evidence coverage over B4 acceptance artifacts):

```
planned  — no unit has an acceptance.json
executed — every unit has acceptance.json with status "pass"
partial  — anything in between (some evidence, fails, pending_manual_only, unreadable)
```

Multi-scope merge takes the LOWEST rung across scopes (any evidence at all lifts `planned` → `partial`).
The verdict rides the script's stdout line (`maturity=<rung>`) and the fragment header comment; it feeds
`refresh-doc-stamps.sh --maturity=` (SKILL Step 6) and the doc frontmatter. The model never computes or
overrides it.

## Multi-scope rules (decision 10, locked)

ONE merged SIT for a multi-scope project: `--vaults=<v1>,<v2>` → `build-sit-evidence.sh --vault=<v1> --vault=<v2>`.

- Ids carry the scope when the vault's `vault.json scope_metadata.id` is set: `TS-BE-001` / `TC-BE-001`.
  Plain `TS-NNN` / `TC-NNN` for a single unscoped vault.
- §1/§3/§4 tables gain a leading `Scope` column; §5 emits one sign-off table PER scope
  (`### Sign-off — Scope <ID>`).
- The merged doc lands in the FIRST vault's `sit/` dir.

TS numbering: 1:1 from `F-*-NNN` — the flow's numeric part when unique within the vault; ordinal
fallback on a numeric collision (deterministic, script-owned).

## Section 1 — Ruang Lingkup Uji

**Slot:** `{{section-1-narrative}}` + fragment block §1
**Source:** `<vault>/04-flows.md` (F-* flows in scope) + `<vault>/_meta/modules.yaml` (module DoD)
**Fragment carries:** the TS ↔ F-id ↔ judul ↔ tipe ↔ DoD-count table + the per-module DoD list.
**Narrative (model):** 2–4 kalimat Indonesia — cakupan uji (flow apa saja, scope mana), dasar penurunannya (vault flows + module DoD), dan apa yang di luar cakupan.
**Missing source:** fragment emits `[Pending — vault/04-flows.md belum berisi flow F-*]` / the honest no-modules note — keep verbatim.

## Section 2 — Skenario Uji

**Slot:** `{{section-2-narrative}}` + fragment block §2
**Source:** `<vault>/04-flows.md` — one `TS-NNN` block per `F-*-NNN` flow (1:1)
**Fragment carries per TS:** heading `### TS-NNN — <judul> (F-id)`, the flow's **Mermaid diagram VERBATIM** (the Mermaid-flows hard rule extends to SIT — never redrawn, never prose-ified), and the flow's **DoD items VERBATIM** as expected outcomes (checkbox states preserved).
**Narrative (model):** 1–2 kalimat pembuka bagian (cara membaca skenario; hubungan TS ↔ flow). TIDAK per-TS — the TS blocks are self-contained.
**Missing source:** a flow without a Mermaid body → fragment's `[Pending — diagram Mermaid untuk F-X belum ada]`; without DoD → `[Pending — Definition of Done …]`. Keep verbatim.

## Section 3 — Matriks Test Case

**Slot:** `{{section-3-narrative}}` + fragment block §3
**Source:** every unit's `acceptance_test[]` frontmatter (structured authority — parsed with the SAME region extraction `run-acceptance-tests.sh` / `validate-unit-spec.sh` use)
**Fragment carries:** one TC row per acceptance entry with FULL traceability `TC ↔ TS ↔ F-id ↔ unit id` + tipe + perintah/deskripsi + expects. Unit→TS mapping via the unit's `vault_source:` F-id token.
**Narrative (model):** 1–2 kalimat — apa itu TC, dari mana barisnya berasal (unit acceptance_test), bagaimana traceability dibaca.
**Missing source:** unit without `acceptance_test` → `[Pending — U-XXX tanpa acceptance_test terstruktur]` row; unit whose flow is unmapped → cell-level Pending. Keep verbatim.

## Section 4 — Bukti Eksekusi

**Slot:** `{{section-4-narrative}}` + fragment block §4 — **THE UNFAKEABLE SECTION**
**Source (hook-guarded evidence artifacts, script-read only):**

1. `<vault>/bolts/U-*/acceptance.json` (B4, written by `run-acceptance-tests.sh`) → §4.1 per-entry rows: status / rc / retried / `output_head` RAW (decision 9 — unknown runner output recorded raw as evidence, counts never fabricated) + §4.2 `pending_manual` entries as manual-test rows awaiting human execution.
2. `<vault>/bolts/U-*/postflight.json` (B1, written by `run-postflight-scan.sh`) → §4.3 per-unit verdict rows.
3. `<vault>/bolts/_batch-suite.json` (B2, written by `run-full-suite.sh`) → §4.4 vault-level suite line.

**Fragment guarantees:** absent evidence → the literal `[Pending — bolt U-XXX belum dieksekusi]` row — NEVER an invented verdict; unreadable artifact → its own Pending row; evidence cells carry the artifact's raw values (head-truncated, markdown-escaped only).
**Narrative (model):** 2–3 kalimat — dari artifact mana bukti berasal (B4/B1/B2, hook-guarded), kenapa baris Pending dibiarkan (bolt belum jalan), dan bahwa tabel dilarang diedit manual.
**Missing source:** all-Pending is a VALID §4 (planned-maturity SIT).

## Section 5 — Sign-off

**Slot:** `{{section-5-narrative}}` + fragment block §5
**Source:** none — **paper-out** (decision 5, locked). The fragment emits one bank-style table per scope (`| Peran | Nama | Tanggal | Tanda tangan | Status |`) whose body rows are placeholder LITERALS:

- Nama / Tanggal / Tanda tangan: `__________`
- Status: `[ ] Diterima · [ ] Ditolak`
- Default roles: QA Lead, Dev Lead, Product Owner

**A model-filled sign-off row is a FABRICATED RECORD** — the worst possible failure in a bank context. Enforced deterministically: `build-sit-evidence.sh --check-signoff` (SKILL Step 4.7 gate + re-emission guard in Step 0) FAILs on any non-placeholder text in the Nama/Tanggal/Tanda-tangan/Status cells with `SIGNOFF_*` lines + Indonesian keterangan. The attested `uat-results.yaml` round-trip is a P10 candidate behind field demand — until then, approval happens by hand on the printed document.
**Narrative (model):** 1–2 kalimat — tabel diisi TANGAN oleh penanggung jawab pada dokumen cetak; baris placeholder tidak boleh diisi digital.

## Citation notes

- The fragment already carries per-section `**Sources for this section:**` footers with `(sha256: \`pending\`)` literals — `build-citation-map.sh --doc=sit` (SKILL Step 4.6) stamps them and writes `<vault>/sit/.citation-map.json`. §4 cites ONLY evidence artifacts that exist (a citation to an absent file would be a deterministic `citation_unresolvable` halt — the Pending rows are the honest representation of absence).
- `[Pending — …]` markers land in the map's `missing_sources[]` (script-derived; surfaced by orchestrate-flow's final summary).

## Drift callouts

On re-emit, `check-citation-drift.sh --doc=sit` lines (`DRIFT`/`GONE`) mark sections for a callout block quote BEFORE the section content, using the script's `old12`/`new12` verbatim (same format as `emit-fsd/references/fsd-template.md §Drift callout format`). Typical SIT drift: `04-flows.md` changed after the last emit (scenarios stale) or an `acceptance.json` re-recorded (evidence superseded).
