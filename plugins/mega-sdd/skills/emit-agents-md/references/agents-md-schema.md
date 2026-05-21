# AGENTS.md Schema — Mega-sdd Emission Format

Per [agents.md spec](https://agents.md/) (Linux Foundation AAIF). Mega-sdd emits a subset focused on what AI coding tools (Continue.dev, Cursor, Aider, Copilot) actually consume.

## Header

```markdown
# AGENTS.md

<!-- generated_by: mega-sdd:emit-agents-md v1.0.0 -->
<!-- vault_source: docs/mega-sdd/vaults/<slug>/vault.json -->
<!-- generated_at: <ISO8601> -->
<!-- vault_version: <vault.json version field> -->
<!-- DO NOT EDIT BELOW THIS LINE — regenerate via /mega-sdd:emit-agents-md -->
```

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

For detailed architecture, see: `docs/mega-sdd/vaults/<slug>/02-architecture.md`
```

## Section 6 — Key decisions

```markdown
## Key decisions

<list of ADR titles from vault 05-decisions.md, with 1-sentence summary each>

- **D-001 \<title\>**: <Decision in 1 sentence>. Source: <PRD § or context>
- **D-002 ...**: ...

For full ADR details, see: `docs/mega-sdd/vaults/<slug>/05-decisions.md`
```

## Section 7 — Open questions

```markdown
## Open questions (cautions for AI tools)

P1 (Sprint-0 blockers):
- **OQ-<TAG>-1**: <question text>. Resolution: <PIC>

P2 (Feature blockers):
- ...

These items are unresolved at vault generation time. AI tools should NOT make assumptions about them.

For full OQ roll-up: `docs/mega-sdd/vaults/<slug>/00-index.md` §Open Questions roll-up
```

## Section 8 — Mega-sdd interop notes

```markdown
## Mega-sdd interop notes

This project uses mega-sdd (https://gitlab.com/airnd1/mega-sdd) for spec-driven AI development. Additional context beyond this AGENTS.md:

- **Full vault**: `docs/mega-sdd/vaults/<slug>/` (7-file structured spec + vault.json manifest)
- **Binding manifest**: `<vault>/binding.md` (vault claims validated against codebase; CONFIRMED / CONFLICT / OQ verdicts; Implementation State Map)
- **Unit specs**: `<vault>/units/U-*.md` (atomic AI-coding-prompt units with Hard Rules pre/post-flight validation)
- **Memory** (operational context across sessions): `<project>/.mega-sdd-memory/`

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

<!-- generated_by: mega-sdd:emit-agents-md v1.0.0 -->
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
