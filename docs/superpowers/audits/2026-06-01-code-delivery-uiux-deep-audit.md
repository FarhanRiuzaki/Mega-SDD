# Mega-SDD Deep Audit — Code Delivery & UI/UX Quality

**Date:** 2026-06-01
**Auditor lens:** Fork A reality (skill-body prose is NOT enforced; only hooks + [HOOK-VALIDATE] validators ship)
**North-star complaint:** "The pipeline runs well, but code DELIVERY is the weak link — especially UI/UX quality, and the PROCESS itself. The pipeline should analyze SHARPER and STRONGER."
**Repo:** `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec`
**Grading authority:** `plugins/mega-sdd/CLAUDE.md` §"Fork A scope (CURRENT) vs Fork B (FUTURE)" (lines 62–98)

---

## 1. Executive summary

**The one root cause: delivery quality is unenforced, and for UI it is also un-sourced.** Three structural facts compound into the complaint. (a) The pipeline's "rigor" lives almost entirely in SKILL.md / reference **prose**, which Fork A explicitly classifies as design vocabulary the model may silently no-op (CLAUDE.md:75, 96) — the only things that actually halt the agent are the 4 `emit_block` sites in `pre-tool-use` plus a handful of SessionStart guards, and **every one of them gates schema / provenance / structure, never code or UI quality**. (b) **There is zero visual / UX / accessibility / responsive quality gate anywhere** — not in the 4 blocking gates, not in the ~16 detection-only PostToolUse validators, not in the bolt post-flight, not in the acceptance-test enum, not in detect-drift. A pixel-perfect view and a broken unstyled view pass identically. (c) Most decisively for UI specifically: **UI/UX fidelity is lost UPSTREAM at CAPTURE**, not at the dispatch last-mile — the source PRD is design-thin, the (correct) anti-hallucination rail refuses to invent design substance, and no channel routes whatever design substance *does* survive into the vault (`06-constraints §Design system`) down into the unit bodies the bolt reads. The dispatch-time `design_tokens` exclusion (execute-bolts SKILL.md:260) is a real but **downstream, brownfield-only** loss, not the originating drop. Net: a UI bolt is dispatched with starved context and its output is checked by nothing. Adding more "build good UI" prose is the documented 4×-failed dead end (Iter 64/65/66a/67) — the durable levers are sourced-enrichment (feed real material) paired with verification-gates (catch bad output).

---

## 2. The Fork A reality — why it FEELS rigorous but is not

The skills read like a rigorous engine: tiered-context budgets, halt taxonomies, rollback sagas, a closed Hard-Rule grammar, provenance trailers, convergence loops, a self-learning memory layer. **Almost none of it is enforced.** Per CLAUDE.md:75 and :96, "Markdown-driven anti-hallucination rails inside skill bodies — model compliance is best-effort and NOT enforced" and "Treat the criteria tables, halt enums, and rule documents below as DESIGN VOCABULARY — they describe how the system *should* work; they do not enforce it in Fork A."

**What is ACTUALLY hook-enforced (the real perimeter — verified by reading the hooks):**

| Gate | Hook site | What it checks | Touches code/UI quality? |
|---|---|---|---|
| scope-flag | `pre-tool-use:159` `emit_block` | PRD `scopes:` declaration (schema) | No |
| handoff-validation | `pre-tool-use:218` `emit_block` (blocks ALL `mega-sdd:*`) | handoff-YAML presence + 4 required fields + 5 shallow type checks + artifact-path existence | No |
| binding→units OQ-IDs | `pre-tool-use:251` `emit_block` (blocks `execute-bolts`) | every binding OQ-ID carried into a unit `binding_refs` (provenance + dependency) | No |
| anti-self-bypass | `pre-tool-use:308` `emit_block` (Bash) | anti-tamper of protected state files (hard-rule) | No |
| mode-migrate | `session-start:99–204` (auto-fix) | vault.json `mode` vs CWD signals — re-entry backstop | No |
| model-tier | `session-start:501–576` | model-tier config presence at chain start | No |
| starterkit cross-metric | `validate-starterkit-metrics.sh` via PostToolUse | `units_with_starterkit_rules` vs `partial:` flag consistency | No |
| starterkit conformance | `validate-starterkit-conformance.sh` via PostToolUse (detection-only) | generated file **location + naming** vs §patterns | No — structural only |
| ~16 detection validators | PostToolUse, `async:true`, always `exit 0` (`post-tool-use:23,560`) | schema / provenance / citation integrity | No |

**The structural ceiling:** PostToolUse is `async:true` and ends `exit 0` on every path (`post-tool-use:23` comment "hook must never block tool execution"; terminal exits at 556/560). It **cannot halt a tool in-band**. A detection FAIL becomes a block only if it lands in one of the 3 blocking state files read by PreToolUse. So the *entire* ~16-validator detection surface — even if a UI validator were added to it — could not stop a bad UI bolt unless its FAIL is explicitly routed into `.validation-blockers.json`.

**Everything else is prose.** The bolt's "GENERATE CODE THAT" contract, the closed Hard-Rule grammar, the acceptance-test enum, the T2 slice builder (including the `design_tokens` exclusion), the Iter 76 few-shot code-slice, the convergence loops, the checkpoint protocol, the suggestion-only memory layer, and the `superpowers-bridge` routing table are all skill-body / reference markdown. They shape behavior only when the model chooses to follow them — which is "quality varies run-to-run."

> **Correction carried from adversarial verification:** Several recon-stage findings tagged the Hard-Rule grammar, the acceptance_test enum, and the bolt pre/post-flight scan as `shipped-deterministic`. That over-credits prose. The **closed Hard-Rule grammar** (`unit-schema.md:146`) and the **acceptance_test enum** (`unit-schema.md:70`) are schema/design-vocabulary; the **pre/post-flight Hard Rule scan** (execute-bolts SKILL.md:73, :555) is skill-body prose with no hook — per `fork-a-recovery-map.md` it is a "Slice 3 candidate = NOT implemented." This report carries the corrected status throughout.

---

## 3. UI/UX fidelity propagation trace (PRD → vault → unit → bolt → code)

Every stage either drops design fidelity or has no slot to hold it, and **no stage is enforced** in the direction of design quality.

| Stage | What happens to UI/UX fidelity | First drop? | Enforcement at this stage |
|---|---|---|---|
| **CAPTURE** (generate-intent) | Source PRD is design-thin; the (correct) anti-hallucination rail (SKILL.md:148, :534) refuses to invent WCAG/Material/Tailwind/spacing/components. Real example vault: `02-architecture.md:24–38` is a 9-row screen-name table with frontend stack unresolved (OQ-AR-1); `06-constraints.md:46–54` §Design system is Voice & brand prose only ("Tokens and a11y sub-blocks omitted — PRD has no design tokens / hex codes (Figma TBD)"). **The substance materially disappears here — but as a design-INTENDED consequence of a correct rail meeting a thin source, not a defect.** | **YES — first material fidelity drop (CONFIRMED, F1-001).** | None (prose rail; unenforced either direction). |
| **DECOMPOSE** (generate-units) | generate-units loads all 7 vault files, but **no procedure step routes `06-constraints §Design system` (tokens/typography/spacing/a11y/voice) into unit `## Context` / `## Hard rules`** — Step 2 (SKILL.md:57) walks only 02-architecture/04-flows/03-data-model for build targets. The only design-ish content that reaches a unit is the *separate* starterkit `ui_ux` slice (layout_extends/notification_lib/idioms), and only on brownfield. **The unit schema has no visual/responsive/a11y acceptance slot** (`unit-schema.md:133–135`) — so even if propagated, design substance has nowhere to land. | No (propagates upstream thinness) | None (prose; asymmetric vs starterkit, which has Step 7.7 + 2 validators). |
| **DISPATCH** (execute-bolts) | `design_tokens` (colors/spacing/fonts, extracted by scan-codebase into `starterkit-context.yaml §ui_ux`, `ui-libs.md:94–97,232–235`) are **explicitly excluded** from the bolt slice: `SKILL.md:260` "layout_extends, notification_lib, idioms only — exclude design_tokens, _source". UI context collapses to one line (`SKILL.md:373–374`). The Iter 76 few-shot code-example is **controller-ONLY** (`SKILL.md:347`); no view/blade/component category exists, so UI units get no exemplar. | No — **downstream, brownfield-only** loss (reframed F1-003/F1-011/FA-002). On greenfield there were no tokens to lose. | None (slice build is prose; no hook performs or checks it). |
| **EMIT** (bolt subagent) | Bolt builds UI from a screen name + the thin `ui_ux:` line + framework-pack conventions ("extend Vuexy layout", SweetAlert, "responsive 375px"). Those conventions are advisory and read by zero hook. The design-aware `frontend-design` skill is referenced **0×** in `plugins/`. The "GENERATE CODE THAT" contract (`bolt-dispatch-prompt.md:302–312`) lists 7 obligations — all provenance/halt/anti-hallucination, **zero positive quality directives**. | No | None — and no gate downstream catches the result (see §4). |

**Bottom line of the trace:** the fidelity loss originates at CAPTURE (thin source × correct rail) and is then never recovered — DECOMPOSE has no propagation channel, the unit schema has no slot, DISPATCH strips the one brownfield artifact that survived, and EMIT has no design engine. Fixing only `:260` recovers brownfield token fidelity; it cannot fix the greenfield/requirement case, which needs sourced-enrichment + a verification gate.

---

## 4. The missing UI/UX quality gate (the structural root)

**A full gate census confirms: zero gate anywhere checks visual / UX / accessibility / responsive quality of delivered code.** Classifying every gate by what it checks:

- **4 blocking gates** (`pre-tool-use:159/218/251/308`): schema / provenance / dependency / anti-tamper. None UI.
- **~16 detection-only validators** (PostToolUse, always `exit 0`): all schema-structure or provenance-citation. A repo-wide grep across all `scripts/*.sh` for `blade|responsive|design_token|a11y|accessibility|contrast|viewport|tailwind|aria|wcag` returns a single false positive (`validate-kb-markers.sh:64`, a citation-format comment) plus `aria`-as-substring-of-"variants". **Zero** substantive UI check.
- **`validate-bolt-artifacts.sh`** (closest to a code check): provenance-trailer presence + `bolt_self_report` YAML presence + cited `D-NNN` decisions exist. Never inspects markup, responsiveness, token usage, or a11y.
- **`validate-starterkit-conformance.sh`** (named "conformance"): file **location + naming** regex vs §patterns. Does NOT check that a Blade view extends the layout, uses tokens, or is responsive — it does not verify the very §ui_ux conformance the name implies.
- **Bolt pre/post-flight Hard Rule scan** (prose): the closed 5-type grammar `DO_NOT_MODIFY | DO_NOT_ADD_DEPS | NAMING_RULE | SIGNATURE_RULE | FILE_PRESENCE_RULE` (`unit-schema.md:146`) is **grammatically incapable** of expressing "view is responsive" / "uses design tokens" / "meets WCAG contrast" — such a rule is rejected as `hard_rule_unparseable`.
- **acceptance_test enum** (`unit-schema.md:70`): `test | manual | lint | typecheck`. No `visual` / `render` / `responsive` / `a11y` / `screenshot` type. A UI unit passes by green PHPUnit while the rendered page is broken.
- **Static-analysis hint** (`bolt-dispatch-prompt.md:262`): conditional Pint (PSR-12) + PHPStan — formatting and type-safety only, orthogonal to UI; and it is the FIRST thing truncated under T2 budget (`SKILL.md:196`).
- **detect-drift** (post-build): categories Missing-in-code / Missing-in-vault / Name drift / Type drift / Behavior drift — entity/flow/API parity. No visual / token / a11y drift category. Advisory report, not a gate.

**You cannot get consistent UI quality from a pipeline whose entire gate surface is UI-blind.** This is the structural root of the UI/UX complaint, and it sits alongside §3's input-starvation: the bolt is given thin material AND its output is checked by nothing.

---

## 5. Findings (deduplicated, grouped by dimension; corrected enforcement_status carried from adversarial verdicts)

No finding was refuted; all are confirmed or reframed. The ~30 raw entries collapse to the distinct findings below.

### CRITICAL

**C1 — No UI/UX/visual/a11y/responsive quality gate exists at ANY tier of the pipeline.**
*(Merges: gate-census F1-009/F1-010/F1-015, fidelity F1-004, UI-substance F1-002, FA-004, and the 4 blocking-gate census entries.)*
- **Severity:** critical
- **Location:** `pre-tool-use:159/218/251/308` (4 blocks); `post-tool-use:23,560` (`async:true`/`exit 0`); `unit-schema.md:70` (acceptance enum), `:146` (closed Hard-Rule grammar); `execute-bolts/SKILL.md:553–601` (post-flight); `detect-drift/SKILL.md:47–54`.
- **Enforcement status:** the hook *substrate* is **shipped-deterministic**; the UI gate itself is a **verified absence** (and the acceptance enum + Hard-Rule grammar that would need to carry a UI rule are **prose/design-vocabulary**, corrected down from the recon's `shipped-deterministic`).
- **Evidence:** exactly 4 `emit_block` sites, none UI; PostToolUse structurally cannot block; closed grammar cannot express a visual rule (`hard_rule_unparseable`); acceptance enum has no visual type; scripts-wide UI grep = 1 false positive. detect-drift has no visual category.
- **Verdict:** confirmed (census/fidelity/FA-004); the "shipped-deterministic on grammar/enum" framing **reframed** to prose/design-vocabulary — but the UI-blindness conclusion holds at every tier.

**C2 — UI/UX fidelity FIRST drops at CAPTURE: a design-thin source meets a (correct, must-keep) anti-hallucination rail, producing near-zero design-system density in the vault.**
*(fidelity F1-001, confirmed `is_first_fidelity_drop`.)*
- **Severity:** critical (it is the originating drop)
- **Location:** `generate-intent/SKILL.md:148,534`; example `02-architecture.md:24–38`, `06-constraints.md:46–54`.
- **Enforcement status:** prose-only-aspirational (the rail is correct and must NOT be relaxed — downgrading it is an explicit PR-close per CLAUDE.md:31).
- **Evidence:** SKILL.md:148 "Industry standards (WCAG, Material Design, Tailwind defaults) are NOT defaults"; example vault captures only "clean and minimal, system fonts, muted palette w/ one accent TBD" with WCAG/accent unresolved.
- **Verdict:** confirmed. The fix is NOT relaxing the rail — it is a CAPTURE-stage gate that emits a high-priority Design-Source OQ when UI components exist but `HAS_TOKENS/HAS_A11Y/HAS_VOICE_BRAND` are all false, plus a grounded enrichment channel (real `tailwind.config.js` / component library / Figma export — sourced, therefore allowed).

### HIGH

**H1 — Design context is extracted then stripped before the bolt, and the dispatch contract has zero positive quality directives.**
*(Merges: fidelity F1-003, execute-bolts F1-002/"GENERATE CODE THAT" F1-001, census F1-011, FA-002.)*
- **Severity:** high
- **Location:** `execute-bolts/SKILL.md:260` (exclusion), `:354` (idioms truncated 3rd under budget), `:373–374` (one-line UI inject); `bolt-dispatch-prompt.md:202`, `:302–312` (contract, 7 provenance/halt obligations, no quality directive); `references/lib-patterns/laravel/ui-libs.md:94–97,232–235` (extraction).
- **Enforcement status:** prose-only-aspirational (slice build + contract are prose; no hook performs or checks them).
- **Evidence:** `:260` "exclude design_tokens, _source"; `ui-libs.md:233` `colors: { primary: "#3b82f6" … }`; contract enumerates conventions/HIGH-claims/anchors/anti-patterns/trailer/halt/self-report — none about design quality.
- **Verdict:** reframed — this is a real but **downstream, brownfield-only** loss (recovers brownfield token fidelity, not greenfield requirement fidelity). The recon's `is_first_fidelity_drop=true` and `sourced-enrichment` framing are corrected: the first drop is CAPTURE (C2); un-excluding `:260` is durable only when paired with a hook that verifies the tokens actually land in the emitted dispatch prompt.

**H2 — `frontend-design` (the only design-quality engine on disk) is never bridged; the bolt routes only to design-unaware executors.**
*(Merges: execute-bolts F1-005, census F1-014, FA-001, FA-003.)*
- **Severity:** high
- **Location:** `execute-bolts/references/superpowers-bridge.md:23–33`; `~/.claude/skills/frontend-design` (0× in `plugins/`); routing signal at `generate-units/SKILL.md:307–309` + `execute-bolts/SKILL.md:242`.
- **Enforcement status:** prose-only-aspirational. The `superpowers-bridge` table is reference prose (no hook routes units to executors); the `starterkit_relevance:["ui_ux"]` signal is **computed in prose** (corrected down from the recon's `shipped-deterministic`) — it is consumed for thin slicing but never to select a design-aware executor.
- **Evidence:** bridge maps only test-driven-development / executing-plans / subagent-driven-development / using-git-worktrees; all four vendored SKILL.md contain no UI/visual/design vocabulary; `grep -rln frontend-design plugins/` → 0.
- **Verdict:** reframed — the gap is real, but framed as a missing branch in a *prose* design (not an enforced router). A clean signal (`ui_ux in starterkit_relevance`) already exists to route on; the durable bridge is **context-injection via a hook**, since a hook cannot force a Skill-invoke (skill-invoke-by-prose is the 4×-failed pattern).

**H3 — The Iter 76 few-shot code-slice (the one genuine quality mechanism) is controller-ONLY and structurally UI-blind; the pattern enum has no view/component category and is unverified-shipped.**
*(Merges: execute-bolts F1-003, F7-001, F7-002, F7-006.)*
- **Severity:** high
- **Location:** `execute-bolts/SKILL.md:275` (category loop), `:312–349` (code-slice), `:347` ("controller category ONLY"); `scan-codebase/SKILL.md:456–501` (7-category schema, no UI entry); `bolt-dispatch-prompt.md:216`.
- **Enforcement status:** prose-only-aspirational (the slice build/inject is prose; no hook builds or asserts it). Not artifact-verified: zero `bolt-report*.md` exist in repo; commit a57e5cb says "Logic-proven on tests/fixtures…; Production live-firing pending."
- **Evidence:** pattern categories = controller/data_model/request_validator/business_logic/test/schema_migration/route — a pure-UI unit (`resources/views/*.blade.php`) matches ZERO category, so it gets no §patterns block and no exemplar.
- **Verdict:** confirmed (UI-blindness) / reframed (the "genuine mechanism / high severity" framing over-credits an unenforced prose mechanism — it does not reliably fire even for controllers). Durable fix: add a view/component category AND verify via a `validate-dispatch-prompt` hook that the slice landed. **Caveat (F7-003):** few-shot quality is bolted to `_source[0]` with no exemplar-quality selection and the "do not deviate" rail makes the sampled file a hard floor *and* ceiling — add exemplar-quality selection at the producer (scan-codebase) before relying on this.

**H4 — Process integrity: the convergence/checkpoint/memory/contract "rigor" is unenforced prose; only a thin slice of the handoff contract is hook-checked.**
*(Merges: process F1-002/F1-004/F1-005/F1-007, orchestrate-flow retraction F1-001.)*
- **Severity:** high
- **Location:** `orchestrate-flow/SKILL.md:518–768` (convergence loop, checkpoint, memory layer — no hook); `validate-handoff-yaml.sh:208` (only 4 required fields), `:227–245` (5 type checks) vs SKILL.md Step 6.b.i/iii/iv/ix (rich contract, prose-only); `orchestrate-flow/SKILL.md:144,146–157,374` (RETRACTED classifier + Plan/Act gating presented as live runtime with no caveat).
- **Enforcement status:** mixed — the handoff gate is **hook-enforced but enforces only EXISTENCE + SHAPE**, not the rich contract (`artifacts`/`blockers` marked REQUIRED in `handoff-contract.md` are not even in the validator's required list); the convergence loop / checkpoint / memory layer are **prose-only-aspirational**; the orchestrate-flow classifier/Plan-Act steps are **retracted** prose still presented as runtime.
- **Evidence:** `pre-tool-use:218` blocks all `mega-sdd:*` on handoff FAIL; validator required_fields = `[emitted_by, emitted_at, status, next_action]`; CLAUDE.md:103 retracts the Step 2.9/6.9 classifier wire-up as "prose only."
- **Verdict:** confirmed (process is mostly unenforced prose) with two corrections carried: **mode-migrate (SessionStart Guard 1) and model-tier (Guard 8) ARE hook-enforced** (not prose), and the **cross-metric check IS shipped** (`validate-starterkit-metrics.sh`). The sharp statement: the real enforcement perimeter is genuine but **entirely schema/provenance/structure — zero touch delivery quality.** Also: the handoff hook can DEADLOCK the whole pipeline on FAIL and the only documented recovery (`rm` the state file) lives solely in the `emit_block` reason string, not in any SKILL.md (F1-008).

### MEDIUM / LOW

**M1 — DECOMPOSE has no channel to route vault `06-constraints §Design system` into unit bodies, and the unit schema has no visual acceptance slot.**
*(UI-substance F1-001/F1-002, execute-bolts/decompose F1-002.)* generate-units *does* load 06-constraints (it loads all 7 files), but **no step routes its design-system content into `## Context`/`## Hard rules`**, unlike the starterkit slice which has a dedicated Step 7.7 channel + validators. Enforcement: prose-only-aspirational. Durable only if paired with a `validate-designsystem-propagation.sh` that asserts UI units carry 06-constraints citations when `HAS_TOKENS/HAS_A11Y/HAS_VOICE_BRAND`. **Verdict: reframed** (the recon claim "06-constraints is never read" is literally false — it is loaded but not routed; the asymmetry vs starterkit is the real gap).

**M2 — TDD/superpowers handoff yields "tested-but-mediocre" by design.** *(execute-bolts F1-006.)* TDD optimizes for "simplest code to pass"; REFACTOR is scoped to "don't add behavior"; no design/aesthetic dimension. For UI, "passes the functional acceptance test" is fully decoupled from visual quality. Enforcement: prose-only-aspirational. Quality must come from inputs + an output gate, not from the executor. **Verdict: confirmed.**

**M3 — SQUAD parallel UI dispatch partially anchors structure but not visual detail.** *(F7-004.)* Layer-partitioning consolidates UI into one squad, but per-unit subagents independently read the same thin `ui_ux:` slice and make their own visual micro-decisions; with `design_tokens` excluded, spacing/color/composition drift across units under parallel dispatch. Enforcement: prose-only-aspirational (and the parallel pathway is itself unverified-runtime). **Verdict: reframed** (partial anchoring, not chaos; the enrichment fix cannot enforce cross-subagent convergence — parallel subagents can't see each other's choices).

**L1 — Framework-pack UI conventions are advisory and read by zero hook.** *(census F1-012, fidelity F1-004.)* `laravel-base-26.md:152–170` is the richest UI content in the plugin but is library plumbing (which functions to call), not design quality. The responsive rule (`:241`) is `severity: WARNING`; the SweetAlert rule (`:223–228`) has a regex-able `forbidden_pattern` but lives in a reference pack read by zero enforcement path. (Note: do not over-claim "both are WARNING" — only responsive carries WARNING; the operative fact is *both are read by zero hooks*.) Enforcement: prose-only-aspirational. **Verdict: confirmed.**

**L2 — Self-learning memory has near-zero influence on UI quality.** *(F7-005.)* Memory is suggestion-only (never auto-applied), `outcomes.md` carries only operational telemetry (halts/retries/durations/violation counts — nothing visual), and the bolt-prompt memory READ is itself prose with no hook (zero memory-read/write telemetry events). Out of scope for UI quality. Enforcement: prose-only-aspirational. **Verdict: confirmed.**

---

## 6. Recommendations

Sorted DURABLE first (hook-enforced / sourced-enrichment / verification-gate), then a clearly-flagged LOW-CONFIDENCE bucket.

### DURABLE — prioritized top 5 (effort / impact)

**D1 — UI verification-gate as the 5th real block.** *(rec_type: verification-gate)*
Add a PostToolUse validator (`validate-ui-quality.sh`, clone `validate-bolt-artifacts.sh`) that fires on Write/Edit of `*.blade.php` / `*.vue` / `*.tsx` and asserts the **regex-checkable** mechanical conventions: layout-extends present, responsive breakpoint classes present, native `alert(|confirm(|prompt(` absent (SweetAlert idiom), basic `aria-`/`alt`/label attributes present. Write a **dedicated** `.ui-quality-blockers.json` (do NOT co-write `.validation-blockers.json` — that file is OVERWRITE-NOT-APPEND owned by `validate-handoff-binding-units.sh`; co-tenancy would clobber/race the binding state). Then add a **new `pre-tool-use` branch that reads `.ui-quality-blockers.json` and `emit_block`s `execute-bolts` on FAIL = a genuine 5th `emit_block` site**, cloning the existing Branch 1b pattern.
*Effort: M. Impact: high — the single highest-leverage durable fix; closes the §4 root.*
*Caveat: only mechanical conventions are deterministically gateable; visual hierarchy/spacing/composition is NOT regex-checkable — that part needs a human-in-loop checkpoint, not a regex.*

**D2 — `visual`/`a11y` acceptance_test type, required for UI units, on a BLOCKING path.** *(rec_type: verification-gate)*
Add a `visual`/`a11y` value to the acceptance_test enum AND make `validate-unit-spec.sh` require ≥1 such entry when `"ui_ux" in starterkit_relevance` (or `HAS_UI_COMPONENTS`). Critical: `validate-unit-spec.sh` is **detection-only** today — its FAIL must be routed to a PreToolUse-blocking path to bite. Populate the criteria from the propagated vault design-system + the framework-pack responsive rule, empty when source is silent (preserves anti-hallucination).
*Effort: M (validator must learn to parse acceptance_test, which it does not today). Impact: high — gives UI a definition-of-done that the gate actually reads.*

**D3 — Un-exclude `design_tokens` at `execute-bolts/SKILL.md:260` + verify the injection landed.** *(rec_type: sourced-enrichment + verification-gate)*
Inject the already-extracted `design_tokens.{colors,spacing,fonts}` (and the layout-file content as a worked example) into the T2 `ui_ux` slice within the ≤8KB budget. **Pair with a `validate-dispatch-prompt.sh` PostToolUse validator** that asserts the emitted dispatch prompt for a `ui_ux` unit actually contains the tokens — this is what makes the enrichment durable rather than prose the model can no-op.
*Effort: S–M. Impact: medium (brownfield only — recovers the existing app's palette; does not fix greenfield).*

**D4 — Add a view/component pattern category + extend the Iter 76 code-slice to UI, with exemplar-quality selection.** *(rec_type: sourced-enrichment + verification-gate)*
Add a `view`/`component` category to the `scan-codebase` patterns schema (extract a real `resources/views/*.blade.php`/component as `_source`), extend the code-example loop to inject it for UI units, and **select `_source` by linter-clean / idiom-conformance rather than `[0]`** so a mediocre sampled file does not become the hard ceiling. Verify via the same `validate-dispatch-prompt.sh` (D3) that a UI unit's prompt carries the exemplar.
*Effort: M–L. Impact: high — makes the one genuine quality mechanism reach UI at all.*

**D5 — Bridge `frontend-design` as hook-injected CONTEXT (not a prose Skill-invoke), routed on `ui_ux in starterkit_relevance`.** *(rec_type: sourced-enrichment)*
A hook cannot force a Skill call (that route is the 4×-failed prose pattern), but SessionStart anchor injection is shipped Fork A — inject `frontend-design`'s design-quality guidance TEXT into the bolt dispatch prompt via a hook when the unit is a UI unit. This gives the bolt a design engine's heuristics as material, deterministically delivered.
*Effort: M. Impact: medium-high — supplies the missing positive control. Must still be paired with D1/D2 so output is checked, not just better-prompted.*

**Additional durable (beyond top 5):**
- **CAPTURE Design-Source OQ gate** (verification-gate, C2): when UI components exist but all design_system_flags are false, emit a blocking high-priority OQ — do NOT relax the rail.
- **`validate-designsystem-propagation.sh`** (verification-gate, M1): assert UI units carry `06-constraints §Design system` citations when the design_system_flags are set.
- **Handoff-deadlock auto-escalation** (hook-enforced, H4/F1-008): `retry_count ≥ 2` surfaces the `rm` recovery instruction to the user automatically rather than burying it in a stopReason string; optionally extend `validate-handoff-yaml.sh` to enforce the `scope.id` enum + cross-metric, inheriting the Branch 1a block for free.
- **Clone the binding→units slice** to the next-highest-value handoffs (the proven Fork-A pattern, CLAUDE.md:88) before adding any new SKILL-body procedure.

### PROSE-ONLY — LOW CONFIDENCE (this is the pattern that FAILED 4× at Iter 64/65/67/66a)

These are recorded for completeness and explicitly de-prioritized. **History shows skill-body markdown wire-ups do not reliably change model behavior** (CLAUDE.md:75,92; MEMORY `feedback_artifact_verified_ships`). Do NOT rely on any of them as a fix:

- Adding "build good UI / make it look polished" prose to any SKILL.md or the dispatch contract.
- Adding the view/component category to the patterns *schema prose* or the code-slice *loop prose* WITHOUT the producer-side exemplar selection + `validate-dispatch-prompt` hook (i.e. D4 minus its hook half).
- "Re-labeling" orchestrate-flow steps as "advisory / model-executed", or adding a disclaimer paragraph to SKILL.md (honest, but not behavior-changing).
- Rewording the anti-halu "do not deviate" rail to "you MAY improve quality" (best-effort prose; the exemplar-quality fix belongs at the producer).
- Telling generate-units in prose to "also read 06-constraints and propagate it" without the backing `validate-designsystem-propagation.sh` (M1 minus its hook).
- Skill-invoking `frontend-design` by prose instruction (a hook cannot force it; this is the 4×-failed mode — use D5's context-injection instead).

---

## 7. Evidence gap

**No real-run corpus of generated UI code exists in this repo.** `find` for `bolt-report*.md` → zero matches; `find` for `*.blade.php`/`*.vue`/`*.tsx`/`*.jsx` outside `node_modules` → zero. The only `bolts/` directory is a test fixture (`tests/fixtures/iter77-range-shorthand/.../bolts/`) whose `U-001…U-025` subdirs contain only empty `.gitkeep`. The only real vault (`examples/timeoff/vault/`) is design-thin by construction. The user generates against a Laravel target that is not on disk here, so those outputs are out of audit scope.

**Consequence:** this audit argues root cause **structurally — from inputs (what reaches the bolt) and process (what gets checked)** — because there is no bad-UI artifact to point at. Per the author's own "artifact-verified ships" principle, the next iteration should be evidence-driven: **the user should supply ONE concrete case of disappointing UI/UX output** (the unit spec(s), the dispatched bolt prompt if recoverable, and the generated view file). That single artifact would let us confirm which stage actually starved or failed — and would gate any "Iter 76 / squad / enrichment improves UI" claim against a real-run bolt-report rather than a fixture.

---

## 8. Coverage

**Examined:** all 4 hook scripts (`pre-tool-use`, `post-tool-use`, `session-start`, `stop`) + `hooks.json`; the 4 `emit_block` blocking sites and the SessionStart guards; the ~16–19 PostToolUse `validate-*.sh` validators (read or grepped scripts-wide for UI vocabulary); `execute-bolts` SKILL.md + `bolt-dispatch-prompt.md` + `superpowers-bridge.md`; `generate-units` SKILL.md + `unit-schema.md`; `generate-intent` SKILL.md (anti-hallucination rail) + the real `examples/timeoff/vault/` density; the framework-convention packs (`laravel-base-26.md`, `_universal.md`, `laravel.md`); `scan-codebase` patterns schema + `ui-libs.md` token extraction; `detect-drift`, `memory`, squad references; CLAUDE.md Fork A scope + `fork-a-recovery-map.md`; the vendored superpowers TDD / executing-plans skills. Every gate/mechanism was graded against the Fork A line (hook-enforced vs prose) and the recon-stage `enforcement_status` over-credits were corrected via adversarial verdicts.

**Did NOT examine:** the user's actual Laravel target project (not on disk); any real-run generated UI code or bolt-report (none exist in repo); runtime telemetry beyond the root `.mega-sdd/` snapshot; the full per-line behavior of every one of the ~19 validators (a representative subset was read; the rest were grepped for UI vocabulary, returning zero substantive matches); whether the PostToolUse hook *actually fires* for an arbitrary target CWD (a documented Fork-A installation caveat); and Fork B control-plane items (implicit re-plan detection, lazy-load tier enforcement) which are explicitly parked and out of scope. The sweeping "~22 gates, zero UI" roll-up rests on the 4 blocking gates (independently read) + the scripts-wide UI grep (independently run); the bolt pre/post-flight and acceptance-test surfaces were assessed as prose, not as enforced gates.
