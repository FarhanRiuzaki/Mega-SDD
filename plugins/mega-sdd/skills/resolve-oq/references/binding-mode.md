# resolve-oq — binding mode (`--binding`)

Loaded when `resolve-oq` is invoked with `--binding`. Walks the unresolved CONFLICT claims in `<vault>/bolts/U-*/binding.json` (the JIT bind, execute-bolts 3.9) and writes back ONLY via `write-unit-binding.sh --resolve=<C-id>=<ACTION> --by=user` + a `vault.json` event. An older layout-2 vault that has not been migrated still carries the whole-vault `binding.md` its classic bind wrote; the **layout-2 leg** below walks it. The standard OQ walk (Steps 0–5) is covered by the interactive-walk reference the SKILL.md router lists.

**Invocation:** `resolve-oq --binding <vault-dir>` — every `bolts/U-*/binding.json` is walked (a `<vault>/bolts/U-XXX/binding.json` argument walks that unit only). A layout-2 vault (or a `<path-to-binding.md>` argument) takes the layout-2 leg.

## Procedure

1. **Load.** Every `<vault>/bolts/U-*/binding.json` whose `claims[]` carry `verdict: CONFLICT` without a `resolution`: each such claim is a conflict to walk. So is every `conflict_history` episode without a `resolution` that the `conflict_bypassed` gate names (`.mega-sdd/.bolt-conflict-bypass-state.json`, reason `closed_conflict`): a unit was committed while it was open and a later re-bind closed it — show the claim, the commit and `closed_at`; the same `--resolve=<claim-id>=<ACTION>` records the decision on the episode. The file is hook-guarded evidence (one writer); never Edit it. **Layout-2 leg:** parse `binding.md` instead. Expect sections:
   - "## Confirmed Claims" (no action needed — informational)
   - "## Conflicts (N) — BLOCKING" carrying one `### CONFLICT-N` detail block per conflict (heading + `- **Vault claim**:` / `- **Codebase reality**:` / `- **Claim**:` lines — the only conflict carrier)
   - "## Open Questions (N)" — auto-propagated deferred OQs that couldn't be auto-resolved (Step 3)

2. **Walk the conflicts** (on the layout-2 leg the menu is built from the `### CONFLICT-N` detail headings). For each conflict, present:

   ```
   CONFLICT-N (BLOCKING)
   > Vault claim: <text>
   > Codebase reality: <text> (<evidence anchor file:line — MANDATORY: the user judges code-vs-vault, so show WHERE in code>)

   Choose action:
     [K] KEEP_VAULT  — vault is correct; code patch will be required later (the unit's bolt lands it; a re-bind keeps this resolution until that code moves)
     [C] KEEP_CODE   — vault is wrong; patch vault inline to match code (vault edited this session)
     [D] DEFER       — downgrade CONFLICT to OQ; gate binding TERBUKA, unit tetap jalan membawa OQ-nya (execute-bolts prompt di "TBD: OQ-XXX" sebelum bolt final; P1 business menghentikan bolt)
     [S] SPLIT       — break vault claim into sub-claims (user provides splits; each sub-claim re-binds separately)
   ```

   The two claim texts + the evidence anchor are MANDATORY — a conflict id alone is never a question (`plugins/mega-sdd/references/output-language.md §Prompt surfaces`). Sources: `CONFLICT-N` = `U-XXX · <claim id>`; Vault claim = the claim's `text` (else its `kind` + `expect`); Codebase reality = its `evidence`; the anchor = its `anchor`. **Layout-2 leg:** the detail block's `- **Vault claim**:` and `- **Codebase reality**:` lines (the anchor rides the Codebase-reality line). **Legacy fallback (pre-P2 bindings):** when a block predates those two lines, read the claim/reality pair from the old summary table and the evidence anchor from the Implementation State Map `Anchor` column (via the block's `- **Claim**:` id).

   **Write-back.** Per resolved claim, **Run** `bash <plugin>/scripts/write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --resolve=<claim-id>=KEEP_VAULT|KEEP_CODE|SPLIT|DEFER --by=user` (DEFER = the `[D]` option: the CONFLICT is downgraded to an OQ the unit carries, the unit's gate opens).

   **Layout-2 leg — Resolution write-back grammar (S4 — the ONLY markers the gate reads).** A
   resolution is recorded by BOTH: (a) updating the `### CONFLICT-N` detail heading to
   `### ✅ CONFLICT-N RESOLVED (<ACTION>) — <original title>`, AND (b) appending a
   `- **Resolution**: ✅ RESOLVED (<ACTION>) <ISO date> — <one-line rationale>` line
   inside the detail block. `validate-handoff-binding-units.sh` keys
   ONLY on the heading-line marker or the
   dedicated Resolution line — a marker anywhere else (prose, a legacy table) does
   NOT clear the gate. Ensure the detail block carries its `- **Claim**: C-NNN` line
   (legacy blocks may lack it — ADD it during
   write-back from the conflict's claim context; a bounded self-heal). Legacy note:
   pre-P2 bindings may still carry a summary table — ignore it; never update it
   (the gate never read it). Then **Run**
   `scripts/derive-binding-json.sh --vault <vault>` (the directory containing
   `binding.md`) to refresh `binding.json` FROM the updated markdown — the json is
   script-derived, never hand-patched (grammar owner: `scripts/_lib/binding_md.py`);
   the resolved claims'
   `resolution:` fields appear from the RESOLVED blocks' Claim lines. Exit 2 = the
   write-back is malformed (most often a RESOLVED block still missing its Claim
   line) — fix the markdown and re-run.
   `derive-binding-json.sh` is the single binding.json writer; there is no separate parity re-run.

   Per-action behavior (vault.json is never hand-edited — the Step-4 derive run carries every manifest effect):

   | Action | vault md update | layout-2 leg: binding.md update |
   |---|---|---|
   | K — KEEP_VAULT | vault claim unchanged; the code change lands in that unit's bolt | Heading + Resolution line marked `✅ RESOLVED (KEEP_VAULT — code update pending)`; the obligation stays traceable via the CONFLICT-N reference the affected units carry in `binding_refs` |
   | C — KEEP_CODE | Edit the unit's `## Claims` line to match code (+ the `context.md` sentence it cites) | Heading + Resolution line marked `✅ RESOLVED (KEEP_CODE — vault patched)`; edit the vault claim inline |
   | D — DEFER | none — the demoted OQ enters `vault.json` via the Step-4 derive's `--patch <tmp-patch>`, file content `{"open_questions":{"OQ-XXX":{…, "status":"deferred", "defer_to":"binding", …}}}`; the deriver preserves such entries on every future derive even though they have no vault-md home, so the delivery report's Deferred OQs resurface it | Heading + Resolution line marked `✅ RESOLVED (DEFER)`; conflict moved to "Open Questions" table; tag as `deferred-binding` |
   | S — SPLIT | For each sub-claim: split the unit's `## Claims` line (+ the `context.md` sentence) | Heading + Resolution line marked `✅ RESOLVED (SPLIT)`; insert N sub-conflicts under it; edit the vault to split |

3. **Walk Open Questions table.** Layout-2 leg only (a per-unit `binding.json` has no propagated-OQ table). For each propagated deferred-OQ, use the standard walk's **single collapsed prompt** (`interactive-walk.md` Step 2b is canonical — ONE `AskUserQuestion` per OQ), with **Defer dropped** (already in binding context — nested deferral not supported). That leaves **three** options, and slot numbers are display positions, so Out of scope renders at `[3]` here:

   - `[1]` the recommended answer (omitted when no citation-probed recommendation exists)
   - `[2]` Skip
   - `[3]` Out of scope
   - *Other* — the free-text ANSWER, parsed per Step 2b
   - *Esc* — end the walk

   **The `→ <file>.md` destination override does NOT apply in this mode** — Step 2b validates it against the vault's document filenames for its layout, and this walk writes none of them: a propagated-OQ resolution's only markdown home is `binding.md` (step 4). So the destination is fixed, not choosable. Still strip a trailing `→ <file>.md` and REJECT it with narration ("tujuan resolusi di mode `--binding` selalu `binding.md`") exactly as Step 2b handles a target outside the legal set: the remainder is the answer, and a BARE override resolves nothing (no write, counted as skipped). Never land a `--binding` resolution in a vault document.

   Never add a fourth option to fill the freed capacity: three options is the shape — not four with a hole. An invented answer is fabrication, and the cap is a ceiling, not a quota. There is no typed end-the-walk sentinel here either. The recorded `action` letters are unchanged (`A` answer / `C` out-of-scope / Skip emits no event).

4. **Write back.** All resolutions persist to:
   - `bolts/U-*/binding.json` — only through `write-unit-binding.sh --resolve` (Step 2). **Layout-2 leg:** `binding.md` detail headings + Resolution lines (+ `- **Claim**:` lines) per the write-back grammar, then `binding.json` refreshed by `scripts/derive-binding-json.sh --vault <vault>` (never edited by hand)
   - `vault.json` — **Run** `scripts/derive-vault-json.sh --vault <vault> --event '{"event":"resolve-oq-binding","at":"<iso>","summary":"N conflicts resolved, M OQs resolved"}'` (+ `--patch <tmp-patch>` — a temp FILE carrying the DEFER-demoted `defer_to: binding` OQ entries per the table above; `--patch` never takes inline JSON). Run it AFTER the binding write-back. Script-derived; never edited by hand
   - `vault.json` changelog (`--event` append per outcome) — each resolution recorded durably (survives re-binds)

5. **Hand-off (differs per action mix).**
   - **Any KEEP_CODE or SPLIT** (a unit was edited) → re-bind just the edited units, `scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=<edited U-ids>` (the edited claims bind cleanly), then `plan --reconcile` (task_type flips), then resume `/mega-sdd --resume` (`execute-bolts --all --lite`). Skipped, the BOLTS gate backstops it: the edited unit trips `unit_changed_since_bind` and 3.9b re-binds it.
   - **Only KEEP_VAULT / DEFER** → do NOT suggest a re-bind: resume `execute-bolts --all --lite` directly. The resolved claims already pass `validate-handoff-binding-units.sh --units=`, and a later re-bind keeps them (`_lib/unit_binding.py` carries a resolution forward while the claim and its code paths are unchanged). KEEP_VAULT's code change lands in that unit's bolt.
   - **Layout-2 leg:** propose `/mega-sdd:migrate-paths --vault-layout=3` (never run it silently) — it carries these resolutions into `bolts/U-XXX/binding-migrated.json` and ends with the mandatory full JIT re-bind; a CONFLICT that re-bind raises again is walked here on the per-unit path.

## Hard rails

- **Never auto-resolve conflicts.** Always user choice per row.
- **Never modify code files.** resolve-oq is read-only on the repo; KEEP_VAULT marks the conflict but does NOT patch code (that happens in `execute-bolts` later).
- **Cycle protection (nothing to walk / unreadable input):** no `bolts/U-*/binding.json` carries an open CONFLICT → say so and exit. An unparseable `binding.json` → halt naming the `write-unit-binding.sh` re-run (`validate-handoff-binding-units.sh` reports it as `<U>:binding.json`). Layout-2 leg: a malformed or empty `binding.md` → halt with a helpful error.
