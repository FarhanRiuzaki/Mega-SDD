# Mega-SDD Deep Audit (advisor-guided)

> Living document. Findings are **verified against current code**, severity-bucketed.
> Spine: per-skill **prose claims vs. enforcement reality** (hook+validator) vs. **prose that can no-op**.
> Anchor: `CLAUDE.md` (the contract — 5 invariants + enforcement doctrine).
> Discipline: subagent output is *leads*, not findings — every claim verified before it lands here.

Started 2026-06-05. Status: Batches 0–4 complete + v4.2.0 shipped. **Round 2 (2026-06-06): deep end-to-end + subagent-decomposition audit — COMPLETE; all findings fixed on branch `fix/round2-audit-pipeline-integrity`.** **Round 3 (2026-06-25, v4.38.0): systematic 9-lane gap sweep over the 54-commit drift since Round 2 — 14 gaps confirmed (0 S1, 7 S2, 7 S3); recorded below, NOT yet fixed (read-only audit).**

## Round-2 RESOLUTION (2026-06-06)

All actionable findings fixed (audit-first held: every finding was surfaced + verified before any edit). Commits by contract:

| Finding | Sev | Fix | Commit / verification |
|---|---|---|---|
| **L1** | — | (not a defect — moat NOT bypassed on fan-out) | empirical probe (Round-2) |
| **L2** | S3 | corrected the false "subagents invisible to PostToolUse" premise → re-attributed under-count to lossy async emission (post-tool-use, telemetry-schema, +execute-bolts fan-out refs) | `fix(docs)…` + `fix(execute-bolts)…` |
| **L3** | S1 | `--per-squad` rewritten as a **main-thread loop** (depth-1, two-stage review preserved) — no squad subagent | `fix(execute-bolts)…` + **test-no-depth2-dispatch.sh** (PASS on fix, FAIL on pre-fix) |
| **L5** | S3 | `--all --parallel` reworded to the v4 main-thread concurrent-Agent pattern (unified with L3) | same commit + same test |
| **L6** | S2 | orchestrate-flow no longer defaults multi-squad into a broken topology (the default path is now valid) | same commit |
| **L4** | S2 | (a) moat file **fails closed on corrupt** in the aggregator; (b) **atomic write** (tmp+os.replace) at all 6 aggregator-read validators — shipped WITH the parallelism enablement | `fix(gate-state)…` + **test-moat-corrupt-fail-closed.sh** (4 cases; discrimination proven vs pre-fix) |
| **L7** | S2 | resume contract reconciled to a two-level precedence (chain = CWD/phase; sub-step = skill checkpoint) | same commit (prose, review-verified) |
| **L9** | S2 | execute-bolts→detect-drift handoff seeds `--scope` when scope-filtered | `fix(handoff)…` |
| **L8** | S3 | generate-intent preserves the enriched stages form (no downgrade) + cross-refs the ui-ux-intelligence design | `fix(generate-intent)…` (prose, review-verified) |
| **L10** | S3 | dropped the stale "PreToolUse Branch 12" enforcement overclaim from fan-out-parity (it is advisory) | `fix(docs)…` |

**New regression tests (enforceable, not prose):** `tests/moat/test-no-depth2-dispatch.sh` (pins the depth-1 invariant across 7 files), `tests/moat/test-moat-corrupt-fail-closed.sh` (pins moat fail-closed). All 3 moat tests pass. Decomposition-scoring verdict: extract-intelligence (waves) + scan-codebase (slices) are the reference depth-1 patterns; execute-bolts squad fan-out was the only break (now fixed).

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

---

## ROUND 3 — systematic gap audit (2026-06-25, v4.38.0)

Nine-lane systematic sweep (moat-spine, factory-line, command-wiring, reference-integrity, test-coverage, doc-consistency, drift-policy, self-analysis, hook-validator-parity). Drift baseline = Round 2 (2026-06-06); 54 commits landed since (Factory Line, graph v4.30.0, .NET packs, design-intelligence, instincts/GateGuard, multi-PRD, compaction advisor, review-panel + L0 code-gates). All L1–L10 remain resolved. Method: parallel finder agents → adversarial verification of every finding (default NOT-A-GAP for documented-intentional / changelog-resolved), each lane pre-loaded with the contract's enforced-list + rejected-capabilities + AUDIT.md by-design notes to suppress false positives. **14 gaps confirmed (0 S1, 7 S2, 7 S3), 4 candidates fully dismissed** (a 5th — anti-self-bypass — was reconciled to a confirmed finding, R3-14, in advisor review). No moat bypass and no broken primary path — the moat is intact. The strongest finding (R3-1) is an enforcement-determinism gap on the new Factory Line: a documented "the loop cannot run hot even if prose is skipped" guarantee the hook does not back on the path it matters. *(Discipline note: subagent output is leads — every R3 finding was independently re-verified against cited file:lines; 5 leads were dismissed when the evidence didn't hold or the item was by-design/historical. The hook-validator-parity lane verification was completed in the main thread after two subagent API stalls.)*

### Confirmed gaps — S2 (consistency/seam) first, then S3 (polish)

#### R3-1 [S2 — misleading enforcement / partial wiring] Anti-spin gate only blocks at execute-bolts; backward re-dispatch of the stuck owning phase is ungated
The Factory Line anti-spin/`phase_stuck` verdict (`.factory-ledger-state.json`) is read by the PreToolUse hook **exactly once**, inside the `SKILL_NAME == mega-sdd:execute-bolts` block — yet on a `phase_stuck`/`anti_spin` ledger the router by definition routes **BACKWARD** to re-run the OWNING phase (bind/scan/units), a `Skill(...)` dispatch that never enters that block. So the deterministic backstop never fires on the dispatch that actually continues the spin.
- **Evidence:** `hooks/pre-tool-use:299` (the only aggregator reading the verdict opens here, closes :386); `:373-377` (sole read of `.factory-ledger-state.json`; repo-wide grep confirms no other reader); `skills/orchestrate-flow/references/factory-routing.md:13-14` (backward route to owning phase) + `:21-22` (false claim: "enforced deterministically … so the loop cannot run hot even if prose is skipped"); `docs/superpowers/specs/2026-06-25-factory-line-queryable-checkpoints-design.md:125` (spec elevates anti-spin to a hook *because* "'Never loop forever' … must be a hook, not a prose promise"); fixtures `tests/fixtures/factory-line/{cap-bad,spin-bad}/.mega-sdd/factory-ledger.json` both model a stuck **bind-codebase** — exactly the case the gate can't block. Backward-dispatch arms (preflight :208, handoff :243, degenerate-map :395) were each checked — none reads the ledger verdict.
- **Why S2 not S1:** execute-bolts *code commits* are still gated on a FAIL ledger (moat-critical action protected); the broken guarantee is the narrower "loop self-terminates even if prose is skipped."
- **Fix:** consult `.factory-ledger-state.json` in the PreToolUse arms that fire on backward re-dispatch of bind/scan/units (or gate at router-dispatch level) so a FAIL ledger blocks the owning-phase re-run, not just the execute-bolts leg.

#### R3-2 [S2 — dead route / misleading recovery instruction] Command + hook prose route users to `/mega-sdd:act` and `/mega-sdd:plan` slash commands that do not exist
Three live user-facing surfaces — a command body, the PreToolUse guard's own recovery error string, and chain prose — instruct users to invoke `/mega-sdd:act` and `/mega-sdd:plan`, but no `commands/act.md`/`commands/plan.md` and no `skills/act`/`skills/plan` exist anywhere.
- **Evidence:** `commands/auto.md:104`; `hooks/pre-tool-use:543` (guard-recovery message naming `/mega-sdd:act` — sharpest instance: it tells a just-blocked user to invoke a non-existent command); `skills/orchestrate-flow/references/chain-execution.md:117,122`. Absence: `commands/` has no `act.md`/`plan.md`; `skills/` has no `act/`/`plan/`; plugin-wide grep returns only these four sites + `references/fork-a-recovery-map.md:28` which labels the Plan/Act toggle "[HOOK] Not implemented."
- **Why S2 not S1:** the `--act`/`--plan` **flags** exist and are handled (`auto.md:105`, `orchestrate-flow/SKILL.md:54`, `chain-execution.md:113-119`) — a working transition fallback exists; the defect is the dead slash-command references, weighted to `pre-tool-use:543`.
- **Fix:** replace the three `/mega-sdd:act` // `/mega-sdd:plan` references with the working `--act`/`--plan` flag form, especially the `pre-tool-use:543` recovery string.

#### R3-3 [S2 — silent-regression risk] `scope-flag` hard-block gate has ZERO regression test in any tree
scope-flag — one of the five enforced PreToolUse gates named in the contract — has no test, fixture, or wiring assertion anywhere, so the validator or its hook branch can be culled/refactored and the whole suite stays green.
- **Evidence:** `CLAUDE.md:31` (scope-flag in the enforced hard-block list); `hooks/pre-tool-use:176-197` (`validate-scope-flag.sh` → `SCOPE_EXIT==1` → reads `.scope-flag-state.json` → `emit_block` = hard deny); `scripts/validate-scope-flag.sh` (7.5K validator). `grep -rli 'scope.flag|scope-flag-state|validate-scope-flag'` over both `tests/` trees returns NONE; `tests/fixtures/code-delivery/` has 19 gate fixture dirs, none for scope-flag — the lone enforced gate with no fixture dir. The other four enforced gates ARE pinned (preflight fixtures, moat `test-moat-corrupt-fail-closed.sh`, 19 code-delivery fixtures).
- **Why S2 not S1:** a refactor of the *shared* `emit_block`/aggregator harness would likely trip adjacent gate tests — not totally unprotected, but the scope-specific logic can silently regress.
- **Fix:** add a good/bad `validate-scope-flag.sh` fixture + a wiring grep that `.scope-flag-state.json` is read in `pre-tool-use` (mirror `tests/bolt-orphans/test-gates-wired.sh`).

#### R3-14 [S2 — silent-regression risk; peer of R3-3, arguably higher priority] `anti-self-bypass` deny branch has ZERO regression test — the anti-tampering guard over the moat state files is unpinned
anti-self-bypass — also an enforced PreToolUse gate (CLAUDE.md:31) — is the guard that denies an agent's Bash attempt to `rm`/truncate/overwrite the moat state files (`.validation-blockers.json`, `.plan-pending`, `.replan-budget`, `.iter-classifier.json`). The deny branch is wired and functional, but no test exercises it, so a regex break silently disarms the protection that stops an agent from deleting the binding gate's own blocker file. *(Reconciled from "Considered & dismissed" in advisor review — see below.)*
- **Evidence:** `CLAUDE.md:31` (anti-self-bypass in the enforced hard-block list); `hooks/pre-tool-use:527-545` (BRANCH 2: `PROTECTED='\.validation-blockers\.json|\.plan-pending|\.replan-budget|\.iter-classifier\.json'` → `BYPASS_DETECTED` → deny). No test feeds a protected-file mutation (`rm`/`>`/`tee` of those files) as a Bash tool_input to the hook to assert the deny fires: the only tests touching `.validation-blockers.json` (`tests/platform/test-platform-pins.sh:24`, `tests/fmea/test-fmea-pins.sh:74`) `printf >` it to set up the *binding→units* gate state — a different branch; the BYPASS deny is never hit.
- **Why this is a confirmed peer (not the dismissal it first looked like):** the finder's *framing* ("changelog falsely claims it is fixture-tested") was correctly refuted — that claim sits in the **frozen** `CHANGELOG.md:691` (`[4.0.0]`), not a live doc — but the *primary* claim (enforced gate, deny branch untested) is identical to R3-3 and survives. anti-self-bypass protects the binding gate's blocker file, so a silent regex regression here is moat-adjacent — pin it first, ahead of scope-flag.
- **Fix:** add a fixture that feeds `rm .mega-sdd/.validation-blockers.json` (and `> .plan-pending`) as a Bash tool_input and asserts the hook denies (exit 2 / `emit_block`), plus the negative case (a benign command is allowed).

#### R3-4 [S2 — partial wiring / unpinned regression] Five code-delivery hard-block gates have validator fixtures but no aggregator-wiring test
flow-coverage, render-test (unit-spec), sibling-consistency, ui-quality, and cross-cutting-registration are validator-fixture-tested, but no test pins that the PreToolUse aggregator actually reads their state and blocks — delete one `fails.append(...)` line and every fixture stays green while the gate stops blocking.
- **Evidence:** `hooks/pre-tool-use:338,345(349),352,359,367-370` (the five state-file reads → hard-block `fails.append`); `CLAUDE.md:31` (all five in the enforced list). Coverage is validator-only: `tests/fixtures/code-delivery/{flow-coverage,render-test,sibling-consistency,ui-quality,cross-cutting}/verify.sh` invoke `validate-*.sh` and assert state-file output, never `pre-tool-use`. The wiring-test pattern **exists** for the sibling gate: `tests/bolt-orphans/test-gates-wired.sh:10` greps the hook for `.bolt-orphans-state.json`; the five higher-value gates lack the equivalent. `CHANGELOG.md:691` claims "kept gates still block" yet grep of that phrase returns empty — unbacked for these five. *(Tests live at repo-root `tests/`, not `plugins/mega-sdd/tests/`.)*
- **Why a gap:** wiring works today; the gap is the missing regression **pin** on the validator-writes-state ↔ hook-blocks-on-state link — the project already treats hook-wiring as first-class.
- **Fix:** one `test-gates-wired.sh` that greps `pre-tool-use` for each of the five state files (extend the bolt-orphans precedent).

#### R3-11 [S2 — silent contradiction in the consistency surface] `/analyze` aggregate-only mode reads stale state-file statuses with no freshness/scope check — the automatic hook path reports FAIL where manual `/analyze` reports PASS on identical inputs
`scripts/run-analyze.sh --aggregate-only` (the mode both automatic invocations use) trusts each validator's last on-disk `status` without checking that the recorded `checked_file` still exists, is in scope, or was written this chain. On this repo (no vault/KB/units) three state files hold leftover FAILs from prior dev runs, so aggregate-only reports overall **FAIL** while FULL mode (find-driven discovery) correctly **SKIP**s all three and reports **PASS**.
- **Evidence:** `run-analyze.sh` aggregate-only path trusts `data.get("status")` and reads only `status`/`summary`/`halt_type`, never `ts`/`checked_file` (both present in the state files); FULL-mode short-circuits to SKIP before any disk read when `find` returns no files. Empirically reproduced this session: FULL `--cwd=<repo>` ⇒ overall PASS (unit_spec/fsd_slots/kb_output all SKIP); `--aggregate-only` (same repo) ⇒ overall FAIL. `.mega-sdd/.fsd-slots-state.json` `checked_file=…/emit-fsd/SKILL.md`; `.unit-spec`/`.kb-output` `checked_file=…/tests/graph/fixtures/…` (stale residue; `ts` 2026-06-12, today 2026-06-25). `hooks/stop:301` + `hooks/post-tool-use:706` both call `--aggregate-only` (buggy); `skills/analyze/SKILL.md:22` calls FULL (correct). `session-start` never purges `.*-state.json`. The freshness contract is *claimed* in comments (`run-analyze.sh:6-8` "written … during the chain"; `stop:291-294` "during this session") but never enforced — the exact "prose that claims enforcement it doesn't have" S2 shape.
- **Why S2 not S1:** non-blocking — `pre-tool-use` reads `.unit-spec-state.json` only for `halt_type=="render_test_missing"` (the stale FAIL is `unit_underspecified`, no match); the binding moat reads `.validation-blockers.json` (PASS); both hooks use `|| true`; the state/report files are gitignored + advisory. No moat bypass. But it makes `/analyze` unreliable as the self-test AUDIT.md B0-1 already flags as missing.
- **Fix:** in aggregate-only, skip/recompute any validator whose recorded `checked_file` no longer exists or is out of scope, or whose `ts` predates the chain; or purge `.*-state.json` at session-start.

#### R3-13 [S2 — silent-regression seam] CI auto-runs 11 of 63 bash suites; the 52-suite repo-root `tests/` tree is never executed by CI (2 suites already RED under green CI)
`.github/workflows/tests.yml:29` discovers tests with one glob — `find plugins/mega-sdd/tests -name 'test-*.sh'` — yielding 11 suites. The repo has 63 bash suites; the other 52 live under repo-root `tests/` (code-gates, instincts-gateguard, bolt-orphans, review-panel, reuse-awareness, security-idioms, fmea, multi-prd, compaction, phase-advisor, hooks, vendoring, …), which the glob root never touches. No master runner backstops them (no Makefile, no root `package.json` test, no `tests/run-all.sh`, no second workflow).
- **Evidence:** `tests.yml:29` (sole discovery command; root `plugins/mega-sdd/tests`, pattern `test-*.sh`); `find tests plugins/mega-sdd/tests \( -name 'test-*.sh' -o -name '*.test.sh' \)` = 63 total, 52 under repo-root `tests/`, never-run = 52. 3 of the 52 are `*.test.sh` (hooks/vendoring) — missed by BOTH root AND pattern. **Decisive proof of the seam:** `tests/security-idioms/test-packs-have-section.sh` is RED today (exit 1: `aspnetcore.md: Security idioms missing class: SQL injection / Secrets` — the .NET pack landed v4.35.0, commit 18cc036, *after* the security-idioms contract and never satisfied it → a real regression CI never caught) while CI stays green. *(`tests/compaction/test-compaction.sh` is also red but possibly timing-sensitive — the seam stands on security-idioms alone.)* Per-cluster `run-all.sh` aggregators (22 of them) exist but CI invokes none. `CLAUDE.md:88` makes running these a release obligation; `CONTRIBUTING.md:30-34` names hooks/ + vendoring/ as automatable bash tests — all manual-discipline-only. The frozen `CHANGELOG.md` 4.34.0:54 claims CI "runs every `tests/**/test-*.sh`" — documented intent was whole-tree; implementation is subtree-only (drift, not design). *(`tests/skill-triggering/` = 0 `.sh` files — markdown fixtures, correctly out of bash-CI scope.)*
- **Why S2 not S1:** these suites *pin* enforcement behavior, they don't *enforce* runtime moat — no live moat is bypassed; but real regressions (incl. enforcement pins) ship under green CI.
- **Fix:** broaden CI discovery to root `tests/` AND pattern `*.test.sh` (the 52 suites already exist and mostly pass — fix the 2 reds first), or add a `tests/run-all.sh` master runner the workflow invokes.

#### R3-5 [S3 — doc-vs-reality drift, named omission] Top-level README undercounts subagents (5 vs 8) and silently drops the entire review panel; also stale skills/commands counts
`README.md`'s architecture table + repo-structure block claim "5 first-class subagents" and enumerate only bolt-implementer/spec-reviewer/code-quality-reviewer/domain-extractor/phase-advisor — omitting the three review-panel agents (security-reviewer, standards-reviewer, design-reviewer), a headline v4.2x feature. The plugin README already says 8, so the two canonical docs contradict each other. Same `README.md:308` also carries stale "16 skills" / "26 commands".
- **Evidence:** `README.md:308,398` (5 subagents, named list of 5), `:308,397` ("16 skills"), `:267,308,399` ("26"/"all 26"); `plugins/mega-sdd/agents/` = 8 `.md`; `plugins/mega-sdd/README.md:79` ("8"), `:72` ("16 skills"), `:41,85` ("26 commands"); `plugins/mega-sdd/CLAUDE.md` Architecture names all 8; `CHANGELOG.md:175,218` added the three review-panel agents; `v4.30.0` shipped `graph` as a first-class skill+command (→ real counts 17/27). Filesystem reality: 8 agents, 17 SKILL.md, 27 commands.
- **Fix:** update both READMEs to 8 subagents (naming the review panel), 17 skills, 27 commands.

#### R3-6 [S3 — contract-doc drift, under-claim] `CLAUDE.md`'s authoritative enforced-gate list omits the live factory-ledger PreToolUse hard-block
The repo CLAUDE.md designates `plugins/mega-sdd/CLAUDE.md:31` as "the authoritative list of what is ACTUALLY enforced (PreToolUse hard-block) vs advisory," but that list does not name the factory-ledger / Factory Line gate, which is a shipped PreToolUse hard-block.
- **Evidence:** `CLAUDE.md:31` (list ends at cross-cutting-registration; no factory-ledger); `hooks/pre-tool-use:373-377,385` (live hard-block on execute-bolts, same aggregator as the named gates); producer chain confirmed (`scripts/validate-factory-ledger.sh:30` writes the state file; `hooks/post-tool-use:457` wires it); `CHANGELOG.md:30-33` (Factory Line shipped the validator + gate). Grep for `factory-ledger|Factory Line` over CLAUDE.md returns nothing. This is the **safe (under-claim) direction** — not the invariant-#2 over-claim shape — but a real false-premise in the authoritative list. *(Distinct from R3-1: that's a wiring gap, this is a list omission.)*
- **Fix:** add factory-ledger / Factory Line to the `CLAUDE.md:31` enforced-hard-block list.

#### R3-7 [S3 — self-contradicting command surface] `migrate-paths` advertises a `--to=legacy` flag its own body declares NOT YET IMPLEMENTED
The frontmatter `argument-hint` and the flag-doc list both advertise `--to=new|legacy`, but the body implements only legacy→new and explicitly states the reverse migration is non-functional.
- **Evidence:** `commands/migrate-paths.md:3` (argument-hint `[--to=new|legacy]`), `:13` (flag-doc), `:207` ("OR run `… --to=legacy` (NOT YET IMPLEMENTED — manual file moves required)"), `:20-35,179-181` (only legacy→new branch exists). Grep for `--to`/`TO_LAYOUT`/`to=legacy` across body + `scripts/` returns only the advertise/doc/rollback sites — no consumption logic. A user reading the hint passes `--to=legacy` expecting a rollback that doesn't exist.
- **Fix:** drop `legacy` from the `--to` argument-hint + flag-doc until the reverse direction is implemented (or mark it explicitly unsupported at the advertise sites).

#### R3-8 [S3 — contract-policy violation, non-canonical cross-skill ref] `routing-rules.md` uses bare `references/squad-subagent.md` for a cross-skill target
`skills/orchestrate-flow/references/routing-rules.md:86` cites bare backticked `references/squad-subagent.md`, which per the one-level-deep rule resolves skill-locally to a file that does not exist in orchestrate-flow; the real target is in execute-bolts.
- **Evidence:** `routing-rules.md:86` ("concurrent depth-1 bolt-agent dispatch — see execute-bolts `references/squad-subagent.md`"); `skills/orchestrate-flow/references/squad-subagent.md` MISSING (dir empty); `skills/execute-bolts/references/squad-subagent.md` EXISTS. `CLAUDE.md:51` (cross-skill refs must use `<skill>/references/X.md`, "never bare … it resolves ambiguously") — `routing-rules.md` is a ref FILE, so the rule applies directly. House norm: every other cross-skill ref uses the concatenated form. Functionally recoverable via the prose-named "execute-bolts" → policy violation, not a hard-broken link.
- **Fix:** rewrite as `execute-bolts/references/squad-subagent.md`.

#### R3-9 [S3 — inconsistent / dangling ref] `bind-codebase` + `emit-fsd` cite bare `references/paths.md` with no skill-local `paths.md`
`skills/bind-codebase/SKILL.md:29` and `skills/emit-fsd/SKILL.md:20` cite bare `references/paths.md`; in a SKILL.md body the bare form resolves to that skill's own `references/` dir, where no `paths.md` exists — the real file is at plugin-root, cited everywhere else as `plugins/mega-sdd/references/paths.md` (~10 sibling sites).
- **Evidence:** both lines verified; `skills/bind-codebase/references/paths.md` + `skills/emit-fsd/references/paths.md` MISSING (no skill-local `paths.md` exists); plugin-root `references/paths.md` EXISTS. Basis = the skills' own demonstrated convention (bind-codebase's SKILL.md uses bare `references/binding-contract.md` for genuine skill-local refs) + the ~10 full-path sibling sites — these two are the sole outliers. Both occurrences are parenthetical prose, not load-bearing router edges. *(CLAUDE.md:51's "never bare" is literally scoped to ref FILES; these are SKILL.md bodies — the gap rests on convention.)*
- **Fix:** change both to `plugins/mega-sdd/references/paths.md`.

#### R3-10 [S3 — authoring-standard violation] `superpowers-bridge.md` (115 lines, non-exempt) lacks the required `## Contents` ToC
`skills/execute-bolts/references/superpowers-bridge.md` is 115 lines with 9 `##` sections and no `## Contents` ToC, violating the contract's >100-line ToC rule; it matches none of the three codified exemptions (packs, `templates/`, do-not-hand-edit catalogs).
- **Evidence:** `wc -l` = 115; 9 `##` sections, no `## Contents`; hand-authored ("# Dispatch Bridge"), routed from `execute-bolts/SKILL.md:127`. `CLAUDE.md:51` requires the ToC. Across all ~60 skill refs >100 lines, every other non-`templates/` file has a ToC — this is the sole non-exempt miss.
- **Fix:** add a `## Contents` ToC listing the 9 sections.

#### R3-12 [S3 — over-broad path filter → false FAIL, with downstream reach] `validate-fsd-slots.sh` `*fsd*.md` glob matches `emit-fsd/SKILL.md` and flags its literal `{{slot}}` doc examples as unfilled template slots
The case filter `*FSD*.md|*fsd*.md|*/fsd/*.md` (`validate-fsd-slots.sh:45-48`) matches `skills/emit-fsd/SKILL.md` (substring "fsd" in the parent dir `emit-fsd`); the slot regex (`:71`) then catches the SKILL.md's own mustache documentation, producing `halt_type=template_slot_unfilled` — the exact stale FAIL recorded in `.fsd-slots-state.json`.
- **Evidence:** filter verified to match `emit-fsd/SKILL.md`; `emit-fsd/SKILL.md:92,112,192,240` carry `{{slot_name}}`/`{{section-3-stakeholders-table}}` etc.; `.fsd-slots-state.json` `status=FAIL, unfilled_slots=[section-3-stakeholders-table, section-7-binding-confirmed-content, slot, slot_name]`. The `:70` comment ("Don't match … inside code fences") is an unfulfilled promise (no fence exclusion) — the over-match is unintentional. Real consumer: `post-tool-use:564` dispatches this validator per-file on every Write/Edit and appends a spurious `template_slot_unfilled` halt event to telemetry. **Downstream reach:** the `*fsd*.md` substring glob fires in any consumer project too — any path containing "fsd" holding `{{...}}` (Handlebars/Vue/mustache) gets a false FAIL.
- **Why S3:** the PreToolUse aggregator does not read `.fsd-slots-state.json` (no hard-block); real but low-severity. Feeds R3-11 (one source of the stale FAILs).
- **Fix:** anchor the glob (`*/FSD.md|*/fsd/*.md`, drop bare-substring `*fsd*.md`) and honor the code-fence exclusion the comment promises.

### Lanes that returned clean (negative results, recorded)

- **hook-validator-parity** — verified clean in the main thread: (a) all 8 `hooks.json` entries dispatch through the portable `bash run-hook.sh <name>` path (the v4.37.0 Windows fix is uniformly applied: session-start, pre-tool-use, post-tool-use ×2, stop, pre-compact, user-prompt-submit, user-prompt-expansion); (b) all 5 pipeline skills (scan/bind/extract/generate-intent/execute-bolts) reference `scripts/resolve-plugin-root.sh` (v4.38.0 glob-anchored resolver) in their path-resolution blocks; (c) no dangling validator (every `validate-*.sh`/`audit-*.sh` referenced in `post-tool-use`/`run-analyze.sh` exists); (d) no dead validator (`validate-pack.sh` is a pack-linter invoked by `scaffold-pack.sh:255,257` + 4 `tests/per-stack-packs`/`tests/pack-kit` suites; `audit-domain-rules.sh` is a Mode-B KB-only audit lens run in FULL `/analyze`, correctly NOT in post-tool-use). The NOT_RUN validators in the self-repo CONSISTENCY-REPORT (constitution, cross-cutting-registration, vault-binding-coverage, vault-flow-staging) ARE wired into `post-tool-use` — NOT_RUN was just "empty self-repo this chain," not orphaned.

### Considered & dismissed (not gaps)

- **factory-ledger missing its `/mega-sdd:analyze` aggregator leg** → evidence true but `run-analyze.sh:363` scopes its cohort to "KEPT hard-block CODE-DELIVERY gates"; factory-ledger is a loop-control backstop (`CHANGELOG.md:34` "a terminal backstop"), a *different category*. The "user gets silence" premise is false — `pre-tool-use:383` emits the halt_type at block time; no contract mandates a tri-leg; no user-facing completeness claim. (Mis-categorized sibling.)
- **CI glob `test-*.sh` can't match `*.test.sh`-named suites** → the stated mechanism is non-operative: the three `.test.sh` files live in repo-root `tests/`, which the glob root never scans at all — the tree-root, not the naming, orphans them. (The real, larger finding is R3-13.)
- **extract-intelligence cites bare `references/model-tiers.md` (×6)** → the operative dispatch route resolves correctly (`SKILL.md:75` → `wave-dispatch-templates.md`, which cites the full `plugins/mega-sdd/references/model-tiers.md:27,35`); `:86-91` are summary prose, and `references/model-tiers.md:7` documents the bare `§`-anchored form as its own consumption shorthand. No dead load-bearing path.
- **anti-self-bypass "changelog claims fixture-tested"** → only the *finder's framing* is dismissed: the false test claim sits in the **frozen** `CHANGELOG.md:691` (`[4.0.0]`), not a live doc. The *primary* claim — enforced gate (CLAUDE.md:31), deny branch untested — is the structural peer of R3-3 and was **reconciled to a confirmed finding (R3-14)** in advisor review (a per-finding verifier had let the refuted secondary claim sink the valid primary one).
- **fsd_slots/kb_output/unit_spec hard-FAIL on absent input (should SKIP)** → the original self-analysis premise: FALSE POSITIVE — the three validators handle empty input correctly (FULL mode SKIPs them). The real defect is upstream in the aggregate-only reader (R3-11) + the over-broad fsd glob (R3-12).

### Net assessment

The plugin is structurally healthy: **no S1, no moat bypass, no broken primary path.** Every confirmed gap is one of three classes — a regression-pin omission (the gate works today but nothing stops it rotting: R3-3, R3-14, R3-4, R3-13), a doc/contract-drift item (R3-5, R3-6, R3-7, R3-8, R3-9, R3-10), or a consistency seam with a working fallback (R3-2 dead recovery string with a live flag; R3-11 advisory aggregate-only contradiction; R3-12 low-severity false FAIL). The single highest-priority gap is **R3-1** — the only finding where enforcement reality diverges from a documented guarantee *today*: the Factory Line "never loop forever" promise the spec elevated to a hook is not backed on the backward owning-phase re-dispatch a `phase_stuck`/`anti_spin` ledger triggers. The next tier is the silent-regression cluster — **R3-14** (the anti-tampering guard over the moat state files, untested), **R3-13** (52 enforcement-pinning suites with zero CI coverage; ≥1 already a real regression), **R3-3**/**R3-4** (enforced gates with no wiring-pin), and **R3-11** (the consistency surface contradicting itself between its automatic and manual paths). Recommended order: R3-1 → R3-14 → R3-13 → R3-3/R3-4 → R3-11 → the S3 doc cluster (cheap, batchable).
