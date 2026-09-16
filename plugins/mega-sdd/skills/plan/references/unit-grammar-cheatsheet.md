# Unit grammar cheatsheet — what each validator PARSES (read this, never the validator source)

> L3a of `docs/superpowers/specs/2026-09-16-clinic-levers-design.md` (MEASUREMENT PENDING). MEASURED on
> the clinic lite run (`research/2026-09-15-v8-p3-report.md §2f`): ±10 of the 56 plan minutes went to
> the model reading `validate-*.sh` / `_lib/*.py` to learn the grammar. Every regex below is copied VERBATIM
> from the named file and pinned by `tests/v8-plan/test-plan-precode-diet.sh` (a regex that no longer appears
> in its file fails the suite — this sheet cannot drift silently). Semantics live in
> `../../generate-units/references/unit-schema.md`; this sheet is only the machine-read SHAPE.

## Frontmatter fields (unit file `units/U-XXX.md`, between the first two `---` lines)

| Field | Reader | Regex (verbatim) | Shape that passes |
|---|---|---|---|
| `prd_source:` | `scripts/validate-unit-spec.sh`, `scripts/validate-plan-coverage.sh` | `^prd_source:[ \t]*(.*)$` | heading slug of the PRD requirement (`#slug` or `:line`); list allowed; omit ONLY with an OQ |
| `context_source:` | `scripts/validate-unit-spec.sh` | `^(?:vault_source\|context_source):\s*(.+?)\s*$` | `context.md#<anchor>` (`#F-U-001`, `#Data-model`, `#Constraints`); never `vault_source` in layout 3 |
| `target_files:` | `scripts/validate-unit-spec.sh`, `scripts/validate-flow-coverage.sh` | `^target_files[ \t]*:[ \t]*(.*)$` | block list of `- path: <repo-relative>` + `operation: create\|modify` (inline `[a, b]` tolerated) |
| `acceptance_test:` | `scripts/validate-unit-spec.sh`, `scripts/run-acceptance-tests.sh` | `^acceptance_test\s*:\s*(.*?)(?=^\S\|\Z)` | ≥ 1 entry; `type: test` MUST carry `command:` + `expects:` (substring); `type: render` for detail views; `type: manual` = `desc:` only |
| `depends_on:` | `scripts/derive-ready-units.sh`, `scripts/validate-unit-spec.sh` (L2) | `^depends_on:[ \t]*(\[[^\]]*\])?[ \t]*\n((?:[ \t]+-[^\n]*\n?)*)` | block list of `- U-XXX` or inline `[U-001, U-002]`; cycles halt in generate-units; depth ≤ 4 hops advisory |

## `## Hard rules` productions (v1 — the ONLY lines B1 can verify; anything else is a prose directive the panel reads)

| Production | Reader | Regex (verbatim) |
|---|---|---|
| `DO NOT modify <path>` | `scripts/_lib/postflight_rules.py` | `^(?:DO NOT\|MUST NOT\|NEVER) modify\s+(\S*[./]\S*)` |
| `DO NOT add new <manifest> dependencies` | `scripts/_lib/postflight_rules.py` | `^(?:DO NOT\|MUST NOT\|NEVER) add new\s+(\S*\.\S+)\s+dependencies` |
| `<glob> MUST follow <case> naming` | `scripts/_lib/postflight_rules.py` | `^(\S+)\s+MUST follow\s+(kebab-case\|camelCase\|snake_case\|PascalCase)\s+naming` |
| `function <name> MUST preserve signature: <sig>` | `scripts/_lib/postflight_rules.py` | `^function\s+(\S+)\s+MUST preserve signature:\s+(.*)$` |
| `file <path> MUST exist after bolt` | `scripts/_lib/postflight_rules.py` | `^file\s+(\S+)\s+MUST exist after bolt` |
| directive (prose, NOT machine-verified) | `scripts/_lib/postflight_rules.py` | `^(?:MUST NOT\|MUST\|DO NOT\|NEVER\|ALWAYS)\b` |

Every rule line starts with `- ` in the unit body; `validate-unit-spec.sh` counts machine-checkable vs directive rules and reports `hard_rules_directive_advisory` when > 80 % are prose (write productions, not sentences).

## `context.md` anchors the parsers key on (`scripts/_lib/vault_md.py`)

| Anchor | Reader | Regex (verbatim) | Note |
|---|---|---|---|
| flow heading | `scripts/_lib/vault_md.py` | `^###\s+(F-(?:[A-Z]-)?\d+)\s*:\s*(.+)$` | one `### F-<prefix>-NNN: <title>` per flow under `## Flows`; Mermaid + `**Definition of Done**` + `**Source**` |
| decision heading | `scripts/_lib/vault_md.py` | `^###\s+(D-\d+)\s*:\s*(.+)$` | only when sourced (`## Decisions` absent otherwise) |
| DBML table | `scripts/_lib/vault_md.py` | `^\s*[Tt]able\s+([A-Za-z0-9_]+)\s*\{` | under `## Data model`; `// Purpose:` per table → `//\s*Purpose:\s*(.+)$` |
| entity description | `scripts/_lib/vault_md.py` | `^###\s+`?([A-Za-z0-9_]+)`?\s*$` | `### <entity>` blocks after the DBML |
| OQ priority | `scripts/_lib/vault_md.py` | `\[\s*(P[123])\s*\]` | every OQ carries `[P1]`/`[P2]`/`[P3]` |
| OQ origin | `scripts/_lib/vault_md.py` | `\[\s*origin:\s*([^\]]+?)\s*\]` | `[origin: context.md#<anchor>]` when the gap arose elsewhere |
| OQ deferred marker | `scripts/_lib/vault_md.py` | `\*\*Deferred\b[^*\n]*\*\*\s*:\s*\S` | xs: `**Deferred (plan)**: resurfaced after bolts` |

## Body sections `validate-unit-spec.sh` measures (xs diet + L2 shape)

- `## Goal` (xs: 1 line) · `## Context (read first)` (xs: ≤ 2 sentences) · `## Implementation steps` (numbered `N.` lines — xs ≤ 3; L2 split candidate > 6) · `## Anti-patterns` / `## Out of scope` (xs: every item sourced — `U-\d{3}|OQ-|C-\d|\.md\b|:\d+\b|§|\(from `).
- `target_files` count > 4 → L2 split candidate; a unit with ≥ 3 direct dependents → L2 hub.
