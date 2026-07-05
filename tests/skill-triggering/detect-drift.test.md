# detect-drift Trigger + Behavior Test

Manual-run fixture for `detect-drift` skill.

## Trigger cases

### DD1: Explicit slash command
- **Prompt:** `/mega-sdd:detect-drift`
- **Expect:** Skill invocation; reads `./vault.json` or auto-detects vault dir

### DD2: Natural English
- **Prompt:** `check code vs vault for drift`
- **Expect:** Skill invocation

### DD3: Natural Indonesian
- **Prompt:** `cek code vs vault`
- **Expect:** Skill invocation

### DD4: Auto-route from orchestrate-flow (post-bolt)
- **Setup:** vault exists with mode=existing, bolts/ dir has reports, no recent DRIFT-REPORT.md
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes detect-drift as next step

## Behavior checks

### B1: Mode requirement
- **Setup:** vault.json has `mode: new`
- **Expect:** halt with mode-migration prompt — detect-drift only runs against `mode=existing` vaults

### B2: Output presence
- After invocation against a valid mode=existing vault: `DRIFT-REPORT.md` exists in vault root.

### B3: Confidence-rated findings
- DRIFT-REPORT.md must categorize findings with confidence levels (high/medium/low).
- Each finding cites both the vault claim AND the code evidence (file:line).

### B4: No silent skip
- Even when zero drift detected, DRIFT-REPORT.md is produced with "No drift detected" summary.
- Skill never returns nothing — always writes a report.

### B5: Non-interactive queue (forked, v3.0.0)
- detect-drift is `context: fork` + non-interactive: it NEVER calls `AskUserQuestion` and offers NO walkthrough.
- Every finding needing a direction call is **queued to `<vault>/PENDING-SYNC.md`**; a human resolves later via `/mega-sdd:sync` or `resolve-oq`.
- Only the narrow `--auto-apply=safe` class (HIGH + name/type/missing-in-vault + not `[LOCKED]` + code committed) is written back inline.

### B6: Handoff routing — sync lane vs standalone (NEVER resolve-oq for drift)
- **Sync lane** (invoked by orchestrate-flow Mode D with the changed-paths scope file, e.g. `--scope=@<vault>/.sync-changed-paths.txt`): the emitted handoff `next_action.suggested_skill` MUST be `mega-sdd:bind-codebase` with `suggested_args` containing `--paths=@<vault>/.sync-changed-paths.txt` — CONTINUE the Mode D chain into claim-scoped re-bind (spec §3.3).
- **Standalone** (no changed-paths scope file — full scan, a drift-axis `--scope=schema-only`, or a bare `--scope=<id>` post-bolt gate): the emitted handoff `next_action` MUST be `null` (the report + `PENDING-SYNC.md` ARE the deliverable).
- In NEITHER case may `next_action.suggested_skill` be `mega-sdd:resolve-oq` — resolve-oq has no drift-consumption mode; routing drift there is a silent no-op that falsely claims a reconcile step ran.

### B7: Report carries no invented resolution command
- `DRIFT-REPORT.md` (and every per-finding "Resolution path") MUST NOT reference `/mega-sdd:resolve-oq --drift <id>` — that mode was never defined by the spec.
- Per-finding resolution paths point ONLY to: human triage of `PENDING-SYNC.md`, `/mega-sdd:sync`, or `--auto-apply=safe` (never on a CRITICAL/`[LOCKED]` finding).

### B8: Sync-lane INPUT scope channel — reads `@file`, never self-resolves (forked)
- **Setup:** Mode D sync lane. `scan-codebase --changed-only` has ALREADY run: `<vault>/.sync-changed-paths.txt` holds the resolved changed set (one path per line), the dirty journal is consumed (rotate-and-delete), and `last_scanned_commit == HEAD`. detect-drift is invoked with `--scope=@<vault>/.sync-changed-paths.txt`.
- **Expect:** detect-drift READS the `@`-prefixed value as a path-list file and scopes the scan to EXACTLY those paths (`Scope hint received: changed-paths(N)`).
- **Expect:** it does NOT re-resolve the changed set from the dirty journal ∪ `git diff <stamp>..HEAD` (both empty post-scan — a full scan would result) and does NOT auto-discover `.sync-changed-paths.txt` from the vault; it uses the file ONLY because `--scope=@<path>` pointed at it (spec §3.2/§3.7).

### B9: Non-sync `@file` scope → STANDALONE (basename discriminator, NOT "any @file")
- **Setup:** A standalone run — NOT the Mode D sync lane: `/mega-sdd:detect-drift --vault=./v --code=./r --scope=@custom.txt`, a documented-valid `@file` path-list scope whose basename (`custom.txt`) ≠ `.sync-changed-paths.txt`. The file `custom.txt` exists and is a real hand-authored path list.
- **Expect:** detect-drift READS `custom.txt` as a path-list file and scopes the scan to exactly those paths (`Scope hint received: changed-paths(N)`, same INPUT channel as B8) — the `@file` still works as a scope.
- **Expect (routing):** because the resolved `--scope` basename ≠ `.sync-changed-paths.txt`, the run is classified **standalone**: the emitted handoff `next_action` MUST be `null` (the `DRIFT-REPORT.md` + `PENDING-SYNC.md` ARE the deliverable).
- **Expect (regression guard — the discriminator is what's under test):** `next_action.suggested_skill` MUST NOT be `mega-sdd:bind-codebase`. If this ever regressed to the loose "any `@file` → sync" rule it would emit `bind-codebase --paths=@<vault>/.sync-changed-paths.txt` — a hardcoded scan of a file no standalone run ever wrote. Sync lane is entered ONLY when the resolved `--scope` `@file` basename == `.sync-changed-paths.txt`, and its `--paths` echoes the ACTUAL scanned scope file, never a hardcoded literal.

## Pass criteria

All trigger cases (DD1-DD4) invoke the skill. Behavior checks confirm: mode gate enforced (B1); output always present (B2, B4) and confidence-rated (B3); forked/non-interactive queue to `PENDING-SYNC.md`, no walkthrough (B5); handoff routes sync-lane → `bind-codebase --paths=@<vault>/.sync-changed-paths.txt` and standalone → `null`, and NEVER to `resolve-oq` for drift (B6); the report contains no invented `resolve-oq --drift` command (B7); the sync-lane INPUT scope arrives via `--scope=@<vault>/.sync-changed-paths.txt` (read as a path list), never self-resolved from the already-consumed journal/git and never auto-discovered (B8); and the sync-vs-standalone discriminator is a deterministic **basename check** — a non-sync `@file` scope (basename ≠ `.sync-changed-paths.txt`) is still read for scoping but classified STANDALONE → `next_action: null`, never a `bind-codebase --paths` hand-off (B9).
