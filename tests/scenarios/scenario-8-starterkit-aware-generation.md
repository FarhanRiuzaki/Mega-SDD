# Scenario 8 — Starterkit-Aware Generation (framework pack)

**Time**: ~30 min
**When to use**: Validate that the guarded pipeline recognises a Laravel starterkit and carries its conventions to every bolt: GROUND matches the framework pack from the manifest, `plan` types units against the existing code, `execute-bolts` puts the pack slices into each dispatch prompt, and the pack-driven gates hold the generated code to the pack.

> **What changed in 9.0.** The deep-scan starterkit derivation is gone (spec `docs/superpowers/specs/2026-09-27-v9-simplification-design.md` §7 decision #1): nothing writes `.mega-sdd/codebase/starterkit-context.yaml` or `reuse-index.yaml` any more, and `plan` writes no `starterkit_context_consumed` / `starterkit_relevance` fields and no starterkit-cited Hard Rules. What reaches the bolt is the framework-pack chain, matched from the manifest by GROUND (a script, seconds — no scan phase). A pre-9.0 `starterkit-context.yaml` left on disk is still read by the dispatch builder (`plugins/mega-sdd/skills/execute-bolts/references/starterkit-enrichment.md`): its `patterns` slice reaches any unit whose `target_files` match a pattern location, while the auth / authz / UI / libs slices need `starterkit_relevance`, which `plan` never writes.
>
> This scenario checks plumbing — what reaches the bolt and which gate reads the pack — not a quality edge. No benchmark showed the guarded pipeline writing better code than the direct/assisted lanes, which build in the main session from the repo's own conventions (spec §1).

## Prerequisites

- Laravel starterkit project at `<project_root>` (a git repo) with:
  - `composer.json` requires `laravel/framework` → the `laravel` pack. The base-laravel-26 starterkit also carries `pixinvent/vuexy-laravel-bootstrap-jetstream` (or `joelbutcher/socialstream`) → the more specific `laravel-base-26` pack wins (`detection_priority: 10` vs 100)
  - `resources/views/layouts/app.blade.php` exists
  - `resources/js/app.js` imports SweetAlert2 and uses `document.addEventListener('DOMContentLoaded', ...)`
  - `app/Models/User.php` uses `HasRoles` trait (Spatie/permission)
  - `database/seeders/RoleSeeder.php` creates `admin` and `user` roles
- PRD at `<project_root>/prd.md` describing "User management feature with CRUD views"
- mega-sdd plugin 9.0+ installed; `ast-grep` on PATH (`/mega-sdd:install-deps`) so GROUND can build the symbol index

## Scenario steps

### Step 1: Verify GROUND matches the framework pack

Both commands only read the repo. On a repo with no `.mega-sdd/` yet they write nothing; once `.mega-sdd/` exists, `derive-state.sh` refreshes `.mega-sdd/state.json` and the resolver its derived cache (`.mega-sdd/.cache/pack-resolver/`):

```bash
bash <plugin>/scripts/derive-state.sh --cwd=. --json-only \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["derived"]["framework_pack"], d["probes"]["framework_pack"]["candidates"])'
bash <plugin>/scripts/_lib/resolve-framework-pack.sh --cwd=.
```

**Assertions (base-laravel-26):**
- `derived.framework_pack` == `laravel-base-26`; candidates list `laravel-base-26(composer.json,p10)` ahead of `laravel(composer.json,p100)`
- The resolver prints the chain `laravel-base-26.md laravel.md _universal.md` (most specific first)
- A plain Laravel app (no starterkit marker) resolves `laravel` → chain `laravel.md _universal.md`

### Step 2: Run the guarded pipeline

```
/mega-sdd ./prd.md --guarded
```

The repo carries code, so without `--guarded` the router picks the assisted lane (`existing_code`): the main session builds the feature from the repo's own `CLAUDE.md` / `AGENTS.md` / existing code, with no dispatch prompt and no pack slices to inspect. `--guarded` runs GROUND (state digest + symbol index) → `plan ./prd.md --lite --mode=existing` → `execute-bolts --all --lite`.

### Step 3: Verify `plan` typed the units against the existing code

```bash
ls .mega-sdd/vaults/*/units/
grep -l "task_type: extend\|task_type: verify" .mega-sdd/vaults/*/units/U-*.md
grep -A3 "^## Anchors" .mega-sdd/vaults/*/units/U-*.md | head
grep -l "starterkit_context_consumed\|starterkit_relevance" .mega-sdd/vaults/*/units/U-*.md   # expect: no output
```

**Assertions:**
- ≥1 unit file exists in `units/`
- A unit that touches an existing starterkit symbol (e.g. `app/Models/User.php`) is typed `extend` or `verify` from a symbol-index hit, with `## Anchors` (`file:line`) and `## Claims` — claims are contracts; the verdict is written at dispatch, never in the unit
- No unit carries `starterkit_context_consumed` / `starterkit_relevance`, and no Hard Rule cites `starterkit-context.yaml`
- No pack rule is copied into a unit's `## Hard rules` (`plan/references/validation-passes.md` §12.4.5: pack rules reach the bolt as the advisory dispatch slice, never a B1 post-flight obligation)

### Step 4: Verify execute-bolts injected the pack slices

```bash
grep -l "^FRAMEWORK: laravel-base-26" .mega-sdd/vaults/*/bolts/U-*/dispatch-prompt.md
grep -l "## Framework pack rules (filtered by your target_files glob match)" .mega-sdd/vaults/*/bolts/U-*/dispatch-prompt.md
grep -l "## Code style (from laravel-base-26" .mega-sdd/vaults/*/bolts/U-*/dispatch-prompt.md
grep -A4 "DO NOT WRITE:" .mega-sdd/vaults/*/bolts/U-*/dispatch-prompt.md | head
```

**Assertions:**
- Every dispatch prompt names the active pack (`FRAMEWORK: laravel-base-26`, or `SCOPE: … — framework: …` on a scoped vault)
- A controller unit's prompt carries `## Framework pack rules` with the `## Hard Rules emitted` entries whose `path_glob` matches its `target_files` — e.g. "Controllers MUST extend BaseController" (`laravel-base-26.md`) and the `Controller` suffix rule (`laravel.md`), each citing its pack and the matched glob
- `## Code style` comes from the most specific pack that has one (`laravel-base-26.md`)
- `DO NOT WRITE:` lists the chain's `## Forbidden patterns`, each with its source pack — e.g. `$(document).ready(...)` and native `alert(...)` / `confirm(...)` (`laravel-base-26.md`)

A section with no matching input is omitted, never padded: a unit whose `target_files` match no pack `path_glob` has no `## Framework pack rules` section.

### Step 5: Verify generated code matches starterkit patterns

For a UI-CRUD bolt (e.g., user-management feature):

```bash
grep "@extends('layouts.app')" resources/views/users/index.blade.php
grep "Swal.fire" resources/js/users.js
grep "middleware('permission:" routes/web.php
grep "document.addEventListener('DOMContentLoaded'" resources/js/users.js
```

**Assertions:**
- Generated Blade view uses `@extends('layouts.app')` (the pack's `layout-extends` required element)
- Generated JS uses `Swal.fire(...)` for confirmations, never native `alert`/`confirm` (pack forbidden pattern; inside a Blade view also the `native-alert` scaffold tell)
- Generated management routes use Spatie permission middleware (e.g., `middleware('permission:users.view')` — the `laravel-base-26.md` route rule; inline role checks are a pack forbidden pattern)
- Generated JS uses `document.addEventListener('DOMContentLoaded', ...)` (pack forbidden pattern: `$(document).ready`)

### Step 6: Verify the pack-driven gates read the same chain

```bash
cat .mega-sdd/.ui-quality-blockers.json
```

**Assertions:**
- `validate-ui-quality.sh` read the merged `## UI quality signatures` of the chain (`laravel.md` scaffold tells + `laravel-base-26.md` required elements `layout-extends` / `responsive`) and recorded no violation for the generated views
- A view with a scaffold tell (a `Customer Id` label, a raw `*_id` echo, unformatted money, native `alert(`) or a non-trivial view missing the layout extend / responsive grid blocks the next `execute-bolts` until it is fixed (the state is re-derived at the execute-bolts PreToolUse gate)
- The other pack-driven gates resolve the same chain: flow coverage (`## Flow-artifact derivation`) and sibling consistency (`## Cross-cutting concerns`)

## Pass criteria

ALL of:
- GROUND matches `laravel-base-26` (or `laravel`) from `composer.json`; the resolver chain is printed most-specific first
- No `starterkit-context.yaml` is written; no unit carries starterkit fields
- Brownfield units carry symbol-index `## Anchors` / `## Claims`
- Dispatch prompts carry `FRAMEWORK:`, the glob-matched `## Framework pack rules`, `## Code style`, and `DO NOT WRITE:` from the chain
- Executed bolts produce code using layouts.app + SweetAlert2 + Spatie `permission:` middleware, and the UI-quality gate records no violation
- The run ends with the result contract every lane delivers: the acceptance-criterion → test table, `delivery-check.sh` `VERDICT: PASS` on the final commit, and the assumptions and decisions made

## Failure modes to watch

- Pack resolves to `_universal` despite a Laravel manifest → read `probes.framework_pack.candidates` in the `derive-state.sh --json-only` output: an empty list means no pack's `dependency_marker` matched the manifest
- Dispatch prompt header reads `FRAMEWORK: (pack chain UNRESOLVED — resolver exit <N>; NOT a packless project)` → the resolver failed (e.g. the Windows App-Execution-Alias `python3` stub); the pack slices are missing for that reason, not because the pack is silent (`execute-bolts/references/context-enrichment.md` §Pack-resolver exit codes)
- A generated Blade view uses native `alert(...)` despite the pack → the UI-quality gate blocks the next `execute-bolts` (`native-alert` tell); fix the view, not the gate
- A pre-9.0 `starterkit-context.yaml` that fails to parse → `deep_scan_cache_corrupt` (C1): GROUND renames it aside, the bolt proceeds without that slice

## Field test (real starterkit verification)

Run Step 1 against the user's actual starterkit:

```bash
cd <your-starterkit-repo>
bash <plugin>/scripts/derive-state.sh --cwd=. --json-only | python3 -c 'import json,sys; print(json.load(sys.stdin)["derived"]["framework_pack"])'
bash <plugin>/scripts/_lib/resolve-framework-pack.sh --cwd=. --section="UI quality signatures"
```

Expected outcomes for `laravel-base-26`:
- `framework_pack` == `laravel-base-26`
- The `UI quality signatures` bodies of `laravel-base-26.md` and `laravel.md` print, most specific first (the gate merges their lists)
- A subsequent `/mega-sdd <feature-prd> --guarded` run produces dispatch prompts carrying the base-26 rules (BaseController, UUID migrations, SweetAlert2, DOMContentLoaded) and code that follows them

A starterkit without a plugin pack gets one by authoring a project pack at `<root>/.mega-sdd/packs/<framework>.md` (`extends: laravel` + a `detection_signature`); it beats a same-named plugin pack and is linted by `scripts/validate-pack.sh <pack.md>`.

## Related artifacts

- `docs/superpowers/specs/2026-09-27-v9-simplification-design.md` §7 decisions #1–#2 (why the deep-scan derivation was dropped; pack rules stay an advisory slice)
- `plugins/mega-sdd/references/framework-conventions/laravel-base-26.md` + `laravel.md` (the packs this scenario exercises)
- `plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md` (the dispatch prompt's pack sections: `FRAMEWORK:` header, `DO NOT WRITE:`, priorities 7a/7b)
- `plugins/mega-sdd/skills/execute-bolts/references/starterkit-enrichment.md` (the legacy `starterkit-context.yaml` reader)
- `docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md` + `docs/superpowers/plans/2026-05-24-iter-32-starterkit-aware-deep-scan.md` (the original, pre-9.0 deep-scan design and plan — historical)
