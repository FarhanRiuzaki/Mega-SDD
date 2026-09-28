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
- **Prompt:** `/mega-sdd:resolve-oq --binding .mega-sdd/vaults/my-app`
- **Expect:** Walks every open CONFLICT claim in the vault's per-unit `bolts/U-*/binding.json` (the JIT bind at execute-bolts pre-flight 3.9); a `bolts/U-XXX/binding.json` argument walks that unit only. A pre-9.0 layout-2 vault (or a `<path-to-binding.md>` argument) takes the layout-2 leg: CONFLICT + Open Questions entries from `binding.md`

### R4: Natural English
- **Prompt:** `resolve open questions`
- **Expect:** Skill invocation

### R5: Natural Indonesian
- **Prompt:** `jawab OQ list`
- **Expect:** Skill invocation

### R6: Auto-route from orchestrate-flow (intent gate)
- **Setup:** vault has 2 open P1 business OQs (status open/pending)
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes resolve-oq first (before any other pipeline row — `plan --regenerate` / `execute-bolts`)

### R7: Auto-route hidden when only deferred OQs
- **Setup:** vault has 2 P1 OQs, all status=deferred; units exist, no bolts yet
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes `execute-bolts --all --lite` next (deferred OQs do NOT gate the chain; they ride the units and resurface in the delivery report)

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
- **Critical:** `stakeholder` is NOT a schema default — `plugins/mega-sdd/references/vault-core.md §OQ status tracking` declares no default for `defer_to`. It is the only LEGAL value in greenfield (`binding` requires a repo to bind against), so it is determined, not derived. A doc that cites a "schema default" here is the defect
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
- **8e — override target VALIDATED pre-write:** the stripped `→ <file>.md` basename must match, character for character, one of the vault's documents for its layout (layout-3: `context.md`; layout-2: `vault.md`/`model.md`/`flows.md`/`constraints.md`; legacy: `00-index.md` … `06-constraints.md`). The collapse removed the pre-write destination confirmation, so this check — not the post-write narration — is what catches a bad target
- **8f — invalid override WITH answer text:** `Pakai RFC 7807 → 07-appendix.md` → the `→ 07-appendix.md` fragment is rejected and DROPPED from the answer text (never recorded as content); the rejection is narrated naming the legal set; the answer still resolves, landing at the AUTO-CLASSIFIED target, which is also narrated. No re-prompt
- **8g — invalid override, BARE:** `→ notes.md` alone → nothing is honorable (the stated intent was to redirect) → no markdown change, OQ stays `[ ]` open, counted as skipped, rejection narrated. **Never** silently accept the recommendation at the auto target, and **never** land an answer in a file outside the legal set for the vault's layout

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
- **Setup:** two units' `bolts/U-*/binding.json` each carry one CONFLICT claim without a `resolution`
- **Expect:** Skill prompts per conflict (`U-XXX · <claim id>`) with the vault claim, the codebase reality AND its evidence anchor (`file:line` — mandatory), then [K] KEEP_VAULT / [C] KEEP_CODE / [D] DEFER / [S] SPLIT
- **Critical:** each choice is written back ONLY through `write-unit-binding.sh --resolve=<claim-id>=<ACTION> --by=user`; `binding.json` is hook-guarded evidence and is never edited

### BM2: Walks propagated deferred OQs (layout-2 leg)
- **Setup:** a pre-9.0 layout-2 vault whose `binding.md` has 1 CONFLICT + 2 Open Questions rows (a per-unit `binding.json` has no propagated-OQ table)
- **Expect:** Skill walks CONFLICTs first, then OQs using the SAME collapsed single prompt as the standard walk, with Defer NOT offered at all — nested deferral is not supported in binding context. Slot numbers are display positions, so the three options render as `[1]` recommended answer / `[2]` Skip / `[3]` Out of scope, per `references/binding-mode.md` step 3 — plus "Other" and Esc
- **Critical:** THREE options, not four with a hole. The cap is a ceiling, not a quota: no fourth option is invented to fill the freed capacity, and there is no empty/placeholder slot. Recorded `action` letters unchanged (`A` / `C`; Skip emits no event)

### BM3: Resolutions persist
- **After resolving conflicts:** the claims' `resolution` lands in `bolts/U-XXX/binding.json` via the writer; `derive-vault-json.sh --event '{"event":"resolve-oq-binding",…}'` appends the vault.json changelog entry (a DEFER adds the demoted OQ through `--patch` with `defer_to: binding`)
- **Layout-2 leg (1 conflict + 1 OQ):** `binding.md` detail heading + `- **Resolution**:` line updated, then `derive-binding-json.sh --vault <vault>` refreshes `binding.json`; vault.json changelog entry added

### BM4: Hand-off after binding mode — ACTION-MIX (not a blanket re-bind)
- **Setup:** at least one CONFLICT resolved via KEEP_CODE or SPLIT (the unit's `## Claims` was edited)
- **Expect:** re-bind just the edited units — `scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=<edited U-ids>` (the edited claims bind cleanly) → `plan --reconcile` (task_type flips) → `/mega-sdd --resume` (`execute-bolts --all --lite`), per `references/binding-mode.md` Step 5. Skipped, the BOLTS gate backstops it: the edited unit trips `unit_changed_since_bind` and 3.9b re-binds it

### BM5: Hand-off KEEP_VAULT/DEFER-only → resume bolts (no re-bind loop)
- **Setup:** all CONFLICTs resolved via ONLY KEEP_VAULT and/or DEFER (vault + code unchanged); zero KEEP_CODE/SPLIT
- **Expect:** NO re-bind is suggested — resume `execute-bolts --all --lite` directly. The resolved claims already pass `validate-handoff-binding-units.sh --units=`, and a later re-bind keeps them (`_lib/unit_binding.py` carries a resolution forward while the claim and its code paths are unchanged); re-binding now would re-derive the unchanged vault-vs-code contradiction and spend the unit's one 3.9b. KEEP_VAULT's code change lands in that unit's bolt

### BM6: DEFER opens the unit's gate, the OQ travels with it
- **Setup:** a CONFLICT resolved via DEFER (`[D]`)
- **Expect:** the CONFLICT is downgraded to an OQ the unit carries and the unit's gate opens; the demoted OQ enters vault.json through the derive's `--patch` (`status: deferred`, `defer_to: binding`) and is re-asked at the unit's dispatch (`TBD: OQ-XXX` — a P1 business one stops the bolt). On the layout-2 leg the gate reads a DEFER-resolved, uncited CONFLICT as the advisory `conflict_id_deferred_uncited` extra, not a blocking `conflict_id_dropped` drop; KEEP_VAULT keeps its citation obligation and an unknown/absent resolution action stays fail-closed (blocking)
- **Layout-2 leg hand-off:** propose `/mega-sdd:migrate-paths --vault-layout=3` (never run silently) — it carries these resolutions into `bolts/U-XXX/binding-migrated.json` and ends with the mandatory full JIT re-bind

## Context-aware recommendations (v0.6+, Iter 7)

### REC1: KB-derived recommendation surfaced
- **Setup:** KB at `docs/knowledge-base/` has `[VERIFIED]` entry matching OQ-AR-7 in `10-domains/50-parameter-reference.md`
- **Expect:** AskUserQuestion option 1 labeled `<answer> (recommended)`; description shows rationale + KB citation + fallback_if_wrong + confidence: HIGH

### REC3: Vault/codebase MEDIUM-confidence recommendation
- **Setup:** No KB. The vault's decisions (`context.md ## Decisions`; layout-2 `vault.md ## Decisions`, legacy `05-decisions.md`) have D-003 about the error envelope; a `query-symbol-index.sh` hit finds an existing `ErrorResource.php`
- **Expect:** Option 1 labeled `<extrapolated answer> (recommended)`; description marks confidence MEDIUM with the vault ADR citation + the `file:line` read at HEAD (a leftover `codebase-map.md` is a hint, never the citation); user warned to review carefully

### REC4: Silent fallback when no confident sources
- **Setup:** Greenfield project, no KB, no relevant vault context
- **Expect:** AskUserQuestion presents WITHOUT `(recommended)` label; falls back to plain interactive walk (v0.5 behavior)
- **Critical:** NO fabricated recommendation; better silent than wrong

### REC5: Anti-halu — no citation = no recommendation
- **Setup:** Claude (LLM) suggests an answer based on prior knowledge alone (no KB/vault/codebase match)
- **Expect:** Skill REJECTS the suggestion at recommendation-build phase; no `(recommended)` surfaced

### REC6: High-stakes business OQ warning
- **Setup:** OQ category=business, priority=P1; a KB or vault source yields a recommendation
- **Expect:** AskUserQuestion description prefixed with ⚠️ "High-stakes business OQ. Review citation + rationale carefully before accepting."

### REC7: Audit trail on ACCEPT
- **Setup:** User picks option 1 (recommended)
- **Expect:** vault.json OQ entry has `resolution_source: recommendation` + `recommendation_citation: <full-citation>`

### REC8: Audit trail on OVERRIDE
- **Setup:** a `(recommended)` option WAS on the prompt and the user declined it — answering via "Other" with different text (often an alternative from the question text, typed back)
- **Expect:** vault OQ entry has `resolution_source: user_override` (the memory row, override counter and the 5-override self-correction loop died with the memory lane in v7.3.0 — nothing else is written)

### REC10b: "Other" with NO recommendation is a direct answer, NOT an override
- **Setup:** the no-recommendation shape (no citable signal, or the probe failed) — "Other" is the ONLY answer channel there; user types an answer
- **Expect:** vault OQ entry gets `resolution_source: user_direct` (the third declared value, per `references/recommendation-context.md §Audit trail`); NO `recommendation_ignored` field
- **Critical:** no `user_override` value is written. Keying the OVERRIDE branch on the CHANNEL ("answered via Other") instead of on *a recommendation existing and being declined* books every unsourced-OQ answer as an override of a recommendation that never existed

### AID1: Tech OQs never enter the walk
- **Setup:** vault with 3 open business OQs + 4 tech OQs the AI decided (`[x]` + `(AI decision …)`), one of them P1
- **Expect:** the queue holds the 3 business OQs only — zero `AskUserQuestion` for a tech OQ under every `RESOLUTION_SCOPE` (`all-priorities` included)

### AID2: `single-oq` on an AI decision = override
- **Setup:** `resolve-oq single-oq OQ-AR-7`; OQ-AR-7 is `[x]` with `→ **Resolved v1.0** (AI decision, 2026-09-20): RFC 7807 problem+json`
- **Expect:** ONE prompt; slot `[1]` = the AI's current pick with its rationale + fallback ("keputusan AI saat ini"); user types another answer via Other → the annotation becomes `→ **Resolved v1.1** (<date>): <human answer>` (NO marker), the next derive drops `resolved_by`, and the `--event` records `ai_decision_overridden` with the replaced pick
- **Expect (keep):** choosing slot `[1]` changes nothing — the marker and `resolved_by: ai` stay

### AID3: `single-oq` on a HUMAN-resolved OQ is not an override
- **Setup:** `single-oq OQ-DM-1`; OQ-DM-1 is `[x]` with a plain `→ **Resolved v1.1** (2026-07-19): UUID.`
- **Expect:** not re-opened by this path (behaviour unchanged)

## Pass criteria

All R1-R7 invoke skill correctly. Tech OQs are decided upstream and never asked (AID1); `single-oq` is the override path for an AI decision (AID2-AID3). The per-OQ walk costs ONE `AskUserQuestion` on the common path (B1, B13); Defer stays visible in every context and only its sub-target question is brownfield-conditional (B2-B3); alternatives ride the question text (B4); there is no typed end-the-walk sentinel and Esc ends the walk while slot `[2]` skips one item (B5-B7); the "Other" parse order composes a bare destination override with the recommendation and VALIDATES its target against the vault's documents for its layout before any write (B8, incl. 8e-8g); the Defer follow-up is one call with two questions, Q2 carries the tag + question text and discloses Esc in operator-visible text, nothing it collects is ever defaulted, and only the "Other" channel is described as verbatim (B9-B10b). State transitions match B11 and the changelog contract B12 — letters, never slot numbers, and no event at all for Skip. Language precedence and the high-stakes double marker hold (B14-B15). Binding mode walks the per-unit `binding.json` conflicts (evidence anchor mandatory, written back only via `write-unit-binding.sh --resolve`) and, on the layout-2 leg, the propagated OQs per BM1-BM3 (three options, Defer not offered, no invented fourth); hand-off is ACTION-MIX per BM4-BM5 (KEEP_CODE/SPLIT → `rebind-units.sh --units=<edited>` → `plan --reconcile`; KEEP_VAULT/DEFER-only → resume `execute-bolts --all --lite` with no re-bind — never a blanket re-bind that loops); a DEFER opens the unit's gate and the demoted OQ travels with it per BM6. Context-aware recommendations (REC1, REC3–REC10b) follow `references/recommendation-context.md` — citation mandatory (KB → vault → codebase at HEAD), silent fallback when no confident sources, audit trail on ACCEPT + OVERRIDE (keyed on a recommendation existing and being declined — never on the "Other" channel, per REC10b).
