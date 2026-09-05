---
name: extract-intelligence
version: 2.6.0
description: Tech-agnostic legacy extractor for rebuild/revamp — census-contracted extraction composes the system's logic into one PRD-kontrak per module (inline file:line citations, [LOCKED]/[INTENT]/[ARTIFACT] mutability tiers), consumed by generate-intent --kb and bind-codebase. Cost scales with the census, not a fixed pipeline — a 1-file engine yields 1 PRD. Triggers — "extract domain knowledge", "reverse engineer this legacy", "pecah legacy code jadi knowledge base", "revamp project ini ke stack baru", "rebuild di stack baru", "legacy intelligence", or paraphrases.
---

# Extract-Intelligence — Legacy → PRD-kontrak

The extraction's job is to compose the legacy system's logic in human
language; the composition IS the PRD — one per module, tech-agnostic,
citation-anchored. Completeness is contracted to the CENSUS (every code file
claimed + cited, or an honest Open Question), never to artifact volume: a
1-file engine fully covered by 1 PRD is 100% complete.

**Announce at start:** "I'm using the extract-intelligence skill to extract domain knowledge from the legacy codebase. `mega-sdd-trace:extract-intelligence`"

> **Skill instruction language:** this skill reasons in English; PRD-kontrak
> content stays tech-agnostic per `references/prd-kontrak-template.md`.
> Narrate (the announce, per-module progress, summaries) in **Indonesian + English technical terms by default**;
> precedence = explicit request > the language the user writes in > Indonesian
> for short/ambiguous input. Tier-1 structural tokens (markers, citations,
> `sha256:`, section headings) stay English
> (→ `plugins/mega-sdd/references/output-language.md`).

**Core principle:** domain-first, not code-first. Tech-agnostic vocabulary.
Citation-disciplined. Ambiguous → `[OPEN]` → Open Questions, never a silent
default. Depth proportional to the census — small legacy runs on the main
thread with zero subagents.

## When to use

- Legacy codebase needs a rebuild/revamp on a different stack (not an in-place migration).
- High-stakes domain (financial, regulatory, healthcare) — missing edges cost money.
- Architect needs "what does this system actually do" without reading the source.
- User says variations of: "extract domain knowledge", "reverse engineer this", "pecah legacy code", "revamp project A ke B", "rebuild di stack baru".

**When NOT to use:**
- Direct code port to a newer version of the same stack → migration tooling.
- Greenfield projects (no legacy).
- "What files are in this repo" → `mega-sdd:scan-codebase` (code-organized catalog).

## Relationship to other mega-sdd skills

| Need | Skill | Why |
|---|---|---|
| Map files/modules in a brownfield repo | `mega-sdd:scan-codebase` | Heuristic catalog organized by code structure |
| Validate an SDD vault claim against existing code | `mega-sdd:bind-codebase` | Primary ground truth = codebase-map; PRD-kontrak consulted as secondary |
| Extract legacy logic into a rebuild contract | **this skill** | Tech-agnostic, module-organized, census-gated |
| Convert brief/PRD-kontrak → intent vault | `mega-sdd:generate-intent` | Consumes this skill's output via `--kb=<path>` |

**Typical chain (the revamp lane):**
`extract-intelligence` → `generate-intent --kb=<kb>` → `generate-units` → `execute-bolts`

## Inputs

- Legacy codebase path (positional, required)
- `--out=<path>` (OUTPUT_ROOT / parent dir; default `.mega-sdd/` per `plugins/mega-sdd/references/paths.md` — output written to `<out>/knowledge-base/`)
- `--seed=<path>` (optional pre-existing forensic dump; moved to `_source/`)
- `--max-parallel=N` (module-extractor cap per batch; **default 5**; soft warn at >5; hard cap 8)
- `--auto` (skip confirmation prompts; quality-gate failures still halt)

## Output

Per `references/prd-kontrak-template.md` — read **§Output layout +
§Module PRD frontmatter + §Module PRD template + §Markers & mutability tiers**
before any dispatch; §README roll-up + §data-mutation-policy at synthesis.

**Secret-scan gate:** before EACH output file is written, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/secret-scan.sh" --redact <assembled-file>` — legacy code routinely hardcodes credentials, and inline citations would otherwise carry them verbatim. Findings → value replaced with `[REDACTED-SECRET]` in the artifact (the legacy SOURCE is never edited) + one chat warning citing source file:line.

## Execution — census → confirm → extract → synthesize → gate

### Step 1 — Census (main thread)

1. Validate the legacy path exists and is non-empty (else halt).
2. If `--seed=<path>`: copy the seed to `{out}/_source/` (read-only cross-reference).
3. **Run** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/derive-extract-census.sh" --legacy=<legacy> --kb-dir={out}/knowledge-base` — writes `census.json`: code files (+sha256, logs/backups/data excluded by construction; non-UTF8 members flagged `encoding: non-utf8` — convert before reading), stacks, entry points, a deterministic module proposal. The census IS the completeness contract.
4. **Run** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/derive-site-census.sh" --legacy=<legacy> --kb-dir={out}/knowledge-base` — WRITE/CALL site inventory per stack idiom (v1: rpg family; unsupported stacks recorded honestly). The Step-5 gate requires every site cited in the KB (`site_uncovered`).
5. Census `stacks` include `rpg`/`rpgle`/`rpg-copy`/`dds` → every extractor AND verifier dispatch carries the `READ ALSO: plugins/mega-sdd/references/legacy-idioms/rpg-as400.md` line (template §Dispatch core).

### Step 2 — Module confirmation (human, only when >1 module proposed)

`census.json` proposes >1 module → ONE AskUserQuestion with keterangan
(Indonesian): show the proposed split (name, file count, lines per module) and
the entry-point hints; options **Pakai pecahan ini** (recommended) / **Ubah**
(user reshapes: merge/split/rename — re-present once) / **Stop**. The split the
human confirms is what gets dispatched — the ground truth of the mapping ends
up in each PRD's own `source_files:` frontmatter, and the census gate
recomputes coverage from those artifacts (never from this conversation).
Exactly 1 proposed module → no question; proceed.

### Step 3 — Per-module extraction

- **1 module (xs):** extract on the MAIN THREAD — no subagent, no dispatch
  overhead. Read the files, compose the PRD per the template, write it through
  the secret-scan gate.
- **>1 module:** dispatch the first-class **`mega-sdd:domain-extractor`**
  agent per module (Agent tool), ≤ `--max-parallel` in flight. The controller
  types ONLY the variable core per `references/prd-kontrak-template.md`
  §Dispatch core (disciplines + REPORT BACK ride the agent body — never
  re-type them). Model tier per role `extract-intelligence-module` from
  `plugins/mega-sdd/references/model-tiers.md`; override via handoff
  `metadata.model_tiers` when invoked through orchestrate-flow.

**Per-module quality gate** (main thread, after each PRD lands): the grep
battery in `references/prd-kontrak-template.md` §Per-module quality gate
(frontmatter, 6 sections + §7 Run & Recovery for workflow modules (7.27.0),
≥3 gotchas for workflow modules, Mermaid fence, advisory `kb-leak-scan.sh`).
FAIL → re-dispatch that module once with the gate output as feedback. The
census gate additionally enforces the 7.27.0 grammar: AC per [LOCKED] BR
(`ac_missing_for_locked`) and an acyclic `rebuild_after`
(`rebuild_order_invalid`); advisories surface undeclared references,
decision-table smells, and flow-vs-[ARTIFACT] contradictions.

**Claim-verify lane (7.25.0)** — after a module's quality gate passes, dispatch
the **`mega-sdd:claim-verifier`** agent for that module (read-only, blind,
adversarial; single-module xs runs DISPATCH TOO — the writer never checks
itself). Controller types only the dispatch core per `references/claim-verify.md`,
then writes the returned `VERIFY REPORT` through
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/write-verify-state.sh" --kb-dir=<kb> --report-file=<tmp>`.
`wrong_load_bearing > 0` → re-dispatch the extractor once with the findings as
feedback (then re-gate + re-verify); twice → halt `quality_gate_failed`
(subtype `claim_verify_failed`). The census gate at Step 5 recomputes coverage
from the artifacts — a missing/under-scoped verify state cannot hand off.

**Per-batch confirmation** (multi-module runs only; skipped under `--auto`):
after a batch's gates pass, ONE AskUserQuestion with keterangan per option —
**Lanjut batch berikutnya** (recommended saat semua gate hijau — module tersisa
N dari M) / **Review output dulu** (buka PRD yang baru ditulis; extraction
menunggu) / **Stop** (KB partial disimpan — PRD yang sudah lolos tetap di
disk).

The SAME module failing its gate twice → **halt** `quality_gate_failed`
(subtype `module_quality_threshold_unmet`), surface the gate output VERBATIM,
ask with keterangan per option: **Re-scope module** (pecah/gabung ulang module
ini lalu re-dispatch) / **Re-prompt** (re-dispatch sekali lagi dengan arahan
tambahan lo) / **Abort** (berhenti; KB partial disimpan di disk — module PRD
yang sudah lolos tetap ada; tidak ada auto-resume — run berikutnya mulai lagi
dari census, idempotent).

Under `--auto`: batch confirmations are skipped; quality-gate failures still
halt.

### Step 4 — Synthesis (main thread ONLY)

0. **Run** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/derive-prd-counts.sh" --kb-dir={out}/knowledge-base --write` — script-derives every frontmatter count from the PRD bodies (extractors no longer type them; 7.26.0). The README roll-up composes FROM these trued-up counts, and the Step-5 gate recounts the roll-up (`rollup_mismatch`).
1. `README.md` roll-up per template §README roll-up (multi-module: + `## ERD`
   + `## System Flow` Mermaid; module quick-reference carries the recommended
   rebuild ORDER from `depends_on` — module is the phasing unit).
2. `data-mutation-policy.md` at the KB root ONLY when ≥1 `[LOCKED]` claim
   exists across modules (template §data-mutation-policy; omit otherwise —
   never pad).

### Step 5 — Completeness gate + hand-off

**Run** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-extract-census.sh" --kb-dir={out}/knowledge-base` — recomputes coverage from census + the PRD artifacts: unclaimed / double-claimed / phantom / uncited files, missing OQ sections, non-Mermaid flows, the claim-verify states (`.verify/<domain>.json` per module: LOCKED coverage + sample floor recomputed from each PRD body — `claim_verify_missing`/`_failed`/`_incomplete`), site coverage (`site_uncovered` — every derived WRITE/CALL site cited ±2 or in-range), and the README roll-up recount (`rollup_mismatch`). Advisory (never blocks): `oq_answerable_from_disk` — an OQ whose `probe-glob:` now matches an artifact on disk → offer a delta re-extract for that module. FAIL → fix (re-dispatch the owning module / run the missing verifier / cite the site) or honestly record the gap as `[OPEN]`/OQ in the owning PRD, then re-run. Never hand off on FAIL.

**Hand-off announce:** "PRD-kontrak written to `<out>/knowledge-base/` — N module(s), census: N files fully claimed. Critical findings: N. Open questions: N (P1: …, P2: …, P3: …). Next: review `<out>/knowledge-base/README.md`, then `generate-intent --kb=<out>/knowledge-base/` to continue the revamp lane." **When Open questions > 0, ALSO offer answering them now (7.21.0):** "Mau jawab OQ-nya sekarang? (resolve-oq KB mode — jawaban legacy paling akurat selagi konteksnya masih hangat; belum dijawab pun tetap ikut ke vault nanti)" — offer only, never auto-invoke.

**Auto-render HTML (7.18.0, 0 model tokens):** after the gate passes, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-html.sh" <out>/knowledge-base --index` and name `<kb>/html/index.html` in the announce — the shareable per-domain report (opens offline, no Claude needed). Fail-open: a render failure is ONE warning line, never a halt; skip when `.mega-sdd/config.yaml` has `render_html: off`.

**Advisor offer (when the target architecture is undecided):** append one line to the announce — "Arsitektur target belum diputuskan? Gue bisa jalanin konsultasi advisor dulu (evidence digest dari KB + census constraint + 2–3 opsi + ADR)." On yes, load `plugins/mega-sdd/references/architecture-advisor.md` and follow it — an OFFER, never auto; the resulting `decisions/ADR-*.md` (accepted) is consumed by `generate-intent --kb`.

## Halt conditions

- Legacy path missing/empty → halt with the exact path probed.
- `--max-parallel` > 8 → halt (token budget collapse).
- Same module's quality gate fails twice → halt `quality_gate_failed` (subtype `module_quality_threshold_unmet`), gate output verbatim (per `plugins/mega-sdd/references/halt-families/extract.md`).
- Same module's claim-verify reports `wrong_load_bearing > 0` twice → halt `quality_gate_failed` (subtype `claim_verify_failed`), verifier findings verbatim.
- `validate-extract-census.sh` FAIL at hand-off → never hand off; fix or record `[OPEN]` honestly.

## Path resolution

No-excuse default: `.mega-sdd/`. Resolution order for `{out}`:
1. `--out=<path>` if provided.
2. `.mega-sdd/config.yaml` `output_root:` if set.
3. `docs/knowledge-base/` ONLY if it already exists (legacy back-compat write path).
4. Otherwise `.mega-sdd/` → output at `.mega-sdd/knowledge-base/`.

Read-side probe order for downstream consumers: `.mega-sdd/knowledge-base/` →
`docs/knowledge-base/` → `docs/mega-sdd/knowledge-base/` →
`old-reference/knowledge-base/` (first hit wins).

## Handoff emission

Under `--auto`, emit the handoff YAML per `references/handoff.md` (operative
spec; `orchestrate-flow/references/handoff-contract.md` owns the base schema):
`status: completed | halted` (halted when a module gate fails twice, ≥1
blocker entry), `artifacts` = KB dir + README path, `next_action` →
`mega-sdd:generate-intent --kb=<kb> --auto`, `metrics.items_processed` =
module PRDs written, and the `mutability` block (this skill is the PRIMARY
mutability-tier producer: `tier_distribution`, `locked_claims_touched`,
`artifact_discards_proposed`). Standalone invocations may emit informationally.

## Cross-references

- `references/prd-kontrak-template.md` — the output grammar (layout, template, markers, dispatch core, gates, README, data-mutation-policy).
- `references/claim-verify.md` — the adversarial claim-verify lane (dispatch core, controller actions, enforcement).
- `references/handoff.md` — the `--auto` handoff record.
- `plugins/mega-sdd/references/architecture-advisor.md` — the optional target-architecture consultation on top of the finished KB (offered at hand-off).
- `mega-sdd:generate-intent` — consumes the output via `--kb=<path>` (incl. `decisions/ADR-*.md` accepted by the advisor).
- `mega-sdd:bind-codebase` — consults the output as secondary ground truth.
- `scripts/derive-extract-census.sh` / `scripts/validate-extract-census.sh` — census + completeness gate.
- `scripts/derive-site-census.sh` / `scripts/derive-prd-counts.sh` — WRITE/CALL site inventory + script-derived frontmatter counts (7.26.0).
- `plugins/mega-sdd/references/legacy-idioms/rpg-as400.md` — extraction-side idiom sheet for the rpg/dds stacks (READ ALSO line in dispatches).
- `scripts/kb-leak-scan.sh` — tech-agnostic vocabulary advisory.
- Design specs: `docs/superpowers/specs/2026-08-26-extract-revamp-contract-design.md` (current), `docs/superpowers/specs/2026-06-15-extract-intelligence-tech-agnostic.md` (historical, wave era).
