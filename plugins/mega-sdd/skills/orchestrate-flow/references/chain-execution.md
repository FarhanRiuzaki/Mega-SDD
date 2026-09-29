# Chain Execution — Preflight, Routing Preflight, Diagnostics, Drift Gate

Detailed procedure for the resolution + execution phases that the SKILL.md router summarizes. Covers: starterkit/mode classification, model-tier resolution, iter-classifier hooks, Plan/Act gating, the predictive preflight loop, auto-integrated diagnostics, and the hybrid drift gate.

## Contents

- [Starterkit detection + mode classification](#starterkit-detection--mode-classification)
- [Model-tier override resolution](#model-tier-override-resolution)
- [Iter classifier hooks (EP1 / EP2)](#iter-classifier-hooks-ep1--ep2)
- [Plan/Act gating](#planact-gating)
- [Predictive preflight loop](#predictive-preflight-loop)
- [First-run pre-flight (execute-bolts)](#first-run-pre-flight-execute-bolts)
- [Auto-integrated diagnostics](#auto-integrated-diagnostics)
- [Hybrid drift gate phase](#hybrid-drift-gate-phase)
- [Final summary appendix (--deep)](#final-summary-appendix---deep)

## Starterkit detection + mode classification

Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield": a starterkit is REQUIRED by default; greenfield only when the user opts in explicitly.

Three modes determined by inspection:

| Mode | Trigger | Chain |
|---|---|---|
| **A — Starterkit-first** (DEFAULT) | `starterkit: detected` + `pack_match: yes` (`derived.framework_pack` from the GROUND matcher) | GROUND (`ground.sh`: state + symbol index + pack) → `plan <prd>` (pack + index aware) → `execute-bolts --all --lite` (JIT bind per unit) |
| **B — Framework-detected** (universal fallback) | `starterkit: detected` + `pack_match: no` | same as A with `_universal` conventions |
| **C — Greenfield (EXPLICIT)** | `--greenfield` flag OR (cwd empty/.git-only AND user confirms via halt) | `plan <prd>` (stack-agnostic; `implementation_mode: new` → every unit `create`) → user scaffolds → `execute-bolts` (JIT bind per unit) |

**Default behavior** when starterkit absent AND `--greenfield` NOT set → halt with `no_starterkit_detected`:

```yaml
halt:
  type: no_starterkit_detected
  reason: "Mega-sdd default workflow requires a framework starterkit (composer.json / package.json / Gemfile / etc.) for delivery-grade output. Vault generation produces stack-agnostic designs without it."
  options:
    a: "Scaffold a starterkit first (recommended). For Laravel: clone base-laravel-26. For Django: django-admin startproject. For Rails: rails new. Then re-run."
    b: "Proceed as greenfield with --greenfield flag (plan writes stack-agnostic units, all create; you scaffold, then execute-bolts JIT-binds each unit before building it)"
    c: "Cancel"
```

**Legacy rebuild scenario** (extract-intelligence + GROUND on target):
```
extract-intelligence <legacy> → KB
  ↓
GROUND on the TARGET scaffold (scripts/ground.sh → state.json + symbol index + framework pack)
  ↓
plan --kb=<kb-dir> → layout-3 vault + units from the KB README.md + modules/*.prd.md; target conventions from GROUND
  ↓ execute-bolts --all --lite (JIT bind per unit)
```

## Model-tier override resolution

Per `plugins/mega-sdd/references/model-tiers.md` override syntax. Resolves model tier per named subagent role from the override chain. Default-on; no flag needed.

a. **Read CLI flags from invocation**: collect all `--model-tier=<role>:<tier>` flags into `cli_overrides`.
b. **Read `<project>/.mega-sdd/config.yaml`**: parse `model_tiers:` section if present; build `project_overrides`.
c. Project `config.yaml model_tiers:` is the single override source (there is no user-scope preferences source).
d. **Compute final resolved tier per role** (precedence: CLI > project > catalog):
   - For each role mentioned in any override source: cli → project → catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`).
e. **Emit final `model_tiers:` dict in handoff metadata** for all downstream skills:
   ```yaml
   metadata:
     model_tiers:
       extract-intelligence-module: sonnet
       extract-intelligence-verify: opus  # override applied — was sonnet in catalog
     model_tier_sources:  # provenance trail (OPTIONAL)
       extract-intelligence-module: catalog
       extract-intelligence-verify: project-config
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
g. **Logging**: log resolved tier summary, e.g. `Model tier overrides applied: extract-intelligence-verify=opus (project-config); audit-probe=sonnet (cli-flag)`
h. **No file writes** — purely resolution; resolved tiers live in handoff metadata only.

## Iter classifier hooks (EP1 / EP2)

> **REMOVED (v7 Fase 2).** The parked EP1/EP2 classifier design (`classify-iter.sh`) never wired into any chain and the script is deleted. iter_type is **PATCH by default** and steerable ONLY by the explicit `--plan` / `--act` / `--plan-then-act` flags that §Plan/Act gating consumes directly. (Historical design: git.)

## Plan/Act gating

iter_type defaults to **PATCH** (no classifier exists), which routes to the PATCH branch below (Direct Act, overridable by `--plan`). Branch:

- **iter_type=PATCH** → Direct Act mode. Continue. (Default; overridable by `--plan` → Plan mode first.)
- **iter_type=MINOR** → Act mode default. If `--plan` → Plan mode first; else continue in Act.
- **iter_type=MAJOR** → **Plan mode FIRST mandatory.**
  - Check for `<project>/.mega-sdd/.plan-pending` (JSON from prior Plan-mode invocation matching current task_id + session_id).
  - If absent OR stale (>24h old): enter Plan mode. Skill body LOADS but DOES NOT execute writes. Emit proposed actions + acceptance criteria + estimated scope to chat. Write `.plan-pending` JSON. STOP chain — user reviews + invokes `/mega-sdd --act` (the `--act` flag) to transition.
  - If `.plan-pending` present + fresh + matches current task: read it; continue in Act mode. Delete `.plan-pending` on Act completion.
- **Explicit override:** `--act` flag forces direct Act. For MAJOR: confirm via AskUserQuestion — question carries the risk context ("MAJOR = perubahan besar; tanpa Plan phase tidak ada review rencana sebelum eksekusi. Proceed?"); options: `Plan first` **(recommended)** — tulis rencana + STOP untuk review, lanjut via `--act`; `Proceed without plan` — langsung eksekusi tanpa rencana tertulis.
- **Explicit Plan force:** `--plan-then-act` flag forces two-phase.

Stale-plan check: if `.plan-pending` exists from a prior session AND > 24h old → warn user "stale plan; rerun `/mega-sdd --plan` or delete `.plan-pending`".

## Predictive preflight loop

Consults the predictive-checks catalog (the `predictive-checks` reference indexed in SKILL.md §Specialist references). Runs BEFORE invoking any skill in the proposed chain.

a. For each skill in the proposed chain (in order):
   - Read the predictive-checks catalog `§<skill> preflight checks` section.
   - For each check entry: run `command`; verify against `expected`.
   - On match → pass; continue.
   - On mismatch: `fatal: no` → accumulate warning (surface to user before chain start); `fatal: yes` → emit halt `predictive_check_failed` with check_id + skill in details; STOP chain (do NOT invoke any skill).
b. After all skills checked:
   - If ≥1 warning accumulated → display warnings via a single message before chain start (e.g., "⚠️ ast-grep not installed — no symbol index; brownfield units typed create, symbol claims stay OQ at JIT bind").
   - If chain halted with `predictive_check_failed` → output halt YAML envelope + exit (no first-run pre-flight, no execution).
c. Wall-clock budget: ≤2 sec total (lightweight bash checks only); if exceeded → log warning + proceed (graceful degradation).
d. **First-run pre-flight special case:** the execute-bolts-specific first-run pre-flight (below) runs AFTER this generic loop. It covers execute-bolts behaviors the generic catalog doesn't capture.

```yaml
# Example predictive_check_failed envelope:
type: predictive_check_failed
source_skill: orchestrate-flow
details:
  failing_check_id: prd_or_kb_input_present
  failing_skill: plan
  command_run: "test -f docs/prd.md"
  expected: "exit 0"
  actual: "exit 1"
next_action: "Pass the PRD path or --kb=<kb-dir> (run extract-intelligence first), then re-run."
```

## First-run pre-flight (execute-bolts)

The first-class agents ship in the plugin tree, so there is no
superpowers/vendored dependency to probe — nothing halts here. A broken Agent
tool surfaces at dispatch time (superpowers-bridge.md §Dispatch order).

## Auto-integrated diagnostics

> **`--lean` profile:** the ADVISORY rows below (`lint-units`, `analyze-parallelism`,
> `list-modules`, `emit-agents-md`) are SKIPPED by default (the P3 lean default) and under the
> lean profile (`--lean` flag or `profile: lean` in config.yaml); `--full` restores them for a run —
> each is re-runnable on demand. `detect-drift` (the hybrid
> gate) and every emit row (already opt-in via `--with-fsd`) are NOT profile-conditioned.


Inside a `--deep` chain (OR `--auto` mode), the orchestrator AUTOMATICALLY runs these diagnostics at appropriate phases — user does NOT run these separately. The operative procedures for `lint-units` / `analyze-parallelism` / `list-modules` live in `references/diagnostics-procedures.md`:

| Phase | Auto-runs | Output integration |
|---|---|---|
| After `plan` completes (only with `--full`) | `lint-units --changed-only` (per `references/diagnostics-procedures.md §lint-units` Step 1b — just-regenerated units differ from the analyze ledger's `unit_baseline`, so the first chain run ≈ full sweep and iteration runs scope to the delta ∪ dependents; no ledger → honest full sweep) | One-line chat summary: "lint: N of M units (changed ∪ dependents) — N HIGH / M MEDIUM / K LOW grounding; X/Y anchors verified" + halt-on-LOW-strict if `--strict-quality` flag set |
| Before `execute-bolts` invocation | `analyze-parallelism` — run the script form `bash <plugin-root>/scripts/analyze-parallelism.sh <vault> --cwd=<root> --format=json` (per `references/diagnostics-procedures.md §analyze-parallelism`) | DAG facts for the chain summary: the JSON's `waves` array (the `depends_on` topological layering) numbers the sprints `execute-bolts --sprint=<n>` runs; the default inline run takes plan order and consumes no wave plan |
| After `execute-bolts` completes | `list-modules` (per `references/diagnostics-procedures.md §list-modules` table format) | Per-module status table in chain end summary |
| After all phases complete | `emit-agents-md` (per the `emit-agents-md` skill, respecting `config.yaml defaults.emit_agents_md: true\|false`) | `AGENTS.md` (or `.mega-sdd.md` sibling) written at repo root |
| After all phases complete | `emit-fsd` (per the `emit-fsd` skill, **OPT-IN** — requires `--with-fsd` flag on `auto`/`orchestrate-flow`. Legacy `--no-fsd` still works as no-op for back-compat. Reason: pandoc + Chrome md2pdf render + low user feedback signal per perf audit.) | `<vault>/fsd/FSD.pdf` (+ FSD.md, .citation-map.json) written ONLY when `--with-fsd` passed; chain summary: "FSD emitted: N sections, M citations, mode: <pre-dev\|post-dev>" |
| **After EACH phase completes (chain boundary)** | **Doc-control stamp refresh** (script-lane, ~0 tokens): for each ALREADY-EMITTED doc — `<vault>/fsd/FSD.md`, `<vault>/prd/PRD.md`, `<vault>/sit/SIT.md`, `<vault>/uat/UAT.md` — that exists, `Run: bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<vault> --doc=<fsd\|prd\|sit\|uat> --position="<phase just completed> selesai; next: <next phase or chain end>"`. **`--position` ONLY** — maturity rungs are set at emit time (SIT via the `build-sit-evidence.sh` verdict; FSD via mode) or by humans (PRD `reviewed`/`final`); the chain never bumps maturity. Non-zero exit → log one line, never halt (the stamp is metadata, not a gate). Skip silently when no emitted doc exists. | Doc-control blocks stay current between full emissions (per `plugins/mega-sdd/references/emission-engine.md §Script contracts` + the `scripts/refresh-doc-stamps.sh` header contract) |
| After `extract-intelligence` completes AND no vault exists yet | Chain-summary MENTION (one line, never auto-run): "KB siap — untuk draft PRD yang bisa dibaca tim dari KB ini (marker `[VERIFIED]/[INFERRED]/[OPEN]` dibawa verbatim), jalankan `/mega-sdd:emit prd` (reverse mode). Pipeline lanjut via `plan --kb=<kb-dir>` (README.md + modules/*.prd.md → vault layout-3 + units) — PRD adalah OUTPUT, bukan input pipeline." | One line in the chain end summary |
| After `execute-bolts` completes AND ≥1 `bolts/U-*/acceptance.json` exists | Chain-summary PROPOSAL (one line, never auto-run): "Bukti eksekusi tersedia — `/mega-sdd:emit sit` menghasilkan dokumen SIT dengan tabel bukti §4 script-derived (maturity dari coverage evidence)." | One line in the chain end summary |
| At chain end AND `<vault>/sit/SIT.md` exists | Chain-summary MENTION (one line, never auto-run): "Tim UAT butuh test script? `/mega-sdd:emit uat` menghasilkan skenario bisnis 1:1 dari flow + berita acara." | One line in the chain end summary |

These diagnostics run TRANSPARENTLY — chat output includes their summaries inline with phase progress lines. User does NOT need to know they exist as separate commands.

`enrich-semantics` is a removal tombstone — a `kb_flow_staging_missing` advisory (validate-kb.sh) is remediated by a scoped `extract-intelligence` re-run on the affected module, reviewed as usual.

**Manual override**: each diagnostic remains runnable on demand for debugging/one-off use — the user asks by phrase through the front door ("lint units", "cek parallelism", "status module") and the orchestrator runs the matching procedure from `references/diagnostics-procedures.md`. Auto-invocations skip when the user explicitly disables via `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags on the front door / `orchestrate-flow`.

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

`detect-drift` standalone (no chain context) → fresh full scan; ignores bolt snapshots. The auto-gate path uses snapshot reuse per `plugins/mega-sdd/references/shared-snapshot-schema.md`.

## Final summary appendix (--deep)

In `--deep` mode, append to the final summary:

- Total phases proposed, total phases completed, total artifacts produced (flat path list).
- **Auto-integrated diagnostics summary**:
  - Quality metrics from auto lint-units (units HIGH/MEDIUM/LOW counts)
  - DAG depth / sprints from auto analyze-parallelism (inline, plan order)
  - Per-module status from auto list-modules (X/Y modules completed)
  - AGENTS.md emission confirmation (file path + section count)
  - Acceptance-test concerns from execute-bolts handoff: IF `metrics.acceptance_test_concerns: []` is non-empty (bolt subagent flagged implementation passes acceptance test but feels under-validated), surface as: `"⚠ N/M bolts flagged acceptance_test_concern — review for under-validation: <unit_id list>. Harden the affected units' acceptance_test (re-run plan's Step 9.5 adversarial review on those units only — plan/references/adversarial-test-prompt.md §Opt-in subagent mode — and merge the gaps in place; never plan --regenerate, it rewrites every unit), then execute-bolts <unit_id> --force."` — mirrors `execute-bolts/references/halts-and-handoff.md §Post-flight acceptance-test concern harvest`.
  - Deferred open questions (P3/A6): IF the vault carries `open_questions[] status == deferred` (incl. the batched walk's auto-defers), surface as: `"⏸ N OQ deferred (auto-deferred P2/P3 + defer manual) — <tag list>. Jawab kapan saja: resolve-oq."` — the defer is recorded state; this line is its mandated resurface (also in execute-bolts `_summary.md §Deferred open questions` and the non-deep Emit-final-summary step).
  - FSD pending sections: IF the chain ran emit-fsd, read `<vault>/fsd/.citation-map.json` `missing_sources[]` — non-empty → surface: `"ℹ FSD emitted with N pending section(s) (sources not yet produced: <list>) — full coverage after the missing artifacts exist (bolts → per-unit binding.json; codebase-map.md / binding.md only on readable layout-2 vaults), then re-run /mega-sdd:emit fsd."`
- **Predictive preflight metrics:**
  ```yaml
  metrics:
    predictive_warnings_count: <int>     # count of non-fatal predictive warnings shown
    predictive_halts_count: <int>        # count of fatal predictive halts (always ≤1 since fatal halts STOP)
  ```
- **Phase context** (appended when vault.json has a `phase` field):
  - IF `vault.phase < vault.phase_total` (legacy numbered-tree KB only — PRD-kontrak KBs are single-phase, module = phasing unit): "Phase <N> of <M> complete. To start Phase <N+1> (MANUAL checkpoint — not auto-routed): `plan --kb=<KB dir> --phase=<N+1>`. Plan: `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md §Phase <N+1>`." (`--phase=N` is the numbered-tree KB flag — `plan/references/kb-input.md §Consumption — legacy numbered-tree grammar`.)
  - IF `vault.phase == vault.phase_total`: "Phase <N> of <M> complete. All phases finished."
  - IF `phase` field absent (single-phase project OR pre-phasing vault): omit the phase context section.

  This complements the execute-bolts handoff `next_action.hint` — orchestrate-flow surfaces the same info at chain-summary level for user visibility.

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: routing-rules (decision matrices the chain is built from), predictive-checks (the preflight catalog this loop consults), and handoff-consumption (the per-skill validation gate inside the execution loop).
