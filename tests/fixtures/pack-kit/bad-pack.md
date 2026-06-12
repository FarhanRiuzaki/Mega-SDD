---
framework: django
framework_version_range: "4.x — 5.x"
last_verified_against: 2026-01-01
maintainer: test
detection_signature:
  package_manifest: pyproject.toml
  dependency_marker: django
  version_regex: 'django==(\d+)\.'
extends: _universal
---

# Bad Pack (deliberately malformed)

A deliberately broken pack for linter testing.

## File location standards

| Artifact | Path |
|---|---|
| Models | `app/models/` |
| Views | `app/views/` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Class case | PascalCase | `MyModel` |
| Method case | snake_case | `get_queryset` |

## Idioms (preferred patterns)

- Use class-based views
- Use model managers for query logic
- Use Django forms for validation

## Hard Rules emitted

```
HARD_RULE: Models MUST live in app/models.py
  path_glob: **/models.py
  rule_type: LOCATION_RULE
  rationale: Django discovers models via INSTALLED_APPS; non-standard locations require manual registration
```

## Forbidden patterns

- Direct SQL queries bypassing the ORM
- Business logic in templates

## ERD additions

- Standard Django auto-pk: `id` BigAutoField unless overridden

## Migration / dependency management

- Lock file: none (pip ecosystem — use `requirements.txt` or `pyproject.toml`)
- Install: `pip install -r requirements.txt`
- Update: `pip install --upgrade <package>`

## Flow-artifact derivation

```yaml
endpoint_kinds:
  - flow_signal: '(?i)\b(submit|save|create|update)\b'
    required_artifact: form
    path_glob: '**/forms.py'
    naming: '{Action}Form'
```

## Entity source globs

```yaml
entity_sources:
  - pattern: '/(?P<entity>[A-Za-z]+)View\.py'
```

## Entity matching tokens

```yaml
stop_tokens: []
compound_aliases: {}
```

## Test patterns

```yaml
detail_view_glob: '**/templates/**/detail.html'
detail_view_render:
  template: |
    response = self.client.get(reverse('{app}:{model}-detail', args=[obj.pk]))
    self.assertEqual(response.status_code, 200)
  test_glob: '**/tests/**/*.py'
```

## UI quality signatures

```yaml
view_glob: '**/templates/**/*.html'
min_view_lines: 20
scaffold_tells:
  - id: raw-pk-display
    regex: '\{\{ object\.pk \}\}'
    message: "Raw pk displayed — show a human-readable label instead."
```

## Cross-cutting concerns

```yaml
cross_cutting_concerns: []
```

## Relation derivation

```yaml
relation_derivation:
  fk_to_accessor:
    rule: '{singular}_id => related_model attribute'
    accessor_template: '{singular}'
```

## Notes / pack-specific guidance

General Django notes here.

## Deep-scan file hints

```yaml
auth_hints:  [ "**/settings.py", "**/urls.py" ]
authz_hints: [ "**/permissions.py" ]
ui_hints:    [ "**/templates/**" ]
broken_key: [this, is, invalid
  yaml: because it is not closed properly
  and: has inconsistent structure
```

## Authz mapping

- `auth.mechanism`: session
- `authz.mechanism`: decorator
- `authz.role_source`: db

## UI detection

- dominant layout: `{% extends "base.html" %}`
- component: `{% include %}`
- notification call: `django.contrib.messages`

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "**/utils.py" ]
  model_api:[ "**/models.py" ]
  services: [ "**/services.py" ]
  commands: [ "**/management/commands/**" ]
```

<!-- LARAVEL LEAK: the following lines contain Laravel-specific tokens -->

The Gate::define method in app/Http/Middleware is used for authorization.
