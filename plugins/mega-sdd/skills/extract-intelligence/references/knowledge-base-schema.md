# Knowledge-Base Output Schema

`.mega-sdd/knowledge-base/` (default, v3.4+ Iter 10) is the structured output of `extract-intelligence`. It is consumed by `mega-sdd:generate-intent` (Mode B brief) and `mega-sdd:bind-codebase` (secondary ground truth). Legacy default `docs/knowledge-base/` retained for read-side back-compat only.

Regenerable — never edited manually. To revise: edit the source legacy code OR re-run extraction with updated `--seed`.

---

## Directory layout

```
{out}/
├── _source/                       # forensic seed cross-reference (optional, read-only)
│   └── <seed-doc>.md
└── knowledge-base/
    ├── README.md                  # nav + critical findings + OQ roll-up + stats
    ├── 00-overview/
    │   ├── system-purpose.md
    │   ├── glossary.md
    │   ├── module-classification.md
    │   └── actors-and-roles.md
    ├── 10-domains/                # 1 file per business domain
    ├── 20-workflows/              # cross-cutting workflows
    │   ├── maker-checker-pattern.md
    │   ├── approval-state-machine.md
    │   └── …
    ├── 30-data-model/
    │   ├── conceptual-erd.md
    │   ├── core-entities.md
    │   └── reference-entities.md
    ├── 40-business-rules/
    │   ├── regulatory-rules.md
    │   ├── operational-rules.md
    │   └── hidden-gotchas.md
    ├── 50-integrations/           # 1 file per external system
    └── 99-rebuild-architecture/
        ├── suggested-erd.md
        ├── suggested-system-flow.md
        ├── module-dependency-graph.md
        └── suggested-phasing.md
```

**Default `--out`:** `.mega-sdd/knowledge-base/` (v3.4+ Iter 10 canonical, enforced as default since v1.3 Iter 21 hotfix). Configurable. Pipeline-consumers probe in this order:

1. `.mega-sdd/knowledge-base/` (v3.4+ default — checked FIRST)
2. `docs/knowledge-base/` (legacy v1.x extraction)
3. `docs/mega-sdd/knowledge-base/` (legacy v2.x layout)
4. `old-reference/knowledge-base/` (cross-folder rebuild placement)

First hit wins.

---

## Per-domain file frontmatter (MANDATORY)

Every file under `10-domains/` (and recommended for `20-workflows/`, `40-business-rules/`, `50-integrations/`):

```yaml
---
generated_by: mega-sdd:extract-intelligence
generated_at: <ISO8601 timestamp>
domain: <kebab-case-id>            # e.g., cif-customer, import-lc-issuance
classification: master | workflow | reporting | integration | reference
criticality: high | medium | low
rebuild_phase: 1 | 2 | 3
depends_on: [<other-domain-ids>]   # for dependency graph synthesis
verified_count: <int>              # count of [VERIFIED] markers in the file
inferred_count: <int>              # count of [INFERRED] markers
open_count: <int>                  # count of [OPEN] markers / OQ entries
# v1.4+ Iter 22 mutability distribution (machine-read by generate-intent --kb)
locked_count: <int>                # count of [LOCKED] markers (1:1 preserve)
intent_count: <int>                # count of [INTENT] markers (outcome-only)
artifact_count: <int>              # count of [ARTIFACT] markers (discardable)
source_files_cited: <int>          # unique source file count in §11
---
```

These fields are machine-read by `bind-codebase` when consulting KB for secondary ground truth, and by `generate-intent --kb` to route claims to vault correctly per mutability tier.

---

## Per-domain 11-section template (MANDATORY)

Every file under `10-domains/` MUST have all 11 sections, in order. Empty sections are filled with `_None detected — see §10 Open Questions._`, never omitted.

```markdown
# <Domain Name>

> **Classification**: <from frontmatter>
> **Criticality**: <from frontmatter>
> **Depends on**: <links to other domain files>
> **Rebuild Phase**: <from frontmatter>

## 1. Purpose

<1-2 paragraphs: what this domain exists for, in business terms. Tech-agnostic.>

## 2. Actors

<List of actor roles touching this domain. Link to `00-overview/actors-and-roles.md`.>

## 3. Flow (Input → Process → Output)

```mermaid
flowchart LR
  …
```

## 4. Inputs

<What triggers / data this domain accepts. Tech-agnostic (e.g., "customer details", not "POST /api/v2/customers").>

## 5. Process

<Step-by-step business logic. State transitions called out. Each non-trivial step carries a marker.>

1. Step 1. [VERIFIED]
2. Step 2. [INFERRED] — single source path; needs confirmation.
3. Step 3. [OPEN] — branch logic unclear in legacy.

## 6. Outputs

<What this domain emits / persists / triggers.>

## 7. Business Rules

| Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|
| <rule statement> | <business reason> | <PRD §? domain SME? code-only?> | [VERIFIED] / [INFERRED] / [OPEN] | [LOCKED] / [INTENT] / [ARTIFACT] / [?] |

## 8. State Machine

<Only if classification = workflow. Otherwise: "_N/A — not a workflow domain._">

```
state-A --event--> state-B
…
```

## 9. Edge Cases & Gotchas

<Silent bugs, race conditions, .bak-vs-live discrepancies, edge cases. Each labelled.>

- **Edge Case 1** [VERIFIED]: <description>. **Source**: <file:line>. **Rebuild guidance**: <do-not-replicate / replicate / open question>.

## 10. Open Questions

> ❓ Items requiring domain expert input. Tagged for downstream OQ propagation.

- [ ] **OQ-<DOMAIN>-<NN>** [P1|P2|P3]: <question text>. **Resolves**: <what unblocks this>.

## 11. Source References

<Every non-trivial claim above maps to a citation here. file:line format.>

- `<file>:<line-range>` — <what this proves>
- …
```

---

## Marker conventions (two orthogonal axes)

### Axis 1 — Confidence

| Marker | Meaning | Behavior downstream |
|---|---|---|
| `[VERIFIED]` | Confirmed by multiple code paths OR explicit doc | `bind-codebase` → CONFIRMED when claim matches |
| `[INFERRED]` | Single source code path; needs confirmation | `bind-codebase` → CONFIRMED with note when claim matches |
| `[OPEN]` | Unknown from code; needs domain expert | `bind-codebase` → escalate as OQ; `generate-intent --kb` → propagates to vault as OQ |

### Axis 2 — Mutability tier (v1.4+, Iter 22)

| Marker | Meaning | `generate-intent --kb` behavior |
|---|---|---|
| `[LOCKED]` | MUST preserve 1:1 — regulatory, contractual, integration-required, or external-FK-dependent | Vault body verbatim; emit as Hard Rule for execute-bolts; mutability_source: kb_locked |
| `[INTENT]` | Outcome matters, implementation free | Vault as outcome goal; reference `99-rebuild-architecture/` recommendation as proposed new shape; mutability_source: kb_intent |
| `[ARTIFACT]` | Coincidental legacy detail — discardable | Vault OQ with default "discard unless user requests preservation"; mutability_source: kb_artifact |
| `[?]` | Mutability pending — only valid when paired with `[OPEN]` | Vault OQ — answering resolves both confidence + mutability |

### Combined notation

Markers stack: `[VERIFIED][LOCKED]`, `[VERIFIED][INTENT]`, `[INFERRED][LOCKED]`, etc. Confidence first, mutability second. Inline format:

```
Status code 14 written by act_import_ops.php:269 [INFERRED][INTENT] — outcome (mark application as approved) matters; field-level mechanism is rebuild's choice.
```

In Business Rules table, two separate columns (Confidence + Mutability). Markers go inline next to claims AND in the table.

### Default tier when uncertain

If a wave-2/3/4 agent can't classify with high confidence, default to `[INTENT]` (middle-ground). Wave 5 synthesis re-reviews and may upgrade to `[LOCKED]` (regulatory citation found) or downgrade to `[ARTIFACT]` (zero callers + workaround pattern).

Never auto-default to `[LOCKED]` (over-constrains rebuild) or `[ARTIFACT]` (risks discarding business rule). Both require positive evidence.

### Backward-compat for KBs without tier markers

Pre-v1.4 KBs that only carry confidence markers: `generate-intent --kb` treats every claim as `[INTENT]` (safe middle-ground). User MAY re-run extraction to upgrade tier classification.

---

## ERD Quality Rails (v1.4+, Iter 22)

`suggested-erd.md` MUST satisfy these checks before Wave 5 writes the file:

### Universal-good-practice defaults

- **Column naming**: snake_case (universal default; framework pack may override — see [`plugins/mega-sdd/references/framework-conventions/`](../../references/framework-conventions/))
- **Table naming**: plural snake_case (`customers`, `loan_applications`)
- **Primary key**: `id` (auto-increment BIGINT or UUID per framework convention)
- **Foreign key**: `{singular_target_table}_id` (e.g., `customer_id` on `loans` table referencing `customers.id`)
- **Standard timestamps**: `created_at TIMESTAMP NOT NULL`, `updated_at TIMESTAMP NOT NULL` on every mutable table
- **Soft delete (when applicable)**: `deleted_at TIMESTAMP NULL` — application enforces filter
- **Audit columns (when applicable)**: `created_by`, `updated_by` → FK to users.id

### Normalization checklist

- **3NF compliance**: every non-key field depends on the WHOLE key, ONLY the key, NOTHING but the key
- **No repeating groups**: e.g., `phone1`, `phone2`, `phone3` → separate `customer_phones` table
- **Junction tables for M:N**: e.g., `users` × `roles` → `user_roles` table with composite PK
- **No denormalization shortcuts** unless paired with `[LOCKED]` tag + business justification (e.g., reporting performance)

### Departures from legacy (mandatory section)

`suggested-erd.md` MUST include a `## Departures from Legacy` section enumerating:

1. **Denormalization fixes** — legacy field X was stored on table Y for read-perf; rebuild moves to JOIN / projection
2. **Naming standardization** — legacy `cifmast` → rebuild `customers`; legacy `cifNm` → rebuild `name`
3. **Type corrections** — legacy `varchar(255)` for currency → rebuild `decimal(15,2)`
4. **Bug fixes structural** — legacy typo `commited_at` → rebuild `committed_at`
5. **Discarded fields** — `[ARTIFACT]` columns listed with discard rationale

Each departure cross-references the `[LOCKED]/[INTENT]/[ARTIFACT]` tier of the affected entity. `[LOCKED]` entities cannot have name/type departures — only additive changes allowed.

---

## `data-mutation-policy.md` template (v1.4+, Iter 22)

```markdown
---
generated_by: mega-sdd:extract-intelligence
wave: 5
purpose: Entity-level mutability policy — drives ERD freedom in generate-intent --kb
---

# Data Mutation Policy

This file declares which legacy entities/fields are LOCKED (must preserve 1:1) vs INTENT (outcome only) vs ARTIFACT (discardable). Generated from per-domain `[LOCKED]/[INTENT]/[ARTIFACT]` markers.

## Entity-level summary

| Entity | Locked count | Intent count | Artifact count | Overall tier | Departure-allowed? |
|---|---|---|---|---|---|
| customers | 3 | 12 | 4 | INTENT (mixed; 3 locked fields) | Yes — except for locked fields below |
| transactions | 8 | 6 | 0 | LOCKED (audit trail compliance) | No structural departures; additive only |
| audit_logs | 4 | 0 | 0 | LOCKED (regulatory) | No |

## Per-locked-field policy

For every `[LOCKED]` field, list explicitly:

| Entity.field | Legacy name | Mandated by | Rebuild permission |
|---|---|---|---|
| customers.nip | cifmast.cifNip | BI Reg 23/2/2021 §4 | Field name MAY change to `national_id`; type + length + validation rule MUST preserve. |
| transactions.swift_mt_type | trxmast.mt_type | SWIFT MT Standard | Field name + values MUST be exact (MT103, MT700, etc.) |
| ... | ... | ... | ... |

## Discardable artifacts

| Entity.field | Legacy purpose | Why discardable | Rebuild action |
|---|---|---|---|
| customers.flag_legacy_v1 | Tag for legacy migration script | Migration completed 2018; field unused since | DROP |
| transactions.amount_str | Denormalized string copy of amount for legacy report | Reports rebuilt; redundant with `amount DECIMAL` | DROP |

## How rebuild teams use this file

1. Read this file BEFORE designing rebuild ERD
2. For `[LOCKED]` entities: clone legacy shape (name/type/constraints), no structural changes
3. For `[INTENT]` entities: design clean rebuild ERD per universal-good-practice defaults + framework conventions
4. For `[ARTIFACT]` columns: confirm with business stakeholder before discarding (default: discard); document discarded items in rebuild ADR
```

---

---

## README roll-up structure

`knowledge-base/README.md` is the master entrypoint. Required sections in order:

1. **Project header** — name, 1-sentence description, extraction date, source codebase path, forensic seed pointer (if any), methodology pointer to the spec.
2. **How to use this knowledge base** — table mapping reader goal → starting file.
3. **Module classification quick reference** — table of all domains with classification + criticality + rebuild phase.
4. **Reading conventions** — marker definitions, file reference format, cross-link conventions.
5. **Critical findings (surface first)** — bugs not to replicate, hidden dependencies, compliance gaps. THIS GETS READ FIRST by rebuild team; lead with what hurts.
6. **Open Questions roll-up** — grouped by phase blocker (Phase 1 / Phase 2 / Phase 3 / regulatory / integration). 1-line per OQ with link.
7. **Directory index** — tree view of `knowledge-base/`.
8. **Stats** — total files, total size, OQ count, business-rule count, gotcha count, state count, MT-type / external-message-type count, entity counts, legacy file count.
9. **Next steps for rebuild** — ordered list pointing reader to next action.
10. **About this extraction** — methodology, discipline, source-of-truth pointer, disclaimer.

---

## 99-rebuild-architecture templates

### `suggested-erd.md`
- Mermaid ER diagram of the clean rebuild schema.
- MUST satisfy §ERD Quality Rails above — universal-good-practice defaults + Normalization checklist + Departures section.
- Documents DEPARTURES from legacy (normalize denormalized tables, event-source mutable counters, fix typo bugs structurally).
- Tech-agnostic field types (e.g., `decimal`, `text`, not `varchar(255)`).
- Cross-references `data-mutation-policy.md` — fields tagged `[LOCKED]` retain legacy shape; `[INTENT]` fields apply rebuild design freedoms; `[ARTIFACT]` fields omitted with discard rationale in §Discarded fields.

### `suggested-system-flow.md`
- Logical service boundaries — NOT a microservice prescription.
- Anti-corruption layer pattern for integrations.
- Idempotency requirements per flow.
- No framework names; describe behavior contracts.

### `module-dependency-graph.md`
- Mermaid DAG showing module-level dependencies.
- Leaf-vs-trunk analysis.
- Critical-path estimate for rebuild ordering.

### `suggested-phasing.md`
- Phase 1 / 2 / 3 plan.
- Per-phase acceptance criteria.
- Per-module acceptance template.
- Pre-phase blocker list (resolved OQs required before phase start).

---

## Anti-hallucination invariants

- Every non-trivial claim has a marker AND a `file:line` citation in §11.
- Section presence is mandatory — empty sections render as `_None detected — see §10._`, never omitted.
- Forbidden patterns (language/DB names) absent in domain files except `## 11. Source References` and `50-integrations/`.
- README "Critical findings" leads with do-not-replicate bugs — surfaced first, not buried.

## Consumed by

- **`mega-sdd:generate-intent` (Mode B with `--kb`)**: reads `README.md` + relevant domain files as PRD-equivalent source quotes. `[VERIFIED]` items → vault body; `[INFERRED]` → confirmation prompt; `[OPEN]` → vault OQ.
- **`mega-sdd:bind-codebase`**: when codebase-map.md is silent on a vault claim, consults the matching domain file. KB `[VERIFIED]` → CONFIRMED; `[INFERRED]` → CONFIRMED with note; `[OPEN]` → escalate as OQ. Never overrides a codebase-map CONFLICT.
- **`mega-sdd:orchestrate-flow`**: detects KB presence in CWD and routes the next step.
