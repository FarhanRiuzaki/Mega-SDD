# Deep-Scan Subagent Prompts

## Contents
- Common dispatch contract
- Variable substitution + `<MANIFEST_FACTS>` injection format
- auth-extractor prompt
- authz-extractor prompt
- ui-ux-extractor prompt
- libs-extractor prompt
- reuse-extractor prompt
- Subagent dispatch pattern (for reference)
- Anti-halu rails (cross-cutting)

> Prompt templates for the 5 parallel subagents dispatched by `scan-codebase` in the deep-scan stage.

**Consumed by:** the deep-scan stage Step 10.5.2 (subagent dispatch; see `references/deep-scan-stage.md`)
**Schema:** `plugins/mega-sdd/references/starterkit-context-schema.md` (target output structure)
**Catalogs:** `plugins/mega-sdd/references/lib-patterns/<framework>/*.md` (detection patterns)

## Common dispatch contract

All 5 subagents follow this contract:

- **Model:** `sonnet`
- **Tool surface:** Read, Glob, Grep, Bash (read-only)
- **Wall-clock budget:** ≤10 min (auto-retry once on timeout; second failure → partial output per `references/halts-flags-handoff.md`)
- **Output format:** structured YAML matching the assigned slice in `starterkit-context-schema.md`
- **Anti-halu rail:** if a lib is not detected in manifests OR not found in code probes, emit `lib: not_detected` — NEVER guess
- **Citation rail:** every output field MUST be backed by `_source: [<file>, ...]` companion field

## Variable substitution

Each prompt template uses placeholders the dispatcher substitutes:
- `<FRAMEWORK>` → framework name from `codebase-map.md §7 Framework.name` (e.g., `laravel`)
- `<PROJECT_ROOT>` → absolute path to project root being scanned
- `<CATALOG_PATH>` → absolute path to `lib-patterns/<FRAMEWORK>/<domain>-libs.md`
- `<MANIFEST_FACTS>` → pre-parsed manifest data injected by main thread per the deep-scan stage Step 10.5.1.5. **Subagents MUST NOT re-read composer.json / package.json / lock files** — manifest_facts struct is authoritative. This saves ~2-6KB per subagent (~9-24KB per scan total).
- `<AUTH_FILE_HINTS>` → substituted by the dispatcher from the framework pack's `## Deep-scan file hints` → `auth_hints` list; falls back to `_universal.md` generic auth hints if the pack has no `auth_hints` section.
- `<AUTH_CONSTRUCT_MAP>` → substituted by the dispatcher from the framework pack's `## Authz mapping` auth.mechanism guidance section; falls back to `_universal.md` generic heuristic if the pack has no applicable section.
- `<AUTHZ_FILE_HINTS>` → substituted by the dispatcher from the framework pack's `## Deep-scan file hints` → `authz_hints` list; falls back to `_universal.md` generic authz hints if the pack has no `authz_hints` section.
- `<AUTHZ_CONSTRUCT_MAP>` → substituted by the dispatcher from the framework pack's `## Authz mapping` section; falls back to `_universal.md` generic heuristic if the pack has no `## Authz mapping` section.
- `<UI_FILE_HINTS>` → substituted by the dispatcher from the framework pack's `## Deep-scan file hints` → `ui_hints` list; falls back to `_universal.md` generic ui hints if the pack has no `ui_hints` section.
- `<UI_CONSTRUCT_MAP>` → substituted by the dispatcher from the framework pack's `## UI detection` section; falls back to `_universal.md` generic heuristic if the pack has no `## UI detection` section.
- `<REUSE_FILE_HINTS>` → substituted by the dispatcher from the framework pack's `## Reuse discovery` → `reuse_hints` list; falls back to `_universal.md` generic reuse hints if the pack has no `## Reuse discovery` section.
- `<REUSE_CONSTRUCT_MAP>` → substituted by the dispatcher from the framework pack's `## Reuse discovery` annotation block; falls back to `_universal.md` generic reuse construct guidance if the pack has no `## Reuse discovery` section.

## `<MANIFEST_FACTS>` injection format

Main thread parses ALL detected manifest files ONCE before dispatch (tech-agnostic — one block per ecosystem present; full per-ecosystem field list in `references/deep-scan-stage.md` Step 10.5.1.5) and injects this YAML block into each subagent prompt:

```yaml
manifest_facts:
  composer: { dependencies: {...}, dev_dependencies: {...}, scripts: {...}, autoload_psr4: {...} }   # php
  package:  { dependencies: {...}, dev_dependencies: {...}, peer_dependencies: {...}, scripts: {...}, type: module|commonjs }  # js/ts
  cargo:    { dependencies: {...}, dev_dependencies: {...} }                                          # rust
  go:       { module: <path>, dependencies: {...} }                                                   # go
  gem:      { dependencies: {...}, groups: {...} }                                                    # ruby
  python:   { dependencies: {...}, optional_dependencies: {...}, source: pyproject|requirements|pipfile }  # python
  jvm:      { dependencies: {...}, build_tool: maven|gradle }                                         # java/kotlin
# Only ecosystems detected in the repo appear. Subagents MUST NOT re-read any manifest or lock file.
```

Subagent prompts use `<MANIFEST_FACTS>` directly for manifest fingerprint lookup. No template instructs a subagent to re-read manifests — if `<MANIFEST_FACTS>` is absent (edge case: dispatch outside the deep-scan stage), the dispatcher must inline the parsed manifest data before sending.

---

## auth-extractor prompt

```
ROLE: Auth library + flow detector for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (auth-libs.md for this framework)
FILE HINTS: <AUTH_FILE_HINTS>          (from pack `## Deep-scan file hints` -> auth_hints; or _universal generic)
CONSTRUCT MAP: <AUTH_CONSTRUCT_MAP>    (from pack `## Authz mapping` auth.mechanism guidance; or _universal generic)

YOUR JOB:
Detect which auth library is in use, identify the auth mechanism, user model,
auth entrypoints (login/register/logout handlers), and feature flags
(2fa, email verification, social login).

INPUTS TO READ:
1. <MANIFEST_FACTS> (authoritative; do NOT re-read manifests)
2. Each path in <AUTH_FILE_HINTS>      (from pack `## Deep-scan file hints` -> auth_hints; or _universal generic)
3. THE CATALOG: <CATALOG_PATH>

DETECTION PROCEDURE:
1. Read catalog + CONSTRUCT MAP. Identify the auth library from <MANIFEST_FACTS> + catalog (open string; not_detected if none).
2. Determine mechanism (session | token | jwt | oauth | builtin | unknown) per CONSTRUCT MAP.
3. Identify the user/account model and the auth entrypoints (login/register/logout handlers) from <AUTH_FILE_HINTS>.
4. Record features (email_verification, 2fa, social_login, ...) only when evidenced.

OUTPUT:
Emit a single YAML block matching the §auth slice in
plugins/mega-sdd/references/starterkit-context-schema.md. Include the
_source array citing every file you read to derive the answer.

If no auth lib fingerprint matches, emit `lib: not_detected` with empty
fields. NEVER guess.

OUTPUT FORMAT (single YAML block in your final response, no prose preamble):

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

CONSTRAINTS:
- READ-ONLY: no Edit, no Write, no Bash mutations
- Cap response at ~80 lines of YAML
- Bind every field to a citation in _source[]
- lib: not_detected is valid if no auth lib found — NEVER guess
- lib is an OPEN string; for an unrecognized lib emit its real name (do NOT coerce to a fixed enum)
- Every field cited in _source; no entrypoint without _source
- If multiple auth libs match fingerprints, emit the highest-precedence as auth.lib:. Do NOT list others here — they will be picked up by libs-extractor.
```

---

## authz-extractor prompt

```
ROLE: Authorization (access-control) detector for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (rbac-libs.md for this framework)
FILE HINTS: <AUTHZ_FILE_HINTS>          (from pack `## Deep-scan file hints` -> authz_hints; or _universal generic)
CONSTRUCT MAP: <AUTHZ_CONSTRUCT_MAP>    (from pack `## Authz mapping`; or _universal generic heuristic)

YOUR JOB:
Detect the authorization library and extract every access-control declaration
into the framework-neutral authz shape. Do NOT assume any specific framework's
constructs - use CONSTRUCT MAP to know what this stack's authz constructs are.

INPUTS TO READ:
1. The package manifest facts in <MANIFEST_FACTS> (authoritative; do NOT re-read manifests)
2. Each path in <AUTHZ_FILE_HINTS>
3. THE CATALOG: <CATALOG_PATH>

DETECTION PROCEDURE:
1. Read catalog + CONSTRUCT MAP. Identify the authz lib (open string; not_detected if none).
2. Determine mechanism (middleware | decorator | guard | policy | mixin | builtin | unknown) per CONSTRUCT MAP.
3. Determine role_source (model | config | db | enum | unknown).
4. For each authz construct named in CONSTRUCT MAP, extract a declaration
   {name, kind, applies_to, _source}. kind in role|permission|gate|policy|group.
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
- lib: not_detected is valid if no authz lib/construct found - NEVER guess
- lib is an OPEN string; for an unrecognized lib emit its real name (do NOT coerce to a fixed enum)
- Every field bound to a citation in _source[]; no declaration without _source
```

---

## ui-ux-extractor prompt

```
ROLE: UI/UX library + design pattern detector for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (ui-libs.md for this framework)
FILE HINTS: <UI_FILE_HINTS>          (from pack `## Deep-scan file hints` -> ui_hints; or _universal generic)
CONSTRUCT MAP: <UI_CONSTRUCT_MAP>    (from pack `## UI detection`; or _universal generic)

YOUR JOB:
Detect JS framework, CSS framework, notification lib, icon lib, datatable lib,
identify layout file + component dir, extract design tokens, infer empirically
grounded idioms from actual code patterns.

INPUTS TO READ:
1. <MANIFEST_FACTS> (authoritative)
2. Each path in <UI_FILE_HINTS>        (from pack `## Deep-scan file hints` -> ui_hints; or _universal generic)
3. THE CATALOG: <CATALOG_PATH>

DETECTION PROCEDURE:
1. Read catalog + <UI_CONSTRUCT_MAP> (from pack `## UI detection`; or _universal generic).
2. js_framework / css_framework / notification_lib / icon_lib / datatable_lib: detect from <MANIFEST_FACTS> + catalog.
3. layout_extends + layout_file + component_dir: per <UI_CONSTRUCT_MAP> (how this stack declares template inheritance / a component).
4. design_tokens: parse the stack's theme/token source named in <UI_CONSTRUCT_MAP> (if present).
5. idioms: per <UI_CONSTRUCT_MAP> idiom probes, each requiring >=3 occurrences evidence.

OUTPUT FORMAT (single YAML block):

```yaml
ui_ux:
  js_framework: <enum>
  css_framework: <enum>
  layout_extends: <string>
  layout_file: <relative path string>
  component_dir: <relative path string>
  notification_lib: <enum>
  icon_lib: <enum>
  datatable_lib: <string>
  design_tokens:
    colors: { <key>: <hex>, ... }
    spacing: <"default" or object>
    fonts: [<list>]
  idioms: [<list of strings>]
  _source: [<list of file citations>]
```

CONSTRAINTS:
- READ-ONLY
- Cap response at ~100 lines of YAML
- idioms array MUST have >=3 occurrences evidence — never guess
- design_tokens only populated if the stack's theme/token source has an explicit extend/override block; else use defaults
- Bind every field to a citation in _source[]
- not_detected is a valid value for notification_lib, icon_lib, datatable_lib — never fabricate
```

---

## libs-extractor prompt

```
ROLE: Full library inventory builder for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (generic-libs.md for this framework)

YOUR JOB:
Build a complete inventory of packages from <MANIFEST_FACTS> (every detected
ecosystem — php/js/rust/go/ruby/python/jvm), categorize each by purpose
(auth/rbac/ui/queue/cache/log/test/http/misc),
and annotate with usage_hint citing files where the package is imported/used.

INPUTS TO READ:
1. <MANIFEST_FACTS> (authoritative; do NOT re-read composer.json / package.json / lock files)
2. THE CATALOG: <CATALOG_PATH> (category mapping reference)
3. For each detected lib: grep -r '<lib-namespace>' across the project source tree (use <FILE_HINTS> if provided, else the framework's conventional source dirs) — capture top 3-5 file matches

DETECTION PROCEDURE:
1. List every entry from EVERY ecosystem block present in <MANIFEST_FACTS>
   (composer / package / cargo / go / gem / python / jvm — dependencies + dev_dependencies).
2. For each lib:
   a. Match against catalog categories. Use the catalog's libs reference tables for this framework.
   b. If not in catalog → assign category `misc`.
   c. usage_hint: grep for the lib's namespace (e.g., the vendor/package namespace as it appears in imports) across the project source tree. Capture top 3-5 matching files (relative paths).
   d. If grep returns 0 matches → usage_hint: [] (lib is unused dependency).

OUTPUT FORMAT (single YAML block):

```yaml
libs:
  - name: <string>
    version: <string>
    category: <enum>
    usage_hint: [<list of file paths>]
  # ... one entry per lib in manifests
```

CONSTRAINTS:
- READ-ONLY
- Cap response at ~200 lines of YAML
- Cap total libs entries at 60 (truncate by alphabetical order if more; flag in _meta)
- Every lib MUST originate from <MANIFEST_FACTS> — never invent
- Empty usage_hint array is valid (suggests unused dep)
- Bind every lib entry to manifest evidence — if a lib is not in <MANIFEST_FACTS>, do NOT emit it
```

---

## reuse-extractor prompt

```
ROLE: Reusable-code (callable API surface) cataloger for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
FILE HINTS: <REUSE_FILE_HINTS>          (from pack `## Reuse discovery`; or _universal generic)
CONSTRUCT MAP: <REUSE_CONSTRUCT_MAP>    (from pack `## Reuse discovery`; or _universal generic)

YOUR JOB:
Catalog the starterkit's OWN reusable code so downstream bolts call it instead of
reinventing it. Four asset categories: helpers/utils, model API (methods/scopes/traits),
services/actions, CLI/commands. Capture SIGNATURE + 1-line purpose + _source ONLY —
never a function body.

INPUTS TO READ:
1. <MANIFEST_FACTS> (authoritative; do NOT re-read manifests)
2. Each path/glob in <REUSE_FILE_HINTS>
   (use tree-sitter -> ast-grep -> ripgrep/regex fallback, the established tool ladder)

PROCEDURE:
1. For each category in <REUSE_CONSTRUCT_MAP>, enumerate the stack's reusable symbols at the hinted locations.
2. For each symbol emit: signature, a 1-line purpose (from docblock if present -> purpose_confidence: stated; else conservatively inferred -> inferred), and _source: <file:line>.
3. Drop any symbol you cannot cite with a real _source. Cap each category at 300; if exceeded set truncated.<cat>: true.

OUTPUT: a single reuse-index.yaml document per `plugins/mega-sdd/references/reuse-index-schema.md` (helpers/model_api/services/commands).

CONSTRAINTS:
- READ-ONLY. Signatures only — NEVER copy a function body.
- Every entry cited in _source. Absence = omission, never a guess.
```

---

## Subagent dispatch pattern (for reference)

`scan-codebase` deep-scan Step 10.5.2 dispatches the stale-slice subagents IN PARALLEL via a single message (up to 5 — auth/authz/ui-ux/libs/reuse; N = len(stale_slices)) with N Agent tool calls (per `superpowers:subagent-driven-development` convention for parallel-safe work). Each Agent call uses the appropriate prompt template above with placeholder substitutions; model resolved from `plugins/mega-sdd/references/model-tiers.md` §<role-name> (default sonnet for all 5 extractors) OR from handoff metadata.model_tiers if override applied.

Consolidator (Step 10.5.3) collects the slice YAML responses, validates each against `starterkit-context-schema.md` (the reuse slice against `reuse-index-schema.md`), drops malformed slices (with `partial_slices:` updated), merges the auth/authz/ui_ux/libs slices into `starterkit-context.yaml` and writes the reuse slice to its own `reuse-index.yaml`, computes the cache signatures, and writes the files atomically.

## Anti-halu rails (cross-cutting)

All 5 prompts include the same 3 rails verbatim:
1. **No-fabrication**: emit `not_detected` / empty arrays when detection fails
2. **Citation**: every output field tied to `_source: [<file>, ...]`
3. **READ-ONLY**: no Edit / Write / mutating Bash operations

Subagents that violate these rails (e.g., emit a lib without citation) cause the consolidator to drop their slice from the merged output. The dropped slice is logged + the affected domain marked in `partial_slices:`.
