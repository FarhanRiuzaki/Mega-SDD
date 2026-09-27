---
description: THE mega-sdd front door — any SDD lane phrase routes here. No arg → derive-state status view (position, vault, counts, staleness, foreign-SDD/adoption notices) + propose the next chain with ONE upfront confirmation. With an artifact arg (PRD / legacy dir / vault / brief) → input-shape detection + the adoption lane. Every gated phase stays Skill-dispatched. Legacy /mega-sdd:<command> typed forms no longer register — typed text still routes here or to its skill by phrase. Triggers — "from this prompt", "from a brief", "init mega-sdd", "scan codebase", "map this repo", "siapkan context codebase", "bind vault to code", "validate vault against repo", "cek vault vs codebase", "binding gate", or paraphrases.
argument-hint: "[input] [--direct|--assisted|--guarded] [--weight=S|M|L] [--deep|--shallow] [--greenfield] [--scope=<id>] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual] [--out=<path>] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md] [--converge|--no-converge] [--max-cycles=N] [--with-fsd] [--lean|--full] [--express] [--plan|--act|--plan-then-act] [--lite] [--model-tier=<tier>|<role>:<tier>] [--no-escalate]"
---

> **The command surface** — three public verbs: `/mega-sdd` (this front door), `/mega-sdd:sync` (reconcile with moved code), `/mega-sdd:emit <prd|fsd|sit|uat>` (the four team documents). Everything else is either auto-invoked by the chain, PROPOSED by this front door when state demands it, or reachable by natural-language phrase — there are no deprecation aliases (a typed legacy form arrives as plain text and still routes to its skill).

This command THINLY WRAPS the orchestrate-flow machinery — it detects the input shape, renders state, and dispatches; it never duplicates chain logic. **Every gated phase is dispatched via the Skill tool (`mega-sdd:orchestrate-flow` and its sub-skills) — NEVER offloaded to the Agent tool.** The PreToolUse moat gates key on Skill calls; the matcher includes `Agent` but gates ONLY a `bolt-implementer` dispatch (as execute-bolts, in-run semantics) — every other Agent-tool offload of a gated phase is ungated by design, so it is forbidden.

User arguments: $ARGUMENTS

> `--weight=S|M|L` — the task-weight override (the anchor's S/M/L table decides by default; this flag is the user's escape hatch and always wins). `--weight=S`: do NOT run Lane 0/1 — answer the request inline as plain Claude Code, zero mega-sdd scripts (for when a small question arrived via `/mega-sdd` anyway). `--weight=M`: force the delta lane (Lane 1 step 3) even if the ownership match is weak. `--weight=L`: force the full chain. No other alias exists for this flag.
>
> `--lean` / `--full` — the tranche-E profile switch (opt-in): lean trims the advisory chain diagnostics; persistent form `profile: lean` in `.mega-sdd/config.yaml` (also governs the Stop-hook analyze aggregate — the flag alone does not). Never touches any gate. → orchestrate-flow SKILL.md Step 7 + `orchestrate-flow/references/chain-execution.md` §Auto-integrated diagnostics.

## Lane 0 — no argument: status view + next-chain proposal

When `<input>` is empty:

1. `Run: scripts/ground.sh --cwd=<root>` — the GROUND step: `derive-state.sh` (probes incl. the manifest→pack matcher, symbol-index freshness) + `build-symbol-index.sh` (seconds, zero model tokens; an absent ast-grep is recorded honestly — the JIT bind (`write-unit-binding.sh`) then verdicts symbol claims `OQ` with the reason, never `CONFIRMED`; propose `/mega-sdd:install-deps`). Pre-init CWDs: run `scripts/derive-state.sh --cwd=<root> --json-only` alone and read stdout. Then read `.mega-sdd/state.json`.
2. Render the **status view** from the digest — compact, Indonesian narrative + English technical terms:
   - **Position** — `derived.position` + `derived.mode_inferred` + starterkit mode.
   - **Vault(s)** — per vault: docs present, units count, bolts count, OQ P0/P1 open, binding state (CONFIRMED/CONFLICT/OQ counts), drift-report / PENDING-SYNC presence.
   - **Staleness** — `change_signal` (symbol-index `head_commit` vs HEAD, dirty-journal rows). Change signal present → surface it and prefer proposing `/mega-sdd:sync`.
   - **Foreign-SDD / adoption** — `probes.foreign_sdd` non-empty → name the detected tool(s) (spec-kit / Kiro / OpenSpec / generic specs) and propose the adoption lane (certify + ingest), never silent.
   - **Maintenance notices (auto-PROPOSED, never auto-run)** — when state demands, propose the matching maintenance one-timer with one keterangan line each: legacy scattered layout detected → `/mega-sdd:migrate-paths`; a layout-2 (classic-born) vault to build or sync on → `/mega-sdd:migrate-paths --vault-layout=3` (then the mandatory full JIT re-bind); missing native deps limiting a proposed phase → `/mega-sdd:install-deps`.
3. Propose the next chain from `derived.proposed_next` and confirm ONCE (the same upfront-confirmation contract as orchestrate-flow — Run / Edit / Cancel covering ALL phases including execute-bolts), then invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` (+ user flags). No fixed starting phase; the digest decides.

## Intent phrases — checked before Lane 1

The description's trigger phrases name an intent, not an input: route them by that intent and never hand the phrase itself to `route-lane.sh --text` as a brief.
- **Codebase context** ("scan codebase", "map this repo", "siapkan context codebase", "init mega-sdd") → Lane 0: GROUND (state digest + symbol index) is the codebase context; no `codebase-map.md` is produced. A phrase naming a concrete task ("scan codebase for hardcoded secrets") is that task — weigh it S/M/L, not Lane 0.
- **Bind** ("bind vault to code", "validate vault against repo", "cek vault vs codebase", "binding gate") → binding is per unit (`write-unit-binding.sh`), so the whole-vault bind is the re-bind audit: layout-3 vault with units → propose `/mega-sdd:sync --full-bind` (`rebind-units.sh --units=all` + the CONFLICT gate; nothing dispatched, every open CONFLICT still blocks); layout-3 without units → `plan <prd> --lite --regenerate` first (no unit, no claim to bind); layout-2 → `/mega-sdd:migrate-paths --vault-layout=3` first (then the mandatory full JIT re-bind); no vault → say so in one line, then Lane 0. ONE confirmation, as in Lane 0.
- **Brief** ("from this prompt", "from a brief") → the brief text is the input: Lane 1 Step 0 (`route-lane.sh --text`), then rule 3 when `guarded`. `plan` takes no brief, only the seed PRD rule 3 writes. No brief text given → ask for it in one line; nothing runs.

## Lane 1 — with an artifact argument: input-shape detection

**Step 0 — pick the lane FIRST (a PRD/brief file or quoted free text; a directory or a vault `.json` skips this step).** `Run: bash "${CLAUDE_PLUGIN_ROOT}/scripts/route-lane.sh" --cwd=<root> (--prd=<file> | --text="<brief>") [--lane=<forced>]` — read-only, zero model tokens, prints `{lane, signals_fired, evidence}`. `--direct` / `--assisted` / `--guarded` force the lane (`--lane=`); `--lite`, `--weight=L` and every pipeline-only flag (`--greenfield`, `--scope`, `--step-after`, `--stop-after`, `--resume`, `--express`) imply `--guarded`.
- `direct` / `assisted` → follow `plugins/mega-sdd/references/direct-lane.md` and STOP here: no GROUND, no orchestrate-flow, no confirmation prompt, no `.mega-sdd/` writes. The run is done only when `scripts/delivery-check.sh` prints `VERDICT: PASS` on the last commit. (Measured on greenfield PRDs: the pipeline cost 9–22× vanilla Claude Code with equal or lower quality — the pipeline is kept for what it can check.)
- `guarded` (vault exists, or forced) → the input-shape rules below (the one spec pipeline: `plan` → `execute-bolts --all --lite` → `delivery-check.sh`).

Argument parsing (input detection rules, per spec `2026-05-20-autonomy-layer-design.md` §4 Pillar 4):

1. **Is `<input>` a path to a directory?**
   - Is it an `extract-intelligence` knowledge base (`README.md` + `census.json` / `modules/*.prd.md`, or the legacy numbered tree `00-overview/` … — `skills/plan/references/kb-input.md` §Grammar detection)?
     - YES → legacy rebuild from a KB. Propose chain `plan --kb=<input> --lite --mode=<existing|new>` → `execute-bolts --all --lite` (the bolts hop only when a target scaffold exists).
   - Does it contain code files (`.{js,ts,php,py,rs,go,java,…}`) but NO vault at any of these paths: `.mega-sdd/vaults/*/vault.json` (canonical), `docs/mega-sdd/vaults/*/vault.json` (legacy), `vaults/*/vault.json` (oldest legacy)?
     - YES → legacy codebase. Propose chain `extract-intelligence <input> --out=<path>` → `plan --kb=<out>/knowledge-base/ --lite --mode=<existing|new>` → `execute-bolts --all --lite` (REQUIRES `--out=<path>` per AUTONOMY-OQ-7 — conflating extract output with rebuild project dir is dangerous; `--out` is the OUTPUT_ROOT / parent dir, default `--out=.mega-sdd/` → KB at `<out>/knowledge-base/`; the bolts hop only when a target scaffold exists — `derived.proposed_next` decides).
   - Does it contain a vault at any of these paths (priority order): `.mega-sdd/vaults/*/vault.json` (canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy)?
     - YES → existing vault. Propose `derived.proposed_next`: layout-3 with units → `execute-bolts --all --lite` (JIT bind per unit at pre-flight 3.9; the CONFLICT gate closes a unit at dispatch); layout-3 without units → `plan <prd> --lite --regenerate`; layout-2 (classic-born — no `context.md`) → propose `/mega-sdd:migrate-paths --vault-layout=3` first (then the mandatory full JIT re-bind), never run it silently.
   - Otherwise → halt; ask user to clarify directory purpose.

2. **Is `<input>` a path to a file?**
   - Extension `.{md,pdf,docx,txt}` → likely PRD. **2-hop chain:** the engine's `derived.proposed_next` renders `plan <input> --lite --mode=<existing|new>` → `execute-bolts --all --lite` (JIT bind runs at dispatch); ONE confirmation covers both hops; `plan` emits NO handoff YAML — after it returns, re-run `derive-state.sh` and `validate-preflight.sh --predictive --cwd=<root> --chain=execute-bolts` (units present + coverage PASS), then dispatch bolts.
   - Extension `.json` with vault schema → vault file directly. Same rule as a vault directory (layout-3 → `derived.proposed_next`; layout-2 → propose `/mega-sdd:migrate-paths --vault-layout=3` first).
   - **Other extension / unrecognized shape → the adoption lane, no more dead end.** `Run: scripts/certify-artifact.sh --cwd=<root> --rung=prd --path=<input>` (the shape sniffer — classifies only, gates nothing downstream) and surface its keterangan verbatim (it explains WHAT was detected: PRD-shaped / arbitrary text / source-code-looking / binary):
     - `CERTIFIED` → proceed `plan <input> --lite --mode=<existing|new>` → `execute-bolts --all --lite`.
     - `CERTIFIED_DEGRADED` → proceed `plan <input> --lite --mode=<existing|new>`, keterangan already warns the vault will be OQ-heavy; the alternative to offer is the direct/assisted lane (`route-lane.sh --text`).
     - `DEMOTE` → C2 halt `adoption_demote_confirm` (ALWAYS confirmed under `--auto` — keterangan first, ONE AskUserQuestion `RE_INGEST`/`MANUAL_FIX`/`CANCEL`, then proceed per the answer).
     - `REJECTED` (binary/non-text) → halt with the certify keterangan verbatim; ask for a text document or the file's intent.

3. **Is `<input>` quoted free-text** (e.g., `"build a clinic appointment system"`)?
   - YES, and NO vault exists in CWD → reached only when `guarded` was forced (Step 0 sends every other brief to direct/assisted). Write the brief to a seed PRD per `skills/plan/references/brief-input.md` (cap 0 — no pre-plan Q&A; every topic the brief leaves open becomes an OQ that `plan` asks ONCE in its batched ask), then propose `plan <OUTPUT_DIR>/source/seed-PRD.md --vault=<OUTPUT_DIR> --lite --mode=<existing|new>` → `execute-bolts --all --lite`.
   - YES, and a vault EXISTS whose index owns an entity/flow/screen the sentence names — the tier-M ownership check is MECHANICAL, not felt: grep the sentence's nouns against each vault's `vault.json` (`entities[].name`, `flows[].title`, module names — the machine index; never a vault md file) → exactly ONE vault matches → **delta lane (tier M)**: propose chain `diff-vault --from-prompt <input>` → `scripts/rebind-units.sh --cwd=<root> --vault=<vault> --paths=@<vault>/.delta-changed-paths.txt` → `plan --reconcile` → `execute-bolts --all --lite` (stale units; `plan --reconcile` never adds a unit — a delta that needs a new one re-plans via `plan --regenerate`). An epic-scale brief is forced out by the `delta_too_large` cap inside diff-vault.
   - YES, vault(s) present but NOTHING matches the vault.json index → **drop to tier S**: answer the request inline as plain Claude Code and end with the one-line offer (`mau masuk pipeline? → /mega-sdd "<brief>" --weight=M`) — do NOT interrogate with AskUserQuestion for a no-match.
   - YES, and SEVERAL vaults match (ownership genuinely ambiguous) → ASK, one `AskUserQuestion` with keterangan per option: `Delta ke vault <name>` — perubahan kecil di vault existing (delta lane); `Epic baru` — brief ditulis ke file (seed PRD) lalu `plan <file> --lite` (guarded), atau lane direct/assisted; `Batal` — tidak ada yang dijalankan.

4. **Flag handling**:
   - `--deep` (default true; opt-out via `--shallow` to revert to 3-skill cap).
   - `--greenfield` — EXPLICIT opt-in for stack-agnostic vault generation. REQUIRED when CWD has no framework manifest (package.json / composer.json / Gemfile / pyproject.toml / go.mod / Cargo.toml). Without this flag AND no manifest detected → halt `no_starterkit_detected`.
   - `--step-after=<phase>` — review checkpoint: **renders to orchestrate-flow as `--to=<phase>`** (orchestrate-flow has NO `--step-after` flag — forwarding it verbatim is silently ignored and `--deep` runs to pipeline end). After the review, continue with `/mega-sdd --resume` WITHOUT `--auto` (manual per-phase handoffs) or `--from=<next-phase>` to resume auto.
   - `--stop-after=<phase>` — alias of the same render: **renders as `--to=<phase>`** (halt after that phase even with no blocker).
   - **Translation law:** a front-door flag that is not in orchestrate-flow's §Flags list MUST be translated at render time, never forwarded verbatim — an unknown flag is silently dropped by the router, which for chain-bounding flags means the chain does NOT stop where the user asked.
   - `--model-tier=inherit|auto|haiku|sonnet|opus` / `--no-escalate` — forwarded VERBATIM to the `execute-bolts` hop (per-unit implementer routing + cascade; execute-bolts §Flags owns the semantics; config default `model_tiers.bolt_implementer: inherit` = today's behavior).
   - `--express` — accepted; it selects no spine (express is the only one: chains carry no scan phase — GROUND is a script). Binding is per unit at `execute-bolts` pre-flight 3.9 (`derive-unit-claims.sh` → `write-unit-binding.sh` → `validate-handoff-binding-units.sh`); there is no bind hop and no standard-lane fallback; verdict grammar unchanged.
   - `--classic` / `spine: classic` / `lane: standard` (config) — retired in 9.0: say so in ONE line, ignore it (it forces no lane) and carry on with the one pipeline — no scan-first spine and no classic chain exist.
   - `--converge` / `--no-converge` / `--max-cycles=N` — forwarded VERBATIM (orchestrate-flow owns them; convergence is default ON under `--deep`). `binding_conflict` is cycle-eligible, so a converging `--deep` chain auto-invokes `resolve-oq --binding` inside `execute-bolts` — reviewing CONFLICTs yourself requires `--no-converge`.
   - `--resume` — re-enter a paused/halted chain; CWD inspection (a fresh `derive-state.sh` digest) rebuilds cursor; halts re-fire if blockers unresolved.
   - `--manual` — disable autonomy entirely; **renders as omitting `--auto` AND not entering the auto-continue loop**: dispatch ONLY the next phase, then stop and print the follow-up command (each skill's chat hint replaces auto-continue; `--deep` under `--manual` widens the PROPOSED chain, not the auto-run).
   - `--out=<path>` — REQUIRED when starting phase is `extract-intelligence` (legacy rebuild scenario). Specifies the OUTPUT_ROOT (parent dir), default `.mega-sdd/`; the KB is written to `<out>/knowledge-base/`.

## Starterkit detection

Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield" — starterkit is REQUIRED by default. Three modes: **A — starterkit-first** (manifest + pack match via the GROUND matcher, DEFAULT), **B — framework-detected** (manifest but `derived.framework_pack: _universal`), **C — greenfield** (EXPLICIT `--greenfield`, or empty CWD + user confirms via the halt). The per-mode chain orderings are owned by `orchestrate-flow/references/chain-execution.md` §Starterkit detection + mode classification (single owner — this front door adds no rows); the state-based chain proposals live in `orchestrate-flow/references/routing-rules.md` §Decision matrix.

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

A PRD without a `scopes:` block is single-scope: no picker, no retrofit subagent — `plan` records `scope_inferred: single` and adds one delivery-report line offering the manual retrofit (`skills/plan/references/scope-flow.md` Step 0.9 c).

When an existing vault carries the same PRD sha256 + a scope (vault.json) → silent default with confirm-once UX.

See `tests/scenarios/scenario-7-multi-architect.md` for walkthrough.

## Auto-integrated diagnostics

The chain transparently invokes diagnostic skills at appropriate phases — the user does NOT need to run them separately. The phase table (what auto-runs where, including the scoped lint pass, the wave-plan step, and the emit proposals/mentions with their keterangan lines) is owned by `orchestrate-flow/references/chain-execution.md` §Auto-integrated diagnostics (single owner — this front door adds no rows).

**Opt-out per diagnostic**: `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags available for debugging or non-standard workflows.

**Opt-in only:**
- `--with-fsd` — OPT-IN auto FSD generation at chain end (default: off; pandoc + Chrome md2pdf render; user can invoke `/mega-sdd:emit fsd` manually for one-off)
- `--no-fsd` — legacy alias / no-op (FSD is opt-in via `--with-fsd`)
- `--lite` — opts into the guarded pipeline (same as `--guarded`; spec 2026-09-10 App. F8). **2-hop chain:** with a PRD argument the proposed chain is `plan <prd> --lite --mode=…` → `execute-bolts --all --lite` (state re-derived from disk between the two hops; no handoff YAML). Also: execute-bolts pre-flight 3.9 JIT bind runs for EVERY wave (not only units carrying `## Claims`), the W1 zero-idle behaviors apply (batched ask absorbs L0, DEFER-class halts quarantine, exactly two interaction points on a happy path), **W2 fast lane:** unit-level readiness instead of the wave barrier (`derive-ready-units.sh` after every implementer return), xs fix-round budget 1 → quarantine, xs implementer routed `auto` (→ sonnet, measured cell); and `validate-plan-coverage.sh` must PASS before bolts (`validate-preflight.sh --predictive` refuses the execute-bolts hop on a missing/FAIL coverage state — a script rail, not prose).
- `--plan` — Plan mode FIRST. Plan mode is non-destructive: skill body reasons + emits proposed actions but performs no writes. User reviews + transitions to Act via the `--act` flag (`/mega-sdd --act`).
- `--act` — direct Act mode (the default). Used in the Plan-then-Act transition.
- `--plan-then-act` — explicit two-phase: Plan first, halt, then Act on continuation. (Gating is flag-driven — the automatic iter classifier was REMOVED, never wired.)

## Convergence loops

In `--deep` mode, eligible halts auto-loop up to `--max-cycles` instead of stopping on first halt. The mechanics, the cycle-eligible list, the always-stop classification (canonical classes: `plugins/mega-sdd/references/halt-protocol.md`, names-only mirror: `orchestrate-flow/references/halt-taxonomy.md`), the cap default, and the per-cycle chat output are owned by `orchestrate-flow/references/convergence-loops.md` (single owner — this front door adds no rows and no numbers). Opt-out: `--no-converge` (stop on any halt); the CONFLICT-review interaction is in §Flag handling above.

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

On chain completion: emit final summary per `orchestrate-flow/SKILL.md` Step 8 (Emit final summary) — total phases completed/paused/halted, flat list of all artifacts produced — ending with the result contract every lane delivers: an acceptance-criterion → test table; `delivery-check.sh` `VERDICT: PASS` on the final commit; the list of assumptions and decisions made.
