# Sensus konsumen artefak antara — mega-sdd @ 7.30.0 (standing census, v8 P0)

**Tanggal:** 2026-09-10 · **Head:** `5f7f220` (7.30.0) · **Pemakai:** spec `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md` (Appendix A adalah ringkasannya; file ini = data lengkapnya). Diarsipkan per keputusan gate owner 2026-09-10 (P0: "arsipkan census App. A ke research/ sebagai sensus tetap").

**Metode:** lima lane read-only (agent Explore, breadth "very thorough"), tiap lane satu artefak antara: (A) vault docs + `vault.json` + `claims-ledger.json`; (B) `binding.md` / `binding.json` / `.validation-blockers.json` / `bound/` / `symbol-index.json`; (C) handoff YAML + `codebase-map.md` + grammar unit; (D) inventaris 89 situs gate/halt; (E) input lane DOCS (emit-*) + lane LIVE (sync/drift/delta/graph/multi-PRD). Setiap baris ber-`path:line` relatif `plugins/mega-sdd/`. Klasifikasi pembaca yang dipakai semua lane: **[DET]** script parse struktural · **[BLOB]** script baca whole-file (sha/regex corpus/byte-copy) · **[PROSE]** hanya baris SKILL/reference yang memerintah (best-effort, per doktrin "prose that says HALT enforces nothing") · **ZERO READERS** = grep pattern tercantum. Path class: BUILD (generate-units / execute-bolts / dispatch / review-tier / gate+hook) · DOCS (emit-*) · LIVE (sync / drift / delta / graph / ownership) · ANALYZE (validator/analyze) · AUTHOR (generate-intent / resolve-oq saja).

**Cara memakai ulang:** sensus ini adalah *snapshot* di head di atas. Sebelum memutuskan pemangkasan artefak/field di head yang lebih baru, ulangi grep pattern yang tercantum di baris "ZERO READERS" — pembaca bisa lahir setelah tanggal ini. Aturan producer-grammar sweep (7.24.0) tetap berlaku.

**Koreksi terhadap spec Appendix B butir 3 (ditemukan saat P0):** "tiga grammar untuk satu field `vault_source`" mencampur dua field berbeda. `build-graph.sh:392-399` (strip `:line`) dan `make-bound.sh` SRC_RE membaca **`binding.json` `claims[].vault_source`** (grammar `<doc>.md:<line>`, ditulis `derive-claims-ledger.sh`). Field **unit** `vault_source` adalah field lain: dokumentasi `unit-schema.md:26` menulis `<vault-file:section>`, template + producer memakai `<doc>.md#<anchor>`, dan di lapangan/fixture ada empat bentuk (`doc#anchor`, `doc:anchor`, `doc §anchor`, `doc` polos). Validasinya presence-only (`validate-unit-spec.sh:188-190`); pembaca deterministik cuma `F_ID_RE.search` (SIT/UAT) yang toleran bentuk apa pun. Perbaikan P0 = satu grammar `<doc>#<anchor>` di unit-schema + validator advisory (bukan gate baru) — lihat CHANGELOG 7.31.0.

---

## Lane A — vault docs, `vault.json`, `claims-ledger.json`

### Headline

1. **Nol byte vault markdown masuk dispatch prompt.** `scripts/build-dispatch-prompt.sh` menyentuh vault hanya di `os.path.join(VAULT, …)` untuk `bolts/` (:312, :1795), `units/` (:969-970, :1800), `constitution.md` (:2071), `binding.md` (:2945), `lens-inputs/` (:3449) dan **`vault.json`** (:1093). Dari `vault.json` diambil tiga hal: sha256 byte file (`vault_sha256`, :1102-1107), `design_system` (:1109), `scope_metadata` (:1110).
2. **`generate-units` tidak punya script.** Seluruh pembacaan vault-nya prose: `skills/generate-units/SKILL.md:48` ("Read the vault docs … + vault.json") dan `:52` ("Walk vault sections (`vault.md ## Architecture`, `flows.md`, `model.md`)"). Konten vault sampai ke unit hanya sebagai teks yang model pilih tulis ke badan unit, plus string pointer `vault_source:` (`references/templates/unit.md:4`).
3. **Satu-satunya konsumen BUILD deterministik vault markdown = `scripts/derive-claims-ledger.sh`** → `claims-ledger.json` → `bind --express` → `binding.md` → `generate-units` task_type. Klaim dicetak dari lima grammar: frontmatter `implementation_mode` (:137-142), heading `## §<id>` (:184-193), DBML `Table` (:195-261), `### F-*` (:263-269), `### D-*` (:271-281), baris tabel NFR (:283-299).
4. **Nuansa kritis:** pass `## §<id>` (satu-satunya yang bisa mengklaim prosa `## Overview`/`## Architecture`) menghasilkan **NOL klaim di vault produksi generate-intent** — `skills/bind-codebase/references/express-bind.md:76`: "a template vault has NO `## §` headings"; template `skills/generate-intent/references/templates/vault.md:72,76,92` memancarkan `### System overview` / `### {Layer 1}` / `### API contracts`. Prosa Architecture/Overview sampai ke binding **hanya** lewat sweep completeness model (`express-bind.md:70-84`) + tabel kategori klaim (`skills/bind-codebase/references/binding-contract.md:22-27`) — BUILD-class tapi **prose-commanded tanpa backing deterministik**.
5. **Hook tidak membaca konten vault sama sekali.** `hooks/stop:152` (`-name claims-ledger.json`) ada di daftar `find … -prune` = non-read. `hooks/pre-tool-use` menyentuh `.mega-sdd/vaults/*/binding.md` (:203, :1357, :1550) dan `bolts/*.json`, tidak pernah vault doc.

### `vault.md`

| section/field | reader (path:line) | what it reads | kind | class |
|---|---|---|---|---|
| frontmatter `vault_layout: 2` | `scripts/_lib/vault_md.py:187-193`, `:231-233`; `derive-vault-json.sh:71`; `derive-claims-ledger.sh:42`; `run-analyze.sh:578-580`; `validate-vault-oqs.sh:520`; `make-bound.sh:32-33`; `build-fsd-core.sh:74-76`; `build-prd-core.sh:73-75`; `build-sit-evidence.sh:99-101`; `build-uat-scaffold.sh:93-95` | layout switch | [DET] | BUILD+DOCS+ANALYZE |
| `vault_version` | `vault_md.py:141-151,275-314` → `derive-vault-json.sh:199,331-337`; consumers `validate-preflight.sh:225-230,411-412`; `build-fsd-core.sh:164`; `build-prd-core.sh:408` | lock scalar / stamp | [DET] | BUILD gate + DOCS |
| `project_shape` | `skills/emit-agents-md/references/agents-md-schema.md:54` | | [PROSE] | DOCS |
| `implementation_mode` | `derive-claims-ledger.sh:119,137-142` (klaim `C-MODE-01`); `generate-units/SKILL.md:46`; `detect-drift/SKILL.md:48,78`; `generate-units/references/defensive-generation.md:39` | mode claim / fork | [DET]+[PROSE] | BUILD + LIVE |
| `mode_migration_trigger` / `mode_migrate_after` | `detect-drift/SKILL.md:78`; `detect-drift/references/auto-and-chain.md:22,27` | | [PROSE] | LIVE |
| `prd_status` | **ZERO READERS** (`grep -rHn "prd_status" scripts/ hooks/ commands/ skills/ agents/` → writer + template) | | | |
| `output_mode` | `resolve-oq/references/interactive-walk.md:429`; `diff-vault/SKILL.md:71,79`; `diff-vault/references/diff-procedure.md:68` | | [PROSE] | AUTHOR/LIVE |
| `project_scale` | `generate-intent/references/generation-guide.md:98,122,166,211`; `self-check.md:22,24,25,34,64` | | [PROSE] | **AUTHOR only** |
| `prd_source` | **ZERO READERS** | | | |
| `locked_at` / `locked_by` | `resolve-oq/references/interactive-walk.md:662`; `resolve-oq/SKILL.md:47` | lock check | [PROSE] | AUTHOR |
| `kb_module_graph` | `generate-units/references/decomposition-rails.md:64` | | [PROSE] | BUILD |
| hard-header contract (`## Overview`/`## Architecture`/`## Decisions`) | `vault_md.py:228,265-272`; enforced `derive-vault-json.sh:146-151` (exit 2), `derive-claims-ledger.sh:124-129` (exit 2); `run-analyze.sh:617-624` | header presence | [DET] | BUILD + ANALYZE |
| `## Phase context` (markdown) | **ZERO READERS** | | | |
| `## Overview` — DOC_CODE `OV` | `vault_md.py:216-227,249-262` → `derive-claims-ledger.sh:165` | attribution | [DET] | lib |
| `## Overview` — claim minting | `derive-claims-ledger.sh:184-193` (`SECTION_RE` `^##\s+§`) — **ZERO di vault template** (`express-bind.md:76`) | | [DET, empty] | BUILD |
| `## Overview` §Purpose/§Product, §Scope/§Target users | `build-fsd-core.sh:185,282-283` (FSD §1) | `md_section` | [DET] | DOCS |
| `## Overview` §Goals/§Success criteria, §Non-Goals/§Out of Scope | `build-fsd-core.sh:295-296` (§2), `:688-690` (§10) | | [DET] | DOCS |
| `## Overview` (whole doc) | `build-prd-core.sh:169-171` (cite, no section parse); `validate-vault-oqs.sh:520-527` (`prose_corpus`) | | [BLOB] | DOCS / ANALYZE |
| `## Overview` → binding claims | `binding-contract.md:22`; `express-bind.md:70-84` | mode claim | [PROSE] | BUILD |
| `## Architecture` — DOC_CODE `AR` | `vault_md.py:218`; `derive-claims-ledger.sh:165,168-178` | | [DET] | BUILD |
| `## Architecture` — claim minting | `derive-claims-ledger.sh:184-193` — **ZERO di vault template** | | [DET, empty] | BUILD |
| `## Architecture` → binding claims | `binding-contract.md:23`; `express-bind.md:70-84` (named-H2, API rows → `C-AR-NN`) | | **[PROSE]** | **BUILD** |
| `## Architecture` → unit candidates | `generate-units/SKILL.md:52`; `decomposition-rails.md:63,83`; `modules-schema.md:82` | | **[PROSE]** | **BUILD** |
| `## Architecture` (whole) | `validate-vault-oqs.sh:526` | | [BLOB] | ANALYZE |
| `## Architecture` | `detect-drift/SKILL.md:56` (`flows-only`); `resolve-oq/references/interactive-walk.md:341,408`; `generate-intent/references/squad-partition.md:11`, `setup-flow.md:119` | | [PROSE] | LIVE / AUTHOR |
| `## Decisions` `### D-NNN:` | `vault_md.py:97` → `derive-claims-ledger.sh:271-281` (`C-DC-NN`); `vault_md.py:100-102,474-517` → `derive-vault-json.sh:155` (`adrs[]`, 0 pembaca); cross-count `derive-claims-ledger.sh:308,313-325`, `derive-vault-json.sh:218,230-244` | | [DET] | BUILD / ANALYZE |
| `## Decisions` (prose readers) | `binding-contract.md:26`; `decomposition-rails.md:63`; `modules-schema.md:83`; `detect-drift/SKILL.md:56`, `report-format.md:45,64,145`; `diff-vault/SKILL.md:28`, `diff-procedure.md:45`; `resolve-oq/SKILL.md:100`, `interactive-walk.md:227,280,411,417,429`, `recommendation-context.md:51` | | [PROSE] | BUILD / LIVE / AUTHOR |
| `## Glossary` | `vault_md.py:220` → `None` (fenced) — **ZERO READERS** | | | |
| `## Auto-Classification Review` | `vault_md.py:226` → `None` — **ZERO machine readers** (bind refs `oq-resolution.md:30,49`, `binding-contract.md:161` menyebut tempat manusia melihat, bukan perintah baca) | | | AUTHOR |
| `## Source documents` (md) | `vault_md.py:225` → `None` — **ZERO READERS** | | | |
| `## Changelog` | `vault_md.py:224` → `None`; `resolve-oq/SKILL.md:49`, `interactive-walk.md:43` (resume); `binding-contract.md:189` (diff-vault-apply ⇒ claim-scoped re-bind) | | [PROSE] | AUTHOR / BUILD-LIVE |
| `## Last updated` | **ZERO READERS** (writers `interactive-walk.md:634`, `diff-procedure.md:112`) | | | |
| whole file (bytes) | `make-bound.sh:118-120,140-172`; `build-citation-map.sh:107-116,199-208` | byte-copy / sha256 | [BLOB] | BUILD / DOCS |

### `model.md`

| section/field | reader (path:line) | what | kind | class |
|---|---|---|---|---|
| DBML `Table <name> {` | `vault_md.py:105,317-401` → `derive-claims-ledger.sh:195-261` (`C-DM-NN`, `hints.symbols`, `fields[]`); `derive-vault-json.sh:152-153` (`entities[]`); guards `derive-claims-ledger.sh:220-227,236-244` | | **[DET]** | **BUILD** |
| `// Purpose:` | `vault_md.py:108` → `derive-claims-ledger.sh:210-212` (claim text); `vault_md.py:360-362` → `entities[].purpose` (0 pembaca) | | [DET] | BUILD |
| `## Entity descriptions` `### <entity>` + `- **Purpose**:` | `vault_md.py:111-112,326-338` → `entities[].purpose` (**0 pembaca**) | | [DET] | — |
| loose count | `run-analyze.sh:583-594`; `derive-vault-json.sh:215-216,230-244`; `derive-claims-ledger.sh:305-325` | | [DET] | ANALYZE |
| `## Constraints` / `## Sources` / `## Out of Scope` (model.md) | **ZERO READERS** | | | |
| whole doc | `validate-vault-oqs.sh:521`; `make-bound.sh:118-120` | | [BLOB] | ANALYZE / BUILD |
| entities (prose) | `binding-contract.md:24`; `generate-units/SKILL.md:52`, `modules-schema.md:170`; `detect-drift/SKILL.md:56`, `report-format.md:70,75,142`; `diff-vault/references/diff-procedure.md:35`, `report-format.md:92` | | [PROSE] | BUILD / LIVE |

### `flows.md`

| section/field | reader (path:line) | what | kind | class |
|---|---|---|---|---|
| `### F-{prefix}-NNN: <title>` | `vault_md.py:94,153-159,404-473`; `derive-claims-ledger.sh:263-269` (`C-FL-NN`); `derive-vault-json.sh:154` (`flows[]`); **`validate-flow-coverage.sh:321-324,671-686` (gate BLOCKING)**; `validate-vault-flow-staging.sh:123-155`; `build-sit-evidence.sh:101,269`; `build-uat-scaffold.sh:95,427`; `build-fsd-core.sh:417-440`; `build-prd-core.sh:248-266`; counts `run-analyze.sh:644-652`, `derive-vault-json.sh:217` | | **[DET]** | **BUILD gate** + DOCS + ANALYZE |
| `**Definition of Done**` + `- [ ]` | `vault_md.py:118,121,445-460` → `flows[].dod_count` (**0 pembaca**); **`build-sit-evidence.sh:296-301`, `build-uat-scaffold.sh:454-458`** (DoD → langkah SIT/UAT); `emit-fsd/references/section-mapping.md:108` | | [DET] | DOCS |
| `**Source**:` `ACn-m` | `vault_md.py:115,119,461-466` → `flows[].source_acs` (**0 pembaca**) | | [DET] | — |
| `**_kb_source**:` | `vault_md.py:120,467-472` → `flows[]._kb_source`; `build-graph.sh:344-348` (edge kb_domain); `validate-vault-flow-staging.sh:152-155,192-208` | | [DET] | LIVE / ANALYZE |
| `**Stages**` / `stateDiagram` | `validate-vault-flow-staging.sh:157,163-190`; `validate-vault-oqs.sh:485-488,573-620` | | [DET] | ANALYZE |
| ```mermaid body edges | **`validate-flow-coverage.sh:692-730`** (gate); `build-prd-core.sh:243-262` (verbatim ke PRD §4) | | **[DET]** | **BUILD gate** + DOCS |
| `## {Flow Type N}` | boundary only (`vault_md.py:424-427`, `validate-vault-flow-staging.sh:145-147`) | | | |
| `## Sources` / `## Out of Scope` (flows.md) | **ZERO READERS** | | | |
| flows (prose) | `binding-contract.md:25`; `generate-units/SKILL.md:52`, `decomposition-rails.md:17,36,103,117,122`, `modules-schema.md:81,94`; `detect-drift/SKILL.md:56`, `report-format.md:82,86,92,144` | | **[PROSE]** | **BUILD** / LIVE |
| whole doc | `make-bound.sh:118-120` | | [BLOB] | BUILD |

### `constraints.md`

| section/field | reader (path:line) | what | kind | class |
|---|---|---|---|---|
| `## Non-functional requirements` table | `derive-claims-ledger.sh:60,283-299` (`C-CN-NN`); `build-fsd-core.sh:496-498,515-543` (FSD §6); `section-mapping.md:133,138,142` | | **[DET]** | **BUILD** + DOCS |
| `## Technical constraints` / `## Business constraints` | **ZERO READERS** | | | |
| `## Design system` (+ Tokens/Accessibility/Voice) | `validate-vault-oqs.sh:522,529-531` (blob corpus) — bukan sumber `vault.json.design_system` (patch-lane, `derive-vault-json.sh:13-16`) | | [BLOB] | ANALYZE |
| `## Sources` / `## Out of Scope` (constraints.md) | **ZERO READERS** | | | |
| `## Open Questions` presence | `derive-vault-json.sh:75,168-182` (centralization, exit 2); `validate-preflight.sh:233-238`; `run-analyze.sh:604-613` | | [DET] | BUILD gate + ANALYZE |
| OQ line `- [ ]/[x]/[~]` + `**OQ-XXX-N**` | `vault_md.py:41-45,23,556-650`; `derive-vault-json.sh:159-167,175,224`; `validate-vault-oqs.sh:130`; **`validate-handoff-binding-units.sh:218-224,423`** (OQ id universe) | | [DET] | BUILD gate + ANALYZE |
| `[P1|P2|P3]` | `vault_md.py:46` → priority; **`state_probes.py:852-880`** (`pending_p0_p1` → oq_gate); `routing-rules.md:38`; `commands/mega-sdd.md:27` | | [DET] | **LIVE** |
| `[tech / scan|recommend]` / `[business]` | `vault_md.py:28-39,58-63`; `validate-vault-oqs.sh:203-219`; `bind-codebase/references/oq-resolution.md:21-30,49` | | [DET]+[PROSE] | ANALYZE / BUILD |
| `[conf: high|medium|low]` | `vault_md.py:64-72` → `classification_confidence` (**0 script readers**); `oq-resolution.md:30,49`, `binding-contract.md:161` | | [PROSE] | BUILD |
| `[origin: <file>#<anchor>]` | `vault_md.py:54,602-604` → `derive-vault-json.sh:97` → `origin`; `resolve-oq/SKILL.md:58` | display only | [PROSE] | **AUTHOR only** |
| `→ **Resolved v{X.Y}**` / `→ Out of Scope` / `**Deferred**` | `vault_md.py:73-78,86-87`; `derive-vault-json.sh:386-397` (`out_of_scope_reason`, `deferred_reason` **0 pembaca**) | | [DET] | — |
| `— resolve: <hint>` | `vault_md.py:91`; `resolve-oq/SKILL.md:58` | | [DET] | AUTHOR |
| `scan_query:` dkk hint lines | `vault_md.py:651-704` → `derive-vault-json.sh:186-190,382-384` | | [DET] | BUILD (bind scan) |
| roll-up | `vault_md.py:705+` → `open_questions_summary` (**0 pembaca**) | | [DET] | — |
| constraints → binding | `binding-contract.md:27` | | [PROSE] | BUILD |

### `vault.json` — setiap key (`derive-vault-json.sh:99-107` KEY_ORDER)

| key | readers | class |
|---|---|---|
| `vault_version` | `validate-preflight.sh:225-230,411-412`; `build-fsd-core.sh:164`; `build-prd-core.sh:408` | BUILD gate + DOCS |
| `vault_layout` | **ZERO READERS** (semua konsumen re-probe fs via `is_layout2_vault`) | — |
| `generated_at` | self (`derive-vault-json.sh:456-460`) | — |
| `title` | `query-graph.sh:189` | LIVE |
| `phase` / `phase_total` | `execute-bolts/references/halts-and-handoff.md:249-259`; `chain-execution.md:231` (prose; `phase_total` 0 script reader) | BUILD prose |
| `project_shape` | `agents-md-schema.md:54` (prose) | DOCS |
| `implementation_mode` | `generate-units/SKILL.md:46` (prose; script baca frontmatter md) | BUILD prose |
| `mode` (legacy) | `ground.sh:85-115` (rewrite); `state_probes.py:891-896,1279` | LIVE |
| `prd_status` | **ZERO READERS** | — |
| `output_mode` | `interactive-walk.md:429`; `diff-vault/SKILL.md:71,79` | AUTHOR/LIVE |
| `mode_migrate_after` | `detect-drift/SKILL.md:78`; `auto-and-chain.md:22,27` | LIVE |
| `project_scale` | **AUTHOR-only** (`generation-guide.md:98,122`; `self-check.md:22,24,25`) | AUTHOR |
| `scope` | `build-uat-scaffold.sh:413-416`; `build-sit-evidence.sh:258`; `generate-units/SKILL.md:98`, `auto-and-memory.md:12,19,78`; `halts-and-handoff.md:87,232`; `diff-vault/references/auto-and-chain.md:138` | BUILD + DOCS |
| `scope_metadata` | **`build-dispatch-prompt.sh:1110`**; `build-uat-scaffold.sh:413`; `build-sit-evidence.sh:258`; `unit-schema.md:322,325,336` | **BUILD** + DOCS |
| `prd_sha256` | `diff-vault/SKILL.md:61`, `diff-procedure.md:16-26`; `halts-and-handoff.md:317` (prose) | LIVE |
| `prd_path_at_generation` | `diff-vault/SKILL.md:61,87,95`, `diff-procedure.md:20,27,147` (prose; 0 script reader) | LIVE |
| `constitution_version` | **ZERO READERS** | — |
| `constitution_hash` | `validate-constitution.sh:7,106`; `commands/sync.md:28` | ANALYZE + LIVE |
| `source_documents` | `run-analyze.sh:632-639`; `diff-vault/SKILL.md:73,79` | ANALYZE + LIVE |
| `design_system_flags` | `validate-vault-oqs.sh:548` | ANALYZE |
| `design_system` | **`build-dispatch-prompt.sh:1109,2593,2608,2814,2877`**; `validate-dispatch-prompt.sh:270-275,361,410` | **BUILD** |
| `advisor` | **ZERO READERS** | — |
| `entities` | `run-analyze.sh:591`; **`commands/mega-sdd.md:51`** (ownership check) — sub-field `purpose/fields_count/doc` **0 pembaca** | ANALYZE + **LIVE** |
| `flows` | `build-graph.sh:327-348`; `run-analyze.sh:646`; `commands/mega-sdd.md:51` — sub-field `dod_count/source_acs` **0 pembaca** | LIVE + ANALYZE |
| `adrs` | **ZERO READERS** | — |
| `open_questions` | `state_probes.py:848-880`; `validate-vault-oqs.sh:236-249`; **`validate-handoff-binding-units.sh:218-224`**; `validate-preflight.sh:243-251`; `build-prd-core.sh:347-362`; `build-fsd-core.sh:640-650`; `halts-and-handoff.md:176` — per-OQ `classification_confidence/resolver_owner/resolved_at/deferred_at/out_of_scope_reason/deferred_reason` **0 script readers** | **BUILD gate** + LIVE + ANALYZE + DOCS |
| `open_questions_summary` | **ZERO READERS** | — |
| `changelog` | **ZERO READERS** (append-only; `commands/emit.md:27` menyebut sebagai sumber summary) | — |
| whole file (bytes) | `build-dispatch-prompt.sh:1102-1107`; `build-citation-map.sh:283-297,389-394`; `publish-artifacts.sh:211` | BUILD + DOCS |
| existence only | `state_probes.py:164,987`; `make-bound.sh:29`; `validate-preflight.sh:89,190,206,237`; `emit-sit/SKILL.md:41`; `emit-uat/SKILL.md:48`; `commands/mega-sdd.md:34,36`; `ground.sh:29,85`; `run-analyze.sh:555`; `build-graph.sh:146,315` | |
| parse-check only | `analyze-parallelism.sh:141-148`; `query-graph.sh:184-191`; `certify-artifact.sh:259-291` | |

### `claims-ledger.json` (producer `derive-claims-ledger.sh:347-356`; konsumen tunggal = `bind --express`)

| field | readers | class |
|---|---|---|
| `schema`, `generated_by`, `vault`, `doc_shas` | **ZERO READERS** (`grep -rHn "claims-ledger\|doc_shas\|generated_by" scripts/ hooks/ skills/ agents/ commands/ references/`); staleness ditangani re-derive tanpa syarat (`express-bind.md:209`) | — |
| `generated_at` | self (:361-365) | — |
| `claims[].id/type/text/source` | `express-bind.md:70-71,76`; `source` → `binding.json vault_source` → `make-bound.sh:127-135` | **BUILD** |
| `claims[].native_id` | `express-bind.md:70` (model); **0 script readers** | BUILD prose |
| `claims[].entity/fields[]` | `express-bind.md:88-90` | BUILD prose |
| `claims[].hints.symbols/terms` | `express-bind.md:88-90` → `query-symbol-index.sh --name=` | **BUILD** |
| whole file | `express-bind.md:55,57,70`; `bind-codebase/SKILL.md:28`; `orchestrate-flow/SKILL.md:124`; `commands/mega-sdd.md:62` | **BUILD** |
| NOT a reader | `hooks/stop:152` (prune list) | — |

### Ringkasan lane A — nol pembaca kelas apa pun (grep patterns)

`vault.md ## Glossary` (`grep -rHn "Glossary" scripts/ hooks/ commands/ agents/` → 0; `vault_md.py:220` fenced) · `## Source documents` (md) · `## Last updated` · `## Phase context` · `## Architecture ### System overview` / `### API contracts` (sebagai parse) · `model.md ## Constraints` / `## Entity descriptions` (produk `entities[].purpose` 0 pembaca) · `## Sources` / `## Out of Scope` di model/flows/constraints · `constraints.md ## Technical constraints` / `## Business constraints` · frontmatter `prd_status` / `prd_source` · vault.json `vault_layout` / `adrs[]` / `open_questions_summary` / `changelog` / `constitution_version` / `advisor` / `phase_total` (script) / `entities[].purpose|fields_count|doc` / `flows[].dod_count|source_acs` / per-OQ `classification_confidence|resolver_owner|resolved_at|deferred_at|out_of_scope_reason|deferred_reason` · claims-ledger `schema|generated_by|vault|doc_shas`. **AUTHOR-only:** `project_scale`, OQ `[origin:]` → `origin`, `## Auto-Classification Review`, `locked_at/locked_by`. **DOCS-only:** `project_shape`, Overview §Product/§Scope/§Goals/§Non-Goals (prose BUILD via sweep saja), NFR sebagai tabel per-kategori (tabel yang sama = klaim `C-CN` di BUILD). **Borderline (BUILD prose, 0 deterministik):** `## Architecture`/`## Overview` prose (sweep `express-bind.md:70-84` + walk `generate-units/SKILL.md:52`), `## Changelog` (`binding-contract.md:189`).

### generate-units + build-dispatch-prompt — apa yang benar-benar ditarik

`generate-units` = 100 % prose, script yang dipanggil hanya `compute-unit-staleness.sh` (:29), `emit-claude-rules.sh` (:120), `render-html.sh` (:148). Dibaca (prose): 4 dok + vault.json (`SKILL.md:48`); `## Architecture` → kandidat (`:52`, `decomposition-rails.md:83`, `modules-schema.md:82`); `flows.md` `F-U-*` steps → artefak per step (`decomposition-rails.md:17,36,117,122`); `model.md` DBML → unit migrasi (`modules-schema.md:170`); `## Decisions` → grouping advisory (`decomposition-rails.md:63`, `modules-schema.md:83`); **`constraints.md`/NFR TIDAK disebut di `skills/generate-units/**`** (`grep -rHn "constraints\.md\|Non-functional\|NFR" skills/generate-units/` → hanya `modules-schema.md:44` listing dir); `vault.json` `implementation_mode` (:46), `scope`/`scope_metadata` (:98, `auto-and-memory.md:12,19`, `unit-schema.md:322,325,336` verbatim), existence (:140); `kb_module_graph` (`decomposition-rails.md:64`); `binding.md`/`bound/` (:48,169).

`build-dispatch-prompt.sh` (`grep -Hn "os.path.join(VAULT" …`): `:312` bolts · `:969-970,975` units · **`:1093` vault.json** · `:1795,1800-1802` dep bolt-report/unit · `:2071` constitution.md · `:2945` binding.md (`:2977` `## Open Questions`, `:3022` State Map) · `:3449` lens-inputs. Dari vault.json: `:1102-1107` `vault_sha256` (byte sha, omit bila absen) · `:1109` `design_system` (patch-lane, model-authored) · `:1110` `scope_metadata.id/name`. `:2038` menyatakan instruksi "load this unit's vault_source sections" **unimplementable**; `:2160-2166` menolak `module` sebagai kunci pengganti.

---

## Lane B — `binding.md`, `binding.json`, `claims-ledger.json`, `.validation-blockers.json`, `bound/`, `symbol-index.json`

### Koreksi premis

| Premis | Kenyataan | Bukti |
|---|---|---|
| `<vault>/.binding.json` ada | **Tidak ada** (`grep -rn '\.binding\.json'` → 0). Sidecar satu-satunya `<vault>/binding.json`; dot-file lain = `<vault>/.internal/binding-json-parity.json` | `validate-binding-json.sh:58-63` |
| `claims-ledger.json` membawa `verdicts` | **Tidak** — envelope `{schema, generated_by, generated_at, vault, doc_shas, claims[]}`; claim `{id,type,text,source}` + `native_id`/`hints`/`entity`/`fields[]`. Skeleton pra-verdict | `derive-claims-ledger.sh:347-356,105-113` |
| `claims-ledger.json` membawa `slugs` | Hanya `vault` = basename dir | `:351-353` |

### `binding.md` — writers

| Writer | path:line | Class |
|---|---|---|
| bind-codebase Step 4 (model) — Summary · Confirmed Claims · Implementation State Map · Tech-OQ Auto-Resolved · Tech-OQ Recommendations · Suggested Unit Hard Rules · Conflicts · Open Questions · Auto-Resolved Deferred OQs; frontmatter `binding_metadata.{codebase_map_provenance,head}` | `bind-codebase/SKILL.md:82` | BIND |
| `derive-binding-json.sh` PHASE 0 banner + enum legend | `:88-91`, `:39-43`, `:45-55` | BIND |
| resolve-oq `--binding` write-back (`### ✅ CONFLICT-N RESOLVED (ACTION)` + `- **Resolution**:`) | `resolve-oq/references/binding-mode.md:30-41,74` | LIVE |
| bind `--paths` re-bind (whole-file rewrite) | `binding-contract.md:187` | LIVE |
| delete-protection | `hooks/pre-tool-use:1550` (`PROTECTED_RM_ONLY`); backstop `validate-handoff-binding-units.sh:261-270` (`binding_missing`) | BUILD |

### `binding.md` — readers via `scripts/_lib/binding_md.py`

| Function | path:line | Reads |
|---|---|---|
| `parse_state_map(md, errors, full)` | `:49-99` | State Map table; `full=False` → `{id, verdict, state}`; `full=True` + `anchor_cell`, `confidence`, `field_diff`; 6-column enforce (:76-84), dup-id (:85-87), missing heading (:94-98) |
| `parse_frontmatter_metadata(md)` | `:122-136` | **Hanya** `binding_metadata.codebase_map_provenance` (:130) dan `.head` (:133); tidak pernah `constitution_hash`/`scope_metadata` |
| `parse_confirmed_sources(md)` | `:139-155` | `## Confirmed Claims` → `{claim_id: field2}`; **field 3 (evidence) + 4 (claim text) dibuang** |
| `parse_conflict_resolutions(md, errors)` | `:158-230` | `### CONFLICT-N` blocks; `- **Claim**:` (:35); `- **Resolution**: ✅ RESOLVED (ACTION)` (:39-41); ACTION ∈ KEEP_VAULT/KEEP_CODE/DEFER/SPLIT (:44-46) |

Callers: `derive-binding-json.sh:106,125,133,137,140,154` (semua) · `validate-binding-json.sh:17,32` (`full=False`, verdict+state saja) · `validate-handoff-binding-units.sh:539-540,555` (`head` untuk RECERTIFY) · `state_probes.py:39,790,799,827,833` · `build-dispatch-prompt.sh:2951,2953` (`full=True`).

### `binding.md` — readers langsung

| Reader | path:line | Reads | Class |
|---|---|---|---|
| `validate-handoff-binding-units.sh` OQ/CONFLICT harvest | `:123-128` glob; `:142` OQ_RE; `:147` CONFLICT_RE; `:161-172` section classes; `:190-200` bucketing | OQ-ID live/pending/resolved per H2; CONFLICT-ID whole-file | ANALYZE |
| same — conflict resolution scan | `:346-410`; regex `:317,319-321,329-331,332-334,341-343` | | ANALYZE |
| same — RECERTIFY | `:536-562`; `:514-534` `_anchor_paths(bj)` | `binding_metadata.head` vs `git rev-parse HEAD` ∩ `binding.json claims[].anchor` | ANALYZE |
| `build-dispatch-prompt.sh` | `:2945` load; `:2953` State Map; `:2960-2969` Confirmed field 3; `:2970-2977` `### CONFLICT` `- **Vault claim**`; `:2978-2986` OQ col 0/1; `:3022` anchor; `:3033-3035` Confidence | confidence labels per claim | BUILD |
| `build-fsd-core.sh` | `:187-192` (root then `bound/binding.md`); `:560,562,568` `## Confirmed Claims` | FSD §7.3 | DOCS |
| `build-locked-index.sh` | `:35-38` glob `vaults/*/binding.md` + `bound/*.md`; `:56-72` | `[LOCKED]` → `.locked-files-index.json` | BUILD (edit-time gate) |
| `hooks/pre-tool-use` GateGuard staleness | `:1357-1363`; Bash fast path `:203-211` | **mtime saja** | BUILD |
| `validate-constitution.sh` | `:224-241` | clause refs count | ANALYZE |
| `validate-constitution-propagation.sh` | `:60-61,81-85,127` | clause ids → ≥1 unit | ANALYZE |
| `validate-preflight.sh` `c_binding_confirmed` | `:209-213`; registry `:399-401` (detect-drift) | `^## Confirmed Claims` existence | ANALYZE |
| `make-bound.sh` | `:34`, `:152` | whole → `bound/binding.md` | BIND |
| `validate-unit-spec.sh` | `:666,684-686` | literal string `binding.md` di unit Hard-rule block | ANALYZE |
| `render-html.sh` `:70`; `migrate-paths.sh:440` | | | DOCS / maintenance |
| `generate-units` (prose) | `SKILL.md:19,38,50,46,56-65`; `task-typing.md:17-40` | task_type | BUILD |
| `resolve-oq --binding` (prose) | `binding-mode.md:9-12,28` | | LIVE |
| `detect-drift` (prose) | `constitution-drift.md:10,22-26` (`constitution_hash` — **no script implements**) | | LIVE |
| `emit-agents-md` (prose) | `SKILL.md:72`; `agents-md-schema.md:243,37` | | DOCS |

### `binding.json` (writer `derive-binding-json.sh:202-225`, dari binding.md saja)

| Field | Readers | Class |
|---|---|---|
| `schema_version`, `generated_by`, `generated_at`, `vault` | **none** | — |
| `codebase_map_provenance` | `build-graph.sh:355` → `_meta` only; **no terminal reader** | LIVE |
| `head` | `build-graph.sh:356-357`; `query-graph.sh:456`; `graph/SKILL.md:33` | LIVE |
| `claims[].id` | `validate-binding-json.sh:36-53`; `make-bound.sh:73-74,114`; `build-graph.sh:359` | ANALYZE/BIND/LIVE |
| `claims[].verdict` | **`make-bound.sh:69-89` refusal gate**; `validate-binding-json.sh:48-50`; `build-graph.sh:363,387-388` | BIND/ANALYZE/LIVE |
| `claims[].state` | `validate-binding-json.sh:48-50`; `build-graph.sh:363` | |
| `claims[].state_reason` | `build-graph.sh:365-366`; `task-typing.md:37` (prose) | |
| `claims[].anchor` | **`validate-handoff-binding-units.sh:514-534` RECERTIFY**; `build-graph.sh:371-390`; `sync-intersect.sh:128-144`; `derive-delta-paths.sh:12-15,62-66` | ANALYZE/LIVE |
| `claims[].confidence` | `build-graph.sh:387-388` | LIVE |
| `claims[].field_diff` | **ZERO script readers** (writer `:182`, lib `binding_md.py:55,92`, comment `build-dispatch-prompt.sh:2952`); prose `task-typing.md:62-63,86-94` | — |
| `claims[].vault_source` | `make-bound.sh:99-114` (SRC_RE `:102-103`); `build-graph.sh:392-399`; `derive-delta-paths.sh:12-13` | BIND/LIVE |
| `claims[].resolution` | `build-graph.sh:367-368`; `task-typing.md:29` | LIVE/prose |
| parity gate | `validate-binding-json.sh:32-53` (ids + verdict + state saja) → `.internal/binding-json-parity.json` (:58-63); dipanggil `make-bound.sh:41-46` | |

### `claims-ledger.json`

Writer `derive-claims-ledger.sh:367-371` (exit 2 = tidak ditulis `:334-345`; exit 3 `:69-72`). Claim `{id "C-<CODE>-<NN>", type, text verbatim, source "NN-name.md:LINE"}` (:102-113); types mode/component/entity/flow/decision/constraint; `hints.symbols` (:74-85,:232), `hints.terms` (:87-96), `fields[]` (:252-258); grammar-fork guard (:301-325). Readers: `express-bind.md:70-71` (text, source), `:97-99` (hints), `:130-131` (fields); `orchestrate-flow/SKILL.md:124`; `commands/mega-sdd.md:62`. **Tidak ada script yang membacanya**; `doc_shas` 0 pembaca; regen tiap express bind (`express-bind.md:55,208-209`; `paths.md:253`).

### `.mega-sdd/.validation-blockers.json`

Writer tunggal `validate-handoff-binding-units.sh` (`:85`, `:113-116`, `:705-709` atomic; OVERWRITE-NOT-APPEND `:31-32`). Schema `{status, ts, validator, slice, summary, drops[], extras[], next_action}` (:687-704). Blocking drops: `binding_missing` (:263), `oq_id_dropped` (:275), `conflict_unresolved` (:399), `conflict_id_dropped` (:479), `binding_stale_recertify` (:566). Advisory extras: `oq_id_extra` (:421), `conflict_id_extra` (:428), `oq_id_resolved_uncited` (:437), `oq_id_pending_uncited` (:449), `conflict_id_deferred_uncited` (:467), `binding_head_absent` (:544), `binding_json_absent` (:557), `binding_head_mismatch` (:582).

Readers: **MOAT gate `hooks/pre-tool-use:940-966`** (path `:946`; parse `:948-952` fail-CLOSED; `:953-966` drops→remediation) — keyed **`SKILL_NAME=mega-sdd:execute-bolts` saja** (`:854`); re-derive `:876` (`:855-858`); python-absent fallback `:420-423`; forge deny Write/Edit `:367,1286,1335`; Bash `:339,1516,1544`; `run-analyze.sh:435,695` (aggregate; `:86` "the moat reads .validation-blockers.json directly"); `hooks/stop:153`; `hooks/post-tool-use:253,373` (komentar). **Asimetri:** `generate-units` di hook hanya `:660` (ledger) dan `:710` (preflight) — **tidak membaca state CONFLICT manapun**.

### `bound/`

Eksistensi (routing): `state_probes.py:897,954,1282,1291-1301`; `make-bound.sh:154-162`; `validate-handoff-binding-units.sh:133-136`; `build-fsd-core.sh:189-192`; `build-locked-index.sh:35`; `validate-constitution.sh:226`; `generate-units/SKILL.md:17,23,48`. Konten `<!-- BIND: -->` (writer `make-bound.sh:143-146`; refusal `:73-89`; skip-count `:107-114,140-141`): **ZERO READERS** (`grep -rn 'BIND:'` → writer + 2 baris doc); kontrak `binding-contract.md:214` "nothing machine-parses them".

### `symbol-index.json`

Writer `build-symbol-index.sh:231-240` (envelope `generated_by, generated_at, head_commit, astgrep_version, file_count, symbol_count, symbols[{file,line,kind,name,signature,lang}]` :225); dipanggil `ground.sh:543` (defer `:527-532`), `express-bind.md:47`. Readers: `head_commit` → `state_probes.py:525-546`, `derive-changed-paths.sh:52,57,64`, `express-bind.md:45-46,166-168`; `symbols[].file/line/name/kind/signature` → `query-symbol-index.sh:59-70`, `build-dispatch-prompt.sh:2286-2367`, `validate-reuse-duplication.sh:71-93`; `symbol_count` → `build-dispatch-prompt.sh:2297`; **`lang`, `astgrep_version`, `file_count`, `generated_by`, `generated_at` = ZERO READERS**; whole → `publish-artifacts.sh:197`. `resolve-review-tier.sh` tidak membaca artefak binding (hits `:10,103,190,201,220,301` = unit `binding_refs`).

### Empat jawaban

**Q1 — minimum binding untuk generate-units:** (1) State cell → `task_type` (`SKILL.md:56-64`, `task-typing.md:17-40,57-65`; `:126` "ONLY from the State Map"); (2) Confidence cell → gate verify vs UNKNOWN + `grounding_confidence` (`:58`, `task-typing.md:22-23,61`); (3) Anchor cell → `## Anchors` (`:65,126`; mandatory verify/extend, empty → `unit_underspecified` `:141`; probe warnings SOFT `:103,129`); (4) CONFLICT-ID + OQ-ID → `binding_refs` (`:40,113,125`; halt `unit_oq_trace_missing` `:142`; hilir `validate-handoff-binding-units.sh:275-281,475-485`). Sekunder: Field diff → `## Migration notes` (prose-only); Confirmed Claims → `existing_interfaces` (`:90`); Suggested Hard Rules → `## Hard rules` (`:105`; `validation-passes.md:66,123`); `binding_metadata.retrieval` (`:46`). Conflict-free = precondition whole-run, tanpa jejak di unit. Binding absen = jalur legal (`task-typing.md:17`; `validate-preflight.sh:635-639`).

**Q2 — execute-bolts membaca binding.md?** SKILL: tidak (`:52-60` unit saja; `grep "bound/" skills/execute-bolts/` → 0). Builder: ya, `:2945`, **hanya bila `binding_refs` non-empty** (`:2947`), State Map per ref (`:3005`, `:3033`, `:3022-3023`) + teks klaim (`:2960-2986`) → `## Confidence labels per claim` (`:3038-3046`; `context-enrichment.md:142`; `bolt-dispatch-prompt.md:266-277`); `omit()` `:3054,3056,3058,3007-3008,3029-3030`; droppable `:3048-3050`. Gate execute-bolts keyed `.validation-blockers.json` (`:854,876,940-966`), bukan binding.md.

**Q3 — scoping express:** `--paths` = WHICH (anchor ∩ changed; `SKILL.md:28`; `sync-intersect.sh:128-144`; `derive-delta-paths.sh:12-15`); `--express` = HOW (`express-bind.md:4-6,144-146`). Retrieval key = `hints.symbols` (entity: snake/Pascal/camel `derive-claims-ledger.sh:74-85,:232`) / `hints.terms` (flow/decision/component/constraint/mode) → `query-symbol-index.sh --name=` (`:15-27,59-70`); hints advisory (`derive-claims-ledger.sh:15`; `express-bind.md:31-37,99-100`). Ladder `express-bind.md:95-122`: index → Read (hanya Read yang mencetak verdict `:101-103`) → collision sweep 2 leg (`:104-111`) → grep (`:112-114`) → KB (`:115-116`) → ungrounded ⇒ OQ/CONFLICT (`:117-122`). Enumerasi = ledger + sweep wajib (`:25,73-84`).

**Q4 — field 0 pembaca:** binding.md fm `vault:`/`codebase_map:`/`bound_at:`/`strict:` (0 reader; `binding-md-template.md:7-10`); `constitution_hash` (0 script; prose `emit-agents-md/SKILL.md:72`, `constitution-drift.md:10`); `scope_metadata` (prose `express-bind.md:87`); `binding_metadata.retrieval` (prose `generate-units/SKILL.md:46`); `## Summary` (0 downstream; `binding-md-template.md:20-24`); Confirmed Claims field 3 (0); Tech-OQ Auto-Resolved cells, Tech-OQ Recommendations body, Auto-Resolved Deferred body (classification only); Suggested Unit Hard Rules tables (0 script); `- **Codebase reality**:` (0 script; prose `binding-mode.md:28`); binding.json envelope + `field_diff` + `codebase_map_provenance`; claims-ledger envelope + whole file (0 script); `bound/` annotations; symbol-index `lang/astgrep_version/file_count/generated_*`.

### Ringkasan lane B untuk keputusan JIT

1. **Tidak ada gate binding→units hari ini — hanya binding→bolts.** Gate keras tunggal `hooks/pre-tool-use:940-966`, armed `SKILL_NAME=mega-sdd:execute-bolts` (`:854`). generate-units refusal prose-only (`SKILL.md:19,38,50,138`; `task-typing.md:30-32`).
2. **Gate sudah recompute saat dispatch** (`:855-877`); recertify head vs anchor (`:504-580`).
3. **Unit = kontrak handoff nyata**; JIT per unit cukup mengisi 4 field (Q1).
4. **Dua coupling non-obvious:** LOCKED index (`build-locked-index.sh:35-72`, trigger mtime `binding.md` `:1357-1363`); `validate-handoff-binding-units.sh:123-136` glob whole-vault + "setiap OQ/CONFLICT id dikutip suatu unit" → harus unit-scoped bila binding per unit.
5. **Surface murah dibuang:** `bound/` annotation, ledger `doc_shas`, `field_diff`, `## Summary`/Tech-OQ cells/Suggested Hard Rules tables/`Codebase reality`, 4 key envelope symbol-index.

---

## Lane C — handoff YAML, `codebase-map.md`, grammar unit

### Handoff YAML

| Field | Producer | Consumer | Apa |
|---|---|---|---|
| `emitted_by` | `handoff-contract.md:27` | `validate-handoff-yaml.sh:207,267,293,538`; `hooks/pre-tool-use:789,795` | required + skill-name |
| `emitted_at` | `:28` | `validate-handoff-yaml.sh:267` | presence only (kontrak `:100` mengakui) |
| `status` | `:29` | `validate-handoff-yaml.sh:267`; `handoff-consumption.md:75,88,92` | branch control-flow |
| `artifacts[]` | `:30-33` | `validate-handoff-yaml.sh:298,573-580` (`os.path.exists` → `artifact_missing`) | eksistensi saja; klaim `:242` "locate the next skill's input" **tidak diimplementasi** |
| `next_action.suggested_skill/args` | `:35-36` | `handoff-consumption.md:83-84`; `validate-handoff-yaml.sh:559,599` (L9 `scope_args_missing`) | hop |
| `next_action.rationale` | `:37` | **none** | |
| `next_action.confidence` | `:144` | `validate-handoff-yaml.sh:350-359`; `handoff-consumption.md:80-82` | floor 0.80 |
| `blockers[]` | `:38-40` | `validate-handoff-yaml.sh:328`; `handoff-consumption.md:93-94` | |
| `metrics.items_blocked/items_processed` | e.g. `auto-memory-handoff.md:144`, `auto-and-handoff.md:69`; `:52` | `handoff-consumption.md:89`; `handoff-contract.md:283` | progress line |
| `metrics.units_with_starterkit_rules` | `generate-units/references/auto-and-memory.md:55` | `handoff-consumption.md:59-62` | b.ix gate |
| `metrics.acceptance_test_concerns` | `halts-and-handoff.md:62,309` | `chain-execution.md:222` | summary line |
| `starterkit_context.*`, `scope.*`, `constitution.*`, `metadata.model_tiers` | `:210,58-61,50`; `orchestrate-flow/SKILL.md:52` | `validate-handoff-yaml.sh:327-328`; `handoff-consumption.md:67`; `handoff-contract.md:194` | propagate / type-check |
| `checkpoints.*` / `cycles.*` / `replay.*` / `pbt.*` / `mutability.*` | `:45-68` | `validate-handoff-yaml.sh:327-328` | **dict type-check only** |

Validator/producer-only (14 dari ~32 leaf): `pbt.properties_validated/failed` (0), `cycles.cycle_count` (0), `cycles.halts_*` (`:323` komentar), `replay.divergence_classification` (0), `replay.snapshot_path`, `constitution.clauses_referenced`, `mutability.tier_distribution/locked_claims_touched/artifact_discards_proposed`, `scope.sibling_scopes` (`:60` "informational"), `checkpoints.latest_step_id/checkpoint_file/resume_command` (`checkpoint-protocol.md:97-99` template; file `.jsonl` yang operatif `:42`), `metadata.model_tier_sources` (`chain-execution.md:68` OPTIONAL), `next_action.rationale`, `emitted_at`, `metrics.duration_ms`.

**Re-derive vs baca handoff:** fase berikut re-derive dari disk — `orchestrate-flow/SKILL.md:66` (`derived.proposed_next` authoritative), `routing-rules.md:24`, `derive-state.sh:71-78`, `state_probes.py:1282-1290`, `bind-codebase/SKILL.md:11,48`, `handoff-contract.md:288-295,301` (`--resume` re-inspect CWD). Handoff hanya membawa hop control-flow + propagate (`handoff-consumption.md:67,83-84`). Gate-time recompute: `hooks/pre-tool-use:751-798` writer tunggal (`:762`), `content_sha256` dedup (`:757-758`).

### `codebase-map.md` + `starterkit-context.yaml` + `symbol-index.json`

Repo ini sendiri tanpa `.mega-sdd/codebase/` (express-born). Presence: `state_probes.py:55-57,192-195` → substitute `probe_symbol_index` `:526-531`; ladder `:1281-1290` (`:1283-1287` express `vault_no_map` → bind tanpa map). Bind: `bind-codebase/SKILL.md:142` (`bind_inputs_missing`) → express `express-bind.md:27,91` "not read at all", substrate index `:45-51` + `query-symbol-index.sh`. Gate degenerate-map `hooks/pre-tool-use:1175-1208` skip (`:1189`); `predictive-checks.md:80` `express_carve_out`. `last_scanned_commit` → probe 7, `validate-codebase-map.sh:150`, `hooks/session-start:241-243` (index head substitute, "round F4"). §1 Top-level / §2 Public interfaces / §3 Routes / §4 Data models → `validate-codebase-map.sh:154-159,185-215`; `build-fsd-core.sh:557-558,571` → absen = `[Pending — … Run scan-codebase.]` (`:560-561`). §5 Naming → `review-panel.md:89`; substitute pack (`resolve-framework-pack.sh:37`). **§6 Pattern signatures** → `build-dispatch-prompt.sh:2759-2775` (fallback kedua setelah starterkit-context `:2373`; keduanya absen → `omit("map_patterns")` `:2775`, `:2752`). §7 Framework → `resolve-framework-pack.sh:98,282-288`; `orchestrate-flow/SKILL.md:45-47`. starterkit-context: `build-dispatch-prompt.sh:2373-2387` (omit `:2752`); `resolve-framework-pack.sh:119,282-288`; `validate-starterkit-conformance.sh:41-45` SKIP; `validate-unit-spec.sh:630,659`; `ground.sh:342-368` (`:363` scan on-demand); `handoff-consumption.md:60`. symbol-index: `query-symbol-index.sh:29`; `build-dispatch-prompt.sh:2286,2365` (omit); `state_probes.py:528`; `hooks/session-start:242`; `validate-reuse-duplication.sh:71,91,93`; `derive-changed-paths.sh:57`; `publish-artifacts.sh:197`; `express-bind.md:45-51` (absen/stale → build atau classic). Express tidak pernah memproduksi map: `derive-codebase-map.sh:1-20` (assembler Step 10 scan), `ground.sh:8`, `scan-codebase/SKILL.md` description, `orchestrate-flow/SKILL.md:65-70`.

### Grammar unit (`unit-schema.md:22-141` frontmatter, `:148-216` body; `templates/unit.md:1-48`)

| Field | Readers (path:line) | Class |
|---|---|---|
| `id` | `validate-unit-spec.sh:151`; `build-graph.sh:424`; `build-fsd-core.sh:246`; `build-sit-evidence.sh:328`; `build-uat-scaffold.sh:486`; `build-dispatch-prompt.sh:1330`; `analyze-parallelism.sh:250`; `compute-unit-staleness.sh:70-86`; `run-acceptance-tests.sh:120` | all |
| `title` | `validate-unit-spec.sh:151`; `build-fsd-core.sh:247`; `build-sit-evidence.sh:330`; `build-uat-scaffold.sh:488`; `validate-flow-coverage.sh:667`; `agents/bolt-implementer.md:14,49` | |
| `vault_source` | `validate-unit-spec.sh:151,188-190` (**presence only**); `build-fsd-core.sh:253,370`; `build-sit-evidence.sh:332,342` (`F_ID_RE`); `build-uat-scaffold.sh:490,524`; prose `generate-units/SKILL.md:76,78`, `task-typing.md:161` | ANALYZE/DOCS |
| `task_type` | `validate-unit-spec.sh:151,167-177,186,329-376`; `resolve-review-tier.sh:91-92,127`; `build-graph.sh:424`; `agents/spec-reviewer.md:29` | |
| `status` | `compute-unit-staleness.sh:70,84,86` (`implemented`/`stale`/`unknown`; `:10` `superseded` NOT computed); consumers prose `unit-schema.md:38-39` | LIVE partial |
| `grounding_confidence` | `validate-unit-spec.sh:380` + A1 → `hooks/pre-tool-use:1071`; `diagnostics-procedures.md:50,73` | LIVE/ANALYZE |
| `risk` | `resolve-review-tier.sh:93-94,228-230,250-251` | LIVE |
| `mutability` | **ZERO READERS** (`unit-schema.md:58` mengakui) | — |
| `squad` | `analyze-parallelism.sh:250,263-267,412-413,457`; `build-graph.sh:424`; prose `squad-subagent.md:35`, `diagnostics-procedures.md:64` | ANALYZE/BUILD |
| `scope` | `build-dispatch-prompt.sh:987`; `build-fsd-core.sh:248,340`; `execute-bolts/SKILL.md:163` | LIVE/DOCS |
| `scope_name` | prose only (`execute-bolts/SKILL.md:163`, `halts-and-handoff.md:150`, `bolt-dispatch-prompt.md:38`) | |
| `reuse_candidates` | `build-dispatch-prompt.sh:996,1412-1423,2195,2218,2276`; `agents/bolt-implementer.md:39`; `review-panel.md:89` | LIVE |
| `module` | `build-graph.sh:424,439-441`; `analyze-parallelism.sh:250`; `validate-flow-coverage.sh:656-657`; `build-dispatch-prompt.sh:2160-2166` (refused as substitute) | BUILD/ANALYZE |
| `depends_on` | `build-graph.sh:426-429`; `analyze-parallelism.sh:250-253,405-414`; `build-dispatch-prompt.sh:3139-3141`; `diagnostics-procedures.md:73` | |
| `target_files` | `validate-unit-spec.sh:151,192,314-321`; `resolve-review-tier.sh:99-125,236-251`; **`validate-bolt-artifacts.sh:1106,1210-1224` (B3)**; `hooks/pre-tool-use:1003,1008,1076`; `build-dispatch-prompt.sh:2299-2300,2321-2328`; `validate-flow-coverage.sh:648-661`; `validate-new-deps.sh`; `agents/bolt-implementer.md:38,58` | LIVE all |
| `existing_interfaces` / `produces_interfaces` / `consumes_interfaces` | **prose only, 0 script/hook** (`generate-units/SKILL.md:90,72`; `bolt-contract.md:8`; `decomposition-rails.md:56`; `halt-protocol.md:26`; `batch-and-fanout.md:87`; `squad-subagent.md:35`) | prose |
| `allowed_new_deps` | `validate-new-deps.sh:59,134,143-150`; `code-gates.md:25,62` (advisory) | LIVE advisory |
| `acceptance_test[]` (`type`, `command`, `expects`, `desc`) | `validate-unit-spec.sh:207,279,301-321`; `run-acceptance-tests.sh:127-152` (`expects` = substring matcher `:145`); `build-dispatch-prompt.sh:1067-1085`; `build-sit-evidence.sh:343,211`; `build-uat-scaffold.sh:499,365`; `hooks/pre-tool-use` F-18 | LIVE/ANALYZE/DOCS |
| `acceptance_test[].ears` | parsed-never-used (`run-acceptance-tests.sh:145`, `build-uat-scaffold.sh:365`, `build-sit-evidence.sh:211`; `unit-schema.md:119`) | — |
| `binding_refs` | `validate-handoff-binding-units.sh:8,279,482,665`; `build-graph.sh:430-437`; `build-dispatch-prompt.sh:993,2129-2133`; `resolve-review-tier.sh:224-226`; `validate-constitution-propagation.sh:8,157`; `validate-constitution.sh:9` | LIVE/BUILD/ANALYZE |
| legacy `grounding_evidence` / `superpowers_skills` / `estimated_complexity` | 0 / `superpowers-bridge.md:34` / 0 | — |
| undeclared but parsed: `_authored_by` (`build-dispatch-prompt.sh:1065,1360-1382`), `implements_claim` (`build-fsd-core.sh:253,370`), `as_a/i_want/so_that/business_value` (`build-fsd-core.sh:249-250,340-341`), `unit_id` alias, `vault_anchors` alias | schema drift | |

Body: `## Goal`/`## Context`/`## Anti-patterns`/`## Implementation steps`/`## Out of scope` → verbatim via `build-dispatch-prompt.sh:1304-1305`, sliced per lens `review-panel.md:89`, `resolve-review-tier.sh:187,194-195` (contract sections); **0 script parse**; rule ">15-word sentence" (`unit-schema.md:281`) tanpa validator. `## Anchors` → `check-anchor-freshness.sh:107,121,132,169,185`; `build-dispatch-prompt.sh:1229,1332-1345`; `validate-unit-spec.sh:119,330-343`; `agents/spec-reviewer.md:31`. `## Hard rules` → `_lib/postflight_rules.py:95,484,678,736-737`; `run-preflight-scan.sh:178,183,262`; `run-postflight-scan.sh`; hook B1; `build-dispatch-prompt.sh:1087,1356,1654-1673,1703`; `resolve-review-tier.sh:194`; `validate-unit-spec.sh:630,659-665`; agents. `## Migration notes` → `validate-unit-spec.sh:347-376`. `## Acceptance criteria` → `build-fsd-core.sh:241`; `resolve-review-tier.sh:194`; A1 markers → `hooks/pre-tool-use:1071`.

xs cut set `build-dispatch-prompt.sh:115,238,278-282,3124-3126` (fail-open), `:3127-3172`: validation_hints (:3130-3132), confidence_labels (:3133-3134), depends_on_summaries ≤1 (:3136-3139), starterkit_slice/map_patterns non-UI (:3141-3142), pack/design/starterkit floor rung UI (:3157-3166), same-dir symbol rows (:2321-2328), NOTE trim (:1372-1379), tracker prose (:3314-3318,3331-3333); not cut `:3118-3121` (body verbatim, P9 constitution).

Sitasi: `vault_source` = `file#section` (template `:4`, `modules-schema.md:94`; schema `:26` menulis `:section`); presence-only (`validate-unit-spec.sh:188-190`); `build-graph.sh:392-399` strip `:line` — **pada binding.json**, bukan unit; `make-bound.sh:15,99,108` SRC_RE = binding.json. `## Anchors` = `path:line[-line]` (`check-anchor-freshness.sh:107,121,132,185,169`; builder `:1344-1345` "content drift NOT checked"). A1 `[grounded: path:line]` (`unit-schema.md:204-212`; `validate-unit-spec.sh:380`; hook `:1071`). **Unit tidak pernah menyitasi PRD** (`unit-schema.md:329,316,205-206,161`); identitas PRD lewat `vault.json` `prd_sha256` + handoff `scope.prd_sha256` (`handoff-contract.md:61`). Koreksi premis: `scripts/lint-units*` tidak ada (prose `diagnostics-procedures.md:14-100`; `:98`); `validate-flow-coverage.sh` + `build-graph.sh` tunggal.

---

## Lane D — inventaris gate/halt (89 situs @ `5f7f220`)

Kode verdict: **CAUGHT** (fired on a real defect) · **DEFECT-DOCUMENTED** (defect on record, gate built after) · **GATE-BUG** (gate proven broken, fixed) · **INERT-ON-FIELD** · **FIRED-0-TP** · **NONE FOUND**. `$P` = `plugins/mega-sdd`, `$R` = repo root.

| # | id | where | class | trigger | input | halt | catch record |
|---|---|---|---|---|---|---|---|
| 1 | python3-absent fail-closed | `$P/hooks/pre-tool-use:418-424` | PreToolUse block | Skill `*execute-bolts*`, no python3 | `.validation-blockers.json` grep `"status":"PASS"` | — | CAUGHT `$R/CHANGELOG.md:1722` |
| 2 | chain-arm switch | `:465-493`; writer `:557-586` | scoping switch | every gated call | `.gateguard-state.json` | — | NONE (`CHANGELOG.md:784` design) |
| 3 | scope-flag gate | `:589-646`; `validate-scope-flag.sh:209-210` | block | generate-intent / orchestrate-flow | user msg `--scope=`, PRD scope decl, `.scope-flag-state.json` | `scope_not_declared_in_prd` | NONE (`CHANGELOG-ARCHIVE.md:2868` pattern-prove) |
| 4 | Factory Line backward | `:648-702`; `validate-factory-ledger.sh:122-145` | block | 5 upstream skills | `factory-ledger.json` → `.factory-ledger-state.json` | `phase_stuck`, `anti_spin` | DEFECT-DOCUMENTED `CHANGELOG-ARCHIVE.md:1058` |
| 5 | predictive preflight FATAL | `:704-739`; `validate-preflight.sh:632-660` | block | bind/units/bolts/scan | vault docs, units, map, partial-state, git → `.preflight-state.json` | `predictive_check_failed` family | GATE-BUG `CHANGELOG-ARCHIVE.md:726` |
| 6 | handoff-validation gate | `:741-840`; `validate-handoff-yaml.sh` | block | every `mega-sdd:*` Skill | transcript last assistant msg; `.handoff-validation-state.json` | `invalid_handoff`, `handoff_type_mismatch`, `handoff_missing`, `artifact_missing`, `scope_args_missing` | GATE-BUG `CHANGELOG-ARCHIVE.md:1211` |
| 7 | gate-time re-derive fan-out (9 validators parallel) | `:869-909` | precondition rows 8-23 | execute-bolts / bolt-implementer | runs handoff-binding-units, unit-spec, flow-coverage, sibling ×2, bolt-artifacts (orphan/batch/postflight recompute/whitelist/acceptance/panel), ui-quality, factory-ledger | — | CAUGHT `CHANGELOG.md:530` |
| 8 | **MOAT binding→units** | `:946-966`; `validate-handoff-binding-units.sh:255-680` | block, fail-CLOSED | execute-bolts | `binding.md` CONFLICT blocks, `binding.json claims[]`+`head`, unit `binding_refs`, `vault.json`, git → `.validation-blockers.json` | `conflict_unresolved`, `binding_missing`, `oq_id_dropped`, `conflict_id_dropped`, `binding_stale_recertify` | CAUGHT `CHANGELOG-ARCHIVE.md:1257`; GATE-BUG `:721` |
| 9 | bolt-orphans | `:972-976`; `validate-bolt-artifacts.sh --orphan-scan` | block | run boundary | git bolt commits × `bolt-report.md` → `.bolt-orphans-state.json` | `bolt_orphans` | CAUGHT `CHANGELOG-ARCHIVE.md:1254,1257`; `CHANGELOG.md:530` |
| 10 | batch-suite-gate B2 | `:984-991` | block (run boundary) | execute-bolts | `_batch-suite.json` (READ), git → `.batch-suite-gate-state.json` | `batch_suite_red`, `batch_suite_gate_missing` | CAUGHT `CHANGELOG-ARCHIVE.md:971` |
| 11 | postflight-evidence B1 | `:996-1000`; `_lib/postflight_rules.py` | block (RECOMPUTED) | execute-bolts | unit `## Hard rules` @ commit, git/fs, `preflight.json` → overwrites `postflight.json` → `.bolt-postflight-state.json` | `postflight_evidence_missing`, `hard_rule_violated` | CAUGHT `CHANGELOG-ARCHIVE.md:984`; FIRED-0-TP DO_NOT_MODIFY `CHANGELOG.md:536` |
| 12 | whitelist-observer B3 | `:1004-1008` | block | execute-bolts | git touched-set vs `target_files` ∪ extras → `.bolt-whitelist-state.json` | `whitelist_violation` | CAUGHT `CHANGELOG.md:530`; origin `CHANGELOG-ARCHIVE.md:697` |
| 13 | acceptance-evidence B4 | `:1016-1030` | block (commit-keyed `SDD-Acceptance: v5`) | execute-bolts | `acceptance.json`, trailer, `acceptance_test[]` → `.bolt-acceptance-state.json` | `acceptance_evidence_missing`, `acceptance_red`, `build_broken` | CAUGHT `CHANGELOG.md:478` |
| 14 | panel-evidence F-07 | `:1035-1040` | block | execute-bolts | `review-tier.json`, `findings.json`, `l0-results.json` → `.bolt-panel-state.json` | `panel_evidence_missing`, `l0_evidence_missing` | CAUGHT `CHANGELOG.md:478` |
| 15 | acceptance-expects F-18 | `:1046-1053` | block (in-run per unit) | bolt-implementer dispatch | `acceptance_test[]` via `.unit-spec-state.json` | `acceptance_expects_missing` | CAUGHT `CHANGELOG.md:488,478` |
| 16 | flow-coverage | `:1056-1060`; `validate-flow-coverage.sh` | block | execute-bolts | **`flows.md`** steps, pack `## Flow-artifact derivation`, unit targets → `.flow-coverage-state.json` | `missing_artifacts`, `dead_scaffold` | INERT-ON-FIELD `CHANGELOG.md:465` |
| 17 | render-test | `:1063-1067` | block (halt_type count) | execute-bolts | `target_files` view shapes × `type: render` | `render_test_missing` | GATE-BUG `CHANGELOG-ARCHIVE.md:711`; INERT `CHANGELOG.md:465` |
| 18 | verify-grounding A1 | `:1068-1071` | block | execute-bolts | verify+HIGH `[grounded:]` anchors | `verify_grounding_untrusted` | GATE-BUG `CHANGELOG-ARCHIVE.md:711` |
| 19 | acceptance-path | `:1072-1076`; `validate-unit-spec.sh:8-10` | block | execute-bolts | acceptance cmd paths × all `target_files` × fs | `acceptance_path_unowned` | GATE-BUG self-caught `CHANGELOG.md:601` |
| 20 | sibling-consistency | `:1079-1083` | block | execute-bolts | cross-cutting decl + FK accessors, pack → `.sibling-consistency-state.json` | `inconsistent`, `missing_relations` | INERT `CHANGELOG.md:465`; GATE-BUG `CHANGELOG-ARCHIVE.md:710` |
| 21 | ui-quality | `:1086-1091` | block | execute-bolts | view files + pack `view_glob` → `.ui-quality-blockers.json` | `scaffold_tells_matched`, `required_elements_missing` | INERT `CHANGELOG.md:465`; CAUGHT-BY-PROXY `CHANGELOG.md:1316` |
| 22 | cross-cutting-registration | `:1094-1097` | block | execute-bolts | pack regexes → `.cross-cutting-state.json` | `missing_registration` | INERT `CHANGELOG.md:465`; GATE-BUG `CHANGELOG-ARCHIVE.md:696` |
| 23 | Factory Line forward | `:1100-1104` | block | execute-bolts | `factory-ledger.json` | `ledger_*`, `phase_stuck`, `anti_spin` | GATE-BUG `CHANGELOG-ARCHIVE.md:696` |
| 24 | multi-fail surfacing M-07 | `:1106-1118` | deny-message shaping | ≥2 fails | `fails[]` | — | CAUGHT (cost) `CHANGELOG-ARCHIVE.md:473` |
| 25 | bind DEGENERATE-MAP | `:1130-1221`; `validate-codebase-map.sh:160-178` | block | bind-codebase | `codebase-map.md` fm + 7 sections → `.codebase-map-state.json` | `codebase_map_sections_incomplete` (+5) | CAUGHT `CHANGELOG-ARCHIVE.md:1257`; GATE-BUG `:738,726` |
| 26 | forged-gate-state deny | `:1279-1294`, `:1334-1336` | Edit/Write block | 15 guarded basenames | path only | — | CAUGHT `CHANGELOG-ARCHIVE.md:729`; Windows `CHANGELOG.md:1652` |
| 27 | pack-resolver cache deny | `:1309-1316` | Edit/Write block | `.cache/pack-resolver/*` | path | — | CAUGHT `CHANGELOG.md:1316` |
| 28 | bolt evidence-artifact deny | `:1317-1321`, `:1337-1339` | Edit/Write block | `bolts/U-*/{pre,post}flight|acceptance|findings|review-tier.json`, `_batch-suite.json` | path regex | — | CAUGHT `CHANGELOG-ARCHIVE.md:387`; `run-full-suite.sh:4-8` |
| 29 | L0 record deny | `:1322-1324` | Edit/Write block | `lens-inputs/*/l0-results.json` | path | `l0_evidence_missing` | CAUGHT `CHANGELOG.md:478` |
| 30 | UAT evidence deny | `:1325-1331` | Edit/Write block | `uat/evidence/**/result.json` | path | `execution_fabricated`/`ANNEX_FORGED` | NONE (comment `:1326-1330`) |
| 31 | GateGuard LOCKED deny-once | `:1342-1451`; `build-locked-index.sh:34-38` | Edit/Write block (chain-scoped) | file in `.locked-files-index.json` | index dari **binding.md, bound/*.md, vault docs, constitution.md**; rebuild trigger mtime binding.md (`:1357-1363`) | — | NONE (cost `CHANGELOG-ARCHIVE.md:473`) |
| 32 | wave commit rail F-16 | `:1462-1482`; `vault_layouts.py:inflight_units` | Bash block | sweeping git verbs | `dispatch-prompt.md` vs `postflight.json` mtime | — | DEFECT-DOCUMENTED `CHANGELOG.md:542` |
| 33 | anti-self-bypass verb battery | `:1544,1553-1596,1598-1601`; `:1512-1533` | Bash block (fail-closed) | protected path × 14 verbs | 15 state files + evidence + cache | — | CAUGHT `CHANGELOG-ARCHIVE.md:729`; `mv` `CHANGELOG.md:536` |
| 34 | binding-doc delete rail | `:1550,1579-1580` | Bash block | `rm`/`unlink` `vaults/**/binding*.md` | path | — | DEFECT-DOCUMENTED `CHANGELOG-ARCHIVE.md:725-729` |
| 35 | Stop bolt-artifact scan | `$P/hooks/stop:104-181` | Stop leg → rows 9-14 | every turn | `.stop-scan-stamp`, `find -newer`, bolt commits + evidence (no `--recompute`) | writes 6 state files | GATE-BUG `CHANGELOG.md:1316` |
| 36 | auto-analyze aggregate | `stop:188-229` | Stop leg advisory | opt-in classic/full | state files → `CONSISTENCY-REPORT.md` | — | NONE |
| 37 | artifact publisher | `stop:231-246`; `publish-artifacts.sh` | Stop leg fail-open | vaults/graph exist | sha state, credentials | — | NONE |
| 38 | dirty-paths journal | `post-tool-use:103-143,335-362` | PostToolUse | Write/Edit in-repo | `config.yaml`; `.dirty-paths.jsonl` | — | CAUGHT `CHANGELOG.md:1627` |
| 39 | LOCKED-edit advisory №G | `post-tool-use:146-172,199` | notice | Write/Edit hitting index | `.locked-files-index.json` | — | NONE |
| 40 | `auto_verify_on_edit` offer | `post-tool-use:173-199` | notice (default false) | Write/Edit of a unit target | unit `target_files`+`acceptance_test` | — | NONE |
| 41 | anchor injection | `session-start:19-60,330` | SessionStart | startup/resume/clear/compact | SDD signal | — | CAUGHT `session-start:56-58` |
| 42 | missing-interpreter notice | `session-start:190-223` | notice | no python3 | | pairs row 1 | CAUGHT `CHANGELOG.md:1722` |
| 43 | living-vault staleness notice | `session-start:231-318` | notice | vault present | map stamp vs HEAD; journal; index head | — | NONE |
| 44 | generate-units HARD GATE | `generate-units/SKILL.md:38,50,19,138` | prose HALT (backed rows 8,71) | generate-units | `binding.md` unresolved CONFLICT | `bind_conflict` | CAUGHT-as-prose-gap `CHANGELOG-ARCHIVE.md:721` |
| 45 | generate-units mixed-verdict | `SKILL.md:63,40` | prose HALT | Step 2.5 | State Map rows | bypass report | NONE |
| 46 | OQ-ID propagation 12.5.g | `SKILL.md:113,125` | prose HALT (backstop row 8) | per unit | binding OQ × `binding_refs` | `unit_oq_trace_missing` | CAUGHT `CHANGELOG-ARCHIVE.md:3634` |
| 47 | anchors + hard-rule grammar | `SKILL.md:127`; `validate-unit-spec.sh:5-7` | prose + validator | authoring | anchors; `## Hard rules` vs 5 productions | `unit_underspecified`, `hard_rule_unparseable`, `hard_rule_mixed_grammar`, `starterkit_rule_citation_missing` | CAUGHT `CHANGELOG-ARCHIVE.md:711` |
| 48 | DAG / module halts | `$P/references/halt-families/units.md:17-53` | prose HALT | DAG build | `depends_on`, modules, squads, interfaces | `dedup_ambiguous`, `cycle_detected`, `cross_squad_*`, `interface_ref_missing`, `cross_module_dep_invalid`, `module_cycle_detected` | registry gap CAUGHT `CHANGELOG.md:31` |
| 49 | bind Step 0 input/glob-root | `bind-codebase/SKILL.md:34,36,38,142` | prose HALT | bind | vault resolution (4 docs / legacy) | `bind_inputs_missing` | CAUGHT `SKILL.md:36` |
| 50 | bind Step 5 decision gate | `SKILL.md:103-124,132,135`; `binding-contract.md:168,172` | prose HALT (backed row 71) | end of bind | counts `conflict>0` / `--strict` oq | `bind_conflict` | CAUGHT `CHANGELOG-ARCHIVE.md:725` |
| 51 | bind project-constitution gate | `SKILL.md:59`; `constitution-and-oq.md` | prose HALT | new vault | `.mega-sdd/constitution.md` × claims | `bind_conflict_constitution_violation` | CAUGHT-adjacent `CHANGELOG-ARCHIVE.md:1257` |
| 52 | bind Tech-OQ recommendation gates | `SKILL.md:137,142`; `validate-vault-oqs.sh` | prose + validator | Step 2.5-2.11 | OQ recommend fields | `oq_recommend_underspecified`, `oq_recommend_citation_invalid`, `oq_tech_missing_mode`, `oq_scan_missing_query` | CAUGHT (false-block) `CHANGELOG-ARCHIVE.md:729` |
| 53 | bind framework-pack gates | `SKILL.md:142`; `halt-families/bind.md:17,21,25` | prose HALT | pack resolution | `.mega-sdd/packs/*.md`, `extends:` | `framework_pack_missing/cycle/unparseable` | CAUGHT `CHANGELOG.md:465` |
| 54 | generate-intent OQ classifier | `generate-intent/SKILL.md:117` | prose HALT | Step 3.5 | OQ brackets/patch | `oq_*` | NONE |
| 55 | generate-intent self-check | `SKILL.md:130`; `self-check.md:8-63` | prose gate | before delivery | 4 vault docs | `oq_blocker` (from-prompt) | NONE |
| 56 | **OQ blocking-tier `oq_gate`** | `routing-rules.md:52,99,108-109`; `resolve-oq/SKILL.md:54-56` | prose route | routing | **`vault.json open_questions[]` → fallback `constraints.md ## Open Questions`** (`state_probes.probe_oq_counts`) | `oq_business_p1_unresolved` | NONE (naming `state_probes.py:839-846`) |
| 57 | factory-ledger contract rules | `factory-ledger-contract.md:28-36` | prose HALT (twin rows 4,23) | handoff | `unresolved[].id` grammar | `ledger_schema` | NONE |
| 58 | checkpoint resume re-validation | `checkpoint-protocol.md:126,102-111,82-88` | prose HALT | `--resume` | checkpoint + phase inputs re-loaded | resume-integrity | NONE |
| 59 | execute-bolts pre-flight ladder | `execute-bolts/SKILL.md:55-66` | prose HALT (script-backed) | run start | unit fm, manifests, git hooks, `## Anchors` vs git, `## Hard rules`, `properties[].cites` | `verify_unit_writable`, `dep_missing`, `commit_rejected_by_hook`, `anchor_missing`, `hard_rule_*`, `pbt_citation_invalid`, `sprint_blocked_by` | CAUGHT `check-anchor-freshness.sh:4-9` |
| 60 | L0 blocking trio | `SKILL.md:70,87`; `run-code-gates.sh:23-25,364-374,392,415` | prose + exit 1 | after commit, before panel | diff → secrets/SAST/deps | `secret_in_code`, `sast_critical_finding`, `dep_not_found` | CAUGHT `CHANGELOG.md:478` |
| 61 | review-panel cap | `SKILL.md:88` | prose HALT | round exhaustion | `findings.json`, verifier | `review_critical_unresolved` | CAUGHT `merge-panel-findings.sh:7-13` |
| 62 | post-flight Hard-rule halt | `SKILL.md:120,157` | prose HALT (twin row 11) | after DONE | `run-postflight-scan.sh` | `hard_rule_violated` | CAUGHT `CHANGELOG-ARCHIVE.md:984` |
| 63 | B4 acceptance halt | `SKILL.md:89` | prose HALT (twin row 13) | after post-flight | `run-acceptance-tests.sh` | `build_broken`, `acceptance_red` | CAUGHT `CHANGELOG.md:478` |
| 64 | per-bolt LOCKED drift check | `SKILL.md:122`; `halts-and-handoff.md:83-106` | prose HALT (pure-pause) | after post-flight | binding [LOCKED] entities | `bolt_introduces_locked_drift` | NONE |
| 65 | self-assessment + provenance trailer | `SKILL.md:116,126`; `validate-bolt-artifacts.sh:5-7` | prose + validator | report write | `bolt_self_report`; trailer | `self_assessment_missing`, `provenance_missing` | NONE |
| 66 | B2 full-suite halt | `SKILL.md:142`; `halts-and-handoff.md:189-212` | prose HALT (twin row 10) | last bolt | `run-full-suite.sh` | `batch_suite_red` | CAUGHT `CHANGELOG-ARCHIVE.md:971` |
| 67 | dispatch-prompt budget halt | `SKILL.md:109-112,116`; `build-dispatch-prompt.sh` | prose HALT (exit-coded) | Step 4.5 | T1/T2/T3 assembly | `dispatch_prompt_too_large` | CAUGHT (cost) `CHANGELOG.md:512` |
| 68 | partial-state / saga | `SKILL.md:146` | prose HALT | `--resume` | `partial-state.json` | `bolt_repeated_partial_failure`, `partial_state_corrupt` | NONE |
| 69 | extract module quality gate | `extract-intelligence/SKILL.md:121-122,132,167-168` | prose HALT — legacy lane | per module | `*.prd.md` + `.verify/*.json` | `quality_gate_failed` | NONE |
| 70 | extract census gate | `SKILL.md:153-155,169`; `validate-extract-census.sh:5-20` | prose + script — legacy lane | end of extraction | `census.json` × modules × citations × Mermaid × verify × site-census → `.extract-census-state.json` | `kb_*`, `claim_verify_*`, `site_uncovered`, `rollup_mismatch` | CAUGHT-as-inertness `$P/CLAUDE.md` §Producer-grammar sweep; `CHANGELOG.md:225-226` |
| 71 | `make-bound.sh` CONFLICT refusal | `make-bound.sh:8-11,65-76,29-35` | script exit (2nd CONFLICT gate) | bind Step 6 | `binding.json claims[].verdict` | exit 2/3 | CAUGHT `CHANGELOG.md:817` |
| 72 | `check-anchor-freshness.sh` | `:2-25,65` | script exit (commit-keyed advisory) | pre-flight 3.7 | `## Anchors` vs git | `anchor_missing` | DEFECT-DOCUMENTED `:6-9` |
| 73 | `run-preflight-scan.sh` | `:1-34,100` | script exit (sole writer) | §4 | `## Hard rules`, sha of targets | `hard_rule_*`, `dep_missing`, 7, 8 | FIRED-0-TP `CHANGELOG.md:536` |
| 74 | `run-postflight-scan.sh` | `:1-30,61` | script exit (sole writer) | §5 / recompute | v1 + v2 rules vs git/fs; directives advisory | exit 1 | CAUGHT (over-count) `CHANGELOG.md:506` |
| 75 | `run-acceptance-tests.sh` | `:1-40,81` | script exit (sole writer) | §5 | `acceptance_test[]`, tree, syntax floor | `build_broken`, `acceptance_red` | CAUGHT `CHANGELOG.md:488` |
| 76 | `run-full-suite.sh` | `:1-25` | script exit (sole writer) | batch completion | manifest runner, HEAD pin | exit 1/2 | CAUGHT `CHANGELOG-ARCHIVE.md:387` |
| 77 | `merge-panel-findings.sh` | `:1-31` | script gate (sole `findings.json` writer) | per round | lens FINDINGS blocks | `gate` field | CAUGHT `:7-13` |
| 78 | `resolve-review-tier.sh` | `:1-31` | script router (+ obligation key) | per unit | `target_files` × pack hints; deps; count; scoped vocab; `binding_refs` §B; `risk` | tier/lenses/model/`unit_tier` | CAUGHT `CHANGELOG.md:564,568` |
| 79 | `validate-binding-json.sh` | `:1-3,17` | script exit | bind 4.5 / analyze | State Map ↔ claims[] | exit 2/3 | NONE |
| 80 | `certify-artifact.sh` | `:11-20,45,98-104,154` | script exit — adoption lane | `/mega-sdd <artifact>` | per rung validators (scratch cwd) | exit 3/4/0 | CAUGHT (migration sweep) `CHANGELOG-ARCHIVE.md:149` |
| 81 | dispatch-prompt advisory | `run-analyze.sh:537` → `validate-dispatch-prompt.sh` | advisory | analyze | `dispatch-prompt.md` vs spec | — | NONE (`pre-tool-use:852-853`) |
| 82 | operator-UX (vault-oqs) | `run-analyze.sh:475` → `validate-vault-oqs.sh:80` | advisory | analyze | 4 vault docs + vault.json | `operator_surface_*`, `oq_misclassified_tech`, `oq_recommend_citation_invalid` | CAUGHT `CHANGELOG-ARCHIVE.md:725` |
| 83 | fan-out-parity | `run-analyze.sh:534` | advisory | analyze | squad/module sets | `fanout_parity_divergence` | NONE |
| 84 | ui-deferral | `run-analyze.sh:535` | advisory | analyze | deferred UI elements | — | NONE |
| 85 | vault-flow-staging | `run-analyze.sh:536` → `validate-vault-flow-staging.sh` | advisory | analyze | **`flows.md`** staging | `kb_flow_staging_missing` | NONE |
| 86 | constitution + propagation | `run-analyze.sh:522,525` | advisory | analyze | `.mega-sdd/constitution.md` × unit citations | `constitution_*` | CAUGHT (false-positive) `CHANGELOG-ARCHIVE.md:1257` |
| 87 | starterkit-conformance | `run-analyze.sh:499` | advisory | analyze | starterkit rules × units | `starterkit_rule_citation_missing` | CAUGHT `CHANGELOG-ARCHIVE.md:711` |
| 88 | KB surface advisories ×5 + reuse-duplication | `run-analyze.sh:483,487,491,495,510,541` | advisory | analyze | KB `modules/*.prd.md`; reuse-index vs diff | `kb_*` (+`kb_discovery` MISCONFIGURED), `defaulted_standard_uncited` | CAUGHT `CHANGELOG.md:225-226` |
| 89 | registry-only halt vocabulary | `halt-protocol.md:75`; `halt-families/*.md` | vocabulary | routing/envelopes | — | `mode_migrate`, `memory_in_use`, `convergence_max_reached`, `no_starterkit_detected`, `adoption_demote_confirm`, `delta_too_large`, `diff_conflict`, `drift_framework_mismatch`, `constitution_drift_detected`, `model_tier_unknown`, `install_failed`, `pkg_mgr_not_found`, `prd_path_missing`, `prd_retrofit_low_confidence`, `prd_no_scopes_block_user_rejected_retrofit`, `deep_scan_*`, `dep_missing`, `pdf_render_failed`, `template_slot_unfilled`, `citation_unresolvable`, `signoff_fabricated`, `execution_fabricated`, `marker_stripped`, `ambiguous_spec`, `test_fail`, `scope_creep_detected`, `module_blocked_by`, `pbt_property_violated` | CAUGHT (registry gaps) `CHANGELOG.md:31,946` |

`state_probes.py` re-derived states (semua recompute dari disk): `_vault_docs`/`V2_DOC_NAMES` (:148-160 — **4 dok layout-2** + legacy); `has_vault`/`has_bound_or_vault`/`has_units` (:162-186); `has_codebase_map` (:188-197); `probe_prd_candidates` (:213); `probe_git` (:290); manifests (:317,336); pack (:383,391,443); `probe_symbol_index` (:525); `probe_astgrep` (:546); `probe_spine` (:561); `probe_code_files` (:578); `probe_codebase_map` (:604); KB (:637,656); `probe_foreign_sdd` (:686); `probe_dirty_journal` (:724); units/bolts (:754,765); **`_conflict_block_stats`** (:771-806, `binding.md ## Conflicts`); **`probe_binding`** (:808-838); **`probe_oq_counts`** (:839-885, `vault.json open_questions[]` → fallback `constraints.md`); vaults (:886,971); `collect_probes`/`derive`/`collect_state` (:998,1063-1178,1330; express→classic downgrade :1108-1118).

**A — keyed vault docs (re-key bila vault jadi emisi turunan):** rows 5, 16, 31/39, 49, 54/55, 56, 58, bind `--express` sweep (`bind-codebase/SKILL.md:28` — A *dan* B), 71, 82, 85, 64; writer derived se-kelas: `derive-vault-json.sh:60,199`, `derive-claims-ledger.sh:34,119`, `build-fsd-core.sh:70`, `build-sit-evidence.sh:97`, `build-uat-scaffold.sh:91`, `build-prd-core.sh:71`, `migrate-paths.sh:115,191` (`import vault_md`).
**B — keyed binding (re-key bila bind = gate JIT):** rows 1, 8 (glob non-rekursif `vaults/binding.md`, `vaults/binding-*.md`, `vaults/*/binding.md`, `vaults/*/binding-*.md` — `bind-codebase/SKILL.md:36`), 25, 26, 31, 33, 34, 44/45, 46, 47 (`validate-unit-spec.sh:666` Suggested Unit Hard Rules), 50-53, 71, 78, 79, 57, 4/23; konsumen claims-ledger.
**C — keyed units+bolts+git saja (tidak terpengaruh):** rows 3, 6, 9-15, 17-22, 24, 27-30, 32, 35-38, 40-43, 48, 59-63, 65-68, 72-77, 81, 83, 84, 87, 88, 89 (≈38 situs = seluruh moat bolt-stage).
**Out of scope greenfield/PRD:** rows 69, 70 (extract), 80 (adoption), 88 KB advisories.

---

## Lane E — lane DOCS (emit-*) + lane LIVE

### DOCS — shared engine

| doc § | input | source | path:line | alternatif? |
|---|---|---|---|---|
| all/step 2 | prior-emit drift | `<vault>/<doc>/.citation-map.json` via `build-citation-map.sh --check-drift` | `emission-engine.md:38,51`; `build-citation-map.sh:135-148` | YES (emitter-owned) |
| all/step 6 | citation resolution | `vault/`-prefix → vault → project → `.mega-sdd/codebase/` | `build-citation-map.sh:107-117,199-207` | mekanisme source-agnostic; string sitasi harus resolve (exit 1 `citation_unresolvable`) |
| all/step 8 | version/Riwayat | `.doc-history.json` via `refresh-doc-stamps.sh` | `emission-engine.md:52-53` | YES |
| all/step 5 | unfilled-slot scan | `{{slot}}` grep | `emission-engine.md:41`; `emit-prd/SKILL.md:59`; `emit-uat/SKILL.md:85` | YES |

### PRD (`build-prd-core.sh`)

| § | input | path:line | alternatif? |
|---|---|---|---|
| mode | vault presence / KB README | `prd-sections.md:27-31`; `:98-104` | YES |
| header | `vault.json` title, vault_version | `:389,400` | YES (`title` carry-forward; PRD punya title) |
| §1 | Overview §Purpose/§Scope (+§Goals) — model slot | `:169`; `vault_md.py:199-207,235-243`; `prd-sections.md:57-62` | YES — dari PRD asli (butuh branch builder baru; `vdoc()` hard-wired) |
| §1 reverse | KB README + `00-overview/` | `:98-104` | YES (KB) |
| §2 actors | **`_meta/squads.yaml` saja** (mechanical) | `:180-189`; `prd-sections.md:66-70` | NO untuk squads.yaml; Overview/flows legs = model slot (`emit-prd/SKILL.md:54`) |
| §3 FR forward | `02-functional.md` FR-NNN first para; fallback `04-flows.md` `### F-*` | `:201-220`; `prd-sections.md:74-81` | PARTIAL — teks FR PRD-native; unit cuma F-id |
| §3 reverse | KB claims + markers | `:228` | YES |
| §4 journeys | `flows.md` **Mermaid verbatim** | `:248-265`; `prd-sections.md:86-93` | **NO** — authored generate-intent; absen dari PRD/units/kode |
| §5 NFR | `02-functional.md §NFR` + constitution `[LOCKED]` | `:297-315`; `prd-sections.md:97-101` | CONDITIONAL (PRD kalau menyebut; constitution authored-only `multi-prd-lifecycle.md:34`) |
| §6 open items | `constraints.md` → `vault.json.open_questions[]` | `:332-362`; `prd-sections.md:106-109` | **NO** (OQ = gap PRD) |
| gate 4.7 | `check-prd-markers.sh --kb` | `emission-engine.md:58`; `emit-prd/SKILL.md:67-71` | YES |

### FSD (`build-fsd-core.sh`)

| § | input | path:line | alternatif? |
|---|---|---|---|
| mode | bolts glob else units glob | `:135-137`; `section-mapping.md:50-54` | YES (units/bolts) |
| header | `vault.json` `vault_version`, **`author`** | `:160,322,325-327` | NO `author` (bukan DERIVED_TOP `derive-vault-json.sh:88-92` maupun KEY_ORDER `:100-107` — carry-forward murni) |
| §1 | Overview §Purpose|§Product + §Scope|§Target users / personas | `:185,283-292`; `section-mapping.md:61-64` | YES substansi (PRD), NO as-keyed (heading literal `:283`) |
| §2 | Overview §Goals + §Non-Goals | `:297-302`; `section-mapping.md:69-72` | YES (PRD) |
| §3 stakeholders | `squads.yaml` → `vault.json.stakeholders[]` → `author` | `:306-331`; `section-mapping.md:77-88` | **NO** (authored) |
| §4 user stories | units `unit_id,title,scope,as_a,i_want,so_that,business_value,command,expected,implements_claim/vault_source` | `:224-254`; `section-mapping.md:93-101` | **YES — 100 % unit** |
| §5 FR | `02-functional.md` FR; fallback `04-flows.md` `### F-*` + DoD (priority `—`) | `:411,414-486`; `section-mapping.md:106-108` | PARTIAL (preseden re-source) |
| §5 verdict | `binding.md` per-line `CONFIRMED|CONFLICT|OQ` + `[C-NNN]` | `:187-192,386-397,405` | **NO** (produk bind) |
| §5 unit/bolt cols | units + bolts | `:406-407` | YES |
| §6 NFR | `02-functional.md §NFR` + `constraints.md ## Non-functional requirements` + constitution `[LOCKED]` | `:496-554`; `section-mapping.md:131-140` | CONDITIONAL |
| §7 entities/modules | **`codebase-map.md`** §Entities/§Modules | `:556-561,195-200` | YES (code-derived) |
| §7 confirmed claims | `binding.md ## Confirmed Claims` | `:559,562,568` | NO |
| §8 API | `codebase-map.md` §Public interfaces + §Entities | `:595`; `section-mapping.md:164-172` | YES |
| §9 pre-dev | units `acceptance_test.command/expected` | `:600-603` | YES |
| §9 post-dev | bolt-reports `bolt_status`, commit, `acceptance_test_concern`, `bolt_subagent_id` | `:258-271,604-618` | YES |
| §10 OQ | `constraints.md` → `vault.json` → 00-index backstop | `:620-653` | NO |
| §10 concerns / out-of-scope | bolt-reports; Overview §Non-Goals | `:655-660,656-658` | YES |

### SIT (`build-sit-evidence.sh`) dan UAT (`build-uat-scaffold.sh`, `build-uat-e2e.sh`, `build-uat-xlsx.sh`)

SIT: pre-flight vault presence (`emit-sit/SKILL.md:41`); scope ids `vault.json.scope_metadata.id` (`:42,254-257` — NO, carry-forward `derive-vault-json.sh:11`); §1–§2 scenarios `flows.md` `### F-*` + Mermaid verbatim + DoD (`:100-101,253-266,440`; `vault_md.py:94,118,121` — **NO**, units cuma F-id `:325-338`); §3 units matrix (`:314-341` — YES); §3 modules `_meta/modules.yaml` (`:343+` — NO); §4.1 `acceptance.json` (`:9-10,380,552-574`), §4.3 `postflight.json` (`:10-11,381,611-623`), §4.4 `_batch-suite.json` (`:11,382,631-639`) — YES bolt artifacts; maturity script-computed (`:37,689-690`; `SKILL.md:49-54`); §5 sign-off literals (`emission-engine.md:57`; `SKILL.md:86-91`). UAT: scope ids (`:38,407-409,520` — NO); §1–§2 flows (`:94-95,567` — NO); §2 step rows dari Mermaid nodes (`emit-uat/SKILL.md:74`; `:186-188,637` — NO); units (`:472-501,524` — YES); SIT entry gate maturity (`:32,115,593`; `SKILL.md:61`); execution literals (`:125-208,304`; `emission-engine.md:59`); §5 annex `result.json` via `_lib/uat_annex.render_annex()` (`:272-282`; `SKILL.md:126,179`); xlsx version sidecar (`emission-engine.md:60`); e2e `test.fixme()` + `// source:` anchors (`SKILL.md:118`).

### VAULT-ONLY facts

**A. Harus tetap ditulis di depan (emitter membacanya):** (1) Mermaid flow + DoD (`build-prd-core.sh:248-265`, `build-fsd-core.sh:414-486`, `build-sit-evidence.sh:100-101,253-266`, `build-uat-scaffold.sh:94-95`; units cuma F-id `build-sit-evidence.sh:325-338`); (2) Open Questions (`constraints.md` grammar `vault_md.py:41-91` → `vault.json.open_questions[]`; PRD §6, FSD §10) + patch-lane `scan_query/recommendation/rationale/scan_citations/fallback_if_wrong/defer_to` (`derive-vault-json.sh:13-17`); (3) `vault.json.author` (`build-fsd-core.sh:160,322,325-327`); (4) `vault.json.stakeholders[]` (`:322`; `section-mapping.md:80`); (5) `_meta/squads.yaml` (`build-fsd-core.sh:306-318`; `build-prd-core.sh:180-189`); (6) `_meta/constitution.md` `[LOCKED]` (`build-fsd-core.sh:493,545,554`; `build-prd-core.sh:298,310,315`; `multi-prd-lifecycle.md:34`); (7) NFR targets (`build-fsd-core.sh:496-497,550`; `build-prd-core.sh:297,313`) — conditional; (8) `scope_metadata.id` (`build-sit-evidence.sh:42,254-257`; `build-uat-scaffold.sh:38,407-409`); (9) `prd_sha256` + `prd_path_at_generation` (`diff-vault/SKILL.md:61,87`; `derive-vault-json.sh:9-11`); (10) heading vocab Overview (`build-fsd-core.sh:283-302,656-658`; `build-prd-core.sh:169`); (11) `_meta/modules.yaml` (`build-sit-evidence.sh:343+`; `build-graph.sh:402-414`); (12) `binding.md ## Confirmed Claims` + verdict rows (`build-fsd-core.sh:559,562,568,386-397`).

**B. Vault-only tapi TIDAK dibaca emitter manapun:** `vault.md ## Decisions` / `D-NNN` (`vault_md.py:97,205,228,474-476`; `derive-vault-json.sh:155,436`; `derive-claims-ledger.sh:54-56`; grep `05-decisions|02-architecture|model\.md|03-data-model|04-design` di 4 builder → **0**), `## Architecture` (`vault_md.py:205,228`; detect-drift `SKILL.md:56`), `model.md` DBML (`vault_md.py:104-112`; entities FSD dari codebase-map `:557,595`), `## Glossary` (`vault_md.py:212,220,251` fence; `migrate-paths.sh:196,230`).

**C. Divergensi ref-vs-script:** `section-mapping.md:148-152` FSD §7 source 3 `04-design.md` — tidak pernah dibaca; `section-mapping.md:42` `model.md` di priority — tidak dibaca builder; `prd-sections.md:67` PRD §2 "Overview actors + flows participants" — script hanya `squads.yaml` (`:180-189`), sisanya model slot (`emit-prd/SKILL.md:54`).

### LIVE lane

| lane | step | key | path:line | units + derived vault.json? |
|---|---|---|---|---|
| sync | change detect | `.dirty-paths.jsonl` ∪ git HEAD vs map/index stamp | `commands/sync.md:12`; `routing-rules.md:127` | YES |
| sync | changed-set map-bearing | `scan --changed-only` → `.sync-changed-paths.txt` | `sync.md:13`; `routing-rules.md:117` | YES |
| sync | changed-set express-born | `git diff <stamp>..HEAD` ∪ porcelain ∪ journal ∪ consumed | `derive-changed-paths.sh:6-9,78,86-99,101-106,135` (exit 3 tanpa stamp `:62-66`) | YES |
| sync | short-circuit | changed ∩ (`binding.json claims[].anchor` ∪ units `target_files`) | `sync-intersect.sh:8-9,128-138,158,170-193`; `sync.md:14`; `routing-rules.md:115` | **NO as written** — `:15-26,136-138` fail-closed tanpa `binding.json` |
| sync | drift scope | `--scope=@.sync-changed-paths.txt` | `detect-drift/SKILL.md:50` | YES |
| detect-drift | mode lock | `implementation_mode: existing` | `SKILL.md:48`; `vault_md.py:125-140` | YES (DERIVED key) |
| detect-drift | Step 1 | `schema-only`→`model.md`; `flows-only`→`flows.md`+`## Architecture`; `decisions-only`→`## Decisions`; `full`→all | `SKILL.md:56` | **NO** — satu-satunya konsumen field signature / step body (deriver simpan name/purpose/title/status saja `vault_md.py:104-112,94-121,97-102`) |
| detect-drift | 1.5 framework | map §7 / manifest probe | `SKILL.md:58` | YES |
| detect-drift | 5.5 write-back / 6 metadata | tulis ke vault md + Changelog + re-derive | `SKILL.md:68,70`; `sync.md:21` | NO (md-authoritative) |
| sync | re-bind | `bind --paths=@`; CONFLICT aktif re-validated | `sync.md:16`; `routing-rules.md:117` | PARTIAL |
| generate-units | `--reconcile` | `binding_refs` primer, `vault_source` fallback; butuh binding baru | `SKILL.md:29`; `task-typing.md:157-174`; `halt-protocol.md:116` | PARTIAL |
| generate-units | staleness | `bolt-report.md target_hashes` vs tree | `compute-unit-staleness.sh:6-10` | YES (`superseded` butuh binding) |
| sync | B2 closing | `run-full-suite.sh` | `sync-digest.md:57` | YES |
| sync | ordering | `query-graph.sh` advisory | `sync.md:27`; `routing-rules.md:122-124` | YES |
| sync | digest | `PENDING-SYNC.md` cites `binding.md §CONFLICT-N` | `sync-digest.md:13-24,26` | NO |
| graph | nodes | `vaults/*/vault.json`, `binding.json`, `units/*.md`, `modules.yaml`, KB | `build-graph.sh:146-148` | — |
| graph | vault/flow | `vault.json flows[]`, `_kb_source` | `:315-348` | **YES (DERIVED)** |
| graph | claim/code_anchor | `binding.json claims[]` anchor split `\s*\+\s*` | `:350-400` | NO (butuh binding.json) |
| graph | unit edges | `depends_on`, `honors`, `in_module`, `target_files` → `touches` | `:416-459` | **YES** |
| graph | symbol | `reuse-index.yaml` | `:476-525` | YES |
| graph | query | lazy rebuild; `vault.json` + units + modules | `query-graph.sh:2,157-191,236-249` | YES |
| diff-vault | 1.5 | `prd_sha256` vs file @ `prd_path_at_generation`; halt `prd_path_missing` | `SKILL.md:61,87,95` | YES mekanis (authored pins) |
| diff-vault | rails | OQ tag identity; ADR `Supersedes/Superseded by` di `## Decisions` | `SKILL.md:27-28,42-43` | NO (md-only) |
| diff-vault | 6.5 | `derive-vault-json.sh --patch` | `SKILL.md:73` | NO (md-first) |
| delta | 7.5 scope | VAULT-DIFF literals → `binding.json claims[]` vault_source doc → anchor → `.delta-changed-paths.txt` | `derive-delta-paths.sh:10-22`; `SKILL.md:77`; exit 3/2 `:24-40` | NO (butuh binding.json; fail-closed) — **defect HEAD `:127` fixed 7.31.0** |
| multi-PRD | ownership | `vault.json entities[].name`, `flows[].title`, modules — "never a vault md file" | `commands/mega-sdd.md:51` | **YES (already)** |
| multi-PRD | route | `multi-prd-lifecycle.md:18-23` (`:23` heading md vs command vault.json = divergensi) | | PARTIAL |
| multi-PRD | index | list `vaults/*/vault.json` | `:27` | YES |
| multi-PRD | constitution | `.mega-sdd/constitution.md` locked layer | `:31,34-36` | NO (authored) |
| routing | Mode D signal/chain | `state.json derived.change_signal`; chain scan→drift→[resolve-oq]→bind→units→bolts | `routing-rules.md:127,114-117`; `sync.md:13-16` | PARTIAL |

**Bottom line lane E.** DOCS: FSD §4/§7/§8/§9 + SIT §3–§4 sudah units+bolts+map-keyed; FSD §5 punya preseden re-source (`build-fsd-core.sh:411,414-486`); yang tidak bisa di-re-source = flows Mermaid+DoD, OQ, `author`/`stakeholders`/`squads.yaml`, constitution `[LOCKED]`, `scope_metadata`/`prd_sha256`, verdict binding. Architecture/Decisions/DBML/Glossary vault-only tapi tanpa emitter. LIVE: ownership multi-PRD, project index, graph vault/flow sudah `vault.json`-only; blocker = `binding.json claims[].anchor` (sync-intersect + delta fail-closed) dan detect-drift Step 1 (field signature/step body).
