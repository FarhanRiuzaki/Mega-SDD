---
description: THE mega-sdd front door — any SDD lane phrase routes here. No arg → derive-state status view (position, vault, counts, staleness, foreign-SDD/adoption notices) + propose the next chain with ONE upfront confirmation. With an artifact arg (PRD / legacy dir / vault / brief) → input-shape detection + the adoption lane. Every gated phase stays Skill-dispatched. Deprecated /mega-sdd:<command> aliases resolve through 5.x.
argument-hint: "[input] [--deep|--shallow] [--greenfield] [--scope=<id>] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual] [--out=<path>] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md] [--converge|--no-converge] [--max-cycles=N] [--with-fsd] [--lean|--full] [--no-telemetry] [--plan|--act|--plan-then-act]"
---

> **The 5.0.0 surface** — three public verbs: `/mega-sdd` (this front door), `/mega-sdd:sync` (reconcile with moved code), `/mega-sdd:emit <prd|fsd|sit|uat>` (the four team documents). Everything else is either auto-invoked by the chain, PROPOSED by this front door when state demands it, or a deprecated alias that keeps resolving through the 5.x cycle.

This command THINLY WRAPS the orchestrate-flow machinery — it detects the input shape, renders state, and dispatches; it never duplicates chain logic. **Every gated phase is dispatched via the Skill tool (`mega-sdd:orchestrate-flow` and its sub-skills) — NEVER offloaded to the Agent tool.** The PreToolUse moat gates key on Skill calls; an Agent-tool offload would bypass them (matcher excludes `Agent`), so it is forbidden.

User arguments: $ARGUMENTS

> `--lean` / `--full` — the tranche-E profile switch (opt-in): lean trims the advisor legs (`--no-advisor`, recorded as `advisor: skipped`) + the advisory chain diagnostics; persistent form `profile: lean` in `.mega-sdd/config.yaml` (also governs the Stop-hook analyze aggregate — the flag alone does not). Never touches any gate. → orchestrate-flow SKILL §Auto-integrated diagnostics.

## Lane 0 — no argument: status view + next-chain proposal

When `<input>` is empty:

1. `Run: scripts/derive-state.sh --cwd=<root>` (pre-init CWDs: add `--json-only` and read stdout), then read `.mega-sdd/state.json`.
2. Render the **status view** from the digest — compact, Indonesian narrative + English technical terms:
   - **Position** — `derived.position` + `derived.mode_inferred` + starterkit mode.
   - **Vault(s)** — per vault: docs present, units count, bolts count, OQ P0/P1 open, binding state (CONFIRMED/CONFLICT/OQ counts), drift-report / PENDING-SYNC presence.
   - **Staleness** — `change_signal` (map stamp vs HEAD, dirty-journal rows). Change signal present → surface it and prefer proposing `/mega-sdd:sync`.
   - **Foreign-SDD / adoption** — `probes.foreign_sdd` non-empty → name the detected tool(s) (spec-kit / Kiro / OpenSpec / generic specs) and propose the adoption lane (certify + ingest), never silent.
   - **Maintenance notices (auto-PROPOSED, never auto-run)** — when state demands, propose the matching maintenance one-timer with one keterangan line each: legacy scattered layout detected → `/mega-sdd:migrate-paths`; missing native deps limiting a proposed phase → `/mega-sdd:install-deps`; pending learning suggestions → `/mega-sdd:memory review`; plugin cache behind the marketplace clone → `/mega-sdd:update-plugin`.
3. Propose the next chain from `derived.proposed_next` and confirm ONCE (the same upfront-confirmation contract as orchestrate-flow — Run / Edit / Cancel covering ALL phases including execute-bolts), then invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` (+ user flags). No fixed starting phase; the digest decides.

## Lane 1 — with an artifact argument: input-shape detection

Argument parsing (input detection rules, per spec `2026-05-20-autonomy-layer-design.md` §4 Pillar 4):

1. **Is `<input>` a path to a directory?**
   - Does it contain code files (`.{js,ts,php,py,rs,go,java,…}`) but NO vault at any of these paths: `.mega-sdd/vaults/*/vault.json` (canonical), `docs/mega-sdd/vaults/*/vault.json` (legacy), `vaults/*/vault.json` (oldest legacy)?
     - YES → legacy codebase. Propose chain starting with `extract-intelligence <input>` (REQUIRES `--out=<path>` per AUTONOMY-OQ-7 — conflating extract output with rebuild project dir is dangerous; `--out` is the OUTPUT_ROOT / parent dir, default `--out=.mega-sdd/` → KB at `<out>/knowledge-base/`).
   - Does it contain a vault at any of these paths (priority order): `.mega-sdd/vaults/*/vault.json` (canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy)?
     - YES → existing vault. Propose chain starting with `scan-codebase` (if no codebase-map at `.mega-sdd/codebase/codebase-map.md` or legacy `codebase-map.md`) or `bind-codebase` (if codebase-map exists) or `generate-units` (if bound-vault exists).
   - Otherwise → halt; ask user to clarify directory purpose.

2. **Is `<input>` a path to a file?**
   - Extension `.{md,pdf,docx,txt}` → likely PRD. Propose chain starting with `generate-intent <input>` (Mode A).
   - Extension `.json` with vault schema → vault file directly. Propose chain starting with `bind-codebase`.
   - **Other extension / unrecognized shape → the adoption lane (P2), no more dead end.** `Run: scripts/certify-artifact.sh --cwd=<root> --rung=prd --path=<input>` (the shape sniffer — classifies only, gates nothing downstream) and surface its keterangan verbatim (it explains WHAT was detected: PRD-shaped / arbitrary text / source-code-looking / binary):
     - `CERTIFIED` → proceed `generate-intent <input>` (Mode A).
     - `CERTIFIED_DEGRADED` → proceed `generate-intent <input>`, keterangan already warns the vault will be OQ-heavy and offers Mode B (`--from-prompt`) as the alternative.
     - `DEMOTE` → C2 halt `adoption_demote_confirm` (decision 7: ALWAYS confirmed under `--auto` — keterangan first, ONE AskUserQuestion `RE_INGEST`/`MANUAL_FIX`/`CANCEL`, then proceed per the answer).
     - `REJECTED` (binary/non-text) → halt with the certify keterangan verbatim; ask for a text document or the file's intent.

3. **Is `<input>` quoted free-text** (e.g., `"build a clinic appointment system"`)?
   - YES → Mode B brief. Propose chain starting with `generate-intent --from-prompt <input>`.

4. **Flag handling**:
   - `--deep` (default true; opt-out via `--shallow` to revert to 3-skill cap).
   - `--greenfield` — EXPLICIT opt-in for stack-agnostic vault generation. REQUIRED when CWD has no framework manifest (package.json / composer.json / Gemfile / pyproject.toml / go.mod / Cargo.toml). Without this flag AND no manifest detected → halt `no_starterkit_detected`.
   - `--step-after=<phase>` — switch to manual handoffs after this phase (e.g., `--step-after=bind-codebase` to review binding before continuing).
   - `--stop-after=<phase>` — halt after this phase even if no blocker.
   - `--resume` — re-enter a paused/halted chain; CWD inspection (a fresh `derive-state.sh` digest) rebuilds cursor; halts re-fire if blockers unresolved.
   - `--manual` — disable autonomy entirely; reverts to per-skill explicit-command behavior (each skill's chat hint replaces auto-continue).
   - `--out=<path>` — REQUIRED when starting phase is `extract-intelligence` (legacy rebuild scenario). Specifies the OUTPUT_ROOT (parent dir), default `.mega-sdd/`; the KB is written to `<out>/knowledge-base/`.

## Starterkit detection

Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield" — starterkit is REQUIRED by default. Three modes per `orchestrate-flow/references/routing-rules.md` §Decision matrix:

| Mode | Trigger | Pipeline ordering |
|---|---|---|
| **A — Starterkit-first** (DEFAULT) | Framework manifest detected + pack match found in `references/framework-conventions/` | scan-codebase FIRST → generate-intent --scan=<map> (pack-aware vault, dual-citation format) → bind → units → bolts |
| **B — Framework-detected** (universal fallback) | Manifest detected but no pack match | scan-codebase FIRST → generate-intent --scan=<map> (universal conventions from `_universal.md`) → bind → units → bolts |
| **C — Greenfield (EXPLICIT)** | `--greenfield` flag OR (cwd empty/.git-only AND user confirms via halt) | generate-intent --greenfield (stack-agnostic vault) → user scaffolds later → re-run scan to bind |

When neither manifest nor `--greenfield` set → halt `no_starterkit_detected` with options (scaffold first / opt in greenfield / cancel).

After detection + flag parse, invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto [--from=<detected-start>] [--greenfield] [other-flags]`.

## Multi-scope picker

When PRD input has canonical `scopes:` frontmatter block, the front door invokes the scope picker BEFORE the pipeline starts:

```
▶ Phase 0a: PRD scope detection
  Reading <prd-path> frontmatter...
  ✓ Canonical format detected (scopes: BE, MW, FE)
  Smart default: BE (cwd basename matches scope id)

❓ This vault is for which scope?
   [1] BE — Backend API (recommended)
   [2] MW — Integration Middleware
   [3] FE — Frontend Web
   [4] All scopes (single combined vault — legacy behavior)
   [5] Cancel
```

`--scope=<id>` flag bypasses picker. `--scope=all` invokes legacy single-vault behavior (with warning).

When PRD lacks scopes block → retrofit bridge fires per `skills/generate-intent/references/legacy-retrofit-prompt.md`.

When memory has prior scope decision for this PRD + cwd matches → silent default with confirm-once UX.

See `tests/scenarios/scenario-7-multi-architect.md` for walkthrough.

## Auto-integrated diagnostics

The chain transparently invokes diagnostic skills at appropriate phases — the user does NOT need to run them separately:

| Phase | Auto-invokes | Why |
|---|---|---|
| After `generate-units` | `lint-units` | Quality gate before bolt execution |
| Before `execute-bolts` | `analyze-parallelism` | Compute optimal wave plan for `--parallel` |
| After `execute-bolts` | `list-modules` | Per-module status in chain summary |
| At chain end | `emit-agents-md` | Tool-agnostic interop file refreshed |
| At chain end | `emit-fsd` (**OPT-IN** — requires `--with-fsd` flag; pandoc + Chrome md2pdf render) | Hybrid Confluence FSD (PDF + Markdown) at `<vault>/fsd/` with sha256-grounded citations — only when `--with-fsd` passed |
| At chain end | `emit-sit` **PROPOSAL** (one line, never auto-run) when ≥1 `bolts/U-*/acceptance.json` exists | "Bukti eksekusi tersedia — `/mega-sdd:emit sit` menghasilkan SIT dengan tabel bukti §4 script-derived" |
| At chain end | `emit-uat` **MENTION** (one line, never auto-run) when SIT.md exists | "Tim UAT butuh test script? `/mega-sdd:emit uat` menghasilkan skenario bisnis 1:1 dari flow + berita acara" |
| At chain end | `emit-prd` reverse-lane **MENTION** (one line, never auto-run) when a KB exists but no vault | Team-readable PRD draft from the KB, markers `[VERIFIED]/[INFERRED]/[OPEN]` carried verbatim |
| At EACH chain boundary | Doc-control stamp refresh for existing emitted docs (`scripts/refresh-doc-stamps.sh --doc=<fsd\|prd\|sit\|uat> --position=…` — script-lane, ~0 tokens, `--position` only; never a maturity bump) | Doc-control blocks stay current between full emissions |
| At chain end | Memory review prompt | Surface pending learning suggestions |

**Opt-out per diagnostic**: `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags available for debugging or non-standard workflows.

**Opt-in only:**
- `--with-fsd` — OPT-IN auto FSD generation at chain end (default: off; pandoc + Chrome md2pdf render; user can invoke `/mega-sdd:emit fsd` manually for one-off)
- `--no-fsd` — legacy alias / no-op (FSD is opt-in via `--with-fsd`)
- `--no-telemetry` — suppress telemetry.jsonl writes for this chain. Persistent opt-out via `defaults.telemetry: false` in `<project>/.mega-sdd/config.yaml`. Read schema: `plugins/mega-sdd/references/telemetry-schema.md`
- `--plan` — force Plan mode regardless of classifier output. Plan mode is non-destructive: skill body reasons + emits proposed actions but performs no writes. User reviews + transitions to Act via the `--act` flag (`/mega-sdd --act`).
- `--act` — force direct Act mode regardless of classifier. For MAJOR iter, requires confirmation prompt (safety gate). Used in Plan-then-Act transition.
- `--plan-then-act` — explicit two-phase: Plan first, halt, then Act on continuation. Overrides classifier default for any iter type.

## Convergence loops

In `--deep` mode, the chain auto-loops eligible halts up to `--max-cycles` (default 5) instead of stopping on first halt. Cycle-eligible halts:

- `bind_conflict` → auto-invoke `resolve-oq --binding` with memory-pre-filled recommendations → re-run binding
- `module_blocked_by` → auto-run prerequisite module first
- `cross_squad_interface_draft` → wait+retry for producer to lock interface
- `oq_recommend_underspecified` → auto-regenerate recommendation fields

Halts that ALWAYS STOP (no auto-loop; require human review): `hard_rule_violated`, `dedup_ambiguous`, `quality_gate_failed`, `oq_business_p1_unresolved`, `test_fail` (post-retries), `hard_rule_unparseable`, `cross_module_dep_invalid`, `memory_schema_mismatch`, `mode_migrate`.

Per-cycle chat output:

```
⛔ Halt: bind_conflict (3 conflicts)
🔁 Cycle 1/5: auto-resolving via resolve-oq...
   ↳ C-007 → KEEP_CODE (memory 8/10; conf: 0.95) → ACCEPTED
✓ Cycle 1 complete. Re-running bind-codebase...
```

Opt-out: `--no-converge` reverts to pre-v3.12 (stop on any halt). Adjust limit: `--max-cycles=10`.

See `orchestrate-flow/SKILL.md` §Convergence loops for full algorithm + safety rails.

## Hard rails:
- **ONE upfront confirmation** showing the full proposed chain (per skill, per arguments). User picks Run / Edit / Cancel.
- **All existing halt-protocol blockers fire identically** — CONFLICT, business OQ P1, dedup_ambiguous, hard_rule_violated, cross_squad_*, quality_gate_failed. Chain pauses; user resolves; runs `/mega-sdd --resume`.
- **Anti-halu invariants preserved**: binding gate non-negotiable, OQ-business stays human-decided, dedup_ambiguous halts on conflict, Hard rules pre/post-flight runs unchanged.
- **Skill-dispatch only**: every phase runs via the Skill tool so the PreToolUse gates fire; NEVER dispatch a gated phase through the Agent tool.
- **`--manual` flag disables autonomy entirely**; reverts to current per-skill explicit invocation behavior.
- **Legacy rebuild scenarios** REQUIRE `--out=<path>` per AUTONOMY-OQ-7. If invoking on a legacy codebase without `--out`, halt with message asking for explicit destination dir.
- **No persisted state file** per AUTONOMY-OQ-2. `--resume` re-runs CWD inspection; cursor position derives from artifact presence.
- **No `--skip-preflight`** for Hard rules (the pre-flight contract is non-negotiable).

On halt OR pause: chain stops; surface verbatim blocker YAMLs in chat (per `orchestrate-flow/references/handoff-contract.md`). User resolves and re-runs `/mega-sdd --resume`.

On chain completion: emit final summary per `orchestrate-flow/SKILL.md` Step 7 — total phases completed/paused/halted, flat list of all artifacts produced.
