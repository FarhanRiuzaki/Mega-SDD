# AGENTS.md Schema — Mega-sdd Emission Format

Per [agents.md spec](https://agents.md/) (Linux Foundation AAIF). Mega-sdd emits a subset focused on what AI coding tools (Continue.dev, Cursor, Aider, Copilot) actually consume.

## Contents

- Header
- Section 1 — Project overview
- Project overview
- Section 2 — Build commands
- Build commands
- Section 3 — Test commands
- Test commands
- Section 4 — Code style + conventions
- Code style + conventions
- Section 5 — Architecture overview
- Architecture overview
- Section 6 — Key decisions
- Key decisions
- Section 7 — Open questions
- Open questions (cautions for AI tools)
- Section 7.5 — Constitution
- Constitution (project-facing rules)
- Section 8 — Mega-sdd interop notes
- Mega-sdd interop notes
- Conditional section presence
- Conditional header field presence
- Append mode
- Sibling mode
- Idempotent regeneration

## Header

```markdown
# AGENTS.md

<!-- generated_by: mega-sdd:emit-agents-md {{generator_version}} -->
<!-- vault_source: {{vault_path}}/vault.json -->
<!-- scope_id: <scope_metadata.id> --> (omit line when vault has no scope)
<!-- scope_name: <scope_metadata.name> --> (omit line when vault has no scope)
<!-- generated_at: <ISO8601> -->
<!-- vault_version: <vault.json version field> -->
<!-- framework: <detected from codebase-map.md §7 — e.g., laravel-base-26, laravel, django, _universal> -->
<!-- framework_pack_path: <relative path to plugins/mega-sdd/references/framework-conventions/<framework>.md> -->
<!-- mutability_summary: locked=<N> intent=<N> artifact=<N> (counts from data-mutation-policy.md when KB-derived vault) -->
<!-- constitution_hash: <sha256 of constitution.md content, if present; from binding.md frontmatter> -->
<!-- properties_validated: <N total invariants across units that hold properties: blocks; from vault.json properties_summary> -->
<!-- replay_snapshot_count: <N replay snapshots recorded; from vault.json replay_state> -->
<!-- convergence_cycle_count: <N successful convergence cycles since vault inception; from vault.json convergence_state> -->
<!-- DO NOT EDIT BELOW THIS LINE — regenerate via /mega-sdd:emit-agents-md -->
```

> Header declares framework pack + mutability summary so tools consuming AGENTS.md can resolve which conventions apply + which vault claims are LOCKED vs free to redesign.
> Header also declares `constitution_hash` (sha256 for staleness detection), `properties_validated` (PBT invariant count), `replay_snapshot_count` (regression baseline count), and `convergence_cycle_count` (auto-recovery cycle count). Tools consuming AGENTS.md can now surface these as caution badges (e.g., "this AGENTS.md was generated after N convergence cycles — vault has undergone semi-automated repair; review for divergence from human intent").
> Header also declares `scope_id` and `scope_name` when vault is scope-tagged (multi-scope vault). A BE-scoped vault and FE-scoped vault now produce distinguishable AGENTS.md exports. Both lines omitted entirely for legacy single-scope vaults (back-compat).

The generation marker (HTML comment) is MANDATORY. Re-emission detects existing mega-sdd output via this marker.

## Section 1 — Project overview

```markdown
## Project overview

<2-3 sentences from vault's 01-overview.md TL;DR>

**Project shape**: <from vault.json `project_shape`>
**Implementation mode**: <from vault.json `implementation_mode`>
```

Cite source: `<!-- from 01-overview.md L<N> -->`

## Section 2 — Build commands

```markdown
## Build commands

\`\`\`bash
<build commands from vault 06-constraints.md tech-stack OR memory conventions.md>
\`\`\`

If unknown → omit section.
```

## Section 3 — Test commands

```markdown
## Test commands

\`\`\`bash
<test framework invocations from memory conventions.md OR vault 04-flows.md DoD>
\`\`\`

Example:
\`\`\`bash
# PHP project detected (phpunit from conventions.md)
./vendor/bin/phpunit
\`\`\`

If no test framework detected → "No test framework detected. Run tests manually per project README."
```

## Section 4 — Code style + conventions

```markdown
## Code style + conventions

- **File naming**: <from conventions.md OR vault 06-constraints.md>
- **Class naming**: <from conventions.md>
- **Test file convention**: <from conventions.md>
- **Error format**: <from conventions.md error envelope section>

Cite source per row: `<!-- from conventions.md §<section> -->`
```

## Section 5 — Architecture overview

```markdown
## Architecture overview

<top-level system overview from vault 02-architecture.md (the high-level paragraph, not the deep dive)>

**Layers** (from vault 02-architecture.md):
- <layer 1>: <1-sentence description>
- <layer 2>: <1-sentence description>
- ...

**Integrations** (if any):
- <integration 1>: <how it's consumed>
- ...

For detailed architecture, see: `.mega-sdd/vaults/<slug>/02-architecture.md`
```

## Section 6 — Key decisions

```markdown
## Key decisions

<list of ADR titles from vault 05-decisions.md, with 1-sentence summary each>

- **D-001 \<title\>**: <Decision in 1 sentence>. Source: <PRD § or context>
- **D-002 ...**: ...

For full ADR details, see: `.mega-sdd/vaults/<slug>/05-decisions.md`
```

## Section 7 — Open questions

```markdown
## Open questions (cautions for AI tools)

P1 (Sprint-0 blockers):
- **OQ-<TAG>-1**: <question text>. Resolution: <PIC>

P2 (Feature blockers):
- ...

These items are unresolved at vault generation time. AI tools should NOT make assumptions about them.

For full OQ roll-up: `.mega-sdd/vaults/<slug>/00-index.md` §Open Questions roll-up
```

## Section 7.5 — Constitution

When `<vault>/constitution.md` exists , include flattened constitution section in AGENTS.md for tool-agnostic consumption:

```markdown
## Constitution (project-facing rules)

Non-negotiable project invariants. AI tools MUST respect these when editing this codebase.

### Coding standards (§A)
- All API endpoints MUST use Sanctum auth middleware (constitution §A-001)
- Naming: PascalCase for classes; kebab-case for routes (§A-002)
- ... (full §A clauses)

### Security baselines (§B)
- All user input passes through Form Request validators (§B-001)
- ... (full §B clauses)

### Architecture invariants (§C)
- Controllers MUST NOT call other Controllers; use Services (§C-001)
- ... (full §C clauses)

### Anti-patterns (§D) — DO NOT replicate
- NEVER replicate cfkdhl→CFKDDL typo (§D-001; see knowledge-base §critical-findings)
- ... (full §D clauses)

### Performance constraints (§E)
- API response time median < 200ms (§E-001)
- ... (full §E clauses)

### Compliance (§F)
- All financial transactions logged to audit_log (§F-001)
- ... (full §F clauses)

For full constitution + citations: see `<vault>/constitution.md`.
```

Cite source for every clause flattened. Section omitted when constitution.md absent (backward compat).

### Conditional rendering

| Constitution status | AGENTS.md §Constitution behavior |
|---|---|
| `<vault>/constitution.md` exists + non-empty | Render full §A-F flattened |
| `<vault>/constitution.md` exists but empty | Skip section (no fluff) |
| `<vault>/constitution.md` absent (older vaults) | Skip section gracefully |

### Anti-halu

- Flattens VERBATIM from constitution.md; no paraphrasing
- Cites clause IDs (§A-001, §B-001, etc.) for traceability
- Constitution hash included in generation marker (HTML comment) for tool-detection of staleness

## Section 8 — Mega-sdd interop notes

```markdown
## Mega-sdd interop notes

This project uses mega-sdd (https://scm.bankmegadev.com/ai-rnd/mega-sdd) for spec-driven AI development. Additional context beyond this AGENTS.md:

- **Full vault**: `.mega-sdd/vaults/<slug>/` (canonical)
- **Binding manifest**: `<vault>/binding.md` (vault claims validated against codebase; CONFIRMED / CONFLICT / OQ verdicts; Implementation State Map)
- **Unit specs**: `<vault>/units/U-*.md` (atomic AI-coding-prompt units with Hard Rules pre/post-flight validation)
- **Memory** (operational context across sessions): `<project>/.mega-sdd/memory/` (canonical)

For tools that understand mega-sdd: consume the vault + binding directly for higher precision than this flattened view.

For tools that consume only AGENTS.md: this section + above sections are everything you need.
```

## Conditional section presence

| Section | Required when |
|---|---|
| Project overview | Always (always have 01-overview.md) |
| Build commands | Detected build tooling (composer/npm/cargo/gradle/etc.) |
| Test commands | Test framework detected in conventions.md OR DoD in 04-flows.md |
| Code style + conventions | conventions.md exists OR 06-constraints.md has style section |
| Architecture overview | Always (always have 02-architecture.md) |
| Key decisions | 05-decisions.md has ≥1 ADR |
| Open questions | vault.json `open_questions_summary.total > 0` |
| Mega-sdd interop notes | Always (signals mega-sdd presence to AGENTS.md-aware tools) |

Empty sections OMITTED (not rendered with placeholders).

## Conditional header field presence

Header HTML comments declare vault-state fields. Each field renders ONLY when its source data exists; otherwise the line is OMITTED entirely (NOT rendered with a placeholder).

| Header field | Source | Render when |
|---|---|---|
| `scope_id` | `vault.json` `scope_metadata.id` | vault has `scope` field (multi-scope vault); OMIT line otherwise |
| `scope_name` | `vault.json` `scope_metadata.name` | vault has `scope` field (multi-scope vault); OMIT line otherwise |
| `constitution_hash` | `binding.md` frontmatter `constitution_hash` | `<vault>/constitution.md` exists AND binding.md has been written  |
| `properties_validated` | `vault.json` `properties_summary.total` | vault has ≥1 unit with `properties:` block  |
| `replay_snapshot_count` | `vault.json` `replay_state.snapshot_count` | vault has been replayed at least once via `/mega-sdd:replay`  |
| `replay_snapshot_count` value 0 | omit field entirely | new vault, never replayed |
| `convergence_cycle_count` | `vault.json` `convergence_state.cycles_completed` | `/mega-sdd --converge` has run ≥1 successful cycle  |
| `convergence_cycle_count` value 0 | omit field entirely | no convergence runs |

**Anti-halu rails:**

- Each header field cites a SPECIFIC source location in vault.json or binding.md. NEVER invented; if the source is missing, the field is omitted.
- `constitution_hash` is the canonical staleness signal — if AGENTS.md emit predates a constitution.md update, the hash differs and downstream tools flag this AGENTS.md as stale.
- `convergence_cycle_count > 0` is a SOFT CAUTION signal to AI tools consuming AGENTS.md — vault has undergone semi-automated repair, so manual review is recommended.

## Append mode

When `--mode=append` AND existing AGENTS.md detected:

1. Read existing file
2. Identify user-authored content (everything before the mega-sdd generation marker)
3. Preserve user content unchanged
4. Append mega-sdd-emitted sections below a clear separator:

```markdown
<!-- user content above -->
...

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- BEGIN MEGA-SDD GENERATED SECTIONS — DO NOT EDIT MANUALLY        -->
<!-- Regenerate via /mega-sdd:emit-agents-md                          -->
<!-- ═══════════════════════════════════════════════════════════════ -->

<!-- generated_by: mega-sdd:emit-agents-md {{generator_version}} -->
<!-- ... rest of mega-sdd output ... -->
```

## Sibling mode

When `--mode=sibling` (default safe when existing AGENTS.md detected and not user-confirmed for append/overwrite):

Output written to `<repo-root>/AGENTS.mega-sdd.md` instead. Both files coexist. Tools that look for AGENTS.md find user's; tools that also look for AGENTS.*.md find mega-sdd's.

## Idempotent regeneration

Subsequent runs:
1. Detect existing AGENTS.md with mega-sdd marker
2. Re-render from current vault state
3. Replace mega-sdd sections (everything below the marker) with new output
4. Preserve user-authored content (everything above the marker, append mode)

User can git-diff the regeneration to see what changed.
