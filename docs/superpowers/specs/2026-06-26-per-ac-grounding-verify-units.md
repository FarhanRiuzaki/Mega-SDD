# Per-acceptance-criterion source grounding for verify units (A1) — design

**Status:** accepted · **Date:** 2026-06-26 · **Skills:** `generate-units` · **Enforcement:** `scripts/validate-unit-spec.sh` + PreToolUse aggregator

## Problem

`grounding_confidence: HIGH` was defined as *"binding present + all anchors verified + no target collisions + binding state all HIGH-conf"*, where **anchors verified = file exists + line valid** (symbol existence). It never required that each acceptance criterion's *behavior* already exists in source.

A `task_type: verify` unit certifies EXISTING implementation — the bolt skips code generation and only runs the acceptance tests. In the field audit a verify unit was stamped HIGH while several of its LOCKED acceptance criteria (daily-limit, source-of-fund, account-state, pending-state) existed **only in test stubs / the PRD** — the behavior was never built. The unit cited one real source anchor (a `MIN_GRAM` constant), so the unit-level anchor set was *not* all-test. Result: a green verify over **unbuilt** behavior, with nothing to catch it.

The defect is **partial** grounding. A check that classifies the unit's `## Anchors` set as a whole ("are all anchors test files?") structurally cannot see that criterion #3 is ungrounded while criterion #1 is grounded — and so misses the exact incident it would exist to catch. **The unit of measurement is the acceptance criterion, not the anchor-set.**

## Design

### Schema — per-criterion grounding marker (`generate-units/references/unit-schema.md`)

In a verify unit's `## Acceptance criteria`, each criterion may carry a grounding marker:

- `- [grounded: <non-test path>:<line>] <criterion>` — the asserted behavior already exists at a **non-test** source anchor.
- `- [ungrounded] <criterion>` — behavior lives only in a test stub / the PRD / nowhere yet.

A **test-file path is not grounding** (a test can assert behavior that does not exist). Once any criterion carries a marker the unit **opts in** and every criterion must be `[grounded: …]`. Legacy units with no markers at all keep the old symbol-existence semantics (tolerated).

### Generation (`generate-units/references/defensive-generation.md`)

For a verify unit intended to be HIGH, ground each criterion individually before writing: locate the non-test source implementing the behavior → `[grounded: path:line]`; not found → `[ungrounded]`, and the unit is **not** verify+HIGH. The remedy is to **downgrade** `grounding_confidence`, or **split** a `verify` unit (grounded criteria) from a `create`/`extend` unit (ungrounded criteria) — which stops the bolt from skipping code for behavior that was never implemented.

### Enforcement (gate, not prose)

`validate-unit-spec.sh` (PostToolUse on unit Write/Edit → `.unit-spec-state.json`) gains check **1b**: for a `task_type: verify` + `grounding_confidence: HIGH` unit that has opted in, every acceptance criterion must carry a `[grounded: …]` anchor whose path is **non-test** AND resolves (file exists + line ≤ EOF). Any `[ungrounded]`, test-path, missing, or non-resolving criterion → **halt `verify_grounding_untrusted`** listing the offending criteria. The PreToolUse aggregator reads the state and **blocks the next `execute-bolts`** (alongside `render_test_missing`).

**Scope, deliberately bounded:**
- **Block-on-HIGH only.** A MEDIUM/LOW verify unit anchored thinly is honest — not blocked. Only a HIGH stamp with an ungrounded criterion is the false-green.
- **Legacy-tolerant.** A verify unit with no per-AC markers keeps the old semantics — not retro-blocked. Only newly stamped HIGH verify units are held to per-AC grounding.

## Tests (behavioral — exercise the validator, never grep prose)

`tests/verify-grounding/test-verify-grounding.sh` — the discriminator is case 1: a verify+HIGH unit with **one grounded + one ungrounded** criterion MUST flag (a test with only the all-test or all-grounded fixtures would go green against the wrong implementation). Plus: all-grounded → clean; test-only anchor → flag; legacy (no markers) → clean; MEDIUM → clean; non-resolving / line-out-of-range → flag. Wiring: `test-verify-grounding-wired.sh`.

## Out of scope / deferred — the post-bolt backstop

A1 is a **unit-spec-time** gate: it catches the false-HIGH *before* bolts run. It cannot see a stubbed `it.todo()` / pending test that a bolt writes — that lives at *test* time, after code exists. The field incident was empirically caught by the bolts surfacing 66 `it.todo()` stubs, not by the generator. That **post-bolt `it.todo()`/pending-test scan** is the natural backstop to A1 (same lever, different phase) and is tracked in the audit backlog — deferred, not dropped.
