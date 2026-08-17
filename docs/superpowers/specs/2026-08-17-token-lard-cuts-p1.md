# Token-lard cuts — P1: honest measurement + hygiene (v6.13.0)

**Status:** SHIPPED v6.13.0 (2026-08-17, 51dc36e, CI green, both-tree suite 273/273). Round: 1 MAJOR (collateral ref orphan) + 3 MINOR folded; suite additionally caught the P6 refs pin live (`${CLAUDE_PLUGIN_ROOT}` in the new ref) + the usability test's location assumption (amended to the SKILL ∪ ref union, mutation controls all firing).
**Source:** live audit 2026-08-17 (chat) over 27,507 telemetry rows / 27 sessions + measured file sizes; executes the user's mandate "audit apalagi yg bisa dipangkas… token use lebih kecil" with the moat-takeout amendment honored (evidence per item, proposal-first for anything with a defect-catch record).
**Scope:** P1 only. P2a (halt-protocol family split) and P2b (hot-SKILL byte diet) are follow-up releases gated on this one's measurement being live. No gate, no moat state, no chain behavior changes.

## Why P1 first

The audit's two biggest levers (P2a/P2b) cut *bytes loaded per run*. But today's `ref_loaded` telemetry logs the **full file size regardless of the actual Read range** (`emit_ref_loaded` does `wc -c` on the path — hooks/post-tool-use), so a §-scoped Read of a 41KB contract logs 41KB. We cannot prove (or later, disprove) that §-reads are happening, and every post-cut "saved X tokens" claim would be unfalsifiable. Fix the ruler before cutting.

Secondary hygiene with evidence:
- telemetry.jsonl grows unbounded — 27.5k rows live now, 9.8k of them `halt_self_resolved` PASS probes; consumers only ever aggregate recent activity.
- `install-deps/SKILL.md` = 25.7KB for a maintenance one-timer (bigger than bind-codebase's body), loaded 153× in the telemetry window; its §Step 2 alone is 7.8KB of tool-matrix walk detail that belongs in a reference.

## D1 — `ref_loaded` records the actual read range

**Change (hooks/post-tool-use):**
1. The stdin parser's `Read` branch additionally emits `READ_OFFSET` / `READ_LIMIT` from `tool_input.offset` / `tool_input.limit` (empty string when absent). Values pass through the existing `shlex.quote` `emit()` — no new unquoted field (the eval-boundary law).
2. `emit_ref_loaded` gains two optional trailing args (offset, limit — empty = full read) and the payload gains three **additive** fields:
   - `read_offset`: int or null
   - `read_limit`: int or null
   - `est_read_tokens`: when `limit` present AND file `lines > 0` → `bytes * min(limit, lines) / lines / 4` (line-proportional estimate, integer); else equal to `estimated_tokens` (full-file).
3. `estimated_tokens`, `bytes`, `lines` keep their exact current meaning (full-file) — **no consumer breaks**: `report-token-cost.sh` aggregates only `usage`-bearing marker events (verified 2026-08-17); nothing reads `estimated_tokens` programmatically today, but keeping it stable costs one field.
4. Bash-detected loads (`cat|head|tail|…`) stay full-file (`read_offset`/`read_limit` null): parsing head/tail ranges out of arbitrary shell text is the exact input-boundary hazard class we've been burned by ([[hook-input-boundary-hazards]]); the Read tool is where §-discipline lives anyway.

**Honest limitation (recorded):** proportional-by-lines is an estimate — long-line files skew it. Good enough to separate "§-read (~1–3k tok)" from "full load (~10k tok)", which is the only question P2 needs answered.

## D2 — telemetry rotation (one generation)

**Change (hooks/session-start):** immediately after `TELEMETRY_FILE` is resolved inside the existing `GUARD_ENABLED` block: if the file exists AND `wc -l` > **20000**, `mv telemetry.jsonl telemetry.jsonl.1` (clobbering any older `.1`) and start fresh. One generation of history survives; nothing is silently deleted the first time.

- Placement rationale: once per session, not per event (the append path in post-tool-use must stay O(1) — no `wc -l` per tool call).
- Opt-out users (`telemetry: false`) never reach the block — they also never grow the file.
- Consumers: `report-token-cost.sh` / analyze aggregate read `telemetry.jsonl` only → post-rotation they report the current window; the `.1` file remains for manual archaeology. Cost-report semantics ("this run / recent activity") unaffected.

## D3 — install-deps SKILL diet

**Change:** move the two fat walk-through blocks out of `skills/install-deps/SKILL.md` into a new `references/audit-and-verify.md` (routed from SKILL.md, one level deep):
- §Step 2 "Audit tool inventory" detail (≈7.8KB) → SKILL keeps the step heading + a 3–5 line router (what the step does, run/read pointers).
- §Step 6 "Verify (post-install)" detail (≈3.3KB) → same treatment.

**Invariants:**
- §"Playwright browser (detect-and-offer)" stays in the body **verbatim** — pinned by `tests/playwright-embed` arms D1–D3.
- All trigger keywords in `description:` unchanged; frontmatter untouched except `version:` bump.
- Body cap **≤ 19,000 bytes** (achieved: 18,378 from 25,749 — −29%). The original ≤15KB target was NOT met and is amended here on the record: the remaining sections (Playwright pin, Step-4 keterangan UX, the operative handoff template, halt registry rows) are pinned or operative — cutting them trades correctness for bytes, which this spec refuses. The routers keep the sharpest verdict rules inline (124/137/127 never `missing`/`unverified`) so a model that skips the ref still cannot produce the false-`missing` bug.
- No orphan refs: the new file must be reachable from SKILL.md (the [[install-deps-audit-lesson]] structural class).

## Tests (TDD — written first)

New `tests/hooks/telemetry-range.test.sh`:
- a1: Read event with `offset`/`limit` in tool_input → row has `read_offset`/`read_limit` ints + `est_read_tokens` < `estimated_tokens` (proportional).
- a2: Read without range → `read_offset`/`read_limit` null, `est_read_tokens` == `estimated_tokens`.
- a3: Bash `cat` load → null range fields (full).
- a4: `telemetry: false` → no row (existing opt-out intact).
- a5: `limit` larger than the file → `est_read_tokens` == `estimated_tokens` (min-clamp).
- r1: seed a telemetry file with >20000 lines → session-start rotates (`.jsonl.1` exists, fresh file small).
- r2: 10-line file → untouched.
- r3: rotation clobbers an existing `.1` (single generation, no `.2`).

`tests/surface/` (or alongside): install-deps arms — body byte cap (≤15360), Step-2/Step-6 detail present in `references/audit-and-verify.md`, SKILL routes to it, playwright-embed D1–D3 arms still green (run that suite).

## Non-goals
- No halt-protocol split (P2a), no hot-SKILL diets (P2b), no advisor tier/scope change (P3 — user decision pending findings-per-bind data that D1 enables).
- No new telemetry event types; no schema change to existing consumers.

## Ship
v6.13.0 — CHANGELOG entry, plugin.json + marketplace.json parity, install-deps skill `version:` bump, full both-tree suite, CI, spec stamp.
