# generate-intent — `--auto`, handoff, memory & path resolution

## Contents
- `--auto` flag behavior
- Handoff emission (`--auto`)
- Memory layer
- Path resolution
- Outputs recap (multi-squad additions)

## `--auto` flag behavior

The `--auto` flag is set by upstream callers — typically `/mega-sdd:orchestrate-flow`, the lifecycle orchestrator — to skip logistical prompts. When `--auto` is set, the Workflow steps behave differently:

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (output path) | Ask the user via `AskUserQuestion` | Default to `.mega-sdd/vaults/<slug>/` (canonical per `plugins/mega-sdd/references/paths.md`) derived from the PRD project name (slug-cased). If the folder exists & is non-empty, **STILL ASK** (destructive — never auto-overwrite). Legacy default `docs/mega-sdd/vaults/<slug>/` only honored when the legacy layout is already detected on disk. |
| Step 0.5 (IMPLEMENTATION_MODE) | Ask | Infer from codebase signals: `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod` / etc. detected in CWD or vault parent → `existing`; else `new`. |
| Step 0.5 (`mode_migrate_after`, mode=new only) | Ask | Default to `"first commit on main"`. |
| Step 0.6 (PRD_STATUS) | Ask | Default to `draft` (safe default — generates more OQs, less assertion). |
| Step 0.7 (OUTPUT_MODE) | Ask | Default to `compact`. |
| Step 2 (gap-count push-back when PRD_STATUS=draft) | Pause if gap count > 10 | Skip the pause; dump all gaps to OQs (matches PRD_STATUS=final behavior). |

**What stays interactive even with `--auto`:**

- **Figma "do you have screenshots?" prompt** if Figma was referenced but no MCP loaded — must NOT invent UI structure.
- **Destructive overwrite confirmations** when the output folder exists and is non-empty.
- **PROJECT_SHAPE confirmation** if inference confidence is low (the skill's existing rule). Otherwise auto-confirm the inferred shape.

**What `--auto` does NOT do (anti-halu rails — NEVER bypass):**

- ❌ Auto-answer Open Questions or invent values for any field.
- ❌ Skip source citation requirements.
- ❌ Skip OQ tagging for gaps.
- ❌ Pretend the PRD is final when the stakeholder hasn't said so.

When the skill is invoked via the `Skill` tool without an explicit `--auto` argument, default to interactive. Only enter `--auto` mode when the caller explicitly passes it.

When `--auto` is active and the skill produces a P1 Open Question that would block downstream work, additionally emit a `blocker` artifact per `generate-intent/references/vault-contract.md §halt-protocol`. The orchestrator (or other autonomous caller) catches this and surfaces it to the human.

## Handoff emission (`--auto`)

When invoked with `--auto` (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`. The orchestrator parses this to decide auto-continue.

```yaml
handoff:
  emitted_by: generate-intent
  emitted_at: <ISO8601 timestamp>
  status: completed | paused | halted
  artifacts:
    - <absolute path to vault directory>
    - <absolute path to vault.json>
  next_action:
    suggested_skill: mega-sdd:scan-codebase     # if mode=existing (brownfield)
    # OR
    suggested_skill: mega-sdd:generate-units    # if mode=new (greenfield)
    suggested_args: ["--auto"]
    rationale: "<1-sentence why this is next>"
  blockers: []   # populated on halt
  metrics:
    items_processed: <N OQs generated>
    items_blocked: <N business-blocking OQs requiring stakeholder input>
  scope:                                  # when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from PRD>
  mutability:                             # when --kb mode produces mutability-tagged claims
    tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
    locked_claims_touched: []
    artifact_discards_proposed: <N>
  phase:                                  # phase fields for KB sub-mode phased rebuild
    phase: 1                              # which phase this vault represents (default 1)
    phase_total: 1                        # total phases planned per suggested-phasing.md (default 1)
```

Status `paused` when P1 business OQs are produced (downstream still works; the user should triage). Status `halted` on `oq_tech_missing_mode` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` / `oq_scan_missing_query`. Required ONLY under `--auto`; standalone invocations may emit informationally.

## Memory layer

When memory is enabled (default; opt-out via `--memory-off`), participate in the mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| At Step 0.5–0.7 flag setup | `~/.mega-sdd/memory/preferences.md` | Update flag tally: increment the count for the picked value (OUTPUT_MODE, PRD_STATUS, IMPLEMENTATION_MODE, PROJECT_SHAPE) |
| After OQ auto-classifier runs (Step 3.5) | `<vault>/.memory/classifier-accuracy.json` | Append a run entry with tags_emitted + user_overrides (when the user flips a tag in review) + accuracy_estimate |

### Reads

| What | Source | How used |
|---|---|---|
| Past flag picks for this user | `~/.mega-sdd/memory/preferences.md` | At Step 0.5–0.7: SUGGEST the default by pre-filling AskUserQuestion. Surface as "Past observed default: <value> (picked N/N times). Use? Y/N/Other" |
| Project conventions (test framework, naming) | `<project>/.mega-sdd/memory/conventions.md` | At Step 2 extraction: when generating tech OQs about conventions, set `resolution_mode: scan` with `scan_query: codebase-map §<convention>` (instead of `recommend`) since the convention is already established |
| Past classifier overrides on the same pattern | `<vault>/.memory/classifier-accuracy.json` | If a past pattern shows a consistent override `tech/recommend → business/blocking`, bias the new classifier toward `business/blocking` (per learning-rules.md §2.1) — SUGGEST not impose |

### Anti-halu rails

- All flag suggestions surface via AskUserQuestion; the user picks the final value.
- Convention-derived OQ downgrades cite the convention entry in the OQ rationale.
- Classifier biases never bypass the heuristic table; they pre-rank options for review.
- `--memory-off` disables both reads and writes.

## Path resolution

Per `plugins/mega-sdd/references/paths.md`:

- **Default vault path:** `<project-root>/.mega-sdd/vaults/<slug>/`
- **Legacy vault path:** `<project-root>/docs/mega-sdd/vaults/<slug>/`
- **Detection:** probe the `<project-root>/.mega-sdd/` directory + the `config.yaml layout:` field.
- **Slug derivation:** from the project name OR PRD title.
- **Read-side back-compat:** the skill probes both candidate dirs when resuming or diffing an existing vault.

## Outputs recap (multi-squad additions)

Additional outputs in multi-squad mode (≥2 squads), emitted per the setup-flow ref's §Multi-squad artifact emission (routed from the SKILL router):

- `_meta/squads.yaml` — squad partition declaration.
- `interfaces/_index.md` — cross-squad contract index (stub; the architect authors the actual contracts).
- `.obsidian/graph.json` — Obsidian graph-view defaults with squad color groups. EXTERNAL-INTEROP TERMINAL artifact (consumed by Obsidian when the user opens the vault there) — no mega-sdd skill reads it; that is by design, not a delivery gap.
