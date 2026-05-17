# Squad Subagent Fan-Out

Specifies how `execute-bolts --per-squad` spawns one Claude subagent per declared squad and consolidates their results.

## When this applies

- Flag `--per-squad` is set on `execute-bolts`
- `_meta/squads.yaml` exists with ≥2 squads

## Subagent dispatch

For each squad declared in `_meta/squads.yaml`, dispatch ONE subagent via the
Agent tool. Subagents run in parallel via `run_in_background: true` so all
squads work concurrently.

### Per-subagent invocation

```
Agent(
  subagent_type: "general-purpose",
  description: "Execute <squad-label> bolts",
  run_in_background: true,
  prompt: """
    You are executing mega-sdd bolts for ONE squad: <SQUAD_ID> (<SQUAD_LABEL>).

    Context:
    - Vault path: <ABSOLUTE_VAULT_PATH>
    - Squad config: <ABSOLUTE_VAULT_PATH>/_meta/squads.yaml
    - Your squad's units: filter <ABSOLUTE_VAULT_PATH>/units/U-*.md where
      `squad: <SQUAD_ID>` in the frontmatter.
    - Interfaces you produce: filter <ABSOLUTE_VAULT_PATH>/interfaces/*.md
      where `producer: <SQUAD_ID>`.
    - Interfaces you consume: filter where `consumers:` array contains `<SQUAD_ID>`.

    Your job:
    1. Load all units assigned to your squad.
    2. For each unit with `consumes_interfaces`, verify each interface has
       `status: locked`. If any are `draft`, HALT with cross_squad_interface_draft
       blocker and stop — do not proceed.
    3. Execute units sequentially in topological order of their `depends_on`
       (all deps are intra-squad by validation).
    4. Use the mega-sdd:execute-bolts skill (this same skill) recursively for
       each unit, but with a single unit ID argument (NOT --per-squad), and
       follow the existing TDD-first procedure with superpowers integration.
    5. Commit each bolt atomically per the existing protocol.
    6. Write bolt-report.md per unit.
    7. Report back when done: { squad: <id>, units_run: N, commits: M, halts: [...] }

    Anti-hallucination rules from the existing execute-bolts SKILL.md still
    apply verbatim (target_files whitelist, no --no-verify, etc.). The vault
    is shared single source of truth — do NOT modify any vault file (only
    units/<your-squad>/U-*.md frontmatter status fields are touchable by you).

    Halt protocol: emit standard blocker YAML if you must stop. Parent will
    consolidate halts from all squads.
  """
)
```

### Parent consolidation

After all subagents complete (or halt), the parent process:

1. Collects per-squad results
2. Builds a single summary table:

   ```
   Squad             Units run   Commits   Status
   ─────────────────────────────────────────────
   squad-be            12          12      OK
   squad-fe-web         8           7      HALT (test_fail on U-FE-005)
   squad-integrations   4           4      OK
   ─────────────────────────────────────────────
   Total:              24          23      1 halt
   ```

3. Lists each blocker verbatim
4. Surfaces to user for resolution

## Why fan out at squad level (not unit level)

The existing `--parallel` flag already fans out independent units within
a single execution stream via `subagent-driven-development`. `--per-squad`
adds a second layer: each squad runs its own parallel-units stream
inside its own subagent.

Combined: `--per-squad --parallel` → N squad subagents, each running
multiple unit subagents internally. Resource usage scales accordingly;
suitable for moderate-size projects (3-5 squads × 10-20 units each).

## Failure isolation

If one squad's subagent halts, others continue (run_in_background means
they don't share execution state). Each writes its own bolt-reports and
halt artifacts. Parent aggregates after all complete.

## Single-squad fallback

If user passes `--per-squad` but only one squad is declared: halt early
(per Procedure step 1 in SKILL.md). Don't spawn a single subagent for
no benefit — defer to plain `--all` or `--parallel`.
