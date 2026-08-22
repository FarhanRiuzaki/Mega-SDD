# Scope Picker Algorithm

Reference for `generate-intent` Step 0.9 scope detection + filtering. Companion to `multi-scope.md` (this directory; the §Multi-scope vault scope-tagging schema).

> **Step numbering note**: Step 0.9 (not 0.6) because Step 0.6 is taken by the PRD_STATUS flag. Scope detection runs AFTER all Step 0.x metadata config and BEFORE Step 1 Load PRD.

## Contents

- Detection priority order
- Smart default heuristic
- --scope flag semantics
- Filter logic
- Sibling scope informational
- Memory hit UX
- Anti-halu rails
- Edge cases handled

## Detection priority order

```
1. Read PRD frontmatter
   - If `scopes:` block present → DETERMINISTIC: use as authoritative list
   - If `scopes:` block absent → continue to step 2

2. Trigger interactive bridge (legacy retrofit)
   - User chooses: [retrofit / single-scope / cancel]
   - On retrofit: AI analyzes PRD content → proposes scopes + sections
                 → writes <prd>.retrofit.md (preserves original)
                 → restart from step 1 with retrofit file
   - On single-scope: route to legacy single-vault flow (current behavior)

3. Determine scope choice (if multi-scope detected)
   - If `--scope=<id>` flag set → use that scope; halt `scope_not_declared_in_prd` if id not in scopes
   - Else if memory has prior choice for this PRD sha256 + cwd basename matches → silent default + confirm-once
   - Else → AskUserQuestion with smart default (see §Smart default heuristic)

4. Filter PRD content per chosen scope
   - Include: universal_sections (from frontmatter) + chosen scope's declared sections
   - Include: cross_scope_dependencies (rendered as informational notes in vault)
   - Exclude: other scopes' specific sections (still cited as "sibling scopes" in vault.md)

5. Tag vault with scope metadata
   - vault.json: scope, scope_metadata, prd_sha256
   - vault.md: scope header + sibling scopes notes + locked contracts

6. Persist scope choice to memory
   - `<project>/.mega-sdd/memory/decisions.md` §PRD Scope Decisions
   - Increment override_count if user switched scope on same PRD
```

## Smart default heuristic

When asking the user, recommend a scope based on signal strength:

| Signal | Confidence | Example |
|---|---|---|
| cwd basename matches `<project>-<scope>` | HIGH | `order-management-be/` → BE |
| cwd basename matches `<scope>-<project>` | HIGH | `be-order-mgmt/` → BE |
| cwd parent dir matches scope id | MEDIUM | `~/projects/order/be/` → BE |
| Composer/package.json filename hints | MEDIUM | composer.json + Laravel → likely BE |
| Memory: last scope used on this PRD sha256 | HIGH (if same cwd) | matches BE → suggest BE |

Conflict resolution:
- If multiple signals match → use highest-confidence
- If signals contradict (memory says BE, cwd says FE) → surface BOTH options to user
- If no signals → present full scope list without "recommended" marker

## --scope flag semantics

| Flag | Behavior |
|---|---|
| `--scope=<id>` | Use that scope; halt if not in PRD scopes block |
| `--scope=all` | Legacy single-vault behavior — include ALL PRD content; emit warning |
| (flag absent) | Interactive picker per step 3 above |

## Filter logic

After scope choice, build the filtered PRD passed to generate-intent's main parser:

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
        # Will be cited as informational in vault.md
        pass

# Always append cross_scope_dependencies as informational footer
filtered_prd += "## Cross-scope dependencies (informational only)\n"
for dep in PRD frontmatter.cross_scope_dependencies:
    if dep.from == chosen_scope or dep.to == chosen_scope:
        filtered_prd += f"- {dep}\n"
```

## Sibling scope informational

When chosen_scope = BE and PRD has scopes = {BE, MW, FE}:

vault.md MUST include:

```markdown
## Sibling scopes (managed externally — NOT in this vault)

- **MW** — Integration Middleware (PIC: <name>; priority: 2)
- **FE** — Frontend Web (PIC: <name>; priority: 3)

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault.
> Locked contracts cross-referenced below for awareness, NOT enforcement.
```

## Memory hit UX

When PRD sha256 found in memory + cwd matches last invocation:

```
▶ PRD ./<path> recognized (sha256: <hash>...)
  Last scope used: <scope> (<date>)

❓ Same scope this run?
   [Enter] <scope> (default after 5s; confirm-once)
   [2/3/4] Different scope
   [5] Cancel
```

Confirm-once timeout default: 5 seconds. Configurable via `--scope-confirm-timeout=N` (rarely needed).

When `--auto` flag set AND memory hit → silent default; do not prompt at all.

## Anti-halu rails

- NEVER silently re-use memory's scope choice without showing it to user (except `--auto` mode)
- NEVER auto-substitute retrofit file path — user explicitly invokes with retrofit file
- NEVER write to memory if user cancels picker
- ALWAYS include cross_scope_dependencies notes when chosen_scope is involved (publisher OR consumer)
- ALWAYS preserve original PRD when generating retrofit; new file written, original untouched

## Edge cases handled

See `generate-intent/SKILL.md` Halt conditions for halt types:
- `scope_not_declared_in_prd`
- `prd_no_scopes_block_user_rejected_retrofit`
- `prd_retrofit_low_confidence`
