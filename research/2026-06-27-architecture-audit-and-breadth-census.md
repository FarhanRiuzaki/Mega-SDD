# Mega-SDD — Architecture Audit + Breadth Census

*2026-06-27 · AI/IT/system-architect + god-reviewer pass · lenses: concept → efficiency → performance → speed → token*

Method: a conceptual spine review (inline, by the orchestrator holding the whole system in context) followed by a **fan-out breadth census** — 13 reviewer slices over all 17 skills + 59 scripts + 27 commands + 10 hooks + 18 shared refs, **each finding adversarially re-read against source before reaching this list**. 89 raw findings → **77 survived, 12 refuted/blocked** (26 agents, ~2.26M tokens, ~25 min wall-clock).

**Headline:** the moat is sound and the v4 lean-core architecture holds. The risk is *accretion*, not design. The actionable work splits into three honestly-different buckets — do **not** conflate them:

| Bucket | What it buys | Reality check |
|---|---|---|
| **Correctness bugs** (7) | Fixes live defects (stale templates, a 5-vs-4 option overflow, data-loss surface, broken anchors) | These are the surprise of the audit — they matter more than any token cut |
| **Token cuts** (heavy-skill ref dedup) | Real per-run token savings **only on refs that load on the hot path** | Dead-scaffold LOC saves *zero* runtime tokens (nothing routes to it) — that's a maintainability win, not a token win |
| **Speed / latency** (F1) | ~30–150ms off the blocking hook path per tool call | Not a token cost at all — wall-clock. The token audit never touched it |

**The guardrail worked:** 6 of the 12 refusals were "obvious" token cuts that were actually test-pinned or moat-load-bearing. A naive cut-list would have shipped them.

---

## P0 — Correctness bugs (found in the wash; not token cuts — live defects)

| # | File:line | Defect | Fix | Conf |
|---|---|---|---|---|
| C1 | `execute-bolts/references/propose-and-confirm-prompt.md:139-145` | Renders a **5-option** AskUserQuestion menu (`[4] Cancel chain` + `[5] Override halt`) while `halts-and-handoff.md:76` documents the platform **4-option cap** (pinned by `test-platform-pins.sh:54`). A controller following the template overflows the cap. | Restructure to 4 options; Override rides the built-in Other/Esc escape. Pinned string lives in the *other* file → stays green. | high |
| C2 | `emit-agents-md/SKILL.md:42-93` | Body inlines a **stale, less-complete** AGENTS.md template — omits the `## Section 7.5 — Constitution` block (flattens `constitution.md`, **moat #4**) + framework/mutability lines that `references/agents-md-schema.md` has. Body wins by proximity (`SKILL.md:40` says "emitted verbatim") → divergent output. | Extract-to-ref; **restores** the missing Constitution flattening. Neutralize the ":40 verbatim" prose so it doesn't dangle. | high |
| C3 | `emit-agents-md` (`SKILL.md:45,140`; `agents-md-schema.md:37,287`) | Generation-marker version hardcoded to **3 different stale literals** (v1.2.4 / v1.0.0 / v1.0) — frontmatter is **1.4.0**. Skill stamps a wrong version into the user's file. | Tokenize to a `{{plugin_version}}` placeholder. Idempotency keys on marker *presence*, not the version → safe. | high |
| C4 | `orchestrate-flow/references/chain-execution.md:105-107` | Live prose instructs invoking `classify-iter.sh --ep=EP1/EP2` — a script the project's own `telemetry-schema.md` documents as **never wired** (`fork-a-recovery-map.md:22`: "Not implemented"). Prose lies about liveness (extends F5). | Reconcile to one truth: delete the invoke lines (and retire the script) OR genuinely wire it. Don't touch orchestrate-flow triggers. | high |
| C5 | `orchestrate-flow/references/predictive-checks.md:17-25` + `handoff-contract.md:14,16` | Iter-archaeology suffixes on **8+ ToC anchors** (`-v3340-iter-50`, `-v370-iter-62-…`) mean the anchors link to nothing — the `##` headers are clean, so the in-file links are **already broken**. Also violates the no-archaeology authoring standard. | Strip suffixes → fixes the broken links *and* removes archaeology. ~25-40 tokens. | high |
| C6 | `commands/migrate-paths.md:22-188` | 231-line command embeds **destructive `git mv` + `sed -i` in-place** bash for the *model* to execute against the user's repo — a genuine data-loss surface (`:218` "without it, vault.json citations break"). | Extract ~160 bash lines → a vetted `migrate-paths.sh` the command calls; **keep** the Step-3 AskUserQuestion confirm + dirty-tree rails as the interactive shell. Removes the model from the data-loss path. | high |
| C7 | `install-deps/SKILL.md:102-103,122-123` | Chat-output mockups label steps off-by-one vs the procedure headers ("Step 3…" printed while executing "### Step 4"). Cosmetic; user-facing sequence is self-consistent. | Renumber mockup labels. | low |

---

## P1 — Speed (F1 confirmed: the highest-ROI structural lever)

**`hooks/pre-tool-use:33-111` — python3 cold-start before the `.mega-sdd` gate.**
The blocking (`async:false`) PreToolUse hook spawns `python3` at L33 **unconditionally**, before the `[ ! -d .mega-sdd ] → exit 0` gate at L111. The matcher is `Skill|Bash|Edit|Write` and hooks are global → **every such tool call in every project, including non-mega-sdd repos that immediately no-op, pays a python cold-start on the agent's critical path.**

- **Fix:** a negative-only short-circuit — resolve project root via the already-pure-shell `scripts/_lib/resolve-project-root.sh`, `exit 0` when no `.mega-sdd` ancestor exists, fall through unchanged when it does.
- **Moat-neutral by construction:** the short-circuit fires *only* when `.mega-sdd` is absent — mutually exclusive with the path that reaches the gates. Can never bypass invariant #2.
- **breaks_test = false:** every pinned moat test does `mkdir .mega-sdd/…`, exercising only the fall-through. Saves ~30–150ms/call. **Confidence: high.**
- Implementer caveat: preserve the python-absent fail-closed branch (L67-88); use the *same* walk-up as L111, not a naive `${CWD}/.mega-sdd` check.

**Secondary (minor, `async:true` non-blocking):** `post-tool-use` re-parses STDIN_JSON via 3 extra python cold-starts (L162/226/310) + double base64-decode (L269/309). Safe subset to fold: `transcript_path` + the duplicate decode.

---

## P1 — Token cuts (genuine per-run savings on hot-path refs)

These load on the pipeline hot path, so trimming them is a *real* token win.

**execute-bolts** (`bolt-dispatch-prompt.md`):
- Extract the **Tier-loading algorithm** (`359-461`, ~90 LOC) — it redefines the budget dict + priority 8→1 order + halt condition that `context-enrichment.md` already owns (the file literally says "figures MUST match that source" = admitted hand-sync). *Scope: the algorithm, not the rendered T2 tracker template.*
- **Cut** the self-labeled `DEPRECATED v1.0 algorithm` + `## Backward compatibility` block (`359-365, 458-478`, ~25 LOC) — version archaeology the standard forbids.
- Minor merges (direction matters — dispatch-prompt stays owner, others point): provenance trailer (~10), `bolt_self_report` schema (~10), halt eligibility lists (careful — lists differ in length, ~14).

**extract-intelligence** (`SKILL.md` — the 410-line body, largest in the plugin): a **cluster of ~10 body→ref relocations**, each into an already-cited ref, that can pull the body toward the ≤200 hot-skill target:
output tree (~12), handoff YAML (~26), glossary pre-parse (~12), deep disciplines (~10), staged-input detection (~12), marker examples (~8), model-tier list (~5), Wave-5 outputs (~8), validation stats (~5), path-resolution (~8), common-mistakes table (~11).
⚠️ **Several are relocations, not deletions** — the procedure must be *added* to the destination ref first (handoff YAML, shared-snapshot procedure). **Keep in-body:** every anti-halu rail (`:190` "a stage you cannot anchor is an [OPEN]", `:285` "never up-rank a principle to COVERED") — moat #5.

**generate-units** (`defensive-generation.md`):
- Field-diff + six-state map + login example (`274-372`, ~85-95 LOC) duplicates `bind-codebase/references/implementation-state.md` (the canonical owner). Collapse to a routed stub. **Bug found:** the copies drifted — `SKILL.md:153` + `task-typing.md:31` say "five-state" but the table has **six** states; fix the stale label while collapsing.
- Step 7.6 collision-prompt **triplicated** (`64-98, 226-244`, ~30-40 LOC) — keep one canonical copy (`task-typing.md` §7.6, which pinned test DG5 asserts), drop the other two, update `SKILL.md:84` to route to one.
- binding-state→task_type table (`321-329`, ~8 LOC) — second copy of `task-typing.md:18-29`.

**Lighter merges** (memory review-flow ~7, scan handoff string ~3, emit-fsd mode-detect ~5 + changelog prose ~12, using-mega-sdd below-anchor dup ~3, install-deps scoop ~5, generate-intent setup-flow↔auto-and-handoff ~12).

---

## P1 — Maintainability (F4: command shadow-logic tier — confirmed)

The "one command per pipeline step / CLI entry point" doctrine has drifted: several commands carry **deterministic logic as model-executed prose with no backing script**, some on the `/mega-sdd:auto` hot path.

| Command | Shadow logic | Action |
|---|---|---|
| `analyze-parallelism.md:16-122` | ~100 lines of **deterministic DAG math** (depth/width/topological-waves/speedup) — self-labeled "DAG analysis is DETERMINISTIC", no script | Extract to a script; keep Step-7 hand-off suggestions as prose |
| `lint-units.md:27-83` | Re-narrates checks `validate-unit-spec.sh` already does — **but adds real module/squad/binding checks the script lacks** | Extract *only* the overlapping subset; do **not** collapse to a dispatcher |
| `list-modules.md:26-62` | Deterministic per-module status rollup as prose | Extract ~35 compute lines; **keep** the `--mark-dod` AskUserQuestion flow |
| `replay.md:18-124` | ~100 lines of bash+jq snapshot/diff/classify ("DETERMINISTIC; no LLM judgment") | Extract to `replay.sh`. Low priority — manual-invoke, off the auto path |
| `auto.md:108-130`, `sync.md:10-28` | Re-narrate orchestrate-flow algorithms they already cite | Collapse to pointers; **keep** input-shape detection (auto) + the moat-reaffirmation line (sync) |

**The convergence target shape** (do **not** cut — these prove the pattern): `validate-handoff.md`, `enrich-semantics.md` (proper dispatchers: invoke a script, body is *why*-documentation), and `detect-drift.md` (15 ln) / `diff-vault.md` (14 ln) thin dispatchers.

`chain-execution.md:173-176` re-points the auto diagnostics at the **command bodies** — re-point at scripts where one exists to break the prose↔ref↔command triplication.

---

## P2 — Dead / parked surface (maintainability; ~0 runtime-token impact)

- **`references/3-tier-context-model.md` (89 ln) + `references/skill-tier-manifest.yaml` (109 ln) — CUT (~198 ln).** Dead Iter-64 lazy-loading scaffold whose enforcement (Iter 66) was parked and never shipped (`:79` "ships the DECLARATIONS only … still load all refs unconditionally"). **Zero routes** (only each other). Manifest is provably stale: pinned to plugin `3.44.0` (live 4.44.0), 5/5 spot-checked paths missing on disk. No "preserve for Fork B" directive. High confidence.
- **`scripts/memory-write.sh` — CUT (~4.5K), medium confidence.** Zero executable refs anywhere; the session-start "memory-write" mention is a *reframed* inline-python Guard, not a call. *Caveat:* a phase-b doc names it as an intended future consumer — confirm that hardening iter is abandoned first.
- **`scripts/check-recursion-budget.sh` + `classify-iter.sh` — KEEP (do not cut).** Dead, but `telemetry-schema.md:173` + `CHANGELOG-ARCHIVE` document a deliberate "kept as advisory tool / Fork-B-parked" decision. Reconcile only the C4 *prose* that lies about classify-iter's liveness.
- **`telemetry-schema.md:161` row — KEEP.** Dead row, but inside a `## Fork-B-future (PARKED)` table with an explicit `:157` "NOT removed entirely" preservation directive. It's the breadcrumb that lets Fork B rediscover the design.
- **Liveness-opacity fix (not a cut):** `run-analyze.sh:111-112` lists two validators as "excluded" that are in fact **live via PostToolUse** (`validate-pandoc-render.sh`, `validate-starterkit-metrics.sh`) — add "excluded from BATCH only; live via hook" so a future liveness scan doesn't false-delete them.

---

## Honest corrections to my own conceptual pass (god-reviewer integrity)

The census **refuted two of my six conceptual findings** — recording them so the audit doesn't overclaim:

- **F2 (detect-drift ≈ diff-vault) — was directionally right, disposition wrong.** The overlap is **pipeline-topology** (shared downstream hand-offs), not logic duplication. Correction: the shared downstream set is **5, not 6/6** (execute-bolts is detect-drift-only; my delegation grep over-counted). Merge is **architecturally blocked** three ways: detect-drift is `context: fork` / diff-vault is interactive (`AskUserQuestion`); different input modality (live-code scan vs doc re-extract); combined 957 LOC > the 500-line rule. The genuinely-shared invariants (lock contract, handoff schema, vault detection) are **already centralized by pointer**. → **keep-noted, no action.**
- **F3 (orchestrate-flow god-object) — partially refuted.** `SKILL.md` is a lean **176-line pure-dispatch router** (healthy — do not touch). The chain-level logic (model-tier, drift-gate, preflight) is **correctly placed** — no single lane skill sees the whole chain. The real bloat is intra-doc **duplication in the handoff doc-pair**, not mis-placed per-lane logic. → the actionable F3 is "trim handoff-contract duplication," **not** "restructure the router."
- **F1, F4, F5, F6 — borne out** with file:line evidence (above).

This is the point of the adversarial layer: a per-skill matrix would have flattened F2/F3 into confident-but-wrong "merge these" findings. Re-reading against source corrected them.

---

## Suggested execution batches (gated on the moat's own change policy)

Acting on skill/hook bodies is a behavior change → per `plugins/mega-sdd/CLAUDE.md` it needs spec acknowledgment + updated `tests/skill-triggering/` fixtures + a CHANGELOG entry. Proposed ordering, smallest-risk first:

1. **Batch A — correctness (C1-C7):** highest value, mostly self-contained, each fixes a live defect. C2/C3 (emit-agents-md) and the five/six-state label bug are user-visible.
2. **Batch B — speed (F1 hook short-circuit):** one file, high ROI, moat-neutral, pinned-test-safe.
3. **Batch C — dead-scaffold cut (3-tier + manifest, ~198 ln):** zero behavior risk (nothing routes to it), pure maintainability.
4. **Batch D — heavy-skill token dedup:** the extract-intelligence body cluster + execute-bolts/generate-units dedup. Highest token payoff but most care (relocations, not deletions; preserve every anti-halu rail).
5. **Batch E — command shadow-logic extraction (F4):** safety + latency + doctrine alignment.

Each batch is independently shippable. None requires touching an enforced gate.
