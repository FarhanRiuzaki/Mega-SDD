# resolve-oq — binding mode (`--binding`)

Loaded when `resolve-oq` is invoked with `--binding`. Walks CONFLICT entries and propagated deferred-OQ entries from a `binding.md` file produced by `bind-codebase`, and writes resolutions back to `binding.md` + the `vault.json` changelog. The standard OQ walk (Steps 0–5) is covered by the interactive-walk reference the SKILL.md router lists.

**Invocation:** `resolve-oq --binding <path-to-binding.md>`

## Procedure

1. **Load and parse binding.md.** Expect sections:
   - "## Confirmed Claims" (no action needed — informational)
   - "## Conflicts (N) — BLOCKING" carrying one `### CONFLICT-N` detail block per conflict (heading + `- **Vault claim**:` / `- **Codebase reality**:` / `- **Claim**:` lines — the only conflict carrier)
   - "## Open Questions (N)" — auto-propagated deferred OQs that couldn't be auto-resolved

2. **Walk the `### CONFLICT-N` detail blocks** (the menu is built from the detail headings). For each conflict, present:

   ```
   CONFLICT-N (BLOCKING)
   > Vault claim: <text from binding.md>
   > Codebase reality: <text from binding.md> (<evidence anchor file:line from binding.md — MANDATORY: the user judges code-vs-vault, so show WHERE in code>)
   > Prior call (suggestion only, when decisions.md carries one for this claim pattern): <ACTION> on <date> — <rationale>

   Choose action:
     [K] KEEP_VAULT  — vault is correct; code patch will be required later (the CONFLICT re-raises on re-bind until the code change lands — by design)
     [C] KEEP_CODE   — vault is wrong; patch vault inline to match code (vault edited this session)
     [D] DEFER       — downgrade CONFLICT to OQ; gate binding TERBUKA, unit tetap digenerate membawa OQ-nya (execute-bolts prompt di "TBD: OQ-XXX" sebelum bolt final; P1 business menghentikan bolt)
     [S] SPLIT       — break vault claim into sub-claims (user provides splits; each sub-claim re-binds separately)
   ```

   The two claim texts + the evidence anchor are MANDATORY — a `CONFLICT-N` code alone is never a question (`plugins/mega-sdd/references/output-language.md §Prompt surfaces`). Source them from the detail block's `- **Vault claim**:` and `- **Codebase reality**:` lines (the anchor rides the Codebase-reality line). **Legacy fallback (pre-P2 bindings):** when a block predates those two lines, read the claim/reality pair from the old summary table and the evidence anchor from the Implementation State Map `Anchor` column (via the block's `- **Claim**:` id). The `Prior call` line renders ONLY when memory has one; it is a suggestion, never a default (the CONFLICT verdict is not bypassable by memory).

   **Resolution write-back grammar (S4 — the ONLY markers the gate reads).** A
   resolution is recorded by BOTH: (a) updating the `### CONFLICT-N` detail heading to
   `### ✅ CONFLICT-N RESOLVED (<ACTION>) — <original title>`, AND (b) appending a
   `- **Resolution**: ✅ RESOLVED (<ACTION>) <ISO date> — <one-line rationale>` line
   inside the detail block. `validate-handoff-binding-units.sh` and
   `validate-conflict-classification.sh` key ONLY on the heading-line marker or the
   dedicated Resolution line — a marker anywhere else (prose, a legacy table) does
   NOT clear the gate. Ensure the detail block carries its `- **Claim**: C-NNN` line
   (legacy blocks resolved before the W2 grammar may lack it — ADD it during
   write-back from the conflict's claim context; a bounded self-heal). Legacy note:
   pre-P2 bindings may still carry a summary table — ignore it; never update it
   (the gate never read it). Then **Run**
   `scripts/derive-binding-json.sh --vault <vault>` (the directory containing
   `binding.md`) to refresh `binding.json` FROM the updated markdown — the json is
   script-derived, never hand-patched (per
   `bind-codebase/references/binding-json-schema.md`); the resolved claims'
   `resolution:` fields appear from the RESOLVED blocks' Claim lines. Exit 2 = the
   write-back is malformed (most often a RESOLVED block still missing its Claim
   line) — fix the markdown and re-run. Do NOT re-run `validate-binding-json.sh`
   after a derive — parity is tautological immediately after deriving from the
   same markdown.

   Per-action behavior (vault.json is never hand-edited — the Step-4 derive run carries every manifest effect):

   | Action | binding.md update | vault md update |
   |---|---|---|
   | K — KEEP_VAULT | Heading + Resolution line marked `✅ RESOLVED (KEEP_VAULT — code update pending)`; the code-change obligation stays traceable via the CONFLICT-N reference the affected units carry in `binding_refs` (the propagation drop keeps it un-droppable) | vault claim unchanged |
   | C — KEEP_CODE | Heading + Resolution line marked `✅ RESOLVED (KEEP_CODE — vault patched)` | Edit vault claim inline to match code |
   | D — DEFER | Heading + Resolution line marked `✅ RESOLVED (DEFER)`; conflict moved to "Open Questions" table; tag as `deferred-binding` | none (the demoted OQ lives in binding.md — it enters vault.json via the Step-4 derive's `--patch <tmp-patch>`, file content `{"open_questions":{"OQ-XXX":{…, "status":"deferred", "defer_to":"binding", …}}}`; the deriver preserves such entries on every future derive even though they have no vault-md home) |
   | S — SPLIT | Heading + Resolution line marked `✅ RESOLVED (SPLIT)`; insert N sub-conflicts under it | For each sub-claim: edit vault to split |

3. **Walk Open Questions table.** For each propagated deferred-OQ, use the standard walk's **single collapsed prompt** (`interactive-walk.md` Step 2b is canonical — ONE `AskUserQuestion` per OQ), with **Defer dropped** (already in binding context — nested deferral not supported; re-binding flow is via re-running `bind-codebase`). That leaves **three** options, and slot numbers are display positions, so Out of scope renders at `[3]` here:

   - `[1]` the recommended answer (omitted when no citation-probed recommendation exists)
   - `[2]` Skip
   - `[3]` Out of scope
   - *Other* — the free-text ANSWER, parsed per Step 2b
   - *Esc* — end the walk

   **The `→ <file>.md` destination override does NOT apply in this mode** — Step 2b validates it against the vault's seven documents, and this walk writes none of them: a propagated-OQ resolution's only markdown home is `binding.md` (step 4). So the destination is fixed, not choosable. Still strip a trailing `→ <file>.md` and REJECT it with narration ("tujuan resolusi di mode `--binding` selalu `binding.md`") exactly as Step 2b handles a target outside the legal set: the remainder is the answer, and a BARE override resolves nothing (no write, counted as skipped). Never land a `--binding` resolution in a vault document.

   Never add a fourth option to fill the freed capacity: three options is the shape — not four with a hole. An invented answer is fabrication, and the cap is a ceiling, not a quota. There is no typed end-the-walk sentinel here either. The recorded `action` letters are unchanged (`A` answer / `C` out-of-scope / Skip emits no event).

4. **Write back.** All resolutions persist to:
   - `binding.md` — detail headings + Resolution lines (+ `- **Claim**:` lines) per the write-back grammar above (the detail blocks are the only surface written)
   - `binding.json` — refreshed by running `scripts/derive-binding-json.sh --vault <vault>` after the markdown write (script-derived from `binding.md`; never edited by hand)
   - `vault.json` — **Run** `scripts/derive-vault-json.sh --vault <vault> --event '{"event":"resolve-oq-binding","at":"<iso>","summary":"N conflicts resolved, M OQs resolved"}'` (+ `--patch <tmp-patch>` — a temp FILE carrying the DEFER-demoted `defer_to: binding` OQ entries per the table above; `--patch` never takes inline JSON). Run it AFTER `derive-binding-json.sh` (the W2 ordering — binding.json first, then the vault manifest event). Script-derived; never edited by hand
   - `decisions.md` (memory layer) — each resolution recorded durably (survives re-binds; per resolve-oq's auto-memory-handoff reference)

5. **Hand-off (S4 — differs per action mix; a blanket re-bind LOOPS on KEEP_VAULT).**
   - **Any KEEP_CODE or SPLIT chosen** (the vault was edited) → suggest `bind-codebase` re-run: the edited claims now match code and re-bind cleanly.
   - **Only KEEP_VAULT / DEFER chosen** (vault AND code unchanged) → do NOT suggest a re-bind: bind Step 2 re-derives verdicts from the unchanged vault-vs-code contradiction, so a re-bind RE-RAISES the same CONFLICT (by design — bind never consumes a prior resolution as evidence; memory only SUGGESTS). The resolved-marked `binding.md` already passes `validate-handoff-binding-units.sh`, so proceed to `generate-units`. For KEEP_VAULT, `<vault>/bound/` is produced only by a future re-bind AFTER the code change lands (typically via execute-bolts on the units carrying the CONFLICT-N reference).
   - Mixed → re-bind (for the vault edits); expect KEEP_VAULT conflicts to re-raise and re-mark them (decisions.md carries the prior call as a suggestion).

## Hard rails

- **Never auto-resolve conflicts.** Always user choice per row.
- **Never modify code files.** resolve-oq is read-only on the repo; KEEP_VAULT marks the conflict but does NOT patch code (that happens in `execute-bolts` later).
- **Cycle protection:** if `--binding` is invoked but binding.md is malformed or empty, halt with a helpful error.
