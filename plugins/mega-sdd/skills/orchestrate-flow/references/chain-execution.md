# Chain Execution — Preflight, Routing Preflight, Diagnostics, Drift Gate

Detailed procedure for the resolution + execution phases that the SKILL.md router summarizes. Covers: starterkit/mode classification, memory-informed routing preflight, model-tier resolution, iter-classifier hooks, Plan/Act gating, chain-optimization skip, the predictive preflight loop, auto-integrated diagnostics, and the hybrid drift gate.

## Contents

- [Starterkit detection + mode classification](#starterkit-detection--mode-classification)
- [Memory-informed routing preflight](#memory-informed-routing-preflight)
- [Model-tier override resolution](#model-tier-override-resolution)
- [Iter classifier hooks (EP1 / EP2)](#iter-classifier-hooks-ep1--ep2)
- [Plan/Act gating](#planact-gating)
- [Chain optimization via binding provenance](#chain-optimization-via-binding-provenance)
- [Predictive preflight loop](#predictive-preflight-loop)
- [First-run pre-flight (execute-bolts)](#first-run-pre-flight-execute-bolts)
- [Auto-integrated diagnostics](#auto-integrated-diagnostics)
- [Hybrid drift gate phase](#hybrid-drift-gate-phase)
- [End-of-chain routing-outcomes write](#end-of-chain-routing-outcomes-write)
- [Final summary appendix (--deep)](#final-summary-appendix---deep)

## Starterkit detection + mode classification

Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield": a starterkit is REQUIRED by default; greenfield only when the user opts in explicitly.

Three modes determined by inspection:

| Mode | Trigger | Express spine (DEFAULT) | Classic (`--classic` / `spine: classic`) |
|---|---|---|---|
| **A — Starterkit-first** (DEFAULT) | `starterkit: detected` + `pack_match: yes` (`derived.framework_pack` from the GROUND matcher) | generate-intent (pack + index aware via state.json/symbol-index) → bind `--express` → units → bolts | scan-codebase FIRST (loads pack into context) → generate-intent (pack-aware vault) → bind → units → bolts |
| **B — Framework-detected** (universal fallback) | `starterkit: detected` + `pack_match: no` | same as A with `_universal` conventions | scan-codebase FIRST (`_universal.md`) → generate-intent → bind → units → bolts |
| **C — Greenfield (EXPLICIT)** | `--greenfield` flag OR (cwd empty/.git-only AND user confirms via halt) | generate-intent (stack-agnostic) → user scaffolds later → bind when code exists | same (Mode C was always scan-free) |

**Default behavior** when starterkit absent AND `--greenfield` NOT set → halt with `no_starterkit_detected`:

```yaml
halt:
  type: no_starterkit_detected
  reason: "Mega-sdd default workflow requires a framework starterkit (composer.json / package.json / Gemfile / etc.) for delivery-grade output. Vault generation produces stack-agnostic designs without it."
  options:
    a: "Scaffold a starterkit first (recommended). For Laravel: clone base-laravel-26. For Django: django-admin startproject. For Rails: rails new. Then re-run."
    b: "Proceed as greenfield with --greenfield flag (vault stays stack-agnostic; you scaffold, then bind when code exists — express needs no scan)"
    c: "Cancel"
```

**Legacy rebuild scenario** (extract-intelligence + scan-on-target):
```
extract-intelligence <legacy> → KB
  ↓
scan-codebase (TARGET — new framework scaffold) → codebase-map.md
  ↓
generate-intent --kb=<kb> --scan=<codebase-map> → vault aware of BOTH legacy domain AND target scaffold conventions
  ↓ bind → units → bolts
```

**Memory hint**: user's last starterkit preference is saved to `~/.mega-sdd/memory/preferences.md` `last_used_starterkit:` — the next legacy-rebuild run prompts "Last 3 projects used `laravel-base-26`. Use same starterkit?" Y/N/other.

## Memory-informed routing preflight

Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) schema. Optional — falls through silently if memory file absent or insufficient history.

a. Compute project fingerprint: `sha256(composer.json + package.json + framework_pack_path)[:16]`
b. Read `<project>/.mega-sdd/memory/routing-outcomes.md` (if exists; else skip).
c. Filter rows matching current fingerprint.
d. Apply decision rules:
   - **≥3 prior rows, converged=yes, same chain-used:** recommend that chain as default; LOG: "Routing recommendation from past N runs (all converged in avg X min)"
   - **≥2 prior rows, converged=no, same chain-used:** WARN: "Past N runs of this chain failed (halts: <list>); consider alternate chain"; fall through to routing-rules.md default (user decides)
   - **Mixed results OR <3 prior rows:** fall through to routing-rules.md default (no override)
e. If file parse fails: emit SOFT halt `routing_outcome_corrupt` + auto-invalidate (rename to `.corrupt-<ISO8601>`); fall through to default; LOG: "routing-outcomes.md corrupt; auto-invalidated; chain proceeds with default routing"
f. Update chain proposal with recommendation OR fall-through default.

## Model-tier override resolution

Per `plugins/mega-sdd/references/model-tiers.md` override syntax. Resolves model tier per named subagent role from the override chain. Default-on; no flag needed.

a. **Read CLI flags from invocation**: collect all `--model-tier=<role>:<tier>` flags into `cli_overrides`.
b. **Read `<project>/.mega-sdd/config.yaml`**: parse `model_tiers:` section if present; build `project_overrides`.
c. **Read `~/.mega-sdd/memory/preferences.md` `## Model tiers` section**: build `user_overrides`.
d. **Compute final resolved tier per role** (precedence: CLI > project > user > catalog):
   - For each role mentioned in any override source: cli → project → user → catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`).
e. **Emit final `model_tiers:` dict in handoff metadata** for all downstream skills:
   ```yaml
   metadata:
     model_tiers:
       auth-extractor: sonnet
       authz-extractor: sonnet
       code-quality-reviewer: sonnet  # override applied — was opus in catalog
     model_tier_sources:  # provenance trail (OPTIONAL)
       auth-extractor: catalog
       code-quality-reviewer: project-config
   ```
f. **Forward-compat tolerance**: if any role in override sources doesn't exist in catalog → emit SOFT halt `model_tier_unknown` (warn-only); log warning; ignore that override; chain proceeds with catalog default.
   ```yaml
   type: model_tier_unknown
   source_skill: orchestrate-flow
   details:
     unknown_role: "some-future-role"
     override_source: "project-config"
     override_file: "<project>/.mega-sdd/config.yaml:line-N"
   next_action: "Role 'some-future-role' not found in plugins/mega-sdd/references/model-tiers.md catalog. Log warning and continue with default tier. Either remove from override OR add the role to the catalog if it's a real subagent role."
   ```
g. **Logging**: log resolved tier summary, e.g. `Model tier overrides applied: code-quality-reviewer=sonnet (project-config); audit-probe=sonnet (cli-flag)`
h. **No file writes** — purely resolution; resolved tiers live in handoff metadata only.

## Iter classifier hooks (EP1 / EP2)

> **STATUS — PARKED (not wired into the live chain).** `classify-iter.sh` exists as a hand-run advisory tool but **no skill body Bash-invokes it** and it is **not wired into any chain** (see `plugins/mega-sdd/references/telemetry-schema.md` + `plugins/mega-sdd/references/fork-a-recovery-map.md` §EP2 — "Not implemented; deferred"). The EP1/EP2 mechanism below documents the *intended* design for a future Fork-B; it is **not executed in the current pipeline**. Until it lands, the effective iter_type defaults to **PATCH** (the documented default branch in §Plan/Act gating below) and is steerable only by the explicit `--plan` / `--act` / `--plan-then-act` flags that §Plan/Act gating consumes directly.

**EP1 (before chain build):** *(parked — see status above)* invoke `plugins/mega-sdd/scripts/classify-iter.sh --ep=EP1 [--explicit-flag=<patch|minor|major> if user passed --iter-type=<>] --emit-telemetry=<project>/.mega-sdd/memory/telemetry.jsonl`. Output JSON parsed for `iter_type` (PATCH | MINOR | MAJOR). Used by downstream skills as input to complexity-gated decisions (Plan/Act gating; budget enforcement). Telemetry event `iter_classifier_output` emitted with EP=EP1.

**EP2 (after chain completes, before final summary):** invoke `plugins/mega-sdd/scripts/classify-iter.sh --ep=EP2 --emit-telemetry=<project>/.mega-sdd/memory/telemetry.jsonl`. Compare EP2 vs EP1 — if mismatch, emit telemetry event `iter_classifier_drift` with both outputs + drift reason. If EP1=PATCH but EP2=MAJOR (scope grew), surface drift to user in final summary so future iter-ceremony decisions can adjust.

## Plan/Act gating

Read the EP1 classifier output (when present — see the PARKED status above). When absent (the current parked default), treat iter_type as **PATCH**, which routes to the PATCH branch below (Direct Act, overridable by `--plan`). Branch:

- **iter_type=PATCH** → Direct Act mode. Continue. (Default; overridable by `--plan` → Plan mode first.)
- **iter_type=MINOR** → Act mode default. If `--plan` → Plan mode first; else continue in Act.
- **iter_type=MAJOR** → **Plan mode FIRST mandatory.**
  - Check for `<project>/.mega-sdd/.plan-pending` (JSON from prior Plan-mode invocation matching current task_id + session_id).
  - If absent OR stale (>24h old): enter Plan mode. Skill body LOADS but DOES NOT execute writes. Emit proposed actions + acceptance criteria + estimated scope to chat. Write `.plan-pending` JSON. STOP chain — user reviews + invokes `/mega-sdd --act` (the `--act` flag) to transition.
  - If `.plan-pending` present + fresh + matches current task: read it; continue in Act mode. Delete `.plan-pending` on Act completion.
- **Explicit override:** `--act` flag forces direct Act regardless of classifier. For MAJOR: confirm via AskUserQuestion — question carries the risk context ("MAJOR = perubahan besar; tanpa Plan phase tidak ada review rencana sebelum eksekusi. Proceed?"); options: `Plan first` **(recommended)** — tulis rencana + STOP untuk review, lanjut via `--act`; `Proceed without plan` — langsung eksekusi tanpa rencana tertulis.
- **Explicit Plan force:** `--plan-then-act` flag forces two-phase regardless of classifier.

Stale-plan check: if `.plan-pending` exists from a prior session AND classifier output differs OR > 24h old → warn user "stale plan; rerun `/mega-sdd --plan` or delete `.plan-pending`".

## Chain optimization via binding provenance

**Express-lane short-circuit (P2 — evaluated FIRST):** if the prior `binding.md` frontmatter carries `binding_metadata.retrieval` (an express bind), this whole optimization is INAPPLICABLE — express stamps `no-snapshot` unconditionally because it reads no map, and the express-spine chains contain no `scan-codebase` hop to remove or retain in the first place. Applying the `no-snapshot` branch below to an express binding would re-add the demoted scan phase to every express chain — the exact resurrect-vector P2 closes. Skip to the preflight loop.

Otherwise (classic lane): after the chain is built, if it includes `scan-codebase` AND `<vault-path>/binding.md` already exists from a recent bind-codebase run, read the binding header for `binding_metadata.codebase_map_provenance` (written by bind-codebase per its SKILL.md):

- IF `snapshot-verified` AND `<project>/.mega-sdd/codebase/codebase-map.md` mtime is newer than every tracked source file mtime → REMOVE scan-codebase from the chain; log: `"⊘ scan-codebase skipped: binding.md attests snapshot-verified + source files unchanged"`.
- IF `snapshot-stale` → keep scan-codebase; prepend log: `"⚠ scan-codebase retained: binding.md flagged snapshot-stale; codebase changed since last binding"`.
- IF `no-snapshot` OR `unverified-external` (externally-authored map without writer-provenance — can never attest freshness) OR binding.md absent OR field unparseable → keep scan-codebase (baseline behavior; no optimization).

## Predictive preflight loop

Consults the predictive-checks catalog (the `predictive-checks` reference indexed in SKILL.md §Specialist references). Runs BEFORE invoking any skill in the proposed chain.

a. For each skill in the proposed chain (in order):
   - Read the predictive-checks catalog `§<skill> preflight checks` section.
   - For each check entry: run `command`; verify against `expected`.
   - On match → pass; continue.
   - On mismatch: `fatal: no` → accumulate warning (surface to user before chain start); `fatal: yes` → emit halt `predictive_check_failed` with check_id + skill in details; STOP chain (do NOT invoke any skill).
b. After all skills checked:
   - If ≥1 warning accumulated → display warnings via a single message before chain start (e.g., "⚠️ no AST engine installed; chain will use regex engine").
   - If chain halted with `predictive_check_failed` → output halt YAML envelope + exit (no first-run pre-flight, no execution).
c. Wall-clock budget: ≤2 sec total (lightweight bash checks only); if exceeded → log warning + proceed (graceful degradation).
d. **First-run pre-flight special case:** the execute-bolts-specific first-run pre-flight (below) runs AFTER this generic loop. It covers execute-bolts behaviors the generic catalog doesn't capture.

```yaml
# Example predictive_check_failed envelope:
type: predictive_check_failed
source_skill: orchestrate-flow
details:
  failing_check_id: ast_engine_present
  failing_skill: scan-codebase
  command_run: "command -v tree-sitter || command -v tree-sitter-cli"
  expected: "exit 0"
  actual: "exit 1 (binary not found)"
next_action: "Install an AST engine (brew install ast-grep — zero-compilation tier — OR brew install tree-sitter-cli) then re-run. Alternatively, run scan-codebase with --engine=regex to accept the regex tier."
```

## First-run pre-flight (execute-bolts)

Only if the chain includes execute-bolts:
- Check superpowers OR `_vendored/` availability.
- If neither → propose install command, halt chain proposal.

## Auto-integrated diagnostics

> **`--lean` profile:** the ADVISORY rows below (`lint-units`, `analyze-parallelism`,
> `list-modules`, `emit-agents-md`) are SKIPPED when the profile is lean (`--lean` flag or
> `profile: lean` in config.yaml) — each is re-runnable on demand. `detect-drift` (the hybrid
> gate) and every emit row (already opt-in via `--with-fsd`) are NOT profile-conditioned.


Per the command-sprawl-audit consolidation restoring "single command" philosophy. Inside a `--deep` chain (OR `--auto` mode), the orchestrator AUTOMATICALLY invokes diagnostic commands at appropriate phases — user does NOT run these separately:

| Phase | Auto-runs | Output integration |
|---|---|---|
| After `extract-intelligence` completes (or whenever a KB is present) AND `.mega-sdd/.kb-flows-state.json` carries a `kb_flow_staging_missing` advisory | `enrich-semantics` in **propose** mode (`scripts/enrich-workflows-staging.sh --vault=<vault> --semantic=staged-input`; `--legacy-root` AUTO-DISCOVERED from the KB README's "source codebase path" + common legacy dirs, or pass it explicitly) | Writes `<vault>/ENRICHMENT-PROPOSALS.md` and **PAUSES the chain** (`status: paused`) with a one-line summary: "staging-missing in N workflow(s) → proposals at ENRICHMENT-PROPOSALS.md; review + `/mega-sdd:enrich-semantics --apply`, then `--resume`". NEVER auto-applies. |
| After `generate-units` completes | `lint-units --changed-only` (per `commands/lint-units.md` Procedure §Step 1b — just-regenerated units differ from the analyze ledger's `unit_baseline`, so the first chain run ≈ full sweep and iteration runs scope to the delta ∪ dependents; no ledger → honest full sweep) | One-line chat summary: "lint: N of M units (changed ∪ dependents) — N HIGH / M MEDIUM / K LOW grounding; X/Y anchors verified" + halt-on-LOW-strict if `--strict-quality` flag set |
| Before `execute-bolts` invocation | `analyze-parallelism` — run the script form `bash <plugin-root>/scripts/analyze-parallelism.sh <vault> --cwd=<root> --format=json` (per `commands/analyze-parallelism.md`) | Wave plan computed; the JSON's `waves` array (the `depends_on` topological layering) sits IN CONTEXT when the chain dispatches `execute-bolts --all --parallel` (the routing/handoff rows carry the flag — `docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md` §2a), and execute-bolts consumes it as the layering input per `execute-bolts/references/batch-and-fanout.md §--all` (the `target_files` overlap rail is applied there, per wave, never by this plan) |
| After `execute-bolts` completes | `list-modules` (per `commands/list-modules.md` table format) | Per-module status table in chain end summary |
| After all phases complete | `emit-agents-md` (per the `emit-agents-md` skill, respecting `config.yaml defaults.emit_agents_md: true\|false`) | `AGENTS.md` (or `.mega-sdd.md` sibling) written at repo root |
| After all phases complete | `emit-fsd` (per the `emit-fsd` skill, **OPT-IN** — requires `--with-fsd` flag on `auto`/`orchestrate-flow`. Legacy `--no-fsd` still works as no-op for back-compat. Reason: pandoc + Chrome md2pdf render + low user feedback signal per perf audit.) | `<vault>/fsd/FSD.pdf` (+ FSD.md, .citation-map.json) written ONLY when `--with-fsd` passed; chain summary: "FSD emitted: N sections, M citations, mode: <pre-dev\|post-dev>" |
| After all phases complete | Memory review check (per the `memory` skill review op if `~/.mega-sdd/memory/patterns.md` has ≥1 pending suggestion) | Surface in chain summary: "N pending learning suggestions → review via `/mega-sdd:memory review`" |
| **After EACH phase completes (chain boundary)** | **Doc-control stamp refresh** (script-lane, ~0 tokens): for each ALREADY-EMITTED doc — `<vault>/fsd/FSD.md`, `<vault>/prd/PRD.md`, `<vault>/sit/SIT.md`, `<vault>/uat/UAT.md` — that exists, `Run: bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<vault> --doc=<fsd\|prd\|sit\|uat> --position="<phase just completed> selesai; next: <next phase or chain end>"`. **`--position` ONLY** — maturity rungs are set at emit time (SIT via the `build-sit-evidence.sh` verdict; FSD via mode) or by humans (PRD `reviewed`/`final`); the chain never bumps maturity. Non-zero exit → log one line, never halt (the stamp is metadata, not a gate). Skip silently when no emitted doc exists. | Doc-control blocks stay current between full emissions (per `plugins/mega-sdd/references/emission-engine.md §Doc-control stamping`) |
| After `extract-intelligence` completes AND no vault exists yet | Chain-summary MENTION (one line, never auto-run): "KB siap — untuk draft PRD yang bisa dibaca tim dari KB ini (marker `[VERIFIED]/[INFERRED]/[OPEN]` dibawa verbatim), jalankan `/mega-sdd:emit prd` (reverse mode). Pipeline lanjut via `generate-intent --kb` — PRD adalah OUTPUT, bukan input pipeline." | One line in the chain end summary |
| After `execute-bolts` completes AND ≥1 `bolts/U-*/acceptance.json` exists | Chain-summary PROPOSAL (one line, never auto-run): "Bukti eksekusi tersedia — `/mega-sdd:emit sit` menghasilkan dokumen SIT dengan tabel bukti §4 script-derived (maturity dari coverage evidence)." | One line in the chain end summary |
| At chain end AND `<vault>/sit/SIT.md` exists | Chain-summary MENTION (one line, never auto-run): "Tim UAT butuh test script? `/mega-sdd:emit uat` menghasilkan skenario bisnis 1:1 dari flow + berita acara." | One line in the chain end summary |

These diagnostics run TRANSPARENTLY — chat output includes their summaries inline with phase progress lines. User does NOT need to know they exist as separate commands.

**Exception — staged-input enrichment PAUSES.** The `enrich-semantics` row is the ONE auto-integrated step that is NOT fire-and-forget: it auto-**proposes** but never auto-**applies** (the per-stage field allocation is best-effort + `--apply` mutates the KB/vault, so review is mandatory per "jangan auto-apply tanpa konfirmasi"). The orchestrator surfaces `ENRICHMENT-PROPOSALS.md`, pauses the chain, and waits for the user to review → `/mega-sdd:enrich-semantics --apply` → `/mega-sdd --resume`. If no `kb_flow_staging_missing` advisory is present, the step is skipped silently. Opt-out: `--no-enrich-staging`.

**Manual override**: users invoking individual commands directly (`/mega-sdd:lint-units` etc.) still works for debugging/one-off use. Auto-invocations skip when the user explicitly disables via `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags on `auto`/`orchestrate-flow`.

## Hybrid drift gate phase

After `execute-bolts --all` batch completes (or with retried halts), orchestrate-flow AUTO-invokes `detect-drift` as a gate phase. DEFAULT-ON.

### Gate behavior

```
✓ execute-bolts: 20/20 done (or 18/20 + 2 halts resolved via propose-and-confirm)
▶ Phase 5.5/6: detect-drift (auto-gate, hybrid mode — DEFAULT-ON)
  Scope: <scope_id> — scope-filtered scan
  Comparing: bolt postflight snapshots vs vault (shared snapshot machinery per plugins/mega-sdd/references/shared-snapshot-schema.md)
  Speed: 4s (vs 28s full re-scan; snapshot reuse saves 6x)

⚠️ Drift findings: N (X CRITICAL, Y HIGH, Z MEDIUM, W LOW)
```

### Severity → chain action mapping

| Severity | Trigger | Chain action |
|---|---|---|
| CRITICAL | Drift on LOCKED entity (data-mutation-policy.md tier) | HALT chain; user MUST resolve before proceeding |
| HIGH | Drift on CONFIRMED claim with no mutability source OR INTENT outcome change | PAUSE; user can override with audit-significant decision |
| MEDIUM | Drift on INTENT claim implementation change | LOG + continue; surface in batch summary |
| LOW | Drift on ARTIFACT cleanup OR style only | LOG only; no chain interruption |

**Keterangan on CRITICAL/HIGH (mandatory — never surface counts alone).** Per finding, render: the entity/claim name, its mutability tier + source citation, one line of *vault-said vs code-is*, and the `DRIFT-REPORT.md` path. The HIGH-pause override is an explicit `AskUserQuestion`: `Resolve first` **(recommended)** — chain tetap pause sampai drift-nya dibereskan (via sync/resolve-oq); `Override & continue` — keputusan audit-signifikan dicatat di chain summary, chain lanjut dengan drift tetap terbuka di `DRIFT-REPORT.md`. A severity count (`2 CRITICAL, 1 HIGH`) with no finding text is unanswerable — the keterangan contract (`plugins/mega-sdd/references/output-language.md §Prompt surfaces`) applies.

### Opt-out

- `--no-drift-check` flag in `/mega-sdd` or `execute-bolts` → skip the auto-drift gate entirely. Escape hatch, not default.

### On-demand drift (separate from auto-gate)

`/mega-sdd:detect-drift` standalone (no chain context) → fresh full scan; ignores bolt snapshots. The auto-gate path uses snapshot reuse per `plugins/mega-sdd/references/shared-snapshot-schema.md`.

## End-of-chain routing-outcomes write

Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) write protocol. Skip entirely if `--memory-off` set.

a. Compute:
   - `chain-used`: short label, e.g., "starterkit-first (scan→intent→bind→units→bolts)"
   - `duration-min`: integer wall-clock from chain start → now
   - `converged`: yes if final status==completed AND blockers==[]; no otherwise
   - `halts-fired`: count of unique halt types fired during chain
b. If the file does not exist: create with header per schema doc (Write, ONCE).
c. Append the row via `bash <plugin>/scripts/memory-write.sh --file=<project>/.mega-sdd/memory/routing-outcomes.md --scope=project --cwd=<project-root>` — the script owns the lock (3-retry backoff, `memory_in_use` telemetry on exhaustion), the secret scan, and the atomic append; exit ≠ 0 → log and continue (never a halt).
d. LOG: "routing-outcomes.md updated (entry: <chain-used> | <duration-min>min | converged=<yes/no>)"

## Final summary appendix (--deep)

In `--deep` mode, append to the final summary:

- Total phases proposed, total phases completed, total artifacts produced (flat path list).
- **Auto-integrated diagnostics summary**:
  - Quality metrics from auto lint-units (units HIGH/MEDIUM/LOW counts)
  - Parallelism speedup from auto analyze-parallelism (X.Yx vs sequential)
  - Per-module status from auto list-modules (X/Y modules completed)
  - AGENTS.md emission confirmation (file path + section count)
  - Memory review prompt if pending suggestions exist
  - Acceptance-test concerns from execute-bolts handoff: IF `metrics.acceptance_test_concerns: []` is non-empty (bolt subagent flagged implementation passes acceptance test but feels under-validated), surface as: `"⚠ N/M bolts flagged acceptance_test_concern — review for under-validation: <unit_id list>. Consider re-running affected units with adversarial-reviewed acceptance tests (run /mega-sdd:generate-units --regenerate --adversarial-subagent --units=<list>)."`
  - Deferred open questions (P3/A6): IF the vault carries `open_questions[] status == deferred` (incl. express auto-defers), surface as: `"⏸ N OQ deferred (auto-deferred P2/P3 di jalur express + defer manual) — <tag list>. Jawab kapan saja: /mega-sdd:resolve-oq."` — the defer is recorded state; this line is its mandated resurface (also in execute-bolts `_summary.md §Deferred open questions` and the non-deep Step 9 summary).
  - FSD pending sections: IF the chain ran emit-fsd, read `<vault>/fsd/.citation-map.json` `missing_sources[]` — non-empty → surface: `"ℹ FSD emitted with N pending section(s) (sources not yet produced: <list>) — full coverage after the missing artifacts exist (scan/bind/bolts), then re-run /mega-sdd:emit fsd."`
- **Predictive preflight metrics:**
  ```yaml
  metrics:
    predictive_warnings_count: <int>     # count of non-fatal predictive warnings shown
    predictive_halts_count: <int>        # count of fatal predictive halts (always ≤1 since fatal halts STOP)
  ```
- **Phase context** (appended when vault.json has a `phase` field):
  - IF `vault.phase < vault.phase_total`: "Phase <N> of <M> complete. To start Phase <N+1>: see `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md §Phase <N+1>` OR run `/mega-sdd:generate-intent --kb=<KB> --phase=<N+1>`."
  - IF `vault.phase == vault.phase_total`: "Phase <N> of <M> complete. All phases finished."
  - IF `phase` field absent (single-phase project OR pre-phasing vault): omit the phase context section.

  This complements the execute-bolts handoff `next_action.hint` — orchestrate-flow surfaces the same info at chain-summary level for user visibility.

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: routing-rules (decision matrices the chain is built from), predictive-checks (the preflight catalog this loop consults), handoff-consumption (the per-skill validation gate inside the execution loop), and memory-layer (read/write batching during the chain).
