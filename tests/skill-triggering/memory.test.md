# /mega-sdd:memory Trigger + Operations Test

The Iter 5 memory + self-learning skill. Tests operations + scope handling + anti-halu rails.

## Trigger cases

### M1: Explicit list
- **Prompt:** `/mega-sdd:memory list`
- **Expect:** Skill invoked; walks all 3 scopes; outputs table of files + line counts + last-modified

### M2: Show specific topic
- **Prompt:** `/mega-sdd:memory show decisions`
- **Expect:** Cat `<project>/.mega-sdd/memory/decisions.md` with markdown rendering + summary stats footer (entry count, date range, source-run distribution)

### M3: Search across files
- **Prompt:** `/mega-sdd:memory search "auth"`
- **Expect:** Grep across all memory files in default scope; output matched lines with file + line citations; highlight "auth" tokens

### M4: Review pending suggestions
- **Setup:** `~/.mega-sdd/memory/patterns.md` has 3 pending suggestions
- **Prompt:** `/mega-sdd:memory review`
- **Expect:**
  - Walk each pending suggestion via `AskUserQuestion`
  - For each: show pattern, source observations, confidence, suggested action
  - User chooses ACCEPT / REJECT / DEFER per suggestion
  - On ACCEPT: write to `learning-log.md` + update target heuristic file
  - On REJECT: write to `learning-log.md` as rejected; clear from pending
  - On DEFER: increment deferred_count; keep in pending

### M5: Prune stale entries
- **Setup:** Memory has entries older than 180 days
- **Prompt:** `/mega-sdd:memory prune`
- **Expect:** List candidates per file; batch-confirm via `AskUserQuestion`; delete confirmed entries
- **`--dry-run`:** Show what would be pruned without writing

### M6: Promote project → user scope
- **Setup:** `<project>/.mega-sdd/memory/decisions.md` has consistent pattern with ≥2 source observations
- **Prompt:** `/mega-sdd:memory promote conflict-pattern-auth --to=user`
- **Expect:**
  - Verify source entry exists + has enough observations
  - Write to `~/.mega-sdd/memory/patterns.md` with `promoted_from: project`, `promoted_at: <date>`
  - Source entry stays (NOT removed)
  - Log to `learning-log.md`

### M7: Diff since date
- **Prompt:** `/mega-sdd:memory diff --since=2026-05-15`
- **Expect:** Walk memory files; list entries with `created_at >= 2026-05-15`; output per-file change summary

### M8: Export / Import roundtrip
- **Prompt:** `/mega-sdd:memory export /tmp/memory-bundle.tar.gz`
- **Expect:** Tarball with all memory files + manifest (checksums + schema version)
- **Prompt:** `/mega-sdd:memory import /tmp/memory-bundle.tar.gz`
- **Expect:** Verify manifest; migrate schema if needed; present preview via `AskUserQuestion`; on confirm write to target scope

### M9: Clear scope with double-confirm
- **Prompt:** `/mega-sdd:memory clear --scope=user`
- **Expect:**
  - First `AskUserQuestion`: "Clear ALL user memory? <N> files, <M> entries"
  - On first ACCEPT: second prompt asks user to type `CLEAR-user` to confirm
  - On both confirms: delete files; write clear event to learning-log.md (if persists)
- **Negative:** typing wrong confirm token → halt; no deletion

## Anti-halu rails (negative validation)

### AH1: No silent learning
- **Setup:** Pending suggestion in patterns.md
- **Prompt:** any pipeline command (not `/mega-sdd:memory review`)
- **Expect:** Suggestion NOT auto-applied; chat may surface "N suggestions pending; review via `/mega-sdd:memory review`" but heuristics unchanged

### AH2: Source citation on every suggestion
- **Setup:** `mega-sdd:memory review` walks suggestion
- **Expect:** Each suggestion in chat cites source: "per `.mega-sdd/memory/decisions.md` rows 7-11"

### AH3: Rollback path works
- **Setup:** Accepted learning #4 in `learning-log.md`
- **User action:** Edit log entry; add `rolled_back_at: 2026-05-22`
- **Next session:** Mega-sdd reads learning-log.md at session start
- **Expect:** Learning #4 NOT applied; behavior reverts to pre-learning state

### AH4: Current evidence wins over memory
- **Setup:** Memory says "always KEEP_CODE on auth conflicts" (8/10 pattern)
- **Current conflict:** Auth conflict BUT with different semantics (vault wants OAuth2, code uses session — vault has explicit new requirement, not legacy preservation)
- **Expect:** resolve-oq surfaces memory suggestion (KEEP_CODE) but user evaluates current context; user picks KEEP_VAULT freely; outcome NOT biased to wrong direction

### AH5: --memory-off disables both reads + writes
- **Prompt:** `/mega-sdd ./prd.md --memory-off`
- **Expect:** No memory consultation messages; no memory writes after chain
- **Verify:** `~/.mega-sdd/memory/preferences.md` not modified (line count unchanged)

### AH6: Schema mismatch halts cleanly
- **Setup:** Memory file has `memory_schema: 99` (future version)
- **Prompt:** any pipeline command with memory enabled
- **Expect:** Chain halts at start with `memory_schema_mismatch` blocker; user prompted to run migration or skip via `--memory-off`

### AH7: Concurrent runs don't corrupt memory
- **Setup:** 2 mega-sdd pipelines running in parallel on same project (rare but possible)
- **Expect:** Append-only writes work atomically; both runs' entries appear in memory files; no file corruption (per MEMORY-OQ-6)

## Pass criteria

All M1-M9 operations succeed per `skills/memory/SKILL.md` Procedure section. AH1-AH7 negative invariants hold — no silent learning, citations mandatory, rollback works, current evidence wins, --memory-off respected, schema check enforced, concurrent-write tolerant.

---

## Iter 33 — Routing outcomes (v1.3.0+)

### M-RO1 — Routing outcomes append on chain end

**Setup:**
- Fresh project; no `.mega-sdd/memory/routing-outcomes.md`
- Chain executes successfully (status=completed, blockers=[])
- Duration: 8 min; 0 halts

**Trigger:** chain completes; Step 7.5 fires

**Expected:**
- `.mega-sdd/memory/routing-outcomes.md` created with header + first row
- Row format: `<today's date> | <fingerprint> | <chain-used> | 8 | yes | 0`
- File lock acquired + released cleanly (no `memory_in_use` halt)

### M-RO2 — Routing outcomes corrupt: auto-invalidate + chain proceeds

**Setup:**
- `.mega-sdd/memory/routing-outcomes.md` exists but is malformed (e.g., invalid markdown table)

**Trigger:** chain start; Step 2.7 fires

**Expected:**
- Step 2.7 parse fails
- Soft halt `routing_outcome_corrupt` emitted
- File renamed to `routing-outcomes.md.corrupt-<ISO8601>`
- Log message: "routing-outcomes.md corrupt; auto-invalidated; chain proceeds with default routing"
- Chain CONTINUES with routing-rules.md default (soft halt warns; doesn't STOP)
- Step 7.5 creates fresh routing-outcomes.md on chain end
