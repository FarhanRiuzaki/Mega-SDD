---
framework: <kebab-case-name>           # e.g., laravel, django, rails, express, nestjs, fastapi
framework_version_range: "X.x — Y.x"
last_verified_against: YYYY-MM-DD
maintainer: <name-or-mega-sdd>
detection_signature:
  package_manifest: <filename>          # composer.json | package.json | Gemfile | pyproject.toml | go.mod | Cargo.toml
  dependency_marker: <string>           # e.g., "laravel/framework", "django", "rails", "express"
  version_regex: <regex>                # optional — extract major version from manifest
extends: <other-pack-or-null>           # optional — pack inheritance (e.g., nestjs extends typescript-universal)
---

# <Framework Display Name> Convention Pack

<1-sentence pack purpose, e.g., "Conventions for Laravel 10.x — 11.x backend projects.">

## File location standards

| Artifact | Path |
|---|---|
| Models | <e.g., `app/Models/`> |
| Controllers | <e.g., `app/Http/Controllers/`> |
| Migrations | <e.g., `database/migrations/`> |
| Routes | <e.g., `routes/web.php` + `routes/api.php`> |
| Tests | <e.g., `tests/Feature/` + `tests/Unit/`> |
| Config | <e.g., `config/`> |
| Static views | <e.g., `resources/views/`> |
| Static assets | <e.g., `resources/js/`, `resources/css/`> |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Column case | snake_case | `created_at`, `user_id` |
| Table case | <plural snake_case OR singular?> | `users`, `loan_applications` |
| Class case | PascalCase | `LoanApplication` |
| Method case | <camelCase OR snake_case?> | <example> |
| Filename case | <PascalCase OR snake_case OR kebab-case?> | <example> |
| Migration filename | <pattern> | <example> |
| FK column | `{singular_target_table}_id` | `customer_id` on `loans` table |
| Pivot/junction table | <pattern> | <example> |
| Standard timestamps | <enabled by default?> | `created_at` + `updated_at` |
| Soft delete column | <if applicable> | `deleted_at` |

## Idioms (preferred patterns)

- <Idiom 1 — e.g., "Use Eloquent over raw query for CRUD operations">
- <Idiom 2 — e.g., "Use Form Requests for input validation, not inline `request()->validate()`">
- <Idiom 3 — e.g., "Use Policies for authorization, not inline checks in controllers">
- <Idiom 4 — e.g., "Use API Resources for JSON response shaping">

## Hard Rules emitted

These rules merge into `binding.md` §Suggested Unit Hard Rules when this pack is loaded.

```
HARD_RULE: <human-readable rule statement>
  path_glob: <e.g., app/Models/*.php>
  rule_type: NAMING_RULE | LOCATION_RULE | SIGNATURE_RULE | DEP_RULE | CUSTOM
  ast_grep_pattern: <YAML rule reference, or empty if NAMING_RULE>
  rationale: <1-sentence why>
```

Example (Laravel):

```
HARD_RULE: Migration files MUST follow `YYYY_MM_DD_HHMMSS_<descriptive>.php` pattern
  path_glob: database/migrations/*.php
  rule_type: NAMING_RULE
  rationale: Laravel orders migrations by filename timestamp; non-conformant files break schema rollout
```

## Forbidden patterns

What violates this framework's idioms (anti-patterns that bolts must NOT generate):

- <Anti-pattern 1 — e.g., "Raw `DB::table()` queries in Controllers (use Models)">
- <Anti-pattern 2 — e.g., "Business logic in `routes/*.php` (use Controllers or Actions)">
- <Anti-pattern 3 — e.g., "Direct `$_POST` / `$_GET` access (use Request object)">

## ERD additions (when this pack applies)

Extends `references/framework-conventions/_universal.md` §ERD Quality Rails:

- <Framework-specific ERD rule 1 — e.g., "Pivot tables: alphabetical singular_a_singular_b (Eloquent convention)">
- <Framework-specific ERD rule 2 — e.g., "Polymorphic relations: morphable_id + morphable_type columns">

## Testing conventions

- Framework test runner: <e.g., `php artisan test` for Laravel; `pytest` for Django/FastAPI>
- Test file location: <e.g., `tests/Feature/` + `tests/Unit/`>
- Test naming: <e.g., `<Feature>Test.php` with `test_<scenario>` methods>
- Fixtures: <e.g., factories under `database/factories/`>

## Migration / dependency management

- Lock file: <e.g., `composer.lock`, `package-lock.json`, `Gemfile.lock`>
- Update command: <e.g., `composer update`, `npm update`>
- Install command: <e.g., `composer install`, `npm install`>
- Build/compile command: <e.g., `npm run build` for assets, `php artisan optimize`>

## Flow-artifact derivation

> Consumed by `validate-flow-coverage.sh` (code-delivery slice A). Declares how an
> input-accepting state-transition step in `04-flows.md` maps to a REQUIRED code
> artifact. The validator is tech-agnostic: it reads these signatures, never
> hardcodes a stack. A pack that omits this section → the validator writes
> `status: SKIP` (graceful, never errors). NOTE: `target_files` is parsed from a
> unit's `## Target files` fenced block, NOT a frontmatter field.

```yaml
endpoint_kinds:
  - flow_signal: <regex matching an input-accepting transition step in 04-flows.
                  The validator splits each flow into per-step BLOCKS (a numbered
                  `N.` line plus its indented sub-bullets) and matches the regex
                  against the whole block — so a signal that appears in a step's
                  detail bullet (e.g. `workflow_state -> SUBMITTED`) still counts.>
    required_artifact: <artifact-kind, e.g. form-request | serializer | form-object | validation-schema>
    path_glob: <glob where that artifact lives, e.g. app/Http/Requests/**/*.php>
    naming: <optional naming template, e.g. '{Action}{Module}Request'>
```

The validator counts, PER MODULE unit, the distinct input-accepting flow steps
(flow_signal match, one count per matching step block) against the count of
`path_glob`-matching artifacts the unit lists in `## Target files`; a shortfall
(steps > artifacts) is a coverage miss.

## Conditional scaffold artifacts

> Consumed by `validate-flow-coverage.sh` (code-delivery slice A — anti dead-stub).
> Declares an artifact that is ONLY valid when a matching flow endpoint exists.
> If a unit lists `artifact_glob` in `## Target files` but NO flow step matches
> `requires_flow_endpoint`, the artifact is a dead scaffold stub → flagged.
> Dead-stub findings are de-duplicated by resolved artifact PATH (not by unit),
> so two units pointing at the same view path count once.

```yaml
- artifact_glob: <e.g. resources/views/**/edit.blade.php>
  requires_flow_endpoint: <regex of the endpoint-kind that must exist for this
                           artifact to be valid, e.g. (?i)\b(update|edit|put|patch)\b>
```

## Entity source globs

> Consumed by `validate-flow-coverage.sh` (code-delivery slice A — module matching).
> Declares HOW to recover a unit's entity name from the paths in its `## Target files`
> block, so a flow can be matched to the unit(s) that implement its module. This is the
> stack-specific half of module matching: a flow titled "Widget Approval" must associate
> with the unit whose controller / view-dir / model is "Widget". The validator is
> tech-agnostic: it reads these capture patterns, never hardcodes a stack. A pack that
> omits this section → the validator degrades to TITLE-ONLY matching (flow title tokens
> vs unit `title:` / `module:` frontmatter tokens) — never errors, just coarser.

```yaml
entity_sources:
  # Each pattern is a Python regex run against every target-files path. The FIRST
  # capture group (or a named group `(?P<entity>...)`) is tokenized into the unit's
  # entity token set. `exclude` (optional) drops capture values that are framework
  # scaffolding dirs, not entities.
  - pattern: '/(?P<entity>[A-Za-z]+)Controller\.php'        # e.g. WidgetController.php -> Widget
  - pattern: 'resources/views/(?P<entity>[a-zA-Z0-9_-]+)/'   # e.g. views/widgets/ -> widgets
    exclude: ['_partials', 'components', 'layouts', 'vendor']
  - pattern: 'app/Models/(?P<entity>[A-Za-z]+)\.php'         # e.g. Widget.php -> Widget
```

## Entity matching tokens

> Consumed by `validate-flow-coverage.sh` (code-delivery slice A — token tuning).
> The validator core carries ONLY generic structural stopwords (articles, prepositions)
> plus mega-sdd vault-FORMAT vocabulary (the workflow / ceremony nouns that appear in
> every vault regardless of stack — e.g. `module`, `flow`, `approve`, `maker`). A pack
> may add DOMAIN-SPECIFIC stopwords (industry jargon that is noise for entity matching
> in THIS project's domain) and compound aliases (multi-word entity → stable token set).
> Optional: a pack that omits this section just uses the validator's universal stopword
> set. Keep project-specific jargon HERE (or in your fork's pack), never in the validator.

```yaml
# Domain stopwords: tokens stripped before entity matching (noise for THIS domain).
stop_tokens: []          # e.g. ['lc', 'swift', 'settlement'] for a trade-finance domain
# Compound aliases: a compacted multi-word entity -> the set of tokens it should match.
compound_aliases: {}     # e.g. { letterofcredit: [letterofcredit, lc, letter, credit] }
```

## Test patterns

> Consumed by `validate-unit-spec.sh` (code-delivery slice D — render-test-per-module
> gate). Declares (a) `detail_view_glob`: the path shape of a DETAIL/SHOW view in this
> stack, and (b) `detail_view_render`: the test template a bolt must emit so the detail
> route is actually rendered (not just route-200-smoke-tested). The validator is
> tech-agnostic: any unit whose `target_files` (frontmatter list OR the `## Target files`
> body block) include a path matching `detail_view_glob` MUST carry a structured
> `acceptance_test:` entry of `type: render` (or `kind: render`); absent → issue
> `render_test_missing` → blocks `execute-bolts`. A pack that omits this section → the
> render check SKIPs (this stack declared no detail-view convention); the other unit-spec
> checks still run. Adding a stack = adding a pack, never editing the validator.

```yaml
detail_view_glob: <glob for a detail/show view, e.g. resources/views/**/show.blade.php>
detail_view_render:
  template: |
    <stack test snippet that builds a model, GETs the detail route, asserts 200,
     and asserts a REAL display field renders — e.g.
     $m = {Model}::factory()->create();
     $this->get(route('{resource}.show', $m))->assertOk()->assertSee((string) $m->{display_field});>
  test_glob: <glob where that render test lives, e.g. tests/Feature/**/*Test.php>
```

## UI quality signatures

> Consumed by `validate-ui-quality.sh` (code-delivery slice E — UI scaffold-tells gate).
> Declares (a) `view_glob`: the path shape of a renderable view in this stack, (b)
> `scaffold_tells`: raw generator output that MUST NOT ship (a match = a defect), and
> (c) `required_elements`: signatures a NON-TRIVIAL view (more than `min_view_lines`)
> MUST contain (an absence = a defect). The validator is tech-agnostic: it reads these
> signatures, never hardcodes a stack. A pack that omits this section → the validator
> writes `status: SKIP` (graceful, never errors). Adding a stack = adding a pack.
>
> LIST MERGE: `scaffold_tells` + `required_elements` are MERGED (union, dedup by `id`)
> across the whole pack `extends` chain, so a base pack can declare stack-generic tells
> (`laravel.md`) while a project pack adds project-specific required elements
> (`laravel-base-26.md`); both apply. Scalars (`view_glob`, `min_view_lines`,
> `scaffold_stub_glob`) are first-occurrence-wins (most-specific pack overrides).

```yaml
view_glob: <glob for a renderable view, e.g. resources/views/**/*.blade.php>
min_view_lines: <optional int (default 20) — views with fewer lines are "trivial"
                 (partials, fragments) and are EXEMPT from the required_elements check;
                 scaffold_tells are checked on EVERY matched view regardless of size>
scaffold_stub_glob: <optional — path of the generator's stub template, reserved for a
                     future min-delta diff; NOT consumed by the v1 tells/elements check>
scaffold_tells:
  # raw generator output that must NOT ship. Each match is a violation.
  - id: <stable name, e.g. title-is-controller>
    regex: <pattern matched against the view text>
    message: <why it is wrong + how to fix>
required_elements:
  # signatures a non-trivial view MUST contain. Each ABSENCE is a violation.
  - id: <stable name, e.g. layout-extends>
    regex: <pattern that must appear at least once>
    message: <what is missing>
```

The validator scans every file under `--cwd` matching `view_glob`. For each it FAILs if
ANY `scaffold_tells.regex` matches, or — when the file has more than `min_view_lines`
lines — if ANY `required_elements.regex` is absent. Findings are emitted as
`violations[{file, id, message, line}]` to `.ui-quality-blockers.json`.

## Notes / pack-specific guidance

<Free-form section for framework-specific quirks, common pitfalls, anti-patterns to call out, etc.>
