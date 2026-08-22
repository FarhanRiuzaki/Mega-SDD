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
- **Model-authored enums that look like prose but are validator-pinned** (highest translation risk — the model writes these, so the "script-emitted" carve-out below does NOT protect them): Extraction Completeness Contract scorecard principle status `COVERED|PARTIAL|MISSING` + `overall_status` `PASS|PARTIAL|FAIL` (`validate-extraction-scorecard.sh`); handoff `status` values (`validate-handoff-yaml.sh`); bolt acceptance verdicts incl. the lowercase set `pass|passed|ok` (`validate-bolt-artifacts.sh`). These stay English verbatim even when the surrounding narration is Indonesian.
- **Markers:** mutability `[LOCKED]` / `[INTENT]` / `[ARTIFACT]`; confidence `[VERIFIED]` / `[INFERRED]` / `[OPEN]`; OQ priority `P1` / `P2` + status `[~]` / `[ ]` / `[x]`.
- **Halt vocabulary:** escalation tiers `C1` / `C2` / `C3`; halt-type vocabulary (`conflict_unresolved`, `missing_*`, `test_fail`, `bind_conflict`, …) + all JSON / frontmatter **field names**.
- **Anti-halu & provenance:** placeholders `[Pending — X]` / `_None detected_`; citation `sha256:` stamp + `[Source: <path>]`; generator directives `<!-- compact-skip -->` / `<!-- full-only -->`; `generated_by:` marker; status `draft|locked`.
- **Doc structural spine** (parsed by validators / wikilinks): section headers (`## Purpose`, `## NFR`, `^FR-\d+`, `Implementation State Map`, `Open Questions`, `## Conflicts` / `### CONFLICT`, the KB 11-section header spine); `[[doc#Header]]` wikilink targets; DBML `Table … { }` blocks; KB `stages:` YAML + mermaid enums; the labels machine-read by `derive-vault-json.sh` (W5) — the six 00-index Vault Lock Status bullet keys (`**Vault version**` / `**Project shape**` / `**Implementation mode**` / `**Mode migration trigger**` / `**PRD status**` / `**Output mode**` — the `**History**` bullet is deliberately NOT machine-read and stays unpinned), the 04-flows `**Definition of Done**:` / `**Source**:` / `**_kb_source**:` labels, the 05-decisions `**Status**:` label, and the `// Purpose:` DBML comment token; the 04-flows `**Stages**` label (the vault flow-staging surface, NOT the deriver: it heads the `stages:` YAML block that `validate-vault-flow-staging.sh` machine-reads).
- **Names & glyphs:** skill names, `/mega-sdd:*` command names, file / state-file paths, glyphs `✓ ⏸ ⛔`, the `CLEAR-<scope>` confirmation sentinel.
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

1. **The actual question/claim text** — quote the OQ question, CONFLICT claim pair, or decision at stake verbatim; an ID/tag (`OQ-AR-1`, `CONFLICT-2`) alone is never a question.
2. **Context** — source citation (doc §/anchor or file:line) + one line of why this is being asked now.
3. **Per-option keterangan** — a Tier-1 enum code (`KEEP_CODE`, `DEFER`, `ACCEPT`, `P1`…) stays English as the LABEL, but every option carries a MANDATORY Tier-2 description of what choosing it DOES and its consequence (e.g. `DEFER — jadi OQ; gate binding terbuka, unit digenerate membawa OQ-nya`). The description must state the mechanic the plugin ACTUALLY implements — a keterangan asserting behavior that does not exist is fabricated UX, worse than a bare code. An option rendered as a bare code is a violation; a literal placeholder (`description: ...`) is a violation.
4. **Recommended default** — stated with a one-line reason whenever one exists; exactly ONE option is marked recommended (two templates disagreeing on the default is a defect).

Descriptions follow the standing Tier-2 language precedence (Indonesian-mix by default). This contract binds the halt displayer (`plugins/mega-sdd/references/halt-protocol.md §Consumer dispatch` renders a keterangan block BEFORE the envelope YAML) and every skill prompt template; pinned by `tests/interaction-keterangan/`.

## Switching & extensibility

- Default `id` (carried by the anchor + the greenfield entry-point directives). The user says "use English" / "pakai bahasa Inggris" / "pakai bahasa Jawa" → the model mirrors.
- Any language works with zero new code: the model is multilingual and Tier-1 stays English regardless. No catalog, no per-language code.
- Not persistent across sessions (and re-asserted each session/compaction by the anchor) — by design, the lightest-touch config.
