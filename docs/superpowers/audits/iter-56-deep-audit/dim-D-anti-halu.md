# Iter 56 Deep Audit — Dimension D: Anti-Halu Rail Enforcement

**Plugin version audited:** v3.38.0
**Baseline:** Iter 38 (v3.26.2)
**Focus:** Iter 54 (emit-fsd), Iter 55 (install-deps), and rail-touching changes in Iter 45/47/49.

## Summary

Anti-halu story is mostly intact, but two rail-claim-vs-procedure mismatches surfaced.

1. **P1 — Iter 45 `--rollback` "default safe" rail is reversed.** SKILL.md advertises per-action confirmation as the default for non-idempotent compensating actions; the AskUserQuestion menu offers `[Y] proceed` (batch-apply ALL actions including `idempotent: false` composer dep removes and migration rollbacks) at the same prominence as `[I] interactive`. A user pressing the natural default destroys non-idempotent state with one keystroke.
2. **P2 — emit-fsd template_slot_unfilled halt is reachable on every emission.** `fsd-template.md` declares `{{section-N-citations}}` slots for ALL 10 sections; `section-mapping.md` has no extraction rule that emits into any `{{section-N-citations}}` slot. Per SKILL.md §Halt protocol L147 + §Anti-hallucination rail 3 L195, unfilled slot = halt. Either every FSD emit halts (bad), or — more likely — Step 4 silently leaves the slot literal in the markdown (worse, halu rail bypassed).
3. **P2 — No procedure step actually performs the post-emission unfilled-slot scan** the rail relies on. Step 4 says "for each `{{slot_name}}` marker: replace with computed slot content"; nothing afterwards re-scans the rendered output for residual `{{…}}` patterns. The halt subtype `template_slot_unfilled` is declared but unfireable.
4. **P3 — emit-fsd citation-map `missing_sources[]` orphan field.** Schema at `section-mapping.md` L193-195 includes a `missing_sources[]` array; no procedure step populates it. Pending sections currently land in the regular `sections[]` array with no distinguishing marker — downstream auditability of "what was skipped" is degraded.
5. **P3 — pandoc-template.tex has no explicit drift-callout styling** (Rail 5: "Drift callouts surface in PDF"). Default blockquote rendering surfaces them, so the rail technically holds, but a single pandoc-template.tex blockquote color tweak would make drift callouts visually distinct from incidental quotes in source artifacts.

All other audited rails (install-deps sudo gate, install-deps curl|bash, install-deps verify-before-memory-write, Iter 49 vault.json lock across 4 writers, Iter 47 NOTE injection logic, Iter 54 fabricate-vs-placeholder discipline) PASS.

---

## Findings

### D1 [P1] — Iter 45 rollback default action is batch-confirm, not per-action

**Location:** `plugins/mega-sdd/skills/execute-bolts/SKILL.md` L36, L383, L391-402

**Rail claim (two places):**
- L36 (inputs/flags description): `Per-action confirmation (default safe for non-idempotent ops).`
- L383 (procedure prose): `with per-action confirmation (default safe for non-idempotent).`

**Procedure actually defines (L391-402):**

```
Rolling back partial bolt U-007 (3 compensating actions):

  3. file_partially_written: git checkout HEAD -- app/Http/Controllers/SubscriptionController.php  [idempotent ✓]
  2. file_created: rm database/migrations/2026_05_25_100000_create_subscriptions_table.php  [idempotent ✓]
  1. composer_dep_added: composer remove laravel/cashier --no-update && git checkout composer.json composer.lock  [idempotent ✗ — composer cache may persist]

Apply in reverse order (3 → 2 → 1)?
  [Y] proceed (records applied_at per action)
  [N] cancel; review partial-state.json manually
  [I] interactive (prompt before each action)
```

**Rail violation:** `[Y] proceed` is the canonical "yes" default in AskUserQuestion-style menus. It is NOT idempotency-gated — pressing it applies ALL actions including `[idempotent ✗]` entries in one go. "Default safe for non-idempotent" would require either:
- (a) gating `[Y]` so it auto-skips and prompts for any `idempotent: false` action, OR
- (b) flipping the default — `[I] interactive` is presented first, `[Y]` only appears when ALL actions in the batch are `idempotent: true`.

Neither (a) nor (b) is in the procedure. A user with composer dep removes + migration rollbacks in the batch can — and will — compound non-idempotent errors by pressing the obvious default.

**Why P1:** rail claim ≠ rail enforcement. Anti-halu rails matter most when the user is fatigued / under crash-recovery pressure; that is exactly when `[Y]` is the most likely keystroke. The CLAUDE.md "Bypassing anti-hallucination" policy explicitly bars downgrading rails without spec amendment + reviewer ack.

**Recommended fix:** rewrite menu — if ANY hint has `idempotent: false`, suppress `[Y]` and present only `[N] cancel` + `[I] interactive (prompt per action)` + optionally `[F] force-batch (override; logs to audit trail)`. Update L36/L383 rail wording to match.

---

### D2 [P2] — `{{section-N-citations}}` slots unmapped → unfillable

**Location:**
- Slots declared: `plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md` L40, L54, L66, L76, L107, L142, L159, L177, L193, L211, L233 (one per section, 10 sections total)
- Extraction rules: `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md` — Sections 1-10 define `**Citation:**` prose but NO entry maps to `{{section-N-citations}}`. Grep `section-N-citations` in section-mapping.md returns 0 matches.

**Rail claim:** SKILL.md L195 (Anti-halu rail 3): "Slot markers `{{slot_name}}` MUST all be filled OR explicitly placeholdered — empty slot = halt `quality_gate_failed:template_slot_unfilled`"
SKILL.md L147 (Halt protocol): "`quality_gate_failed` with subtype `template_slot_unfilled` — internal bug: a `{{slot}}` marker in fsd-template.md has no extraction rule in section-mapping.md (impossible if reference files are consistent; defensive check)"

**Procedure gap:** Step 3 (per-section emission loop) emits `slot content` and (Step 3.h) "Substitute slot in `references/fsd-template.md §Section N` template" — singular slot. Step 4.2 "For each `{{slot_name}}` marker: replace with computed slot content from Step 3." Both reference singular section content (e.g., `{{section-1-content}}`). Neither step instructs Step 3 to produce `{{section-N-citations}}` content — and section-mapping.md offers no extraction rule for that slot family.

**Failure mode:** on every FSD emission, 10 `{{section-N-citations}}` slots remain unfilled. Two possible runtime behaviors, both bad:
- (i) Strict implementation: halt `template_slot_unfilled` every time. FSD never emits.
- (ii) Loose implementation: SKILL.md doesn't define a post-emission scan, so the LLM running Step 4 will likely either (a) leave the literal `{{section-N-citations}}` in the output, OR (b) hallucinate citations to fill the slot — the exact failure Rail 1 ("EVERY section text MUST trace to a source artifact via .citation-map.json entry") is meant to prevent.

**Why P2:** ambiguity at the rail/procedure interface gives the LLM operator latitude to fabricate. The rail is documented; enforcement is not.

**Recommended fix:** add `{{section-N-citations}}` extraction rule per section in section-mapping.md (assemble the per-section footer from collected source citations Step 3.g pushed into the in-memory citation_map). Format already specified in fsd-template.md L243-248.

---

### D3 [P2] — Post-emission unfilled-slot scan is missing from procedure

**Location:** `plugins/mega-sdd/skills/emit-fsd/SKILL.md` Step 4 (L90-94), Step 6 (L120) — no scan step

**Rail claim:** SKILL.md L195 + L147 (see D2).

**Procedure gap:** Step 4 instructs substitution; Step 5 invokes pandoc; Step 6 writes citation-map. No step scans the assembled FSD.md for residual `{{…}}` patterns prior to pandoc invocation. Without a scan, the halt subtype `template_slot_unfilled` cannot fire — making it a dead halt code.

The rail is the LLM operator's only protection against silently emitting `{{section-N-citations}}` literal text in the rendered PDF. Currently:
- Substitution failures slip through.
- Hallucinated content (D2 mode ii.b) also slips through, because Step 6 writes citation-map AFTER FSD.md is already on disk and PDF is already rendered.

**Why P2:** the rail words exist but cannot empirically fire. Defensive-check halt that never runs ≈ no halt.

**Recommended fix:** insert "Step 4.5: Post-emission slot scan — `grep -E '\\{\\{[a-z0-9-]+\\}\\}' <vault>/fsd/FSD.md`. If any match → halt `quality_gate_failed:template_slot_unfilled` with details `{unfilled_slots: [<list>]}`." BEFORE Step 5 (pandoc).

---

### D4 [P3] — `missing_sources[]` citation-map field orphaned

**Location:**
- Schema declared: `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md` L193-196
- Procedure: `plugins/mega-sdd/skills/emit-fsd/SKILL.md` Step 3.d, Step 6

**Schema:**
```json
"missing_sources": [
  {"section": "9", "expected_source": "bolts/", "reason": "pre-dev mode"}
]
```

**Procedure gap:** Step 3.d ("If any source artifact absent: emit `[Pending — <source> not yet generated]` placeholder") and Step 3.g ("Append entry to in-memory citation_map.sections[]") both populate the regular `sections[]` array. No step branches placeholder cases into a separate `missing_sources[]` collection. Step 6 ("Write citation map") doesn't reference `missing_sources` either.

**Why P3:** not a rail break — `[Pending — …]` placeholders still surface to the reviewer in the FSD body. But auditability is degraded: a downstream consumer (e.g., a future "re-emit-when-bolts-arrive" automation) cannot programmatically enumerate "what's still missing" without parsing FSD prose.

**Recommended fix:** in Step 3.d, ALSO append to `citation_map.missing_sources[]` with `{section, expected_source, reason}`. Step 6 already emits the field by transitivity.

---

### D5 [P3] — pandoc-template.tex drift-callout has no distinct styling

**Location:** `plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex` (entire file; especially L7-104)

**Rail claim:** SKILL.md L197 (Anti-halu rail 5): "Drift callouts MUST surface in PDF — silent regeneration would hide content changes from reviewers."

**Procedure:** Step 3.f flags sections with sha256 mismatch + inserts `> ⚠ **Updated since last emit**` markdown blockquote per `fsd-template.md` L254-256.

**Template gap:** pandoc-template.tex defines no custom rendering for blockquotes. Pandoc's default LaTeX blockquote (`\begin{quote}…\end{quote}`) renders as indented text — readable but visually indistinguishable from an incidental author blockquote that happened to be pulled in from a source artifact (e.g., a stakeholder voice quote in 01-overview.md). Reviewers scanning a 30-page FSD will miss drift unless they read every blockquote.

**Why P3:** the rail "surface in PDF" holds in the strictest sense — text is visible. But the spirit of the rail ("hide content changes from reviewers" is the failure to avoid) is undermined by visual sameness. Low-cost fix.

**Recommended fix:** add to pandoc-template.tex (after the existing `% --- Color ---` block):
```latex
\usepackage{tcolorbox}
\newtcolorbox{driftcallout}{colback=yellow!10,colframe=orange,title=Updated since last emit,fonttitle=\bfseries}
```
And update fsd-template.md drift callout to a pandoc raw-LaTeX hint OR a `:::`-fenced div pandoc can map. Alternatively, simplest: re-color blockquotes globally in the template (drift is the only blockquote use case for FSD content anyway).

---

## Verified PASS (per task checks)

### Iter 55 install-deps anti-halu rails — ALL PASS

- **Rail 1 (NEVER auto-sudo):** `references/tool-matrix.yaml` tags 6 entries with `requires_sudo: true` (lines 19-21, 25-28, 81-83, 87-89, 135-137, 141-143, 207-209). SKILL.md Step 3 (L88-90): "If a tool has `requires_sudo: true`: DO NOT add to auto-execute plan. Add to 'manual install' list shown separately with explicit instruction." Step 5 header (L119) reinforces: "Execute install (only for auto-executable tools — never sudo-required)". PASS.
- **Rail 2 (NEVER curl|bash):** grep across SKILL.md + tool-matrix.yaml + os-detection.md returns ZERO `curl … | bash` or `wget … | sh` patterns inside any `install_cmd:`. The two grep hits are both rail SELF-DECLARATIONS (SKILL.md L4 description, L235 rail). os-detection.md L112 explicitly FORBIDS Homebrew's own install script: `"Auto-execution of Homebrew's own install script (/bin/bash -c "$(curl -fsSL https://...)") is FORBIDDEN per safety rails"`. PASS.
- **Rail 3 (show cmd+source+size BEFORE running):** SKILL.md Step 4 (L96-117) defines the AskUserQuestion gate with explicit per-tool line `<tool> <size>MB <install_cmd>`. `--dry-run` exits before execution; `--manual` prints commands only. Step 5 (L119-132) runs only after approved plan. PASS.
- **Rail 4 (verify post-install):** SKILL.md Step 6 (L135-150) — "For each successfully-installed tool: 1. Run `verify_cmd`. 2. Exit 0 + version capture → mark `verified`. 3. Exit non-zero → mark `unverified`; add to halt list." Halt `install_failed:verify_after_install_failed` defined. PASS.
- **Rail 5 (memory write AFTER verify pass):** Step 7 (L153-160) ordered AFTER Step 6 verify loop. SKILL.md §Anti-halu Rail 6 (L239): "Memory write happens AFTER verify pass — never record 'installed' on partial state." Procedure order matches rail. PASS.

### Iter 49 vault.json advisory lock — ALL 4 WRITERS PASS

- **generate-intent:** `SKILL.md` L544 has explicit Iter 49 lock language ("acquire exclusive file lock on `<vault>/vault.json.lock` … BEFORE writing vault.json. Backoff + retry 3x; fail with `memory_in_use` halt"). PASS.
- **bind-codebase:** `SKILL.md` L470 has same lock language for the append-write path. PASS.
- **diff-vault:** `SKILL.md` L361 has lock language for the overwrite path. PASS.
- **resolve-oq:** `SKILL.md` L217 has lock language wired Iter 52 fix-forward — covers Resolve / Out-of-Scope / Defer write paths. PASS.

All 4 reference the same `vault-contract.md §Concurrency contract` and use the same `memory_in_use` halt type — consistent rail enforcement across writers.

### Iter 47 _authored_by NOTE injection — IMPLEMENTATION MATCHES SPEC (task standard is stricter than spec)

- **Spec source:** `docs/superpowers/specs/2026-05-25-iter-47-independent-acceptance-test-authoring-design.md` L82-94 marks FOUR values as "strong": `adversarial-reviewed (no gaps)`, `adversarial-reviewed (+N gaps merged)`, `independent-llm`, `human`.
- **Implementation:** `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` L64 ("when … `_authored_by` field is `same-pass` OR `adversarial-review-failed`") — NOTE injects ONLY for the two weak values. The other 5 values (4 strong per spec + `adversarial-reviewed` plain) get no NOTE.
- **Task description standard:** "only `human` and `independent-llm` give STRONG blind-spot coverage" — this is stricter than the spec doc.
- **Verdict:** implementation matches spec; spec explicitly designates 4 strong values. If the task's stricter standard reflects a post-spec correction, that requires a spec amendment per CLAUDE.md §Skill Edit Policy. No finding raised here; flagging for the orchestrator to reconcile with whoever drafted the audit task.

### Iter 54 fabricate-vs-placeholder discipline (Check 6) — PASS

- `section-mapping.md` Sections 1-10 each include an explicit `**Missing source:**` line declaring the `[Pending — <source> not yet generated]` placeholder text (verbatim wording matches across sections).
- SKILL.md §Anti-halu Rail 2 (L194): "Missing source MUST emit `[Pending — <source> not yet generated]` — NEVER fabricate content".
- Decision tree clear: source absent → emit Pending placeholder per per-section rule. No section invites narrative invention.
- Minor caveat (P3-borderline, not raised as finding): Section 5 FR-details extraction (section-mapping.md L72-91) depends on a parser parsing 02-functional.md FR headings. If 02-functional.md PARSES but contains zero FR-NNN headings, procedure is ambiguous between "emit empty table" and "emit Pending". Defensive read suggests empty table is the right call (presence trumps content). Wording could clarify.

---

## Anti-Halu Coverage Matrix

| Rail / Check | Skill(s) | Documented | Enforced in procedure | Verdict |
|---|---|---|---|---|
| Citation discipline — every section traces to source | emit-fsd | Yes (L193) | Partial — `{{section-N-citations}}` slot unmapped (D2) | **P2** |
| No fabrication — missing source → Pending placeholder | emit-fsd | Yes (L194, section-mapping per-section) | Yes — explicit per-section rules | PASS |
| Slot completeness — no unfilled `{{…}}` reaches PDF | emit-fsd | Yes (L195, halt L147) | NO — no post-emission scan step (D3) | **P2** |
| sha256 stamps at emit-time (no cache) | emit-fsd | Yes (L196) | Yes — Step 3.b "check existence + read content + compute sha256" | PASS |
| Drift callouts surface in PDF | emit-fsd | Yes (L197) | Partial — surfaces, but no distinct styling (D5) | **P3** |
| missing_sources[] populated for audit trail | emit-fsd | Schema declared (section-mapping.md L193-196) | NO — no procedure step writes it (D4) | **P3** |
| NEVER auto-sudo | install-deps | Yes (L234) | Yes — Step 3 L88-90 gates, Step 5 L119 reinforces | PASS |
| NEVER curl\|bash | install-deps | Yes (L235) | Yes — tool-matrix.yaml has zero such patterns; os-detection.md L112 explicit | PASS |
| Show cmd+source+size BEFORE run | install-deps | Yes (L236) | Yes — Step 4 AskUserQuestion gate | PASS |
| Verify post-install before "installed" claim | install-deps | Yes (L237) | Yes — Step 6 with `install_failed:verify_after_install_failed` halt | PASS |
| Memory write AFTER verify pass | install-deps | Yes (L239) | Yes — Step 7 ordered after Step 6 | PASS |
| Iter 49 vault.json advisory lock — 4 writers | generate-intent / bind-codebase / diff-vault / resolve-oq | Yes | Yes — all 4 wired (L544 / L470 / L361 / L217) | PASS |
| Iter 47 NOTE injection on weak provenance | execute-bolts | Yes (bolt-dispatch-prompt.md L62-82) | Yes — `same-pass` OR `adversarial-review-failed` triggers; matches spec doc (4 strong values, not 2 — task standard is stricter than spec) | PASS (spec-aligned) |
| Iter 45 saga `--rollback` per-action confirm for non-idempotent | execute-bolts | Yes (L36, L383) | NO — `[Y] proceed` is batch-apply default; only `[I]` is per-action (D1) | **P1** |

---

## Severity counts

| Severity | Count | Findings |
|---|---|---|
| P1 HIGH (rail violated) | 1 | D1 |
| P2 MEDIUM (rail documented, enforcement weak) | 2 | D2, D3 |
| P3 LOW (rail wording/styling unclear) | 2 | D4, D5 |

**Total findings:** 5. Total checks performed: 13. Pass rate: 8/13 (62%).

---

## Recommendations (in priority order)

1. **Immediately:** fix D1 by suppressing `[Y]` when any hint has `idempotent: false`. One-line procedure edit at execute-bolts/SKILL.md L391-402. Touches a Tier-1 anti-halu rail; should not wait.
2. **Before next FSD emit:** fix D2 (add `{{section-N-citations}}` extraction rules to section-mapping.md) + D3 (add Step 4.5 post-emission scan to emit-fsd/SKILL.md). Pair-fix; D3 protects against any future D2-class slot/rule mismatch.
3. **Next emit-fsd iteration:** fix D4 (`missing_sources[]` population) and D5 (drift-callout LaTeX styling). Both low-risk cleanups.
4. **Cross-reference action:** reconcile task description's claim that "only `human` and `independent-llm` give STRONG coverage" against spec doc's 4-value strong list at `docs/superpowers/specs/2026-05-25-iter-47-independent-acceptance-test-authoring-design.md` L82-94. Either spec needs amendment (and bolt-dispatch-prompt.md updated to inject NOTE for all 5 non-strong values) OR task standard needs softening. Per CLAUDE.md §Skill Edit Policy, rail tightening = spec amendment first.
