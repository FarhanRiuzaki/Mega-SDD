# resolve-oq Trigger + Behavior Test

Manual-run fixture for the `resolve-oq` skill.

## Trigger cases

### R1: Explicit standalone (intent mode)
- **Prompt:** `/mega-sdd:resolve-oq`
- **Expect:** Skill invocation; walks OQs from vault in CWD (auto-detect vault dir)

### R2: Explicit with vault path
- **Prompt:** `/mega-sdd:resolve-oq ./docs/mega-sdd/vaults/my-app`
- **Expect:** Walks OQs from the specified vault

### R3: Binding mode
- **Prompt:** `/mega-sdd:resolve-oq --binding ./vaults/v1-bound/binding.md`
- **Expect:** Walks CONFLICT + Open Questions entries from binding.md

### R4: Natural English
- **Prompt:** `resolve open questions`
- **Expect:** Skill invocation

### R5: Natural Indonesian
- **Prompt:** `jawab OQ list`
- **Expect:** Skill invocation

### R6: Auto-route from orchestrate-flow (intent gate)
- **Setup:** vault has 2 P1 OQs, status=pending
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes resolve-oq first (before scan/bind/units)

### R7: Auto-route hidden when only deferred OQs
- **Setup:** vault has 2 P1 OQs, all status=deferred, mode=existing, .git present
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes scan-codebase next (deferred OQs do NOT gate the chain)

## Behavior — the ONE collapsed per-OQ prompt

Canonical shape: `references/interactive-walk.md` Step 2b. Slots are a display detail; the recorded
`action` letters (`A`/`B`/`C`) are the derive contract and did NOT change with the collapse.

### B1: One prompt, 4 slots (brownfield)
- **Setup:** vault.mode=existing AND .git present
- **Expect:** Per OQ, exactly ONE `AskUserQuestion` with options `[1]` `<recommended answer> (recommended)` / `[2]` Skip / `[3]` Defer / `[4]` Out of scope; "Other" carries the free-text answer + the `→ <file>.md` destination override; Esc ends the walk
- **Critical:** NO separate "what is your answer?" prompt and NO separate "confirm the destination?" prompt — the answer option's description discloses where the answer lands

### B2: Defer is ALWAYS visible (greenfield)
- **Setup:** vault.mode=greenfield
- **Expect:** Slot `[3]` Defer still shown — a stakeholder defer must be reachable in every context. What changes is the FOLLOW-UP: it carries the reason question only (no `defer_to` sub-target question), and `defer_to` is written EXPLICITLY as `stakeholder` by the derive patch
- **Critical:** `stakeholder` is NOT a schema default — `generate-intent/references/vault-contract.md §OQ status tracking` declares no default for `defer_to`. It is the only LEGAL value in greenfield (`binding` requires a repo to bind against), so it is determined, not derived. A doc that cites a "schema default" here is the defect
- **Critical:** because Q1 is omitted, Q2 must carry the OQ tag AND the verbatim question text in its own body — a bare "alasan defer-nya apa?" with no question in front of it is a keterangan rule-1 breach on every greenfield Defer

### B3: Defer sub-target hidden (no repo signals)
- **Setup:** vault.mode=existing but CWD has no .git/package.json/etc.
- **Expect:** Slot `[3]` Defer still shown; the follow-up omits the `stakeholder`/`binding` question; skill warns user about the mode/CWD mismatch

### B4: Alternatives ride the question text, not a slot
- **Setup:** recommendation built with one grounded alternative
- **Expect:** the alternative appears as prose in the question text under the template's own literal, `Alternatif yang sudah dipertimbangkan: … — kalau …`, with its citation or an explicit `tanpa sumber` marker; it does NOT consume an option slot
- **Critical:** no grounded alternative → the line is OMITTED, never padded with an invented one

### B5: No typed end-the-walk sentinel
- **Setup:** an OQ whose text is "payment gateway timeout — lanjut atau berhenti?"; user types `stop` into "Other"
- **Expect:** `stop` is recorded as the ANSWER (action `A`). The walk does not end. There is no `STOP`/`BERHENTI` sentinel anywhere in the walk

### B6: Esc ends the walk (not the item)
- **Setup:** N=5 OQs, 2 already resolved, Esc pressed on OQ 3
- **Expect:** OQ 3 untouched and counted as skipped; the walk does NOT advance to OQ 4; skill jumps to Step 3 (version bump + Changelog recording the 2 resolutions) and exits. Same meaning Esc has in `execute-bolts/references/halt-recovery.md` and `propose-and-confirm-prompt.md`

### B7: Skip (slot `[2]`) skips ONE OQ and continues
- **Setup:** N=5 OQs, Skip chosen on OQ 3
- **Expect:** no file change, no derive run, OQ 3 stays `[ ]` open; the walk CONTINUES to OQ 4

### B8: "Other" parse order — destination override composes with the answer
- **8a — text + override:** `Pakai RFC 7807 → 02-architecture.md` → action `A`, answer = `Pakai RFC 7807`, destination = `02-architecture.md`
- **8b — BARE override (D5):** `→ 02-architecture.md` alone → action `A` accepting the RECOMMENDED answer, landed in `02-architecture.md`. **It must NOT parse as Skip** — that silently discarded an accepted answer before this round
- **8c — bare override with NO recommendation:** nothing to accept → no file change, OQ stays `[ ]` open, outcome narrated, counted as skipped
- **8d — empty "Other":** Skip, with the outcome narrated (not a silent no-op)
- **8e — override target VALIDATED pre-write:** the stripped `→ <file>.md` basename must match, character for character, one of the vault's seven documents (`00-index.md`, `01-overview.md`, `02-architecture.md`, `03-data-model.md`, `04-flows.md`, `05-decisions.md`, `06-constraints.md`). The collapse removed the pre-write destination confirmation, so this check — not the post-write narration — is what catches a bad target
- **8f — invalid override WITH answer text:** `Pakai RFC 7807 → 07-appendix.md` → the `→ 07-appendix.md` fragment is rejected and DROPPED from the answer text (never recorded as content); the rejection is narrated naming the legal set; the answer still resolves, landing at the AUTO-CLASSIFIED target, which is also narrated. No re-prompt
- **8g — invalid override, BARE:** `→ notes.md` alone → nothing is honorable (the stated intent was to redirect) → no markdown change, OQ stays `[ ]` open, counted as skipped, rejection narrated. **Never** silently accept the recommendation at the auto target, and **never** land an answer in a file outside the seven

### B9: Defer follow-up = ONE call, TWO questions
- **Setup:** brownfield, Defer chosen
- **Expect:** ONE `AskUserQuestion` whose `questions` array holds 2 entries — Q1 `defer_to` (`stakeholder` / `binding`, each with a mandatory keterangan), Q2 the reason (≤4 common-reason options + "Other" for PIC/date specifics). The 4-option cap is per QUESTION, not per call
- **Critical:** neither `defer_to` nor `deferred_reason` may be defaulted or derived from the OQ text (invariant #5). Esc here abandons the Defer AND ends the walk — nothing is written for this OQ
- **Critical:** Q2 is the ALWAYS-present question, so Q2 (not only Q1) carries the OQ tag + verbatim question text, and Q2 (not a YAML comment) discloses Esc in operator-visible text

### B10: Out-of-scope follow-up
- **Expect:** ONE `AskUserQuestion`, one question, ≤4 rationale options + "Other" for a custom rationale. Esc abandons the OOS **and ends the walk**, disclosed in the question text rather than only in a YAML comment; a canned rationale is never substituted

### B10b: recorded language on BOTH follow-ups (the Tier-2/Tier-3 seam)
- **Setup:** the operator is writing in English; the vault's content language is Indonesian
- **Expect:** the follow-up prompts RENDER in English (Tier-2 precedence rule 2), but what lands in the vault is written in the vault's language (Tier-3, `plugins/mega-sdd/references/output-language.md`). Picking a canned category records that fixed category in the vault's language — a fixed mapping, never a re-interpretation
- **Critical:** only the "Other" free text may be described, or recorded, as VERBATIM. A canned option's description promising "tercatat verbatim" is the defect — it promises Tier-3 fidelity for a Tier-2 string

### B11: State transitions per action
- **`[1]` / "Other" text / bare override → action `A`** → OQ becomes `status: resolved`, `resolved_at: <iso>`, `resolution: <text>`
- **`[3]` Defer → action `B`** → `status: deferred`, `defer_to: stakeholder|binding`, `deferred_at: <iso>`, `deferred_reason: <asked, never invented>`
- **`[4]` Out of scope → action `C`** → `status: out-of-scope`, `out_of_scope_reason: <text>`
- **`[2]` Skip** → no field change; OQ remains pending; **no derive run at all**
- **Esc** → no field change for the current OQ; walk ends

### B12: Vault.json changelog appended
- **After a Resolve / Defer / Out-of-scope:** vault.json gets a new changelog entry: `{ "event": "oq-resolved|oq-deferred|oq-out-of-scope", "id": "OQ-XXX", "at": "<iso>", "action": "A|B|C" }`
- **Critical:** Skip emits NO event — `"action": "D"` never appears in a changelog entry. The recorded value is always a LETTER, never a slot number (`"action": "1"` is a defect)

### B13: Prompt budget (the collapse, as a rail)
- Answer = **1** prompt · Skip = **1** · end the walk = **1** · Defer = **2** (choice + the one two-question call) · Out of scope = **2** (choice + rationale)
- **Critical:** a Defer costing 3 (sub-target and reason asked separately) is a regression

### B14: Language precedence on the prompt
- **Setup:** the user has been writing in English
- **Expect:** the panel, question body, bullets, `Alternatif` line, option labels and descriptions all render in ENGLISH per `plugins/mega-sdd/references/output-language.md §Precedence` rule 2. The Indonesian template strings are the default rendering, not a fixed catalog
- **Critical:** Tier-1 tokens (`OQ-…`, `P1`, `[ ]`/`[x]`/`[~]`, file names, `defer_to`, `stakeholder`, `binding`, `HIGH`/`MEDIUM`) stay English in every language

### B15: High-stakes marker in BOTH positions
- **Setup:** OQ with `category: business` AND `P1`
- **Expect:** the ⚠️ marker appears on the panel banner AND as the prefix of the recommended option's `description`. Losing either is a regression

## Behavior — --binding mode

### BM1: Walks conflicts
- **Setup:** binding.md has 2 CONFLICT rows
- **Expect:** Skill prompts per conflict with [K] KEEP_VAULT / [C] KEEP_CODE / [D] DEFER / [S] SPLIT

### BM2: Walks propagated deferred OQs
- **Setup:** binding.md has 1 CONFLICT + 2 Open Questions rows
- **Expect:** Skill walks CONFLICTs first, then OQs using the SAME collapsed single prompt as the standard walk, with Defer NOT offered at all — nested deferral is not supported in binding context. Slot numbers are display positions, so the three options render as `[1]` recommended answer / `[2]` Skip / `[3]` Out of scope, per `references/binding-mode.md` step 3 — plus "Other" and Esc
- **Critical:** THREE options, not four with a hole. The cap is a ceiling, not a quota: no fourth option is invented to fill the freed capacity, and there is no empty/placeholder slot. Recorded `action` letters unchanged (`A` / `C`; Skip emits no event)

### BM3: Resolutions persist
- **After resolving 1 conflict + 1 OQ:** binding.md updated, vault.json changelog entry added

### BM4: Hand-off after binding mode — ACTION-MIX (not a blanket re-bind)
- **Setup:** at least one CONFLICT resolved via KEEP_CODE or SPLIT (the vault was edited)
- **Expect:** handoff `next_action.suggested_skill: mega-sdd:bind-codebase` — the edited claims now match code and re-bind cleanly (per `references/binding-mode.md` Step 5)

### BM5: Hand-off KEEP_VAULT/DEFER-only → generate-units (no re-bind loop)
- **Setup:** all CONFLICTs resolved via ONLY KEEP_VAULT and/or DEFER (vault + code unchanged); zero KEEP_CODE/SPLIT
- **Expect:** handoff `status: completed`, `next_action.suggested_skill: mega-sdd:generate-units` (NOT bind-codebase) — the resolution-marked binding.md already passes `validate-handoff-binding-units.sh`; a re-bind would re-derive the unchanged vault-vs-code contradiction and RE-RAISE the identical CONFLICT (infinite loop). Under `--deep`/`--resume` the chain proceeds to generate-units; it does NOT route back to bind.

### BM6: DEFER-resolved CONFLICT is advisory at the binding→units gate (not a hard block)
- **Setup:** a CONFLICT resolved via DEFER (downgraded to an OQ per `references/binding-mode.md:45`); no unit cites CONFLICT-N (the deferred OQ carries the trace instead)
- **Expect:** `validate-handoff-binding-units.sh` emits an advisory `conflict_id_deferred_uncited` extra, NOT a blocking `conflict_id_dropped` drop → the execute-bolts PreToolUse gate does NOT hard-block the DEFER→generate-units→execute-bolts path. KEEP_VAULT keeps its un-droppable citation obligation; an unknown/absent resolution action stays fail-closed (blocking).

## Context-aware recommendations (v0.6+, Iter 7)

### REC1: KB-derived recommendation surfaced
- **Setup:** KB at `docs/knowledge-base/` has `[VERIFIED]` entry matching OQ-AR-7 in `10-domains/50-parameter-reference.md`
- **Expect:** AskUserQuestion option 1 labeled `<answer> (recommended)`; description shows rationale + KB citation + fallback_if_wrong + confidence: HIGH

### REC2: Memory-derived recommendation surfaced
- **Setup:** No KB. `<project>/.mega-sdd/memory/decisions.md` has 5 consistent rows resolving auth-pattern OQs as KEEP_CODE
- **Expect:** AskUserQuestion option 1 labeled `KEEP_CODE (recommended)`; cites memory rows; confidence: HIGH

### REC3: Vault/codebase MEDIUM-confidence recommendation
- **Setup:** No KB. No memory match. Vault `05-decisions.md` has D-003 about error envelope; codebase-map has existing `ErrorResource.php`
- **Expect:** Option 1 labeled `<extrapolated answer> (recommended)`; description marks confidence MEDIUM with vault + codebase-map citation; user warned to review carefully

### REC4: Silent fallback when no confident sources
- **Setup:** Greenfield project, no KB, fresh memory, no relevant vault context
- **Expect:** AskUserQuestion presents WITHOUT `(recommended)` label; falls back to plain interactive walk (v0.5 behavior)
- **Critical:** NO fabricated recommendation; better silent than wrong

### REC5: Anti-halu — no citation = no recommendation
- **Setup:** Claude (LLM) suggests an answer based on prior knowledge alone (no KB/memory/vault/codebase match)
- **Expect:** Skill REJECTS the suggestion at recommendation-build phase; no `(recommended)` surfaced

### REC6: High-stakes business OQ warning
- **Setup:** OQ category=business, priority=P1; memory has matching pattern
- **Expect:** AskUserQuestion description prefixed with ⚠️ "High-stakes business OQ. Review citation + rationale carefully before accepting."

### REC7: Audit trail on ACCEPT
- **Setup:** User picks option 1 (recommended)
- **Expect:** vault.json OQ entry has `resolution_source: recommendation` + `recommendation_citation: <full-citation>`
- **Memory write:** `.mega-sdd/memory/decisions.md` row marked `source: ai_recommended`

### REC8: Audit trail on OVERRIDE
- **Setup:** a `(recommended)` option WAS on the prompt and the user declined it — answering via "Other" with different text (often an alternative from the question text, typed back)
- **Expect:** vault OQ entry has `resolution_source: user_override`; memory row marked `recommendation_ignored: <recommended-text>`
- **Self-learning feedback:** override counter incremented for this OQ pattern

### REC9: Self-correction loop after 5 overrides
- **Setup:** Same OQ pattern has been overridden 5 times across runs
- **Expect:** `~/.mega-sdd/memory/patterns.md` pending suggestion: "Disable recommendation for OQ pattern X (5/5 overrides)"; user reviews via `/mega-sdd:memory review`; ACCEPT disables future recommendations for that pattern

### REC10b: "Other" with NO recommendation is a direct answer, NOT an override
- **Setup:** the no-recommendation shape (no citable signal, or the probe failed) — "Other" is the ONLY answer channel there; user types an answer
- **Expect:** vault OQ entry gets `resolution_source: user_direct` (the third declared value, per `references/recommendation-context.md §Audit trail`); memory row `source: user_direct`; NO `recommendation_ignored` field
- **Critical:** the override counter is NOT incremented and no `user_override` row is written. Keying the OVERRIDE branch on the CHANNEL ("answered via Other") instead of on *a recommendation existing and being declined* books every unsourced-OQ answer as an override of a recommendation that never existed — and would fire the REC9 self-correction loop on patterns the recommender never attempted

### REC10: Override reason captured (optional)
- **Setup:** User picks alternative + provides override reason via free-text
- **Expect:** memory row includes `override_reason: <user-text>`; aids future pattern analysis

## Pass criteria

All R1-R7 invoke skill correctly. The per-OQ walk costs ONE `AskUserQuestion` on the common path (B1, B13); Defer stays visible in every context and only its sub-target question is brownfield-conditional (B2-B3); alternatives ride the question text (B4); there is no typed end-the-walk sentinel and Esc ends the walk while slot `[2]` skips one item (B5-B7); the "Other" parse order composes a bare destination override with the recommendation and VALIDATES its target against the vault's seven documents before any write (B8, incl. 8e-8g); the Defer follow-up is one call with two questions, Q2 carries the tag + question text and discloses Esc in operator-visible text, nothing it collects is ever defaulted, and only the "Other" channel is described as verbatim (B9-B10b). State transitions match B11 and the changelog contract B12 — letters, never slot numbers, and no event at all for Skip. Language precedence and the high-stakes double marker hold (B14-B15). Binding mode walks conflicts and OQs per BM1-BM3 (three options, Defer not offered, no invented fourth); hand-off is ACTION-MIX per BM4-BM5 (KEEP_CODE/SPLIT→bind-codebase, KEEP_VAULT/DEFER-only→generate-units — never a blanket re-bind that loops); DEFER-resolved uncited CONFLICTs are advisory at the binding→units gate per BM6. Context-aware recommendations (REC1-REC10) follow `references/recommendation-context.md` — citation mandatory, silent fallback when no confident sources, audit trail on ACCEPT + OVERRIDE (keyed on a recommendation existing and being declined — never on the "Other" channel, per REC10b), and the self-correction loop after consistent overrides.
