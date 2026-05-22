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
source_files_cited: <int>          # unique source file count in §11
---
```

These fields are machine-read by `bind-codebase` when consulting KB for secondary ground truth.

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

| Rule | Why | Source | Marker |
|---|---|---|---|
| <rule statement> | <business reason> | <PRD §? domain SME? code-only?> | [VERIFIED] / [INFERRED] / [OPEN] |

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

## Marker conventions

| Marker | Meaning | Behavior downstream |
|---|---|---|
| `[VERIFIED]` | Confirmed by multiple code paths OR explicit doc | `bind-codebase` → CONFIRMED when claim matches |
| `[INFERRED]` | Single source code path; needs confirmation | `bind-codebase` → CONFIRMED with note when claim matches |
| `[OPEN]` | Unknown from code; needs domain expert | `bind-codebase` → escalate as OQ; `generate-intent --kb` → propagates to vault as OQ |

Markers go inline next to claims (`Status code 14 written by act_import_ops.php:269 [INFERRED]`) AND in the Business Rules table column.

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
- Documents DEPARTURES from legacy (normalize denormalized tables, event-source mutable counters, fix typo bugs structurally).
- Tech-agnostic field types (e.g., `decimal`, `text`, not `varchar(255)`).

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
