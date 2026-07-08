# Memory Layer — Pointer Slices, Emission-Time Writes

When memory is enabled (default; opt-out via `--memory-off`), the orchestrator does the chain's ONE memory read at chain start — the rows enter the session context there and stay available to every in-session sub-skill. Handoffs carry **pointers, not row text** (M-16): `metadata.memory_context` is a pointer slice (file path + row keys + one-line digest), and skills append their own rows via `scripts/memory-write.sh` at emission time, reporting only a write receipt (`files_written` path list + `rows_appended` count) in `metadata.memory_writes`. Row content transits chat ONCE (the chain-start read) instead of 2–3×.

## Contents

- [Chain start (single memory read)](#chain-start-single-memory-read)
- [Per-phase invocation](#per-phase-invocation)
- [Per-phase writes (emission-time)](#per-phase-writes-emission-time)
- [Chain end](#chain-end)
- [Mode D (sync) memory](#mode-d-sync-memory)
- [Anti-halu rails](#anti-halu-rails)

## Chain start (single memory read)

Before invoking the first skill in `--deep` mode:

1. If a scope `_index.md` exists, consult it FIRST and open only the files the chain needs (just-in-time; a stale index is a hint, never the data — when in doubt, read the file)
2. Read user-scope: `~/.mega-sdd/memory/preferences.md` + `~/.mega-sdd/memory/patterns.md`
3. Read project-scope: `<cwd-project>/.mega-sdd/memory/decisions.md` + `conventions.md` + `outcomes.md`
4. Read vault-scope (if vault detected): `<vault>/.memory/classifier-accuracy.json` + `bind-history.md` + `bolt-outcomes.json` (+ `drift-history.md` when the chain includes detect-drift)
5. Verify all `memory_schema` versions match expected; halt with `memory_schema_mismatch` blocker if any differ
6. Build per-skill **pointer slices**: per relevant row — file path + row keys (`date` + `oq-id`/`conflict-id`/rule-id tuples; memory rows have no ordinal IDs) + a one-line digest. NO row text — the rows are already in session context from this read.
7. Surface chain history in confirmation: "Past 3 runs: 2 completed, 1 halted on bind_conflict. Continue?"

## Per-phase invocation

When invoking each skill via the Skill tool:

1. Pass that skill's **pointer slice** via handoff YAML `metadata.memory_context` field (per the handoff-contract reference `§Memory layer integration`, indexed in SKILL.md §Specialist references)
2. Skill consults the row text already in session context (the chain-start read). When the pointed rows are NOT in context — a fresh/resumed session, or any forked skill (no conversation history) — it does a **targeted Read of the pointed file/rows**. Never guess a row's content from its digest.

## Per-phase writes (emission-time)

Skills append their own rows at emission time — the orchestrator no longer replays row content into a second append call:

1. The skill composes its row(s) per `memory/references/memory-schema.md` and appends via `bash <plugin>/scripts/memory-write.sh --file=<resolved-path> --scope=<user|project|vault> --cwd=<project-root>` (content via `--content` or stdin). The script secret-scans the content itself (`[REDACTED-SECRET]` redaction — memory files can be git-tracked), acquires the advisory lock, and appends atomically.
2. **Path resolution is the skill's job**: `--scope` is informational; resolve the absolute target per scope rules (user `~/.mega-sdd/memory/`, project `<project-root>/.mega-sdd/memory/`, vault `<vault>/.memory/`) before calling. Pass `--cwd` so lock-failure telemetry lands at the canonical root.
3. The handoff carries only a **write receipt**: `metadata.memory_writes: {files_written: [<paths>], rows_appended: <int>}` — the path LIST (not a bare count) is what the chain-end pass and `_index.md` regeneration key off.
4. `memory-write.sh` exit ≠ 0 → the skill logs it and CONTINUES (memory is optional; a lock contention or scan hiccup is never a chain halt) — report the failure in the receipt by omitting the failed path.
5. The orchestrator logs one line per `files_written` entry to chain progress chat.

## Chain end

After the last skill completes:

1. **Step 7.6 — extract-learnings (the owned threshold pass).** Identify the rows touched this chain from the union of the handoffs' `memory_writes.files_written` path lists, and do TARGETED reads of those files (the receipt carries paths, not content — this is why `files_written` must be a list). Then run the `memory/references/learning-rules.md §1` threshold pass ONCE over those rows (per-pattern: classifier overrides, CONFLICT resolutions, Hard-Rule reverts, recommendation rejects, conventions, flags, drift directions, sync write-back classes, concern recurrences). Each threshold-crossing candidate is APPENDED to the user-scope `patterns.md` `## Pending suggestions` with `status: pending` + source citations. Nothing is applied — `/mega-sdd:memory review` remains the only pending → applied path. No skill evaluates thresholds mid-chain.
2. Regenerate each touched scope's `_index.md` (per `memory/references/memory-schema.md §8.5`) — touched scopes derive from the `files_written` paths (user `~/.mega-sdd/`, project `.mega-sdd/memory/`, vault `<vault>/.memory/`): per file — row count, last-entry date, one-line current-state summary, pending-suggestion count, size flag (> 256 KB → `prune?` suggestion; never auto-prune)
3. Final memory summary in chat: "Chain wrote N memory entries across scopes: user (X), project (Y), vault (Z)" — N from summing `rows_appended`, the scope split from the `files_written` paths
4. If pending suggestions accumulated (≥1 threshold crossed): announce "Mega-SDD has N pending learning suggestions. Review via `/mega-sdd:memory review`"

## Mode D (sync) memory

Each `--sync` run appends ONE `kind: sync` row to project-scope `outcomes.md` (schema: `memory/references/memory-schema.md §outcomes`): trigger channel mix (journal/git), per-phase outcome counts, applied-vs-queued patch tally, `--auto-apply=safe` accept/reject tally, closing staleness. This is what makes the §2.8 learning pattern (suggest defaulting `--auto-apply=safe` after 3 consistently-ACCEPTed runs) observable — the suggestion itself fires only at the Step 7.6 pass and applies only on explicit ACCEPT.

## Anti-halu rails

- Memory schema mismatch HALTS the chain (cannot continue with mixed schemas)
- Memory I/O failures (disk, perm) logged but do NOT halt (graceful degradation)
- Suggestions surfaced at chain end; NEVER auto-applied
- `--memory-off` propagates to all sub-skills automatically (passed as a flag in handoff invocation args)

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: handoff-contract (`§Memory layer integration` — the pointer-slice `metadata.memory_context` schema + the `metadata.memory_writes` write-receipt shape) and chain-execution (where the chain-start read and end-of-chain routing-outcomes write sit in the execution flow).
