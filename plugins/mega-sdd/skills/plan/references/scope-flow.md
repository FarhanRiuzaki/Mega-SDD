# plan — Scope flow (multi-scope PRD, `--scope`)

> Relocated from `skills/generate-intent/references/setup-flow.md` (§Step 0.9, §Scope-detection halt conditions), `skills/generate-intent/references/scope-picker.md` and `skills/generate-intent/references/multi-scope.md` in 9.0 (P1); tuned text kept verbatim.

Load when the PRD declares a `scopes:` block or `--scope=<id>` is passed. Owns the scope choice, the PRD filter, the `vault.json` scope tagging and the scope halt. A PRD without a `scopes:` block is single-scope: no picker, no scope tagging — only Step 0.9 c applies (`scope_inferred: single` in the patch + ONE delivery-report line).

## Contents

- Step 0.9 — Scope detection + PRD filtering
- Detection priority order
- Smart default heuristic
- --scope flag semantics
- Filter logic
- Sibling scope informational
- Prior-vault hit UX
- Anti-halu rails
- vault.json scope tagging (extension, field rules, validation rules, backward compatibility)
- Scope-detection halt conditions

## Step 0.9 — Scope detection + PRD filtering

Driven by the scope-picker rules below (§Detection priority order → §Anti-halu rails: filter logic + prior-vault default rules). Runs AFTER plan Step 0 (the script pins, incl. `prd_status`) and BEFORE the full source read of plan Step 1 — scope choice filters which PRD content gets loaded. `--scope=<id>` semantics: §--scope flag semantics.

a. **Read PRD frontmatter.** `scopes:` block present → step b; absent → step c.

b. **Canonical scope handling:**
   - Only one scope declared → silent route to legacy single-vault flow (no picker).
   - Multiple scopes declared:
     - `--scope=<id>` set → validate against declared scopes; **halt `scope_not_declared_in_prd`** if invalid (surface the PRD-declared scope list + cancel).
     - Else → `AskUserQuestion` with a lead line ("Memilih satu scope memfilter PRD ke bagian scope itu; scope lain bisa digenerate sebagai vault terpisah nanti."): one option per declared scope rendered as `<id> — <name/1-line summary from the PRD scopes: block>` (smart-default flagged per cwd heuristic) + "All scopes — satu vault gabungan (legacy; tidak ada filter per scope)" + "Cancel".
     - If the user chose `--scope=all` (legacy) → emit a warning, proceed with all content.
   - After scope chosen: filter PRD content per §Filter logic + persist the choice in `vault.json` (`scope` + `prd_sha256`, §Detection priority order step 6); tag `vault.json` with `scope` / `scope_metadata` through the `derive-vault-json.sh --patch` per §vault.json scope tagging (`prd_sha256` is the Step-0 pin the deriver mirrors from the `context.md` frontmatter); write `scope` / `scope_name` into the `context.md` frontmatter; render sibling-scope informational notes in `context.md ## Overview` (§Sibling scope informational).

c. **PRD without a `scopes:` block — single-scope, no ask.** Treat the PRD as single-scope, record `scope_inferred: single` in the vault.json patch, and add ONE delivery-report line offering the retrofit lane (`plan --regenerate --scope=<id>` after a manual `scopes:` block — plan Step 0 refuses an existing vault without `--regenerate`). This holds interactive and `--auto` alike: no retrofit prompt, no retrofit subagent.

## Detection priority order

```
1. Read PRD frontmatter
   - If `scopes:` block present → DETERMINISTIC: use as authoritative list
   - If `scopes:` block absent → continue to step 2

2. No `scopes:` block → single-scope (no ask, no retrofit subagent)
   - record `scope_inferred: single` in the vault.json patch
   - ONE delivery-report line: add a `scopes:` block by hand, then re-run `plan --regenerate --scope=<id>`

3. Determine scope choice (if multi-scope detected)
   - If `--scope=<id>` flag set → use that scope; halt `scope_not_declared_in_prd` if id not in scopes
   - Else if an EXISTING vault in this project carries the same `prd_sha256` + a `scope` (vault.json — the pipeline record) → suggest that scope as default + confirm-once
   - Else → AskUserQuestion with smart default (see §Smart default heuristic)

4. Filter PRD content per chosen scope
   - Include: universal_sections (from frontmatter) + chosen scope's declared sections
   - Include: cross_scope_dependencies (rendered as informational notes in vault)
   - Exclude: other scopes' specific sections (still cited as "sibling scopes" in context.md ## Overview)

5. Tag vault with scope metadata
   - vault.json: scope, scope_metadata, prd_sha256
   - context.md: frontmatter scope / scope_name + ## Overview sibling scopes note

6. The scope choice is persisted in the vault itself (step 5: vault.json `scope` + `prd_sha256`) — no side record.
```

## Smart default heuristic

When asking the user, recommend a scope based on signal strength:

| Signal | Confidence | Example |
|---|---|---|
| cwd basename matches `<project>-<scope>` | HIGH | `order-management-be/` → BE |
| cwd basename matches `<scope>-<project>` | HIGH | `be-order-mgmt/` → BE |
| cwd parent dir matches scope id | MEDIUM | `~/projects/order/be/` → BE |
| Composer/package.json filename hints | MEDIUM | composer.json + Laravel → likely BE |
| Existing vault with same prd_sha256 carries a scope | HIGH (if same cwd) | vault.json scope: BE → suggest BE |

Conflict resolution:
- If multiple signals match → use highest-confidence
- If signals contradict (existing vault says BE, cwd says FE) → surface BOTH options to user
- If no signals → present full scope list without "recommended" marker

## --scope flag semantics

| Flag | Behavior |
|---|---|
| `--scope=<id>` | Use that scope; halt if not in PRD scopes block |
| `--scope=all` | Legacy single-vault behavior — include ALL PRD content; emit warning |
| (flag absent) | Interactive picker per step 3 above |

## Filter logic

After scope choice, build the filtered PRD passed to plan's Step 1 read:

```
filtered_prd = ""
filtered_prd += frontmatter   # always include all frontmatter (mega-sdd reads metadata)

for section in PRD body:
    if section.heading in universal_sections:
        filtered_prd += section
    elif section.heading in chosen_scope.sections:
        filtered_prd += section
    else:
        # Skip — sibling scope section
        # Will be cited as informational in context.md ## Overview
        pass

# Always append cross_scope_dependencies as informational footer
filtered_prd += "## Cross-scope dependencies (informational only)\n"
for dep in PRD frontmatter.cross_scope_dependencies:
    if dep.from == chosen_scope or dep.to == chosen_scope:
        filtered_prd += f"- {dep}\n"
```

**Coverage (Step 5).** `validate-plan-coverage.sh` censuses the whole PRD file, not the filtered copy. Every heading of a sibling scope's sections therefore gets one `context.md ## Coverage exclusions` line, for example `- "<heading>" — scope <id>, planned in its own vault`. This is the one kind of line that declares a requirement: it belongs to another vault, and that vault's own plan must cover it (`plan/references/context-authoring.md §Coverage exclusions`).

## Sibling scope informational

When chosen_scope = BE and PRD has scopes = {BE, MW, FE}:

`context.md ## Overview` MUST include the note below as an H3 (on layout-3 an H2 is a section boundary). The note is sourced from the PRD `scopes:` block, so `## Overview` is written for it even when the PRD has no Background section:

```markdown
### Sibling scopes (managed externally — NOT in this vault)

- **MW** — Integration Middleware (PIC: <name>; priority: 2)
- **FE** — Frontend Web (PIC: <name>; priority: 3)

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault.
> Locked contracts cross-referenced in `vault.json` `scope_metadata` (`published_locked_contracts` / `consumed_locked_contracts`) for awareness, NOT enforcement.
```

## Prior-vault hit UX

When an existing vault carries the same PRD sha256 + a scope:

```
▶ PRD ./<path> recognized (sha256: <hash>...)
  Existing vault scope: <scope> (vault.json)

❓ Same scope this run?
   [Enter] <scope> (recommended — confirm-once)
   [2/3/4] Different scope
   [5] Cancel
```

When `--auto` flag set AND a prior-vault hit → silent default; do not prompt at all.

## Anti-halu rails

- NEVER silently re-use a prior vault's scope choice without showing it to user (except `--auto` mode)
- NEVER write to or substitute the PRD — a `scopes:` block is added by the author, by hand; the original stays untouched
- ALWAYS include cross_scope_dependencies notes when chosen_scope is involved (publisher OR consumer)

## vault.json scope tagging

When `plan` runs with `--scope=<id>` flag OR canonical PRD has `scopes:` block, the vault is tagged with scope metadata. Single-scope PRDs without scopes block use current single-vault schema (no scope tagging).

> **Patch-lane:** `title` / `scope` / `scope_metadata` are AUTHORED fields — supply them in the `--patch` JSON consumed by `scripts/derive-vault-json.sh` at plan Step 3 (never hand-write vault.json). `prd_sha256` / `prd_path_at_generation` are the Step-0 pins (`derive-plan-pins.sh`) written in the `context.md` frontmatter — the deriver mirrors them (md wins); never put them in the patch. The deriver carries the authored fields forward verbatim on every later derive; `prd_sha256` is the at-generation pin `diff-vault` compares against and is NEVER recomputed by the script.

### vault.json extension

```json
{
  "vault_version": "1.0",
  "title": "Order Management System — BE",
  "implementation_mode": "existing",
  "scope": "BE",
  "scope_metadata": {
    "id": "BE",
    "name": "Backend API",
    "pics": ["BE Architect 1", "BE Architect 2"],
    "priority": 1,
    "prd_sections_used": ["§Backend", "§1", "§2", "§3", "§4", "§5", "§6", "§7", "§9"],
    "sibling_scopes_in_prd": ["MW", "FE"],
    "consumed_locked_contracts": [],
    "published_locked_contracts": ["be-mw-event-bus", "be-fe-orders-api"]
  },
  "prd_sha256": "abc123...",
  "prd_path_at_generation": "./shared-docs/prd.md"
}
```

### Field rules

| Field | Required | Set by | Purpose |
|---|---|---|---|
| `scope` | When `scope_metadata` exists | plan Step 0.9 | Quick lookup; matches `scope_metadata.id` |
| `scope_metadata.id` | Yes | plan | Stable id from PRD frontmatter |
| `scope_metadata.name` | Yes | plan | Display name from PRD frontmatter |
| `scope_metadata.pics` | Yes | plan | Array of architect names (team-shared) |
| `scope_metadata.priority` | No (default 1) | plan | Delivery sequencing hint |
| `scope_metadata.prd_sections_used` | Yes | plan | Computed: universal_sections + scope.sections |
| `scope_metadata.sibling_scopes_in_prd` | Yes | plan | Other scopes from PRD (informational) |
| `scope_metadata.consumed_locked_contracts` | Yes | plan | From PRD scope's `depends_on_locked_contracts` |
| `scope_metadata.published_locked_contracts` | Yes | plan | Computed: contracts where this scope is `from` in `cross_scope_dependencies` |
| `prd_sha256` | Yes | plan Step 0 (`derive-plan-pins.sh`) | For the prior-vault scope default on re-invocation (§Detection priority order step 3) |
| `prd_path_at_generation` | Yes | plan Step 0 (`derive-plan-pins.sh`) | For PRD change tracking via diff-vault |

### Validation rules (enforced by plan when assembling the authored patch)

- If `scope` field present → `scope_metadata` MUST exist with all required fields
- `scope_metadata.id` MUST match PRD frontmatter `scopes.<id>` key
- `sibling_scopes_in_prd` MUST list ALL other scopes from PRD scopes block (not chosen ones)
- `prd_sha256` MUST be sha256 of PRD content at generation time (used by the prior-vault scope default) — computed once at Step 0 into the `context.md` frontmatter, which the deriver mirrors; later derives carry it forward, and only `diff-vault` re-baselines it
- When chosen scope == `all` (legacy flag) → patch omits the `scope` field (back-compat)

### Backward compatibility

- Vaults without a `scope` field → consumed unchanged by `plan --reconcile` + `execute-bolts` (JIT bind per unit)
- Mixed vaults (some scoped, some legacy) permitted in same project — orchestrate-flow handles both
- diff-vault reads `prd_sha256` to detect PRD changes; vaults without `prd_sha256` skip this check gracefully

## Scope-detection halt conditions

One halt fires during Step 0.9: `scope_not_declared_in_prd`. Classified ALWAYS STOP CHAIN by `orchestrate-flow` (requires human input). PRDs without a `scopes:` block never trigger it (step c). The retrofit-bridge halts (`prd_no_scopes_block_user_rejected_retrofit`, `prd_retrofit_low_confidence`) never fire from `plan`: there is no retrofit prompt and no retrofit subagent.

**Options keterangan (rendered by the halt displayer per the keterangan contract — codes stay English, descriptions Tier-2):** `re-pick-from-declared` — pilih ulang dari daftar scope yang PRD deklarasikan; `cancel` — berhenti, tidak ada vault yang ditulis.

### `scope_not_declared_in_prd`
Fires when `--scope=<id>` is set BUT the id is not in the PRD's `scopes:` frontmatter list.

```yaml
blocker:
  type: scope_not_declared_in_prd
  context: "Step 0.9 scope picker"
  requested_scope: "<id from flag>"
  declared_scopes: ["<id1>", "<id2>", ...]  # from PRD frontmatter
  options: ["re-pick-from-declared", "cancel"]
  resolver_route: user
```
