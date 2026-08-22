---
name: emit-agents-md
version: 1.7.0
description: Flatten vault + binding + units into AGENTS.md (AAIF standard) for tool-agnostic interop; marker-guarded write-out. Triggers — "emit agents.md", "generate agents file", "tool-agnostic export", "interop agents.md", or paraphrases.
---

# Emit AGENTS.md — Tool-Agnostic Interop

Generates `AGENTS.md` at repo root from vault + binding + units context. AGENTS.md is the [Linux Foundation AAIF](https://agents.md/) emerging standard for AI-coding-tool interop.

**Announce at start:** "I'm using the emit-agents-md skill to flatten vault into AGENTS.md format. `mega-sdd-trace:emit-agents-md`"

**Core principle:** Pure transformation. No inference. No invention. Just project vault → AGENTS.md schema.

## When to use

- Explicit: `emit-agents-md`
- Auto: `orchestrate-flow --deep` runs this at chain end (config-controlled per ITER6-OQ-4)
- Opt-out per chain: `--no-agents-md` flag
- Opt-out per project: `<project>/.mega-sdd/config.yaml` `defaults.emit_agents_md: false`

## When NOT to use

- AGENTS.md exists AND user authored it manually → ask first; do NOT overwrite
- Vault is fully greenfield (no implementation context yet) → halt; AGENTS.md without bind context is fluff
- User explicitly disabled via config

## Inputs

- Vault path (positional, default: detect in priority order `.mega-sdd/vaults/*/vault.json` (canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy back-compat))
- `--out=<path>` (default `<repo-root>/AGENTS.md`)
- `--mode=overwrite|append|sibling` (default `sibling` if AGENTS.md exists; creates `AGENTS.mega-sdd.md`)
- `--include-section=<list>` (default all: build, test, conventions, architecture, decisions)
- `--auto`

## Output

`AGENTS.md` at `<repo-root>/` (or specified path). Format per [agents.md spec](https://agents.md/).

Output shape: a generation-marker header block (HTML comments citing vault source + versions), then the conditional sections Project overview / Build commands / Test commands / Code style + conventions / Architecture overview / Key decisions / Open questions / Constitution / Mega-sdd interop notes — each rendered per the schema's conditional-presence tables.
The authoritative template is `references/agents-md-schema.md` — render from it (procedure step 5); it owns the header field list, per-section shapes, and the conditional-presence tables.
Never render from memory of this summary.

## Path resolution

Per `plugins/mega-sdd/references/paths.md`:

- **AGENTS.md output**: `<repo-root>/AGENTS.md` (UNCHANGED — interop file MUST be at repo root for discovery by Continue.dev, Cursor, Aider, etc.)
- **Vault detection**: probe BOTH `<project>/.mega-sdd/vaults/*/vault.json` AND `<project>/docs/mega-sdd/vaults/*/vault.json` (legacy) — use first match
- **Generation marker**: HTML comment cites the vault path actually used so future regen knows source

## Procedure

1. **Detect vault**. Walk CWD for `<project>/.mega-sdd/vaults/*/vault.json` FIRST, then fall back to `<project>/docs/mega-sdd/vaults/*/vault.json` (legacy). OR accept explicit positional arg.
2. **Check existing AGENTS.md**:
   - If `<repo-root>/AGENTS.md` exists AND has no mega-sdd generation marker → halt; ask user choice per the glossed menu in §Halt conditions (sibling recommended; overwrite flagged destructive)
   - If exists AND has mega-sdd marker → safe to regenerate (marker-detected)
3. **Read vault sources**:
   - `vault.json` for structured metadata (project shape, mode, OQ counts)
   - `vault.md`, `flows.md`, `constraints.md` (legacy: `00-index.md`/`01-overview.md`/`02-architecture.md`/`05-decisions.md` + siblings) for prose
   - `binding.md` (if exists) for implementation state
   - `<project>/.mega-sdd/memory/conventions.md` (if exists) for detected conventions
4. **Read user-authored AGENTS.md** (if `--mode=append`):
   - Preserve user-authored sections (anything before mega-sdd generation marker)
   - Append mega-sdd section after marker
5. **Render per template** in `references/agents-md-schema.md`. Cite vault file:section for every claim (best-effort — no deterministic verifier backs this lane, unlike the four doc-packs) (anti-halu rail: AGENTS.md is a flattened view, must cite source). **Variable substitution:**
   - `{{generator_version}}` → the plugin's own version, read from `plugin.json` `version` at the resolved plugin root (per `plugins/mega-sdd/references/plugin-root-resolution.md`). If the plugin root cannot be resolved, OMIT the token entirely so the marker renders `<!-- generated_by: mega-sdd:emit-agents-md -->` (still valid — safe re-emission detects the marker via the `generated_by: mega-sdd:emit-agents-md` substring, NEVER the version). NEVER hard-code a literal version.
   - `{{vault_path}}` → actual detected vault directory relative to repo root. canonical → `.mega-sdd/vaults/<slug>`; legacy → `docs/mega-sdd/vaults/<slug>`. NEVER hard-code either path.
   - `{{scope_id}}` → vault.json `scope_metadata.id` (only when vault has scope field; OMIT entire header line otherwise)
   - `{{scope_name}}` → vault.json `scope_metadata.name`; OMIT line otherwise
   - `{{vault_version}}` → `vault.json` `version` field
   - `{{constitution_hash}}` → from `binding.md` frontmatter (only if `<vault>/constitution.md` exists AND binding has been written); OMIT entire header line otherwise
   - Per `references/agents-md-schema.md` §Conditional header field presence — each field renders ONLY when its source data exists; absent → line omitted, NEVER rendered with placeholder values.
6. **Write to output path**. Best-effort flatten — model-rendered, NOT byte-idempotent; the vault remains the sole source of truth and AGENTS.md is never a cited record.
6.5. **Claude Code bridge (the official interop pair).** Claude Code does NOT read AGENTS.md natively (CLAUDE.md only; the sanctioned bridge is an `@AGENTS.md` import — per code.claude.com/docs/en/memory). After writing AGENTS.md: if the repo has NO `CLAUDE.md`, OFFER to create a minimal stub (`@AGENTS.md` as its first line + a one-line note); if `CLAUDE.md` exists WITHOUT an `@AGENTS.md` import, OFFER to append the import line. Never edit CLAUDE.md without explicit yes — it is user-owned.
7. **Hand-off**: announce "AGENTS.md written to `<path>`. Tools that support AGENTS.md (Codex, Copilot, Cursor, Jules, Gemini, Continue.dev, Aider) consume it directly; Claude Code reads it via the `@AGENTS.md` import in CLAUDE.md (offered above)."

## Halt conditions

- AGENTS.md exists, user-authored, no marker → halt; ask via AskUserQuestion with the glossed menu (keterangan contract): `sibling` **(recommended — the safe default per the Hard rails)** — tulis `AGENTS.mega-sdd.md` terpisah, file lo tidak disentuh; `append` — konten mega-sdd ditambahkan di bawah marker, teks manual dipertahankan; `overwrite` — **DESTRUKTIF**: AGENTS.md lama diganti seluruhnya, isi manual hilang
- Vault not detected → halt; ask user for explicit path
- vault.json missing required fields → halt; vault is corrupt; instruct repair

## Anti-hallucination rails

- AGENTS.md is a FLATTENED VIEW of vault. Never adds info not in vault.
- Generation marker (`<!-- generated_by: mega-sdd:emit-agents-md {{generator_version}} -->`) MANDATORY for safe re-generation detection (detection keys on the `generated_by: mega-sdd:emit-agents-md` substring, never the version)
- Sections that have no source content in vault → OMITTED (not faked with placeholders)
- User-authored AGENTS.md preserved when `--mode=append`; mega-sdd appends below a clear marker
- `--mode=sibling` writes `AGENTS.mega-sdd.md` instead of overwriting (safe default when existing AGENTS.md detected)

## Handoff emission (when --auto)

```yaml
handoff:
  emitted_by: emit-agents-md
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - <absolute path to AGENTS.md or AGENTS.mega-sdd.md>
  next_action:
    suggested_skill: null    # terminal skill; no pipeline continuation
    type: chain_complete     # AGENTS.md is the pipeline terminal output for AI agent consumers
    rationale: "AGENTS.md emitted; pipeline already complete."
  blockers: []               # populated on halt — envelope per plugins/mega-sdd/references/halt-protocol.md
  metrics:
    agents_md_lines: <N>
    rules_emitted: <N>
  scope:                                       # omit block when vault has no scope field
    id: <vault.scope_metadata.id>
    name: <vault.scope_metadata.name>
    sibling_scopes: <vault.scope_metadata.sibling_scopes_in_prd>
    prd_sha256: <vault.prd_sha256>
```

Status `halted` on: `user_authored_conflict | vault_not_found | vault_corrupt | greenfield_no_bind_context` — the §Halt conditions above; under `--auto` there is no user to ask, so emit the blocker envelope instead of prompting. (This skill only READS memory files and never takes the vault.json lock, so it can never emit `memory_in_use`.)

When vault has `scope` field, handoff YAML MUST include scope: block per `orchestrate-flow/references/handoff-contract.md` (scope block). Omit when vault is legacy single-scope.

## References

- AGENTS.md spec: https://agents.md/
- Agentic AI Foundation (AAIF): https://aaif.io
- `references/agents-md-schema.md` — full per-section template
- Design spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.4
