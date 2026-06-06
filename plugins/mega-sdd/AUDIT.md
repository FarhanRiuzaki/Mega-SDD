# Mega-SDD Deep Audit (advisor-guided)

> Living document. Findings are **verified against current code**, severity-bucketed.
> Spine: per-skill **prose claims vs. enforcement reality** (hook+validator) vs. **prose that can no-op**.
> Anchor: `CLAUDE.md` (the contract — 5 invariants + enforcement doctrine).
> Discipline: subagent output is *leads*, not findings — every claim verified before it lands here.

Started 2026-06-05. Status: Batches 0–4 complete + v4.2.0 shipped. **Round 2 (2026-06-06): deep end-to-end + subagent-decomposition audit — in progress.**

---

## ROUND 2 — End-to-end pipeline + subagent-decomposition audit (2026-06-06)

User ask: verify the whole pipeline runs correctly flow-by-flow (no miss/gap), and — grounded in real research on how Claude Code subagents work — that heavy skills correctly auto-decompose into subagents/batches/pipelines when one pass is too heavy.

### Research grounding (claude-code-guide agent, doc-cited)
- **Hooks fire on subagent tool calls** — `hooks.md` defines `agent_id` "present only when the hook fires inside a subagent call." Foreground AND background.
- **Subagents CANNOT spawn subagents** — hard depth-1 limit (`agent-sdk/subagents.md`: "Subagents cannot spawn their own subagents… the runtime prevents nesting regardless"). Confirmed in-harness: a dispatched general-purpose agent has **no Agent/Task tool**.
- Background subagents change only permission mode (auto-deny on prompt), not hook firing.
- Canonical "too-heavy → decompose": Agent tool for a few tasks (isolated ctx, parent sees only final msg, pass paths explicitly); Workflow tool for dozens+; between-stage gates = separate runs; hooks inherited by all (cost multiplies).

### FINDING L1 [RESOLVED — not a defect; moat NOT bypassed on fan-out]
**Empirically settled the linchpin.** Probe: 3 sentinel `references/*.md` files at telemetry count 0, each read by a different actor → all logged `ref_loaded`:
- `oq-resolution.md` (foreground subagent): 0 → 2 ✓
- `constitution-drift.md` (background subagent): logged ✓
- `pagerank-targeting.md` (main thread control): logged ✓

**PostToolUse hooks DO fire on subagent (fg+bg) writes/reads.** So the moat quality gates fire on bolt-subagent writes — the fan-out path does **not** bypass enforcement. Good news for correctness.

### FINDING L2 [S3 — false-premise rationale in plugin docs]
`hooks/post-tool-use:13-18` header asserts "subagent-internal tool calls … are NOT visible to the parent's PostToolUse hook … Fork-A limitation"; `references/telemetry-schema.md §Emission mechanism` and `execute-bolts/references/batch-and-fanout.md:71` ("parent thread MUST explicitly re-invoke the project-wide quality validators after each batch") are all premised on that claim. **L1 proves the premise FALSE** — hooks DO fire on subagent writes. The resulting over-protection is harmless (re-scan is redundant belt-and-suspenders), but the rationale + telemetry under-count claim are wrong. Fix: correct the comments; note the re-scan is defense-in-depth, not load-bearing.
- **Sharpened (telemetry under-count cause):** the under-count is **real but for a different reason** — telemetry is *lossy by construction* (PostToolUse `async:true` in `hooks.json:34`; every emit is `>> … 2>/dev/null || true`, exit-0-always), not because subagent calls are invisible. So keep the "ref_loaded UNDER-COUNTS" caveat, but re-attribute it to async/lossy emission, and delete every "subagents are invisible to PostToolUse" sentence.

### FINDING L3 [S1 — CONFIRMED structural break] `execute-bolts --per-squad` violates the subagent depth-1 limit
The v4 per-unit flow: `execute-bolts` (main-thread **controller**) dispatches `bolt-implementer` → `spec-reviewer` → `code-quality-reviewer` via the Agent tool (`superpowers-bridge.md:20-49`). `superpowers-bridge.md:12` states the controller MUST stay main-thread **"(Subagents cannot spawn subagents — that's why the controller stays in the main thread.)"**

But `--per-squad` (`squad-subagent.md:12-57` + `superpowers-bridge.md:97-99`) dispatches **one subagent per squad** (general-purpose, `run_in_background`) and makes THAT subagent the per-unit controller ("Use the mega-sdd:execute-bolts skill recursively for each unit" → which dispatches the three bolt agents). That is **depth 2 → forbidden**. `squad-subagent.md:87` even promises "`--per-squad --parallel` → N squad subagents, each running multiple unit subagents internally" — structurally impossible.

**Internal contradiction:** `superpowers-bridge.md:12` (controller must be main-thread, *because* nesting is forbidden) vs. `superpowers-bridge.md:99` + `squad-subagent.md` (a squad subagent IS the controller). Empirically confirmed: a dispatched subagent has no Agent tool, so the squad subagent cannot dispatch the bolt agents → either hard-fails or silently degrades to inline implementation (losing the two-stage review = the moat's quality enforcement).

**Scope:** `--per-squad` + `--per-squad --parallel` broken. Single-unit + `--all` (sequential) fine (main-thread controller, depth-1 dispatch). `--all --parallel` is **salvageable at depth-1** but documented with stale pre-v4 prose → see **L5** (the SELF-TRACE resolved it as a doc fix, NOT a structural break).

**Conservative fixes (defer to user):** (a) restructure squad fan-out as a **main-thread loop over squads** (controller stays main-thread; parallelism moves to concurrent bolt-agent dispatch across squads) — preserves two-stage review; (b) document `--per-squad` as running bolts inline without agent review (degraded, explicit); or (c) deprecate `--per-squad`. NOT fixing this pass — audit-first.

### FINDING L4 [today S3-latent → S2-on-parallel: fail-open aggregator + non-atomic state writes] (SELF-TRACE 2)
> **Reconciliation (advisor):** L4's *torn-write race* is **gated by L3 + L5 — there is no live concurrent-write path today.** `--per-squad` is structurally broken (L3); `--all --parallel` is stale/uncorrectly-implemented prose (L5); sequential bolts fire PostToolUse one-at-a-time (no torn write). So the **race cannot fire right now.** What IS live today is the fail-open hole. The actionable coupling: **whoever fixes L3/L5 (enables real parallelism) MUST ship atomic-write in the same change** — else turning parallelism on activates a silent moat bypass. Per [[feedback_propagation_within_iter]], that belongs in one iter, not deferred.

**Live hole (fail-open on corrupt state, any cause).** The PreToolUse aggregator (`hooks/pre-tool-use:264-321`) loads each gate state file via `def L(fn): try: json.load(...) except Exception: return None`, and every gate is `if d and d.get("status")=="FAIL"`. **A corrupt/unparseable/absent state file FAILS OPEN** — `L()` returns `None`, the gate is skipped, a bolt that should be blocked slips through silently. This holds for ANY corruption cause (killed mid-write, disk-full), independent of the race. The aggregator cannot tell *parse-error* (suspicious — was a FAIL there?) from *absent* (legitimately never run).

**Latent race (activates when parallelism is implemented correctly).** The state files are **OVERWRITE-not-append, no atomic write, no lock** — `validate-ui-quality.sh:142-147`, `validate-unit-spec.sh:114`, `validate-bolt-artifacts.sh:236`, `validate-vault-binding-coverage.sh:202` all do `open(state_file,"w"); json.dump(...)` (no tmp+`os.replace`, no flock). Hooks fire on subagent writes (L1), so once concurrent bolt dispatch exists, two validators `open(…,"w")` the same file simultaneously → torn JSON → fail-open.

**Self-healing semantics (why even then it's S2 not S1).** Scans are **project-wide current-truth full-glob** (`validate-ui-quality.sh:339-351` re-walks the whole tree every run; PostToolUse fires *after* each write lands). A real FAIL can't be clobbered by a later PASS — no later scan sees a tree *without* the offending file. The only failure mode is a torn write coinciding with the gate read.

**Exposed-file scoping (corrected, advisor catch).** During `--all --parallel` bolt *code* writes, the concurrently-overwritten **aggregator-read** files are `.ui-quality-blockers.json` (view sub-case), `.cross-cutting-state.json` (model sub-case), **and `.unit-spec-state.json`** — the latter via the `run_validator_and_emit` block (`post-tool-use:566-614`) which sits *outside* the path sub-cases and fires `validate-unit-spec` (+ bolt-artifacts, vault-binding-coverage, …) on **every** Write|Edit. The moat `.validation-blockers.json`, `.flow-coverage-state.json`, `.sibling-consistency-state.json` are written only inside the `units/U-*.md` sub-case (`post-tool-use:372-413`) → single-threaded in generate-units → not exposed during parallel bolts (but `--per-squad` would write units concurrently and expose the moat).

**Conservative fixes (defer to user):** (a) atomic write everywhere — `json.dump` to `<state>.tmp` then `os.replace()` (atomic on POSIX) — kills the torn write; **ship this together with any L3/L5 parallelism fix**; (b) for the **moat file only**, make the aggregator fail-closed-with-surface on a *parse error* of `.validation-blockers.json` (a corrupt moat state should HALT, not pass) — distinct from absent. NOT fixing this pass — audit-first.

### FINDING L5 [S3 — stale pre-v4 prose on the `--all --parallel` path] (SELF-TRACE 1)
`SKILL.md:25` ("`--parallel` — dispatch independent units via `subagent-driven-development`") and `batch-and-fanout.md:16` ("dispatch the group **as a subagent batch** via `subagent-driven-development`") describe the **pre-v4** dispatch. The v4 authoritative design (`superpowers-bridge.md:12`) keeps the controller in the **main thread** dispatching `bolt-implementer`+reviewers directly via the Agent tool, *because* nesting is forbidden. `--all --parallel` is **valid at depth-1** when implemented as the main thread issuing several `bolt-implementer` Agent calls concurrently (two-stage review per unit as each returns) — but the stale wording invites a reader to implement it as "a subagent that runs subagent-driven-development" = depth-2 = the same break as L3. (`subagent-driven-development`'s own rules even forbid parallel implementers, so the literal reading is doubly wrong.) **Fix:** reword `SKILL.md:25` + `batch-and-fanout.md:16` to the v4 main-thread concurrent-Agent-dispatch pattern; this is a doc fix, not a structural break. NOT fixing this pass — audit-first.

### Self-traces (DONE — done in main context, not delegated)
- ✅ **`--all --parallel` topology** → resolved as **L5** (stale prose, salvageable depth-1; doc fix).
- ✅ **State-file concurrency race** → resolved as **L4** (torn-write + fail-open aggregator; self-healing semantics, S2).

### Round-2 RESULTS — workflow fan-out (6 lanes, both-sides-cited, every lead verified in main context)

> Method: parallel evidence-gatherers returned cited file:line on both sides; verdicts synthesized + **independently re-verified** here (subagent output = leads, not findings, per [[project_phase2_realrun_evidence]] fan-out-divergence risk). V1–V5 = the verification greps/reads I ran before promoting each lead.

#### Decomposition scoring (thread B of the user ask — "too-heavy → auto-split into subagents + pipeline")
**3 of 4 heavy skills decompose CORRECTLY at depth-1. The one structural break is execute-bolts' squad fan-out (L3), and orchestrate-flow routes into it by default (L6).**

| Heavy skill | Decompose pattern | Depth | Verdict |
|---|---|---|---|
| **extract-intelligence** | 6 waves; W0+W5 main-thread, W1–4 parallel `domain-extractor` subagents (3/4/5/3); 6 between-wave bash gates; split-at-30-files; `--max-parallel` cap (default 3, re-batches nominal 4/5) | depth-1 ✓ (`domain-extractor` has no Agent tool → depth-2 impossible) | ✅ **reference implementation** |
| **scan-codebase** deep-scan | 4 fixed slice-extractors (auth/rbac/ui/libs), main-thread, selective re-dispatch (1–4 stale slices), read-only subagents; size valves = >100k-files CONFIRM halt + 200-symbol truncation | depth-1 ✓ | ✅ correct (parallelism keyed on slice, not file-count — by design). S3 doc-drift: "Step 2.2/2.3" vs "Step 10.5.x" numbering |
| **execute-bolts** single / `--all` sequential | main-thread controller dispatches `bolt-implementer`→`spec-reviewer`→`code-quality-reviewer` per unit | depth-1 ✓ | ✅ correct |
| **execute-bolts** `--per-squad` / `--all --parallel` | squad subagent becomes per-unit controller / stale "subagent batch" prose | **depth-2 ✗ / ambiguous** | ❌ **L3** (broken) / **L5** (stale prose) |

#### New findings (verified)
### FINDING L6 [S2 — auto-route into a broken topology] orchestrate-flow defaults multi-squad to `--per-squad`
`routing-rules.md:57` ("Vault has `squad_count: ≥2`, units exist, some not in bolts → `execute-bolts --per-squad`") + `routing-rules.md:76` ("Default to `--per-squad` (parallel subagent fan-out)"). So the headline `/mega-sdd:auto` UX **silently routes any multi-squad vault into the L3-broken depth-2 path by default** — not a rarely-hit flag, but the default for an entire project class. **Amplifies L3's blast radius.** Confirmed V2. Fix is coupled to L3's fix (don't route into a topology that can't run).

### FINDING L7 [S2 — resume contract self-contradiction] (F6, flagged at spec level — not asserted at runtime)
`orchestrate-flow/SKILL.md:102` ("**No state file** … resumption = CWD inspection rebuilds state") + `handoff-contract.md:697` (resume "does NOT read a persisted state file", phase-granularity) **contradict** `checkpoint-protocol.md:72-78` (under `--auto`, "Orchestrator **reads ALL checkpoints** … `--resume-from=<step-id>` … Skill resumes mid-execution", sub-step granularity). Two resume mechanisms; the checkpoint JSONL *is* a state file; **precedence is unspecified** when both a completed-phase artifact (CWD says skip) AND a mid-skill checkpoint (cursor says resume claim-46) exist for the same phase. Confirmed V3. Behavioral verification deferred (audit-first); spec-level contradiction is itself the defect. *Note:* `checkpoint-protocol.md:61` uses **append-only JSONL with explicit concurrency-safety** — the plugin already knows how to do safe concurrent state; **L4's fix should reuse this pattern** for the gate files.

### FINDING L8 [S3 — producer-only ship; capability gap] extract-intelligence enriched-stages is consumer-blind
`knowledge-base-schema.md:158-162` (v3.72.0+) emits enriched `input_fields` objects + per-stage delta fields (`new_fields_vs_prior` / `hidden_fields_vs_prior` / `promoted_to_mutable_vs_prior` / `dynamic_disclosures`) for progressive-disclosure intent. **generate-intent never reads them** — grep across `skills/generate-intent/` = **0 hits** (V1). "Copy verbatim" (vault-contract.md:104) carries the bytes into `04-flows.md`, but the delta semantics are never modeled downstream → the captured maker→checker field-promotion / show-hide intent **dies at the intent phase, never reaching units/bolts**. By-design back-compat-tolerant (producer: "a consumer that doesn't read the enriched fields simply uses `name` — no consumer breaks"), so NOT a contract break — but a textbook producer-only ship per [[feedback_propagation_within_iter]], and squarely relevant to [[project_ui_ux_intelligence_integration]] (the progressive-disclosure intent the UI/UX work wants to preserve is being captured then dropped one phase later).

### FINDING L9 [S2 — seam] execute-bolts → detect-drift drops scope
execute-bolts emits `suggested_args: []` **and** a `scope:` block in the same handoff (`halts-and-handoff.md:343,355`); it never seeds `--scope` into detect-drift's `suggested_args`. orchestrate-flow's consumption loop injects `--auto` unconditionally (`handoff-consumption.md:151`, so `--auto` is NOT lost) but passes the empty `suggested_args` through, and there is **no separate scope-seed** (V4 = 0 hits). detect-drift's *own* downstream emission DOES propagate scope (`handoff-contract.md:515`) — an **asymmetry**: in a multi-squad / scope-filtered run, detect-drift falls back to a full scan instead of inheriting the bolt batch's scope. Aligns with [[feedback_seamless_pipeline]]. (Blast radius partly overlaps L3/L6.)

### FINDING L10 [S3 — overclaimed enforcement] fan-out-parity validator claims a blocking gate it doesn't have
`validate-fanout-parity.sh:27` + `post-tool-use:407-408` assert "PreToolUse **Branch 12** gates execute-bolts on `fanout_parity_divergence` COUNT" — but the aggregator never reads `.fanout-parity-state.json` (V5: `grep -c fanout hooks/pre-tool-use` = **0**), and `CLAUDE.md` lists fan-out-parity as **Advisory** (`/mega-sdd:analyze` only). The **check itself is GOOD** — obligation-presence parity (`## UI contract` section + `type: render` acceptance test across view-bearing siblings), exactly the spec-obligation semantics the user wants, NOT a richness proxy (this **refutes the B3-2 worry**). The defect is the stale comments overclaiming enforcement — the "prose that claims enforcement it doesn't have" anti-pattern; comments weren't updated when the gate was demoted to advisory.

#### B3-2 worry → RESOLVED (not a finding)
fan-out-parity checks **spec obligations**, not context richness (see L10) → the original B3-2 concern does not hold; only the stale-enforcement comment (L10) remains.

---

## Severity bar

- **S1 (correctness/moat):** breaks an invariant, a gate that can't fire, prose that claims enforcement it doesn't have.
- **S2 (consistency/seamless):** command↔skill drift, doc/version lag, stale flag, fan-out divergence — ships undetected, erodes trust.
- **S3 (polish):** wording, narrative lag, nice-to-have ergonomics.

Bias: conservative fixes (plugin is shipped + working).

---

## Batch 0 — surface inventory + `/analyze` blind-spot baseline

### Surface inventory (verified)
- skills = 17 · commands = 25 · agents = 4 (`bolt-implementer`, `spec-reviewer`, `code-quality-reviewer`, `domain-extractor`)
- hooks: `hooks.json`, `pre-tool-use` (18.3K), `post-tool-use` (31.3K), `session-start` (27K), `stop` (16.7K), `run-hook.cmd`
- validators = 30 (all under `scripts/validate-*.sh`)
- reference dirs = 15 · total reference `.md` = 114

### FINDING B0-1 [S2 — observation, not a defect] `/mega-sdd:analyze` is project-scoped; no plugin self-test exists
**Claim (CLAUDE.md) — accurate:** "`/mega-sdd:analyze` is the consolidated consistency surface — runs the validators, emits CONSISTENCY-REPORT.md." It never claims to self-audit the plugin, so there is **no false-enforcement claim** here.

**Reality (verified `scripts/run-analyze.sh`):** the `validator_results` dict (full ~30-validator roster) keys every validator to a project `state_file` (`.validation-blockers.json`, `.unit-spec-state.json`, …) run with `--cwd` = a **downstream mega-sdd project root**. So `/analyze` validates a *consumer project's* vault/units/bolts output — by design.

**Observation (not a correctness defect):** no plugin-facing self-test exists, so plugin-internal drift (command↔skill flag parity, doc accuracy, version stamps) has no automated guard. This is consistent with — though does not by itself prove — why drifts this session shipped undetected (the `--out` contradiction, `--max-parallel` stale default, `--refresh` phantom flag, scenario drift, README version lag). They don't live in a project state file.

**Scope note:** a `validate-plugin-self.sh` + harness would be *new infrastructure*, which runs against the standing constraints (minimum new files, reuse-over-reinvent, conservative fixes — plugin is shipped+working). **This audit's job is to find gaps, not ship a harness.** Recorded as a note for the user to decide separately. The structural read (project-scoped validators) is sound; the "zero self-validation" framing rested on one 5-string grep — kept as a note, not a headline.

---

## Batch 1 — Enforcement spine (prose-claim vs hook-reality) — VERIFIED

Method: traced every enforced gate's 4-link chain (skill prose → PreToolUse hook → validator → state file) and **read the actual code** for every claim below. Subagent leads that did not survive my own trace are marked "lead dropped."

### FINDING B1-1 [S2 — moat-adjacent wording] Invariant #2 claims more than the hook deterministically enforces
**Claim (CLAUDE.md invariant #2):** "The CONFLICT gate blocks — **unresolved CONFLICTs** block downstream unit/bolt generation. This is enforced by the PreToolUse hook on execute-bolts (reads `.validation-blockers.json`)…"

**Verified reality:**
- The execute-bolts PreToolUse aggregator (`hooks/pre-tool-use:274-278`) blocks when `.validation-blockers.json` `status == "FAIL"`.
- That status is set by `scripts/validate-handoff-binding-units.sh:153-197`, where `status = "FAIL" if drops`. A **drop** = a binding OQ-ID/CONFLICT-ID that **no unit frontmatter cites** (propagation discipline). The validator's own header (line 6) states its scope: "OQ-ID **propagation** discipline." It scans CONFLICT-IDs by regex (line 112) and checks *citation*, never *resolution status*.

**The gap:** the deterministic hook enforces **ID propagation**, not CONFLICT **resolution**. An *unresolved* CONFLICT that happens to be cited in some unit's frontmatter produces **no drop → PASS → execute-bolts not blocked**. The literal "unresolved → blocked" guarantee is therefore carried by **prose** in generate-units (`SKILL.md:36,48` "REFUSE"), not by the hook. CLAUDE.md attributes a resolution-blocking guarantee to the hook that the hook does not implement (it implements a propagation proxy).

**Why it's S2 not S1:** the gate *does* fire (on drops); the moat is not absent — it's a propagation gate plus a prose resolution-gate. The defect is a **truthfulness gap in the contract's own wording**, which is exactly the class this audit exists to close ("prose that claims enforcement it doesn't have" — here the *contract* over-claims the *hook*).

**Conservative fix (recommend a, defer b):**
- (a) **doc-only, truthful:** reword invariant #2 to "enforced by the PreToolUse hook as a binding-ID **propagation** gate (every binding OQ/CONFLICT-ID must be traced into a unit), plus a prose resolution-refusal in generate-units." Zero mechanism change.
- (b) **mechanism (defer, needs user):** extend the validator to FAIL on any CONFLICT-ID lacking a resolution marker. Bigger; touches the moat; only if user wants the stronger deterministic gate.

### NOTE B1-2 [by design, no finding] render-test is the *only* unit-spec halt_type that hard-blocks
`pre-tool-use:288-292` blocks execute-bolts on `count(issues where halt_type=="render_test_missing")`, NOT on `status==FAIL`. Other unit-spec halts (`unit_underspecified`, `hard_rule_unparseable`, `starterkit_rule_citation_missing`) are detected by `validate-unit-spec.sh` but do **not** hard-block at execute-bolts. **Verified this matches the doctrine:** the skill prose for those (`generate-units/SKILL.md:109,134-136`) says STOP **at generation time** ("do not write the unit"), and only `unit-schema.md:278` claims a hook block — for render-test alone. This is the intended `rule→gate→hook` escalation (render-crash on empty model is critical+un-promptable → escalated to hook; the rest stay prose). No finding.

### NOTE B1-3 [by design] anti-self-bypass has no skill prose and no validator script
Verified: the guard is inline in `pre-tool-use:354-367` (regex over the decoded Bash command), protects `.validation-blockers.json` / `.plan-pending` / `.replan-budget` / `.iter-classifier.json`. It is a *guard*, not a pipeline gate — correctly has no skill-prose claim and no `scripts/validate-*.sh`. No finding.

### LEAD TO VERIFY (Batch boundary) handoff-validation Branch 1a reads Stop-hook-written state
Subagent lead: `.handoff-validation-state.json` is written by the **Stop** hook (`hooks/stop`), but read for blocking at PreToolUse Branch 1a — a one-response latency window. NOT yet traced by me. Flag for Batch 2 verification before it lands (potential S3 timing note, or non-issue if the Stop-write precedes any cross-skill handoff).

---

## Batch 1b — Inter-skill data contract — VERIFIED (partial)

### FINDING B1b-1 [S2 — internal inconsistency] dispatch-prompt budget caps disagree across the two files SKILL.md cites as authoritative
**Verified — three sources, two contracts:**
- `execute-bolts/SKILL.md:67`: target **≤9KB**, hard cap **12KB**.
- `references/context-enrichment.md:37-40` (assembly logic): `cap_hard=12288`, `cap_target=9216`, `cap_t1=2048`, `cap_t2=10240`; restated at line 327 `(cap 10240, hard 12288)`.
- `references/bolt-dispatch-prompt.md`: header line 5 "T2 ≤5KB … Total ≤7KB (hard cap 10KB)"; line 276 `(cap 5120, hard 10240)`; the block at lines 330-333 `cap_hard=10240, cap_target=7168, cap_t2=5120` — and line 318 declares **itself** "the canonical contract for execute-bolts v2.8.0+."

SKILL.md:67 explicitly points the assembler to **both** files ("Per `bolt-dispatch-prompt.md` (template) + `context-enrichment.md` (assembly logic)"), yet they disagree on hard cap (10KB vs 12KB), target (7KB vs 9KB), and T2 budget (5KB vs 10KB). SKILL.md sides with context-enrichment.md (12KB), making bolt-dispatch-prompt.md's numbers the **stale** ones. An agent that follows bolt-dispatch-prompt.md (the file literally labeled "canonical contract") will truncate T2 at 5KB and halt at 10KB — different dispatch behavior than the live assembly logic.

**Conservative fix:** doc-only — update the stale numbers in `bolt-dispatch-prompt.md` (lines 5, 152, 276, 330-333) to match the canonical `context-enrichment.md` / SKILL.md (target 9216 / hard 12288 / T2 10240). No mechanism change.

### Data-contract leads DROPPED on my own trace (not findings)
- **A-1** `design_system.provenance` not injected at bolt-time → `context-enrichment.md:113` *explicitly* excludes it ("audit-only"). Intentional. Dropped.
- **A-2** `constitution_hash` not read by generate-units → consumed by `detect-drift` (different skill, by design per `vault-contract.md:421`). Dropped.
- **C-5a** UI-quality state keys → **verified clean**: writer emits `summary.scaffold_tells_matched`/`required_elements_missing` (`validate-ui-quality.sh:424-427`) = exactly the gate's read (`pre-tool-use:304-306`); SKIP writes a string summary but the gate only reads under `status==FAIL`. Dropped.
- **C-6a** `design_system_not_injected` written, only `status` read → advisory validator; status roll-up is the contract. Dropped.

### Lower-priority unpaired-field leads (need consumer-trace in Batch 4, likely by-design)
`open_questions_summary` (A-3), `mode_migrate_after` (A-4), `adrs`-via-vault.json (A-5), `grounding_confidence`/`grounding_evidence` (B-3), `mutability` frontmatter (B-5): each is a vault/unit field generate-units/execute-bolts doesn't read **by name** — but plausibly consumed by analyze/resolve-oq/detect-drift or human/audit surfaces, OR read as markdown not via the JSON index. Recorded as leads, NOT findings, pending Batch-4 consumer trace.

---

## Batch 2 — Command↔skill parity — VERIFIED (result: HEALTHY)

The exact drift class the session kept hitting. **Result: parity is healthy.** The 3 prior drifts confirmed **fixed** (`--out` default, `--max-parallel` default=3 both sides, `--refresh` real on both sides). Subagent surfaced 22 "drift candidates"; on my own trace **almost all are by-design over-claims:**

- **D1–D10, D20–D21 (orphan commands / route-to-script) — DROPPED.** CLAUDE.md's "command↔skill parity" = "never *delete* a pipeline command," NOT "every command must have a skill." `analyze`, `lint-units`, `list-modules`, `migrate-paths`, `migrate-rules`, `replay`, `update-plugin`, `validate-handoff`, `enrich-semantics` are utility/inline commands that legitimately route to inline procedures or scripts. `using-mega-sdd` is the anchor skill (no command, by design). Not defects.
- **D13–D16, D19, D22 (argument-hint omits advanced skill flags) — DROPPED to S3-optional.** An `argument-hint` is a terse CLI hint, not an exhaustive flag list; the command *body* documents the rest. No contradiction. Brevity-by-design.
- **D17/D18 (`--plan`/`--act`/`--no-telemetry` parity) — DROPPED.** Verified `orchestrate-flow/SKILL.md:50` handles `--act`/`--plan-then-act`, and `auto.md:8` "both invoke the same skill" — the parity claim holds; the orchestrate-flow hint is just terser than auto's.

**Net: command layer is consistent.** The prior consistency sweep worked. No S1/S2 here.

---

## Batch 4 — Version / doc truth — VERIFIED

- **Plugin SemVer — CLEAN.** `plugin.json:3` = `4.1.0` == `marketplace.json:12` = `4.1.0`. Single-source-of-truth invariant holds.
- **CHANGELOG — not a defect.** No plugin-level `CHANGELOG.md`; the canonical one is repo-root `../../CHANGELOG.md` (335KB, updated today). Monorepo convention. Dropped.

### FINDING B4-1 [S3] `analyze/SKILL.md` is missing a `version:` frontmatter stamp
Verified: `skills/analyze/SKILL.md:1-4` frontmatter has `name` + `description` only — **no `version:`**. Every other first-party skill carries one (bind-codebase 2.0.0, execute-bolts 2.1.0, …). CLAUDE.md: "Skills: per-skill `version:` in frontmatter." Fix: add `version: 1.0.0` (or current). (The 4 `_vendored/` skills also lack stamps — correct, they carry upstream superpowers versions; not a finding.)

### FINDING B4-2 [S3, known] README release-narrative still says `### v4.0.0 — lean-core (current)`
Verified: `README.md:5` stamp = `4.1.0`, `README.md:44` manifest comment = `v4.1.0`, but `README.md:73` narrative heading = `### v4.0.0 — lean-core (current)`. Already flagged in [[project_ui_ux_intelligence_integration]] as the stamp-only-scope follow-up. Fix: add a `### v4.1.0` narrative section (or retitle), drop stale `(current)`.

### FINDING B4-3 [S3, trivial] `replay.md:33` example uses non-canonical `vault_version: "1.2.0"`
Verified: canonical `vault_version` is `"1.1"` (`vault-contract.md:13`); the replay snapshot *example* at `commands/replay.md:33` shows `"1.2.0"` — a schema version that doesn't exist and uses 3-part vs the 2-part convention. Illustrative-only, but misleading. Fix: change example to `"1.1"`.

---

## Resolved leads (investigated, no defect)
- **handoff-validation Branch 1a timing** (`pre-tool-use:200-250`): reads `.handoff-validation-state.json` written by the Stop hook, which fires *between* cross-turn producer→consumer handoffs; allows producer self-fix (225-226) + gives explicit unblock path (243). No exploitable latency window found. Dropped.

---

## CONSOLIDATED FINDINGS (audit result)

**The skills work correctly by design.** Enforcement spine traced end-to-end: every enforced gate has a real validator+hook+state-file chain. Command parity is healthy. No S1 defects.

| ID | Sev | One-line | Fix type |
|----|-----|----------|----------|
| B1-1 | **S2** | CLAUDE.md invariant #2 says the hook blocks "unresolved CONFLICTs"; the hook actually blocks binding-ID **propagation drops** (resolution-blocking is prose-only) | doc reword (a) / mechanism (b, defer) |
| B1b-1 | **S2** | Dispatch-prompt budget caps disagree across the two files SKILL.md cites authoritative (12KB/9KB/10KB vs 10KB/7KB/5KB) | doc sync (stale file → canonical) |
| B4-1 | S3 | `analyze/SKILL.md` missing `version:` stamp | add field |
| B4-2 | S3 | README narrative stuck at `v4.0.0 (current)` while stamp is 4.1.0 | add v4.1.0 section |
| B4-3 | S3 | `replay.md` example uses non-canonical `vault_version 1.2.0` | fix example |

All fixes are **doc-only / conservative** (no rails change, no new mechanism, no new files) except B1-1 option (b) which is deferred to user choice.

---

## Batch 3 — Intelligence / seamlessness — VERIFIED

Two confirmed S2 gaps (both advisory-layer + already-tracked in user feedback memory; **not fixed this conservative pass** — recommended as a future iter):

### FINDING B3-1 [S2, advisory — aligns with [[feedback_seamless_pipeline]]] execute-bolts→detect-drift snapshot reuse is prose-only
Verified `handoff-contract.md:393-394`: the execute-bolts handoff names `suggested_skill: mega-sdd:detect-drift` with **`suggested_args: []`** (empty). The `--auto-gate` / `--reuse-bolt-snapshots` coupling that makes detect-drift reuse bolt postflight snapshots (6× faster) is set by orchestrate-flow **prose**, not carried in the handoff args. If a consumer follows `suggested_args` literally, detect-drift does a full fresh re-scan. This is the exact handoff-smoothness roughness the user already flagged for an Iter-30 field-test follow-up.

### FINDING B3-2 [S2, advisory — aligns with [[project_phase2_realrun_evidence]]] fan-out parity checks spec obligations, not context richness
Verified `validate-fanout-parity.sh:208-209`: the parity obligations are only `ui_contract` (`## UI contract` section) + `render_test` (`type: render` acceptance test). It does **not** check `starterkit_relevance` consistency across view-bearing siblings. So two siblings touching the same view glob — one with a rich `starterkit_relevance` array, one with an empty/missing one — get **divergent** T2 bolt-dispatch context yet both PASS parity. This is the documented "U-026 rich / U-027–031 drifted" fan-out-divergence failure pattern; the validator catches the symptom (missing section) not the cause (divergent context).

### Lower-priority Batch-3 leads (S3 / by-design, recorded not fixed)
- OQ recommend: `scan_citations` "closest-match" prose path lets a recommendation cite a non-exact anchor; no validator verifies a non-KB `file:line` exists on disk (anti-halu softness, mitigated by user-confirm + `recommend` mode). S3.
- OQ-DESIGN-SOURCE blocking-fallback not distinguished from recommend by `validate-vault-oqs.sh` — **by design** (anti-halu: no map match → blocking). Not a defect.
- detect-drift handoff `artifacts:` lists bolt *dirs* not `postflight.json`; partial completion → silent full re-scan. S3 robustness.
- extract-intelligence Wave 1 parallel agents run before the glossary exists (1.B/1.C can't cross-ref 1.A terms) — **by design** (Wave 1 *creates* the glossary). Edge.

---

## ✅ Fixes applied this pass (conservative)

| ID | Sev | Fix | Files | Verified |
|----|-----|-----|-------|----------|
| **B1-1** | S2→**mechanism** | Extended the moat validator to fail-closed on unresolved `### CONFLICT-` headings (resolution check, not just ID propagation) — closes the "cited-but-unresolved" gap; invariant #2 is now genuinely hook-enforced | `scripts/validate-handoff-binding-units.sh` (+ comments/slice label) ; **TDD** `tests/moat/test-conflict-unresolved.sh` (3 cases) | test GREEN; OQ-drop + no-vault regressions GREEN |
| **B1b-1** | S2 | Synced stale dispatch-prompt caps to canonical (target 9KB / hard 12KB / T2 10KB), added a "MUST match context-enrichment.md" pointer | `skills/execute-bolts/references/bolt-dispatch-prompt.md` (lines 5, 152, 230, 276, 330-336) | grep: no stale 5120/7168/7KB/10KB-hard remain |
| **B4-1** | S3 | Added `version: 2.0.0` (matches v4 lean-core sibling cohort) | `skills/analyze/SKILL.md` | — |
| **B4-2** | S3 | Added `### v4.1.0 — UI/UX design intelligence (current)` narrative; demoted v4.0.0's `(current)` | `README.md` | — |
| **B4-3** | S3 | Fixed non-canonical example `vault_version 1.2.0` → `1.1` | `commands/replay.md:33` | — |

**B3-1, B3-2** confirmed but **not fixed** (advisory-layer, already user-tracked, larger than a conservative doc/mechanism fix).

### Versioning (applied)
B1-1 is a rails *strengthening* (the gate now does what invariant #2 always promised). **Plugin bumped 4.1.0 → 4.2.0** (MINOR — new enforcement behavior): `plugin.json` + `marketplace.json` (4.2.0) + `version_note`; README stamp + v4.2.0 narrative (current); repo-root `CHANGELOG.md` [4.2.0] entry. Committed on branch `feat/moat-audit-fixes`.
