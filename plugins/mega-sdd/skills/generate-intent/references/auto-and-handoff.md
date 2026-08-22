# generate-intent — `--auto`, handoff & path resolution

## Contents
- `--auto` flag behavior
- Handoff emission (`--auto`)
- Path resolution
- Outputs recap (multi-squad additions)

## `--auto` flag behavior

The `--auto` flag is set by upstream callers — typically `/mega-sdd`, the lifecycle orchestrator — to skip logistical prompts. When `--auto` is set, the Workflow steps behave differently:

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

When `--auto` is active and the skill produces a P1 Open Question that would block downstream work, additionally emit a `blocker` artifact per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`. The orchestrator (or other autonomous caller) catches this and surfaces it to the human.

## Handoff emission (`--auto`)

When invoked with `--auto` (typically by `orchestrate-flow --deep` or `/mega-sdd`), emit a handoff YAML record at the end of skill output per the local template below — the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index). The orchestrator parses this to decide auto-continue.

```yaml
handoff:
  emitted_by: generate-intent
  emitted_at: <ISO8601 timestamp>
  status: completed | paused | halted
  artifacts:
    - <absolute path to vault directory>
    - <absolute path to vault.json>
  next_action:
    # CWD-conditional on codebase-map presence — resolve at emission time (mirrors
    # scan-codebase's own handoff, scan-codebase/references/halts-flags-handoff.md
    # §next_action; grounded in routing-rules.md Decision matrix :53/:55). Under the
    # scan-first brownfield reorder (routing-rules.md :110/:115) scan-codebase runs
    # BEFORE generate-intent (invoked WITH --scan=<map>), so the codebase-map is
    # ALMOST ALWAYS already present here — bind-codebase is the common brownfield hop;
    # the scan-codebase branch fires only when no map exists on disk yet.
    suggested_skill: mega-sdd:bind-codebase     # mode=existing (brownfield) + codebase-map PRESENT (args: <vault> --auto — the norm under scan-first)
    # OR
    suggested_skill: mega-sdd:scan-codebase     # mode=existing (brownfield) + NO codebase-map on disk yet
    # OR
    suggested_skill: mega-sdd:generate-units    # mode=new (greenfield)
    suggested_args: ["--auto"]                  # bind-codebase branch prepends a leading <vault>: ["<vault>", "--auto"] (orchestrator reconstructs <vault> from CWD/artifacts); scan-codebase/generate-units take ["--auto"] as-is
    rationale: "<1-sentence why this is next>"
  blockers: []   # populated on halt
  metrics:
    items_processed: <N OQs generated>
    items_blocked: <N business-blocking OQs requiring stakeholder input>
    flows_with_stages: <N>              # OPTIONAL — staged-input flows carried into the vault (generation-guide.md §staged inputs); type-checked when present, never required on absence; a staged-input drop surfaces as ADVISORY vault_flow_staging_drop, not a halt
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
