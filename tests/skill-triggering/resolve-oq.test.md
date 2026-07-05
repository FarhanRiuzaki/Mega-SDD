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

## Behavior — 4-action menu

### B1: All 4 options offered (brownfield)
- **Setup:** vault.mode=existing AND .git present
- **Expect:** Per OQ, options [A] Answer / [B] Defer / [C] Out-of-scope / [D] Skip shown

### B2: Defer option hidden (greenfield)
- **Setup:** vault.mode=greenfield
- **Expect:** Per OQ, only options [A] / [C] / [D] shown

### B3: Defer option hidden (no repo signals)
- **Setup:** vault.mode=existing but CWD has no .git/package.json/etc.
- **Expect:** Only options [A] / [C] / [D] shown; skill warns user about the mode/CWD mismatch

### B4: State transitions per action
- **[A] Answer** → OQ becomes `status: resolved`, `resolved_at: <iso>`, `resolution: <text>`
- **[B] Defer to binding** → `status: deferred`, `defer_to: binding`, `deferred_at: <iso>`, optional `deferred_reason`
- **[C] Out of scope** → `status: out-of-scope`, `out_of_scope_reason: <text>`
- **[D] Skip** → no field change; OQ remains pending

### B5: Vault.json changelog appended
- **After any action:** vault.json gets a new changelog entry: `{ "event": "oq-<action>", "id": "OQ-XXX", "at": "<iso>", "action": "A|B|C|D" }`

## Behavior — --binding mode

### BM1: Walks conflicts
- **Setup:** binding.md has 2 CONFLICT rows
- **Expect:** Skill prompts per conflict with [K] KEEP_VAULT / [C] KEEP_CODE / [D] DEFER / [S] SPLIT

### BM2: Walks propagated deferred OQs
- **Setup:** binding.md has 1 CONFLICT + 2 Open Questions rows
- **Expect:** Skill walks CONFLICTs first, then OQs (with 4-action menu, Option B hidden because nested deferral not supported)

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
- **Setup:** User picks alternative option (not recommended)
- **Expect:** vault OQ entry has `resolution_source: user_override`; memory row marked `recommendation_ignored: <recommended-text>`
- **Self-learning feedback:** override counter incremented for this OQ pattern

### REC9: Self-correction loop after 5 overrides
- **Setup:** Same OQ pattern has been overridden 5 times across runs
- **Expect:** `~/.mega-sdd/memory/patterns.md` pending suggestion: "Disable recommendation for OQ pattern X (5/5 overrides)"; user reviews via `/mega-sdd:memory review`; ACCEPT disables future recommendations for that pattern

### REC10: Override reason captured (optional)
- **Setup:** User picks alternative + provides override reason via free-text
- **Expect:** memory row includes `override_reason: <user-text>`; aids future pattern analysis

## Pass criteria

All R1-R7 invoke skill correctly. 4-action menu obeys brownfield/greenfield/repo-signal conditions. State transitions match B4. Binding mode walks conflicts and OQs per BM1-BM3; hand-off is ACTION-MIX per BM4-BM5 (KEEP_CODE/SPLIT→bind-codebase, KEEP_VAULT/DEFER-only→generate-units — never a blanket re-bind that loops); DEFER-resolved uncited CONFLICTs are advisory at the binding→units gate per BM6. Context-aware recommendations (REC1-REC10) follow `references/recommendation-context.md` — citation mandatory, silent fallback when no confident sources, audit trail on ACCEPT + OVERRIDE, self-correction loop after consistent overrides.
