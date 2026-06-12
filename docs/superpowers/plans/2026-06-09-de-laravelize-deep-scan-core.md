# De-Laravelize Deep-Scan Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the deep-scan machinery genuinely tech-stack-agnostic by replacing Laravel paths/constructs/ontology with a neutral `authz` ontology + pack-supplied hints, migrating the three downstream consumers, and proving it with a thin Django pack.

**Architecture:** This is a documentation/schema/prompt refactor of a Claude Code plugin (not app code). The leak is three layers — paths, constructs, and the output ontology (`rbac:{middleware,gates,policies}`) which is consumed structurally downstream. We move Laravel specifics out of the "generic" deep-scan prompts into `laravel.md`, restructure the slice schema to a neutral `auth`/`authz` shape, migrate every repo-wide-grepped consumer, and validate with deterministic bash assertions (the repo's existing test idiom) plus a Django proof-pack.

**Tech Stack:** Markdown skill/reference files, YAML schema blocks, bash test scripts (mirroring `scripts/validate-*.sh` + `tests/moat/*.sh`), `grep`/`rg`.

**Spec:** `docs/superpowers/specs/2026-06-09-de-laravelize-deep-scan-core-design.md`

---

## File Structure

**New test files** (deterministic gates — the per-task contracts):
- `tests/de-laravelize/golden-laravel-tokens.txt` — Laravel token set captured BEFORE refactor (safety net)
- `tests/de-laravelize/test-clean-template.sh` — generic prompts have zero Laravel tokens
- `tests/de-laravelize/test-relocation-coverage.sh` — every golden token now lives in `laravel.md`
- `tests/de-laravelize/test-neutral-schema.sh` — schema has neutral `authz` block + open libs
- `tests/de-laravelize/test-consumer-migration.sh` — 3 consumers read neutral ontology, no old tokens
- `tests/de-laravelize/test-fixtures-migrated.sh` — all `starterkit-context.yaml` fixtures use `authz:`
- `tests/de-laravelize/test-django-pack.sh` — Django pack contract present
- `tests/de-laravelize/run-all.sh` — runs the suite

**Modified:**
- `plugins/mega-sdd/references/starterkit-context-schema.md` — `rbac`→`authz`, open libs (§auth/§rbac blocks, lines 279-330)
- `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` — parameterize auth/rbac(→authz)/ui-ux prompts (lines 62-252)
- `plugins/mega-sdd/references/framework-conventions/_template.md` — 3 new contract sections
- `plugins/mega-sdd/references/framework-conventions/laravel.md` — receive relocated paths/constructs
- `plugins/mega-sdd/references/framework-conventions/_universal.md` — generic cross-stack hints
- `plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md` — ontology-driven (lines 74, 119, 133)
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` (line 201) + `context-enrichment.md` (line 252)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`
- ~25 `tests/fixtures/**/starterkit-context.yaml`
- Version: skill frontmatter (scan-codebase, generate-units, execute-bolts), `plugin.json`, `marketplace.json`

**New plugin content:**
- `plugins/mega-sdd/references/framework-conventions/django.md`
- `plugins/mega-sdd/references/lib-patterns/django/{auth-libs,rbac-libs,ui-libs,generic-libs}.md`
- `tests/fixtures/de-laravelize/django-sample/.mega-sdd/codebase/starterkit-context.yaml` (neutral-shape Django fixture)

---

## Task 1: Golden snapshot + test scaffold (safety net — MUST be first, before any edit)

**Files:**
- Create: `tests/de-laravelize/golden-laravel-tokens.txt`
- Create: `tests/de-laravelize/run-all.sh`

- [ ] **Step 1: Capture the current Laravel token set from the prompts (before any change)**

Run (records the exact Laravel paths/constructs the prompts currently contain):

```bash
mkdir -p tests/de-laravelize
cd plugins/mega-sdd/skills/scan-codebase/references
grep -oE 'app/Http/[A-Za-z/]*|app/Providers/[A-Za-z.]+|resources/views/[A-Za-z/<>.-]*|resources/js/[A-Za-z.]+|resources/css/[A-Za-z.]+|config/(auth|permission|fortify|jetstream)\.php|routes/auth\.php|Gate::define|\$routeMiddleware|\$policies|@extends|@heroicons|@fortawesome|blade-ui-kit|yajra/laravel-datatables[a-z-]*|Kernel\.php|AuthServiceProvider\.php|RoleSeeder|Spatie..Permission' deep-scan-prompts.md | sort -u > "$OLDPWD/tests/de-laravelize/golden-laravel-tokens.txt"
cd "$OLDPWD"
wc -l tests/de-laravelize/golden-laravel-tokens.txt
```

Expected: a non-empty file (~20-30 unique tokens). This is the frozen baseline of "Laravel knowledge that must end up relocated to laravel.md, not lost."

- [ ] **Step 2: Create the suite runner**

```bash
cat > tests/de-laravelize/run-all.sh <<'EOF'
#!/usr/bin/env bash
# Runs the de-laravelize deterministic gate suite. Exit non-zero on any failure.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "=== $(basename "$t") ==="
  bash "$t" || { echo "FAIL: $(basename "$t")"; fail=1; }
done
exit $fail
EOF
chmod +x tests/de-laravelize/run-all.sh
```

- [ ] **Step 3: Commit the baseline**

```bash
git add tests/de-laravelize/golden-laravel-tokens.txt tests/de-laravelize/run-all.sh
git commit -m "test(de-laravelize): freeze Laravel token baseline + suite runner"
```

---

## Task 2: Neutral auth/authz ontology in the schema

**Files:**
- Modify: `plugins/mega-sdd/references/starterkit-context-schema.md:279-308` (§auth + §rbac blocks)
- Test: `tests/de-laravelize/test-neutral-schema.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/de-laravelize/test-neutral-schema.sh <<'EOF'
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/references/starterkit-context-schema.md"
err=0
# Neutral authz block must exist
grep -q '^## §authz block' "$f" || { echo "missing §authz block"; err=1; }
grep -q 'declarations:' "$f" || { echo "missing authz.declarations"; err=1; }
grep -q 'mechanism:' "$f" || { echo "missing mechanism field"; err=1; }
grep -q 'role_source:' "$f" || { echo "missing role_source"; err=1; }
grep -q 'lib_source:' "$f" || { echo "missing lib_source"; err=1; }
# Closed Laravel enums for the auth/authz LIB must be gone (open string now)
grep -qE 'enum: sanctum \| breeze' "$f" && { echo "auth.lib still a closed Laravel enum"; err=1; }
grep -qE 'enum: spatie/permission' "$f" && { echo "authz.lib still a closed Laravel enum"; err=1; }
# The old Laravel-ontology authz fields must be gone from the schema
grep -qE '^\s*gates:' "$f" && { echo "old rbac.gates field still present"; err=1; }
grep -qE '^\s*policies:' "$f" && { echo "old rbac.policies field still present"; err=1; }
exit $err
EOF
chmod +x tests/de-laravelize/test-neutral-schema.sh
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/de-laravelize/test-neutral-schema.sh; echo "exit=$?"`
Expected: prints "missing §authz block" etc., `exit=1`.

- [ ] **Step 3: Replace the §auth + §rbac blocks with neutral ontology**

In `plugins/mega-sdd/references/starterkit-context-schema.md`, replace the entire `## §auth block` and `## §rbac block` sections (lines 279-308) with:

````markdown
## §auth block (authentication — framework-neutral)

```yaml
auth:
  lib: "<open string>"             # e.g. sanctum | django-allauth | passport | next-auth | not_detected (NOT a closed enum)
  lib_version: ""                  # version string or "" if not_detected
  lib_source: "<file:line>"        # evidence proving the lib (required unless not_detected)
  mechanism: session               # session | token | jwt | oauth | builtin | unknown
  user_model: "<FQCN or path or null>"
  entrypoints:                     # login / register / logout handlers
    - { name: "login", _source: "<file:line>" }
  features: []                     # subset of recognized features (email_verification, 2fa, social_login, ...)
  _source: ["<file:line>", ...]    # anti-halu citation
```

## §authz block (authorization — framework-neutral; replaces the old Laravel-shaped `rbac` block)

```yaml
authz:
  lib: "<open string>"             # e.g. spatie/permission | django.contrib.auth | casl | not_detected (open, not an enum)
  lib_source: "<file:line>"        # evidence (required unless not_detected)
  mechanism: middleware            # middleware | decorator | guard | policy | mixin | builtin | unknown
  role_source: model               # model | config | db | enum | unknown — where roles/groups are defined
  declarations:                    # the access-control rules, stack-neutral
    - name: "<role|permission|gate|policy name>"
      kind: role                   # role | permission | gate | policy | group
      applies_to: "<route/controller/view it guards, or null>"
      _source: "<file:line>"
  _source: ["<file:line>", ...]
```
````

- [ ] **Step 4: Run to verify it passes**

Run: `bash tests/de-laravelize/test-neutral-schema.sh; echo "exit=$?"`
Expected: `exit=0` (no output).

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/references/starterkit-context-schema.md tests/de-laravelize/test-neutral-schema.sh
git commit -m "feat(scan): neutral auth/authz ontology in starterkit-context schema"
```

---

## Task 3: Parameterize the authz extractor prompt + relocate Laravel specifics to laravel.md

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md:128-181` (rbac-extractor → authz-extractor)
- Modify: `plugins/mega-sdd/references/framework-conventions/laravel.md` (append `## Deep-scan file hints` + `## Authz mapping`)
- Test: reuses `test-clean-template.sh` (Task 5 creates the full version; this task adds the authz lines first)

- [ ] **Step 1: Append the Laravel hints + authz mapping to laravel.md (relocation target FIRST, so nothing is lost)**

Append to `plugins/mega-sdd/references/framework-conventions/laravel.md`:

````markdown
## Deep-scan file hints

```yaml
authz_hints:
  - config/permission.php
  - app/Models/User.php          # traits
  - app/Http/Middleware/         # role/permission middleware
  - app/Http/Kernel.php          # $routeMiddleware aliases
  - app/Providers/AuthServiceProvider.php   # Gate::define + $policies
  - app/Policies/
  - database/seeders/RoleSeeder.php
auth_hints:
  - config/auth.php
  - routes/auth.php              # Breeze/Fortify
  - routes/web.php
  - app/Http/Middleware/Authenticate.php
  - config/fortify.php
  - config/jetstream.php
ui_hints:
  - resources/views/layouts/
  - resources/views/components/
  - resources/js/app.js
  - resources/css/app.css
  - tailwind.config.js
```

## Authz mapping

- `mechanism`: `middleware` (+ `policy` when policies present)
- `role_source`: `model` (spatie roles table) — or `config` for custom
- Construct → `declarations[].kind`:
  - `Gate::define('<name>', ...)` in `AuthServiceProvider.php` → `{kind: gate, name}`
  - entries of the `$policies` array → `{kind: policy, name}`
  - Spatie roles (RoleSeeder `Role::create(['name'=>...])`) → `{kind: role, name}`
  - `$routeMiddleware` RBAC aliases (role, permission, role_or_permission) → record as `mechanism: middleware` + applies_to on guarded routes

## UI detection

- dominant layout: most-referenced `@extends('layouts.<x>')` across `resources/views/`
- component dir: `resources/views/components/`
- notification call: SweetAlert/Toastr import in `resources/js/app.js` or `notification.blade.php`
- icon lib: `@heroicons/*`/`@fortawesome/*` in package.json or `blade-ui-kit/blade-heroicons` in composer.json
````

- [ ] **Step 2: Rewrite the rbac-extractor prompt as a neutral authz-extractor**

Replace `deep-scan-prompts.md` lines 128-181 (the `## rbac-extractor prompt` block) with:

````markdown
## authz-extractor prompt

```
ROLE: Authorization (access-control) detector for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (rbac-libs.md for this framework)
FILE HINTS: <AUTHZ_FILE_HINTS>          (from pack `## Deep-scan file hints` → authz_hints; or _universal generic)
CONSTRUCT MAP: <AUTHZ_CONSTRUCT_MAP>    (from pack `## Authz mapping`; or _universal generic heuristic)

YOUR JOB:
Detect the authorization library and extract every access-control declaration
into the framework-neutral authz shape. Do NOT assume any specific framework's
constructs — use CONSTRUCT MAP to know what this stack's authz constructs are.

INPUTS TO READ:
1. The package manifest facts in <MANIFEST_FACTS> (authoritative; do NOT re-read manifests)
2. Each path in <AUTHZ_FILE_HINTS>
3. THE CATALOG: <CATALOG_PATH>

DETECTION PROCEDURE:
1. Read catalog + CONSTRUCT MAP. Identify the authz lib (open string; `not_detected` if none).
2. Determine `mechanism` (middleware | decorator | guard | policy | mixin | builtin | unknown) per CONSTRUCT MAP.
3. Determine `role_source` (model | config | db | enum | unknown).
4. For each authz construct named in CONSTRUCT MAP, extract a declaration
   {name, kind, applies_to, _source}. kind ∈ role|permission|gate|policy|group.
5. If a construct is found but unmappable, record best-effort kind + _source; never drop _source.

OUTPUT FORMAT (single YAML block):

```yaml
authz:
  lib: <open string or not_detected>
  lib_source: <file:line or empty>
  mechanism: <enum>
  role_source: <enum>
  declarations:
    - { name: <string>, kind: <role|permission|gate|policy|group>, applies_to: <string or null>, _source: <file:line> }
  _source: [<file:line citations>]
```

CONSTRAINTS:
- READ-ONLY
- Cap response at ~80 lines of YAML
- `lib: not_detected` is valid if no authz lib/construct found — NEVER guess
- `lib` is an OPEN string; for an unrecognized lib emit its real name (do NOT coerce to a fixed enum)
- Every field bound to a citation in _source[]; no declaration without _source
```
````

- [ ] **Step 3: Verify the golden authz tokens are now in laravel.md**

Run:

```bash
for tok in 'Gate::define' '$policies' '$routeMiddleware' 'AuthServiceProvider.php' 'app/Http/Kernel.php' 'RoleSeeder'; do
  grep -qF "$tok" plugins/mega-sdd/references/framework-conventions/laravel.md && echo "OK  $tok" || echo "MISSING $tok"
done
```

Expected: all `OK` (relocated, not lost).

- [ ] **Step 4: Verify the authz prompt no longer contains Laravel constructs**

Run:

```bash
sed -n '/## authz-extractor prompt/,/^## ui-ux-extractor prompt/p' plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md | grep -nE 'Gate::define|\$policies|\$routeMiddleware|app/Http|AuthServiceProvider|RoleSeeder|Spatie' && echo "LEAK FOUND" || echo "CLEAN"
```

Expected: `CLEAN`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md plugins/mega-sdd/references/framework-conventions/laravel.md
git commit -m "feat(scan): neutral authz-extractor prompt; relocate Laravel authz specifics to pack"
```

---

## Task 4: Parameterize the auth extractor prompt

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` (auth-extractor prompt, lines ~62-124)

- [ ] **Step 1: Rewrite the auth-extractor prompt to use hints + construct map**

In the `## auth-extractor prompt` block, replace the hard-coded `INPUTS TO READ` Laravel file list (the `config/auth.php`, `routes/auth.php`, `app/Http/Middleware/Authenticate.php`, `config/fortify.php`, `config/jetstream.php` lines) with:

```
INPUTS TO READ:
1. <MANIFEST_FACTS> (authoritative)
2. Each path in <AUTH_FILE_HINTS>      (from pack `## Deep-scan file hints` → auth_hints; or _universal generic)
3. THE CATALOG: <CATALOG_PATH>
```

And change the OUTPUT FORMAT block to the neutral `auth` shape (open `lib`, add `lib_source`, `mechanism`, `entrypoints[]`, drop `guard`/`routes` Laravel specifics — those map into `mechanism`/`entrypoints`):

```yaml
auth:
  lib: <open string or not_detected>
  lib_version: <string or empty>
  lib_source: <file:line or empty>
  mechanism: <session|token|jwt|oauth|builtin|unknown>
  user_model: <FQCN/path or null>
  entrypoints: [ { name: <login|register|logout>, _source: <file:line> } ]
  features: [<list>]
  _source: [<file:line>]
```

Update the DETECTION PROCEDURE prose to remove the word `guard` and any Laravel filename; phrase generically ("identify the auth library from the catalog + manifest; record its mechanism per CONSTRUCT MAP").

- [ ] **Step 2: Verify no Laravel leak in the auth prompt**

Run:

```bash
sed -n '/## auth-extractor prompt/,/## rbac-extractor prompt\|## authz-extractor prompt/p' plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md | grep -nE 'config/auth\.php|config/fortify|config/jetstream|routes/auth\.php|guard' && echo "LEAK" || echo "CLEAN"
```

Expected: `CLEAN`.

- [ ] **Step 3: Commit**

```bash
git add plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md
git commit -m "feat(scan): parameterize auth-extractor prompt (hints + neutral shape)"
```

---

## Task 5: Parameterize the ui-ux extractor prompt + clean-template + relocation tests

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` (ui-ux-extractor, lines 185-252)
- Test: `tests/de-laravelize/test-clean-template.sh`, `tests/de-laravelize/test-relocation-coverage.sh`

- [ ] **Step 1: Write the two failing tests**

```bash
cat > tests/de-laravelize/test-clean-template.sh <<'EOF'
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md"
# The generic extractor prompts must contain ZERO Laravel tokens.
hits=$(grep -nE 'app/Http|app/Providers|resources/views|resources/js|resources/css|config/(auth|permission|fortify|jetstream)\.php|routes/auth\.php|Gate::define|\$routeMiddleware|\$policies|@extends|@heroicons|@fortawesome|blade|yajra/laravel|Kernel\.php|AuthServiceProvider|RoleSeeder|Spatie..Permission|guard name' "$f")
if [ -n "$hits" ]; then echo "Laravel tokens still in generic prompts:"; echo "$hits"; exit 1; fi
exit 0
EOF
chmod +x tests/de-laravelize/test-clean-template.sh

cat > tests/de-laravelize/test-relocation-coverage.sh <<'EOF'
#!/usr/bin/env bash
set -u
golden="tests/de-laravelize/golden-laravel-tokens.txt"
pack="plugins/mega-sdd/references/framework-conventions/laravel.md"
err=0
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  grep -qF "$tok" "$pack" || { echo "NOT RELOCATED: $tok"; err=1; }
done < "$golden"
exit $err
EOF
chmod +x tests/de-laravelize/test-relocation-coverage.sh
```

- [ ] **Step 2: Run both — verify they fail**

Run: `bash tests/de-laravelize/test-clean-template.sh; echo c=$?; bash tests/de-laravelize/test-relocation-coverage.sh; echo r=$?`
Expected: both print leaks/not-relocated tokens, `c=1`, `r=1` (ui-ux prompt still has `resources/views`, and some golden tokens not yet in laravel.md).

- [ ] **Step 3: Rewrite the ui-ux-extractor prompt to use hints + construct map**

Replace `deep-scan-prompts.md` lines 199-224 (the ui-ux `INPUTS TO READ` + `DETECTION PROCEDURE` Laravel specifics) with hint/construct-driven prose:

```
INPUTS TO READ:
1. <MANIFEST_FACTS> (authoritative)
2. Each path in <UI_FILE_HINTS>        (from pack `## Deep-scan file hints` → ui_hints; or _universal generic)
3. THE CATALOG: <CATALOG_PATH>

DETECTION PROCEDURE:
1. Read catalog + <UI_CONSTRUCT_MAP> (from pack `## UI detection`; or _universal generic).
2. js_framework / css_framework / notification_lib / icon_lib / datatable_lib: detect from <MANIFEST_FACTS> + catalog.
3. layout_extends + layout_file + component_dir: per <UI_CONSTRUCT_MAP> (how this stack declares template inheritance / a component).
4. design_tokens: parse the stack's theme/token source named in <UI_CONSTRUCT_MAP> (if present).
5. idioms: per <UI_CONSTRUCT_MAP> idiom probes, each requiring ≥3 occurrences evidence.
```

(Keep the OUTPUT FORMAT `ui_ux:` block as-is — those fields are already framework-neutral.)

- [ ] **Step 4: Run both tests — verify they pass**

Run: `bash tests/de-laravelize/test-clean-template.sh; echo c=$?; bash tests/de-laravelize/test-relocation-coverage.sh; echo r=$?`
Expected: `c=0`, `r=0`. (If relocation fails for a UI token like `@extends`/`@heroicons`, confirm Task 3 Step 1's `## UI detection` block contains it; add the missing token there.)

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md tests/de-laravelize/test-clean-template.sh tests/de-laravelize/test-relocation-coverage.sh
git commit -m "feat(scan): parameterize ui-ux-extractor; add clean-template + relocation gates"
```

---

## Task 6: Pack contract (`_template.md`) + generic fallback (`_universal.md`)

**Files:**
- Modify: `plugins/mega-sdd/references/framework-conventions/_template.md`
- Modify: `plugins/mega-sdd/references/framework-conventions/_universal.md`

- [ ] **Step 1: Add the three contract sections to `_template.md`**

Append to `_template.md` (documenting the contract every future pack must follow):

````markdown
## Deep-scan file hints   <!-- REQUIRED when the stack has auth/authz/ui -->

```yaml
auth_hints:  [ <paths/globs where authentication config & handlers live> ]
authz_hints: [ <paths/globs where access-control rules live> ]
ui_hints:    [ <paths/globs where layouts/components/tokens live> ]
```

## Authz mapping   <!-- REQUIRED when the stack has authorization -->

- `auth.mechanism`: <session|token|jwt|oauth|builtin>
- `authz.mechanism`: <middleware|decorator|guard|policy|mixin|builtin>
- `authz.role_source`: <model|config|db|enum>
- Construct → `declarations[].kind`: <table mapping THIS stack's authz constructs to role|permission|gate|policy|group>

## UI detection   <!-- REQUIRED when the stack renders server/client UI -->

- template inheritance / dominant layout: <how this stack declares it>
- component: <how this stack declares a component>
- notification call: <how this stack invokes notifications>
````

- [ ] **Step 2: Add generic (non-Laravel) hints to `_universal.md`**

Append to `_universal.md`:

````markdown
## Deep-scan file hints (generic fallback — NOT framework-specific)

```yaml
auth_hints:  [ "**/auth*", "**/login*", "**/session*", "**/*security*", "config/**" ]
authz_hints: [ "**/middleware/**", "**/permission*", "**/policies/**", "**/decorators*", "**/guards/**", "**/rbac*", "**/roles*" ]
ui_hints:    [ "**/templates/**", "**/views/**", "**/components/**", "**/layouts/**", "**/pages/**", "**/static/**", "**/assets/**" ]
```

## Authz mapping (generic heuristic)

- `mechanism`: infer from where rules live — a `middleware/` dir → `middleware`; decorators on handlers → `decorator`; mixin/base classes → `mixin`; else `unknown`.
- Construct → `declarations[].kind`: any named role/group → `role`/`group`; any named permission/ability → `permission`; route/handler guards → record with `applies_to`.

## UI detection (generic heuristic)

- dominant layout: the most-included/extended base template across the UI dir.
- component: the convention used under the components/ dir.
- notification call: a notification lib import in the JS entrypoint, else native flash messages.
````

- [ ] **Step 3: Verify `_universal` hints are not Laravel-shaped**

Run:

```bash
grep -nE 'app/Http|resources/views|blade|Gate::define' plugins/mega-sdd/references/framework-conventions/_universal.md && echo "LEAK" || echo "CLEAN"
```

Expected: `CLEAN`.

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/references/framework-conventions/_template.md plugins/mega-sdd/references/framework-conventions/_universal.md
git commit -m "feat(packs): pack-contract hints/authz-mapping/ui-detection + generic _universal fallback"
```

---

## Task 7: Consumer migration — generate-units / starterkit-derivation.md

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md` (lines 74, 119, 133-138)
- Test: `tests/de-laravelize/test-consumer-migration.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/de-laravelize/test-consumer-migration.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
files=(
  "plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md"
  "plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md"
  "plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md"
  "plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
)
for f in "${files[@]}"; do
  # old Laravel-ontology structural reads must be gone
  if grep -nE 'rbac\.lib *== *"spatie/permission"|rbac\.middleware|rbac\.gates|rbac\.policies|auth\.guard|starterkit_context\.rbac' "$f"; then
    echo "OLD ontology read in $f"; err=1
  fi
done
# starterkit-derivation must now read the neutral ontology
grep -q 'authz\.declarations\|authz\.mechanism' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "starterkit-derivation does not read authz ontology"; err=1; }
# bolt prompt + context-enrichment must inject the neutral Authz line
grep -q 'authz\.mechanism\|authz\.declarations\|Authz:' plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md || { echo "bolt-dispatch missing Authz line"; err=1; }
grep -q 'authz\.mechanism\|authz\.declarations\|Authz:' plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md || { echo "context-enrichment missing Authz line"; err=1; }
exit $err
EOF
chmod +x tests/de-laravelize/test-consumer-migration.sh
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash tests/de-laravelize/test-consumer-migration.sh; echo exit=$?`
Expected: lists old reads in all 4 files, `exit=1`.

- [ ] **Step 3: Migrate starterkit-derivation.md to the neutral ontology**

Apply these exact edits in `plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md`:

- Line 74 `IF starterkit_context.rbac.middleware contains entries:` → `IF starterkit_context.authz.declarations is non-empty:`
- Line 119 Hard Rule `MUST use auth guard '<starterkit_context.auth.guard>' (e.g., sanctum or web)` → `MUST apply authorization via <starterkit_context.authz.mechanism> using the existing declarations (<names from authz.declarations>)`
- Line 133 `IF starterkit_context.rbac.lib == "spatie/permission":` → `IF starterkit_context.authz.declarations has any kind in [role, permission]:`
- Lines 135/138 citations `starterkit-context.yaml §rbac.middleware` / `§rbac.role_model` → `§authz.declarations` / `§authz.role_source`

- [ ] **Step 4: Migrate the execute-bolts injectors (covered fully in Task 8; this step is the starterkit-derivation half)**

Run the consumer test now expecting it to STILL fail on the execute-bolts/handoff files (those are Task 8/9), but PASS the starterkit-derivation assertions:

Run: `grep -nE 'rbac\.|auth\.guard' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md && echo "STILL LEAKS" || echo "DERIVATION CLEAN"`
Expected: `DERIVATION CLEAN`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md tests/de-laravelize/test-consumer-migration.sh
git commit -m "feat(generate-units): starterkit-derivation reads neutral authz ontology"
```

---

## Task 8: Consumer migration — execute-bolts dispatch + context-enrichment

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md:201`
- Modify: `plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md:252`

- [ ] **Step 1: Replace the RBAC injection line in bolt-dispatch-prompt.md**

Line 201 `RBAC: lib=<rbac.lib>, role_model=<rbac.role_model>, middleware=<rbac.middleware joined by ", ">` →
`Authz: lib=<authz.lib>, mechanism=<authz.mechanism>, declarations=<authz.declarations[].name joined by ", ">`

- [ ] **Step 2: Replace the RBAC injection line in context-enrichment.md**

Line 252 `RBAC: lib=<slice.rbac.lib>, role_model=<slice.rbac.role_model>, middleware=<slice.rbac.middleware joined by ", ">` →
`Authz: lib=<slice.authz.lib>, mechanism=<slice.authz.mechanism>, declarations=<slice.authz.declarations[].name joined by ", ">`

- [ ] **Step 3: Run the consumer test (expect handoff-contract still failing)**

Run: `bash tests/de-laravelize/test-consumer-migration.sh; echo exit=$?`
Expected: only `OLD ontology read in .../handoff-contract.md` remains, `exit=1`.

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md
git commit -m "feat(execute-bolts): inject neutral Authz line into bolt dispatch + context slice"
```

---

## Task 9: Consumer migration — orchestrate-flow handoff-contract

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`

- [ ] **Step 1: Find the old shape references**

Run: `grep -nE 'rbac|auth\.guard' plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`
Expected: shows the lines documenting the old `rbac`/`auth.guard` slice shape in the handoff schema.

- [ ] **Step 2: Update the documented handoff shape**

Replace each `rbac:` / `rbac.*` / `auth.guard` reference in the handoff-contract starterkit slice with the neutral shape: `authz: {lib, mechanism, role_source, declarations[]}` and `auth: {lib, mechanism, user_model}`. Keep the surrounding handoff-contract prose intact.

- [ ] **Step 3: Run the full consumer test — verify it passes**

Run: `bash tests/de-laravelize/test-consumer-migration.sh; echo exit=$?`
Expected: `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
git commit -m "feat(orchestrate-flow): handoff contract carries neutral auth/authz shape"
```

---

## Task 10: Django proof-pack + neutral-shape Django fixture

**Files:**
- Create: `plugins/mega-sdd/references/framework-conventions/django.md`
- Create: `plugins/mega-sdd/references/lib-patterns/django/{auth-libs,rbac-libs,ui-libs,generic-libs}.md`
- Create: `tests/fixtures/de-laravelize/django-sample/.mega-sdd/codebase/starterkit-context.yaml`
- Test: `tests/de-laravelize/test-django-pack.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/de-laravelize/test-django-pack.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
p="plugins/mega-sdd/references/framework-conventions/django.md"
[ -f "$p" ] || { echo "missing django.md"; err=1; }
for s in "## Deep-scan file hints" "## Authz mapping" "## UI detection"; do
  grep -qF "$s" "$p" 2>/dev/null || { echo "django.md missing section: $s"; err=1; }
done
# Django authz mapping must reference Django constructs, NOT Laravel
grep -qE 'permission_required|PermissionRequiredMixin|Group|django\.contrib\.auth' "$p" 2>/dev/null || { echo "django.md authz mapping not Django-shaped"; err=1; }
grep -qE 'Gate::define|app/Http|@extends' "$p" 2>/dev/null && { echo "django.md leaks Laravel"; err=1; }
for c in auth-libs rbac-libs ui-libs generic-libs; do
  [ -f "plugins/mega-sdd/references/lib-patterns/django/$c.md" ] || { echo "missing lib-patterns/django/$c.md"; err=1; }
done
# Django fixture must use the neutral shape
fx="tests/fixtures/de-laravelize/django-sample/.mega-sdd/codebase/starterkit-context.yaml"
[ -f "$fx" ] || { echo "missing django fixture"; err=1; }
grep -q 'authz:' "$fx" 2>/dev/null || { echo "django fixture not neutral shape"; err=1; }
grep -qE '^\s*rbac:' "$fx" 2>/dev/null && { echo "django fixture uses old rbac shape"; err=1; }
exit $err
EOF
chmod +x tests/de-laravelize/test-django-pack.sh
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash tests/de-laravelize/test-django-pack.sh; echo exit=$?`
Expected: missing django.md etc., `exit=1`.

- [ ] **Step 3: Create the thin django.md pack**

Create `plugins/mega-sdd/references/framework-conventions/django.md`:

````markdown
---
framework: django
extends: _universal
detection_signature:
  package_manifest: pyproject.toml
  dependency_marker: django
---

# Django Convention Pack (thin proof-pack)

## File location standards
- models: `**/models.py`
- views: `**/views.py`
- urls: `**/urls.py`
- templates: `**/templates/**`
- migrations: `**/migrations/`

## Deep-scan file hints

```yaml
auth_hints:  [ "**/settings.py", "**/urls.py", "**/views.py" ]
authz_hints: [ "**/settings.py", "**/permissions.py", "**/decorators.py", "**/views.py" ]
ui_hints:    [ "**/templates/**", "**/static/**" ]
```

## Authz mapping

- `auth.mechanism`: `session` (Django auth) — `token`/`jwt` if DRF/SimpleJWT present
- `authz.mechanism`: `decorator` (+ `mixin`, `builtin`)
- `authz.role_source`: `db` (`auth.Group`)
- Construct → `declarations[].kind`:
  - `@permission_required('app.codename')` / `permission_classes` → `{kind: permission, name}`
  - `PermissionRequiredMixin.permission_required` → `{kind: permission}`
  - `Group` objects / `@user_passes_test` role checks → `{kind: group}`

## UI detection
- dominant layout: most-`{% extends "<base>" %}` template across `templates/`
- component: `{% include %}` partials / `templatetags`
- notification call: `django.contrib.messages` framework usage
````

- [ ] **Step 4: Create the four minimal lib-pattern catalogs**

Create each file with a minimal "Detection Examples" stub (manifest fingerprint + file fingerprint + sample YAML slice):

```bash
mkdir -p plugins/mega-sdd/references/lib-patterns/django
cat > plugins/mega-sdd/references/lib-patterns/django/auth-libs.md <<'EOF'
# Django auth libs
- django-built-in: marker `django` in pyproject; file `settings.py` AUTH_USER_MODEL. → auth.lib: django-built-in, mechanism: session
- django-allauth: marker `django-allauth`; `INSTALLED_APPS` has `allauth`. → auth.lib: django-allauth
- djangorestframework-simplejwt: marker `djangorestframework-simplejwt`. → auth.lib: simplejwt, mechanism: jwt
EOF
cat > plugins/mega-sdd/references/lib-patterns/django/rbac-libs.md <<'EOF'
# Django authz libs
- django.contrib.auth permissions: built-in; `@permission_required`, `Group`. → authz.lib: django.contrib.auth, mechanism: decorator, role_source: db
- django-guardian: marker `django-guardian` (object-level perms). → authz.lib: django-guardian
- django-rules: marker `rules`. → authz.lib: django-rules
EOF
cat > plugins/mega-sdd/references/lib-patterns/django/ui-libs.md <<'EOF'
# Django UI libs
- Django templates: `templates/` + `{% extends %}`. → ui_ux.layout via base template
- tailwind / bootstrap: marker in package.json (if a JS build present).
- htmx / alpine: markers in templates / static.
EOF
cat > plugins/mega-sdd/references/lib-patterns/django/generic-libs.md <<'EOF'
# Django generic libs
- celery (queue), django-redis (cache), django-filter, djangorestframework (API).
EOF
```

- [ ] **Step 5: Create the neutral-shape Django fixture**

```bash
mkdir -p tests/fixtures/de-laravelize/django-sample/.mega-sdd/codebase
cat > tests/fixtures/de-laravelize/django-sample/.mega-sdd/codebase/starterkit-context.yaml <<'EOF'
schema_version: "3.0"
framework: django
framework_pack: django
auth:
  lib: django-built-in
  lib_version: "5.0"
  lib_source: "pyproject.toml:12"
  mechanism: session
  user_model: "accounts.User"
  entrypoints:
    - { name: login, _source: "accounts/urls.py:5" }
  features: []
  _source: ["pyproject.toml:12", "settings.py:40"]
authz:
  lib: django.contrib.auth
  lib_source: "settings.py:33"
  mechanism: decorator
  role_source: db
  declarations:
    - { name: "orders.add_order", kind: permission, applies_to: "orders.views.OrderCreate", _source: "orders/views.py:22" }
    - { name: "Manager", kind: group, applies_to: null, _source: "accounts/migrations/0003_groups.py:10" }
  _source: ["settings.py:33", "orders/views.py:22"]
EOF
```

- [ ] **Step 6: Run — verify it passes**

Run: `bash tests/de-laravelize/test-django-pack.sh; echo exit=$?`
Expected: `exit=0`.

- [ ] **Step 7: Commit**

```bash
git add plugins/mega-sdd/references/framework-conventions/django.md plugins/mega-sdd/references/lib-patterns/django tests/fixtures/de-laravelize tests/de-laravelize/test-django-pack.sh
git commit -m "feat(packs): thin Django proof-pack + neutral-shape Django fixture (option-X validation)"
```

---

## Task 11: Migrate the ~25 committed starterkit-context.yaml fixtures + run validator suite

**Files:**
- Modify: all `tests/fixtures/**/starterkit-context.yaml` carrying the old `rbac:`/`auth.guard` shape
- Test: `tests/de-laravelize/test-fixtures-migrated.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/de-laravelize/test-fixtures-migrated.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
while IFS= read -r f; do
  if grep -qE '^\s*rbac:' "$f"; then echo "old rbac: shape in $f"; err=1; fi
  if grep -qE '^\s*guard:' "$f"; then echo "old auth.guard in $f"; err=1; fi
done < <(find tests -name starterkit-context.yaml)
exit $err
EOF
chmod +x tests/de-laravelize/test-fixtures-migrated.sh
```

- [ ] **Step 2: Run — verify it fails (lists ~25 fixtures)**

Run: `bash tests/de-laravelize/test-fixtures-migrated.sh; echo exit=$?`
Expected: lists the old-shape fixtures, `exit=1`.

- [ ] **Step 3: Migration rule + one worked example**

For EACH fixture, transform its `rbac:` block to `authz:` and `auth.guard` to `auth.mechanism`, using this mapping (worked example — apply identically to all):

Old:
```yaml
auth:
  lib: sanctum
  guard: sanctum
rbac:
  lib: spatie/permission
  role_model: "Spatie\\Permission\\Models\\Role"
  middleware: [role, permission]
  gates: [view-admin]
  policies: ["App\\Policies\\UserPolicy"]
  default_roles: [admin, user]
```
New:
```yaml
auth:
  lib: sanctum
  mechanism: token            # guard:sanctum → token; guard:web → session
authz:
  lib: spatie/permission
  mechanism: middleware
  role_source: model
  declarations:
    - { name: admin, kind: role, applies_to: null, _source: "RoleSeeder.php" }
    - { name: user,  kind: role, applies_to: null, _source: "RoleSeeder.php" }
    - { name: view-admin, kind: gate, applies_to: null, _source: "AuthServiceProvider.php" }
    - { name: "App\\Policies\\UserPolicy", kind: policy, applies_to: null, _source: "AuthServiceProvider.php" }
```

Mapping rules: `gates[]`→declarations kind=gate; `policies[]`→kind=policy; `default_roles[]`→kind=role; `middleware`→`authz.mechanism: middleware`; `role_model` present→`role_source: model`. Preserve each fixture's intent (good/bad scenarios must still trigger the same validator outcome).

- [ ] **Step 4: Apply to every fixture, then run the existing code-delivery validator suite**

After migrating all fixtures, run the validators that consume these fixtures to confirm they still pass/fail as designed:

```bash
bash tests/de-laravelize/test-fixtures-migrated.sh; echo migrated=$?
# Re-run the code-delivery validator suite against the (migrated) good/bad fixtures:
for v in validate-sibling-consistency validate-dispatch-prompt validate-cross-cutting-registration validate-ui-quality validate-flow-coverage validate-fanout-parity validate-ui-deferral validate-starterkit-conformance; do
  echo "--- $v ---"; ls plugins/mega-sdd/scripts/$v.sh >/dev/null 2>&1 && echo "exists (run per its own harness)"; done
```

Expected: `migrated=0`. Each validator's own test harness (the `good/` fixtures pass, `bad/` fixtures fail) must be unchanged — run them per the repo's existing test entrypoint and confirm no regression.

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures tests/de-laravelize/test-fixtures-migrated.sh
git commit -m "test(fixtures): migrate ~25 starterkit-context fixtures to neutral authz shape"
```

---

## Task 12: Version bumps + full suite green

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/SKILL.md`, `generate-units/SKILL.md`, `execute-bolts/SKILL.md` (frontmatter `version:`)
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump the three skill versions**

In each SKILL.md frontmatter, increment the `version:` minor (e.g., `2.6.0` → `2.7.0`). Add a one-line Changelog entry if the skill carries one.

- [ ] **Step 2: Bump plugin version in both manifests (must match)**

`plugin.json` and `marketplace.json` `version` → next minor (e.g., `4.3.0` → `4.4.0`), and update `marketplace.json` `version_note` with a one-line summary.

- [ ] **Step 3: Run the full de-laravelize suite**

Run: `bash tests/de-laravelize/run-all.sh; echo SUITE=$?`
Expected: `SUITE=0` (all gates green).

- [ ] **Step 4: Final repo-wide leak sweep (no old ontology read anywhere outside the laravel pack + golden file)**

Run:

```bash
grep -rnE 'starterkit_context\.rbac|rbac\.lib *==|rbac\.gates|rbac\.policies|auth\.guard' plugins/mega-sdd/ \
  | grep -vE 'framework-conventions/laravel|golden-laravel-tokens' && echo "LEAK REMAINS" || echo "FULLY MIGRATED"
```

Expected: `FULLY MIGRATED`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/*/SKILL.md plugins/mega-sdd/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): bump scan/units/bolts skills + plugin to v4.4.0 (de-laravelize core)"
```

---

## Self-Review (completed by author)

- **Spec coverage:** §2 ontology→Task 2; §3 prompt parameterization→Tasks 3-5; §4 pack contract→Task 6; §5 consumers (all 3)→Tasks 7-9; §6 Django proof-pack→Task 10; §6.5 fixture migration→Task 11; §8.1 regression (clean-template + relocation-coverage)→Tasks 1/5; §8.3 ontology-positive→Task 10; versioning→Task 12. No spec section unmapped.
- **Placeholder scan:** test scripts authored in full; novel content (schema block, prompts, Django pack) authored exactly; the repetitive fixture migration uses one worked example + an explicit mechanical rule + a gating test over all files (DRY, not a placeholder).
- **Type consistency:** field names align across tasks — `authz.{lib,lib_source,mechanism,role_source,declarations[].{name,kind,applies_to,_source}}` and `auth.{lib,lib_source,mechanism,user_model,entrypoints}` used identically in schema (Task 2), prompts (Tasks 3-5), consumers (Tasks 7-9), Django pack/fixture (Task 10), and fixture migration (Task 11).
