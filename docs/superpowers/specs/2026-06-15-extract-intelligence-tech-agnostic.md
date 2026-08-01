# Extract-Intelligence Tech-Agnostic Hardening — Design Spec

- **Date:** 2026-06-15
- **Status:** ACTIVE
- **Supersedes/extends:** `2026-06-02-extract-intelligence-deepening-design.md` (the deepening spec that introduced P1–P5)
- **Plugin version target:** 4.29.0 (MINOR — new reasoning discipline + new advisory script + scorecard field, all back-compat; no breaking renames, no halt-enum removal, no new skill dir)
- **Skill version target:** `extract-intelligence` 1.10.0 → 1.11.0

## North star (user intent)

> "EI ini harus support tech agnostic ga hanya PHP, ini jadi gerbang kuat utama jika harus rev eng legacy.. php just example"
> — User, 2026-06-15

extract-intelligence (EI) is the **strong front gate** for reverse-engineering legacy. It must capture *all* cases — including dynamic ones — for **any** stack, not just PHP. The deepening spec already declared the five principles "stack-agnostic", but the agent-facing implementation (`references/wave-dispatch-templates.md` DEEP DISCIPLINES + the between-wave tech-leak gate) carried PHP-only illustrative vocabulary, biasing the extraction subagents toward PHP idioms and under-firing on C# / Java / Go / Rust. This spec closes that gap and adds the one principle the PHP corpus never exercised: **dynamic dispatch**.

This is alignment with the EXISTING plugin contract, not a new direction: `plugins/mega-sdd/CLAUDE.md` already mandates *"Tech-agnosticism — the pipeline must work for ANY supported stack, not just PHP/JS."* The PHP-coupling was a standards regression; this spec repairs it.

## Diagnosis (measured, not assumed)

| # | Site | Problem |
|---|---|---|
| 1 | `wave-dispatch-templates.md:130-133` (DEEP DISCIPLINES P1–P3) | Logic is stack-agnostic; **examples are PHP-only** (`INSERT…SELECT`, `$_GET['action']`, `die()/exit()`, `$debug=1`). Concrete examples are *why* the disciplines fire — PHP-only examples bias the model. |
| 2 | `wave-dispatch-templates.md:228,393` (between-wave + final tech-leak gate) | `grep 'varchar\|int(11)\|MySQL\|MSSQL\|composer\|namespace '` — hardcoded SQL/PHP denylist. A C# domain file leaking `DbContext` / `IServiceCollection` / `[HttpGet]`, a Java file leaking `@Entity` / `@Autowired`, etc., passes the leak check entirely. |
| 3 | `validate-extraction-scorecard.sh:71-77` (`REQUIRED_PRINCIPLES`) | Scorecard scores P1–P5 only. No falsifiable dimension for dynamic dispatch — a fully reflection/DI-driven seam can be silently missed because it never appears as a P1 *writer* to begin with. Dynamic wiring is MORE prevalent in C#/Java/Go (DI, reflection, interfaces) than in the PHP corpus the disciplines were tuned on. |

## Design — three changes, Fork-A discipline preserved

> Fork-A doctrine (plugin `CLAUDE.md`): prose that says "HALT" enforces nothing; anything that must hold deterministically lives in a script/validator. The tech-leak gate moves from inline ad-hoc grep into a script; the dynamic-dispatch dimension becomes a scorecard field a validator checks.

### Change 1 — Concept-first disciplines + per-stack idiom table

Rewrite DEEP DISCIPLINES P1–P3 (and the SKILL.md §Deep disciplines vocabulary) so the *principle* is stated in stack-neutral terms, followed by a single **"pattern → per-stack idiom"** lookup table covering PHP, JS/TS, Python, C#/.NET, Java, Go, Ruby, Rust. The subagent keeps concrete anchors for whatever stack it is reading, instead of only PHP anchors. The two copies (SKILL.md design vocabulary + wave-dispatch-templates agent-facing) must not drift — the agent-facing copy is authoritative.

> **Amendment (2026-07-06, token-efficiency Batch B1 / finding M-01 — emission change):** the full 8-stack table is no longer injected into every subagent prompt. It becomes the dispatcher-side **MASTER STACK IDIOM TABLE** (single authoritative copy in `wave-dispatch-templates.md`); each dispatched prompt receives a `<STACK_IDIOM_ROWS>` SLICE — the Principle column + one column per stack in the **UNION** of the Wave 0 enumeration's languages (`.scan-meta.json` breakdown; a multi-stack legacy gets every matching column; JS+TS share a column, C#/VB.NET map to `C# / .NET`). **Full-table fallback** when the enumeration is missing/empty or no detected language maps to a column — a subagent is never dispatched without concrete idiom anchors; partially-unmapped mixes inject the mapped columns and lean on the retained reason-by-analogy line. The Change-1 guarantee is unchanged and sharpened: the subagent still gets concrete anchors for exactly the stack it is reading (7 dead columns × 12–15 dispatches ≈ 2.5 KB each are dropped), and the no-drift rule improves — the agent-facing copy is now a generated slice OF the master, not a second hand-maintained copy. Riding along (same finding): the `<GLOSSARY_INDEX>` switches to a one-line-per-term form with an ~80-char `short_def` cap (citation format + spot-read discipline unchanged), the skeleton's DISCIPLINE block keeps only the deltas the `domain-extractor` agent body lacks (same-line-citation + §11, [INTENT]-default with positive-evidence tiers, .bak-vs-live) — the core rails live once in the agent's system prompt, which loads on every dispatch — and the glossary usage instruction appears once per prompt instead of twice.

> **Amendment (2026-08-01, tranche 5d of `2026-07-30-token-and-latency-optimization.md` — emission change, guarantees unchanged):** the B1 shape above is superseded in its DELIVERY only. The invariant contract (DISCIPLINE deltas, EXTRACTION DEPTH, DEEP DISCIPLINES P1–P4+P6, REPORT BACK + both self-check rails, glossary usage) moved wholesale into `agents/domain-extractor.md` — the subagent's system prompt, which loads on every dispatch BY CONSTRUCTION, so a hurried controller can no longer truncate what B1 still trusted it to type. The `<STACK_IDIOM_ROWS>` and `<GLOSSARY_INDEX>` injections are now derived by `scripts/build-extract-static.sh` into `<kb>/.dispatch-static.md` (Wave 0, re-run after the Wave 1 gate), which every subagent Reads first; the script PARSES the MASTER table out of `wave-dispatch-templates.md` at run time, so the single-copy/no-drift rule is now structural, and the glossary `short_def` is a verbatim word-boundary prefix — the model-paraphrase surface is gone. Every B1 slicing rule (UNION, full-table fallback, mapped-columns-only mixes, never-empty, LANG_MAP alias parity, markup-ignored) is unchanged and now script-enforced + pinned functionally by `tests/token-efficiency/test-extract-dispatch-static.sh`. The typed dispatch shrinks to the variable core (ROLE/CONTEXT/SEED/READ-FIRST/FILES/OUTPUT/TEMPLATE + wave SCOPE blocks).

### Change 2 — P6: Dynamic dispatch & runtime wiring (new falsifiable principle)

A sixth reasoning discipline: for every **dynamic seam** — a call site whose concrete target is resolved at runtime, not lexically — locate the real target(s) and document the behaviour. Covers DI-container resolution, reflection / `dynamic` / duck-typing, attribute/annotation/convention-based routing & validation, interface → implementation dispatch, and event/delegate/middleware wiring. Anti-fabrication preserved: a seam whose target cannot be resolved from the code is an `[OPEN]`, never an invented target.

- Agent-facing: P6 added to `wave-dispatch-templates.md` DEEP DISCIPLINES + REPORT BACK fields `dynamic_seams_found` / `dynamic_seams_resolved` / `dynamic_seams_open`.
- Scorecard: `P6_dynamic_dispatch` added to `REQUIRED_PRINCIPLES`. **COVERED** when every found seam is resolved or carries an `[OPEN]`; **PARTIAL/MISSING** otherwise. `overall_status: FAIL` when a PARTIAL/MISSING P6 hides a gap with zero `[OPEN]` markers — the silent-miss this principle exists to catch.

### Change 3 — Per-stack tech-leak gate (`scripts/kb-leak-scan.sh`)

A new deterministic script replaces the hardcoded inline grep. It applies a **universal SQL/DB denylist + the union of every supported stack's leak tokens** to the KB domain bodies (so a tech-agnostic domain file is checked regardless of which stack the legacy used), and can narrow to a single stack via `--stack=<x>` when `.scan-meta.json` records the legacy language. Behaviour stays **advisory** (print + count, exit 0) to preserve the current non-blocking gate contract — this is a soft operator signal, not a hard rail, and must not be silently upgraded to a blocking fail.

## Back-compat (non-negotiable)

- `validate-extraction-scorecard.sh` SKIP-on-absent-scorecard contract preserved. A scorecard emitted by a PRE-1.11.0 extractor (no `P6_dynamic_dispatch`) MUST NOT be marked FAIL solely for missing P6 — P6 absence is gated on `extractor_version` and degrades to an advisory, not a structural FAIL.
- The five existing principles' verdict logic is unchanged.
- No new runtime dependency (script is bash + python3, already required by the sibling validators).

## Invariants preserved (the moat)

1. No fabrication — unresolved dynamic seam → `[OPEN]`.
2. Scorecard remains falsifiable — `FAIL` on a hidden gap (PARTIAL/MISSING principle with zero `[OPEN]`).
3. Citation discipline — every dynamic-seam claim carries `file:line` for both the seam and the resolved target(s).
4. Advisory gates stay advisory; blocking gates untouched.

## Out of scope

- scan-codebase / bind-codebase C# first-class support (tree-sitter `tags-csharp.scm`, `.csproj`/`.sln` detection, ASP.NET framework pack) — that is the *deterministic* engine; a separate effort. EI is LLM-based and stack-agnostic by construction, which is why it is the front gate this spec hardens.
