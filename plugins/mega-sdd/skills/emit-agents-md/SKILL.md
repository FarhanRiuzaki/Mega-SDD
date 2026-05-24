---
name: emit-agents-md
version: 1.2.4
description: Flatten mega-sdd vault + binding + units summary into AGENTS.md format (Linux Foundation AAIF standard; 60k+ repos adopt). Tool-agnostic visibility — Continue.dev, Cursor, Aider, and other AGENTS.md-aware tools can consume mega-sdd's intelligence without knowing mega-sdd specifics. Pure write-out; zero runtime cost; idempotent regeneration. Triggers — "emit agents.md", "generate agents file", "tool-agnostic export", "interop agents.md", or paraphrases.
---

# Emit AGENTS.md — Tool-Agnostic Interop

Generates `AGENTS.md` at repo root from vault + binding + units context. AGENTS.md is the [Linux Foundation AAIF](https://agents.md/) emerging standard for AI-coding-tool interop — adopted by 60k+ repos as of mid-2026.

**Announce at start:** "I'm using the emit-agents-md skill to flatten vault into AGENTS.md format."

**Core principle:** Pure transformation. No inference. No invention. Just project vault → AGENTS.md schema.

## When to use

- Explicit: `/mega-sdd:emit-agents-md`
- Auto: `orchestrate-flow --deep` runs this at chain end (config-controlled per ITER6-OQ-4)
- Opt-out per chain: `--no-agents-md` flag
- Opt-out per project: `<project>/.mega-sdd/memory/config.yaml` `defaults.emit_agents_md: false`

## When NOT to use

- AGENTS.md exists AND user authored it manually → ask first; do NOT overwrite
- Vault is fully greenfield (no implementation context yet) → halt; AGENTS.md without bind context is fluff
- User explicitly disabled via config

## Inputs

- Vault path (positional, default: detect in priority order `.mega-sdd/vaults/*/vault.json` (v3.4+ canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy back-compat))
- `--out=<path>` (default `<repo-root>/AGENTS.md`)
- `--mode=overwrite|append|sibling` (default `sibling` if AGENTS.md exists; creates `AGENTS.mega-sdd.md`)
- `--include-section=<list>` (default all: build, test, conventions, architecture, decisions)
- `--auto`

## Output

`AGENTS.md` at `<repo-root>/` (or specified path). Format per [agents.md spec](https://agents.md/).

The output template is a LITERAL emission target — every line below is written verbatim to AGENTS.md EXCEPT (a) `{{var}}` template tokens replaced by procedure step 5, and (b) conditional lines omitted entirely when their source data is absent per `references/agents-md-schema.md` §Conditional header field presence (`constitution_hash`, `properties_validated`, `replay_snapshot_count`, `convergence_cycle_count`).

```markdown
# AGENTS.md

<!-- generated_by: mega-sdd:emit-agents-md v1.2.4 -->
<!-- vault_source: {{vault_path}}/vault.json -->
<!-- scope_id: {{scope_id}} -->
<!-- scope_name: {{scope_name}} -->
<!-- generated_at: <ISO8601> -->
<!-- vault_version: {{vault_version}} -->
<!-- constitution_hash: {{constitution_hash}} -->
<!-- properties_validated: {{properties_validated}} -->
<!-- replay_snapshot_count: {{replay_snapshot_count}} -->
<!-- convergence_cycle_count: {{convergence_cycle_count}} -->

## Project overview

<from 01-overview.md TL;DR>

## Build commands

<from 06-constraints.md tech-stack section, if present>

## Test commands

<from 04-flows.md DoD test invocations, OR conventions.md test framework if memory layer detected it>

## Code style + conventions

<from 06-constraints.md naming + style section + conventions.md established conventions>

## Architecture overview

<from 02-architecture.md top-level summary>

## Key decisions

<from 05-decisions.md ADR titles + 1-sentence summaries>

## Open questions

<from 00-index.md OQ roll-up; surfaced as cautions for AI tools>

## Mega-sdd interop notes

For tools that understand mega-sdd:
- Full vault at: `{{vault_path}}/`
- Binding manifest: `binding.md` (claims validated against codebase)
- Unit specs: `<vault>/units/U-*.md` (atomic AI-coding prompts with Hard Rules)
- Memory: `<project>/.mega-sdd/memory/` (operational context across sessions)

For AGENTS.md-only tools: the sections above contain everything you need.
```

## Path resolution (v1.1+, Iter 10)

Per `plugins/mega-sdd/references/paths.md`:

- **AGENTS.md output**: `<repo-root>/AGENTS.md` (UNCHANGED — interop file MUST be at repo root for discovery by Continue.dev, Cursor, Aider, etc.)
- **Vault detection**: probe BOTH `<project>/.mega-sdd/vaults/*/vault.json` (v3.4+) AND `<project>/docs/mega-sdd/vaults/*/vault.json` (legacy) — use first match
- **Generation marker**: HTML comment cites the vault path actually used so future regen knows source

## Procedure

1. **Detect vault**. Walk CWD for `<project>/.mega-sdd/vaults/*/vault.json` (v3.4+) FIRST, then fall back to `<project>/docs/mega-sdd/vaults/*/vault.json` (legacy). OR accept explicit positional arg.
2. **Check existing AGENTS.md**:
   - If `<repo-root>/AGENTS.md` exists AND has no mega-sdd generation marker → halt; ask user choice (overwrite / append / sibling)
   - If exists AND has mega-sdd marker → safe to regenerate (idempotent)
3. **Read vault sources**:
   - `vault.json` for structured metadata (project shape, mode, OQ counts)
   - `00-index.md`, `01-overview.md`, `02-architecture.md`, `04-flows.md`, `05-decisions.md`, `06-constraints.md` for prose
   - `binding.md` (if exists) for implementation state
   - `<project>/.mega-sdd/memory/conventions.md` (if exists) for detected conventions
4. **Read user-authored AGENTS.md** (if `--mode=append`):
   - Preserve user-authored sections (anything before mega-sdd generation marker)
   - Append mega-sdd section after marker
5. **Render per template** in `references/agents-md-schema.md`. Cite vault file:section for every claim (anti-halu rail: AGENTS.md is a flattened view, must cite source). **Variable substitution (v1.2.3+, Iter 26 — closes P1-A + P1-9 from v3.17.0 verification audit):**
   - `{{vault_path}}` → actual detected vault directory relative to repo root. v3.4+ canonical → `.mega-sdd/vaults/<slug>`; legacy → `docs/mega-sdd/vaults/<slug>`. NEVER hard-code either path.
   - `{{scope_id}}` → vault.json `scope_metadata.id` (only when vault has scope field; OMIT entire header line otherwise); v1.2.4+ Iter 29 P1-4
   - `{{scope_name}}` → vault.json `scope_metadata.name`; OMIT line otherwise; v1.2.4+ Iter 29 P1-4
   - `{{vault_version}}` → `vault.json` `version` field
   - `{{constitution_hash}}` → from `binding.md` frontmatter (only if `<vault>/constitution.md` exists AND binding has been written); OMIT entire header line otherwise
   - `{{properties_validated}}` → from `vault.json` `properties_summary.total` (only if ≥1 unit has `properties:` block); OMIT line otherwise
   - `{{replay_snapshot_count}}` → from `vault.json` `replay_state.snapshot_count` (only if value > 0); OMIT line otherwise
   - `{{convergence_cycle_count}}` → from `vault.json` `convergence_state.cycles_completed` (only if value > 0); OMIT line otherwise
   - Per `references/agents-md-schema.md` §Conditional header field presence — each field renders ONLY when its source data exists; absent → line omitted, NEVER rendered with placeholder values.
6. **Write to output path**. Idempotent — same vault → same output.
7. **Hand-off**: announce "AGENTS.md written to `<path>`. Tools that support AGENTS.md (Continue.dev, Cursor, Aider, etc.) can now consume mega-sdd context."

## Halt conditions

- AGENTS.md exists, user-authored, no marker → halt; ask `overwrite | append | sibling` via AskUserQuestion
- Vault not detected → halt; ask user for explicit path
- vault.json missing required fields → halt; vault is corrupt; instruct repair

## Anti-hallucination rails

- AGENTS.md is a FLATTENED VIEW of vault. Never adds info not in vault.
- Generation marker (`<!-- generated_by: mega-sdd:emit-agents-md v1.0 -->`) MANDATORY for safe re-generation detection
- Sections that have no source content in vault → OMITTED (not faked with placeholders)
- User-authored AGENTS.md preserved when `--mode=append`; mega-sdd appends below a clear marker
- `--mode=sibling` writes `AGENTS.mega-sdd.md` instead of overwriting (safe default when existing AGENTS.md detected)

## Handoff emission (when --auto)

```yaml
handoff:
  emitted_by: emit-agents-md
  emitted_at: <ISO8601>
  status: completed
  artifacts:
    - <absolute path to AGENTS.md or AGENTS.mega-sdd.md>
  next_action:
    suggested_skill: null    # terminal skill; no pipeline continuation
    rationale: "AGENTS.md emitted; pipeline already complete."
  blockers: []
  scope:                                       # v1.2.4+ Iter 29 (P1-4) — omit block when vault has no scope field
    id: <vault.scope_metadata.id>
    name: <vault.scope_metadata.name>
    sibling_scopes: <vault.scope_metadata.sibling_scopes_in_prd>
    prd_sha256: <vault.prd_sha256>
```

**v1.2.4+ Iter 29 (P1-4)**: When vault has `scope` field, handoff YAML MUST include scope: block per `orchestrate-flow/references/handoff-contract.md` v3.20+ contract (line 44). Omit when vault is legacy single-scope.

## References

- AGENTS.md spec: https://agents.md/
- Linux Foundation AAIF: https://www.linuxfoundation.org/projects/aaif (AI Agents Interop Forum)
- `references/agents-md-schema.md` — full per-section template
- Iter 6 spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.4
