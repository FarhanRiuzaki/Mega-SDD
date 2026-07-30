# Fork-safety audit — `scan-codebase` + `bind-codebase` (Phase 5a)

**Date:** 2026-07-30 · **Method:** 13-agent workflow — 6 independent dimensions, each
passed through a dedicated adversarial verifier prompted to REFUTE, then synthesized.
1.85M subagent tokens, 380 tool calls, 0 agent errors.

**Question:** can `scan-codebase` and `bind-codebase` safely take `context: fork`
frontmatter? Spec: `docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md`
§Phase 5a. Worth ~2.0M cost-units (11-16% of main-thread cost) if it ships.

## Dimension verdicts (pre-refutation)

| dimension | verdict |
|---|---|
| DIMENSION 1 — scan-codebase interactivity (fork-readiness of every human-stop path) | BLOCKER |
| Dimension 6 — deterministic input resolution (scan-codebase / bind-codebase under `context: fork`) | BLOCKER |
| Dimension 4 — handoff emission under `context: fork` (scan-codebase + bind-codebase) | BLOCKER |
| Dimension 2 — bind-codebase interactivity under `context: fork` | BLOCKER |
| Dimension 5 — gate + moat preservation under `context: fork` (scan-codebase, bind-codebase) | BLOCKER |
| Dimension 3 — conversation-history dependence in scan-codebase and bind-codebase (mega-sdd-trace:fork-audit) | BLOCKER |

> Finder-level severities below were **corrected by the verifiers** — see §3 of the
> synthesis. Do not implement against the raw finder verdicts.

---

# Phase 5a fork audit — GO/NO-GO synthesis

**Trace:** `mega-sdd-trace:fork-audit`
**Path prefix:** `PLUGIN` = `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/mega-sdd-github/plugins/mega-sdd`, `REPO` = `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/mega-sdd-github`. Every path below expands from one of those two.

---

## 1. VERDICT

| | Verdict | Why |
|---|---|---|
| **Both** | **NO-GO today** | Blocked by the project's own contract precondition, independent of every prose edit. `PLUGIN/CLAUDE.md:69`: *"Re-evaluate fork for `scan-codebase` / `bind-codebase` (also non-interactive) **only after** the live token before/after on detect-drift confirms the win — the measurement is scaffolded (`scripts/measure-fork-tokens.sh` + `research/2026-06-26-fork-token-measurement-procedure.md`); **run it before extending**."* Nothing in the six audited dimensions establishes that this ran. `REPO/research/2026-07-20-fork-ab-headless-attempt.md:11` records the only attempt and it FAILED (`context: fork` silently no-ops under `claude -p` — 0 sidechains). CONFIRMED. |
| **scan-codebase** | **GO after a bounded edit set + Precondition 0** — no unresolvable risk | Nothing scan writes feeds a blocking gate. Remaining work is ~7 rule statements across 4 locations, all deterministic prose→blocker conversion, **plus one genuine design decision** (monorepo rail) and **one channel that does not exist** (warnings). No new mechanism required. |
| **bind-codebase** | **NO-GO until the depth-2 probe returns** — one risk the pilot structurally cannot de-risk | Its verdict logic is CLEAN and does not need a single edit. Its edit volume is *smaller* than scan's. But its default-on phase-advisor (`PLUGIN/skills/bind-codebase/SKILL.md:58`) is a moat-**recall** layer, and whether a forked body can dispatch an `Agent` is doc-cited but never exercised — **detect-drift dispatches no subagent at all**, so the live precedent proves nothing about it. |

The two verdicts differ on **risk type**, not edit volume. scan's residue is implementable work. bind's residue includes one thing you cannot read your way out of.

---

## 2. What this audit RETIRES — state these so they are never re-litigated

**The brief's headline hazard cannot happen via a fork.** *"A fork that silently changes where `.validation-blockers.json` lands breaks the gate"* — **REFUTED**, on three independent mechanisms, each verified from primary source by at least two dimensions:

1. bind-codebase **never writes the file**. Sole writer is `PLUGIN/scripts/validate-handoff-binding-units.sh:85` (`BLOCKER_FILE="${CWD}/.mega-sdd/.validation-blockers.json"`), invoked only by hooks with a hook-computed `--cwd=$PROJECT_ROOT` derived from the harness payload, never from anything the skill body says. The only mentions inside the skill are descriptive (`SKILL.md:58`, `references/binding-contract.md:184`).
2. The state is **recomputed unconditionally at the gate before it is read** — `PLUGIN/hooks/pre-tool-use:421-422` runs the validator, `:474-494` then loads and evaluates it (fail-closed on unparseable). The S4 BC-GATE-1 comment at `:407-420` states the intent verbatim.
3. Direct writes are hard-denied: `pre-tool-use:774`/`:804` (Write/Edit), `:924`/`:951` (Bash).

Corollary: **the June "producer-timing race"** (`research/2026-06-26-context-reset-fork-feasibility.md:51`, citing `absent ⇒ allow` at the old `pre-tool-use:370`) is **STALE for the moat**. It survives only for the three advisory validators dispatched on the `*/binding.md` PostToolUse arm (`PLUGIN/hooks/post-tool-use:640-668`), none of which any blocking gate reads.

**bind's CONFLICT verdict path needs ZERO edits.** Verified by two independent adversarial paraphrase sweeps (not a token grep): zero `AskUserQuestion`, zero paraphrased prompts, zero conversation-state reads across `SKILL.md` + all 10 references. The blocked branch writes `binding.md`/`binding.json`, emits the `bind_conflict` halt YAML, and routes to `resolve-oq` with no prompt (`SKILL.md:87-90`); `bound/` production is delegated to `scripts/make-bound.sh`, which **independently refuses** while any CONFLICT exists, so the gate does not rely on model compliance. Tech-OQ recommendations are rendered *into* `binding.md` as a deferred ACCEPT/OVERRIDE/REJECT block (`references/oq-resolution.md:44-46`) — structurally identical to detect-drift's PENDING-SYNC.md queue.
> **Implementation rail: any patch that touches the CONFLICT/OQ decision path (Steps 2–5) while "making it fork-safe" must be rejected on sight.** All fork work is at the input and output boundaries.

**Memory WRITES are already fork-hardened in both skills, independently of detect-drift.** `PLUGIN/skills/scan-codebase/references/halts-flags-handoff.md:155` and `PLUGIN/skills/bind-codebase/references/auto-memory-handoff.md:115` both append via `scripts/memory-write.sh` at emission time; only the *receipt* rides the handoff, and a receipt is derivable. This was detect-drift's #4 fix and it is already done here.

**The sync-lane scope channel was already converted to disk BECAUSE bind was expected to fork.** `PLUGIN/skills/scan-codebase/references/scan-procedure.md:49`: *"the SOLE scope channel for the two forked, non-interactive downstream phases — `detect-drift --scope=@…` and `bind-codebase --paths=@…`"*. The strongest positive evidence in the whole audit.

**Depth-2 sub-dispatch from a fork is doc-cited and permitted.** `research/2026-06-26-context-reset-fork-feasibility.md:22` cites sub-agents.md ~790/796 (depth limit 5; "a fork cannot spawn another fork [but] can spawn other subagent types"), and `:17` explicitly corrects the misreading that two dimensions repeated: *"`CLAUDE.md:57`'s 'no `Agent` tool' governs **plugin agents** in `agents/*.md`, not a `context: fork` skill."* `PLUGIN/agents/phase-advisor.md` is a plain plugin agent (`tools: Read, Grep, Glob`, no `context:` key) — i.e. "another subagent type", the permitted case. **Dimension 2's verifier is right; Dimensions 5 and 6 overstated this as a repo self-contradiction.** But see §4 — doc-cited is not measured.

---

## 3. Claims the verifiers REFUTED that change the answer

These are load-bearing corrections. Do not implement against the finder-level severities.

**R1 — "bind has no blocker for an unresolvable vault" is REFUTED at the layer that enforces.** Four of six dimensions called this a BLOCKER; three proposed the same fix. **Absence is already hook-blocked, deterministically, pre-fork, and more strongly than detect-drift's prose blocker:** `PLUGIN/scripts/validate-preflight.sh:107-110` emits FATAL `binding_input_vault_missing`, and `PLUGIN/hooks/pre-tool-use:314-340` runs that preflight for `mega-sdd:bind-codebase` and calls `emit_block` at `:336` on `status == FATAL` (verified by direct read). The chain also passes the path explicitly: `PLUGIN/skills/orchestrate-flow/references/handoff-contract.md:271` renders `mega-sdd:bind-codebase <vault> --auto`.
**What actually remains is AMBIGUITY, not absence:** >1 vault under `.mega-sdd/vaults/` + no positional + standalone invocation. `has_vault()` passes, and nothing in `SKILL.md` or its 10 refs disambiguates (`SKILL.md:21` is the entire spec: *"Vault path (positional, required)"*). Severity: **FIXABLE, and it must still be fixed before the flip** — see R2 for why.

**R2 — why ambiguity is dangerous rather than untidy** (no finder located this mechanism; it was assembled across two verifiers and I confirmed it by reading the validator). Three properties compose: (a) no `.mega-sdd/vaults/` dir → `{"status":"PASS","reason":"no_vault"}` and exit 0 (`validate-handoff-binding-units.sh:106-119`); (b) the binding globs are **four NON-recursive patterns**, not `**` (`:123-128`); (c) the `binding_missing` fail-closed backstop fires only on `units_paths and unit_conflict_citations and not binding_paths` (`:237-247`), so a **stale** binding.md inside the glob root keeps `binding_paths` non-empty and the backstop never fires. Result: a binding.md written outside `<cwd>/.mega-sdd/vaults/**` is invisible and the gate reads PASS. Pre-existing, **not fork-caused** — `$ARGUMENTS` is byte-identical forked or not — but it is exactly why the Step-0 fix must **constrain resolution to the glob root**, and why the fork test must pin the write location.

**R3 — `derived.vault` is the vault NAME, not the path.** `PLUGIN/scripts/_lib/state_probes.py:645-646`: `"vault": vault["name"]`, `"vault_path": vault["path"]`. **Four separate findings proposed reading `derived.vault` as the resolver.** Shipping that resolves `VAULT_DIR` to a bare slug. The edit list below says `derived.vault_path`.

**R4 — the spec's "one missing `--auto`-policy paragraph another skill already ships verbatim" does not port.** The paragraph exists (`PLUGIN/skills/generate-units/references/pagerank-targeting.md:131-179`) but its safest option costs nothing — the skipped pass is advisory (`:119`) — whereas scan's over-budget item **is the deliverable**. It also forbids scan's cheap out (`:166-171`, regex-tier re-scan mutates `precision_tier`, "bind-codebase anchors included"), which scan's own rail forbids too (`scan-procedure.md:240`). **Phase 5a's scoping line must be amended; this is a design decision, not a copy-paste.**

**R5 — enum registration is over-specification.** `drift_inputs_missing` is **not** in `PLUGIN/references/halt-protocol.md:87`; it lives only in `PLUGIN/skills/detect-drift/references/auto-and-chain.md:31-46` and is pinned there by `tests/drift/test-detect-drift-fork.sh:64-65`. The precedent bar is a **`type:` YAML shape in the skill's own operative reference**, per the precedence rule at `handoff-contract.md:7`. Several findings proposed halt-protocol enum registration — **drop it**.

**R6 — three findings do not survive and should not consume implementation time.** (a) The "fail-STUCK handoff deadlock" is refuted under **both** branches of its own contingency and applies identically to scan, so it cannot support a split verdict. (b) The Stop→SubagentStop rail loss is near-zero: `hooks/stop:115` fires at the end of a *main-thread turn* on the last assistant message, so under `--auto` auto-continue it never covered a mid-chain scan/bind handoff to begin with. (c) The factory-ledger channel is **already unimplemented pre-fork** (`grep factory-ledger` over both skills returns zero); fork cannot regress it.

**R7 — commands/ files are not fork-prompt hazards.** `PLUGIN/commands/scan-codebase.md` and `commands/bind-codebase.md` expand in the **parent**; their operative instruction is "invoke the Skill". Reword for consistency, but do not count them as text the fork executes, and do not build fork-contract assertions on them.

---

## 4. Precondition 0 and the measurement plan — what each run must measure

`CLAUDE.md:69` gates the whole phase. Beyond that, five runtime facts are load-bearing and **none is settled in-repo**. Ranked by evidentiary strength:

| Fact | Status | Does the detect-drift pilot answer it? |
|---|---|---|
| Token win exists | Unmeasured; scaffolded | **YES** — `scripts/measure-fork-tokens.sh` + `research/2026-06-26-fork-token-measurement-procedure.md` |
| Handoff reaches the capture point | Unmeasured, and **already-shipped exposure** | **YES** — detect-drift emits an inline handoff (`detect-drift/references/auto-and-chain.md:71`) |
| CWD inheritance under fork | Assumed everywhere | **YES** — run from a subdirectory |
| PreToolUse fires on the Skill call before the body forks | `research:50` — *"grounded inference, not explicit doc"* | Low value — conclusion is robust either way: the hook fires on `tool_name=Skill` with `SKILL_NAME` regardless of ordering, and the moat is argued from recompute-at-gate, never from this |
| **Depth-2 `Agent` dispatch from a fork** | Doc-cited (`research:22`), **never exercised** | **NO — detect-drift dispatches no subagent at all** (grep over `skills/detect-drift/` returns none) |

**RUN 1 — the pilot (interactive session; headless no-ops fork per `CLAUDE.md:69`).** One `/mega-sdd:sync` on a Mode-D brownfield repo, invoked from a **sub-directory** of the project. Measure exactly:
1. **Token before/after** per the scaffolded procedure — this is Precondition 0 itself.
2. **Handoff survival** — does the forked detect-drift's handoff block reach the orchestrator's capture point (`PLUGIN/skills/orchestrate-flow/references/handoff-consumption.md:27`, *"the last assistant message"*), i.e. does the chain actually continue to `bind-codebase --paths`? Also check whether `.mega-sdd/.handoff-validation-state.json` advances (`hooks/stop:154-175`).
3. **CWD inheritance** — do `DRIFT-REPORT.md` / `PENDING-SYNC.md` land at the canonical root, not under the sub-directory?

**RUN 2 — the depth-2 probe (separate; the pilot cannot cover it).** In an interactive session, invoke a `context: fork` skill whose body attempts exactly one `Agent` dispatch, and observe whether the tool is available. This gates bind specifically and also determines whether scan's default-on 5-way deep-scan stage (`scan-codebase/SKILL.md:60-67`) survives a fork at all.

**Do not treat RUN 1 as clearance for RUN 2's question.**

---

## 5. EXACT ORDERED EDIT LIST

Ordered for implementation. Frontmatter flips are **last** in each group.

### Group A — spec (do first; it records the decisions the rest depend on)

**A1.** `REPO/docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md` (~lines 199-201). Replace the Phase 5a scoping line. Per **R4**, "one missing `--auto`-policy paragraph another skill already ships verbatim" is wrong. Record, with citations: (i) the real scan work is 4 prompts + 1 behavior table + 1 warnings channel + 1 unconditional handoff; (ii) the real bind work is Step 0 + one reattribution + one declaration; (iii) the two CLEAN results from §2 above (moat is fork-immune via recompute-at-gate; bind Steps 2–5 are untouchable); (iv) `research/2026-06-26-context-reset-fork-feasibility.md:15,17,22,40` as the depth-2 citation so it is not re-litigated; (v) Precondition 0 + RUN 1 / RUN 2 as ship gates.

**A2.** Same file — **make the two design decisions explicitly** (they cannot be inferred from any rail):
- **Spawn-cost gate policy.** Choose (A) named `scan_spawn_budget_exceeded` blocker when over budget with no explicit `--engine=`/`--include=` (both flags already exist, `halts-flags-handoff.md:84,86` — no new surface, detect-drift-shaped), or (B) a **LOUD recorded** downgrade to regex stamping `precision_tier: regex` + a downgrade reason in both the map frontmatter and the handoff. (B) is more available than it looks: `pagerank-targeting.md:141` states the governing distinction — *"The `--auto` skip is not a SILENT skip — 'silently' is about the record, not the action"* — and scan is the **producer** of `precision_tier`, not a consumer mutating upstream state. **If (B), that reconciliation with `scan-procedure.md:240` must be written down, not assumed.** Recommendation: **(A)** — smaller, reversible, no rail reconciliation needed.
- **Monorepo rail.** Three shapes, pick one: **(A)** named `scan_primary_app_ambiguous` blocker + a new `--app=` (or reuse `--include=`) **threaded through the orchestrate-flow routing rows** — mandatory, because two independent greps found **ZERO** rows carrying `--include`/`--engine`/`--force-large` across `skills/orchestrate-flow/`, and scan is phase 1 of nearly every brownfield chain (`routing-rules.md:68,69,82,84,92,94,148,149,151,153,154,155`), so a blocker without pre-resolution converts a one-time question into a phase-1 chain halt for every monorepo user. This threading is precisely what makes detect-drift's blocker acceptable (`handoff-contract.md:271` pre-resolves its inputs). **(B)** a deterministic precedence rule (explicit `--include` > root manifest > single app-root manifest), blocker only on residual ambiguity. **(C)** scan-all-app-roots + stamp `primary_app: unresolved` — already the pre-rail default (`scan-procedure.md:87`, `SKILL.md` step 2 *"Multiple → record all"*), but it would require bind to honor a flag that does not exist, i.e. a new contract on the moat keystone. Recommendation: **(B) with an (A) fallback** — least chain disruption, and the blocker only fires on genuine ambiguity.
- **Warnings channel.** scan's handoff schema carries `blockers[]` only, and `pagerank-targeting.md:159` forbids inventing a warnings key. Decide: route the ~8 warn sites to disk (detect-drift's PENDING-SYNC.md move) or accept the loss in writing. **At minimum the security one must be routed** — `scan-procedure.md:451`: *"Findings present → emit one chat warning listing the affected source `file:line` rows … so the user can rotate/relocate the credential"*. The map gets `[REDACTED-SECRET]`; the live credential's location exists **only in chat** and would be swallowed by the fork.

### Group B — scan-codebase (`PLUGIN/skills/scan-codebase/`)

**B1.** `SKILL.md` — insert the non-interactive declaration immediately under the title, in the shape of `PLUGIN/skills/detect-drift/SKILL.md:10`: forked + non-interactive; NEVER calls `AskUserQuestion` on any path; inputs resolve from `$ARGUMENTS`/CWD; unresolvable required input → blocker, never a prompt; **the former `--auto` behavior is now the only behavior**. *Why:* under fork the body IS the subagent prompt, and the fork inherits the **user project's** CLAUDE.md, not the plugin's — so the fork contract must be stated locally.

**B2.** `SKILL.md:52` — rewrite *"above 60 s, ASK before proceeding"* to the A2-chosen deterministic outcome. **This is the load-bearing edit**: it sits in the always-loaded body, so a fix confined to `scan-procedure.md:234` leaves an unexecutable instruction inside the fork prompt.

**B3.** `SKILL.md:76` — two rules in one line. `>100k files → confirm (--force-large)` becomes a named `scan_repo_too_large` blocker carrying the exact re-run command (`--force-large` already exists at `halts-flags-handoff.md:84`). `0 public interfaces → warn … offer re-run` becomes *"record the suggested re-run command in the scan summary and the handoff, then complete"* — it is not in the `status: halted` list (`halts-flags-handoff.md:143`) and must not read as an instruction to wait.

**B4.** `references/scan-procedure.md:234` — replace the literal `AskUserQuestion` block (the only such token in the skill) with the A2-chosen policy. Keep the three remedies as `next_action` / resolver_route text, never as options awaiting a reply.

**B5.** `references/scan-procedure.md:78` — implement the A2 monorepo decision. Delete *"ask ONCE which app is the PRIMARY scan target"*.

**B6.** `references/halts-flags-handoff.md:27,28,29` — rewrite all three halt rows to match B2/B3/B4, and add `type:` YAML shapes for the new blockers beside the existing ones at `:32-71` (per **R5**: here, not in `halt-protocol.md`). Reuse the existing YAML blocker shapes so the halt taxonomy stays uniform (invariant #4).

**B7.** `references/halts-flags-handoff.md:83` — replace *"`--auto`: skip confirmation prompts"* (suppression with no resolution) with a detect-drift-shaped deterministic-behavior table covering every former prompt, stated as the **only** behavior with `--auto` implied. Template: `detect-drift/references/auto-and-chain.md:16,18-25`.

**B8.** `references/halts-flags-handoff.md:98` and `:143` — remove the `--auto` gate on handoff emission (*"Required ONLY under `--auto`"*). Under unconditional fork frontmatter, a direct `/mega-sdd:scan-codebase` run (`commands/scan-codebase.md:11-14` never injects `--auto`) would emit **no handoff at all** and the main thread would get no `next_action`, no `artifacts[]`, no `blockers[]`.

**B9.** Warnings routing per A2 — minimum: give the secret-scan finding a durable on-disk home (`scan-procedure.md:451`).

**B10.** `references/deep-scan-dispatch.md:90` + `references/deep-scan-prompts.md:336` — the model-tier override arrives via `handoff metadata.model_tiers`, which a fork cannot harvest (`research:24`: *"no separate metadata channel"*). Reword the fallback to name the fork case explicitly: *"a forked or standalone invocation uses the catalog default unconditionally."* Benign degradation, but it must be stated rather than inferred from "standalone".

**B11.** `PLUGIN/commands/scan-codebase.md:20` — reword for cross-surface consistency only (per **R7**, main-thread, already phrased as a halt).

**B12.** If A2 chose monorepo shape (A): thread the new flag through the `skills/orchestrate-flow/references/routing-rules.md` rows that dispatch scan-codebase, so the main thread pre-resolves before the fork.

**B13. LAST** — add `context: fork` to `SKILL.md` frontmatter and bump `version`.

### Group C — bind-codebase (`PLUGIN/skills/bind-codebase/`)

**C1.** `SKILL.md` — insert the same non-interactive declaration under the title (detect-drift `SKILL.md:10` shape), and add the matching rail to §Anti-hallucination rails (`SKILL.md:112-121`) in the shape of `detect-drift/SKILL.md:82`: *"Non-interactive (forked, `context: fork`). NEVER calls `AskUserQuestion` and never prompts; conflict resolution belongs to `resolve-oq`, not bind."* **Put it in SKILL.md, not the command file** — the fork never sees the command file.

**C2.** `SKILL.md` §Inputs — add a deterministic Step 0 modeled on `detect-drift/SKILL.md:47-52`. Resolution order: (1) `--vault=<path>` / first positional; (2) `bash scripts/derive-state.sh --cwd=<root> --json-only` → **`derived.vault_path`** (per **R3** — NOT `derived.vault`, which is the name); (3) CWD probe for a directory holding all 7 vault files. **Ambiguity (>1 candidate) → emit `bind_inputs_missing` with `details.reason: vault_ambiguous` + the candidate list — never `vaults[0]`, never a prompt, never a guess.** `state_probes.py:614-617` (`_primary_vault` returns `vaults[0]`) is acceptable for a status digest and **not** for the moat keystone's input. **Additionally constrain the resolved path to `<cwd>/.mega-sdd/vaults/`** — per **R2** that is the glob root the gate scans, and it is the single path by which a fork could blind the gate.

**C3.** `references/auto-memory-handoff.md` — define `type: bind_inputs_missing` with a YAML shape beside the existing halts (per **R5**, operative reference, not the enum). Discriminator `details.missing: vault | vault_ambiguous | codebase_map | vault_index`.

**C4.** `references/conflict-resolution.md:46` — **the single genuine in-fork interactivity instruction in the skill.** It reads *"Action: bind-codebase prompts user to confirm; vault is patched in place"*, it is stale attribution (`references/binding-contract.md:194` shows resolve-oq's walker owns the prompt and the patch), and `SKILL.md:90` routes to this file on the `conflict > 0` branch. Today it has a compliant reading (bind prompts, the user chooses, satisfying `:62`'s *"without user choice"*). **Under unconditional fork there is no compliant branch left** — the only way to follow it is to patch without the confirm, which `:62` forbids. Reattribute to resolve-oq and state that bind never prompts and never patches the vault; it re-derives verdicts on the next re-bind.

**C5.** `SKILL.md:125` — the three prose-only halts have no machine-readable shape (verified: the only `type:` YAML in the whole bind ref set is `bind_conflict_constitution_violation` at `references/constitution-and-oq.md:18`). Fold missing-`codebase-map` and malformed-vault into `bind_inputs_missing` via the `details.missing` discriminator; make `claims_total == 0` a `status: completed` + explicit skip note (it is the greenfield path, not an error, and must not read as a silent no-op).

**C6.** `references/auto-memory-handoff.md:117` — name the fork case in the memory-read fallback. Cheap NIT (the three pointed paths are canonical and named in the same sentence, and `:119` confirms memory never bypasses a CONFLICT), but align it with `orchestrate-flow/references/memory-layer.md:31`, which already says *"or any forked skill (no conversation history)"*.

**C7.** `SKILL.md` — add an Instruction-language block after the Announce line, copying `scan-codebase/SKILL.md:13`'s wording and reason clause. bind is the only fork candidate without one, it emits Indonesian keterangan (`SKILL.md:33`, `:80-85`), and a fork does not receive the SessionStart anchor (`PLUGIN/hooks/session-start:123`). *Note: `detect-drift/SKILL.md:14` is **not** the precedent here — it carries a block but does not restate the narration default; the precedents are scan-codebase, install-deps, orchestrate-flow.*

**C8.** Contingent on RUN 2. If a fork **cannot** dispatch `Agent`: do **not** ship a fork whose fallback is a permanent `--no-advisor` — that is a silent moat-recall downgrade. Either do not fork bind, or hoist Step 2.12 out of the forked body (caller dispatches phase-advisor on the main thread against the on-disk `<vault>/.advisor-bundle.md`, then re-enters for materialization). Independently, consider promoting `advisor: unavailable` to `status: paused` in `references/auto-memory-handoff.md:109` — today the halted-status trigger list is `bind_conflict` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` only, so a bind whose advisor never ran is read downstream as clean, contradicting `SKILL.md:62`'s *"NEVER reported as clean"*.

**C9. LAST** — add `context: fork` to `SKILL.md` frontmatter and bump `version`.

### Group D — cross-cutting (contingent on RUN 1)

**D1.** If RUN 1 shows the handoff does **not** reach the capture point: amend `skills/orchestrate-flow/references/handoff-consumption.md:27` to state that for a `context: fork` producer the validated text is the Skill **tool result**, and add a deterministic disk fallback. `handoff-contract.md:152` already permits an optional sidecar (`<vault>/.internal/checkpoints/<ISO8601>-<skill>.handoff.yaml`) while `:130` forbids disk as the channel — elevate the sidecar to mandatory-when-forked and teach `scripts/validate-handoff-yaml.sh` to discover it (`:33` already accepts a file path; only discovery is missing). **The sidecar location must be vault-independent** (e.g. `.mega-sdd/.internal/checkpoints/`) — scan has an explicit no-vault branch (starterkit-first), so a vault-rooted sidecar leaves scan's handoff unrecoverable on exactly its greenfield-entry path.

**D2.** Also fix `skills/orchestrate-flow/references/routing-rules.md:92` and `skills/scan-codebase/references/scan-procedure.md:49`, which render the Mode-D full-scan-fallback handoff as bare `bind-codebase --auto` while `halts-flags-handoff.md:110` renders the same branch as `bind-codebase <vault> --auto`. **Two of three surfaces send a forked bind zero vault signal on the sync lane** — the one lane where both downstream phases are forked. Reconcile to the `<vault>`-carrying form.

**D3.** Reconcile the doc/frontmatter drift: `scan-procedure.md:49`, `halts-flags-handoff.md:89` and `routing-rules.md:92` already describe bind-codebase as forked, but `bind-codebase/SKILL.md:1-5` carries no `context:` key. Land in the same commit as the flip, or correct now if 5a slips.

---

## 6. TESTS

Template: `PLUGIN/tests/drift/test-detect-drift-fork.sh` (5 assertions — frontmatter, non-interactivity, `drift_inputs_missing`, disk-persisted drift-history, deprecation note; bash + python3 only, CI-safe).

**T1 — `PLUGIN/tests/scan/test-scan-codebase-fork.sh` (new).** Assert:
1. `SKILL.md` frontmatter has `context: fork`, version bumped, description is a valid YAML scalar (the colon-space bug).
2. **No ask-class directive survives on any of the three fork-visible surfaces** — grep `SKILL.md`, `references/scan-procedure.md`, `references/halts-flags-handoff.md` for `AskUserQuestion|ASK before|confirm with user|ask ONCE|offer to re-run` → **zero hits**. This is the assertion that catches the audit's single most common failure mode: fixing `scan-procedure.md:234` and leaving `SKILL.md:52` live.
3. The new blockers are referenced in `SKILL.md` **and** defined with `type:` in `references/halts-flags-handoff.md` — the exact two-location conjunction at `test-detect-drift-fork.sh:64-65`.
4. `SKILL.md` carries the "never AskUserQuestion / `--auto` implied" rail.
5. Handoff emission is **not** `--auto`-gated (`halts-flags-handoff.md` no longer says "Required ONLY under `--auto`").
6. The monorepo rail's ask directive is gone and the chosen deterministic rule is present.

**T2 — `PLUGIN/tests/binding/test-bind-codebase-fork.sh` (new).** Assert:
1. Frontmatter `context: fork` + version + valid YAML scalar.
2. Zero ask-class directives across `SKILL.md` + all 10 references — **specifically that `references/conflict-resolution.md` no longer says "bind-codebase prompts user to confirm"**.
3. `bind_inputs_missing` named in `SKILL.md` **and** `type: bind_inputs_missing` defined in `references/auto-memory-handoff.md`.
4. Step 0 exists and resolves via `$ARGUMENTS` → `derived.vault_path` → CWD probe → blocker; assert the string `derived.vault_path` (not `derived.vault`) — pins **R3**.
5. **The moat-location invariant:** binding.md is written under `<vault>/` where `<vault>` came from Step 0, and Step 0 refuses any vault outside `.mega-sdd/vaults/` — pins **R2**, the one path by which a fork could blind the gate.
6. **Negative assertion:** neither `SKILL.md` nor any reference writes `.validation-blockers.json`, so a future refactor cannot move the write into the forkable body.
7. The non-interactive rail is present in §Anti-hallucination rails.
8. Steps 2–5 (the CONFLICT/OQ decision path) are unchanged — a checksum or a grep for the load-bearing verdict strings, so a "fork-safety" patch cannot silently touch the moat.

**T3 — `PLUGIN/tests/handoff/test-handoff-under-fork.sh` (new).** `tests/handoff/` has 5 files, **none** pins scan's or bind's own handoff and **none** is fork-aware (`grep -i fork tests/handoff/` → zero). Assert both skills' handoff templates emit the required canonical fields, and — if D1 lands — that both declare the sidecar write and the consumer ref names the tool-result/sidecar capture path.

**T4 — extend `PLUGIN/tests/drift/test-detect-drift-fork.sh`.** Add the durability assertion that protects the §2 CLEAN result independently of the fork decision: **`hooks/pre-tool-use` still invokes `validate-handoff-binding-units.sh` unconditionally before the aggregator's python read of `.validation-blockers.json`** (`:421-422` before `:474-494`). If that ever becomes read-not-recomputed, every fork risk re-opens. Ship this one **regardless of the fork decision**.

*Note:* no static test can assert handoff survival under fork — that is RUN 1's job, not CI's. Do not write an assertion that pretends otherwise.

---

## 7. Genuinely unresolvable without a live interactive run

Stated plainly, per the brief:

1. **Does a forked skill body retain the `Agent` tool?** Doc-cited as yes (`research:22` ← sub-agents.md ~790/796) and the in-repo misreading is explicitly corrected (`research:17`), but **never exercised** — detect-drift dispatches no subagent. **RUN 2 must measure this**, in an interactive session, by having a `context: fork` skill attempt exactly one Agent dispatch and observing availability. This gates bind's default-on phase-advisor and scan's default-on 5-way deep-scan. **Cannot be papered over: this is why bind is NO-GO rather than GO-after-edits.**
2. **Does a forked skill's handoff reach the orchestrator's capture point?** Unmeasured, and — importantly — **not a bind/scan-specific blocker**: detect-drift already ships the identical exposure (`auto-and-chain.md:71` emits an inline handoff) and `test-detect-drift-fork.sh` asserts nothing about survival. It is an already-accepted, never-measured precedent-level open item that bind raises the stakes on, because `auto-memory-handoff.md:70-89`'s `--reconcile`-vs-`--auto` decision is state-aware and cannot be re-derived downstream (a bare `["--auto"]` there *"breaks id-stability + stale/superseded handling"*). **Mitigating and worth stating: `pre-tool-use:422` re-derives at the gate, so a lost handoff degrades routing and id-stability, never the blocking verdict.** RUN 1 measures it.
3. **Does a fork's tool calls report the parent's cwd?** No in-repo artifact records it. Every gate/validator path uses the shared `scripts/_lib/resolve-project-root.sh`, so the two sides can never disagree *given the same cwd* — but if a fork reports a different cwd, PROJECT_ROOT diverges between the fork's writes and the main-thread gate's reads, landing squarely in **R2**'s silent-PASS path. Partially precedent-covered (detect-drift already ships the CWD assumption). RUN 1 measures it by running from a sub-directory.
4. **The token win itself.** Precondition 0. Unmeasured; scaffolded; gated by `CLAUDE.md:69`.

---

## 8. What could still break in production that this audit cannot rule out

- **A phantom win.** `research:39` warns the reduction could be "cost relocated, not deleted", and `SubagentStop` is Stop-blind so a forked phase emits **zero `turn_end_marker`** — the telemetry is dark by construction until a synthetic marker is emitted. You may ship a fork, see a smaller main-thread transcript, and have moved cost rather than removed it.
- **Silent moat-recall loss.** If `Agent` is unavailable under fork and someone ships the `--no-advisor` fallback anyway, existing CONFLICTs still block (the gate is safe) but **missed** ones stay missed, on every forked bind, with the "NEVER reported as clean" rail addressed to a human who cannot see subagent chat. This degrades detection quality without ever tripping a gate — the hardest class of failure to notice in the field.
- **Eight warnings going dark**, including the credential-location warning (`scan-procedure.md:451`). The map is redacted; the *location of the live secret* exists only in chat. If A2's warnings decision is deferred, this ships as a silent security-hygiene regression.
- **`R2`'s silent-PASS path is pre-existing and untested.** Nothing in the current suite exercises a binding.md landing outside the glob root, `no_vault → PASS`, or a stale-binding backstop miss. The fork edits constrain resolution but do not fix the validator; a legacy-layout project (`references/paths.md:105` documents `docs/mega-sdd/vaults/<slug>/`) remains invisible to it.
- **Windows.** The target platform (per your CONFIRMED v5.9.0 floor) has ~220 ms/spawn under CrowdStrike. Fork adds a subagent boundary and the deep-scan stage dispatches five of them. Neither RUN 1 nor RUN 2 as scoped measures the Windows spawn cost of the fork boundary itself.
- **Chain-lane vs standalone-lane divergence.** The chain pre-resolves inputs and injects `--auto` (`handoff-contract.md:271`); a natural-language standalone invocation does neither, and `SKILL.md:4`'s NL triggers route straight to the Skill tool, bypassing the command file's `$ARGUMENTS` parsing entirely. Every edit above must be validated on the **standalone** lane, which is the one the audit found weakest and the one no routing row protects.
