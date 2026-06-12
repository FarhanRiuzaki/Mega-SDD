# Pack lint checklist

Use this checklist when authoring or reviewing a framework convention pack. The automated gate (`validate-pack.sh`) enforces the same rules; this file is the human-readable version plus the machine-readable token map the script consumes.

## Check 1 — Required frontmatter keys

The pack's YAML frontmatter (between the first two `---` lines) must contain ALL of the following keys:

- `framework:` — the framework's kebab-case name (e.g. `laravel`, `django`, `rails`)
- `detection_signature:` — the detection block, which MUST include:
  - `package_manifest:` — the filename the CLI probes to detect the framework (e.g. `composer.json`, `pyproject.toml`)
  - `dependency_marker:` — the string the CLI searches for within the manifest (e.g. `laravel/framework`, `django`)
- `framework_version_range:` — the version range the pack was verified against (e.g. `"10.x — 12.x"`)

Optional but recommended: `last_verified_against:`, `maintainer:`, `detection_signature.version_regex:`, `extends:`.

## Check 2 — Required-always sections

Every pack MUST contain ALL five of the following `## ` headings (in any order):

1. `## File location standards` — table mapping artifact kinds to filesystem paths
2. `## Naming standards` — table of naming conventions (class, method, file, column, etc.)
3. `## Idioms` — bullet list of the framework's preferred patterns
4. `## Hard Rules emitted` — fenced block of `HARD_RULE:` entries that merge into `binding.md`
5. `## Testing conventions` — test runner, test file location, naming, and fixture conventions

A pack that omits any of these is incomplete and MUST NOT be loaded into the registry.

## Check 3 — Conditional sections (present or opted-out)

The following sections MUST be present if the framework has the capability. A pack that genuinely lacks the capability opts out by writing the heading immediately followed by `_(N/A:` and a brief explanation. The heading itself MUST still appear.

- `## Deep-scan file hints` — REQUIRED when the stack has auth, authz, or UI. Opt-out with `_(N/A: this stack has no built-in auth/authz/UI)_` if the framework truly has none.
- `## Authz mapping` — REQUIRED when the stack has authorization. Opt-out with `_(N/A: no built-in authorization)_` if the framework has none.
- `## UI detection` — REQUIRED when the stack renders server- or client-side UI. Opt-out with `_(N/A: API-only / no UI)_` if the framework is API-only.
- `## Reuse discovery` — REQUIRED when the stack has reusable first-party code (helpers, models, services, commands). Opt-out with `_(N/A: no conventional reuse locations)_` only for minimal/micro frameworks.

## Check 4 — Valid YAML in hint-section fenced blocks

Every fenced ` ```yaml ` block that appears under the four conditional sections (`## Deep-scan file hints`, `## Authz mapping`, `## UI detection`, `## Reuse discovery`) MUST be valid YAML. Common errors: unclosed brackets `[`, inconsistent indentation, colons inside unquoted strings, tab characters instead of spaces.

The script validates each such block with `python3 -c 'import yaml; yaml.safe_load(sys.stdin)'` (or a structural fallback if PyYAML is unavailable).

## Check 5 — No cross-framework token leaks

A pack's BODY (everything after the frontmatter closing `---`) MUST NOT contain tokens that are strongly distinctive of a DIFFERENT framework, except inside a fenced block whose info-string or whose immediately-preceding paragraph contains the phrase "contrast example".

The token map below is the machine-readable source for this check. The script reads the `## Cross-framework token map` section, determines the pack's `framework:` value, and greps the body for every OTHER framework's tokens. Any match outside a "contrast example" fence is a violation.

Rationale: a token leak indicates the pack was copy-edited from another framework's pack and not properly cleaned, or the author accidentally documented the wrong stack's idioms. Leaks confuse the bind-codebase binding step.

---

## Cross-framework token map

Format: one framework per line, `framework: token1, token2, ...`. The script splits on `, ` to get the token list.

```
laravel: app/Http, Gate::define, $routeMiddleware, .blade.php, Eloquent, artisan, @extends(, @section(, blade
django: settings.py, INSTALLED_APPS, models.Model, urls.py, manage.py, {%url
rails: ActiveRecord, config/routes.rb, app/controllers, .html.erb, attr_accessible
spring: @RestController, application.properties, @Autowired, pom.xml, @SpringBootApplication, @Service(, @Repository(
```
