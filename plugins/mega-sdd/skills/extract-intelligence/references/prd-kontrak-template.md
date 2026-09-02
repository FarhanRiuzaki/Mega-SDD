# PRD-kontrak — output grammar for extract-intelligence

The extraction's job is to compose the legacy system's logic in human language;
the composition IS the PRD — one per module, tech-agnostic, citation-anchored.
This file is the single grammar authority: layout, frontmatter, section
template, marker/tier rules, the per-module dispatch core, and the per-module
quality gate. (Spec: `docs/superpowers/specs/2026-08-26-extract-revamp-contract-design.md`.)

## Contents
- §Output layout
- §Module PRD frontmatter
- §Module PRD template (6 sections)
- §Staged inputs (`stages:` block)
- §Markers & mutability tiers
- §Dispatch core (what the controller types per module)
- §MASTER STACK IDIOM TABLE
- §Per-module quality gate
- §README roll-up
- §`data-mutation-policy.md` template

## Output layout

```
{out}/
├── _source/                      # forensic seed cross-reference (optional, read-only)
└── knowledge-base/               # home name unchanged — path consumers stay intact
    ├── census.json               # script-derived completeness contract (derive-extract-census.sh)
    ├── README.md                 # roll-up + nav (master entrypoint; probed by routing)
    ├── modules/
    │   └── <domain>.prd.md       # ONE PRD-kontrak per module
    ├── data-mutation-policy.md   # ONLY when ≥1 [LOCKED] claim exists (omit otherwise)
    └── .extract-census-state.json  # gate state (validate-extract-census.sh, re-derived)
```

Default `--out` = `.mega-sdd/` → KB at `.mega-sdd/knowledge-base/` per
`plugins/mega-sdd/references/paths.md`; the legacy read-side probe order
(`docs/knowledge-base/` → `docs/mega-sdd/knowledge-base/` →
`old-reference/knowledge-base/`) is unchanged. Regenerable — never edited
manually. Pre-existing numbered-tree KBs (`00-overview/` … `99-rebuild-architecture/`)
stay readable by their existing validators; new extractions write ONLY this grammar.

## Module PRD frontmatter

Machine face — read by `validate-extract-census.sh` (coverage recompute),
`build-graph.sh` (`domain:` → `kb_domain` node), and `bind-codebase`
(secondary ground truth + counts):

```yaml
---
generated_by: mega-sdd:extract-intelligence
generated_at: <ISO8601>
domain: <module-name>                # = the module; file is modules/<domain>.prd.md
classification: master | workflow | reporting | integration | reference
criticality: high | medium | low
depends_on: []                       # other module names
source_files:                        # census paths this module CLAIMS (exactly-once across all PRDs)
  - <path relative to legacy root>
verified_count: <int>                # unmarked cited claims (default-verified)
inferred_count: <int>
open_count: <int>
locked_count: <int>
intent_count: <int>
artifact_count: <int>
source_files_cited: <int>
---
```

## Module PRD template (6 sections)

Headings verbatim (English headings = machine-greppable Tier-1 tokens; body
narrative follows the output-language rule). A section with nothing to record
carries ONE explicit line `_Tidak terdeteksi._` — auditable absence, never
silent omission, never padded content.

```markdown
# PRD — <Module name>

## 1. Purpose
<2-3 kalimat: apa yang module ini lakukan, bahasa bisnis, tech-agnostic.>

## 2. Business Rules
| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-<DOMAIN>-1 | <rule in business language — explicit, not code-level> | <business reason> | <file:line> | (blank = verified) / [INFERRED] / [OPEN] | [LOCKED] / [INTENT] / [ARTIFACT] / [?] |

Depth: every conditional branch that drives a different business outcome = one
rule row; implicit conditionals made explicit; error-handling rules count.

## 3. Flow
<Mermaid flowchart WAJIB (Input → Process → Output) per
plugins/mega-sdd/references/mermaid-emission-rules.md. Actor/role labels on the
nodes/lanes. Workflow-classified module: ALSO a stateDiagram-v2 with ALL states
(error/timeout/cancellation/reversal/partial), each transition = event + guard
+ citation. Multi-step input collection: the §Staged inputs `stages:` block
rides HERE, before the diagrams.>

## 4. Data In/Out
<Input yang diterima, output/persistensi/efek yang diemisi, entitas yang
disentuh — tech-agnostic ("customer details", bukan "POST /api/v2/customers").
Staged workflow: keep this as the flat union; `stages:` stays the
authoritative field→stage allocation — never let this section be the ONLY
place inputs live for a multi-step workflow.>

## 5. Edge Cases & Gotchas
<Min 3 untuk module workflow (gate-enforced). Tiap entri: deskripsi +
file:line + rebuild guidance (replicate / do-not-replicate / open). Cari:
empty-collection, boundary, race, timezone, silent-error-swallow,
.bak-vs-live discrepancy, dynamic-dispatch seams (P6).>

## 6. Open Questions
<OQ-<DOMAIN>-<NN> [P1|P2|P3] + apa yang di-resolve. Ambigu di kode = entri di
sini, TIDAK PERNAH dikarang. `_Tidak ada._` bila kosong. Badan pertanyaan WAJIB
human-first — pertanyaan utuh yang bisa dijawab orang bisnis tanpa buka kode
(konteks 1 kalimat → pertanyaan → detail teknis sebagai keterangan; jargon tidak
boleh jadi subjek kalimat) — kontrak + contoh ❌/✅ di
`plugins/mega-sdd/references/output-language.md §OQ authoring`.>
```

Citations are INLINE: `(path:line)` or `(path:line-line)` immediately after
the claim, path exactly as it appears in `census.json`. Every `source_files`
entry must be cited at least once in the body (gate-recomputed). A claim that
cannot cite a source may not be written — it becomes an Open Question.

## Staged inputs (`stages:` block)

A flat inputs list silently destroys staging: a downstream bolt then builds
ONE form when the legacy was a multi-step wizard (the captured trade-finance
regression). REQUIRED inside §3 when the source is multi-step — a wizard /
`step`/`stage`/page param, conditional rendering keyed to a stage, a
maker→checker multi-role hand-off, or a status-gated input sequence.
Single-step flows: no block needed.

```yaml
stages:
  - stage_id: "S1"
    stage_name: "Initial input"
    actor_role: "Maker"
    input_fields: ["field_a", "field_b"]   # bare-string form (valid), or the
                                           # enriched object form below
    transitions:
      - to: "S2"
        trigger: "submit_partial"
        conditions: []
    _source: ["legacy/path/file.php:120-184"]
  - stage_id: "S2"
    stage_name: "Review & complete"
    actor_role: "Checker"
    input_fields:
      - { name: "field_a", mutability: "dual-key-re-entry", visibility: "shown", conditional: "always" }
      - { name: "field_d", mutability: "required",          visibility: "shown", conditional: "always" }
    new_fields_vs_prior: ["field_d"]
    hidden_fields_vs_prior: ["field_b"]
    promoted_to_mutable_vs_prior: ["field_a (display-only at S1 → dual-key-re-entry at S2)"]
    dynamic_disclosures:
      - { trigger: "discount_type dropdown change", fields_shown: ["field_g"], _source: "legacy/path/file.php:215-222" }
    transitions:
      - to: "DONE"
        trigger: "approve"
        conditions: ["actor_role in {MGRL1, MGRL2}"]
    _source: ["legacy/path/file.php:201-240"]
```

- `input_fields` accepts bare strings OR objects with `name` + optional
  `mutability` ∈ {`required`, `optional`, `display-only`, `dual-key-re-entry`}
  + `visibility` ∈ {`shown`, `hidden`, `conditional`} + `conditional`.
  Delta lists (`new_fields_vs_prior` / `hidden_fields_vs_prior` /
  `promoted_to_mutable_vs_prior`) and `dynamic_disclosures` are OPTIONAL,
  best-effort/advisory — absence never fails a gate.
- Anti-halu rail: every stage carries its own `_source` anchor — a stage with
  no citation is an `[OPEN]`, never an invented step.
- Carry-over: `stages:` propagates PRD-kontrak → vault `flows.md` → units
  verbatim; `generate-intent` copies the block and emits the matching Mermaid
  `stateDiagram`, never re-flattens it; `validate-vault-flow-staging.sh`
  follows the flow's `_kb_source: [modules/<domain>.prd.md]` back-reference to
  prove staging was not dropped.

## Markers & mutability tiers

Two orthogonal axes; a claim tags only what departs from the default.

**Confidence (axis 1) — default is VERIFIED:** a cited claim with no marker is
verified-by-citation. Mark only the exceptions:
- `[INFERRED]` — single source code path; needs confirmation downstream
  (generate-intent asks; bind-codebase confirms with note).
- `[OPEN]` — unknown from code; the claim body moves to §6 Open Questions and
  propagates to the vault as an OQ.

**Mutability (axis 2) — the revamp contract itself** (plugin invariant #4;
drives Hard Rules in execute-bolts, ERD freedom in generate-intent, and
`data-mutation-policy.md`):
- `[LOCKED]` — MUST preserve 1:1: regulatory, contractual,
  integration-required, or external-FK-dependent. Needs positive evidence —
  never a default.
- `[INTENT]` — outcome matters, implementation free. THE default when
  uncertain.
- `[ARTIFACT]` — coincidental legacy detail, discardable. Needs positive
  evidence (zero callers + workaround pattern) — never a default.
- `[?]` — mutability pending; only valid paired with `[OPEN]`.

Stacking: confidence first — `[INFERRED][LOCKED]`, `[OPEN][?]`. Tech-agnostic
vocabulary everywhere except inside citation tokens (`kb-leak-scan.sh`
enforces, citation tokens exempt).

## Dispatch core (what the controller types per module)

The invariant extraction contract (depth, P1–P4+P6 disciplines, REPORT BACK +
self-check rails) rides the `domain-extractor` agent body — never re-type it.
Per module, the controller types ONLY:

```
ROLE: Legacy module extractor — module <domain>.
CONTEXT: legacy root <abs path>; stack(s): <stacks from census.json>; rebuild target: <stack | unknown>.
READ FIRST: <plugin-root>/skills/extract-intelligence/references/prd-kontrak-template.md
FILES (yours alone — siblings cover the rest): <path (size)> …
OUTPUT TO: <kb>/modules/<domain>.prd.md
mega-sdd-trace:extract-intelligence
```

Files >40KB: instruct offset/limit reads. A module with 30+ files: split the
file list across two dispatches for the same PRD only as a last resort —
prefer proposing a finer module split to the human first.

## MASTER STACK IDIOM TABLE

Single authoritative copy (moved from the retired wave-dispatch reference).
The extractor reads its own stack's column(s); for stacks beyond the table,
reason by analogy from the principle name.

| Principle | PHP | JS / TS | Python | C# / .NET | Java | Go | Ruby | Rust |
|---|---|---|---|---|---|---|---|---|
| **P1** state write | `UPDATE`/`INSERT`/`$x =` | assignment / ORM `.save()` | assignment / ORM `.save()` | EF `SaveChanges` / property set | JPA `persist`/`merge` / setter | struct field set / `db.Save` | AR `update`/`save` / `attr=` | field set / `diesel update` |
| **P1** clone copy | `INSERT … SELECT` | object spread `{...x}` | `dict(**x)` / `copy()` | `INSERT … SELECT` / object init | `INSERT … SELECT` / copy ctor | struct copy `b := a` | `dup`/`clone`/`attributes` | `.clone()` / struct update |
| **P2** entry dispatcher | `$_GET['action']` / `mode==` | `req.method` / route switch | `request.method` / view dispatch | attribute route / `switch(action)` | `@RequestMapping` / servlet `switch` | `switch r.Method` / mux | `params[:action]` / routes | match on path / router |
| **P3** hard halt | `die()`/`exit()` | `process.exit()`/`throw` | `sys.exit()`/`raise` | `Environment.Exit`/`throw` | `System.exit`/`throw` | `os.Exit`/`panic`/`log.Fatal` | `exit`/`abort`/`raise` | `std::process::exit`/`panic!` |
| **P3** silent-success | empty `catch`/`@` | empty `catch`/`?? true` | bare `except: pass` | empty `catch`/swallow | empty `catch` | ignored `err` (`_ =`) | bare `rescue`/`rescue nil` | `let _ =`/`.ok()` discard |
| **P6** DI / IoC | service locator / container | DI token / factory inject | constructor inject / `Depends()` | `IServiceCollection` / ctor inject | `@Autowired`/`@Inject` | wire / provider func | initializer / `.new` inject | trait object / builder |
| **P6** reflection | `call_user_func`/`$$var` | `obj[name]()` / proxy | `getattr`/`__getattr__` | reflection / `dynamic` | reflection / proxy | `reflect` / interface assert | `send`/`method_missing` | trait dynamic / `Any` |
| **P6** route/validate by attr | annotation `@Route` | decorator route | decorator route | `[HttpGet]`/`[Authorize]`/`[Required]` | `@GetMapping`/`@Valid` | tag-based bind | DSL macro | attribute macro |
| **P6** event / wiring | observer / hook | `emitter.on` / callback | signal / observer | event/delegate / `+=` / middleware | listener / `@EventListener` | channel / callback | callback / ActiveSupport notif | channel / trait callback |

## Per-module quality gate

Run on the main thread after each module PRD lands (before the next dispatch
batch); on FAIL → re-dispatch that module's agent once with the gate output as
feedback; the SAME module failing twice → halt `quality_gate_failed`
(subtype `module_quality_threshold_unmet`) with the gate output verbatim.

```bash
P=modules/<domain>.prd.md
# 1. frontmatter present + generated_by + domain + source_files
head -1 "$P" | grep -qx -- '---' && grep -q '^generated_by: mega-sdd:extract-intelligence' "$P" \
  && grep -q '^domain:' "$P" && grep -q '^source_files:' "$P" || echo "GATE FAIL: frontmatter"
# 2. all 6 sections present (explicit absence allowed, omission not)
for n in 1 2 3 4 5 6; do grep -qE "^## ${n}\." "$P" || echo "GATE FAIL: section $n missing"; done
# 3. workflow module: ≥3 gotcha entries in §5
# 4. Mermaid fence in §3 (mermaid-emission-rules 5-rule checklist)
grep -q '```mermaid' "$P" || echo "GATE FAIL: §3 Flow has no Mermaid fence"
# 5. advisory: kb-leak-scan.sh --kb-dir=<kb> --stack=auto  (never fails the gate)
```

The extraction-wide completeness gate is `validate-extract-census.sh --kb-dir=<kb>`
(unclaimed / double-claimed / phantom / uncited / missing-OQ / non-Mermaid
flow) — run after synthesis, before hand-off; FAIL → fix or honestly record
the gap as `[OPEN]`/OQ and re-run.

## README roll-up

`knowledge-base/README.md` — the master entrypoint (its presence is the
routing probe for "KB exists"). Required sections in order:

1. **Project header** — name, 1-sentence description, extraction date, legacy source path.
2. **How to use** — table: reader goal → file.
3. **Module quick reference** — table of modules: classification + criticality + recommended rebuild order (from `depends_on`; this REPLACES the retired `--phase` machinery — module = the phasing unit).
4. **`## Reengineering Opportunities`** — forward-looking design opportunities (heading verbatim — read by `generate-intent --kb`).
5. **`## Mutability Tier Distribution`** — LOCKED/INTENT/ARTIFACT counts per module (heading verbatim — read by `generate-intent --kb`).
6. **`## Critical Findings`** — do-not-replicate bugs first; lead with what hurts.
7. **Open Questions roll-up** — 1 line per OQ with link.
8. **Stats** — module/file/OQ/rule/gotcha counts (from census + frontmatter counts).

Multi-module extraction adds, between 3 and 4: **`## ERD`** (Mermaid
`erDiagram` of the cross-module conceptual model, ERD Quality Rails per
`plugins/mega-sdd/references/framework-conventions/_universal.md`) and
**`## System Flow`** (Mermaid cross-module flow). Single-module: the module
PRD's own §3/§4 carry this — never duplicate.

## `data-mutation-policy.md` template

Emitted at the KB ROOT, ONLY when ≥1 `[LOCKED]` claim exists across modules
(omit otherwise — `build-dispatch-prompt.sh` records absence honestly).
Consumed by `generate-intent --kb` (ERD freedom) and `build-dispatch-prompt.sh`
(DO-NOT-MODIFY anti-context) — the section headings + table columns below are
that consumer contract; keep them verbatim:

```markdown
---
generated_by: mega-sdd:extract-intelligence
purpose: Entity-level mutability policy — drives ERD freedom in generate-intent --kb
---

# Data Mutation Policy

## Entity-level summary

| Entity | Locked count | Intent count | Artifact count | Overall tier | Departure-allowed? |
|---|---|---|---|---|---|
| transactions | 8 | 6 | 0 | LOCKED (audit trail compliance) | No structural departures; additive only |

## Per-locked-field policy

| Entity.field | Legacy name | Mandated by | Rebuild permission |
|---|---|---|---|
| transactions.swift_mt_type | trxmast.mt_type | SWIFT MT Standard | Field name + values MUST be exact (MT103, MT700, etc.) |

## Discardable artifacts

| Entity.field | Legacy purpose | Why discardable | Rebuild action |
|---|---|---|---|
| customers.flag_legacy_v1 | Tag for legacy migration script | Migration completed; unused | DROP |

## How rebuild teams use this file

1. Read BEFORE designing the rebuild ERD.
2. `[LOCKED]` entities: clone legacy shape; no structural changes.
3. `[INTENT]` entities: clean rebuild design per framework conventions.
4. `[ARTIFACT]` columns: confirm with business stakeholder before discarding (default: discard); document in rebuild ADR.
```
