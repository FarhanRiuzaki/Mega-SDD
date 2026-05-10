# v0.14 Flow Orchestrator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the multi-skill lifecycle orchestrator (`/grand-design-spec:flow`) per the spec at `docs/superpowers/specs/2026-05-10-flow-orchestrator-design.md` so the plugin v0.14.0 can ship with end-to-end agentic chaining while preserving anti-halu rails.

**Architecture:** Documentation/skill-instruction edits only — no runtime code. New top-level skill (`flow`) plus `--auto` flag plumbing in 4 existing skills. A new `§halt-protocol` section in the shared `vault-contract.md` unifies the v0.11 `OQ_BLOCKER` artifact with two new sibling types (`diff_conflict`, `drift_framework_mismatch`). Each task is a focused edit, ending in an atomic commit. Order is dependency-aware: contract first (Task 1) so all downstream skills can reference it; sub-skills next (Tasks 2–6); orchestrator skill + command (Tasks 7–8); user-facing docs (Task 9); version bump + CHANGELOG last (Task 10).

**Tech Stack:** Markdown, YAML frontmatter. No build tooling. Skill orchestration via the `Skill` tool inside Claude Code.

**Source spec:** `docs/superpowers/specs/2026-05-10-flow-orchestrator-design.md`

**Decisions locked from spec:**
- `blocker:` envelope (no namespace prefix, per OQ-FLOW-2 — short and the document context establishes scope)
- Plan editing in `flow` v0.1: only `skip step N` and `stop after step N` (per spec Section 3)
- Stateless orchestrator — no `.gds-state.json`
- Backward-compat: AI consumers should accept both `oq_blocker:` (v0.13 form) and `blocker: type: oq_blocker` (v0.14 form) for one release cycle

---

## File Structure

| File | Action | Why |
|------|--------|-----|
| `plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md` | Modify | Add §halt-protocol section with unified `blocker` envelope |
| `plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md` | Modify | Replace `oq_blocker:` YAML examples with `blocker: type: oq_blocker` form |
| `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md` | Modify | Add §--auto-flag section before Workflow; bump version 0.9.0 → 0.10.0 |
| `plugins/grand-design-spec/skills/resolve-oq/SKILL.md` | Modify | Add §--auto-flag section; bump version 0.3.0 → 0.4.0 |
| `plugins/grand-design-spec/skills/vault-diff/SKILL.md` | Modify | Add §--auto-flag section + diff_conflict blocker emit; bump version 0.2.0 → 0.3.0 |
| `plugins/grand-design-spec/skills/drift-detect/SKILL.md` | Modify | Add §--auto-flag section; bump version 0.2.0 → 0.3.0 |
| `plugins/grand-design-spec/skills/flow/SKILL.md` | **Create** | The orchestrator skill |
| `plugins/grand-design-spec/commands/flow.md` | **Create** | Slash command wrapper |
| `README.md` | Modify | Add `/grand-design-spec:flow` row to commands table; update repo structure with `flow/` skill dir; update Changelog footer |
| `plugins/grand-design-spec/README.md` | Modify | Add flow row to skills+commands table; update Lifecycle diagram |
| `CONTRIBUTING.md` | Modify | Add `--auto` flag convention as required for any future skill |
| `plugins/grand-design-spec/.claude-plugin/plugin.json` | Modify | Version 0.13.0 → 0.14.0 |
| `.claude-plugin/marketplace.json` | Modify | Version 0.13.0 → 0.14.0 |
| `CHANGELOG.md` | Modify | Add v0.14.0 entry with skill version moves |

10 commits total. 2 new files, 12 modified files.

---

## Task 1: Add §halt-protocol to vault-contract.md

**Files:**
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md`

Add the unified `blocker` envelope as a new section in the shared contract. All sub-skills will reference this section instead of inlining their own envelopes.

- [ ] **Step 1: Add §halt-protocol section after §id-stability**

The contract currently ends with `## §id-stability — ID conventions`. Use the Edit tool to append the new section.

OLD STRING (the last few lines of the file):
```
## §id-stability — ID conventions

Across all skills, these identifiers are **stable across rounds**:

- `OQ-{CODE}-{N}` — Open Question tag.
- `F-{prefix}-NNN` — Flow ID. Prefixes: `F-U-` (user), `F-S-` (system/backend), `F-C-` (cross-cutting), `F-P-` (pipeline), `F-X-` (custom).
- `D-NNN` — ADR ID.
- Entity names — DBML table names; preserve casing across edits.

When a sibling skill creates new entries, use **next-available** number, never reuse.
```

NEW STRING:
```
## §id-stability — ID conventions

Across all skills, these identifiers are **stable across rounds**:

- `OQ-{CODE}-{N}` — Open Question tag.
- `F-{prefix}-NNN` — Flow ID. Prefixes: `F-U-` (user), `F-S-` (system/backend), `F-C-` (cross-cutting), `F-P-` (pipeline), `F-X-` (custom).
- `D-NNN` — ADR ID.
- Entity names — DBML table names; preserve casing across edits.

When a sibling skill creates new entries, use **next-available** number, never reuse.

## §halt-protocol — Unified `blocker` envelope (v0.14)

When a skill running in `--auto` mode hits something that requires human judgment (unresolved P1 OQ blocking downstream work, vault-diff conflict, framework mismatch), it emits a structured YAML artifact called a **blocker**. The orchestrator (`/grand-design-spec:flow`) catches blockers, pauses the chain, and surfaces the artifact in chat for the user to act on.

The envelope is uniform across types so a single consumer can handle all of them.

### Schema

```yaml
blocker:
  type: oq_blocker | diff_conflict | drift_framework_mismatch
  tag: <stable identifier — OQ-AR-1, D-007, etc.>
  priority: P1 | P2 | P3 | n/a
  context: "<what's blocked, e.g. 'Implementing F-U-001 backend' or 'Applying vault-diff Step 6'>"
  resolver_owner: "<name or role, e.g. 'Mike Patel (Eng Lead)'>"
  resolver_route: "<where to find them, e.g. 'ask in #timeoff-team'>"
  vault_version: "<current vault version, e.g. '1.1'>"
  source_skill: grand-design-spec | vault-diff | drift-detect
  # type-specific fields below
  conflict_old: "<vault state>"            # diff_conflict only
  conflict_new: "<new PRD state>"          # diff_conflict only
  options: ["supersede", "keep_vault", "capture_both"]  # diff_conflict only
  detected_framework: "<e.g. 'Java/Spring'>"  # drift_framework_mismatch only
  expected_framework: "<e.g. 'PHP/Laravel'>"  # drift_framework_mismatch only
```

### Type-specific guidance

**`oq_blocker`** — emitted by `grand-design-spec` (when generation surfaces a P1 that would block downstream tasks) or by AI consumers reading the vault non-interactively. The `tag` is the OQ identifier. `priority` is always `P1` (lower priorities don't halt).

**`diff_conflict`** — emitted by `vault-diff` Step 5 when a Resolved-OQ conflict or Decision conflict requires stakeholder input. `tag` is the OQ or ADR ID. `priority` is `n/a` (conflicts aren't priority-tagged). `conflict_old`, `conflict_new`, `options` are required.

**`drift_framework_mismatch`** — emitted by `drift-detect` Step 1.5 when the vault implies one framework but the codebase is another. `tag` is `n/a`. `priority` is `n/a`. `detected_framework` and `expected_framework` are required.

### Multiple blockers in one run

For multiple blockers in a single sub-skill run, emit an array:

```yaml
blockers:
  - type: oq_blocker
    tag: OQ-AR-1
    priority: P1
    context: "Implementing F-U-001 backend"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.0"
    source_skill: grand-design-spec
  - type: diff_conflict
    tag: OQ-DC-2
    priority: n/a
    context: "Applying vault-diff to PRD-v2.pdf"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.1"
    source_skill: vault-diff
    conflict_old: "Idempotency 24h TTL (D-010)"
    conflict_new: "Idempotency 7d TTL (PRD §X.Y)"
    options: ["supersede", "keep_vault", "capture_both"]
```

### Backward compatibility

Vaults generated under v0.13 still emit the legacy `oq_blocker:` YAML form (without the unified envelope). AI consumers reading vaults should accept both shapes for one release cycle:

```yaml
# Legacy v0.13 form (still valid):
oq_blocker:
  tag: OQ-AR-1
  priority: P1
  ...

# New v0.14 form:
blocker:
  type: oq_blocker
  tag: OQ-AR-1
  priority: P1
  ...
```

Vaults regenerated under v0.14+ produce only the new form.

### Field rules

- `tag` mirrors the markdown identifier (OQ tag, ADR ID, or `n/a`). Never invent.
- `resolver_owner` is best-effort; use `null` if not declared in the OQ entry.
- `vault_version` is the current vault version at emit time, not the target post-resolution version.
- `source_skill` identifies the emitting skill — needed because consumers may dispatch differently per source.
- `context` is human-readable; keep it short (one line). It's not a structured field.
- For `diff_conflict`, `options` MUST list the user choices verbatim from the diff report (e.g., "supersede", "keep_vault", "capture_both").
```

- [ ] **Step 2: Verify section added**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -n "§halt-protocol" plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md
grep -n "type: oq_blocker | diff_conflict | drift_framework_mismatch" plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md
grep -c "Backward compatibility" plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md
```

Expected:
- 1 hit for "§halt-protocol"
- 1 hit for the type enum
- 1 hit for "Backward compatibility"

- [ ] **Step 3: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(v0.14): add §halt-protocol to vault-contract.md

Unified blocker envelope replacing v0.11 OQ_BLOCKER. Three types:
- oq_blocker (per v0.11)
- diff_conflict (new — for vault-diff Resolved-OQ + Decision conflicts)
- drift_framework_mismatch (new — for drift-detect framework collisions)

All emit a uniform `blocker:` YAML so the new flow orchestrator can
catch them with one parser. Backward compat: AI consumers should
accept legacy oq_blocker: form for one release cycle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Update 00-index.md template Halt protocol section

**Files:**
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md`

Replace the `oq_blocker:` YAML examples with the unified `blocker:` envelope. AI consumers reading newly-generated vaults will see the new form.

- [ ] **Step 1: Replace the Halt protocol section**

Use the Edit tool.

OLD STRING:
```
### Halt protocol for autonomous runs (v0.11)

In **interactive mode** (chat with a human), "STOP and ask user" works fine — surface the issue in chat and wait. In **autonomous mode** (agent runners, CI tasks, headless workflows), silent halt loses the signal. Instead, emit a structured `OQ_BLOCKER` artifact so the runner can route it.

When you hit an unresolved P1 OQ that blocks your current task, emit (in addition to any chat response):

```yaml
oq_blocker:
  tag: OQ-AR-1
  priority: P1
  category: "Tech stack & architecture"
  blocking_task: "Implementing F-U-001 backend"
  resolver_owner: "Mike Patel (Eng Lead)"
  resolver_route: "ask in PM Slack channel #timeoff-team or via PRD §L review"
  vault_version: "1.0"
  doc: "02-architecture.md"
```

For multiple blockers in one task, emit an array:

```yaml
oq_blockers:
  - tag: OQ-AR-1
    priority: P1
    blocking_task: "Implementing F-U-001 backend"
    resolver_owner: "Mike Patel"
  - tag: OQ-DM-1
    priority: P1
    blocking_task: "Implementing F-U-001 backend"
    resolver_owner: "Mike Patel + security"
```

The agent runner decides what to do (page resolver, create ticket, post to Slack). The skill's job is to emit the structured artifact reliably — don't paraphrase, don't drop fields.
```

NEW STRING:
```
### Halt protocol for autonomous runs (v0.11, unified envelope v0.14)

In **interactive mode** (chat with a human), "STOP and ask user" works fine — surface the issue in chat and wait. In **autonomous mode** (agent runners, CI tasks, headless workflows, the `flow` orchestrator), silent halt loses the signal. Instead, emit a structured `blocker` artifact so the runner can route it.

The unified envelope (per `references/vault-contract.md` §halt-protocol) covers three blocker types: `oq_blocker` (unresolved P1 OQ), `diff_conflict` (vault-diff conflict), and `drift_framework_mismatch` (drift-detect framework mismatch).

When you hit an unresolved P1 OQ that blocks your current task, emit (in addition to any chat response):

```yaml
blocker:
  type: oq_blocker
  tag: OQ-AR-1
  priority: P1
  context: "Implementing F-U-001 backend"
  resolver_owner: "Mike Patel (Eng Lead)"
  resolver_route: "ask in PM Slack channel #timeoff-team or via PRD §L review"
  vault_version: "1.0"
  source_skill: grand-design-spec
```

For multiple blockers in one task, emit an array:

```yaml
blockers:
  - type: oq_blocker
    tag: OQ-AR-1
    priority: P1
    context: "Implementing F-U-001 backend"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.0"
    source_skill: grand-design-spec
  - type: oq_blocker
    tag: OQ-DM-1
    priority: P1
    context: "Implementing F-U-001 backend"
    resolver_owner: "Mike Patel + security"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.0"
    source_skill: grand-design-spec
```

The agent runner decides what to do (page resolver, create ticket, post to Slack). The skill's job is to emit the structured artifact reliably — don't paraphrase, don't drop fields. See `references/vault-contract.md` §halt-protocol for the full schema and the two non-OQ types (`diff_conflict`, `drift_framework_mismatch`).

> **Backward compat note (v0.11→v0.14)**: vaults generated under v0.13 emit `oq_blocker:` (legacy form). AI consumers should accept both `oq_blocker:` and `blocker: type: oq_blocker` shapes for one release cycle.
```

- [ ] **Step 2: Verify edit**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -n "blocker:" plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md
grep -n "type: oq_blocker" plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md
grep -c "oq_blocker:" plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md
grep -c "Backward compat note" plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md
```

Expected:
- ≥3 hits for `blocker:` (envelope + two examples)
- ≥3 hits for `type: oq_blocker`
- 1 hit for `oq_blocker:` only inside the backward-compat note (legacy reference)
- 1 hit for "Backward compat note"

- [ ] **Step 3: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md
git commit -m "$(cat <<'EOF'
feat(v0.14): update 00-index template halt protocol to unified blocker

Migrates the OQ_BLOCKER YAML emission examples from the legacy
oq_blocker: shape (v0.11) to the unified blocker: type: oq_blocker
shape (v0.14) defined in vault-contract.md §halt-protocol.

Newly-generated vaults will instruct AI consumers in the new form.
Backward-compat note added so consumers know to accept both shapes
during the transition cycle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: grand-design-spec skill — add `--auto` flag (0.9.0 → 0.10.0)

**Files:**
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md`

Add a top-level `## --auto flag` section before `## Workflow`. Existing Step 0–0.7 prose stays — the new section overrides their interactive behavior when `--auto` is set.

- [ ] **Step 1: Bump frontmatter version**

Use Edit tool. Replace:
```
version: 0.9.0
```
With:
```
version: 0.10.0
```

- [ ] **Step 2: Add --auto flag section before Workflow**

Find the line `## Workflow`. Insert a new section before it.

OLD STRING:
```
If critical inputs are missing or unclear, **ask before generating**. Better 5 upfront questions than 7 docs of guesses.

---

## Workflow
```

NEW STRING:
```
If critical inputs are missing or unclear, **ask before generating**. Better 5 upfront questions than 7 docs of guesses.

---

## --auto flag (v0.10+)

The `--auto` flag is set by upstream callers — typically `/grand-design-spec:flow`, the lifecycle orchestrator — to skip logistical prompts. When `--auto` is set, the Workflow steps below behave differently:

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (output path) | Ask user via `AskUserQuestion` | Default to `./<slug>-spec/` derived from PRD project name (slug-cased). If folder exists & non-empty, **STILL ASK** (destructive — never auto-overwrite). |
| Step 0.5 (IMPLEMENTATION_MODE) | Ask | Infer from codebase signals: `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod` / etc. detected in CWD or vault parent → `existing`; else `new`. |
| Step 0.5 (`mode_migrate_after`, mode=new only) | Ask | Default to `"first commit on main"`. |
| Step 0.6 (PRD_STATUS) | Ask | Default to `draft` (safe default — generates more OQs, less assertion). |
| Step 0.7 (OUTPUT_MODE) | Ask | Default to `compact`. |
| Step 2 (gap-count push-back when PRD_STATUS=draft) | Pause if gap count > 10 | Skip the pause; dump all gaps to OQs (matches PRD_STATUS=final behavior). |

What stays interactive even with `--auto`:

- **Figma "do you have screenshots?" prompt** if Figma was referenced but no MCP loaded — must NOT invent UI structure.
- **Destructive overwrite confirmations** when output folder exists and is non-empty.
- **PROJECT_SHAPE confirmation** if inference confidence is low (skill's existing rule). Otherwise auto-confirm the inferred shape.

What `--auto` does NOT do (anti-halu rails — NEVER bypass):

- ❌ Auto-answer Open Questions or invent values for any field.
- ❌ Skip source citation requirements.
- ❌ Skip OQ tagging for gaps.
- ❌ Pretend the PRD is final when stakeholder hasn't said so.

When the skill is invoked via the `Skill` tool without an explicit `--auto` argument, default to interactive (current v0.9 behavior). Only enter `--auto` mode when the caller explicitly passes it.

When `--auto` is active and the skill produces a P1 Open Question that would block downstream work, additionally emit a `blocker` artifact per `references/vault-contract.md` §halt-protocol. The orchestrator (or other autonomous caller) catches this and surfaces it to the human.

---

## Workflow
```

- [ ] **Step 3: Verify edits applied**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -n "version: 0.10.0" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md
grep -n "## --auto flag" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md
grep -c "anti-halu rails — NEVER bypass" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md
grep -n "§halt-protocol" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md
```

Expected:
- `version: 0.10.0` at line 3
- `## --auto flag` at exactly 1 line (the new section header)
- 1 hit for "anti-halu rails — NEVER bypass"
- ≥1 hit for §halt-protocol

- [ ] **Step 4: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/grand-design-spec/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.14): grand-design-spec skill 0.9.0 → 0.10.0 — add --auto flag

Adds a §--auto-flag section before Workflow that overrides Step 0-0.7
interactive prompts with deterministic defaults when called from
upstream orchestrator (/grand-design-spec:flow).

Hard rails preserved: --auto NEVER bypasses Figma "do you have
screenshots?" question, destructive overwrite confirmations, OQ
tagging, or source citation. P1 OQs that would block downstream
work emit a blocker artifact per vault-contract.md §halt-protocol.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: resolve-oq skill — add `--auto` flag (0.3.0 → 0.4.0)

**Files:**
- Modify: `plugins/grand-design-spec/skills/resolve-oq/SKILL.md`

Add `--auto` only for logistical prompts (vault path, resume detection, scope, lock ack). Per-OQ Resolve/OOS/Defer choices STAY interactive — that's the substance prompt.

- [ ] **Step 1: Bump frontmatter version**

Use Edit tool. Replace `version: 0.3.0` with `version: 0.4.0`.

- [ ] **Step 2: Add --auto section before Workflow**

Find the line `## Workflow`. Insert before it.

OLD STRING:
```
This preserves auditability — anyone reviewing the vault later can trace each OQ tag from its origin in the PRD gap analysis to its final resolution.

## Resolution outcomes
```

NEW STRING:
```
This preserves auditability — anyone reviewing the vault later can trace each OQ tag from its origin in the PRD gap analysis to its final resolution.

## --auto flag (v0.4+)

The `--auto` flag is passed by upstream callers (typically `/grand-design-spec:flow`) to skip **logistical** prompts only. **Substance prompts — per-OQ Resolve / Out-of-Scope / Defer / Skip choices — ALWAYS stay interactive.** That's the entire point of this skill: capturing stakeholder answers, not Claude's guesses.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (vault location) | Ask via `AskUserQuestion` | If exactly 1 vault detected in CWD, use it without prompting. If 0 or >1, ask (or fail loudly if called with `--auto` from a non-orchestrator context). |
| Step 0 (lock check, if `Status: 🔒 LOCKED`) | Ask user to confirm unlock | Default to "proceed if DRAFT" (no unlock implied). If LOCKED, **STILL ASK** — unlocking has audit consequences. |
| Step 0.5 (resume detection) | Ask continue / fresh / cancel | Default to "continue from current state". |
| Step 0.6 (resolution scope) | Ask scope | Default to `p1-only`. |
| Step 2 (per-OQ Resolve/OOS/Defer/Skip) | **Always ask** | **Always ask** (substance prompt — no override) |
| Step 2c (cross-cutting multi-doc landing) | Ask user to confirm primary doc | Always ask (substance prompt — landing affects content placement) |

What stays interactive even with `--auto`:

- **Per-OQ choice** (Resolve / OOS / Defer / Skip) — captures stakeholder answers; never auto-decides.
- **Resolution destination override** when auto-classification is wrong.
- **Cross-cutting OQ landing prompts** — affects which doc the answer lives in.
- **LOCKED vault unlock confirmation** — audit-significant.

When this skill is invoked without `--auto`, behavior is unchanged from v0.3.

---

## Resolution outcomes
```

- [ ] **Step 3: Verify**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -n "version: 0.4.0" plugins/grand-design-spec/skills/resolve-oq/SKILL.md
grep -n "## --auto flag" plugins/grand-design-spec/skills/resolve-oq/SKILL.md
grep -c "Substance prompts" plugins/grand-design-spec/skills/resolve-oq/SKILL.md
```

Expected:
- `version: 0.4.0` at line 3
- 1 hit for `## --auto flag`
- 1 hit for "Substance prompts"

- [ ] **Step 4: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/resolve-oq/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.14): resolve-oq skill 0.3.0 → 0.4.0 — add --auto for logistics

Adds §--auto-flag that overrides logistical prompts (vault path,
resume detection, resolution scope, lock-state ack default) when
called from /grand-design-spec:flow. Substance prompts — per-OQ
Resolve/OOS/Defer/Skip choice, cross-cutting landing — ALWAYS stay
interactive. That's the anti-halu rail: this skill captures
stakeholder answers, never auto-decides.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: vault-diff skill — add `--auto` flag + diff_conflict blocker (0.2.0 → 0.3.0)

**Files:**
- Modify: `plugins/grand-design-spec/skills/vault-diff/SKILL.md`

Two changes: add `--auto` flag handling, add `blocker` (type=`diff_conflict`) emit when conflicts hit in `--auto` mode.

- [ ] **Step 1: Bump frontmatter version**

Replace `version: 0.2.0` with `version: 0.3.0`.

- [ ] **Step 2: Add --auto section before Workflow**

Find `## Workflow`. Insert before it.

OLD STRING:
```
| **Unchanged** | Old vault content is still accurate per new PRD. | No-op. | No. |

## Workflow
```

NEW STRING:
```
| **Unchanged** | Old vault content is still accurate per new PRD. | No-op. | No. |

## --auto flag (v0.3+)

The `--auto` flag is passed by upstream callers (typically `/grand-design-spec:flow`) to skip logistical prompts. **Substance prompts — Resolved-OQ conflicts and Decision conflicts — ALWAYS stay interactive OR emit a blocker artifact.** Conflicts represent disagreement between vault state and new source; auto-deciding would silently overwrite stakeholder choices.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (vault path) | Auto-detect or ask | Use auto-detected if exactly 1 vault in CWD. |
| Step 0 (git safety check) | Ask if uncommitted | Continue but record uncommitted state in the diff report's metadata. |
| Step 0.5 (diff scope) | Ask | Default to `full`. |
| Step 1 (old source path) | Ask once | Skip — use vault-state-only. |
| Step 5 (per-conflict resolution) | Ask Supersede/Keep/Both/Skip | **Emit `blocker` (type=`diff_conflict`)** per conflict and pause. Caller decides next steps. |
| Step 5 (auto-resolved OQs batch confirm) | Ask "Apply all / one-by-one / skip" | Default to "Apply all". |
| Step 5 (added/changed/removed batch confirm) | Ask | Auto-apply if total change count ≤ 50; otherwise pause and emit `blocker` (type=`diff_conflict`, tag=`OQ-FLOW-3-cap`, context="change count exceeds auto-apply cap"). |
| Step 6 (apply changes Y/N) | Ask | Skip — apply approved (non-conflict) changes. |
| Step 7 (vault version bump type) | Ask patch vs minor | Use heuristic: minor if any conflicts had user input OR added entities/flows ≥ 5; patch otherwise. |

What stays interactive even with `--auto`:

- **Resolved-OQ conflicts** — emit `blocker` per conflict, never auto-decide.
- **Decision conflicts** — same.
- **Major scope shift detection** — push-back rule from existing skill (e.g., >50% entity churn) still triggers.
- **LOCKED vault confirmation** — destructive, audit-significant.

### `diff_conflict` blocker emission

When a conflict is hit in `--auto` mode, instead of `AskUserQuestion`, emit:

```yaml
blocker:
  type: diff_conflict
  tag: <OQ-DC-2 | D-007 | etc.>
  priority: n/a
  context: "<e.g. 'vault-diff Step 5: Resolved-OQ conflict on idempotency strategy'>"
  resolver_owner: "<from vault metadata or null>"
  resolver_route: "<from vault metadata or null>"
  vault_version: "<current>"
  source_skill: vault-diff
  conflict_old: "<vault state, verbatim from VAULT-DIFF.md>"
  conflict_new: "<new PRD state, verbatim from VAULT-DIFF.md>"
  options: ["supersede", "keep_vault", "capture_both"]
```

After emit, halt the apply phase. The diff report (`VAULT-DIFF.md`) is still written with the conflict surfaced. The caller (orchestrator or human) handles resolution and re-invokes `vault-diff` (without `--auto`) to walk it interactively.

When this skill is invoked without `--auto`, behavior is unchanged from v0.2.

---

## Workflow
```

- [ ] **Step 3: Verify**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -n "version: 0.3.0" plugins/grand-design-spec/skills/vault-diff/SKILL.md
grep -n "## --auto flag" plugins/grand-design-spec/skills/vault-diff/SKILL.md
grep -c "diff_conflict" plugins/grand-design-spec/skills/vault-diff/SKILL.md
grep -c "blocker:" plugins/grand-design-spec/skills/vault-diff/SKILL.md
```

Expected:
- `version: 0.3.0` at line 3
- 1 hit for `## --auto flag`
- ≥3 hits for `diff_conflict`
- ≥1 hit for `blocker:`

- [ ] **Step 4: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/vault-diff/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.14): vault-diff skill 0.2.0 → 0.3.0 — --auto + diff_conflict

Adds §--auto-flag with logistical defaults (full scope, vault-state-
only, auto-apply non-conflict changes ≤ 50). Conflict resolution
ALWAYS pauses: emits blocker (type=diff_conflict) per the unified
envelope in vault-contract.md §halt-protocol.

Major scope shift push-back, LOCKED vault confirmation, and the
"auto-resolve all conflicts" refusal stay intact.

Auto-apply cap of 50 changes per OQ-FLOW-3 spec decision.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: drift-detect skill — add `--auto` flag (0.2.0 → 0.3.0)

**Files:**
- Modify: `plugins/grand-design-spec/skills/drift-detect/SKILL.md`

drift-detect is read-only by design. `--auto` mostly means "skip the interactive walkthrough; just write the report".

- [ ] **Step 1: Bump frontmatter version**

Replace `version: 0.2.0` with `version: 0.3.0`.

- [ ] **Step 2: Add --auto section before Workflow**

Find `## Workflow`. Insert before it.

OLD STRING:
```
Each finding carries a **confidence**: `high` (exact name + type match found / not-found), `medium` (similar names but different signatures), `low` (heuristic guess based on keyword search).

## Workflow
```

NEW STRING:
```
Each finding carries a **confidence**: `high` (exact name + type match found / not-found), `medium` (similar names but different signatures), `low` (heuristic guess based on keyword search).

## --auto flag (v0.3+)

The `--auto` flag is passed by upstream callers (typically `/grand-design-spec:flow`) to skip logistical prompts and the optional Step 5 interactive walkthrough.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (vault path) | Ask | Auto-detect from CWD if exactly 1. |
| Step 0 (codebase path) | Ask | If CWD obviously a code repo (has `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod`), use CWD. Otherwise REQUIRE explicit arg — never guess. |
| Step 0 (mode=new bail-out) | Surface migration trigger | Same — but emit `blocker` (type=`drift_framework_mismatch` if trigger isn't detectable, OR refuse cleanly with a structured message). |
| Step 0.5 (drift scope) | Ask | Default to `full`. |
| Step 1.5 (framework detection) | Auto-detect, propose scope dirs, ask user to confirm | Auto-confirm if confidence high (single framework signature found). If multi-framework or ambiguous → emit `blocker` (type=`drift_framework_mismatch`). |
| Step 5 (interactive walkthrough) | Ask "walk now / save report only / cancel" | **Skip walkthrough.** Write `DRIFT-REPORT.md`. Surface top 3 PRIORITY-1 findings in chat. **Do NOT generate `DRIFT-ACTIONS.md`** — the action list is a deliberate human decision. |

What stays interactive even with `--auto`:

- **Major framework mismatch warning** — when vault implies one stack but codebase is another (e.g., vault says Java/Spring, code is PHP). Emits `blocker` per Step 0/1.5. Never assume vault is wrong.
- **mode=new bail-out** — drift-detect refuses cleanly when vault is `mode=new`; this is a hard rule that `--auto` doesn't change.

### `drift_framework_mismatch` blocker emission

When framework detection fails or finds a mismatch with vault expectations:

```yaml
blocker:
  type: drift_framework_mismatch
  tag: n/a
  priority: n/a
  context: "<e.g. 'drift-detect Step 1.5: vault implies Java/Spring per 02-architecture; codebase is PHP/Laravel per composer.json'>"
  resolver_owner: null
  resolver_route: null
  vault_version: "<current>"
  source_skill: drift-detect
  detected_framework: "<e.g. 'PHP/Laravel'>"
  expected_framework: "<e.g. 'Java/Spring'>"
```

After emit, the skill stops. No `DRIFT-REPORT.md` is generated for the mismatched scope. Caller decides whether to override scope or correct vault.

What `--auto` does NOT do:

- ❌ Generate `DRIFT-ACTIONS.md` (deliberate human decision; `--auto` only writes reports).
- ❌ Modify vault content (drift-detect is read-only by design).
- ❌ Open PRs or run code changes.

When this skill is invoked without `--auto`, behavior is unchanged from v0.2.

---

## Workflow
```

- [ ] **Step 3: Verify**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -n "version: 0.3.0" plugins/grand-design-spec/skills/drift-detect/SKILL.md
grep -n "## --auto flag" plugins/grand-design-spec/skills/drift-detect/SKILL.md
grep -c "drift_framework_mismatch" plugins/grand-design-spec/skills/drift-detect/SKILL.md
grep -c "DRIFT-ACTIONS.md" plugins/grand-design-spec/skills/drift-detect/SKILL.md
```

Expected:
- `version: 0.3.0` at line 3
- 1 hit for `## --auto flag`
- ≥3 hits for `drift_framework_mismatch`
- ≥2 hits for `DRIFT-ACTIONS.md`

- [ ] **Step 4: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/drift-detect/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.14): drift-detect skill 0.2.0 → 0.3.0 — add --auto flag

Adds §--auto-flag that defaults to full scope, auto-confirms framework
detection when high confidence, skips Step 5 interactive walkthrough
(writes DRIFT-REPORT.md only — no DRIFT-ACTIONS.md, deliberate human
decision). Framework mismatch emits blocker (type=drift_framework_
mismatch) per the unified envelope.

Read-only invariant preserved: --auto NEVER edits the vault or the
codebase.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Create flow/SKILL.md

**Files:**
- Create: `plugins/grand-design-spec/skills/flow/SKILL.md`

The orchestrator skill itself. ~250 lines covering identity, principle, workflow (inspect/propose/confirm/execute/report), decision matrix, halt handling, and references.

- [ ] **Step 1: Create the skill directory and file**

Use the Write tool. Create the file with this EXACT content (everything between START/END markers, exclusive):

START-OF-FILE-CONTENT
---
name: flow
version: 0.1.0
description: Multi-skill lifecycle orchestrator for grand-design-spec. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms with user once, then executes the chain in --auto mode. Triggers — "run the flow", "orchestrate vault lifecycle", "auto vault", "do the next thing", or paraphrases.
---

# Flow — Lifecycle Orchestrator

Multi-skill orchestrator for `grand-design-spec`. Inspects CWD, builds a proposed chain of sub-skill invocations, confirms with the user once, then executes the chain with sub-skills in `--auto` mode. Removes the friction of remembering which skill to invoke for which lifecycle event while preserving every anti-hallucination rail in the sub-skills.

> **Skill instruction language**: this skill is written in English for reasoning quality. Chat prompts (proposed plan, final summary) adapt to the user's language at runtime. Per `references/vault-contract.md` §boilerplate.

## When to use this skill

Trigger this skill for:

- "run the flow" / "auto vault" / "run grand-design-spec end to end"
- "do the next thing" / "what's next?" (ambiguous lifecycle position)
- "orchestrate" / "chain the skills" / "lifecycle round"
- The user has just received a new PRD revision and wants the natural next steps to happen automatically.
- The user has finished a stakeholder meeting and wants OQ resolution + downstream impact checks in one shot.

Do NOT use this skill when:

- Only one specific skill is needed (e.g., "just resolve OQs"). Prefer the direct invocation.
- The vault is in an unusual state the user wants to handle manually.
- The user explicitly wants to walk through a step interactively without `--auto` shortcuts.

## Core principle

> **The orchestrator routes; sub-skills produce content. Never the other way around.**

The orchestrator inspects state, proposes a plan, dispatches sub-skills with `--auto` flags. It does NOT:

- Generate vault content.
- Auto-answer Open Questions.
- Auto-resolve diff conflicts.
- Auto-fill anything stakeholders need to decide.

Anti-halu rails live in the sub-skills, untouched. The orchestrator's job is sequencing — nothing more.

## Workflow

### Step 0: Inputs

Accept arguments:

- **No args** → operate on CWD.
- **One arg = directory path** → operate on this vault.
- **One arg = file path** (`.pdf`/`.docx`/`.md`) → bias toward "vault-diff this PRD against the closest vault in CWD".

Persist:

- `WORK_DIR=<resolved CWD>`
- `EXPLICIT_VAULT_PATH=<path or null>`
- `EXPLICIT_PRD_PATH=<path or null>`

If WORK_DIR is empty (no files at all) and no args, STOP and tell the user: *"No vault, no PRD detected. Point me at one: `/grand-design-spec:flow ./vault-dir/` or `/grand-design-spec:flow PRD-v2.pdf`."*

### Step 1: CWD inspection

Run deterministic state reading. No LLM judgment in this step.

| Signal | How detected | What it tells us |
|--------|--------------|------------------|
| Vault present? | Look for a directory in WORK_DIR (or EXPLICIT_VAULT_PATH) containing all 7 files (`00-index.md` through `06-constraints.md`) | Generate vs evolve |
| `vault.json` present? | File next to the 7 .md files | Pre- or post-v0.11 vault |
| Vault metadata | Parse `00-index.md` Vault Lock Status: `Implementation mode`, `PRD source` filename + version, last `Vault version`, `mode_migrate_after` | Lifecycle position |
| PRD/source files | PDF/DOCX/MD files in WORK_DIR or EXPLICIT_PRD_PATH. Compare filename/version to vault's `PRD source` | New PRD revision? |
| Codebase signals | `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod` / `requirements.txt` / `pubspec.yaml` in WORK_DIR or vault parent | Is `mode=existing` actionable? |
| Unresolved P1 count | `vault.json.open_questions_summary.by_priority.P1` (or grep `[ ] **OQ-...** [P1]` across docs 01-06 if vault.json missing) | Resolve-oq needed? |
| Mode migration trigger fired? | `mode_migrate_after` from Vault Lock Status. Auto-detectable: `"first commit on main"` (check `git log --reverse | head -1`). Not auto-detectable: `"first prod deploy"` / `"sprint-1 demo"` (require human knowledge — note as such in plan) | mode=new vault about to flip? |
| Git state | `git log --oneline -1` and `git status` in WORK_DIR | Safety nudges in summary |

Persist findings as a structured state object that Step 2 reads.

### Step 2: Build proposed chain

Apply the decision matrix in order. First match wins; conditional chains add subsequent steps when their preconditions are met.

```
RULE 1 — IF no vault AND PRD detected:
    → propose: grand-design-spec (generate)
    → optional chain: resolve-oq (offered as opt-in in confirmation, since user may not have stakeholder answers yet)

RULE 2 — IF vault exists AND new PRD detected
    (filename or version differs from vault's PRD source):
    → propose: vault-diff
    → conditional chain: resolve-oq IF vault-diff is expected to introduce ≥1 new P1 OQ
      (heuristic estimate from PRD content delta; surfaced as estimate in plan)

RULE 3 — IF vault exists AND vault.json missing:
    → propose: grand-design-spec re-run with vault's existing flags (regenerates manifest)

RULE 4 — IF vault exists AND P1 count > 0 AND no new PRD:
    → propose: resolve-oq (scope=p1-only)

RULE 5 — IF vault exists AND mode=existing AND codebase detected:
    → propose: drift-detect
    → conditional chain: resolve-oq IF drift findings produce vault-side actions

RULE 6 — IF vault exists AND mode=new AND mode_migrate_after trigger has fired:
    → propose: vault-diff with mode flip prompt OR manual edit instruction
      (only if trigger is auto-detectable — e.g., "first commit on main")

RULE 7 — IF nothing matched:
    → STOP, surface "no vault or PRD found, or no actionable state — point me at a PRD or vault dir"
```

**Hard cap**: max 3 skills per chain. If the matrix produces more than 3, surface and ask for explicit confirmation before proceeding.

**Lifecycle order is fixed**: generate → diff → resolve → drift. Never out of order.

### Step 3: Present plan + single confirmation

Format the plan per this template (placeholders filled from Step 1 findings):

```
grand-design-spec:flow — proposed chain

Detected state:
  • Vault: <path> (v<version>, mode=<new|existing>, output_mode=<compact|full>, prd_status=<draft|final>)
  • PRD source on file: <filename> (vault was generated from this)
  • New PRD candidate: <filename> (<reason: different filename → new revision | same filename, different version | etc.>)
  • vault.json: <present (in sync) | missing (will regenerate) | stale (vault older than json)>
  • Unresolved P1 OQs: <count>
  • Codebase: <detected (<framework>) | not detected (mode=<x>, no codebase signals in CWD)>

Plan (<N> steps):
  [1] <skill-name> <args>
        Why: <rule-derived reason>
        --auto mode: <yes | NO (always interactive — captures stakeholder answers)>
        <skill-specific note>

  [2] <skill-name> ...
        Why: <conditional rationale>
        ...

  [3] <skill-name> — SKIPPED
        Why: <why this rule didn't fire>

Proceed? [y / edit / cancel]
```

Use a single `AskUserQuestion` with three options:

- **`Run as proposed`** (default) — execute the chain.
- **`Edit plan`** — accept free-text input. v0.1 supports only `skip step N` and `stop after step N`. Anything else → ask for clarification, then re-confirm.
- **`Cancel`** — exit, no actions taken.

If user picks **Edit plan** with valid syntax (`skip 2` / `stop after 1`), apply the edit silently and re-display the modified plan with another single `AskUserQuestion` (`Run / Edit again / Cancel`).

### Step 4: Execute chain

For each confirmed step, in order:

1. Echo the step header: `[Step N/M] <skill name> — starting`
2. Dispatch the sub-skill via the `Skill` tool, passing args + `--auto` flag where applicable. **Sub-skills that don't have `--auto` (`resolve-oq` for substance, but `--auto` still skips its logistical prompts) are dispatched with the same flag — each sub-skill decides what `--auto` means for itself.**
3. Capture sub-skill outcome:
   - **DONE** → log one-line summary, move to next step.
   - **DONE_WITH_CONCERNS** → log summary + concerns, continue.
   - **BLOCKED** → log error, stop chain.
   - **`blocker` artifact emitted** (any `type`) → log summary, pause chain, capture YAML for the final summary.
4. After each step, append a one-line summary for the final report.

**No re-prompts between steps.** Sub-skills handle their own substance prompts.

**Two exceptions where the chain pauses for human input:**

- **`resolve-oq` step**: this skill is *always* interactive on per-OQ choices (substance prompts). Orchestrator hands off; resolve-oq prompts as normal; control returns when resolve-oq's Step 5 finishes. The chain continues from there.
- **Sub-skill emits `blocker` (any type) in `--auto`**: orchestrator catches it, surfaces the YAML in chat verbatim (don't paraphrase, don't drop fields), pauses chain at this step. Final summary marks the step ⏸. User can resume by re-invoking `flow` after manual fix.

### Step 5: Final summary

**Always emit, regardless of completion or pause.**

```
flow <complete | paused | failed>

Steps executed:
  ✓ [1] <skill-name>: <one-line outcome>
  ⏸ [2] <skill-name>: <partial outcome — paused on blocker / user exit>
  – [3] <skill-name>: skipped (<reason>)

Vault state: <path> (v<version>)
Unpushed commits: <count>
Pending blockers: <count + summary, e.g. "3 P1 OQs unresolved · 1 DIFF_CONFLICT in 05-decisions">
Next suggested step: <heuristic-only suggestion>
```

The "Next suggested step" line is a heuristic — **never auto-executed**. It's a hint for the user to act on if they want.

If any blockers were emitted during the chain, append the verbatim YAML(s) below the summary:

```
Blockers surfaced:

blocker:
  type: ...
  tag: ...
  ...

(repeat for each blocker)
```

## Decision matrix (deterministic — Step 2 detail)

The 7 rules above are the canonical statement. Implementation notes:

- **Rule precedence**: rules are checked top-to-bottom; first match builds the base step. Conditional chains (Rule 2's "+ resolve-oq if new P1s", Rule 5's "+ resolve-oq if vault-side actions") add subsequent steps to the base.
- **Inference must be cheap**: Step 1 reads files, runs grep, runs `git log` once. Don't run sub-skills speculatively to predict their output.
- **Estimates are best-effort**: "vault-diff likely introduces N new P1 OQs" is a heuristic from PRD-content delta inspection. Surface the estimate but don't block on its accuracy.
- **Rule 7 is the safety net**: if no rule fires, STOP cleanly. Don't propose nothing — surface the empty state.

## --auto dispatch semantics

When `flow` dispatches a sub-skill, it passes the `--auto` flag along with skill-specific args. Each sub-skill defines its own `--auto` semantics — see each skill's §--auto-flag section. Common contract:

- `--auto` skips **logistical** prompts (paths, modes, scopes, format choices that have a defensible default).
- `--auto` NEVER skips **substance** prompts (stakeholder answers, conflict resolutions, content-affecting choices).
- `--auto` NEVER auto-fills content (no inventing answers, no auto-resolving conflicts).
- `--auto` HALTS with structured `blocker` artifact when blocked.

`flow` is the canonical caller of `--auto`. Other autonomous callers (CI tasks, agent runners) can also pass `--auto`; the contract is uniform.

## Halt handling

The orchestrator catches `blocker` artifacts (per `references/vault-contract.md` §halt-protocol). Three types:

- **`oq_blocker`** — sub-skill hit an unresolved P1 OQ that blocks downstream work.
- **`diff_conflict`** — `vault-diff` hit a Resolved-OQ or Decision conflict needing user input.
- **`drift_framework_mismatch`** — `drift-detect` found a framework mismatch needing user confirmation.

When caught:

1. Pause chain at the step that emitted.
2. Surface the YAML in chat **verbatim** (don't paraphrase, don't drop fields, don't reformat).
3. In Step 5 final summary, mark the step ⏸ (paused) and append the YAML in the "Blockers surfaced" section.
4. Suggest the appropriate resolution path:
   - `oq_blocker` → re-invoke `flow` after stakeholder follow-up; `resolve-oq` will pick up the OQ.
   - `diff_conflict` → re-invoke `vault-diff` directly (without `--auto`) to walk the conflict interactively.
   - `drift_framework_mismatch` → manual investigation; vault may have been generated against a different repo.

## Quality bar

- **Inspectability**: user sees the proposed chain before any sub-skill runs. No silent multi-skill execution.
- **Stateless**: no `.gds-state.json`. Resumption = re-invoke `flow`. Each call re-inspects CWD.
- **Hands-off mid-chain**: once a chain is confirmed, orchestrator only pauses for substance prompts (resolve-oq's per-OQ choices) or `blocker` artifacts. Logistical prompts never fire.
- **No content invention**: orchestrator emits no vault content. Routing only.
- **Anti-halu preserved by composition**: every anti-halu rail lives in a sub-skill. Orchestrator is a thin layer over them.

## What `flow` does NOT do

- ❌ Auto-resolve OQs (`resolve-oq` stays fully interactive on substance).
- ❌ Auto-pick a side on conflicts (`vault-diff` emits `blocker`; orchestrator pauses).
- ❌ Generate content of any kind.
- ❌ Modify the vault directly — only sub-skills do that.
- ❌ Persist state (no `.gds-state.json`). Resumption = re-running `flow`.
- ❌ Push to remote.
- ❌ Run skills in parallel (sequential only — sub-skills may race on the vault otherwise).
- ❌ Override an existing skill's substance behavior — `--auto` is a skip-logistics flag, not a bypass.

## When to push back on the user

### Always

- **No vault and no PRD detected** → STOP, ask for an explicit path. Don't guess.
- **User says "auto-resolve all conflicts"** → refuse. The orchestrator routes; conflicts halt; humans decide.
- **User picks Edit plan with malformed syntax** → ask for clarification, then re-confirm. Don't apply ambiguous edits.
- **More than 3 skills in proposed chain** → surface and ask for explicit confirmation. Hard cap.

### Conditional

- **mode=new vault and `mode_migrate_after` trigger appears to have fired but flag is ambiguous (e.g., "sprint-1 demo")** → ask the user, don't auto-flip.
- **Multiple new PRD candidates in WORK_DIR** → surface them in the plan, ask user which one is canonical.
- **Vault is LOCKED** → refuse to proceed in `--auto` for any step that would unlock it. Sub-skills handle this individually; orchestrator just doesn't override.

## References

- Schema, OQ conventions, halt protocol: `../grand-design-spec/references/vault-contract.md` (§schema, §OQ-conventions, §halt-protocol).
- Sub-skill behavior contracts:
  - `../grand-design-spec/SKILL.md` (vault generation + §--auto-flag)
  - `../resolve-oq/SKILL.md` (OQ resolution + §--auto-flag)
  - `../vault-diff/SKILL.md` (vault evolution + §--auto-flag + diff_conflict blocker)
  - `../drift-detect/SKILL.md` (drift detection + §--auto-flag + drift_framework_mismatch blocker)
END-OF-FILE-CONTENT

- [ ] **Step 2: Verify**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
ls -la plugins/grand-design-spec/skills/flow/SKILL.md
wc -l plugins/grand-design-spec/skills/flow/SKILL.md
grep -c "## Workflow\|## Core principle\|## Decision matrix\|## --auto dispatch semantics\|## Halt handling\|## Quality bar\|## When to push back\|## References" plugins/grand-design-spec/skills/flow/SKILL.md
grep -n "version: 0.1.0" plugins/grand-design-spec/skills/flow/SKILL.md
```

Expected:
- file exists, ~250 lines, ~12-15K
- ≥7 hits for the section headers grep
- `version: 0.1.0` at line 3

- [ ] **Step 3: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/flow/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.14): add flow orchestrator skill (0.1.0)

New top-level skill /grand-design-spec:flow that inspects CWD, builds
a proposed chain of sub-skill invocations (generate / resolve-oq /
vault-diff / drift-detect), confirms once with the user, then
executes the chain in --auto mode.

Stateless. No content generation. Pauses on blocker artifacts (per
vault-contract.md §halt-protocol). Hard cap of 3 skills per chain.
Anti-halu invariants preserved by composition — every rail lives in
a sub-skill.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Create commands/flow.md

**Files:**
- Create: `plugins/grand-design-spec/commands/flow.md`

Slash command wrapper, similar to the existing 4. Makes `flow` appear in `/grand-design-spec:` autocomplete.

- [ ] **Step 1: Create the command file**

Use Write tool. Content (everything between START/END markers, exclusive):

START-OF-FILE-CONTENT
---
description: Multi-skill lifecycle orchestrator. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms once, then executes in --auto mode.
argument-hint: [optional vault-path or PRD-path]
---

Invoke the `grand-design-spec:flow` skill via the Skill tool to orchestrate a lifecycle round across the grand-design-spec sub-skills.

User arguments (vault-path, PRD-path, or empty for CWD auto-detect): $ARGUMENTS

Follow the skill exactly:

- Step 0: parse args, persist `WORK_DIR`, `EXPLICIT_VAULT_PATH`, `EXPLICIT_PRD_PATH`.
- Step 1: deterministic CWD inspection (vault detection, PRD detection, vault metadata, codebase signals, P1 count, mode-migration trigger, git state).
- Step 2: build proposed chain via the 7-rule decision matrix. Hard cap of 3 skills.
- Step 3: present plan + single `AskUserQuestion` (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only.
- Step 4: execute chain by dispatching sub-skills with `--auto` flag. Pause on `blocker` artifacts (any type) per vault-contract.md §halt-protocol. `resolve-oq` step is always interactive on per-OQ choices.
- Step 5: emit final summary with completed/paused/skipped per step + verbatim blocker YAMLs if any.

Hard rails:
- No content generation by the orchestrator itself.
- No state file (`.gds-state.json` is explicitly out of scope — resumption = re-invoke `flow`).
- No skill runs in parallel.
- Sub-skill substance prompts (per-OQ choices, conflict resolutions) ALWAYS surface to human.
END-OF-FILE-CONTENT

- [ ] **Step 2: Verify**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
ls -la plugins/grand-design-spec/commands/flow.md
grep -n "description:" plugins/grand-design-spec/commands/flow.md
grep -c "argument-hint:" plugins/grand-design-spec/commands/flow.md
```

Expected:
- file exists, ~1KB
- 1 hit for `description:`
- 1 hit for `argument-hint:`

- [ ] **Step 3: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/commands/flow.md
git commit -m "$(cat <<'EOF'
feat(v0.14): add /grand-design-spec:flow slash command

Thin wrapper around the new flow orchestrator skill so it appears
in the / autocomplete menu alongside the existing 5 commands
(grand-design-spec, resolve-oq, vault-diff, drift-detect, update).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update READMEs + CONTRIBUTING.md

**Files:**
- Modify: `README.md`
- Modify: `plugins/grand-design-spec/README.md`
- Modify: `CONTRIBUTING.md`

User-facing documentation sync. Add `flow` to commands tables, repo structure, lifecycle diagram. Add `--auto` convention note to CONTRIBUTING.md.

- [ ] **Step 1: Add flow to root README commands table**

Find the table starting `| Slash command | Use when | Skill |`. Use Edit tool.

OLD STRING:
```
| Slash command | Use when | Skill |
|---------------|----------|-------|
| `/grand-design-spec:grand-design-spec` | Initial vault from PRD/BRD/Figma | vault generator |
| `/grand-design-spec:resolve-oq` | Stakeholder meeting answered some OQs | OQ resolver |
| `/grand-design-spec:vault-diff` | PRD got a new version | vault evolution |
| `/grand-design-spec:drift-detect` | `mode=existing` — reconcile against live codebase | vault ↔ code drift |
| `/grand-design-spec:update` | Pull latest plugin from `origin/main` and refresh cache | plugin maintenance |

The four lifecycle skills share the vault as state. They preserve OQ tag identity, ADR `D-XXX` numbering, and Changelog history across rounds. `update` is a maintenance command (no vault interaction).
```

NEW STRING:
```
| Slash command | Use when | Skill |
|---------------|----------|-------|
| `/grand-design-spec:flow` ⭐ (v0.14) | "Do the next thing" — inspects state, proposes a chain, runs sub-skills with `--auto` | lifecycle orchestrator |
| `/grand-design-spec:grand-design-spec` | Initial vault from PRD/BRD/Figma | vault generator |
| `/grand-design-spec:resolve-oq` | Stakeholder meeting answered some OQs | OQ resolver |
| `/grand-design-spec:vault-diff` | PRD got a new version | vault evolution |
| `/grand-design-spec:drift-detect` | `mode=existing` — reconcile against live codebase | vault ↔ code drift |
| `/grand-design-spec:update` | Pull latest plugin from `origin/main` and refresh cache | plugin maintenance |

The four lifecycle skills share the vault as state. `flow` orchestrates them — inspects CWD, proposes a chain (e.g., "vault-diff → resolve-oq for new P1s"), confirms once, runs the chain in `--auto` mode while preserving every anti-halu rail. They all preserve OQ tag identity, ADR `D-XXX` numbering, and Changelog history across rounds. `update` is a maintenance command (no vault interaction).
```

- [ ] **Step 2: Update root README repo structure**

Find the repo structure block. Use Edit tool.

OLD STRING:
```
│       ├── commands/                         # user-typeable slash commands
│       │   ├── grand-design-spec.md          # → main vault generator skill
│       │   ├── resolve-oq.md                 # → OQ resolver skill
│       │   ├── vault-diff.md                 # → vault evolution skill
│       │   ├── drift-detect.md               # → vault ↔ code drift skill
│       │   └── update.md                     # plugin maintenance: git pull + cache nudge
│       ├── skills/
│       │   ├── grand-design-spec/            # main skill — vault generation
│       │   │   ├── SKILL.md
│       │   │   └── references/
│       │   │       ├── vault-contract.md     # shared schema + OQ + ID conventions (v0.13)
│       │   │       └── templates/*.md        # 7 scaffolds (compact/full markers, v0.13)
│       │   ├── resolve-oq/                   # companion skill — OQ resolution
│       │   │   └── SKILL.md
│       │   ├── vault-diff/                   # companion skill — vault evolution
│       │   │   └── SKILL.md
│       │   └── drift-detect/                 # companion skill — vault vs codebase
│       │       └── SKILL.md
```

NEW STRING:
```
│       ├── commands/                         # user-typeable slash commands
│       │   ├── flow.md                       # → orchestrator skill (v0.14)
│       │   ├── grand-design-spec.md          # → main vault generator skill
│       │   ├── resolve-oq.md                 # → OQ resolver skill
│       │   ├── vault-diff.md                 # → vault evolution skill
│       │   ├── drift-detect.md               # → vault ↔ code drift skill
│       │   └── update.md                     # plugin maintenance: git pull + cache nudge
│       ├── skills/
│       │   ├── flow/                         # orchestrator skill (v0.14)
│       │   │   └── SKILL.md
│       │   ├── grand-design-spec/            # main skill — vault generation
│       │   │   ├── SKILL.md
│       │   │   └── references/
│       │   │       ├── vault-contract.md     # shared schema + OQ + ID + halt-protocol (v0.13/v0.14)
│       │   │       └── templates/*.md        # 7 scaffolds (compact/full markers, v0.13)
│       │   ├── resolve-oq/                   # companion skill — OQ resolution
│       │   │   └── SKILL.md
│       │   ├── vault-diff/                   # companion skill — vault evolution
│       │   │   └── SKILL.md
│       │   └── drift-detect/                 # companion skill — vault vs codebase
│       │       └── SKILL.md
```

- [ ] **Step 3: Update root README Changelog footer**

OLD STRING:
```
## Changelog

See [CHANGELOG.md](./CHANGELOG.md). Latest: **v0.13.0** — closes 3 HIGH and 4 MED ship-readiness audit findings: `vault-diff` now refreshes `vault.json` after applying changes (the v0.11 parity gap), `drift-detect` documents its no-auto-regen boundary, `lock-vault` forward-references replaced with manual-edit instructions, and a shared `references/vault-contract.md` becomes the single source of truth for the JSON schema and OQ conventions. Templates gain `<!-- compact-skip -->` / `<!-- full-only -->` markers replacing 5 memorized runtime transformations. New [`CONTRIBUTING.md`](./CONTRIBUTING.md) documents independent skill semver. Earlier highlights: v0.12.x exposed lifecycle skills as slash commands; v0.11 introduced `vault.json` + `OQ_BLOCKER` halt protocol + mode-migration trigger.
```

NEW STRING:
```
## Changelog

See [CHANGELOG.md](./CHANGELOG.md). Latest: **v0.14.0** — adds `/grand-design-spec:flow`, the multi-skill lifecycle orchestrator. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms with user once, then executes in `--auto` mode. Existing skills gain a `--auto` flag that skips logistical prompts but never substance prompts (anti-halu rails preserved by composition). The v0.11 `OQ_BLOCKER` halt-artifact unifies into a `blocker` envelope with new `diff_conflict` and `drift_framework_mismatch` types. Earlier highlights: v0.13 closed audit findings + extracted shared `vault-contract.md`; v0.12.x exposed lifecycle skills as slash commands; v0.11 introduced `vault.json` + halt protocol + mode-migration trigger.
```

- [ ] **Step 4: Update plugin README skills+commands table**

Find the table in `plugins/grand-design-spec/README.md`.

OLD STRING:
```
## Skills + commands in this plugin

| Slash command | Skill | Purpose |
|---------------|-------|---------|
| `/grand-design-spec:grand-design-spec` | **`grand-design-spec`** | Initial vault generation. PRD/BRD/Figma → 7-file dev handoff folder with anti-hallucination guarantees. Also writes a `vault.json` manifest for machine consumption. |
| `/grand-design-spec:resolve-oq` | **`resolve-oq`** | Interactive Open Questions resolver. Walks the OQ roll-up by priority, captures stakeholder answers, updates the vault with version bump + Changelog. Preserves OQ tag identity as audit trail. Cross-cutting OQs land in a primary doc with cross-refs in others. |
| `/grand-design-spec:vault-diff` | **`vault-diff`** | Vault evolution when the PRD/BRD source revisions. Computes structured diff, surfaces conflicts (Resolved-OQ vs new PRD, ADR vs new PRD) for explicit user resolution, applies approved changes without losing prior history. |
| `/grand-design-spec:drift-detect` | **`drift-detect`** | For `mode=existing` vaults: scans the live codebase, compares against vault, flags drift (entity rename, type changed, decision violated, code shipped without ADR). For `mode=new` vaults, surfaces the `mode_migrate_after` trigger so you know what to do before re-running. |
| `/grand-design-spec:update` | _(no skill — bash wrapper)_ | Plugin maintenance. `git pull --ff-only` inside `~/.claude/plugins/marketplaces/grand-design-spec/`, prints before/after version, then prompts you to run the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. |
```

NEW STRING:
```
## Skills + commands in this plugin

| Slash command | Skill | Purpose |
|---------------|-------|---------|
| `/grand-design-spec:flow` ⭐ | **`flow`** (v0.14) | Lifecycle orchestrator. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms with user once, then executes the chain in `--auto` mode. Stateless. Pauses on `blocker` artifacts. Anti-halu rails preserved by composition. |
| `/grand-design-spec:grand-design-spec` | **`grand-design-spec`** | Initial vault generation. PRD/BRD/Figma → 7-file dev handoff folder with anti-hallucination guarantees. Also writes a `vault.json` manifest for machine consumption. Supports `--auto` (v0.10+). |
| `/grand-design-spec:resolve-oq` | **`resolve-oq`** | Interactive Open Questions resolver. Walks the OQ roll-up by priority, captures stakeholder answers, updates the vault with version bump + Changelog. Preserves OQ tag identity as audit trail. Cross-cutting OQs land in a primary doc with cross-refs in others. Supports `--auto` for logistical prompts (v0.4+); per-OQ choices stay interactive. |
| `/grand-design-spec:vault-diff` | **`vault-diff`** | Vault evolution when the PRD/BRD source revisions. Computes structured diff, surfaces conflicts (Resolved-OQ vs new PRD, ADR vs new PRD) for explicit user resolution, applies approved changes without losing prior history. Supports `--auto` (v0.3+); conflicts emit `blocker` (type=`diff_conflict`) and pause. |
| `/grand-design-spec:drift-detect` | **`drift-detect`** | For `mode=existing` vaults: scans the live codebase, compares against vault, flags drift (entity rename, type changed, decision violated, code shipped without ADR). For `mode=new` vaults, surfaces the `mode_migrate_after` trigger so you know what to do before re-running. Supports `--auto` (v0.3+); skips interactive walkthrough, writes `DRIFT-REPORT.md` only. |
| `/grand-design-spec:update` | _(no skill — bash wrapper)_ | Plugin maintenance. `git pull --ff-only` inside `~/.claude/plugins/marketplaces/grand-design-spec/`, prints before/after version, then prompts you to run the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. |
```

- [ ] **Step 5: Update plugin README lifecycle diagram (add flow at the top)**

Find the lifecycle diagram block. Use Edit tool.

OLD STRING:
```
## Lifecycle at a glance

```
   Initial PRD      Stakeholder mtg     PRD revisi      Live codebase
       │                  │                  │                 │
       ▼                  ▼                  ▼                 ▼
 grand-design-spec → resolve-oq    →   vault-diff   →    drift-detect
                                                         (existing only)
       │                  │                  │                 │
       ▼                  ▼                  ▼                 ▼
  vault v1.0        vault v1.1         vault v1.2       DRIFT-REPORT.md
                                                        DRIFT-ACTIONS.md
```
```

NEW STRING:
```
## Lifecycle at a glance

```
                                  flow (v0.14)
                          ────────────────────────────
                          orchestrates the row below
                          based on CWD state, in --auto

   Initial PRD      Stakeholder mtg     PRD revisi      Live codebase
       │                  │                  │                 │
       ▼                  ▼                  ▼                 ▼
 grand-design-spec → resolve-oq    →   vault-diff   →    drift-detect
                                                         (existing only)
       │                  │                  │                 │
       ▼                  ▼                  ▼                 ▼
  vault v1.0        vault v1.1         vault v1.2       DRIFT-REPORT.md
                                                        DRIFT-ACTIONS.md
```

`flow` is the recommended entry point: it inspects state, proposes a chain across the row above, confirms once, runs sub-skills in `--auto` mode. Direct invocation of any sub-skill still works (and bypasses orchestration when you want full interactive control).
```

- [ ] **Step 6: Update CONTRIBUTING.md with --auto convention**

OLD STRING (the "Adding a new skill" section):
```
## Adding a new skill

When adding a new skill to the plugin:

1. Create directory under `plugins/grand-design-spec/skills/<skill-name>/`.
2. Add `SKILL.md` with frontmatter: `name`, `version: 0.1.0`, `description`.
3. Add a corresponding command at `plugins/grand-design-spec/commands/<skill-name>.md` so it appears in slash autocomplete.
4. Reference `references/vault-contract.md` for shared definitions instead of duplicating.
5. Add a CHANGELOG entry that includes the new skill at version 0.1.0.
```

NEW STRING:
```
## Adding a new skill

When adding a new skill to the plugin:

1. Create directory under `plugins/grand-design-spec/skills/<skill-name>/`.
2. Add `SKILL.md` with frontmatter: `name`, `version: 0.1.0`, `description`.
3. Add a corresponding command at `plugins/grand-design-spec/commands/<skill-name>.md` so it appears in slash autocomplete.
4. Reference `references/vault-contract.md` for shared definitions instead of duplicating.
5. **Implement `--auto` flag handling (v0.14 convention)**: any new skill that has prompts must define a `## --auto flag` section near the top of its SKILL.md, listing what `--auto` skips (logistical) vs what stays interactive (substance). When blocked in `--auto`, emit a `blocker` artifact per `vault-contract.md` §halt-protocol — pick the existing type (`oq_blocker`, `diff_conflict`, `drift_framework_mismatch`) or propose a new type as part of the contract bump.
6. Add a CHANGELOG entry that includes the new skill at version 0.1.0.
```

- [ ] **Step 7: Verify all 3 files updated**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -c "/grand-design-spec:flow" README.md
grep -c "/grand-design-spec:flow" plugins/grand-design-spec/README.md
grep -c "v0.14" README.md
grep -c "v0.14" plugins/grand-design-spec/README.md
grep -c "Implement \`--auto\` flag" CONTRIBUTING.md
grep -c "v0.14 convention" CONTRIBUTING.md
```

Expected:
- ≥2 hits each in root README and plugin README
- ≥1 v0.14 mention in each
- 1 hit each in CONTRIBUTING.md

- [ ] **Step 8: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add README.md plugins/grand-design-spec/README.md CONTRIBUTING.md
git commit -m "$(cat <<'EOF'
docs(v0.14): update READMEs + CONTRIBUTING for flow orchestrator

- Root README: add /grand-design-spec:flow row to commands table,
  add flow/ skill to repo structure, bump changelog footer.
- Plugin README: add flow row + --auto notes per sub-skill, update
  lifecycle diagram to show flow as recommended entry point.
- CONTRIBUTING.md: add --auto flag convention to "Adding a new skill"
  checklist; new skills must define §--auto-flag and emit blocker
  artifacts when halted autonomously.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Bump versions and add CHANGELOG entry

**Files:**
- Modify: `plugins/grand-design-spec/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md`

Final atomic commit. Plugin/marketplace bumps + CHANGELOG entry move together.

- [ ] **Step 1: Bump plugin.json**

Use Edit. Replace `"version": "0.13.0"` with `"version": "0.14.0"`.

- [ ] **Step 2: Bump marketplace.json**

Use Edit. Replace `"version": "0.13.0"` with `"version": "0.14.0"` (in `plugins[0]` entry).

- [ ] **Step 3: Add v0.14.0 CHANGELOG entry**

Find the line `## [0.13.0] — 2026-05-09` and insert the new v0.14.0 block immediately above it.

OLD STRING:
```
## [0.13.0] — 2026-05-09
```

NEW STRING:
```
## [0.14.0] — 2026-05-10

The agentic upgrade. Adds `/grand-design-spec:flow`, a multi-skill lifecycle orchestrator that turns the plugin from "4 separate tools" into "one workflow." Inspects CWD, proposes a sub-skill chain (e.g., "vault-diff → resolve-oq for new P1s"), confirms once, executes in `--auto` mode. Anti-halu rails preserved by composition — every rail lives in a sub-skill, untouched.

### Skill version moves

- `flow`: **NEW at 0.1.0** (lifecycle orchestrator)
- `grand-design-spec`: 0.9.0 → **0.10.0** (added `--auto` flag for logistical prompts)
- `resolve-oq`: 0.3.0 → **0.4.0** (added `--auto` for logistics; per-OQ choices stay interactive)
- `vault-diff`: 0.2.0 → **0.3.0** (added `--auto` flag; conflicts emit `blocker` type=`diff_conflict`)
- `drift-detect`: 0.2.0 → **0.3.0** (added `--auto` flag; skips interactive walkthrough; framework mismatch emits `blocker` type=`drift_framework_mismatch`)

### Added

- **`/grand-design-spec:flow`** — the orchestrator command. Inspects WORK_DIR for vault, PRD, codebase signals, P1 count, mode-migration trigger, git state. Applies a 7-rule decision matrix to build a proposed chain (max 3 skills). Single user confirmation (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` in v0.1; reordering deferred. Stateless — resumption is just re-invoking. Pauses on `blocker` artifacts; surfaces YAML verbatim in chat.
- **`§halt-protocol`** in `references/vault-contract.md` — unified `blocker` envelope with three types: `oq_blocker` (per v0.11), `diff_conflict` (vault-diff conflicts), `drift_framework_mismatch` (drift-detect framework mismatches). Schema, field rules, type-specific guidance, multi-blocker array form, and v0.11 → v0.14 backward-compat note.
- **`--auto` convention** documented in CONTRIBUTING.md — required for any future skill with prompts. Skips logistical prompts (paths, modes, scopes); never skips substance prompts (stakeholder answers, conflict resolutions); emits `blocker` when halted autonomously.

### Changed

- **`00-index.md` template Halt protocol section** — emits `blocker: type: oq_blocker` (new unified envelope) instead of legacy `oq_blocker:` form. Backward-compat note appended for AI consumers reading v0.13 vaults.
- **`grand-design-spec/SKILL.md`** — adds `## --auto flag` section before Workflow describing how Step 0–0.7 prompts default in `--auto` mode (output folder slug-derived, mode inferred from codebase signals, PRD_STATUS=draft, OUTPUT_MODE=compact). Anti-halu rails (Figma "do you have screenshots?", destructive overwrite confirmation, OQ tagging, source citation) NEVER bypassed.
- **`resolve-oq/SKILL.md`** — adds `## --auto flag` section. Substance prompts (per-OQ Resolve/OOS/Defer/Skip choice, cross-cutting landing) ALWAYS interactive. Logistics (vault path, resume detection, scope, lock ack default) auto-defaulted.
- **`vault-diff/SKILL.md`** — adds `## --auto flag` section. Conflicts (Resolved-OQ, Decision) emit `blocker` (type=`diff_conflict`) and pause. Auto-applies non-conflict changes ≤ 50; emits `blocker` if change count exceeds cap (per OQ-FLOW-3 spec decision).
- **`drift-detect/SKILL.md`** — adds `## --auto flag` section. Skips Step 5 interactive walkthrough; writes `DRIFT-REPORT.md` only (no `DRIFT-ACTIONS.md` — deliberate human decision). Framework mismatch emits `blocker` (type=`drift_framework_mismatch`).
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.13.0 → 0.14.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:flow` to commands tables, update lifecycle diagram (flow as recommended entry point), update repo structure with `flow/` skill dir.

### Backward compatibility

- v0.13 vaults continue to work read-only.
- AI consumers reading vault halts should accept both `oq_blocker:` (legacy v0.11–v0.13 form) and `blocker: type: oq_blocker` (new v0.14 form) for one release cycle. v0.15+ may drop legacy support.
- Direct sub-skill invocation (without `flow`) is unchanged when `--auto` is not passed — full interactive behavior per v0.13.
- `flow` is opt-in. Users who prefer manual sub-skill invocation can ignore it entirely.

### Notes

- The orchestrator is **stateless by design**. No `.gds-state.json` is written. This simplifies the contract (every flow run re-inspects CWD) but means "did I forget drift-detect?" recall depends on user re-running flow.
- **Hard cap of 3 skills per chain** prevents runaway chains. Beyond 3, orchestrator surfaces and asks for explicit confirmation.
- **`flow` does NOT run sub-skills in parallel** — sequential only. Sub-skills modifying the same vault would race otherwise.
- Audit findings deferred to v0.15+: state file with lifecycle position tracking (Approach 2 from brainstorming), reorder-and-edit-args plan editing, scheduled-mode drift-detect via `schedule` skill, self-critiquing loops (Approach 4 from brainstorming).

## [0.13.0] — 2026-05-09
```

- [ ] **Step 4: Verify all 3 files updated**

Run:
```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -c "0.14.0" plugins/grand-design-spec/.claude-plugin/plugin.json
grep -c "0.14.0" .claude-plugin/marketplace.json
grep -n "## \[0.14.0\]" CHANGELOG.md
grep -A2 "## \[0.14.0\]" CHANGELOG.md | head -3
grep -c "Skill version moves" CHANGELOG.md
```

Expected:
- 1 hit each in plugin.json and marketplace.json
- 1 hit for the v0.14.0 heading in CHANGELOG (above [0.13.0])
- ≥2 hits for "Skill version moves" (v0.14.0 + v0.13.0 entries)

- [ ] **Step 5: Final cross-check that v0.14 is fully wired**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
echo "--- flow skill exists ---"
test -f plugins/grand-design-spec/skills/flow/SKILL.md && echo OK
echo "--- flow command exists ---"
test -f plugins/grand-design-spec/commands/flow.md && echo OK
echo "--- §halt-protocol in vault-contract ---"
grep -c "§halt-protocol" plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md
echo "--- 4 sub-skills have --auto sections ---"
for skill in grand-design-spec resolve-oq vault-diff drift-detect; do
  echo -n "$skill: "
  grep -c "## --auto flag" plugins/grand-design-spec/skills/$skill/SKILL.md
done
echo "--- skill versions ---"
for skill in flow grand-design-spec resolve-oq vault-diff drift-detect; do
  echo -n "$skill: "
  grep "^version:" plugins/grand-design-spec/skills/$skill/SKILL.md
done
echo "--- plugin version ---"
grep '"version"' plugins/grand-design-spec/.claude-plugin/plugin.json | head -1
echo "--- README contains flow ---"
grep -c "/grand-design-spec:flow" README.md
echo "--- CONTRIBUTING contains --auto convention ---"
grep -c "v0.14 convention" CONTRIBUTING.md
```

Expected:
- flow files exist
- §halt-protocol: ≥1
- All 4 sub-skills: 1 hit each for `## --auto flag`
- Skill versions: flow 0.1.0, gds 0.10.0, resolve-oq 0.4.0, vault-diff 0.3.0, drift-detect 0.3.0
- Plugin version: 0.14.0
- README hits ≥2
- CONTRIBUTING hits 1

- [ ] **Step 6: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/.claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(v0.14): bump versions and add CHANGELOG entry

Plugin 0.13.0 → 0.14.0. The agentic upgrade — adds
/grand-design-spec:flow lifecycle orchestrator + --auto flags across
the 4 existing skills + unified blocker envelope.

Skill version moves enumerated:
- flow: NEW at 0.1.0
- grand-design-spec: 0.9.0 → 0.10.0
- resolve-oq: 0.3.0 → 0.4.0
- vault-diff: 0.2.0 → 0.3.0
- drift-detect: 0.2.0 → 0.3.0

Backward compat: legacy oq_blocker: YAML form still accepted by AI
consumers for one release cycle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

**Spec coverage:**

| Spec section | Plan task | Covered? |
|--------------|-----------|----------|
| Skill identity (name, slash command, args, description) | Tasks 7 + 8 | ✅ |
| CWD inspection + decision matrix | Task 7 (Workflow Steps 1-2) | ✅ |
| Plan format + confirmation UX | Task 7 (Workflow Step 3) | ✅ |
| `--auto` semantics per sub-skill | Tasks 3, 4, 5, 6 (one section per sub-skill) | ✅ |
| Unified `blocker` halt envelope | Task 1 (vault-contract.md) | ✅ |
| Failure handling + reporting | Task 7 (Workflow Steps 4-5) + Halt handling section | ✅ |
| 12 modified + 2 new files | Task 1 (1 mod) + Task 2 (1 mod) + Tasks 3-6 (4 mod) + Task 7 (1 new) + Task 8 (1 new) + Task 9 (3 mod) + Task 10 (3 mod) = 12 mod + 2 new ✓ | ✅ |
| Skill version moves (gds 0.10, resolve-oq 0.4, vault-diff 0.3, drift-detect 0.3, flow 0.1, plugin 0.14) | Tasks 3, 4, 5, 6, 7, 10 | ✅ |
| 00-index template halt section migration | Task 2 | ✅ |
| CONTRIBUTING.md `--auto` convention | Task 9 Step 6 | ✅ |
| Backward-compat note (legacy oq_blocker:) | Tasks 1 + 2 + 10 (CHANGELOG) | ✅ |

All 11 spec sections covered.

**Placeholder scan:** none. Every step contains the exact content to insert. No "TBD", "TODO", "implement later", "etc." dummies.

**Type consistency:**
- `blocker:` envelope (not `gds-blocker:` — locked per OQ-FLOW-2 decision in plan header)
- `type` field uses three values: `oq_blocker`, `diff_conflict`, `drift_framework_mismatch` — same across vault-contract.md, 00-index.md template, all 4 sub-skill `--auto` sections, and flow/SKILL.md
- File paths absolute and consistent across tasks
- Skill version targets in Task 10 CHANGELOG entry match the per-task bumps (Tasks 3-7)

---

Plan complete and saved to `docs/superpowers/plans/2026-05-10-v014-flow-orchestrator.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration. 10 tasks; given the consistent Task pattern (mostly mechanical edits + verification grep + commit), this should run smoothly with haiku implementers like the v0.13 round did.

2. **Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batched with checkpoints. Single context, no fresh-eyes review.

Which approach?
