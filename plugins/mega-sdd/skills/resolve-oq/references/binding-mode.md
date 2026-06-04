# resolve-oq — binding mode (`--binding`)

Loaded when `resolve-oq` is invoked with `--binding`. Walks CONFLICT entries and propagated deferred-OQ entries from a `binding.md` file produced by `bind-codebase`, and writes resolutions back to `binding.md` + the `vault.json` changelog. The standard OQ walk (Steps 0–5) is covered by the interactive-walk reference the SKILL.md router lists.

**Invocation:** `/mega-sdd:resolve-oq --binding <path-to-binding.md>`

## Procedure

1. **Load and parse binding.md.** Expect sections:
   - "## Confirmed Claims" (no action needed — informational)
   - "## Conflicts (N) — BLOCKING" with table columns: ID | Vault Claim | Codebase Reality | Resolution Needed
   - "## Open Questions (N)" — auto-propagated deferred OQs that couldn't be auto-resolved

2. **Walk Conflicts table.** For each conflict, present:

   ```
   C-NNN (BLOCKING)
   > Vault claim: <text from binding.md>
   > Codebase reality: <text from binding.md>

   Choose action:
     [K] KEEP_VAULT  — vault is correct; code patch will be required later
     [C] KEEP_CODE   — vault is wrong; patch vault inline to match code
     [D] DEFER       — downgrade CONFLICT to OQ; re-resolve later
     [S] SPLIT       — break vault claim into sub-claims (user provides splits)
   ```

   Per-action behavior:

   | Action | binding.md update | vault.json update |
   |---|---|---|
   | K — KEEP_VAULT | Mark conflict resolved as `CONFIRMED_PENDING_CODE_UPDATE` | Append changelog entry; vault claim unchanged |
   | C — KEEP_CODE | Mark conflict resolved as `vault patched` | Edit vault claim inline to match code; changelog entry |
   | D — DEFER | Move conflict to "Open Questions" table; tag as `deferred-binding` | Add new OQ entry (status=deferred, defer_to=binding); changelog |
   | S — SPLIT | Mark original conflict resolved; insert N sub-conflicts under it | For each sub-claim: edit vault to split; changelog |

3. **Walk Open Questions table.** For each propagated deferred-OQ, use the standard 4-action menu (`[A]` Answer now / `[C]` Out of scope / `[D]` Skip — same Step 2b menu as the standard walk), with **Option [B] Defer hidden** (already in binding context — nested deferral not supported; re-binding flow is via re-running `bind-codebase`).

4. **Write back.** All resolutions persist to:
   - `binding.md` — conflict rows updated with resolution column; OQ rows updated with action
   - `vault.json` — append changelog: `{ "event": "resolve-oq-binding", "at": "<iso>", "summary": "N conflicts resolved, M OQs resolved" }`

5. **Hand-off.** After the loop completes:
   - If any DEFER chosen → suggest `/mega-sdd:bind-codebase` re-run (deferred CONFLICTs become OQs in the next bind pass)
   - If no DEFERs → all conflicts cleared, suggest `/mega-sdd:bind-codebase` re-run (now should produce bound-vault cleanly)

## Hard rails

- **Never auto-resolve conflicts.** Always user choice per row.
- **Never modify code files.** resolve-oq is read-only on the repo; KEEP_VAULT marks the conflict but does NOT patch code (that happens in `execute-bolts` later).
- **Cycle protection:** if `--binding` is invoked but binding.md is malformed or empty, halt with a helpful error.
