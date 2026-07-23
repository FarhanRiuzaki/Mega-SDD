# Emission Engine — the shared spine behind every emitted doc

> **The shared emission contract** (P3, spec `docs/superpowers/specs/2026-07-19-v5-execution-spec.md` P3 row; research §4). Extracted from `emit-fsd`'s proven spine so that P5's `emit-prd` / `emit-sit` consume the SAME machinery instead of reinventing it. This doc is **doc-agnostic**: everything FSD-specific stays in the FSD doc-pack (`skills/emit-fsd/SKILL.md` + its `references/`), which BINDS this spine to concrete FSD rules. The engine describes the invariant steps; a doc-pack supplies the variables.
>
> **Invariant-3 guard (binding):** factoring this engine out changed FSD emission behavior by ZERO bytes — pinned permanently by `tests/derived-artifacts/test-p3-emission-parity.sh` (output byte-identical with and without `--doc=fsd`, against the pre-P3 baseline flow).

## Contents

- What a doc-pack supplies
- The emission spine (steps)
- Script contracts (shared, `--doc`-parameterized)
- Doc-pack sidecar scripts (P5 — doc-specific, not engine spine)
- Anti-hallucination rails (engine-level)
- Doc-pack registry
- P5 seams (declared in P3 — resolved in P5)

## What a doc-pack supplies

A **doc-pack** is a skill (e.g. `emit-fsd`) that binds the engine spine to one document type. It supplies:

| Variable | Meaning | FSD doc-pack value |
|---|---|---|
| `<doc>` | lowercase doc lane name — output dir + `--doc` flag value | `fsd` |
| `<DOC>.md` | the emitted markdown file at `<vault>/<doc>/<DOC>.md` | `<vault>/fsd/FSD.md` |
| **section map** | per-section source artifact(s) + extraction rules + citation format + missing-source placeholder text | `emit-fsd/references/section-mapping.md` |
| **template** | the slot-marker (`{{slot_name}}`) skeleton the loop fills | `emit-fsd/references/fsd-template.md` |
| **maturity ladder** | the doc's maturity rungs for the doc-control stamp | FSD `pre-development → post-development` (PRD `draft-from-legacy → reviewed → final`; SIT `planned → partial → executed`; UAT `draft → ready-for-uat → signed-off`) |
| **mode detection** | how CWD state picks the emission mode/maturity | `section-mapping.md §Mode determination` |
| **render config** | styling + optional PDF/HTML render inputs | `emit-fsd/references/styling-config.yaml` (doc-metadata) + `scripts/md2pdf.sh` + `references/github.css` (PDF style — NEVER LaTeX) |

The doc-pack keeps EVERY doc-specific rule (section semantics, slot names, mode labels, halt subtypes' `source_skill`, handoff schema). The engine owns only the spine below.

## The emission spine (steps)

The proven 8-step order (extracted from `emit-fsd/SKILL.md` — the FSD doc-pack remains the operative wording for the FSD lane):

1. **Mode/maturity detect** — inspect CWD state per the doc-pack's mode-determination rules; a user `--mode` flag overrides detection. Announce the detected mode + evidence to chat.
2. **Prior-emit drift check (script-run)** — run `check-citation-drift.sh --vault=<vault> --cwd=<project-root> [--doc=<doc>]` and consume ONLY its output lines (`DRIFT` / `GONE` / `UNVERIFIED` / `NO_PRIOR` / `PRIOR_UNREADABLE`). The model NEVER reads `.citation-map.json` — the script is the map's only sanctioned reader. Flagged sections get a drift callout block quote on re-emit, using the script's `old12`/`new12` prefixes verbatim.
3. **Per-section emission loop** — for each section in the doc-pack's section map: check each declared source artifact's existence, read it, apply the extraction rules. An absent source emits the doc-pack's `[Pending — <source> not yet generated]` placeholder — NEVER fabricated content. **Stamp rule (engine-invariant):** every citation stamp in emitted text is the LITERAL `(sha256: pending)` — the model MUST NOT write hash characters; the stamping script replaces `pending` with the real 12-char prefix computed from file bytes.
4. **Assemble `<DOC>.md`** — substitute slot content into the doc-pack template; write to `<vault>/<doc>/<DOC>.md`.
5. **Unfilled-slot scan** — scan the assembled file for leftover `{{...}}` markers (`grep -oE '\{\{[a-z0-9_-]+\}\}'`); ANY hit → halt `quality_gate_failed` with subtype `template_slot_unfilled` and STOP before render — a literal slot marker must never ship.
6. **Citation stamping + map write (script-run, BEFORE render)** — run `build-citation-map.sh --vault=<vault> --cwd=<project-root> --mode=<mode> [--doc=<doc>]`. Exit 0 → stamps are real, `<vault>/<doc>/.citation-map.json` (schema 2.0) written including script-derived `missing_sources[]`; exit 1 → halt `quality_gate_failed:citation_unresolvable` carrying the script's `UNRESOLVED`/`LEFTOVER` lines, do NOT render (a fabricated or stale citation must never ship in a stamped document); exit 2 → internal usage bug.
7. **Optional render** — md2pdf.sh → GitHub-styled PDF via Chrome (never LaTeX); HTML fallback when Chrome absent; markdown-only when pandoc absent (the doc-pack owns the exact commands + warnings). Render failure → halt `quality_gate_failed:pdf_render_failed`.
8. **Doc-control stamping** — the doc-control/state-stamp block (maturity rung, pipeline position, generated-at pointer) is SCRIPT-OWNED: `refresh-doc-stamps.sh` writes/refreshes it as a parser-invisible HTML-comment block; the model never types it. Full emissions pass --bump with the drift-derived change-note (doc-pack SKILL wording); the version ladder (0.x draft → human-approved 1.0/2.0) lives in the sidecar. Then summary to user (+ handoff YAML under `--auto`, per the doc-pack).

## Script contracts (shared, `--doc`-parameterized)

All three scripts live in `plugins/mega-sdd/scripts/` and default to the FSD lane — **with `--doc` absent or `=fsd`, every code path is byte-identical to the pre-P3 scripts** (the P3 parity pin).

- **`build-citation-map.sh --vault=<v> --cwd=<root> --mode=<m> [--doc=<name>]`** — parses `<vault>/<doc>/<DOC>.md`'s citation markers via the canonical `_lib/citation_pattern.py` grammar, resolves each cited path (vault/-prefix → vault → project → codebase-map), computes sha256 over file BYTES, replaces `pending` stamps in place, writes `<vault>/<doc>/.citation-map.json` (schema 2.0 — the `fsd_section` key name is schema-pinned and stays for every doc lane). Exit 0 clean (ONE stdout line) · 1 UNRESOLVED/LEFTOVER (map still written — audit trail survives the halt) · 2 usage. Idempotent.
- **`check-citation-drift.sh --vault=<v> --cwd=<root> [--doc=<name>]`** — the sanctioned reader of `<vault>/<doc>/.citation-map.json`; recomputes each prior source's sha256 and prints ONLY the pinned grammar `DRIFT <section> <path> <old12> <new12>` / `GONE <section> <path> <old12>` / `UNVERIFIED <section> <path>` / `NO_PRIOR` / `PRIOR_UNREADABLE` — never 64-hex strings, never raw JSON. Exit 0 for all informational outcomes · 2 usage.
- **`refresh-doc-stamps.sh --vault=<v> --doc=<name> [--maturity=..] [--position=..] [--generated-at=..] [--bump --change-note=..] [--approve --approver=..]`** — writes/refreshes ONLY the script-owned doc-control block (`<!-- mega-sdd:doc-control … -->`, inserted after the frontmatter) without touching any other byte (stamp-binding-boilerplate.sh precedent: parser-invisible, pure-additive, idempotent, atomic). Exit 0 stamped/no-op · 2 usage/doc missing. **WIRED (P5):** every emitter's final step runs it (emit-fsd Step 6.5, emit-prd Step 6, emit-sit Step 6), and orchestrate-flow refreshes the `position` field for every existing emitted doc at chain boundaries (`chain-execution.md §Auto-integrated diagnostics` — script-lane, ~0 tokens; a maturity/position refresh never needs a re-emission). Maturity rungs are set ONLY at emit time (FSD from mode; SIT from the `build-sit-evidence.sh` verdict) or by humans (PRD `reviewed`/`final`) — the chain boundary passes `--position` only.
  **Versioning (script-owned):** `--bump` (every full emission) minor-bumps the doc version in the sidecar `<vault>/<doc>/.doc-history.json` (first emission → `0.1`), sets `status: draft`, and appends one curated history row (actor, git short hash, derived change-note); `--approve --approver="Nama, Peran"` is a HUMAN-run governance event minting the next whole version (`0.x → 1.0`, `1.x → 2.0`) with `status: approved`. The block gains `version:`/`status:` fields and the doc gains a visible script-rendered `**Riwayat Revisi:**` table (`<!-- mega-sdd:revision-history -->` region, latest first) — auto-generated projection of the sidecar, never hand-maintained, per spec 2026-07-23 §4. `--position`-only chain-boundary refreshes never touch version state. Docs never bumped keep the legacy 3-field block byte-identically.

### Doc-pack sidecar scripts (P5 — doc-specific, not engine spine)

- **`build-sit-evidence.sh --vault=<v> [--vault=<v2> …] --cwd=<root> [--out=..] [--check-signoff]`** — the SIT doc-pack's deterministic evidence builder: emits the §1–§5 fragment (`<vault>/sit/.sit-evidence.md`) from `04-flows.md` + unit `acceptance_test[]` + the hook-guarded B4/B1/B2 artifacts, computes the `planned|partial|executed` maturity verdict, and enforces the sign-off slot grammar (`--check-signoff`: a non-placeholder Nama/Tanggal/Tanda-tangan/Status cell in §5 → exit 1 `SIGNOFF_*` + keterangan — a model-filled sign-off is a fabricated record, decision 5).
- **`check-prd-markers.sh --prd=<PRD.md> --cwd=<root> [--kb=..]`** — the PRD doc-pack's marker-preservation check: a PRD line citing a KB claim must carry that claim's `[VERIFIED]/[INFERRED]/[OPEN]` marker verbatim (`MARKER_STRIPPED`/`MARKER_UPGRADED`/`MARKER_MISSING` → exit 1 + keterangan — an inferred claim presented as fact never ships).
- **`build-uat-scaffold.sh --vault=<v> [--vault=<v2> …] --cwd=<root> [--out=..] [--check-execution]`** — the UAT doc-pack's deterministic scaffold builder: emits the §1–§4 fragment (`<vault>/uat/.uat-scaffold.md`) with business scenarios aligned 1:1 to SIT TS ids (UAT-NNN mirrors TS-NNN derivation), execution/RTM/berita-acara cells held to script-owned placeholder literals, and warns (never fails) when the SIT entry gate (SEOJK §2.3.1.5) isn't yet `executed`. `--check-execution` is the UAT lane's fabrication gate — any filled §2 execution cell, §3 RTM status, or §4 sign-off cell in the assembled `UAT.md` → exit 1 halt `execution_fabricated`, since UAT execution results are a human-run event, never a model guess.
- **`build-uat-xlsx.sh --vault=<v>`** — the UAT doc-pack's zero-dependency xlsx renderer (python3 stdlib only — hand-written OOXML, no openpyxl/pip): derives a version-named `<vault>/uat/UAT-v<version>.xlsx` (version read from the sidecar `.doc-history.json`) with Rekap/RTM/per-scenario sheets, execution columns left BLANK for the tester. Exit 3 REFUSE when the target file already exists (never overwrite a tester's filled workbook); exit 1 on an unparsable `UAT.md`.

## Anti-hallucination rails (engine-level)

Every doc-pack inherits these (the FSD doc-pack states the operative FSD wording in `emit-fsd/SKILL.md §Anti-hallucination rails`):

1. Every section text MUST trace to a source artifact via the SCRIPT-COMPUTED citation map — the model never writes the map.
2. Missing source MUST emit the `[Pending — <source> not yet generated]` placeholder — NEVER fabricate.
3. All template slots filled OR explicitly placeholdered — a leftover `{{slot}}` is a halt, not a guess.
4. sha256 stamps are computed at emit-time by the script from file bytes — the model emits only the literal `(sha256: pending)`; a citation to a nonexistent path is a deterministic exit-1 halt.
5. Drift callouts MUST surface in the rendered output — silent regeneration would hide content changes from reviewers.
6. The doc version, status, and Riwayat Revisi are script-derived from the sidecar + git — a model-typed version number or history row is a fabricated audit record.

## Doc-pack registry

| doc | pack (skill) | status |
|---|---|---|
| `fsd` | `emit-fsd` (SKILL.md + references/section-mapping.md + fsd-template.md) | LIVE — the extracted-from original; byte-parity-pinned |
| `prd` | `emit-prd` (SKILL.md + references/prd-sections.md + prd-template.md) — forward + REVERSE (KB, no vault), `[VERIFIED]/[INFERRED]/[OPEN]` markers carried verbatim (`check-prd-markers.sh`) | LIVE (P5) |
| `sit` | `emit-sit` (SKILL.md + references/sit-sections.md + sit-template.md) — TS-NNN ← F-NNN scenarios (Mermaid verbatim), script-derived executed evidence + placeholder-literal sign-off (`build-sit-evidence.sh`) | LIVE (P5) |
| `uat` | `emit-uat` (SKILL.md + references/uat-sections.md + uat-template.md) — UAT-NNN ← F-NNN business scenarios aligned to SIT TS ids, placeholder-literal execution columns + berita acara (`build-uat-scaffold.sh`), zero-dep xlsx render (`build-uat-xlsx.sh`) | LIVE (5.3.0) |

## P5 seams (declared in P3 — resolved in P5)

- **`validate-fsd-slots.sh` stays FSD-scoped — permanently.** Its PostToolUse contract keys on the written file path (`*FSD.md` / `*/fsd/*.md`) and writes `.mega-sdd/.fsd-slots-state.json`; widening the path filter (or adding a `--doc` flag the hook dispatch could never pass) would change hook behavior for existing projects. **P5's chosen zero-risk wiring:** the prd/sit lanes run the engine's step-5 in-skill `grep -oE '\{\{[a-z0-9_-]+\}\}'` slot scan, and the SIT sign-off slot grammar is enforced by the SIBLING deterministic check `build-sit-evidence.sh --check-signoff` (run as a mandatory emit-sit gate step + as a re-emission guard) — no hook contract touched.
- **`refresh-doc-stamps.sh` is WIRED (P5)** — emitter final steps + orchestrate-flow chain boundaries (see §Script contracts above).
- The map's `fsd_section` field name is schema-2.0-pinned and stays for every doc lane (prd/sit maps reuse it verbatim); renaming per doc lane remains a schema-3.0 decision.
