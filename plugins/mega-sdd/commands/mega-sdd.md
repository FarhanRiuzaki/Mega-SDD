---
description: THE mega-sdd front door — any SDD lane phrase routes here. No arg → derive-state status view (position, vault, counts, staleness, foreign-SDD/adoption notices) + propose the next chain with ONE upfront confirmation. With an artifact arg (PRD / legacy dir / vault / brief) → input-shape detection + the adoption lane. Every gated phase stays Skill-dispatched. Legacy /mega-sdd:<command> typed forms no longer register — typed text still routes here or to its skill by phrase.
argument-hint: "[input] [--deep|--shallow] [--greenfield] [--scope=<id>] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual] [--out=<path>] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md] [--converge|--no-converge] [--max-cycles=N] [--with-fsd] [--lean|--full] [--express|--classic] [--advisor|--no-advisor] [--no-telemetry] [--plan|--act|--plan-then-act]"
---

> **The command surface** — four public verbs: `/mega-sdd` (this front door), `/mega-sdd:sync` (reconcile with moved code), `/mega-sdd:emit <prd|fsd|sit|uat>` (the four team documents), `/mega-sdd:slice` (standalone UI slicing from a design reference — command-only, never auto-routed). Everything else is either auto-invoked by the chain, PROPOSED by this front door when state demands it, or reachable by natural-language phrase — the 5.x deprecation aliases were removed (a typed legacy form arrives as plain text and still routes to its skill).

This command THINLY WRAPS the orchestrate-flow machinery — it detects the input shape, renders state, and dispatches; it never duplicates chain logic. **Every gated phase is dispatched via the Skill tool (`mega-sdd:orchestrate-flow` and its sub-skills) — NEVER offloaded to the Agent tool.** The PreToolUse moat gates key on Skill calls; an Agent-tool offload would bypass them (matcher excludes `Agent`), so it is forbidden.

User arguments: $ARGUMENTS

> `--lean` / `--full` — the tranche-E profile switch (opt-in): lean trims the advisor legs (`--no-advisor`, recorded as `advisor: skipped`) + the advisory chain diagnostics; persistent form `profile: lean` in `.mega-sdd/config.yaml` (also governs the Stop-hook analyze aggregate — the flag alone does not). Never touches any gate. → orchestrate-flow SKILL §Auto-integrated diagnostics.

## Lane 0 — no argument: status view + next-chain proposal

When `<input>` is empty:

1. `Run: scripts/ground.sh --cwd=<root>` — the GROUND step (P2): `derive-state.sh` (probes incl. the manifest→pack matcher, spine, symbol-index freshness) + `build-symbol-index.sh` (seconds, zero model tokens; an absent ast-grep is recorded honestly — bind `--express` then falls back to the standard lane). Pre-init CWDs: run `scripts/derive-state.sh --cwd=<root> --json-only` alone and read stdout. Then read `.mega-sdd/state.json`.
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
     - YES → existing vault. Propose chain starting with `bind-codebase` (express default — no map needed; classic with no codebase-map at `.mega-sdd/codebase/codebase-map.md` or legacy `codebase-map.md` → start with `scan-codebase`) or `generate-units` (if bound-vault exists).
   - Otherwise → halt; ask user to clarify directory purpose.

2. **Is `<input>` a path to a file?**
   - Extension `.{md,pdf,docx,txt}` → likely PRD. Propose chain starting with `generate-intent <input>` (Mode A).
   - Extension `.json` with vault schema → vault file directly. Propose chain starting with `bind-codebase`.
   - **Other extension / unrecognized shape → the adoption lane (P2), no more dead end.** `Run: scripts/certify-artifact.sh --cwd=<root> --rung=prd --path=<input>` (the shape sniffer — classifies only, gates nothing downstream) and surface its keterangan verbatim (it explains WHAT was detected: PRD-shaped / arbitrary text / source-code-looking / binary):
     - `CERTIFIED` → proceed `generate-intent <input>` (Mode A).
     - `CERTIFIED_DEGRADED` → proceed `generate-intent <input>`, keterangan already warns the vault will be OQ-heavy and offers Mode B (`--from-prompt`) as the alternative.
     - `DEMOTE` → C2 halt `adoption_demote_confirm` (ALWAYS confirmed under `--auto` — keterangan first, ONE AskUserQuestion `RE_INGEST`/`MANUAL_FIX`/`CANCEL`, then proceed per the answer).
     - `REJECTED` (binary/non-text) → halt with the certify keterangan verbatim; ask for a text document or the file's intent.

3. **Is `<input>` quoted free-text** (e.g., `"build a clinic appointment system"`)?
   - YES, and NO vault exists in CWD → Mode B brief. Propose chain starting with `generate-intent --from-prompt <input>` (greenfield brief — unchanged).
   - YES, and a vault EXISTS whose docs own an entity/flow/screen the sentence names (prompt-scale ownership signal: heading/entity match against the vault's `00-index.md` roll-up) → **delta lane**: propose chain `diff-vault --from-prompt <input>` → claim-scoped re-bind (`--paths=@<vault>/.delta-changed-paths.txt`) → `generate-units --reconcile` → `execute-bolts` (stale/new). An epic-scale brief is forced out by the `delta_too_large` cap inside diff-vault.
   - YES, vault(s) present but ownership UNSURE (nothing matches, or several vaults match) → ASK, one `AskUserQuestion` with keterangan per option: `Delta ke vault <name>` — perubahan kecil di vault existing (delta lane); `Epic baru` — vault baru via generate-intent (Mode B); `Batal` — tidak ada yang dijalankan.

4. **Flag handling**:
   - `--deep` (default true; opt-out via `--shallow` to revert to 3-skill cap).
   - `--greenfield` — EXPLICIT opt-in for stack-agnostic vault generation. REQUIRED when CWD has no framework manifest (package.json / composer.json / Gemfile / pyproject.toml / go.mod / Cargo.toml). Without this flag AND no manifest detected → halt `no_starterkit_detected`.
   - `--step-after=<phase>` — review checkpoint: **renders to orchestrate-flow as `--to=<phase>`** (orchestrate-flow has NO `--step-after` flag — forwarding it verbatim is silently ignored and `--deep` runs to pipeline end). After the review, continue with `/mega-sdd --resume` WITHOUT `--auto` (manual per-phase handoffs) or `--from=<next-phase>` to resume auto.
   - `--stop-after=<phase>` — alias of the same render: **renders as `--to=<phase>`** (halt after that phase even with no blocker).
   - **Translation law:** a front-door flag that is not in orchestrate-flow's §Flags list MUST be translated at render time, never forwarded verbatim — an unknown flag is silently dropped by the router, which for chain-bounding flags means the chain does NOT stop where the user asked.
   - `--advisor` / `--no-advisor` — forwarded VERBATIM (orchestrate-flow routes them to the bind hop; `--advisor` forces the scope-gated advisor pass, `--no-advisor` skips it — see bind-codebase Step 2.12).
   - `--express` / `--classic` — forwarded VERBATIM (orchestrate-flow owns them). **Express is the DEFAULT spine (P2):** chains render without a scan phase (GROUND ran as a script at Lane step 1) and bind hops retrieve claim-scoped (script-derived claims ledger + model completeness sweep of the vault docs + symbol-index queries + targeted Reads, zero codebase-map load) with an honest fallback to the standard lane when the index/ledger is unavailable. `--classic` (or persistent `spine: classic` in `.mega-sdd/config.yaml`) restores the scan-first chains verbatim. No gate changes on either spine; verdict grammar identical.
   - `--converge` / `--no-converge` / `--max-cycles=N` — forwarded VERBATIM (orchestrate-flow owns them; convergence is default ON under `--deep`). Note the interaction with review checkpoints: `bind_conflict` is cycle-eligible, so a converging `--deep` chain auto-invokes `resolve-oq --binding` INSIDE the bind phase — `--to=bind-codebase` alone does not prevent that; reviewing CONFLICTs yourself requires `--no-converge`.
   - `--resume` — re-enter a paused/halted chain; CWD inspection (a fresh `derive-state.sh` digest) rebuilds cursor; halts re-fire if blockers unresolved.
   - `--manual` — disable autonomy entirely; **renders as omitting `--auto` AND not entering the auto-continue loop**: dispatch ONLY the next phase, then stop and print the follow-up command (each skill's chat hint replaces auto-continue; `--deep` under `--manual` widens the PROPOSED chain, not the auto-run).
   - `--out=<path>` — REQUIRED when starting phase is `extract-intelligence` (legacy rebuild scenario). Specifies the OUTPUT_ROOT (parent dir), default `.mega-sdd/`; the KB is written to `<out>/knowledge-base/`.

## Starterkit detection

Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield" — starterkit is REQUIRED by default. Three modes: **A — starterkit-first** (manifest + pack match via the GROUND matcher, DEFAULT), **B — framework-detected** (manifest but `derived.framework_pack: _universal`), **C — greenfield** (EXPLICIT `--greenfield`, or empty CWD + user confirms via the halt). The per-mode, per-spine chain orderings are owned by `orchestrate-flow/references/chain-execution.md` §Starterkit detection + mode classification (single owner — this front door adds no rows); the state-based chain proposals live in `routing-rules.md` §Decision matrix.

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

The chain transparently invokes diagnostic skills at appropriate phases — the user does NOT need to run them separately. The phase table (what auto-runs where, including the scoped lint pass, the wave-plan step, and the emit proposals/mentions with their keterangan lines) is owned by `orchestrate-flow/references/chain-execution.md` §Auto-integrated diagnostics (single owner — this front door adds no rows).

**Opt-out per diagnostic**: `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags available for debugging or non-standard workflows.

**Opt-in only:**
- `--with-fsd` — OPT-IN auto FSD generation at chain end (default: off; pandoc + Chrome md2pdf render; user can invoke `/mega-sdd:emit fsd` manually for one-off)
- `--no-fsd` — legacy alias / no-op (FSD is opt-in via `--with-fsd`)
- `--no-telemetry` — suppress telemetry.jsonl writes for this chain. Persistent opt-out via `defaults.telemetry: false` in `<project>/.mega-sdd/config.yaml`. Read schema: `plugins/mega-sdd/references/telemetry-schema.md`
- `--plan` — Plan mode FIRST. Plan mode is non-destructive: skill body reasons + emits proposed actions but performs no writes. User reviews + transitions to Act via the `--act` flag (`/mega-sdd --act`).
- `--act` — direct Act mode (the default). Used in the Plan-then-Act transition.
- `--plan-then-act` — explicit two-phase: Plan first, halt, then Act on continuation. (Gating is flag-driven — the automatic iter classifier is PARKED.)

## Convergence loops

In `--deep` mode, eligible halts auto-loop up to `--max-cycles` instead of stopping on first halt. The mechanics, the cycle-eligible list, the always-stop classification (canonical classes: `references/halt-protocol.md`, names-only mirror: `orchestrate-flow/references/halt-taxonomy.md`), the cap default, and the per-cycle chat output are owned by `orchestrate-flow/references/convergence-loops.md` (single owner — this front door adds no rows and no numbers). Opt-out: `--no-converge` (stop on any halt); the `--to=<phase>` interaction is in §Flag handling above.

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
