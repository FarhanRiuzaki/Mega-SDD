---
framework: _universal
framework_version_range: "n/a"
last_verified_against: 2026-05-22
maintainer: mega-sdd
detection_signature:
  package_manifest: null              # Always applies as fallback
  dependency_marker: null
extends: null
---

# Universal Good-Practice Convention Pack

Always applies — loaded by `bind-codebase` step 2.8 either ALONE (when no framework detected) or MERGED WITH a framework-specific pack (framework rules take precedence on conflict).

These are universal good practices that hold across most backend frameworks and database systems. Use as baseline when no framework-specific guidance exists.

## File location standards

Universal pack does NOT prescribe paths — they're framework-specific. Defer to framework pack or codebase-detected conventions.

## Naming standards

| Concept | Convention | Rationale |
|---|---|---|
| Column case | **snake_case** | SQL convention; works across all major RDBMS |
| Table case | **plural snake_case** | `customers`, not `customer`; collection semantic |
| FK column | `{singular_target_table}_id` | Explicit + self-documenting |
| Boolean column | `is_<state>` or `has_<thing>` | `is_active`, `has_phone_verified` — readable in queries |
| Datetime column | `<verb>ed_at` | `created_at`, `updated_at`, `deleted_at`, `verified_at`, `last_logged_in_at` |
| Count column | `<noun>_count` | `view_count`, `comment_count` |
| Standard timestamps | `created_at TIMESTAMP NOT NULL`, `updated_at TIMESTAMP NOT NULL` | On every mutable table |
| Soft delete column | `deleted_at TIMESTAMP NULL` | Application filters rows where `deleted_at IS NOT NULL` |
| Audit columns (when applicable) | `created_by`, `updated_by` → FK to users.id | Audit trail for sensitive entities |
| Primary key | `id` | Auto-increment BIGINT or UUID v4 / v7 per framework default |
| UUID column (when applicable) | `uuid` (in addition to `id`) | Use `id` for FK joins (performance), `uuid` for external references |

## ERD Quality Rails

Every `suggested-erd.md` produced by `extract-intelligence` MUST satisfy:

### Normalization checklist

- **3NF compliance**: every non-key field depends on THE WHOLE KEY, ONLY the key, NOTHING but the key
- **No repeating groups**: `phone1`, `phone2`, `phone3` → separate `customer_phones` table
- **Junction tables for M:N**: `users` × `roles` → `user_roles(user_id, role_id)` composite PK
- **No string-encoded structure**: `tags VARCHAR(255)` with comma-delimited values → separate `tags` + `taggables` tables
- **No mixed-type columns**: `value VARCHAR(255)` storing strings/numbers/dates → use proper types or split

### Allowed denormalization

Only when paired with `[LOCKED]` tag + business justification:

- Reporting performance (e.g., precomputed `total_amount` on `invoices` table refreshed by trigger)
- Audit immutability (e.g., `customer_name_snapshot` on `orders` to preserve historical name)
- Regulatory snapshot (e.g., audit-trail tables with field copies)

Document the denormalization rationale in `data-mutation-policy.md` per-locked-field policy.

### Departures from legacy (mandatory section)

`suggested-erd.md` MUST list:

1. **Denormalization fixes** — what legacy denormalized, how rebuild normalizes
2. **Naming standardization** — legacy abbreviated/cryptic names → rebuild full descriptive names
3. **Type corrections** — legacy `varchar(255)` for everything → rebuild proper types (`decimal(15,2)` for currency, `text` for unbounded, `enum` for fixed sets)
4. **Structural bug fixes** — legacy typo column names corrected
5. **Discarded fields** — `[ARTIFACT]` columns listed with discard rationale

## Hard Rules emitted

```
HARD_RULE: Column names in schema definitions MUST follow snake_case
  path_glob: <framework-specific — set by framework pack overlay>
  rule_type: NAMING_RULE
  case_style: snake_case
  rationale: SQL convention; cross-framework portability

HARD_RULE: Foreign key columns MUST follow `{singular_target_table}_id` pattern
  path_glob: <framework-specific>
  rule_type: NAMING_RULE
  pattern: `[a-z][a-z0-9_]*_id$`
  rationale: Self-documenting + searchable + ORM convention across frameworks

HARD_RULE: Boolean columns MUST follow `is_<state>` or `has_<thing>` pattern
  path_glob: <framework-specific>
  rule_type: NAMING_RULE
  pattern: `^(is|has)_[a-z][a-z0-9_]*$`
  rationale: Readable in query expressions (e.g., `WHERE is_active = true`)
```

## Forbidden patterns

- Tables without `id` primary key (denormalized intermediate tables OK as composite PK)
- Tables without `created_at` + `updated_at` timestamps (unless explicitly immutable like audit logs)
- VARCHAR(255) used as default type for everything (use proper sized/typed columns)
- Comma-delimited values in single columns (use junction tables)
- Date/time stored as VARCHAR/INT (use proper TIMESTAMP/DATETIME types)
- Foreign keys without explicit constraint (`ON DELETE`/`ON UPDATE` defined)

## Testing conventions (universal defaults)

- Test isolation: every test resets DB state (transactional rollback or per-test schema)
- Naming: test functions describe scenario, not implementation (`test_user_cannot_login_with_revoked_token`, not `test_login`)
- Fixtures: factories preferred over hardcoded SQL inserts

## ID convention guidance

Choose ONE per project (frameworks may default to a specific choice):

| Style | When to use | Tradeoff |
|---|---|---|
| Auto-increment BIGINT | Most internal data; high join performance; small storage | Sequential — exposes record counts; not safe for external URLs |
| UUID v4 | Distributed systems; external-facing URLs; offline-generated | Larger storage; random — poor index locality |
| UUID v7 (time-ordered) | Distributed + needs index locality | New (2026+); framework support varies |
| Composite key | Junction tables only | Awkward for ORMs |

## Flow-artifact derivation

> Universal reasoning core for code-delivery slice A (`validate-flow-coverage.sh`).
> The PRINCIPLE is stack-neutral; the SIGNATURES are not.

Universal principle (holds across all backends): **every input-accepting
state-transition step in a flow must map to exactly one input-validation artifact
in the unit that builds that module — no more, no fewer.** A module unit that
enumerates N input-accepting flow steps but ships fewer validation artifacts has
under-decomposed the flow (a step accepts input with no place to validate it).

This pack declares ONLY the principle — it does NOT name a concrete artifact kind
or path, because "where input validation lives" is framework-specific (Laravel:
Form Request under `app/Http/Requests/`; Django: a `Form`/serializer; Express: a
validation-schema middleware). A framework pack overrides this section with its own
`endpoint_kinds:` block (see `_template.md` §Flow-artifact derivation). When NO pack
in the chain declares concrete `endpoint_kinds:`, the validator writes `status: SKIP`
— a stack is never blocked for a signature it never declared.

## Conditional scaffold artifacts

> Universal reasoning core for code-delivery slice A (anti dead-stub).

Universal principle: **a scaffolding generator emits some artifacts that are only
valid when a corresponding flow endpoint exists** (e.g. an edit/update view is dead
weight if the entity has no update flow). A unit that lists such an artifact in its
target files without the gating flow endpoint is shipping a dead stub.

As above, the universal pack declares only the principle; the concrete
`artifact_glob` + `requires_flow_endpoint` signatures are framework-specific and
live in the framework pack. Absent → the validator skips the dead-stub check.

## Entity source globs

> Universal reasoning core for code-delivery slice A (module matching).

Universal principle: **to compare a flow against the unit that builds its module,
the validator must recover each unit's entity name.** The strongest evidence is the
unit's own `module:`/`title:` frontmatter; the next-strongest is the entity baked
into the paths it ships (a `WidgetController`, a `widgets/` view dir, a `Widget`
model). WHERE that entity lives in a path is framework-specific — Laravel buries it
in `app/Http/Controllers/{Entity}Controller.php`; Django in an app/`models.py` class;
Express in a `routes/{entity}.js`. This universal pack declares ONLY the principle.

The concrete `entity_sources:` capture patterns live in the framework pack (see
`_template.md` §Entity source globs). When NO pack in the chain declares them, the
validator degrades to TITLE-ONLY matching (flow title tokens vs unit frontmatter
tokens) — coarser, but never an error and never a crash on an undeclared stack.

## Entity matching tokens

> Universal reasoning core for code-delivery slice A (token tuning).

Universal principle: **entity matching reduces both a flow title and a unit to a SET
of significant tokens and intersects them.** Generic structural words (articles,
prepositions) and mega-sdd vault-FORMAT vocabulary (`module`, `flow`, `approve`,
`maker`, …) are universal noise and are stripped by the validator core itself.

DOMAIN-specific jargon (industry terms that are noise for entity matching in a given
project) and compound-entity aliases are NOT universal — they belong in the framework
pack (or a project fork's pack) via `stop_tokens:` / `compound_aliases:` (see
`_template.md` §Entity matching tokens). The validator never bakes in a domain term.
