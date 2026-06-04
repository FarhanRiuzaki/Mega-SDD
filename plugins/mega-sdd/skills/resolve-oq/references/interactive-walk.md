# resolve-oq — interactive walk procedure

## Contents
- Step 0 — Vault location & integrity check
- Step 0.5 — Resume detection
- Step 0.6 — Resolution scope
- Step 1 — Parse OQ list
- Step 2 — Loop per OQ (display, 4-action menu, state transitions)
- Step 2c — Apply outcome (Resolve / Out of Scope / Defer / Skip)
- Step 3 — Update vault metadata (version + Changelog template)
- Step 4 — Self-check before exit
- Step 5 — Present summary

Loaded by `resolve-oq` for the standard (non-`--binding`) walk. The SKILL.md body carries the compact skeleton + rails; this file carries the full procedure, display formats, templates, and the self-check. Resolution content is recorded in the vault's existing language.

## Step 0 — Vault location & integrity check (MANDATORY)

1. **Get the vault path** from the user.
   - **Claude Code**: use `AskUserQuestion` with options like `["Use auto-detected '<path>'", "Specify path", "Cancel"]`.
   - Auto-detect: scan CWD for a directory containing all of `00-index.md`, `01-overview.md`, `02-architecture.md`, `03-data-model.md`, `04-flows.md`, `05-decisions.md`, `06-constraints.md`. If exactly one such directory exists, suggest it as default.
   - Fallback: ask plainly — *"Path to the vault directory? (must contain 00-index.md through 06-constraints.md)"*

2. **Verify integrity**:
   - All 7 files exist (`00-index.md` through `06-constraints.md`).
   - `00-index.md` has a `## Open Questions roll-up` section.
   - At least one `[ ]` OQ entry exists across the 6 numbered docs.
   - If any check fails → STOP, surface the issue. Suggest the user run `generate-intent` first if the vault is malformed/missing.

3. **Lock check**: parse `00-index.md` Vault Lock Status section for the `Status:` line.
   - If `Status: 🔒 LOCKED` → ask via `AskUserQuestion`: *"This vault is LOCKED for `<scope>`. Resolving OQs will edit it and require re-sign-off after. Proceed?"* → options `["Unlock and proceed (re-sign-off needed after)", "Cancel"]`.
   - If user cancels → STOP. If proceeds → record in the resolution-round Changelog entry that the vault was unlocked for this round. User is responsible for re-locking after the round: edit `00-index.md` Vault Lock Status — change `Status: ⚠️ DRAFT (unlocked for resolve-oq round)` back to `Status: 🔒 LOCKED for <scope>`, refresh `Locked at` / `Locked by`, append a Changelog entry confirming the relock.
   - If `Status: ⚠️ DRAFT` → no lock; continue normally.

4. **Persist** the vault path:
   - Echo: `VAULT_DIR=<resolved-absolute-path>`.
   - Re-echo at the start of each major step.

> Skill never proceeds to Step 0.5 without a verified vault and lock-state acknowledged.

## Step 0.5 — Resume detection (MANDATORY, after vault path)

1. Parse `00-index.md` `## Changelog` for entries from prior runs of this skill (look for `### v{X.Y} (YYYY-MM-DD)` entries that say "Resolved N OQs via resolve-oq").
2. If a prior round exists:
   - Show: *"Vault is currently at v{X.Y}. Last resolution round on {date} resolved {N} OQs. {M} OQs are still `[ ]` open."*
   - Ask via `AskUserQuestion`: `["Continue from current state", "Start fresh review of all open OQs", "Cancel"]`.
3. If no prior round: this is the first resolution pass. Continue.

## Step 0.6 — Resolution scope (MANDATORY, after resume detection)

Ask the user which OQs to walk through this session:

- **`p1-only`** — only Priority 1 OQs (sprint-0 blockers). Recommended for a focused first pass.
- **`p1-then-p2`** — P1 first, then P2. Skip P3.
- **`all-priorities`** — full P1 → P2 → P3 walk. Long session.
- **`by-category`** — group by category from the roll-up (e.g., "PRD inconsistencies" first, "Tech stack" second). Useful when each category aligns with a different stakeholder.
- **`single-oq`** — jump to a specific OQ tag (e.g., `OQ-FL-1`). For quick targeted resolution.

Persist: `RESOLUTION_SCOPE=<choice>`. Echo back so the user sees the plan.

## Step 1 — Parse OQ list

1. Read all 7 vault files.
2. For each numbered doc (01–06), extract entries from its `## Open Questions` section that are still `[ ]` (open) — skip `[x]` (resolved) and `[~]` (out of scope).
3. For each OQ, capture:
   - Tag (`OQ-{CODE}-{N}`)
   - Priority (`P1 | P2 | P3`)
   - Doc origin
   - Question text
   - Any resolution-path hint already written by the original generator (often after "Resolution:" or "Resolve:").
4. Cross-reference with `00-index.md` Open Questions roll-up to capture the **category** assigned in the roll-up (e.g., "PRD inconsistencies", "Tech stack & architecture") — this informs the by-category scope.
5. Build the work queue based on `RESOLUTION_SCOPE` from Step 0.6.

If the queue is empty (e.g., user picked `p1-only` and there are no P1 OQs left) → skip to Step 5 with summary.

## Step 2 — Loop per OQ

For each OQ in the queue:

### Step 2a — Display

Show the user:

```
[{i}/{N}] {OQ tag}  {priority}  {category}
  Doc: {doc filename} → {section anchor if available}
  Question: {full question text}
  Hint: {resolution-path hint from generator, if present}
```

When `vault.json` has a `scope` field, prepend scope context to the panel (and to each `AskUserQuestion`):

```
OQ-AR-7 [P1] [tech] (scope: BE — Backend API):
  Question: Use RFC 7807 problem+json envelope?
  ...
```

Lightweight: read `vault.json` scope at skill start; prepend scope context to each `AskUserQuestion`. Helps multi-architect scenarios where one OQ might involve cross-scope dependencies — the user knows which scope they're answering for. (The matching scope handoff block is documented under the `--auto` / handoff reference the SKILL.md router lists.)

### Step 2b — Action prompt

For each OQ presented (in priority order P0 → P1 → P2 → P3), display:

```
OQ-<DOC>-<NNN> (<priority>, section <filename>)
> <question text>

Choose action:
  [A] Answer now              — provide stakeholder resolution inline
  [B] Defer to binding        — code-dependent OQ; resolve at bind-codebase phase
  [C] Out of scope            — declare irrelevant to current spec
  [D] Skip                    — leave pending, decide later
```

**Conditional display of Option [B].** Option [B] appears ONLY when ALL of these are true:
- Vault `mode: existing` (brownfield)
- CWD has repo signals (any of `.git`, `package.json`, `composer.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`)

In greenfield contexts OR when no repo signals detected, suppress Option [B] from the menu. The user sees only [A], [C], [D].

**Per-action state transitions:**

| Action | OQ field changes |
|---|---|
| A — Answer | `status: resolved`, `resolved_at: <now>`, `resolution: <answer text>` |
| B — Defer to binding | `status: deferred`, `defer_to: binding`, `deferred_at: <now>`, `deferred_reason: <optional user-provided text>` |
| C — Out of scope | `status: out-of-scope`, `out_of_scope_reason: <text>` |
| D — Skip | (no field changes; OQ remains pending) |

After action selection, write the field updates to `vault.json` immediately and append to the vault's changelog:
```
{ "event": "oq-resolved" | "oq-deferred" | "oq-out-of-scope", "id": "OQ-XXX", "at": "<iso>", "action": "A|B|C|D" }
```

### Step 2c — Apply outcome

**If `Resolve`:**

1. Ask the user for the answer (free text, up to a few sentences).
2. Auto-classify the resolution destination by OQ code prefix:
   - `OV-` → typically updates `01-overview.md` (success criteria, OOS, persona)
   - `AR-` → typically `02-architecture.md` (component, endpoint, tech stack, layer detail)
   - `DM-` → typically `03-data-model.md` (field constraint, table, relation)
   - `FL-` → typically `04-flows.md` (flow step, DoD detail, edge case)
   - `DC-` → typically `05-decisions.md` (new ADR `D-XXX`)
   - `CN-` → typically `06-constraints.md` (NFR, business, technical, regulatory)
3. Show the auto-classified destination + ask user to confirm or override (any OQ can land in any doc; the prefix is just a hint).
4. Choose resolution density:
   - **Inline** (default for short answers) — the answer goes inline in the OQ entry: `[x] **OQ-XXX-N** [P{x}]: <original question> → **Resolved v{X.Y}** (YYYY-MM-DD): <answer>.`
   - **Promoted** (for substantial answers) — the answer is added to the target doc as a new entry (e.g., new ADR `D-XXX` in `05-decisions.md`, new field constraint in `03-data-model.md`), and the OQ entry points to it: `[x] **OQ-XXX-N** [P{x}]: <original question> → Resolved as **D-010** in `05-decisions.md` (v{X.Y}).`
5. **Cross-cutting check**: some OQs legitimately affect 3+ docs (e.g., a tech-stack decision touches `02-architecture.md` "Tech stack" line + a new ADR in `05-decisions.md` + a constraint in `06-constraints.md`). For these:
   - After auto-classification, ask the user: *"This OQ looks cross-cutting (touches multiple docs). Land primary content in `<auto-classified primary doc>` and add cross-references in `<other affected docs>`?"*
   - User confirms or overrides which doc is primary.
   - Skill writes the **primary entry** in full (e.g., new ADR `D-XXX` in `05-decisions.md`).
   - Skill adds **cross-reference lines** in the other affected docs, format: `> Resolves OQ-{tag}: see {primary-doc.md}#{anchor or D-XXX}`. The cross-ref stays terse — no content duplication.
   - All entries point back to the OQ tag for audit trail.
   - Heuristic for cross-cutting: tech stack, multi-tenancy isolation, auth specifics, compliance items — these almost always touch ≥3 docs. Single-AC clarifications usually don't.
6. For `Promoted`, format the new entry per the target doc's existing convention:
   - `05-decisions.md`: ADR-lite per the `OUTPUT_MODE` of the vault (compact = 1-paragraph; full = multi-section). Set `**Status**: Accepted`, `**Date**: YYYY-MM`, `**Source**: resolve-oq session YYYY-MM-DD + <stakeholder/PIC if user named one>`. Cross-reference the resolved OQ tag in the Context line.
   - `03-data-model.md`: append constraint to relevant entity's DBML notes, or update the field-level validation table. Add comment `// Resolves OQ-DM-N`.
   - Other docs: append to the appropriate sub-section, with a `> Resolves OQ-{tag}` annotation.
7. Write the changes to the file(s) using `Edit`.
8. Update the OQ roll-up entry in `00-index.md` to also show `[x]` resolved with the same pointer.
9. **Update `vault.json` (lock contract):** change the OQ's `status` from `open` to `resolved` in the manifest, recompute `open_questions_summary` counts. If a new ADR was created, add it to `adrs[]`. If a new entity field was added, update that entity in `entities[]`.

   Acquire an exclusive file lock on `<vault>/vault.json.lock` per `../generate-intent/references/vault-contract.md §Concurrency contract` BEFORE writing vault.json. Backoff + retry 3×; fail with a `memory_in_use` halt if all retries fail. Release the lock after the atomic write completes. Lock acquisition is REQUIRED for every vault.json regen path in resolve-oq (Resolve / Out-of-Scope / Defer outcomes ALL write vault.json).
10. Show the user a confirmation summary of the diff.

**If `Out of Scope`:**

1. Ask the user for the rationale (1 sentence — why is this not in scope for the project?).
2. Move the OQ entry to the same doc's `## Out of Scope` section with format: `- <original question text>. (was OQ-XXX-N, declared OOS v{X.Y} on YYYY-MM-DD: <rationale>)`.
3. In the original `## Open Questions` section, mark the OQ `[~]` with a one-line pointer: `[~] **OQ-XXX-N** [P{x}]: <original question> → Out of Scope v{X.Y}: see Out of Scope section.`
4. Update the roll-up entry in `00-index.md` similarly.
5. **Update `vault.json`:** set the OQ's `status` to `out_of_scope` in the manifest; recompute `open_questions_summary.by_status`. (Same lock contract as the Resolve path.)

**If `Defer`:**

There are TWO defer targets (per `vault-contract.md §schema` `defer_to` field):

- **`defer_to: stakeholder`** (default) — waiting on a human decision (legal review, PM, security, target date)
- **`defer_to: binding`** — code-aware OQ; offered ONLY in brownfield context (vault.mode=existing AND repo signals present); resolved at `bind-codebase` phase against codebase-map

For brownfield code-aware OQs, prefer the 4-action menu's `[B] Defer to binding` option (Step 2b). The procedure below applies to stakeholder-defer specifically.

1. Ask the user for the defer reason — who needs to answer, by when, or what condition unblocks it (e.g., "waiting on legal review by 2026-06-01").
2. Append to the OQ entry: `**Deferred (v{X.Y})**: <reason / PIC / target date>`.
3. Leave `[ ]` open (it's still an Open Question, just waiting).
4. Update the roll-up annotation in `00-index.md` so readers see the defer reason at-a-glance.
5. **Update `vault.json`:** set the OQ's `status` to `deferred` in the manifest; set `defer_to: stakeholder`; set `deferred_at: <iso>`; set `deferred_reason: <user-provided text>` (per OQ schema in `vault-contract.md`); recompute `open_questions_summary.by_status`. (Same lock contract.)

**If `Skip`:**

1. No file changes.
2. Track skipped count — surface in the Step 5 summary as "still open after this session".

### Step 2d — Continue

Move to the next OQ in the queue. Allow the user to bail out at any time (`AskUserQuestion` should always include a "Stop here, save progress, exit" option in case they need to step away).

## Step 3 — Update vault metadata

After the loop completes (or the user bails out with progress to save):

1. **Bump vault version** in `00-index.md` Vault Lock Status:
   - Patch bump for resolution-only rounds (e.g., v1.0 → v1.1).
   - The bump is shared across the round — every OQ resolved/OOS/deferred in this session gets the same `v{X.Y}` marker.
2. **Append Changelog entry** to `00-index.md`:

```markdown
### v{X.Y} ({YYYY-MM-DD})

Resolved {R} OQs via `resolve-oq` session.

- **Resolved** ({R} entries):
  - OQ-XXX-N → <1-line resolution summary> (see {target doc/section})
  - OQ-YYY-M → <...>
- **Out of Scope** ({O} entries):
  - OQ-ZZZ-K → <reason>
- **Deferred** ({D} entries):
  - OQ-AAA-P → <reason + PIC / target date>
- **Still open after this session**: {S}
```

3. **Update `Last updated`** date in `00-index.md` to today's date (`YYYY-MM-DD`).

## Step 4 — Self-check before exit

- [ ] Every resolved OQ marked `[x]` with a `→ Resolved v{X.Y}` pointer in both its origin doc AND the roll-up in `00-index.md`.
- [ ] Every Out of Scope OQ marked `[~]` and physically present in the target doc's `## Out of Scope` section.
- [ ] Every Deferred OQ still `[ ]` but with a `**Deferred (v{X.Y})**:` annotation.
- [ ] No OQ silently dropped (every queue item ended in resolve / OOS / defer / skip).
- [ ] Vault version bumped in Vault Lock Status section.
- [ ] Changelog entry written with accurate counts.
- [ ] `Last updated` date updated.
- [ ] If any resolution was `Promoted`, the target doc has the new entry (e.g., new ADR `D-XXX` exists in `05-decisions.md`) — verify via grep that the cross-reference resolves.
- [ ] No invented answers. Every resolution traces to user input from this session. Skill never auto-fills "best practice" defaults.
- [ ] `vault.json.open_questions_summary.total` matches the count of OQ entries in `00-index.md` roll-up after the round.
- [ ] Every OQ marked `[x]` / `[~]` / Deferred in markdown has matching `status` (`resolved` / `out_of_scope` / `deferred`) in `vault.json.open_questions[]`.
- [ ] If any resolution was Promoted to a new ADR, `vault.json.adrs[]` contains the new entry.

## Step 5 — Present summary

Output to chat (no file generation needed at this step):

1. Summary stats: `{R} resolved · {O} out of scope · {D} deferred · {S} skipped (still open) · {U} untouched (out of scope this round)`.
2. New vault version: `v{X.Y}`.
3. Path to vault: `<VAULT_DIR>` (absolute).
4. If still-open count > 0: top 3 remaining P1 blockers (one-line each) with their tags.
5. Suggested next step: re-run `resolve-oq` after stakeholder follow-up. To lock the vault for sprint implementation, edit `00-index.md` Vault Lock Status manually (`Status: 🔒 LOCKED for <scope>`, fill `Locked at` / `Locked by`, append a Changelog entry).

After completion, if any OQs were deferred to binding, suggest:
- For brownfield: `/mega-sdd:scan-codebase && /mega-sdd:bind-codebase <vault>` (binding will auto-resolve deferred OQs against codebase-map)
- For greenfield: warn the user — deferred OQs in greenfield have no resolution path (no binding phase will run)

Do NOT pad with "I have resolved..." preamble. Just report numbers and surface remaining blockers.
