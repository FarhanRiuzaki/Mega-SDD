# scan-codebase Triggering Test

## Trigger cases

### S1: Explicit
- **Prompt:** `/mega-sdd:scan-codebase`
- **Expect:** Skill invoked, scan begins with CWD

### S2: Natural prompt
- **Prompt:** `siapkan context codebase buat AI dev`
- **Expect:** Skill invoked

### S3: orchestrate-flow auto-route
- **Setup:** CWD has `.git`, no `codebase-map.md`, vault exists
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes scan-codebase as next step

## Behavior checks

### B1: Output presence
- After invocation: `codebase-map.md` exists at `.mega-sdd/codebase/codebase-map.md` (canonical per `references/paths.md`; legacy repo-root only when `.mega-sdd/` absent or `--out` overrides).

### B2: Schema compliance
- Output has all 7 required sections per `codebase-map-schema.md` (§1 structure … §7 framework).
- Frontmatter has `generated_by: mega-sdd:scan-codebase`, `engine`, `precision_tier`, and `last_scanned_commit` (git HEAD; omitted only outside a git repo).

### B3: Anti-hallucination
- Test on a repo with NO routes: section reads "None detected", not invented endpoints.

### B4: Secret-scan gate (Step 10a)
- Seed a fixture file containing a fake credential (e.g., `AKIA` + 16 uppercase alphanumerics) on a line that symbol extraction captures: the written map contains `[REDACTED-SECRET]` instead of the value, a chat warning cites the source `file:line`, and the repo source file is untouched.

## Pass criteria

All triggers fire. Output exists, schema-compliant, no hallucinations. Incremental sync-lane hand-off (SC-INC1/2): on `--changed-only` incremental success with a vault present, scan writes `<vault>/.sync-changed-paths.txt` (the resolved changed set, one path per line) and its handoff scopes detect-drift via `--scope=@<vault>/.sync-changed-paths.txt`; the full-scan fallback writes no scope file, deletes any stale one, and drops the `--scope` flag.

---

## Deep-scan stage cases

### SC-DS1 — Fresh deep-scan: full Laravel starterkit detected

**Setup:**
- Laravel project at `<project_root>`
- `composer.json` `require` includes: `laravel/sanctum`, `spatie/laravel-permission`
- `package.json` `dependencies` includes: `alpinejs`, `tailwindcss`, `sweetalert2`
- No prior `.mega-sdd/codebase/starterkit-context.yaml`

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 10.5.0 trigger check passes (framework confidence ≥ MEDIUM)
- Step 1 surface scan completes; codebase-map.md §7 Framework.confidence == HIGH (≥ 0.8) for Laravel
- Step 10.5.1 cache check: no prior file → cache miss
- Step 10.5.2: 4 subagents (auth/authz/ui-ux/libs) dispatched in PARALLEL (single message, 4 Agent calls)
- Step 10.5.3: 4 YAML responses consolidated → `.mega-sdd/codebase/starterkit-context.yaml` written
- File contents include: `auth.lib: sanctum`, `authz.lib: spatie/permission`, `ui_ux.notification_lib: sweetalert2`, ≥3 libs in libs[]
- Handoff YAML includes `starterkit_context:` block with `reused: false`
- artifacts[] includes both `codebase-map.md` and `starterkit-context.yaml`

### SC-DS2 — Cache reuse on re-scan with unchanged deps

**Setup:** SC-DS1 just ran; `.mega-sdd/codebase/starterkit-context.yaml` exists; `composer.lock` and `package-lock.json` unchanged

**Trigger:** `/mega-sdd:scan-codebase <project_root>` (run again)

**Expected:**
- Step 10.5.1 cache check: prior file exists; lock hashes match → CACHE HIT
- Steps 10.5.2 + 10.5.3 SKIPPED (no subagent dispatch)
- `.mega-sdd/codebase/starterkit-context.yaml` unchanged (mtime preserved or near-preserved)
- Handoff YAML includes `starterkit_context: reused: true`
- Wall-clock for Step 10.5: <2 seconds

### SC-DS3 — Cache invalidation on dep change

**Setup:** SC-DS2 just ran; user then runs `composer require laravel/cashier`; `composer.lock` regenerated with new hash

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 10.5.1: lock hash mismatch → cache invalidated
- Step 10.5.2: 4 subagents re-dispatched
- Step 10.5.3: new `.mega-sdd/codebase/starterkit-context.yaml` written
- Contents: libs[] now includes `laravel/cashier`
- Handoff: `starterkit_context: reused: false`

### SC-DS4 — Pure config repo (no framework detected)

**Setup:** Repo at `<project_root>` has only `.gitignore`, `README.md`, `LICENSE`. No `composer.json`, no `package.json`.

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 1: §7 Framework.confidence == LOW (< 0.5) or framework absent
- Step 10.5.0 trigger check FAILS (confidence below threshold) → Step 10.5 SKIPPED entirely
- Log line emitted: "framework confidence LOW (<value>); deep-scan skipped — install ambiguous, run /mega-sdd:scan-codebase --force-deep to override"
- codebase-map.md WRITTEN normally (without §7 detailed framework block, or with `framework: none`)
- `.mega-sdd/codebase/starterkit-context.yaml` NOT created
- Handoff YAML has NO `starterkit_context:` block
- artifacts[] includes only `codebase-map.md`

### SC-DS5 — Subagent timeout + partial output

**Setup:** Laravel project as SC-DS1; simulate auth-extractor subagent failing twice (e.g., via API timeout simulation or by injecting a malformed prompt fixture)

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 10.5.2: 4 subagents dispatched
- auth-extractor: first attempt fails → auto-retry (single retry per spec §5.1)
- auth-extractor: second attempt also fails → soft halt `deep_scan_subagent_failed` emitted
- Other 3 subagents (authz, ui-ux, libs) succeed
- Step 10.5.3: consolidator emits partial output:
  ```yaml
  starterkit_context:
    schema_version: 3.1
    partial: true
    partial_slices: [auth]
    authz: {...}
    ui_ux: {...}
    libs: [...]
    # auth block ABSENT
  ```
- Pipeline CONTINUES (soft halt is warn-only, NOT chain-stopping)
- Handoff YAML includes `starterkit_context:` block with `partial: true` flag forwarded to consumers

### SC-DS6 — All-fail (API outage simulation)

**Setup:** Laravel project as SC-DS1; simulate ALL 4 subagents failing twice (API outage)

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 10.5.2: all 4 subagents fail (after retry)
- Step 10.5.3: hard halt `deep_scan_subagent_all_failed` emitted
- `.mega-sdd/codebase/starterkit-context.yaml` NOT written
- Any pre-existing `.mega-sdd/codebase/starterkit-context.yaml` preserved untouched
- Status: halted; chain STOPS (orchestrator does not auto-route to generate-intent)
- Handoff YAML: `status: halted`, `blockers: [{ type: deep_scan_subagent_all_failed, ... }]`
- User-facing message: "All 4 deep-scan subagents failed (likely API outage). Re-run /mega-sdd:scan-codebase later."

---

## Incremental / sync-lane scope hand-off (Mode D, spec §3.2/§3.3/§3.7)

### SC-INC1 — `--changed-only` writes the durable changed set + scopes detect-drift

**Setup:**
- Prior `codebase-map.md` exists with a `last_scanned_commit` stamp that is an ancestor of HEAD
- A vault exists (`mode=existing`) — this is the Mode D sync lane
- Two source files changed since the stamp (git delta) and/or appear in `.mega-sdd/codebase/.dirty-paths.jsonl`; churn < 40% (incremental, NOT the full-scan fallback)

**Trigger:** `/mega-sdd:scan-codebase --changed-only`

**Expected (FAILS pre-fix on BOTH assertions):**
- `<vault>/.sync-changed-paths.txt` is written, containing EXACTLY the resolved changed paths (post-exclusion), one repo-relative path per line — the same set scan re-extracted (per `scan-procedure.md §Incremental step 5`). Pre-fix: no such file is ever written.
- Handoff `next_action.suggested_skill == mega-sdd:detect-drift` AND `suggested_args` CONTAINS `--scope=@<vault>/.sync-changed-paths.txt` (plus `--auto`). Pre-fix: `suggested_args` was bare `--auto`, so the forked detect-drift would full-scan — the journal is already consumed and the stamp advanced, so it cannot self-resolve the changed set.
- `artifacts[]` includes `<vault>/.sync-changed-paths.txt`.

### SC-INC2 — full-scan fallback SKIPS scoped drift and continues Mode D to a FULL re-bind

**Setup:** `--changed-only` invoked but a step-2 fallback precondition holds (no `last_scanned_commit` stamp / git delta channel unavailable / churn > 40%); a stale `<vault>/.sync-changed-paths.txt` from a prior run is present; a vault + prior `binding.md` exist (this is the Mode D sync lane — `orchestrate-flow --sync` forces the chain).

**Trigger:** `/mega-sdd:scan-codebase --changed-only`

**Expected (FAILS pre-fix on the `next_action` assertion):**
- Scan falls back to a full scan (one-line note).
- The stale `<vault>/.sync-changed-paths.txt` is DELETED (`rm -f`) — a full scan has no changed set; a leftover file must not wrongly scope a downstream `--scope=@file`.
- Handoff `next_action.suggested_skill == mega-sdd:bind-codebase` with `suggested_args` containing `--auto` (a FULL re-bind — no `--paths`, no changed set to scope). detect-drift is SKIPPED on this branch, exactly as the cold brownfield path (`scan → bind`) skips it on a from-scratch map.
- **Pre-fix (the confirmed B6 bug):** `next_action` handed off `mega-sdd:detect-drift --auto` with `--scope` dropped. But detect-drift infers sync-lane membership ONLY from a `--scope=@file`, so with no scope it self-classified as STANDALONE, emitted `next_action: null`, and the orchestrator treated null as terminal — truncating the forced Mode D chain BEFORE the re-bind and leaving `binding.md`/units/bolts stale vs the freshly re-scanned code (the highest-divergence case). Grounding: spec §3.8(b)(1); `scan-procedure.md §Incremental step 5`; `halts-flags-handoff.md §Hand-off`.

---

## Iter 33 — Predictive checks (consumed by orchestrate-flow Step 3.5)

### SC-PH1 — ast_engine_present predictive check entry

**Setup:** N/A — this is a documentation test verifying scan-codebase catalog entry exists in `predictive-checks.md`

**Verify:**
- Grep `references/predictive-checks.md` for `## scan-codebase preflight checks` section
- Confirm `check_id: ast_engine_present` entry present (fires only when tree-sitter AND ast-grep are BOTH absent; ts-absent-but-ast-grep-present is the softer `tree_sitter_present` WARN from validate-preflight.sh)
- Confirm command, expected, on_fail, fatal=no, predicts_halt=dep_missing
- Confirm catalog entry matches behavior in scan-codebase SKILL.md Step 0 engine detection (consistent message + install hint)
