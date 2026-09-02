# Output language — default Indonesian-mix, extensible

mega-sdd's **runtime output** defaults to **Indonesian, mixing English technical terms per context**, so an Indonesian team gets native-language explanations out of the box. Non-Indonesian users stay fully served and any language works — the model is natively multilingual, so this is a *policy* + a do-not-translate list, **not** a string catalog.

This file is itself an English directive doc (it mandates Indonesian output but is not itself translated). It is loaded on demand; the always-injected anchor carries the short policy + precedence.

## Precedence (resolve output language in this strict order)

1. **Explicit request this session** ("use English", "pakai bahasa Jawa") — wins over everything until the user changes it.
2. **The language the user is writing in** — English message → narrate English; another language → mirror it.
3. **Indonesian default** — only for short / ambiguous / mixed-or-tokenless input (`gas`, `go`, `next`, `lanjut`, `ok`, `proceed`).

**Tier-1 technical tokens stay English in ALL cases** (list below). This ordering is what serves non-ID users: an English-writing user gets English by rule (2), never a wall of Indonesian.

Reasoning language is **unchanged** (skills reason in English internally); only *output* language changes. The two are independent.

## The 3 tiers

| Tier | What | Language |
|---|---|---|
| **1 — Frozen** | structural / machine-parsed tokens (census below) | **English always** |
| **2 — Narration** | run-time chat: announcements, halt / propose-confirm prose, recommendations, progress, questions | **Indonesian-mix (default), per precedence** |
| **3 — Artifact** | emitted docs | **per-audience** (table below) |

## Tier-1 — do-not-translate census

These are English words sitting in machine-parsed positions; every one is parser- or test-pinned, so translating one is a hard FAIL at an artifact gate (e.g. `validate-unit-spec.sh` rejects `task_type: verifikasi`), not a silent moat breach.

- **Verdicts & IDs:** `CONFIRMED` / `CONFLICT` / `OQ`; `C-NNN` / `CONFLICT-N` / `OQ-N` / `OQ-AR-N` / `FR-N` / `BR-N` / `D-N` / `F-N`.
- **Enums:** Implementation-State `IMPLEMENTED` / `PARTIAL_FIELDS_*` / `NEW` / `UNKNOWN`; confidence `high|medium|low` + `HIGH|MEDIUM|LOW`; `task_type` `create|extend|verify`; OQ `category` `business|tech` + `resolution_mode`; validator `PASS|FAIL`; mode `new|existing`; drift verdicts `KEEP_VAULT|KEEP_CODE|DEFER|SPLIT`.
- **Model-authored enums that look like prose but are validator-pinned** (highest translation risk — the model writes these, so the "script-emitted" carve-out below does NOT protect them): extract-census gate status `PASS|FAIL|SKIP` (`validate-extract-census.sh`); handoff `status` values (`validate-handoff-yaml.sh`); bolt acceptance verdicts incl. the lowercase set `pass|passed|ok` (`validate-bolt-artifacts.sh`). These stay English verbatim even when the surrounding narration is Indonesian.
- **Markers:** mutability `[LOCKED]` / `[INTENT]` / `[ARTIFACT]`; confidence `[VERIFIED]` / `[INFERRED]` / `[OPEN]`; OQ priority `P1` / `P2` + status `[~]` / `[ ]` / `[x]`.
- **Halt vocabulary:** escalation tiers `C1` / `C2` / `C3`; halt-type vocabulary (`conflict_unresolved`, `missing_*`, `test_fail`, `bind_conflict`, …) + all JSON / frontmatter **field names**.
- **Anti-halu & provenance:** placeholders `[Pending — X]` / `_None detected_`; citation `sha256:` stamp + `[Source: <path>]`; generator directives `<!-- compact-skip -->` / `<!-- full-only -->`; `generated_by:` marker; status `draft|locked`.
- **Doc structural spine** (parsed by validators / wikilinks): section headers (`## Purpose`, `## NFR`, `^FR-\d+`, `Implementation State Map`, `Open Questions`, `## Conflicts` / `### CONFLICT`, the KB 11-section header spine); `[[doc#Header]]` wikilink targets; DBML `Table … { }` blocks; KB `stages:` YAML + mermaid enums; the lock values machine-read by `derive-vault-json.sh` (W5), dual-layout — layout-2: the six `vault.md` frontmatter scalars `vault_version` / `project_shape` / `implementation_mode` / `mode_migrate_after` / `prd_status` / `output_mode` (+ the hard-header anchors `## Overview` / `## Architecture` / `## Decisions`, which the parsers exit-2 on); legacy: the six `00-index.md` Vault Lock Status bold-bullet keys (`**Vault version**` / `**Project shape**` / `**Implementation mode**` / `**Mode migration trigger**` / `**PRD status**` / `**Output mode**` — the `**History**` bullet is deliberately NOT machine-read and stays unpinned); the `flows.md` (legacy `04-flows.md`) `**Definition of Done**:` / `**Source**:` / `**_kb_source**:` labels, the `vault.md ## Decisions` (legacy `05-decisions.md`) `**Status**:` label, and the `// Purpose:` DBML comment token; the `flows.md` (legacy `04-flows.md`) `**Stages**` label (the vault flow-staging surface, NOT the deriver: it heads the `stages:` YAML block that `validate-vault-flow-staging.sh` machine-reads).
- **Names & glyphs:** skill names, `/mega-sdd:*` command names, file / state-file paths, glyphs `✓ ⏸ ⛔`.
- **Gateway & git surfaces:** the gateway tag family `mega-sdd-trace:*` (byte-verbatim contract — `docs/gateway-contract.md`); the commit trailers `SDD-Acceptance: v5` / `SDD-PROVENANCE:` / `Unit:` (parser-pinned).
- **Script-emitted output stays English** (`query-graph.sh` incl. its `--modules` rollup, `analyze-parallelism.sh` — their labels / headers / JSON are asserted by executable `.sh` tests). Scripts are not localized; only model-generated prose is.

## Tier-3 — per-artifact language

| Artifact | Language |
|---|---|
| Plugin-authored report prose (FSD body + headings; `CONSISTENCY-REPORT.md` analysis/recommendations) | Indonesian (per precedence) |
| Vault docs (PRD / BRD / brief → markdown) **and content recorded INTO the vault** (OQ resolution answers, drift rationale, `binding.md` claim text) | the **vault's / input doc's** language (existing behavior — unchanged) |
| `AGENTS.md`, `vault.json`, `binding.md` **structure** | **English** (machine-interop) |
| **Quoted / cited source content** (PRD excerpts, constitution clauses, binding quotes) | **source language — never translate a citation** (citation discipline) |
| Doc structural spine (`§` headers parsed by validators, `[Source: sha256:…]`) | **English** |

**Surface split for `analyze` / `detect-drift` / `bind-codebase` / `resolve-oq`:** what they *say to the user* (chat narration of a recommendation, a drift finding, an OQ prompt) is Tier-2 → Indonesian by default, already governed by the anchor. What they *record into a vault artifact* (an OQ resolution answer, drift rationale written to the vault, `binding.md` claim text) is vault content → stays the vault's language. Only `emit-fsd` and `analyze` author standalone plugin-owned report files, so they are the only L3 Tier-3 pointer additions; the others narrate via the anchor and write via the vault-language rule, and are deliberately not given an artifact-language directive.

## Prompt surfaces (AskUserQuestion / halt menus) — the keterangan contract

A human-facing question the human cannot answer from the prompt alone is a defect (user-mandated, 2026-07-08 — a live run was blocked by a code-only prompt). EVERY interactive surface (AskUserQuestion, halt re-engagement, propose-and-confirm menu) MUST carry:

1. **The actual question/claim text** — quote the OQ question, CONFLICT claim pair, or decision at stake verbatim; an ID/tag (`OQ-AR-1`, `CONFLICT-2`) alone is never a question. **Verbatim is necessary but NOT sufficient (7.21.1):** when the quoted text is jargon-heavy, a human framing in common ID/EN PRECEDES it — konteks situasi + maksudnya (apa yang sebenarnya diminta) — a display translation derived only from the text + its citations, never a rewrite of the artifact and never invented facts (canonical shape: `skills/resolve-oq/references/interactive-walk.md` Step 2a).
2. **Context** — source citation (doc §/anchor or file:line) + one line of why this is being asked now.
3. **Per-option keterangan** — a Tier-1 enum code (`KEEP_CODE`, `DEFER`, `ACCEPT`, `P1`…) stays English as the LABEL, but every option carries a MANDATORY Tier-2 description of what choosing it DOES and its consequence (e.g. `DEFER — jadi OQ; gate binding terbuka, unit digenerate membawa OQ-nya`). The description must state the mechanic the plugin ACTUALLY implements — a keterangan asserting behavior that does not exist is fabricated UX, worse than a bare code. An option rendered as a bare code is a violation; a literal placeholder (`description: ...`) is a violation.
4. **Recommended default** — stated with a one-line reason whenever one exists; exactly ONE option is marked recommended (two templates disagreeing on the default is a defect).

Descriptions follow the standing Tier-2 language precedence (Indonesian-mix by default). This contract binds the halt displayer (`plugins/mega-sdd/references/halt-protocol.md §Consumer dispatch` renders a keterangan block BEFORE the envelope YAML) and every skill prompt template; pinned by `tests/interaction-keterangan/`.

## Register — natural, bukan baku (mandat user + tim, 2026-08-31)

Semua prosa Indonesia yang plugin HASILKAN (Tier-2 narasi + Tier-3 artefak — vault, KB, binding, laporan, keterangan, emissions) ditulis sebagai **bahasa kerja engineer yang natural**, bukan bahasa dokumen resmi atau terjemahan harfiah. Istilah teknis English dipakai apa adanya; kalimat aktif dan langsung; kata upacara dibuang.

| ❌ Kaku (jangan) | ✅ Natural (tulis begini) |
|---|---|
| melakukan proses validasi terhadap input | memvalidasi input |
| dipergunakan untuk keperluan autentikasi | dipakai buat autentikasi |
| adapun titik akhir yang digelar adalah | endpoint yang di-deploy: |
| sehubungan dengan hal tersebut di atas | (hapus — langsung ke isinya) |
| apabila pengguna tidak terautentikasi maka sistem akan menolak | user belum login → request ditolak 401 |
| setiap klaim menyebut sumbernya | tiap klaim ada sumbernya |
| hanyalah otomasi di sekeliling kontrak tersebut | cuma otomasi di sekitar kontrak itu |
| memahami sistem tanpa mengarang | paham dulu sistemnya, jangan ngarang |

Rambu:
- **Bookish-halus juga kaku (kalibrasi ronde 2, 2026-09-02 — owner menegur ke-4 kalinya).** Kalimat bisa gramatikal, puitis, dan "rapi" tapi tetap terasa dokumen — kelasnya: kata upacara halus (*hanyalah, menyebut, menimbang, meninggalkan, menemui, sepatah kata pun*). Tes praktisnya: bacakan kalimatnya ke rekan kerja — kalau lo ga akan ngomong begitu, tulis ulang pakai kata yang dipakai waktu ngomong (*cuma, ada, nimbang, ninggalin, ketemu*).
- **Flawless ≠ gaul.** Tetap gramatikal + profesional — "lo/gue" adalah register chat, bukan artefak tim; jangan bawa ke dokumen.
- **Carve-out regulator:** bagian dokumen yang menghadap regulator (emit-uat berita acara SEOJK — bagian formalnya) TETAP baku; regulator memang mengharapkan register itu. Di luar carve-out ini, natural.
- Tier-1 tak tersentuh (enum, verdict, ID, path — English verbatim); "vault ikut bahasa input" tak berubah — register ini berlaku SAAT prosa ditulis dalam Indonesia.

## OQ authoring — human-first (mandat tim, 2026-09-02)

§Register mengatur register (kaku vs natural); section ini mengatur **komprehensibilitas** — keluhan lapangan: "bahasa OQ seperti alien". Berlaku untuk SEMUA teks OQ yang DITULIS ke artifact (KB PRD-kontrak §6, vault `constraints.md ## Open Questions`, propagasi binding):

Setiap OQ = **pertanyaan utuh yang bisa dijawab orang bisnis TANPA buka kode**, tiga bagian berurutan:
1. Satu kalimat konteks situasi dalam bahasa manusia (kapan/di mana masalah ini muncul).
2. Pertanyaannya sendiri — jargon internal (nama SP, kolom, simbol, config key) BOLEH sebagai penjelas dalam kurung, **TIDAK BOLEH jadi subjek kalimat**.
3. Detail teknis (sitasi `file:line`, marker) menyusul sebagai keterangan.

| ❌ Alien (jangan) | ✅ Manusiawi (tulis begini) |
|---|---|
| `OQ-ACQ-03 [P1] grace_period NULL fallback semantics SP_CALC_DENDA?` | `OQ-ACQ-03 [P1] Kalau jatuh tempo lewat tapi masa tenggang belum diisi (kolom grace_period kosong — SP_CALC_DENDA:120), denda mulai dihitung dari hari ke berapa? [OPEN][?]` |

Tag/ID/marker tetap Tier-1 (English verbatim, tak berubah) — yang diatur section ini hanya BADAN teks pertanyaannya. Aturan yang sama berlaku untuk teks jawaban/hasil yang direkam (resolution answers, rationale): tulis buat pembaca bisnis dulu, detail teknis menyusul.

## Switching & extensibility

- Default `id` (carried by the anchor + the greenfield entry-point directives). The user says "use English" / "pakai bahasa Inggris" / "pakai bahasa Jawa" → the model mirrors.
- Any language works with zero new code: the model is multilingual and Tier-1 stays English regardless. No catalog, no per-language code.
- Not persistent across sessions (and re-asserted each session/compaction by the anchor) — by design, the lightest-touch config.
