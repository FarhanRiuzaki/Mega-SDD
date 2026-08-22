# Squad Partition Rules

Defines how `_meta/squads.yaml` ownership rules route vault artifacts (entities, flows, ADRs, OQs, integrations) to squads. Consumed by `generate-units` when assigning the `squad:` field on each unit.

## Partition models

### Layer-based (`partition_model: layer`)

Default for `web-app` and most multi-component shapes.

Routing: a vault artifact's primary layer (from `vault.md ## Architecture`) matches a squad's `owns_layers` list.

| Vault layer hint | Routes to squad with `owns_layers` containing |
|---|---|
| `backend`, `api`, `service` | `backend` |
| `web-frontend`, `web-client`, `ui` | `web-frontend` |
| `mobile`, `ios`, `android` | `mobile` |
| `data-model`, `database`, `schema` | `data-model` (often paired with backend) |
| `integrations`, `external`, `webhook` | `integrations` |
| `infra`, `devops`, `platform` | `infra` |

### Feature-based (`partition_model: feature`)

Each squad owns one or more feature tags. Vault MUST tag flows/entities with feature names during `generate-intent` (use `tags: [feature/auth, feature/billing]` in flow descriptions or entity headers).

Routing: artifact's feature tag matches a squad's `owns_feature_tags` list.

If an artifact has multiple feature tags, the first match in declaration order wins.

### Hybrid (`partition_model: hybrid`)

Priority: feature > layer.

Routing rule:
1. If artifact has a feature tag matching some squad's `owns_feature_tags` → route to that squad.
2. Else if artifact has a layer matching some squad's `owns_layers` → route to that squad.
3. Else: unrouted — emit warning at `generate-units` time.

## Routing precedence (within a partition model)

When multiple rules in the same squad match, precedence is:

1. `owns_components` (explicit named match) — highest precedence
2. `owns_flow_prefixes` (flow ID prefix match, e.g., `F-B-` for backend flows)
3. `owns_layers` (architectural layer match)
4. `owns_feature_tags` (feature tag match)

If two squads claim the same artifact via the same precedence level → halt at `generate-units` time with `cross_squad_ambiguous` (NOT silently pick one).

## Single-squad mode

If `squads.yaml` declares exactly one squad, or the file is absent:
- All units get `squad: default` (or omit the field)
- No interface notes required
- `generate-units` skips all cross-squad validations
- Behaves as the single-squad default — no cross-squad machinery engages

## Validation (performed by generate-units)

- Each squad ID matches `^squad-[a-z0-9-]+$`
- No two squads claim same `owns_layers` entry
- No two squads claim same `owns_components` entry
- No two squads claim same `owns_feature_tags` entry
- If `partition_model: feature`, every squad has non-empty `owns_feature_tags`
- All artifacts route to exactly one squad (warn on unrouted)
