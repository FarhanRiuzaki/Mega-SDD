# Iter 63 Performance + Sharpness Design — v4.0.0-Candidate Refactor (Sub-Project 1)

**Status:** Design approved 2026-05-26. **AUDIT-CORRECTED 2026-05-27 → Iter 67.5 Fork A scope lock.**
**Iter target:** Plugin v3.41.0 → v3.42.0 (MINOR — auto-invoke behavior change with backward-compat)
**Driver:** user shift from feature work to performance/sharpness. "Senior engineer collaborator, not verbose assistant."
**Spec author:** brainstorming session (research-driven; superpowers:brainstorming flow)
**Audit source:** `docs/superpowers/audits/2026-05-26-iter-63-performance-audit.md`

> **POST-SHIP CORRECTION (Iter 67.5, 2026-05-27):** Audit `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md` revealed that the runtime claims in §4.2 (Iter 65 classifier + guard), §4.3 (Iter 66 lazy-loading), and §4.4 (Iter 67 Plan/Act) were never artifact-verified and never actually executed in real chain runs. The scripts exist as advisory tools; the gating was prose only. Iter 67.5 retracts the "Runtime SHIPPED" claims, scopes Iter 67.5+ to Fork A (telemetry via hooks + skill-body design vocabulary), and parks all control-plane enforcement as Fork-B-future (Agent SDK / custom runtime). See `plugins/mega-sdd/CLAUDE.md` §"Fork A scope (CURRENT) vs Fork B (FUTURE)" for the canonical statement.
>
> The sections below remain as the *original design intent*; they describe what the system *would* do if a control plane existed. They do NOT describe what runs in Fork A. Treat as forward-looking documentation pending Fork B.

---

## 0. Scope decomposition (3 sub-projects)

This spec covers **Sub-Project 1 (Quick Wins, Iter 63) in detail** + Sub-Project 2 + 3 at roadmap level. Each sub-project gets its own spec → plan → implementation cycle when ready.

| Sub-project | Iters | Plugin range | Status |
|---|---|---|---|
| **SP1 — Quick Wins (this spec)** | Iter 63 | v3.41.0 → v3.42.0 | DETAILED + approved; ship now |
| **SP2 — Architecture Refactor** | Iter 64-70 | v3.42.0 → v3.50.0 | ROADMAP only; each iter brainstormed separately when reached. **~1 week edit work; wall-clock several weeks due to telemetry soak gap (see §4.5).** |
| **SP3 — Foundation Replacement** | Multi-week R&D | v4.0.0 candidate | UNCOMMITTED; explicit fork decision required first |

---

## 1. Research backing (2026 context engineering)

Sources (loaded in brainstorming session, sourced from auto mode WebSearch):

- **LangChain Deep Agents** — 3-tier architecture: hot memory (always loaded) / domain specialists (per task) / cold memory (RAG on-demand)
- **Claude Code tool lazy loading** — 95% context reduction via on-demand tool discovery vs upfront loading
- **Morph / Augment Code 2026** — 40%+ of context budget burned BEFORE agent does real work; 39.9-59.7% of tool-result tokens removable with no perf loss
- **Cline Plan & Act** (v3.78+, April 2026) — Plan mode = cheap non-destructive reasoning; Act mode = expensive execution. **Plan/Act is COMPLEXITY-GATED in Cline, not universal**
- **Context rot research** (Morph, Atlan, Zylos 2026) — Lost-in-middle attention gaps + 30%+ accuracy drop in mid-window + attention dilution as token count grows
- **Token budget thresholds** (industry consensus 2026) — 20K tokens for tool outputs, 85% total context utilization

**Empirical takeaway:** large markdown skill bodies (mega-sdd has 8,174 lines across 15 skills) hit context rot before they hit window limit. Trim is more impactful than expansion.

---

## 2. Audit-measured current state

From [iter-63-performance-audit.md](../audits/2026-05-26-iter-63-performance-audit.md):

| Metric | Value |
|---|---|
| Skill bodies | **8,174 lines** across 15 skills |
| Reference files | **~10,132 lines** across ~50 files |
| Heaviest skills | generate-intent **1,267** / execute-bolts **1,012** / generate-units **826** / orchestrate-flow **764** |
| `generate-intent` reference files | **13** (unmanageable) |
| CHANGELOG | **5,663 lines / 82 versions** |
| Halt taxonomy | **60+ distinct types** |
| TOTAL plugin content | **~18,000 lines** + CHANGELOG |

Plus 7 actionable audit-flagged top wins (TRIM/CONSOLIDATE/DEFER/OVERLAP/HEAVY/AMBIGUOUS categorization).

---

## 3. Sub-Project 1 (Iter 63) — Quick Wins Design

### 3.1 Section 1 — FSD auto-invoke opt-out

**User explicit ask:** FSD generation expensive (pandoc/LaTeX) + low user feedback signal. Flip to opt-in.

**Change:**
- `orchestrate-flow/SKILL.md` Step 6 auto-integrated diagnostics table — `emit-fsd` row flips `default: on` → `default: off`
- `commands/auto.md` adds `--with-fsd` flag (opt-in). Existing `--no-fsd` continues to work as no-op (back-compat)
- `commands/orchestrate-flow.md` same flag pattern
- `commands/emit-fsd.md` standalone command unchanged (user invokes manually for FSD generation)

**Not changed:** emit-fsd skill itself unchanged; can be invoked manually anytime via `/mega-sdd:emit-fsd <vault>`.

**Lines impact:** ~10 edits, 0 new lines. Skill versions: `orchestrate-flow` 3.7.0 → 3.8.0 (MINOR — auto-invoke default change).

### 3.2 Section 2 — Skill body trim (~1,500 line target)

**Strategy:** move-to-references + structural cleanup. NO rewrite (preserves correctness; minimal drift risk).

**Per-skill trim plan:**

| Skill | Current | Target | Strategy |
|---|---|---|---|
| `generate-intent` | 1,267 | ~700 | Move halt-protocol descriptions (already mirrored in `vault-contract.md`); move Iter 35 phase context detail to new `references/phase-context.md`; consolidate 13 reference files where possible |
| `execute-bolts` | 1,012 | ~600 | Move T2 budget tracker procedural detail to `references/t2-budget-tracker.md` (Iter 44 spec content); move saga compensating actions detail to `references/saga-rollback.md` (Iter 45 spec content) |
| `generate-units` | 826 | ~500 | Move adversarial review wiring detail to existing `references/adversarial-test-prompt.md` (consolidate redundant content) |
| `orchestrate-flow` | 764 | ~500 | Move predictive-checks consumer detail to refs (already partial); move handoff validation gate detail to new `references/validation-gate.md` |
| Other heavy skills (>300 lines) | varies | shave 20-30% each | Strip version-stamp prose ("v1.10+, Iter 46:" etc. — git log has this); move worked examples to refs |

**Net effect (tune meta-#3 — math reconciled):**
- Skill bodies (HOT tier, loads every session): 8,174 → ~6,500 lines (**-1,674 line / -20% hot-tier reduction**)
- References (SPECIALIST/COLD tier, loads on-demand): ~10,132 → ~11,132 lines (**+1,000 due to relocation** of content from bodies)
- Pure deletion (version-stamp prose, redundant historical context, mirrored halt descriptions): **~-674 lines net deletion** (small)
- **Plugin total content: ~18,306 → ~17,632 lines (~-3.7% — nearly flat)**

**The win is hot→cold tier RELOCATION, not deletion.** Skill bodies that load every session via anchor drop -20%. Refs grow but load on-demand. Plugin total content nearly flat — claim is NOT line-deletion, it's CONTEXT-WINDOW IMPACT at session start.

**Backward compat:** all existing skills work; refs are loaded by skill body when referenced. Trim is documentation-style; no behavioral change. Iter 66 (SP2) lazy-loading completes the win by making specialist refs truly on-demand.

### 3.3 Section 3 — Command differentiation (keep both, explicit)

**Resolve `/mega-sdd:auto` ↔ `/mega-sdd:orchestrate-flow` ambiguity** without deprecation.

**`/mega-sdd:auto`** — user-facing entry-point. Detects input shape (PRD file / legacy code / brief / vault state) + proposes chain + single confirm. THIS is the marketed "ONE command users need."

**`/mega-sdd:orchestrate-flow`** — power-user lower-level chain executor. Skips input-shape detection (assumes user already knows what to chain). For advanced use (e.g., custom chain composition).

**Doc updates:**
- Both `commands/auto.md` + `commands/orchestrate-flow.md` get cross-reference block at top
- Both clarify scope explicitly in description line
- README documents `/mega-sdd:auto` as primary; `/mega-sdd:orchestrate-flow` as power-user

**No deprecation; no breaking changes; no merge.**

### 3.4 Section 4 — Per-iter ceremony aggressive opt-in (DETERMINISTIC classifier — DUAL EVALUATION POINT)

**User concern (tune meta-#1):** Classifier temporal kebalik in original spec. Ceremony decision is PRE-work (before commit exists); version-bump labeling is POST-work. Same enum, two evaluation points — state explicitly.

**Two evaluation points, same enum output (PATCH | MINOR | MAJOR):**

| Evaluation point | When | Inputs | Use-case |
|---|---|---|---|
| **EP1: Ceremony gating** | BEFORE work starts (pre-commit) | working-tree state + upfront scope estimate | Decides whether to emit spec/plan/audit docs |
| **EP2: Version-bump labeling** | AFTER work done (post-commit) | `git diff HEAD~1 HEAD` of completed commits | Decides PATCH/MINOR/MAJOR version bump in plugin.json + CHANGELOG label |

**EP1 (pre-work) inputs — deterministic estimates:**
- `est_files_changed` = `git diff --stat HEAD | wc -l` (working tree vs HEAD) + plan-doc-declared targets if exists
- `est_halt_enum_diff` = scan in-flight changes to vault-contract.md halt enum (grep working tree diff)
- `est_new_skill_dir` = check working tree for new `plugins/mega-sdd/skills/<new>/` directories
- `breaking_marker` = user's explicit flag `--iter-type=<>` OR scope-statement in brainstorming session
- Fallback when no working-tree changes yet (start-of-work): use user's stated iter-type from brainstorming session intent → default PATCH if absent

**EP2 (post-work) inputs — deterministic completed-diff:**
- `files_changed` = `git diff --name-only HEAD~1 HEAD | wc -l`
- halt-enum diff = `git diff HEAD~1 HEAD -- plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | grep -c "^[+-].*type:.*|"`
- new skill dir = `git diff HEAD~1 HEAD --name-status | grep "^A.*plugins/mega-sdd/skills/.*/SKILL.md"`
- handoff-contract field diff = same pattern on handoff-contract.md
- breaking change marker = `git log -1 --pretty=%B | grep -c "BREAKING CHANGE:"`

**Classifier criteria (same enum, applied at both EPs):**

| Iter type | Criteria (machine-checkable at both EPs) | Required artifacts | Optional |
|---|---|---|---|
| **PATCH** | `files_changed ≤ 5` AND no halt-enum diff AND no new skill dir AND no `BREAKING CHANGE:` marker | CHANGELOG entry only | (nothing) |
| **MINOR** | `files_changed 5-15` OR new halt-enum entry OR new field in handoff-contract OR existing skill body modified | CHANGELOG entry | Spec (only if brainstorming skill invoked) |
| **MAJOR** | new skill dir OR `BREAKING CHANGE:` commit marker OR `files_changed > 15` | CHANGELOG + spec + plan | Audit (only if explicitly requested) |

**Drift handling (EP1 vs EP2 mismatch):**
If EP1 classified PATCH but EP2 reveals MAJOR criteria met (e.g., scope grew during work): emit drift warning + retroactively generate missing artifacts (spec/plan) under accelerated rules (compressed prose; not full ceremony). Log to telemetry as `ceremony_classifier_drift` event for Iter 68 analysis.

**Precedence rule (uniform across plugin, both EPs):**
```
explicit user flag (--iter-type=major) > classifier output > default (PATCH)
```

**No LLM judgment in any path. Output is enum: PATCH | MINOR | MAJOR.**

**Estimated effect:** ~70% of future iters skip spec+plan ceremony (most iters are PATCH-classified per audit's recent-iter analysis).

### 3.5 Section 5 — CHANGELOG archive rotation

**Cutoff:** v3.27.0+ stays in main `CHANGELOG.md` (~28 recent versions). v3.0.0-v3.26.x rotates to `CHANGELOG-ARCHIVE.md` at repo root.

**Main `CHANGELOG.md` header** adds: `For pre-v3.27.0 history, see [CHANGELOG-ARCHIVE.md](CHANGELOG-ARCHIVE.md).`

**Net effect:** main CHANGELOG drops 5,663 → ~1,500 lines (73% reduction). Archive readable but not loaded into context unless user explicitly opens it.

**Future rotation rule (added to plugin CLAUDE.md):** when main CHANGELOG exceeds 2,000 lines OR 30 versions, oldest 50% rotate to archive.

### 3.6 Section 6 — Version + release

- Plugin **v3.41.0 → v3.42.0** MINOR (auto-invoke FSD default change is behavior change; backward-compat preserved via `--with-fsd` flag)
- `orchestrate-flow` **3.7.0 → 3.8.0** MINOR (Step 6 default change)
- Heavy-trim skills get PATCH bumps per change (generate-intent, execute-bolts, generate-units): all retain frontmatter `version: <current+0.0.1>`

---

## 4. Sub-Project 2 Roadmap (Iter 64-70, ~1 week EDIT WORK + soak gap)

**Timeline clarification (tune meta-#2):** ~1 week refers to ACTIVE edit work across Iter 64-70. BUT Iter 68 (telemetry analyze) requires accumulated real-usage data from Iter 64+ — soak gap = wall-clock several weeks of real-world usage between Iter 64 ship and Iter 68 analysis. Iter 64-67 + 69-70 can ship at edit-pace; Iter 68 PAUSES the sequence until soak window completes.

**Realistic wall-clock:** ~1 week edit work + 3-4 weeks soak gap = ~4-5 weeks total elapsed for SP2 completion. SP3 gate at Iter 68 cannot fire faster than soak window allows. If telemetry analysis runs with insufficient data (< 14 days OR < 10 chain runs), it produces "data insufficient" report instead of conclusions — SP3 gate stays closed until enough data accumulated.

Each iter brainstormed separately when reached. This is the COMMITTED sequencing — not detailed design.

### 4.0 Iter 63.5 — Deferred skill body trim sprint (RECLASSIFIED + HOT/COLD TRIAGE INSIDE per post-ship review)

Iter 63 deferred T5-T9 skill body trim (~1,500 line hot-tier relocation across 9 skills) to a dedicated follow-up iter. Post-ship review (2026-05-26) caught 3 issues with the original framing — corrections below.

**Reclassification per Iter 63 classifier rules (dogfooding):**

Original framing called Iter 63.5 a PATCH iter. Per the classifier rules shipped in Iter 63 to `plugins/mega-sdd/CLAUDE.md`:
- MINOR trigger: "existing skill body modified" — YES, all 9 skill bodies modified
- MAJOR trigger: `files_changed > 15` — likely yes (9 skill bodies + multiple new ref files = ~15-20 files)

**Two valid paths (pick one before Iter 63.5 starts):**

| Path | Classification | Implication |
|---|---|---|
| **A. Honest classification** | MINOR (or MAJOR if file count tips over) | Iter 63.5 gets full ceremony: spec doc (this entry stands as inline spec) + plan doc per writing-plans (atomic per-skill task sequence) + CHANGELOG entry. Dogfoods classifier. |
| **B. Explicit carve-out in rules** | PATCH with carve-out | Amend classifier in `plugins/mega-sdd/CLAUDE.md` to add carve-out: "pure documentation relocation (file split with semantic verification + zero behavior change) = PATCH regardless of file count". Carve-out criteria must be deterministic (no LLM judgment). Risk: weakens classifier. |

**Recommendation:** Path A. Iter 63.5 gets ceremony — it's a meaningful refactor across 9 skills, not a trivial fix. Dogfoods the new classifier in practice.

**Hot/cold triage pulled INTO Iter 63.5 scope (per post-ship review):**

Original framing: "move to references" + Iter 66 (SP2) lazy loading completes the picture. Post-ship correction: **move-to-references only reduces hot context if moved content is SPECIALIST/COLD** (not loaded every session). If moved content is HOT (still loaded every session via cross-ref), the trim adds indirection without hot-context win — repeating the CHANGELOG framing error structurally.

Pull lightweight tier triage INTO Iter 63.5 — do NOT wait for Iter 66:

For each block targeted for relocation, BEFORE the cut-paste:
1. **Audit "is this HOT?"** — does every skill invocation read this block? Manual inspection of skill procedure (does the procedure step that loads this block fire every session, or conditionally?).
2. If HOT → KEEP IN BODY (trim other things instead OR re-evaluate whether the block can be condensed without relocating).
3. If SPECIALIST (loaded per-task subset) → relocate to ref file; body keeps step header + cross-ref + load-pointer at correct procedure step.
4. If COLD (rarely loaded; on-demand) → relocate to ref file; body keeps single-line summary; cross-ref optional.

Without this triage, "successful trim" by line count could deliver 0 hot-context reduction.

**Semantic verification criteria (NOT line counts) per post-ship review:**

Line count is a vanity metric. Real verification for each trim commit:

1. **Load-pointer integrity** — every block moved to a ref file has a load-pointer in the body at the procedure step where it should be read. No "moved to refs but never referenced from body."
2. **No ref orphan** — created ref files are actually cross-referenced from body. No "ref file created but never linked."
3. **End-to-end coherence** — skill body reads coherent without the cut content. Test: another engineer (or fresh subagent) can execute the skill body following only the body — references load on-demand when body says "see references/X.md for Y." No silent dependencies on cut content.

Verification command pattern per commit:
```bash
# 1. Load-pointer integrity
for ref in <ref-files-created-this-commit>; do
  grep -q "references/$(basename $ref)" <skill>/SKILL.md || echo "ORPHAN ref: $ref"
done

# 2. No ref orphan
grep -rn "references/$(basename $ref)" <skill>/ || echo "Created ref $ref unused"

# 3. End-to-end coherence
# Manual: read skill body top-to-bottom. Every cross-ref `references/X.md` must
# tie to a step where the procedure says "load X.md to do Y." Cross-refs should
# READ as "see <ref> for detail" with body still semantically complete.
```

**Iter 63.5 scope (revised):**

- Hot/cold triage of T5-T9 trim targets (BEFORE relocation)
- Per-skill trim commits with semantic verification (NOT line-count verification)
- Reclassify Iter 63.5 as MINOR per classifier (Path A; dogfood) OR add explicit carve-out (Path B; risk-bearing) before commits start
- Atomic per-skill commits with semantic verification gate per commit
- Document achieved hot-context reduction (real reduction, not "line count went down")

**Estimated effort:** 3-5 hours dedicated session per skill (4 heavy + 5 medium = ~10-15 hours total), reflecting honest scope.

### 4.1 Iter 64 — 3-tier context architecture + START telemetry collection (SCHEMA LOCKED PRE-SOAK per post-ship review)

**Tune #1 applied:** telemetry SPLIT into collect-vs-analyze. **Collection starts Iter 64** (cheap append-only `<project>/.mega-sdd/memory/telemetry.jsonl`). Iter 68 = analyze/enforce phase. Rationale: tier assignment (Iter 64), Plan/Act (Iter 67), budget (Iter 69) all need historical data; if instrumentation starts at Iter 68, downstream iters have only days of history. Decouple instrument from analyze.

**Post-ship review correction (2026-05-26):** soak data CANNOT be backfilled. Whatever Iter 64 does NOT log, Iter 68 cannot analyze. Schema MUST nail down ALL Iter 68/69/70 needs BEFORE Iter 64 ships. Lock list below.

### Iter 66a fix-forward correction (2026-05-27 — POST-IMPLEMENTATION)

**Empirical gap discovered post-Iter-67 ship:** Iter 64 locked the schema + shipped script-side emitters (classify-iter.sh + check-recursion-budget.sh) but assumed skill bodies would emit `ref_loaded` / `skill_invoked` / `turn_loaded_summary` via markdown-instructed convention. Verification grep returned ZERO hits in `plugins/mega-sdd/skills/`. The convention was a fiction; soak window was collecting nothing.

**Root cause (re-frame):** the model cannot precisely count its own context tokens. Iter 64 schema even acknowledges this with `estimated_tokens` fields. Markdown-instructed emission was structurally wrong — only the harness has deterministic byte/line counts.

**Iter 66a fix (v3.47.0, MINOR):**

- New: `plugins/mega-sdd/hooks/post-tool-use` — PostToolUse hook, matcher `Read|Skill`, emits `ref_loaded` (filtered to mega-sdd paths only) + `skill_invoked` (filtered to `mega-sdd:*` / `using-mega-sdd`).
- New: `plugins/mega-sdd/hooks/stop` — Stop hook, emits `turn_end_marker` per agent turn. Only fires if telemetry.jsonl already exists (no pollution in non-mega-sdd projects).
- Updated: `plugins/mega-sdd/hooks/hooks.json` registers PostToolUse + Stop alongside existing SessionStart.
- Updated: `telemetry-schema.md` adds `turn_end_marker` event_type + new "Emission mechanism" section (hooks-based, with markdown skill-body emission downgraded to "best-effort").
- Aggregation pivot: `turn_loaded_summary` is no longer expected live — Iter 68 derives it offline from `ref_loaded` events bracketed by adjacent `turn_end_marker` events. This is the correct design (per-turn aggregation needs a turn-boundary signal only the harness owns).
- Soak gate REFRAMED: clock starts at **Iter 66a ship**, not Iter 64. Pre-66a telemetry.jsonl files (if any) are empty. ≥14 days + ≥10 runs counted from 66a verified-write date.

**Pre-condition for soak activation:** Iter 66a hooks MUST be observed writing telemetry.jsonl in at least ONE real chain run on a real project (e.g., TF Import). Until verified, soak window is NOT counting toward Iter 68 prerequisites.

**Schema lock policy honored:** the lock forbids removing/renaming fields and changing types/required-status. Adding `turn_end_marker` to the `event_type` enum is an additive change (explicitly allowed per schema doc §"Frozen-schema policy"). No existing field touched.

**Iter 66b (deferred):** lazy-load tuning still depends on post-soak telemetry. 66a unblocks data collection; 66b consumes the data.

### Telemetry schema (LOCKED Iter 64 ship; cannot evolve mid-soak)

Line schema in `telemetry.jsonl` (one JSON object per line, append-only):

```json
{
  "ts": "<ISO8601 timestamp>",
  "skill": "<skill name, e.g., generate-intent>",
  "event_type": "skill_invoked | ref_loaded | halt_fired | tier_classification_decision | iter_classifier_output | iter_classifier_drift | activation_outcome",
  "iter_classifier": {
    "ep": "EP1 | EP2",
    "output": "PATCH | MINOR | MAJOR",
    "criteria_matched": ["..."],
    "explicit_flag": null | "patch|minor|major"
  },
  "token_count": {
    "estimated_input": <int>,
    "estimated_output": <int>,
    "reference_loads": [{"path": "...", "estimated_tokens": <int>}]
  },
  "loaded_per_turn": {
    "turn_id": "<UUID per agent turn>",
    "skill": "<skill that loaded this content this turn>",
    "lines_loaded": <int>,
    "tokens_loaded": <int>,
    "breakdown_by_tier": {
      "hot": {"lines": <int>, "tokens": <int>},
      "specialist": {"lines": <int>, "tokens": <int>, "refs_loaded": ["..."]},
      "cold": {"lines": <int>, "tokens": <int>, "refs_loaded": ["..."]}
    }
  },
  "activation_outcome": {
    "skill": "<which skill was invoked>",
    "outcome": "success | halted | user_aborted | downstream_failure",
    "false_positive_signal": "user_explicit_skip | wrong_skill_invoked | overlap_with_other_skill | null",
    "downstream_skill_invoked_within_chain": "<other skill name or null>"
  },
  "tier_classification_decision": {
    "ref_path": "...",
    "declared_tier": "HOT | SPECIALIST | COLD",
    "loaded_this_session": true | false,
    "load_step": "<procedure step where loaded, or 'never'>"
  },
  "payload": { "<event-specific fields>": "..." }
}
```

**Schema rationale (each field traces to a downstream consumer):**

| Field | Consumed by | Why needed |
|---|---|---|
| `ts` | Iter 68 time-series analysis | Trend over soak window |
| `skill` + `event_type` | Iter 68 skill hit frequency | Which skills invoked most |
| `iter_classifier.output` | Iter 68 classifier accuracy + Iter 69 budget tuning | Distribution of iter types over time |
| `iter_classifier.criteria_matched` | Iter 68 classifier audit | Are inputs catching the right cases? |
| `iter_classifier.explicit_flag` | Iter 68 override frequency | Do users override classifier often? Signal of misclassification |
| `token_count.estimated_input` | Iter 68 token-per-skill aggregate | Which skills heaviest in practice |
| `token_count.reference_loads` | Iter 68 hot/cold reality check | Are SPECIALIST refs actually loaded per-task, or always? Validates tier discipline |
| `activation_outcome.outcome` | Iter 68 activation accuracy | Did invoked skill achieve its goal? |
| `activation_outcome.false_positive_signal` | Iter 68 false-positive rate | Hardest metric to capture — see ACTIVATION OUTCOME LABELING below |
| `tier_classification_decision.loaded_this_session` | Iter 68 tier discipline audit | Was HOT actually loaded? Was COLD never loaded? Validates Iter 66 lazy loading payoff |
| `loaded_per_turn.lines_loaded` + `tokens_loaded` | **§9.4 NEW METRIC (post-Iter-63.5 reframe)** | The actual metric that matters — turn-level context cost. Replaces dead "skill body line count" metric per Iter 63.5 finding (bodies mostly load-bearing). Iter 68 produces baseline; Iter 66 target = ≥30% reduction in median. Cannot be backfilled — schema captures from day 1. |
| `loaded_per_turn.breakdown_by_tier` | Iter 66 lazy-loading manifest tuning | Empirical evidence of which refs load WHEN. SPECIALIST/COLD refs that never load → confirm tier; SPECIALIST refs that load every turn → reclassify HOT; HOT refs that rarely load → reclassify SPECIALIST. Data-driven manifest, not human guess. |

### Activation outcome labeling — the hard metric

**Problem:** activation accuracy (false-positive rate) is the trickiest metric — cannot be measured automatically without outcome label per invocation. User-explicit-skip is automatic (user pressed Cancel → log `user_explicit_skip`). But "wrong skill invoked" requires human label OR heuristic.

**Iter 64 strategy:**
- Automatic signals (no user effort):
  - `outcome: user_aborted` when AskUserQuestion Cancel hit
  - `outcome: halted` when halt fires
  - `outcome: downstream_failure` when next-step skill in chain fails AND failure trace points back to current skill's handoff
  - `outcome: success` when handoff status = completed AND chain proceeds
- Semi-automatic signal:
  - `false_positive_signal: overlap_with_other_skill` when 2+ skills invoked within 60s of each other AND latter's input was previous's output (overlap heuristic)
- Manual signal (user opt-in):
  - User can run `/mega-sdd:telemetry label <invocation-id> false-positive` to retroactively mark a skill invocation as wrong-skill. Stored as separate label event.

**If activation accuracy can't be captured reliably:** Iter 68 documents this as a known limitation. Other metrics (skill hit freq, token-per-skill, tier discipline) still actionable.

### Soak window requirements

Iter 68 analysis can fire ONLY if BOTH conditions met:
- ≥ 14 calendar days elapsed since Iter 64 ship
- ≥ 10 real chain runs logged (not test runs)

**Real pipeline usage during soak is REQUIRED** — user-side discipline. Recommended: run mega-sdd on at least one real project (e.g., TF Import Phase 2 — mentioned in audit as upcoming pipeline usage). If soak window passes with <10 runs OR <14 days: Iter 68 emits "DATA INSUFFICIENT" report instead of conclusions; SP3 gate stays closed.

**Scope:**
- Codify 3-tier model per skill in plugin docs (hot/specialist/cold)
- Mark which references are HOT (always-loaded) vs SPECIALIST (per-task) vs COLD (RAG-on-demand)
- **Start telemetry.jsonl append** with schema LOCKED above
- Activation outcome labeling automatic + semi-automatic + manual paths wired
- Telemetry opt-out via `--no-telemetry` flag (privacy)
- No analysis logic yet — just collection. Schema MUST be complete pre-ship; cannot backfill.

### 4.2 Iter 65 — Complexity classifier + anti-recursive guard (2 separate modules, same iter)

**Tune #5 applied:** classifier + guard = different concerns, separate modules, can ship same iter for sequencing convenience.

**Iter 65 CONCRETE DELIVERABLES (tune meta-#4 — what Iter 65 actually builds):**

Iter 63 only documents the classifier criteria + guard rules as CONVENTION in CLAUDE.md (no runtime artifact). Iter 65 builds the executable mechanism:

1. **`plugins/mega-sdd/scripts/classify-iter.sh`** — executable bash script wrapping the git/grep commands; output is JSON `{iter_type: "PATCH|MINOR|MAJOR", criteria_matched: [...], evaluation_point: "EP1|EP2"}` for both pre-work and post-work invocation
2. **`plugins/mega-sdd/scripts/check-recursion-budget.sh`** — bash script that reads `<project>/.mega-sdd/.replan-budget` ephemeral state file; tracks active task's re-plan count + re-validate count; exits non-zero if cap exceeded (orchestrator translates to halt)
3. **Orchestrate-flow integration** — orchestrate-flow Step 3 invokes `classify-iter.sh` at chain start (EP1); Step 7 (final summary) invokes again at chain end (EP2); telemetry event logged on drift
4. **Skill body invocation pattern** — skills that gate behavior on complexity (Iter 67 Plan/Act gating, Iter 69 budget enforcement) invoke `classify-iter.sh` at procedure start (caching result in handoff metadata for single-classifier-per-chain discipline)

**Without these concrete artifacts, Iter 65 would be a no-op** (the convention from Iter 63 would just sit in CLAUDE.md without runtime enforcement). Iter 65 ships the enforcement layer.

**Module A: Deterministic complexity classifier**

Specified in Section 4 above. Single source of truth for PATCH/MINOR/MAJOR enum. Used by:
- Iter 63 Section 4 iter-ceremony rule (which artifacts to emit)
- Iter 67 Plan/Act gating (when to plan vs direct act)
- Iter 69 budget enforcement (per-tier context thresholds)

**Module B: Anti-recursive guard (formal spec)**

Codified as plugin-wide rule (added to `plugins/mega-sdd/CLAUDE.md`):

```
RULE 1 — Re-plan triggers (CLOSED ENUM, no judgment):
  - execution_failed (commit failed / test failed / halt fired)
  - ambiguity_increased (new contract mismatch detected POST-plan)
  - contract_mismatch (handoff field TYPE drift caught at validation gate — STRICTLY this only)

RULE 1.5 — Tune #4 explicit exclusion (per user clarification):
  - bind-codebase CONFLICT is NOT a re-plan trigger. CONFLICT hard-gate is human-halt
    (user resolves via resolve-oq OR vault edit). Guard MUST NOT loop binding gate
    into re-plan cycles. Scope of contract_mismatch is HANDOFF FIELD TYPE DRIFT ONLY.

RULE 2 — Hard caps per task (CONFIGURABLE DEFAULTS, tune post-Iter 68):
  - max_replan_count: 2 (DEFAULT — only magic number without empirical evidence;
    Tune #2 explicitly flagged for revisit post-Iter 68 telemetry analysis)
  - max_revalidate_count: 3 (DEFAULT — same caveat)
  - Exceeded → halt (NAMING DEFERRED to Iter 65 implementation, per tune meta-#5):
    Iter 65 evaluates reuse-first options BEFORE creating new halt enum entry:
    (a) Reuse `bolt_repeated_partial_failure` semantic (existing N-retry-exhausted halt;
        generalize from execute-bolts-only to "any task hitting hard retry cap")
    (b) Add subtype to `quality_gate_failed` (subtype: `replan_budget_exceeded` |
        `revalidate_budget_exceeded` — pattern from Iter 53/54 subtype discriminator)
    (c) LAST RESORT only: new halt enum entry `replan_budget_exceeded`
    Iter 65 ships the decision + impl. Iter 63 spec defers naming to avoid
    pre-committing to halt enum growth (Fork-A debt concern §5.2).

RULE 3 — No validating-the-validation:
  - If validation step itself fails, halt directly — DO NOT spawn meta-validation
  - Validators are LEAF NODES in execution graph, not internal nodes
  - "Plan to validate the validation plan" is recursion → prohibited
```

### 4.3 Iter 66 — Lazy reference loading — **MAIN LEVER for hot-context reduction** (post-Iter-63.5 reframe)

**Post-Iter-63.5 reframe (per user direction):** Iter 63.5 confirmed skill bodies are mostly load-bearing — only ≈7 lines OBVIOUS-removable across 9 skills. "Trim 1,500 lines" was largely illusory. This shifts Iter 66 from "refinement that completes Iter 63.5's picture" → **THE main lever for hot-context reduction in SP2**.

**Premise change:** the content in skill bodies doesn't shrink (it's load-bearing). What changes is WHEN it loads — conditional/on-demand vs always-loaded. Iter 66 doesn't move content; it changes the load discipline.

**Architecture:**

Skills declare per-reference loading discipline at frontmatter or in a manifest:
- `HOT` — always loaded when skill body loads (e.g., `vault-contract.md` halt enum is always needed for any halt emission)
- `SPECIALIST` — loaded ONLY when the specific procedure step requires it (e.g., `t2-budget-tracker.md` loaded only when execute-bolts hits Step 4.5.a.5; `phase-context.md` loaded only when generate-intent --phase flag set)
- `COLD` — loaded ONLY via explicit grep/RAG when user request matches (e.g., individual scenario walkthroughs; archived halt descriptions)

**Lazy-load implementation** (markdown-driven; no runtime code):
- Skill body uses conditional cross-ref pattern: `*If condition X: load `references/Y.md` per Step Z*` instead of always emitting the content inline
- Anchor skill (using-mega-sdd) reads only HOT tier of each skill on session start; SPECIALIST/COLD tiers stay on disk until conditional triggers
- New skill body convention: every cross-ref to a reference file declares its tier (HOT/SPECIALIST/COLD) at the cross-ref site

**Tier classification source (per-skill, manifest-style):**

Each skill ships a `references/_manifest.yaml` (or in SKILL.md frontmatter):
```yaml
references:
  vault-contract.md: HOT       # halt enum always needed
  phase-context.md: SPECIALIST  # only when --phase flag set
  saga-rollback.md: SPECIALIST  # only when --rollback flag set
  conflict-resolution.md: COLD  # only when bind_conflict halt fires
```

**Data dependency on telemetry (Iter 64 → Iter 68 → Iter 66):**

Iter 64 starts logging `tier_classification_decision` + `loaded_this_session` per ref load (LOCKED schema per §4.1). Iter 68 analyzes 14+ days of soak data to validate which refs are TRULY hot vs cold in practice. Iter 66 uses that empirical data to set per-skill manifests — NOT human guess.

**Without telemetry data:** Iter 66 would guess HOT/COLD wrong (same risk as Iter 63.5 blind relocation). Data-driven is non-negotiable per post-ship review.

**Success criterion (Iter 66):**

After Iter 66 ships + 14-day re-soak window: `lines_loaded_per_turn` median drops by ≥30% vs Iter 64 baseline. If <30%: lazy-loading discipline insufficient OR baseline already lean. Result audit feeds back into manifest tuning.

**Iter 66 timing:** post-Iter-68 analysis (when soak data exists). Cannot ship before Iter 68 — would be guessing.

### 4.3.1 (was 4.3) — original Iter 66 sketch (superseded by reframe above)

Telemetry from Iter 64 used to validate which refs are actually hot vs cold (post-Iter 68 analysis tunes the discipline).

### 4.4 Iter 67 — Plan/Act mode per skill — COMPLEXITY-GATED via Iter 65 classifier

**Tune #3 applied: Plan/Act is NOT universal default.**

Plan-mode is cheap reasoning (Cline pattern); Act-mode is expensive execution. Gating per Iter 65 classifier:

| Iter complexity | Plan/Act behavior |
|---|---|
| PATCH | Direct act (no plan phase) — economics dictate |
| MINOR | Optional plan (user opt-in via `--plan` flag) |
| MAJOR | Plan → Act mandatory; explicit transition required |

Universal-plan rejected — violates economics goal (cheap → cheap; expensive → planned).

### 4.5 Iter 68 — Telemetry ANALYZE phase + SP3 gate

**Tune #1 applied:** Iter 64 = collect; Iter 68 = analyze. Iter 68 reads accumulated telemetry.jsonl (likely 30-60 days of data by this point) and produces:

- Skill hit frequency report (which skills invoked most/least)
- Token-per-skill aggregate (which skills heaviest in practice)
- Activation accuracy (false-positive skill invocations)
- Tier-classification decision log analysis (validate hot/specialist/cold predictions vs actual loads)

**Output:** `docs/superpowers/telemetry/iter-68-analysis.md` — data-driven baseline for tuning Iter 69/70 + gate decision for SP3.

**"Prove gains" gate for SP3:** must point to specific metrics from this analysis. No SP3 work without empirical evidence.

### 4.6 Iter 69 — Token budget enforcement (data-driven thresholds)

Uses Iter 68 telemetry to tune per-tier context thresholds:
- Hot tier budget (default 20K tokens per research industry consensus)
- Specialist tier per-skill budget (data-driven from token-per-skill report)
- Cold tier on-demand (no upfront budget)

Extend `execute-bolts` T2 budget tracker pattern to ALL skills. Total context budget enforced at 85% of model window (industry standard).

### 4.7 Iter 70 — Skill consolidation evaluation (data-driven)

Read telemetry from Iter 68. Consolidate only skills with empirically low hit-frequency or high overlap. Candidates flagged by audit (NOT acted on without data):
- `diff-vault` + `detect-drift` + `resolve-oq --binding` (same "compare 2 ground truths" algorithm)
- `extract-intelligence` + `scan-codebase` (both wave-dispatched walkers)

**Tune #2 applied:** also revisit Iter 65 magic numbers (max_replan=2, max_revalidate=3) using re-plan distribution data.

---

## 5. Sub-Project 3 R&D — UNCOMMITTED + Explicit Fork Decision Required

**Tune #3 applied:** Plan/Act-as-universal-default REJECTED. Deepen complexity-gated pattern instead.

### 5.1 Strategic fork (MUST be resolved before SP3 work starts)

**Tune #5 applied with #3:** explicit decision inputs + acknowledgment of Fork A debt.

| Fork | Identity | Implication |
|---|---|---|
| **A. Correctness layer** | Mega-SDD sits ON TOP OF Claude Code / VSCode / Cline / other runtimes. Provides anti-halu rails + memory + handoff contracts. Runtime is someone else's problem. | Lighter touch. SP1 + SP2 sharpening makes this fork strong. v4.0.0 = VSCode extension that LAYERS over Copilot/Cline. |
| **B. Runtime itself** | Mega-SDD replaces the agent runtime. Owns LLM dispatch loop + tool execution + permission model + UI. | Heavier. Cline-pattern. v4.0.0 = standalone extension that ships its own runtime (Anthropic SDK / multi-provider). Much larger scope. |

**Decision inputs (machine-evaluable when SP3 reached):**

1. **SP2 telemetry results** (Iter 68 analysis): does mega-sdd's anti-halu value-add justify lighter-touch layer, or do runtime concerns dominate?
2. **User base composition**: do users primarily use Claude Code (Fork A natural fit) or are they multi-IDE / runtime-agnostic (Fork B better)?
3. **Host runtime availability**: do Claude Code + Cline + Cursor + VSCode Agent plugins cover enough use-cases that Fork A scales? If host runtimes have gaps in skill execution / memory / anti-halu, Fork B becomes necessary.

**Decision rule:** Fork chosen when SP3 starts, based on input data above. NOT chosen by drift.

### 5.2 Fork A debt acknowledgment (per tune #3)

**"SP2 keeps us in Fork A" applies to NEW WORK ONLY — not existing B-ward debt.**

Mega-SDD has been drifting toward Fork B since v2.0:
- Own halt taxonomy (60+ types) — Fork A may not need full taxonomy if host runtime provides error semantics
- Own execution model (skill bodies as agent instructions) — Fork A may simplify to typed manifests
- Own memory layer (3 scopes × 4-7 files) — Fork A may delegate to host runtime memory

**If Fork A chosen at SP3:** acknowledge existing B-ward artifacts may need unwind/deprecate work. SP3 spec MUST include explicit debt list + migration path.

**If Fork B chosen at SP3:** existing artifacts amortize over MAJOR breaking version. SP3 = own runtime build-out.

### 5.3 SP3 candidate scope items (revisited at SP3 brainstorm time)

Not committed; for reference:

- Semantic skill graph (activation-rule-driven loading)
- Structured context (typed manifest) vs markdown prose for hot tier
- Deepen complexity-gated Plan/Act (NOT universal — per tune #3)
- Always-on context budget enforcement at 85% with auto-compression
- IF Fork B: own runtime (Cline pattern)
- IF Fork A: deeper integration with host runtimes (Claude Code plugin API + VSCode Agent plugin API)

---

## 6. Unified complexity axis (single source of truth)

Iter 65 deterministic classifier drives THREE downstream consumers — NO parallel config surfaces:

```
                       ┌─────────────────────────────────────┐
                       │  Iter 65 deterministic classifier   │
                       │  (input: git/fs counts;             │
                       │   output: PATCH | MINOR | MAJOR)    │
                       └────┬────────────┬───────────────┬───┘
                            │            │               │
                ┌───────────▼───┐  ┌─────▼──────┐  ┌─────▼─────────┐
                │ Section 4     │  │ Iter 67    │  │ Iter 69       │
                │ iter-ceremony │  │ Plan/Act   │  │ budget        │
                │ rule (this    │  │ gating     │  │ enforcement   │
                │ iter)         │  │            │  │               │
                └───────────────┘  └────────────┘  └───────────────┘

Precedence (uniform across plugin):
  explicit user flag > classifier output > default (PATCH)
```

---

## 7. Anti-recursive guard formal spec (folded with binding CONFLICT exclusion per tune #4)

Codified Iter 65 in plugin CLAUDE.md (preview here for spec completeness):

```
RULE 1 — Re-plan triggers (closed enum, no LLM judgment):
  execution_failed | ambiguity_increased | contract_mismatch

RULE 1.5 — Explicit exclusion (tune #4):
  bind-codebase CONFLICT is NOT a re-plan trigger.
  CONFLICT hard-gate stays human-halt (user resolves via resolve-oq OR vault edit).
  Guard MUST NOT loop binding gate into re-plan cycles.
  contract_mismatch is SCOPED STRICTLY to handoff field TYPE drift caught at Iter 33 F4
  validation gate — NOT broader semantic disagreement.

RULE 2 — Hard caps per task (configurable defaults — tune #2):
  max_replan_count: 2 (DEFAULT — revisit post-Iter 68 telemetry analysis)
  max_revalidate_count: 3 (DEFAULT — same caveat)
  Exceeded → halt (NAMING DEFERRED to Iter 65 — reuse-first evaluation:
    bolt_repeated_partial_failure generalization OR quality_gate_failed
    subtype OR new enum entry as LAST RESORT. Per tune meta-#5.)

RULE 3 — No validating-the-validation:
  Validators are LEAF NODES; do not spawn meta-validators.
  Validation failure → halt directly. Never "validate the validation."
```

---

## 8. Iter 63 (SP1) Implementation scope

**Atomic deliverables:**

1. **Section 1 (FSD opt-out):** edit `orchestrate-flow/SKILL.md` Step 6 + `commands/auto.md` + `commands/orchestrate-flow.md`
2. **Section 2 (skill trim):** move-to-references + structural cleanup for generate-intent, execute-bolts, generate-units, orchestrate-flow, + 5 medium-trim skills
3. **Section 3 (command differentiation):** edit `commands/auto.md` + `commands/orchestrate-flow.md` cross-links
4. **Section 4 (ceremony classifier):** add classifier criteria + precedence rule to `plugins/mega-sdd/CLAUDE.md`
5. **Section 5 (CHANGELOG rotation):** create `CHANGELOG-ARCHIVE.md` at repo root with v3.0-v3.26.x entries; trim main `CHANGELOG.md` to v3.27.0+; add archive cross-ref in main header; document future rotation rule in `plugins/mega-sdd/CLAUDE.md`
6. **Section 6 (release):** plugin.json v3.41.0 → v3.42.0; orchestrate-flow 3.7.0 → 3.8.0; heavy-trim skills PATCH bumps; READMEs version refs; CHANGELOG entry

**Plus:**

7. Update `plugins/mega-sdd/README.md` + root `README.md` audit table (Iter 63 + roadmap reference)
8. Spec doc itself (this file) committed
9. Plan doc generated by writing-plans (per current process — last iter under OLD ceremony rules; PATCH iters under new rules skip plan doc)

**Total files touched:** ~25 (5 modifications per heavy skill trim + 7 surface touches + version refs + READMEs).

**No new skills. No new halt types. No new schemas. Backward-compatible behavior change (FSD flag).**

---

## 9. Success criteria

### 9.1 Iter 63 SP1 (shipped v3.42.0)

- [x] `/mega-sdd:auto` runs WITHOUT FSD emission by default; `--with-fsd` opts in
- [x] CHANGELOG.md line count: 5,663 → 1,806 (cold-tier/repo hygiene; NOT hot context)
- [x] `plugins/mega-sdd/CLAUDE.md` has deterministic classifier criteria + precedence rule + anti-recursive guard preview (Iter 65 full impl)
- [x] `/mega-sdd:auto` + `/mega-sdd:orchestrate-flow` docs both have cross-reference blocks + scope clarification
- [x] No new halts; no new skills; no new schemas
- [x] Plugin v3.41.0 → v3.42.0 ships clean

### 9.2 Iter 63.5 OBVIOUS trim (shipped v3.43.0)

- [x] OBVIOUS-only trim with semantic verification per commit (load-pointer / no ref orphan / end-to-end coherence)
- [x] Classifier dogfood Path A — MINOR classification correctly applied per deterministic criteria
- [x] "If ragu → biarin di body" rule honored — 4 skills skipped where pattern was borderline

### 9.3 Iter 63.5 finding — Iter 66 reframing

**Result of Iter 63.5:** ≈7 net lines removable as OBVIOUS-only across 9 heavy/medium skills. Confirms premise: **Mega-SDD skill bodies are mostly load-bearing, not bloat.** "Trim ~1,500 lines" framing was largely illusory.

**Dead metric (removed from success criteria):** ~~"Skill body line count: 8,174 → ~6,500"~~ — invalid; body size is a proxy that doesn't measure what we actually care about (turn-level context window cost). Replace with §9.4 metric.

### 9.4 NEW SP2 metric — `lines_loaded_per_turn` / `tokens_loaded_per_turn`

**What we actually care about:** how much context loads per agent turn, not how big the skill body files are. Body of 1,267 lines that loads conditionally is cheaper than body of 300 lines that loads every turn.

**Measured via Iter 64 telemetry** (LOCKED schema per §4.1) — captured day-1 since cannot be backfilled. Per-turn aggregate:

```
loaded_per_turn = sum_over_skill(
  hot_tier_lines_loaded +
  specialist_tier_lines_loaded_this_turn +
  cold_tier_lines_loaded_this_turn
) per turn
```

**Target setting deferred** to Iter 68 analysis (need soak baseline first). Iter 66 success criteria will be data-driven against the Iter 64-68 baseline measurement.

### 9.5 Hot-tier win positioning (HONEST)

**Currently delivered hot-tier reduction: ≈0.** Iter 63 SP1 + Iter 63.5 delivered:

- ✅ Process integrity: classifier dogfood + semantic verification pattern
- ✅ Runtime recurring saving: FSD opt-out (per-chain pandoc/LaTeX skip)
- ✅ Cold-tier / repo hygiene: CHANGELOG -68% (NOT auto-loaded; archive readable)

**Hot-tier win locked behind:** Iter 66 lazy reference loading (the MAIN LEVER — see §4.3) + Iter 64-68 telemetry soak data validating which refs are truly SPECIALIST/COLD vs HOT.

**No hot-context win claims pre-Iter-66.** Any future iter claiming "context reduction" must point to `lines_loaded_per_turn` metric from telemetry — not file-size proxies.

---

## 10. Out of scope (explicit deferrals for SP1)

- 3-tier context architecture (SP2 Iter 64)
- Telemetry collection start (SP2 Iter 64)
- Complexity classifier impl (SP2 Iter 65 — Section 4 here is RULE doc only)
- Anti-recursive guard runtime enforcement (SP2 Iter 65 — Section 7 here is RULE doc only)
- Lazy reference loading (SP2 Iter 66)
- Plan/Act mode per skill (SP2 Iter 67)
- Token budget enforcement (SP2 Iter 69)
- Skill consolidation (SP2 Iter 70)
- Fork A vs Fork B decision (SP3 prerequisite)
- v4.0.0 work (SP3)

---

## 11. Risks + mitigations

| Risk | Mitigation |
|---|---|
| Skill body trim introduces drift between body and references | Move-to-references preserves content (cut-paste, not rewrite); refs are loaded by body so no semantic gap |
| CHANGELOG archive rotation breaks user bookmarks/links | Main CHANGELOG.md header has prominent cross-ref to archive; archive at repo root (discoverable) |
| Classifier deterministic criteria too rigid (misclassifies real-world iters) | Precedence rule allows explicit `--iter-type=major` override; defaults are conservative (PATCH default for ambiguous case) |
| FSD opt-out surprises users who relied on auto-emit | `--no-fsd` still works as no-op (back-compat); CHANGELOG entry highlights new default; existing users see one extra opt-in step |
| Anti-recursive guard cap values (2 re-plan / 3 re-validate) too tight or too loose | Tune #2 explicitly: defaults are placeholders; Iter 68 telemetry analysis informs revision |

---

## 12. Process notes (this spec under new ceremony rules)

Iter 63 itself = MINOR (classifier: existing skill body modified + new content in CLAUDE.md). Under NEW ceremony rules: CHANGELOG entry + spec (this doc, since brainstorming invoked) but optionally plan doc.

**Decision:** writing-plans skill invoked (current process applies; new rules ship WITH this iter). Future iters under MINOR with NO brainstorm skip both spec + plan.

**Last iter to follow old ceremony fully.** Iter 64+ subject to new classifier.

---

**Approval:** user approved Section 1-6 unchanged + revised roadmap + 5 tunes (telemetry split, configurable defaults, fork inputs explicit + Fork A debt, binding CONFLICT exclusion, classifier/guard separation) on 2026-05-26.

**Post-spec meta-tunes (applied in 2nd-pass user review of written spec):**
- meta-#1: Classifier temporal split (EP1 pre-work vs EP2 post-work) — §3.4
- meta-#2: SP2 timeline clarified (edit work + soak gap = ~4-5 weeks wall-clock) — §0 + §4
- meta-#3: Trim math reconciled (hot-tier relocation -1,674 lines vs net deletion only ~-674 small) — §3.2
- meta-#4: Iter 65 concrete deliverables specified (4 artifacts: classify-iter.sh, check-recursion-budget.sh, orchestrate-flow integration, skill invocation pattern) — §4.2
- meta-#5: `replan_budget_exceeded` halt naming deferred — Iter 65 reuse-first evaluation (bolt_repeated_partial_failure generalize / quality_gate_failed subtype / new enum LAST RESORT) — §4.2 + §7
- cosmetic: "4 tunes" → "5 tunes" consistent throughout

**Next:** writing-plans skill to produce atomic implementation plan for Iter 63 (SP1) scope.
