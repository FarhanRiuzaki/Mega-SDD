# E2E Integration Audit — Iter-78 Code-Delivery Sharpening (v3.69.0)

**Date:** 2026-06-02
**Branch under audit:** `feat/sharpen-code-delivery-uiux` (v3.69.0)
**Scope:** the integrated 8-gate `execute-bolts` enforcement stack (5 new validators + 2 extended), each wired PostToolUse → `.<name>-state.json` + a PreToolUse branch that blocks `mega-sdd:execute-bolts` on `status==FAIL` (or precise `halt_type` count for the two extensions).
**Spec:** `docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md`
**Method:** read-only audit. Every finding was reproduced by code-read + runtime gate execution on `/tmp` copies. The real fixture `new-tradefinance-import` (Laravel) was read-only — never gated against directly, never edited.
**Mandate checked:** tech-agnostic (graceful SKIP on non-Laravel / no-pack; no false block; no crash) per spec §1.1 / §4.

---

## 1. Executive summary

**The integrated 8-gate system is DEADLOCK-SAFE but NOT precision-sound.** The composition layer is clean — verified no hard deadlock (CD-1), well-formed independent case blocks with fail-open-on-parse-error (CD-5), and surgically-scoped `halt_type` filters on the two extension gates that prevent their pre-existing FAILs from spuriously gating bolts (CD-6/IE-4). But the *content* layer fails in **both directions at once**:

- **Over-blocks correct and non-Laravel code (hard block).** Four confirmed false-positive gates fire on code that is already correct: ui-quality blocks correct Blade partials/modals (FPP-2, critical), cross-cutting blocks the scope-SOURCE `User` model that must NOT self-scope (FPP-3, high), sibling-consistency blocks every FK-bearing unit that derives accessors by ORM convention (FPP-4, high), and — most severely against the tech-agnostic mandate — sibling-consistency false-FAILs **any** non-Laravel project that declares an FK, because its relation detection hardcodes the Eloquent paren-call idiom (TAE2E-01, critical).
- **Misses its target defects on the dominant real input shapes (silent PASS / fail-open).** A single stray UTF-8 byte from a PRD copy-paste crashes flow-coverage + sibling-consistency and silently disables the gate (ADV-01, critical). The flow-step parser only recognizes `N.` numbered steps, so mermaid/bullet/`N)` flows — one of the two real production formats — produce a silent PASS (ADV-02, high). The vault-oqs workflow detector misses inflected decision verbs (`approves`/`reviews`/`confirms`) so a real maker-checker flow passes both operator-UX rails (ADV-03, high). The ui-quality scaffold-tell regexes are wholesale-evadable (ADV-04, high).

**The single most important integration risk** is a composition-level emergent property no individual finding names: **`emit_block` exits on the FIRST failing gate (CD-4), and on a real Laravel project at HEAD multiple confirmed false-positive gates (FPP-2 + FPP-3 + FPP-4) fire simultaneously on code that is already correct.** The agent therefore faces serial invoke→block→invoke round-trips against gates that have **no legitimate fix** — the code is correct, so each "recovery" is either editing correct code to satisfy a brittle regex, or `rm`-ing the state file. That is the integration failure: the stack does not reliably permit correct code through, and where it blocks there is frequently nothing real to fix.

---

## 2. Gate composition — the 8 execute-bolts gates

The PreToolUse hook (`plugins/mega-sdd/hooks/pre-tool-use:108-552`) gates `mega-sdd:execute-bolts` through **9 branches** total: the universal handoff Branch 1a (`mega-sdd:*`, minus the `using-mega-sdd` anchor) plus **8 execute-bolts-scoped branches** at case sites `:228` (1b binding→units), `:263` (B5 flow-coverage), `:300` (B7 sibling-consistency), `:337` (B6 render-test), `:366` (B8 ui-quality), `:405` (B9 dispatch-prompt), `:444` (B10 vault-oqs), `:471` (B11 cross-cutting). PostToolUse (`async:true`, `hooks.json:34`) is the producer; PreToolUse (`async:false`) is the synchronous consumer.

**Deadlock risk — NONE (CD-1, CD-5, verified).** Every gate is independently clearable by an action *other than* the gated skill: (a) editing the owning artifact re-triggers the validator via a PostToolUse glob, and state files are OVERWRITE-NOT-APPEND so a PASS/SKIP overwrites a prior FAIL; (b) the 7 new state files + Branch 1a's `.handoff-validation-state.json` are NOT in Branch 2's anti-bypass protected regex (`pre:532`), so `rm` is allowed. Only Branch 1b's `.validation-blockers.json` is `rm`-protected, and it clears via fix-and-revalidate using agent-editable inputs. No circular dependency exists — each validator reads only its OWN state file. The case blocks are independent siblings with exact-string matching and no inter-branch fall-through; malformed state files fail OPEN (parse error → PARSE_ERROR/UNKNOWN/0, none of which equal the FAIL trigger).

**One real recovery-text defect — CD-2 (high): Branch 9's REASON is CIRCULAR.** The dispatch-prompt is written by `execute-bolts` mid-turn, but PreToolUse fires *before* the body runs, so a stale FAIL blocks the invocation before the prompt can be re-emitted. The REASON (`pre:428`) instructs only "re-run execute-bolts (re-emitting the prompt re-validates)" — the exact action just blocked. A literal-instruction-following agent loops invoke→block→same-REASON→invoke. The real escapes (direct Edit of `dispatch-prompt.md` adding a `Design tokens:` + `Pattern: view` line; or `rm` the non-protected state file) are absent from the REASON. Contrast Branch 1a (`pre:217`), which documents its `rm` escape explicitly. A related recovery-text trap exists at Branch 10 (CD-3, medium): its REASON leads with "re-run generate-intent," which (per Fork-A anti-hallucination doctrine) may regenerate a vault that re-FAILs the same deterministic content check — the deterministic escape (add the Design-Source OQ directly to the vault) is buried.

**Multi-failure diagnosis — only the FIRST emit_block fires (CD-4, medium).** `emit_block` (`pre:92-101`) writes one `stopReason` and `exit 0`, short-circuiting all later branches; no pre-scan/aggregation exists. A vault failing (say) flow-coverage + sibling-consistency + ui-quality surfaces only flow-coverage's REASON, forcing N serial invoke→block round-trips with no upfront visibility of the total failure set. This is recoverable (not a deadlock) but is a real diagnosis cost — and it is the multiplier behind the §1 headline risk when the failing gates are false positives with no real fix. The physical branch-order inversion (B7 `:300` precedes B6 `:337`) is benign: it only changes which REASON shows first.

**Recovery — sound in shape, weak in text.** The mechanism (artifact edit → PostToolUse re-validate → state overwrite) is verified to work end-to-end. The defects are in the *guidance* (CD-2 circular, CD-3 mis-ordered) and in the *serial cost* (CD-4), not in the clearability itself.

---

## 3. False-positive risk — does any gate block a legit/real project?

**Yes — four confirmed false-positive hard blocks fire on correct code (`new-tradefinance-import` HEAD shape).** All are hook-enforced genuine `{"continue": false}` blocks of the next `execute-bolts`, not graceful SKIPs.

- **FPP-2 (CRITICAL) — ui-quality blocks correct Blade partials/modals.** `validate-ui-quality.sh:28` claims "trivial views / partials are exempt," but the only exemption in the scan loop is `if n_lines > min_view_lines (20)` (`:381`). A 72-line Bootstrap-modal partial (`_partials/batch-modal.blade.php`) is flagged for BOTH `layout-extends` ("no @extends app layout") and `responsive` ("no row/col-*") — both structurally WRONG for an `@include`'d partial whose parent supplies the layout. `scaffold_stub_glob` is parsed (`:187,:242`) but never consulted. Reproduced on a faithful fixture: a 37-line `modal fade` partial under `_partials/` → status FAIL, 2 `required_element_missing`. Because the gate is project-wide current-truth, this FAIL blocks bolts even for a backend-only unit.
- **FPP-3 (HIGH) — cross-cutting is intent-blind; flags the scope-SOURCE `User` model.** `User.php` carries `branch_id` as the user's home branch — it is the SCOPE SOURCE that *drives* `BranchScoped` onto other models; self-scoping it would break auth. The validator's rule ("table has `branch_id` ⇒ MUST register `BranchScoped`") cannot read this intent (flagged "(by class-name match)"). Reproduced on a `/tmp` fixture built from the real unmodified `User.php`: status FAIL, `missing_registration[0].file=app/Models/User.php`. There is no exemption/opt-out path anywhere in the validator (grep: none). `Customer.php`/`GlJournalEntry.php` are AMBIGUOUS (needs-domain-confirmation), but `User` alone proves intent-blindness.
- **FPP-4 (HIGH) — sibling-consistency forces every FK to spell out its accessor.** The `missing_relations` check (`:280-292`) flags EVERY declared FK column whose camelCase accessor (`branch()`, `customer()`) is not literally in the unit body — with NO sibling comparison at all (a solo unit with zero siblings is still flagged; reproduced). This contradicts the header's "fan-out divergence" framing (`:10`). Units that declare FK columns as data-model fields and let Eloquent derive `belongsTo` by convention are uniformly flagged — the signature of a spec-AUTHORING-STYLE mismatch, not a real inter-sibling inconsistency.

**NOT a false-positive (reclassified per FPP-5 reframe):** flow-coverage `dead_scaffold` flagging the `{...,edit}` brace-shorthand is a **TRUE-POSITIVE spec-hygiene flag**, not a false positive on correct code. The gate reads the unit SPEC's `## Target files`, never shipped code, and fires at the *decomposition* stage *before* any code exists on disk. The remedy is a one-line spec prune (`{index,create,show}`), exactly the `good`-fixture's intended fix. Real coupling note worth carrying: `find_flows_and_units` picks the vault with the most units, so the FAIL covers ALL units — one unit's stale shorthand blocks the whole execute-bolts run for unrelated units.

**TRUE positives working as designed (retroactive on the pre-Iter-78 vault) — FPP-6 reframed.** vault-oqs Branch 10 DOES block the phase-2 vault via `design_source_oq_missing` (reproduced: all 6 docs return gating FAIL). This is a real operator-UX rail catching a genuine spec gap. **Reframe correction:** the trigger is NOT "any vault with `HAS_UI_COMPONENTS=true` + no Design-Source OQ" (that universal claim is FALSIFIED by phase-1, which has identical flags yet PASSes). The real trigger requires a 4th precondition — `vault_has_workflow_flow` (a maker-checker / multi-stage approval flow in 04-flows). The validator's OWN header (`:16-18`) omits this precondition: an inherited doc/code mismatch. render-test (Branch 6) is the parallel true-positive: view-bearing units U-026..U-039 carry only prose `## Acceptance`, no structured render test.

---

## 4. Tech-agnostic E2E — per-validator behavior on a non-Laravel/no-pack project (the user mandate)

Resolver fallback verified correct on both axes (TAE2E-02): a named-but-nonexistent pack (`framework_pack: django`) → `# pack file django.md not found — falling back to _universal`, exit 0; and no-manifest → `_universal (via fallback (no manifest))`, exit 0. `_universal.md` deliberately declares section HEADERS but prose-only bodies (no machine-parseable keys), so the literal `status:SKIP` path IS reachable end-to-end for real no-pack projects (TAE2E-03) — graceful degradation by principle-not-signature design.

Per-validator result on a clean no-pack non-Laravel fixture (Django models, React `.jsx` + Django `.html` views, well-formed unit):

| Validator | Result | Gates? | Tech-agnostic OK |
|---|---|---|---|
| flow-coverage (B5) | SKIP (no parseable `endpoint_kinds`) | no | yes |
| **sibling-consistency (B7)** | **FALSE-FAIL when an FK is declared** | **BLOCKS** | **NO (TAE2E-01)** |
| render-test slice / unit-spec (B6) | render check SKIPs (no `detail_view_glob`); `render_test_missing`=0 | no | yes (TAE2E-04) |
| ui-quality (B8) | SKIP (no `view_glob`) | no | yes |
| dispatch-prompt (B9) | SKIP (no `view_glob`) | no | yes |
| vault-oqs / operator-UX (B10) | PASS (no pack dependency; condition-gated on workflow) | no | yes (TAE2E-04) |
| cross-cutting (B11) | SKIP (no `registration_signature`) | no | yes |

**6/7 exit-0 SKIP/PASS, NONE crash. The lone deviation is the most severe finding in this dimension:**

- **TAE2E-01 (CRITICAL) — sibling-consistency false-FAILs ANY non-Laravel FK project, violating the core tech-agnostic mandate.** On a pure-`_universal` Django fixture declaring `foreign key column branch_id` (relation expressed the Django way via attribute access `order.branch`), the validator returns status FAIL with `missing_relations=[{expected_accessor:'branch()'}]` → Branch 7 emits a genuine `{"continue": false}` block of `execute-bolts` (driven through the real hook). Root cause is layered: `_universal.md:194-211` declares only the PRINCIPLE (FK ⇒ relation accessor) and a `fk_to_accessor` default, but the validator's `accessor_declared` (`:236-238`) hardcodes `\b<accessor>\s*\(` — a paren CALL, which is Eloquent/ActiveRecord-shaped, not universal. `relation_enabled` (`:159-164`) only string-matches `fk_to_accessor`/`relation_derivation` to switch the check ON; it never parses a pack-supplied accessor SHAPE — even Laravel's own `accessor_template: '{camelSingular}()'` (`laravel.md:402`) is ignored. So a pack CANNOT override the paren requirement; the stack idiom is baked into the core. The detection is brittle both ways: it false-PASSes when an incidental `Word (` substring matches (e.g. `customer_id` + `class Customer(models.Model):`), and false-FAILs on a legitimate non-paren relation.

**Why the other 6 hold:** the 5 net-new validators write literal `status:SKIP` on absent-pack (Branches 5/7/8/9/11 read `status==FAIL`, so SKIP is non-blocking), and the 2 extensions degrade by omission — unit-spec's render check is pack-gated behind `if detail_glob:` (`validate-unit-spec.sh:421`) so `render_test_missing`=0 when no pack declares `detail_view_glob`, and vault-oqs has NO framework-pack dependency at all (its rails are condition-gated on a vault workflow signal, not a stack). The `$(resolver …) || VAR=""` degradation idiom (no `set -e` after the call) means a resolver exit-3 degrades to an empty section → SKIP, never a crash.

---

## 5. Fork-A enforcement — per-gate hook-wiring confirmation (real vs prose)

Every gate's *mechanism* (validator runs → writes state → PreToolUse reads state → emit_block) was reproduced end-to-end by driving the real hooks, not by reading skill prose. This is the strongest dimension of the integration.

| Gate | Enforcement | Evidence |
|---|---|---|
| B5 flow-coverage | **hook-enforced** (real) | FA-1: validator emits literal `FAIL` (`:782`), PostToolUse dispatches on unit-write glob, PreToolUse blocks; PASS/SKIP proceed. |
| B7 sibling-consistency | **hook-enforced** (real) | FA-1: same chain; no cross-firing; bolts-only scope confirmed. |
| B6 render-test | **hook-enforced** (real) | FA-2: gates on `halt_type==render_test_missing` COUNT, not status — proven non-tautological (status PASS + render issue → BLOCKS; status FAIL + other halt_type → no block). Producer emits the exact filtered string (`validate-unit-spec.sh:427`). |
| B10 operator-UX | **hook-enforced** (real) | FA-2: gates on `operator_surface_missing`/`design_source_oq_missing` COUNT; pre-existing OQ-citation FAILs do NOT gate. Producer emits exact strings (`validate-vault-oqs.sh:376,412`). |
| B9 dispatch-prompt | **hook-enforced** (real) | FA-3: validator emits exact `summary.*` keys Branch 9 reads (`pre:422`); FAIL state blocks, PASS proceeds. Default write path is parent-thread (more solidly enforced than 8/11). |
| B8 ui-quality | **MIXED** | FA-4: validator-runs half PROVEN (PostToolUse Write of a bad view → FAIL → PreToolUse blocks). But the triggering view-write is frequently subagent-internal under `--parallel`/`--per-squad` (invisible to parent PostToolUse, `post:14-18`), so it is a detect-and-block-NEXT gate — a false-negative window persists until a later parent-thread Write re-triggers the project-wide rescan. |
| B11 cross-cutting | **MIXED** | FA-4: same detect-and-block-NEXT shape; validator provably runs+emits FAIL and PreToolUse blocks, but the model-write is often subagent-internal. |

**Load-bearing nuance (FA-6, reframed):** the dispatch globs are cheap TRIGGERS, not the scan boundary — ui-quality and cross-cutting re-resolve the active pack and rescan the entire project-wide glob (current-truth), which is the safety net keeping 8/11 "mixed" rather than "prose-only." **Reframe correction:** the original "all 7 dispatch globs" is wrong — only 5 of 7 validators are glob-dispatched (via 4 case-globs; flow-coverage+sibling share the unit-write glob); unit-spec and vault-oqs run UNCONDITIONALLY on every Write|Edit, so they are not "triggers" at all. The rescan-on-trigger insight (picks up files never directly observed, incl. subagent writes) stands. Tech-agnostic SKIP contract holds across all gates: SKIP and PASS produce empty hook output (FA-5).

**Default sequential `execute-bolts` is fully enforced for 8/11** (executing-plans runs parent-thread, writes are parent-visible). The residual gap is specific to `--parallel`/`--per-squad`. Recommended hardening (FA-4): execute-bolts post-flight (parent thread) explicitly bash-invokes both project-wide validators after each bolt batch, refreshing the state regardless of who wrote the file.

---

## 6. Findings — by severity

### CRITICAL

**ADV-01 — Inducible fail-open: invalid-UTF8 / cp1252 paste CRASHES flow-coverage + sibling-consistency → gate silently disabled.**
Location: `validate-flow-coverage.sh:624,545` + `validate-sibling-consistency.sh:198` (bare `open()`, no `errors="replace"`); masked by `post-tool-use:394,402` (`>/dev/null 2>&1 || true`); fail-open read at `pre-tool-use:265,302`. Enforcement: hook-enforced. tech_agnostic_ok: **false**. Verdict: **confirmed/reproduced.** A single `0xC3 0x28` byte (a copy-pasted en-dash/smart-quote from a PRD) → `UnicodeDecodeError`, no state written, crash fully swallowed (zero log), `if [ -f STATE ]` false → bolts NOT blocked. Note: `validate-ui-quality.sh:362` and `validate-cross-cutting-registration.sh:174` DO pass `errors="replace"` — the asymmetry is the root cause. Scoped to fresh/poison-from-first-authoring or a same-save FAIL masked by a stale PASS.

**FPP-2 — ui-quality blocks correct Blade partials/modals ("partials exempt" documented but unimplemented).** (See §3.) Location: `validate-ui-quality.sh:28` vs `:380-390`, `:342`, `:187/:242`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.**

**TAE2E-01 — sibling-consistency false-FAILs + BLOCKS any non-Laravel FK project (hardcoded Eloquent paren-call idiom).** (See §4.) Location: `validate-sibling-consistency.sh:238,159-164,280-292`; `pre-tool-use:301,311`; `_universal.md:194-211`. Enforcement: hook-enforced. tech_agnostic_ok: **false**. Verdict: **confirmed/reproduced.** *Directly violates the spec §1.1 tech-agnostic mandate.*

### HIGH

**CD-2 — Branch 9 (dispatch-prompt) ships CIRCULAR recovery text.** (See §2.) Location: `pre-tool-use:404-433` (REASON `:428`); `dispatch-prompt.sh:240,246`; `post-tool-use:448-455`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.**

**FPP-3 — cross-cutting is intent-blind; false-positives the scope-SOURCE `User` model.** (See §3.) Location: `validate-cross-cutting-registration.sh` → `.cross-cutting-state.json:60`; `pre-tool-use:472-496`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.**

**FPP-4 — sibling-consistency `missing_relations` is an absolute "every FK must name its accessor" rule (uniform spec-style false positive).** (See §3.) Location: `validate-sibling-consistency.sh:10` vs `:280-288`, `:236-238`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.**

**ADV-02 — flow-coverage step parser only recognizes `N.` numbered steps → bullets / `N)` / mermaid flows produce a silent PASS.**
Location: `validate-flow-coverage.sh:639-663` (`split_step_blocks`, gated on `^\s*\d+\.\s`). Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.** One of the two real production formats is fully bypassed — the real Phase-1 `04-flows.md` is 100% mermaid flowcharts (zero `N.` steps), so the entire coverage check is inert; Phase-2 (numbered) IS detected. Emits a false-confidence PASS, strictly worse than a SKIP.

**ADV-03 — vault-oqs workflow detector misses inflected decision verbs (`approves`/`reviews`/`confirms`/`rejects`) → maker-checker undetected → both operator-UX rails inert → silent PASS.**
Location: `validate-vault-oqs.sh:249-253` (`DECISION_STEP_RE`, `\b`-anchored bare lemmas) + `:261-280`; spec intent at `generate-intent/references/vault-contract.md:72`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.** Spec-vs-regex divergence; shares the `^\s*\d+\.\s` numbered-only parser with ADV-02.

**ADV-04 — ui-quality scaffold-tell regexes are wholesale-evadable (two-word/uppercase labels, array-access/spaced-arrow FK echoes, non-amount money columns); required_elements empty on plain-laravel pack.**
Location: `laravel.md:327-342` (regexes), consumed by `validate-ui-quality.sh:333-336,369-378`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.** Same five defect classes reshaped → status PASS, 0 tells. The `required_elements` half is inert unless a starterkit pack supplies them.

**IE-1 — new gates read state written by an async PostToolUse producer (same-turn read-before-write timing window).**
Location: `hooks.json` (PostToolUse `async:true`) vs `pre-tool-use:264-496`; `post-tool-use:392-565`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **reframed (high→low/medium).** The async-producer/sync-consumer pattern is real, but the harm is overstated: branches are FAIL-direction (state ABSENT → fail-OPEN, only on genuine first-run; OLD FAIL persists during in-flight re-validate → fail-CLOSED/safe); detect-and-block-next is the *intended, documented* behavior (spec `:26-28`), not a race; and the invariant is inherited from `validate-handoff-binding-units` (identical async path, real-run-verified). Survives as a **defense-in-depth hardening note**: document the same-turn timing contract; add a soak test (write failing unit → immediately invoke execute-bolts same turn → confirm block).

### MEDIUM

**CD-3 — Branch 10 (vault-oqs) recovery leads with "re-run generate-intent" (potentially non-converging); deterministic escape (emit OQ) buried.** (See §2.) Location: `pre-tool-use:443-462` (REASON `:457`); `validate-vault-oqs.sh:368-425`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.**

**CD-4 — emit_block exits on FIRST failing gate; simultaneous multi-gate FAIL is serialized into N invoke→block round-trips (no single multi-failure diagnosis).** (See §2 + §1 headline.) Location: `pre-tool-use:92-102`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.**

**ADV-05 — sibling-consistency missing-relation requires literal `FK`/`foreign` on the FK column line → a naturally-declared `branch_id` escapes the accessor check.**
Location: `validate-sibling-consistency.sh:220-229` (`declared_fk_columns` gated on `\b(fk|foreign)\b`). Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.** Fix must thread a needle: the keyword-gate is intentional (avoids matching FK names mentioned only in prose, e.g. `lc_id correlation`), so detecting by `<name>_id` shape needs a prose-exclusion heuristic (backticked token / Schema block).

**ADV-06 — cross-cutting: a comment mentioning the registration signature satisfies the check (false negative on a real leak); `addGlobalScope($var)` indirect registration is flagged (false positive blocking execute-bolts).**
Location: `validate-cross-cutting-registration.sh:188-189,225` (`reg_re` applied to whole file text incl. comments). Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.** Secondary no-`$table` class-token escape reframed to a lower-value edge gap (idiomatic `Bill`→`bills` IS caught).

**ADV-07 — render-test false-positive on inline-list `acceptance_test`; dispatch-prompt vacuous-pass on placeholder marker lines.**
Location: `validate-unit-spec.sh:413-417` (block-form-only `acceptance_test` regex); `validate-dispatch-prompt.sh:240,246` (label-presence checks). Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.** An inline-list `acceptance_test: [{type: render}]` (YAML-equivalent) is wrongly blocked at Branch 6; a `Design tokens: TODO none captured yet` placeholder + bare `Pattern: view` label + controller-only File: citation passes Branch 9 with 0 issues.

**IE-2 — vault-oqs writes OVERWRITE-not-append and self-gates per single written file → Branch 10 state can go stale relative to live vault truth.**
Location: `validate-vault-oqs.sh:60-63,65,427-452`; `post-tool-use:562-565`; `pre-tool-use:445-456`. Enforcement: hook-enforced. tech_agnostic_ok: true. Verdict: **confirmed/reproduced.** INTENDED current-truth-until-next-matching-write semantics, but reachable staleness via non-Write/Edit vault mutations (Bash/sed edits, git checkout) — and symmetrically a stale PASS can fail-OPEN against a now-broken vault. Document that Branch 10/6 gate on the LAST matching-file write, not live truth.

### LOW

- **CD-1** — verified no-defect: 8-gate stack cannot hard-deadlock; every gate independently clearable. (confirmed)
- **CD-5** — verified clean: independent case blocks, exact matching, fail-open on parse error. (confirmed)
- **CD-6 / IE-4 / FA-2 / TAE2E-04** *(deduped — one property)* — Branches 6 & 10 use PRECISE `halt_type` counting (not `status==FAIL`), so the two extensions' pre-existing FAILs do NOT spuriously gate bolts, and the render check / vault-oqs degrade gracefully on no-pack. This is the load-bearing integration-safety property AND a verified design strength; the 5 net-new validators correctly emit `status:SKIP` on absent pack. (confirmed; **design strength, no change** — but document that any FUTURE issue type on these extensions is non-blocking until a branch opts it into the filter.)
- **TAE2E-02 / TAE2E-03 / FA-5** *(deduped — one property)* — tech-agnostic SKIP contract holds end-to-end: resolver falls back to `_universal` on both named-nonexistent-pack and no-manifest; `_universal` declares prose-only bodies so 5/7 validators SKIP gracefully; no false block, no crash; `$(resolver) || VAR=""` degradation never aborts. (confirmed; no change.)
- **IE-3** — both extended validators preserve original checks; new issue types are strictly additive on the same `issues[]`+`halt_type` envelope the helper requires; no KeyError. (confirmed; no change.)
- **IE-5** — skill PROSE cites correct branch numbers (no prose-vs-validator contradiction), but the design spec `2026-06-01-...md:115` carries a STALE branch number (says "Branch 5" for slice E/UI; shipped code put UI on Branch 8). Enforcement: mixed (doc). (confirmed.)
- **IE-6** — 5 Style-A validators emit no `halt_self_resolved` telemetry; the 2 helper-routed extensions do → observability asymmetry (gate-fire analysis under-counts the 5). Not a correctness break (gates read state files, not telemetry). (confirmed; conditional impact.)
- **FA-1 / FA-3** — full chains for Branches 5/7/9 re-confirmed hook-enforced end-to-end (not prose). (confirmed.)
- **FA-6** — dispatch globs are cheap triggers, not the scan boundary; rescan-on-trigger is the current-truth mechanism. (reframed: 5 of 7 glob-dispatched, not all 7; core stands.)

---

## 7. Prioritized remediation

Ordered: criticals → highs → mediums → docs. Each marked **durable** (validator / pack / hook / fixture change — survives autonomously) or **prose-only (LOW-CONF)** (skill-body / doc text the model may no-op).

1. **[CRITICAL · durable]** ADV-01 — add `errors="replace"` to the 3 bare `open()` calls in `validate-flow-coverage.sh:624,545` + `validate-sibling-consistency.sh:198` (match ui-quality:362 / cross-cutting:174). Also `validate-unit-spec.sh` read. Stop masking validator exit≠0 silently in `post-tool-use` — log crashes to `hook-debug.log`. *(Cheapest, highest leverage — fixes a silent gate-disable.)*
2. **[CRITICAL · durable]** TAE2E-01 — make the accessor SHAPE pack-declared, not core-hardcoded: add `accessor_form: call|attribute` to `_universal` `relation_derivation:`, have `accessor_declared` honor it; default `_universal` to attribute-or-call. OR demote `missing_relations` to advisory when resolving to `_universal`. *(Restores the tech-agnostic mandate.)*
3. **[CRITICAL · durable]** FPP-2 — exempt partial/component paths from `required_elements`: honor the already-parsed `scaffold_stub_glob`, or skip basenames starting `_` and files under `*/_partials/`, `*/partials/`, `*/components/`. Keep `scaffold_tells` on all views.
4. **[HIGH · durable]** CD-2 — rewrite Branch 9 REASON (`pre-tool-use:428`) to LEAD with a non-circular escape (direct Edit of `dispatch-prompt.md` adding `Design tokens:` + `Pattern: view`; or `rm` the non-protected state file), mirroring Branch 1a; keep "re-run execute-bolts" secondary.
5. **[HIGH · durable]** FPP-3 — add a pack-declared exemption marker (`// not-branch-scoped: <reason>` or a scope-source-class glob) to the Cross-cutting section; grade `User` the FP; surface `Customer`/`GlJournalEntry` as "needs domain confirmation," not auto-block.
6. **[HIGH · durable]** FPP-4 — downgrade `missing_relations` to advisory (accessors are conventionally derived), OR make it a true consistency check (flag an FK accessor named in SOME siblings but not others), not an absolute per-unit rule.
7. **[HIGH · durable · fixture]** ADV-02 + ADV-03 (shared parser) — broaden the step detector in BOTH validators to recognize `- `/`* ` bullets, `N)` paren numbering, and mermaid `-->`/node-label transitions; make `DECISION_STEP_RE` inflection-tolerant (`approv(?:e|es|ed|al|ing)`, `review(?:s|ed|ing)?`, `confirm(?:s|ed|ing|ation)?`, `reject(?:s|ed|ing|ion)?`, `countersign…`). Add a mermaid/bullet-shaped `04-flows` fixture test (model on real Phase-1).
8. **[HIGH · durable · pack]** ADV-04 — tighten pack tell regexes: multi-word + uppercase ID labels; FK echoes via array-access + spaced arrows; heuristic money (decimal-cast / `*_amount`/`*_total` suffixes) not a 4-word allow-list. Document the inert `required_elements` half on generic Laravel.
9. **[MEDIUM · durable]** ADV-07 — render-test: accept inline-list/inline-map `acceptance_test` in addition to block form. dispatch-prompt: require a non-empty `design_tokens` value (reject placeholder) and tie `has_view_exemplar` to a cited `File:` that matches the pack `view_glob`, not a bare `Pattern: view` label.
10. **[MEDIUM · durable]** ADV-06 — strip PHP comments/docblocks before scanning (closes the false-negative); broaden the signature to accept indirect `addGlobalScope($var)` where `$var = new BranchScoped(...)` is assigned in the same `booted()` (closes the false-positive that blocks idiomatic code).
11. **[MEDIUM · durable]** ADV-05 — detect FK columns by the `<name>_id` shape, with a prose-exclusion heuristic (require a backticked token / inside a Schema/Columns block) to preserve the intentional anti-prose-match behavior.
12. **[MEDIUM · durable]** CD-3 — reorder Branch 10 REASON (`pre-tool-use:457`) to lead with the deterministic direct-vault-edit escape (add the Design-Source OQ / operator surface to the vault doc); mention `rm .vault-oqs-state.json`; position "re-run generate-intent" last.
13. **[MEDIUM · durable]** CD-4 — before the first `emit_block` in the execute-bolts path, read all 8 state files; if >1 is FAIL, prepend a one-line summary ("3 gates failing: …") so the agent can batch fixes. Additive text, not control-flow change.
14. **[MEDIUM · durable]** IE-2 (+ FA-4 hardening) — have execute-bolts post-flight (parent thread) bash-invoke `validate-ui-quality.sh` + `validate-cross-cutting-registration.sh` + `validate-vault-oqs.sh` after each bolt batch, refreshing state regardless of who wrote the file (closes the subagent-blind window AND the staleness window).
15. **[LOW · prose-only (LOW-CONF)]** IE-1 — document the same-turn async timing contract in each branch REASON ("a missing/stale state is possible; the gate re-fires next turn"); add the same-turn soak test (durable test, but the contract note itself is prose).
16. **[LOW · prose-only (LOW-CONF)]** IE-5 — fix the stale spec branch number at `2026-06-01-sharpen-code-delivery-uiux-design.md:115` (slice E → "Branch 8"); optionally renumber branches in file order to remove the 7-before-6 inversion.
17. **[LOW · prose-only (LOW-CONF)]** CD-6/IE-4 + TAE2E-03 — document the design invariants so a future contributor does not regress them: (a) gates on the 2 extension validators MUST use precise `halt_type` counting, never `status==FAIL`; (b) `_universal` intentionally backstops only the reasoning PRINCIPLE — adding concrete signatures there would silently convert SKIPs into runs.

---

## 8. Coverage

**Exercised (reproduced by code-read + runtime gate execution on `/tmp` copies):** all 9 PreToolUse branches that gate `execute-bolts`; deadlock-safety (escape paths a+b); all 7 validators' SKIP/PASS/FAIL paths; resolver fallback on named-nonexistent-pack + no-manifest; per-validator no-pack non-Laravel E2E (6/7 SKIP/PASS, 1 false-FAIL); halt_type-precise filtering (consumer + producer halves); the async producer/sync consumer state-read dependency and fail-direction; adversarial bypass on the dominant real flow shapes (UTF-8 crash, mermaid/bullet/paren steps, inflected verbs, evasive UI tells, comment/indirect registration, inline acceptance_test, placeholder dispatch markers); the real `new-tradefinance-import` `User.php`, Phase-1 + Phase-2 `04-flows.md`, and `_partials/batch-modal.blade.php` (read-only).

**NOT exercised / out of scope:** (a) the harness's actual async scheduling window (a gate unit-test cannot reproduce harness timing — IE-1's window is reasoned from the `async:true` flag, not run); (b) real Agent subagent dispatch under `--parallel`/`--per-squad` (cannot dispatch subagents from bash — the subagent-blind FA-4 gap is confirmed by the documented `post:14-18` limitation, not runtime-tested); (c) the project-wide quantitative scale of FPP-2 ("232 views, 51/153 on partials") — mechanism verified on one fixture + one read-only real file, counts illustrative; (d) the `Customer.php`/`GlJournalEntry.php` ambiguous cross-cutting cases (needs-domain-confirmation, not adjudicated); (e) skill-body prose execution parent-side (FA-3's "more solidly enforced" ranking is an architectural observation consistent with the skill as written, per the Fork-A best-effort doctrine, not a runtime guarantee).
