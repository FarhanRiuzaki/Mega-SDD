# Scenario 5 — Multi-Squad Parallel

**Time**: ~15 minutes (a migrated vault)
**Goal**: Know what happened to multi-squad mode in 9.0, and run a pre-9.0 multi-squad vault to completion.

> **Multi-squad authoring is retired in 9.0** (spec `docs/superpowers/specs/2026-09-27-v9-simplification-design.md` §7 decision #3). `plan`, the one spec producer, never writes `_meta/squads.yaml` or `interfaces/`, and 9.0 ships no template for either. The classic chain produced them, and it was removed. The unit-side squad rules are **kept for vaults that already carry those files**: a pre-9.0 vault, migrated to layout-3.

## What changed, in one table

| | Before 9.0 | 9.0 |
|---|---|---|
| Declaring squads (`_meta/squads.yaml`) + interface notes (`interfaces/<id>.md`) | authored with the vault | **retired**: nothing writes them; no template |
| `squad:` / `produces_interfaces` / `consumes_interfaces` on units | assigned when units were generated | **kept** on a vault that has `squads.yaml` (≥2 squads): `plan --regenerate` assigns and validates them |
| `execute-bolts --per-squad` / `--squad=<id>` | yes | `--per-squad` **retired** (inert since P3); `--squad=<id>` / `--all` run inline |
| Halts `cross_squad_dep_invalid` / `cross_squad_ambiguous` / `interface_ref_missing` / `cross_squad_interface_draft` | yes | **kept** for those vaults (`cross_squad_interface_draft`: a run-start quarantine) |

## Starting a new multi-team project

There is no multi-squad lane for a new vault. What 9.0 offers instead:

- **One vault per scope.** When BE / FE / MW teams share one PRD, give the PRD a `scopes:` block and have each architect plan their own scope (`--scope=<id>`). → [Scenario 7 — Multi-architect](scenario-7-multi-architect.md).
- **Modules inside one vault.** `plan` groups units into modules (`_meta/modules.yaml`, auto-derived when absent), and `execute-bolts --module=<id>` runs one module's units in topological order. It halts `module_blocked_by` when a prerequisite module is not done. Modules have no interface-lock gate; cross-module `depends_on` edges need an explicit `blocked_by`.
- Each team then merges through your normal git workflow (PRs, rebase).

## Running a pre-9.0 multi-squad vault

You have a vault built by the classic chain. It has `_meta/squads.yaml` with ≥2 squads, `interfaces/*.md` notes, and units carrying `squad:`.

### Step 1 — Migrate it to layout-3

9.0 reads layout-2 vaults but builds only on layout-3. Run `/mega-sdd` with no argument: the status view flags the vault and **proposes** the migration. It never runs it silently.

```
/mega-sdd:migrate-paths --vault-layout=3            # dry-run: shows what moves
/mega-sdd:migrate-paths --vault-layout=3 --apply    # executes (refuses a dirty tree)
```

The migration:

- folds `vault.md` / `model.md` / `flows.md` / `constraints.md` into `context.md`;
- archives the four docs, plus `binding.md` and the other layout-2 artefacts, verbatim under `<vault>/_meta/archive/layout2/`;
- splits `binding.md` per unit into `bolts/U-XXX/binding-migrated.json`, keeping every human CONFLICT resolution;
- rewrites each unit's `vault_source` to `context.md`.

It does **not** touch `_meta/squads.yaml`, `interfaces/`, or the units' squad fields.

It ends by printing the mandatory next step: a **full JIT re-bind**. Either run it now:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/rebind-units.sh" --cwd=. --vault=<vault> --units=all
```

or let `execute-bolts` bind each unit at run start (Step 2). Until a unit is re-bound, a CONFLICT it cites from the old `binding.md` still blocks it, unless its `binding-migrated.json` carries a recorded human resolution for that CONFLICT.

### Step 2 — Execute

```
/mega-sdd
```

The state engine sees units still to run and proposes:

```
Proposed pipeline (--deep):
  1. execute-bolts --all --lite
```

Invoked from one team's context (a dev's laptop, one role), run only that squad's units instead: `execute-bolts --squad=<answer>` (its units become the run's `--units`).

The run is inline: one context, plan order, an up-front bind and a re-bind at each task (pre-flight 3.9). At run start, `derive-exec-plan.sh` checks every `consumes_interfaces` entry. A unit whose interface is still `draft` is quarantined together with its dependents, the Karantina table names the producer squad, and the rest of the run goes on:

```
  Karantina: U-FE-002 cross_squad_interface_draft (api-patient-booking, producer squad-be) · U-FE-003 via U-FE-002
```

### Step 3 — The producer locks the interface

The producer squad reviews its note and sets `status: locked`:

```yaml
# <vault>/interfaces/api-patient-booking.md frontmatter:
---
id: api-patient-booking
producer: squad-be
consumers: [squad-fe-web]
kind: api
status: locked        # ← was: draft
# locked_at / locked_by: optional, your own bookkeeping
contract:
  endpoint: POST /api/appointments
  request: { patient_id, doctor_id, service_id, start_time }
  response: { appointment_id, status, confirmation_token }
  errors: 401, 422, 503
---
```

Then `/mega-sdd --resume`. The consumer squad's units proceed.

### Multi-machine

Each team can run only its own slice, on its own machine, and merge through normal git:

```bash
# Backend dev's machine — in Claude Code: "execute bolts --squad=squad-be"
# Frontend dev's machine — in Claude Code: "execute bolts --squad=squad-fe-web"
```

Every lane ends with the same result contract: the acceptance-criterion → test table, `delivery-check.sh` `VERDICT: PASS` on the final commit, and the assumptions and decisions made.

## Common pitfalls (migrated multi-squad vaults)

### cross_squad_dep_invalid halt

A unit's `depends_on` points to a unit in another squad without going through an interface note. `plan --regenerate` raises it while it re-writes units:

```yaml
blocker:
  type: cross_squad_dep_invalid
  details:
    unit_id: U-FE-005
    unit_squad: squad-fe-web
    dependency_id: U-BE-003
    dependency_squad: squad-be
```

Fix: remove the cross-squad `depends_on`. The producer unit declares `produces_interfaces`, the consumer declares `consumes_interfaces`, and both name an existing `interfaces/<id>.md`.

### interface_ref_missing halt

A unit names an interface ID with no `<vault>/interfaces/<id>.md` file. Fix the ID, or write the note by hand in the same frontmatter shape as the vault's existing notes (`id`, `producer`, `consumers`, `kind`, `status`, `contract`). There is no template.

### cross_squad_ambiguous halt

Two squads in `_meta/squads.yaml` claim the same artifact at the same precedence level. The precedence order is `owns_components` > `owns_flow_prefixes` > `owns_layers` > `owns_feature_tags`. Fix: make one squad's match more specific.

### cross_squad_interface_draft quarantine

The producer hasn't locked the interface, so `derive-exec-plan.sh` quarantines the consuming unit and its dependents at run start. The rest of the run continues, and the Karantina table names the interface and the producer squad. Fix: the producer sets `status: locked`, then run `execute-bolts` again.

### Unrouted units (`squad: default`)

A unit that matches no ownership rule gets `squad: default`. That is a warning, not a halt, and the unit still executes. To route it, refine `squads.yaml` or set `squad:` in the unit's frontmatter.

## What you learned

- Multi-squad **authoring** is retired in 9.0: nothing writes `squads.yaml` or `interfaces/` for a new vault.
- A pre-9.0 multi-squad vault still runs once migrated: `migrate-paths --vault-layout=3`, the mandatory re-bind, then `execute-bolts --all` or `--squad=<id>`, with the draft-interface quarantine at run start.
- For a new multi-team project, use one vault per PRD scope (Scenario 7) or modules with `execute-bolts --module=<id>`.

## Next scenario

→ [Scenario 6 — Recovery from halt](scenario-6-recovery-from-halt.md): bolt halted on Hard Rule violation; recover safely.
