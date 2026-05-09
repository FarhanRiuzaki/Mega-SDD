# v0.13 Ship-Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the 7 priority fixes from `docs/superpowers/specs/2026-05-09-plugin-audit-design.md` so `grand-design-spec` plugin v0.13.0 can ship cleanly.

**Architecture:** Documentation/skill-instruction edits only — no runtime code. Each task is a focused edit to one or two files, ending in an atomic commit. Order is dependency-aware: shared `vault-contract.md` first (Task 1), then per-skill updates that reference it (Tasks 2-5), then templates (Task 6), then versioning meta (Tasks 7-8).

**Tech Stack:** Markdown, YAML frontmatter, JSON manifest schema. No build tooling.

**Source spec:** `docs/superpowers/specs/2026-05-09-plugin-audit-design.md`

**Findings addressed in this plan:**

| Finding | Severity | Where it gets fixed |
|---------|----------|---------------------|
| H-1 vault-diff doesn't write back vault.json | HIGH | Task 4 |
| H-2 drift-detect doesn't reconcile vault.json | HIGH | Task 5 (explicit-boundary-doc per OQ-AUDIT-1 decision) |
| H-3 lock-vault forward-references | HIGH | Task 3 |
| M-1 / L-8 / L-9 shared vault-contract.md | MED/LOW | Task 1 |
| M-3 skill-versioning rule | MED | Task 7 |
| M-5 templates compact/full markers | MED | Task 6 |
| M-6 OQ_BLOCKER self-check | MED | Task 2 |
| M-8 vault.json count match self-check | MED | Task 3 |

**Decision on OQ-AUDIT-1 (H-2):** explicit-boundary-doc, not auto-reconcile. Reasoning: drift-detect's core principle is "no code execution, write reports only" (line 396 of drift-detect/SKILL.md). Auto-regenerating vault.json contradicts that. Explicit boundary stays honest.

**Decision on M-3:** independent semver per skill, with stricter CHANGELOG discipline. Each release entry must enumerate per-skill version moves.

---

## File structure

| File | Action | Why |
|------|--------|-----|
| `plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md` | **Create** | Shared schema + OQ conventions; addresses M-1/L-8/L-9 |
| `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md` | Modify | Reference contract, add OQ_BLOCKER self-check (M-6), version 0.8.0 → 0.9.0 |
| `plugins/grand-design-spec/skills/resolve-oq/SKILL.md` | Modify | Remove lock-vault refs (H-3), add vault.json count self-check (M-8), version 0.2.0 → 0.3.0 |
| `plugins/grand-design-spec/skills/vault-diff/SKILL.md` | Modify | Add Step 6.5 vault.json refresh (H-1), Step 8 self-check, version 0.1.0 → 0.2.0 |
| `plugins/grand-design-spec/skills/drift-detect/SKILL.md` | Modify | Document the vault.json regeneration boundary (H-2). No version bump. |
| `plugins/grand-design-spec/skills/grand-design-spec/references/templates/*.md` (7 files) | Modify | Add `<!-- compact-skip -->` / `<!-- full-only -->` markers (M-5) |
| `CONTRIBUTING.md` | **Create** | Skill-versioning rule (M-3) |
| `plugins/grand-design-spec/.claude-plugin/plugin.json` | Modify | Version 0.12.1 → 0.13.0 |
| `.claude-plugin/marketplace.json` | Modify | Version 0.12.1 → 0.13.0 |
| `CHANGELOG.md` | Modify | Add v0.13.0 entry |

8 commits total.

---

## Task 1: Create shared vault contract

**Files:**
- Create: `plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md`

This file becomes the single source of truth for the vault.json schema, OQ tagging conventions, and the "Skill instruction language" boilerplate. Sibling skills will reference it instead of duplicating the same content.

- [ ] **Step 1: Create the contract file with full content**

Create `plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md` with this exact content:

````markdown
# Vault Contract

Shared definitions referenced by all `grand-design-spec` skills. **Single source of truth** — when this file changes, every skill that references it inherits the change.

> **Maintenance rule**: edits to this file are breaking changes for sibling skills. Bump the affected skill versions + CHANGELOG entry whenever you touch this file.

## §schema — `vault.json` manifest

Every `grand-design-spec` vault has a `vault.json` alongside the 7 markdown files. The markdown is human-authoritative; the JSON is a derived structural index optimized for AI consumers (Claude Code, Cursor, automated agents).

```json
{
  "vault_version": "1.0",
  "generated_at": "YYYY-MM-DDTHH:MM:SSZ",
  "project_shape": "web-app",
  "implementation_mode": "new",
  "prd_status": "draft",
  "output_mode": "compact",
  "mode_migrate_after": "first commit lands on main branch (mode=new only)",
  "source_documents": [
    {"type": "PRD", "path": "examples/timeoff/PRD.pdf", "version": "1.0", "date": "YYYY-MM-DD"}
  ],
  "entities": [
    {"name": "leave_request", "purpose": "Lifecycle entity for a leave request", "doc": "03-data-model.md", "fields_count": 13}
  ],
  "flows": [
    {"id": "F-U-001", "title": "Submit leave request", "type": "user", "doc": "04-flows.md", "dod_count": 7, "source_acs": ["AC1-1","AC1-2","AC1-3","AC1-4","AC1-5"]}
  ],
  "adrs": [
    {"id": "D-001", "title": "Multi-tenant SaaS-only deployment", "doc": "05-decisions.md", "status": "accepted"}
  ],
  "open_questions": [
    {"tag": "OQ-AR-1", "priority": "P1", "doc": "02-architecture.md", "status": "open", "category": "Tech stack & architecture", "resolver_owner": "Mike Patel"}
  ],
  "open_questions_summary": {
    "total": 48,
    "by_priority": {"P1": 12, "P2": 22, "P3": 14},
    "by_status": {"open": 48, "resolved": 0, "deferred": 0, "out_of_scope": 0}
  },
  "design_system_flags": {
    "HAS_UI_COMPONENTS": false,
    "HAS_TOKENS": false,
    "HAS_A11Y": false,
    "HAS_VOICE_BRAND": true
  }
}
```

### Field rules

- Every entity in `03-data-model.md` DBML must have a row in `entities[]`. Same for `flows[]` (one per `F-{prefix}-NNN`), `adrs[]` (one per `D-NNN`), `open_questions[]` (one per `OQ-{CODE}-{N}`).
- `open_questions[].status` mirrors the markdown checkbox: `[ ]` → `open`, `[x]` → `resolved`, `[~]` → `out_of_scope`. A `[ ]` with a `**Deferred**:` annotation maps to `deferred`.
- `open_questions[].category` matches the category header used in the `00-index.md` Open Questions roll-up.
- `open_questions[].resolver_owner` is best-effort — extract from the OQ entry's "Resolve: ..." or "owner" hint when present; otherwise `null`.
- `mode_migrate_after` is informational metadata for `mode=new` vaults only. For `mode=existing`, use `null`.
- Keep this file in sync with the markdown on every regeneration / `vault-diff` / `resolve-oq` round. The markdown is canonical; `vault.json` is a derived index.

### When skills must regenerate `vault.json`

- `grand-design-spec` Step 3 — initial generation.
- `resolve-oq` Step 2c step 9 — after every Resolve / Out-of-Scope / Defer outcome.
- `vault-diff` Step 6.5 — after applying approved changes (added/changed/removed entities, flows, ADRs, auto-resolved or new OQs).
- `drift-detect` — does NOT regenerate. Drift-detect produces reports only; vault.json regen happens via `resolve-oq` (for OQ-tagged actions) or manual + grand-design-spec re-run (for entity/flow/ADR additions).

## §OQ-conventions — Open Question tagging

Every Open Question MUST have a unique tag and priority marker.

**Tag format**: `OQ-{DOC_CODE}-{N}` where:

| Doc | Code |
|-----|------|
| `01-overview.md` | `OV` |
| `02-architecture.md` | `AR` |
| `03-data-model.md` | `DM` |
| `04-flows.md` | `FL` |
| `05-decisions.md` | `DC` |
| `06-constraints.md` | `CN` |

`N` is sequential within each doc (1, 2, 3 …). Tags are stable identifiers — once assigned, do not renumber when adding new questions.

**Priority levels**:

- **P1 — Sprint-0 blocker**: Must be answered before any coding starts. Examples: tech stack, API contracts, source-data inconsistencies, missing sign-off, regulatory/compliance scope.
- **P2 — Feature blocker**: Blocks a specific feature/flow but not the whole project. Examples: edge-case behavior, channel mapping for notifications, max value limits.
- **P3 — Refinement**: Useful to clarify but project can move without it. Examples: future-proofing, optimization details, optional analytics.

**Status markers** (in markdown):

- `[ ]` — open
- `[x]` — resolved (followed by `→ Resolved v{X.Y}: <answer or pointer>`)
- `[~]` — out of scope (followed by `→ Out of Scope v{X.Y}: <reason>`)
- `[ ]` + `**Deferred (v{X.Y})**: <reason>` — deferred (still open, but waiting on something specific)

## §boilerplate — Skill instruction language

Reusable shim. Each skill's SKILL.md should reference this section:

> **Skill instruction language**: this skill is written in English for reasoning quality. Generated content (vault docs, resolution answers, diff reports, drift findings) is recorded in the vault's existing language — same as the rest of the vault. The skill's chat prompts adapt to the user's language at runtime.

## §id-stability — ID conventions

Across all skills, these identifiers are **stable across rounds**:

- `OQ-{CODE}-{N}` — Open Question tag.
- `F-{prefix}-NNN` — Flow ID. Prefixes: `F-U-` (user), `F-S-` (system/backend), `F-C-` (cross-cutting), `F-P-` (pipeline), `F-X-` (custom).
- `D-NNN` — ADR ID.
- Entity names — DBML table names; preserve casing across edits.

When a sibling skill creates new entries, use **next-available** number, never reuse.
````

- [ ] **Step 2: Verify the file exists and renders correctly**

Run: `ls -la plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md`
Expected: file exists, ~5KB.

Run: `head -20 plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md`
Expected: shows the title and first paragraph.

- [ ] **Step 3: Commit**

```bash
git add plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(v0.13): add shared vault-contract.md

Single source of truth for vault.json schema, OQ tagging conventions,
ID stability rules, and "Skill instruction language" boilerplate.
Addresses audit findings M-1, L-8, L-9 — schema previously inlined in
grand-design-spec/SKILL.md only; sibling skills referenced fields blind.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Update `grand-design-spec/SKILL.md`

**Files:**
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md`

Three changes: reference vault-contract instead of inlining schema, add the OQ_BLOCKER self-check (M-6), bump skill version 0.8.0 → 0.9.0.

- [ ] **Step 1: Bump frontmatter version**

Edit `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md` line 3:

Replace:
```yaml
version: 0.8.0
```
With:
```yaml
version: 0.9.0
```

- [ ] **Step 2: Add OQ_BLOCKER self-check item to Step 4**

Find the section under Step 4 self-check labeled `**`vault.json` manifest (v0.11):**`. After its last bullet (the design-system flags one), add a new sub-section before "Design-system grounding":

Insert after the line ending in `match the values used to drive Step 3 conditional generation.`:

```markdown

**Halt protocol & implementation notes (v0.13):**
- [ ] `00-index.md` contains "Halt protocol for autonomous runs" sub-section under Implementation Notes for AI Consumers (per template).
- [ ] `00-index.md` contains "Parallel-work guidance while P1s are unresolved" sub-section.
- [ ] `00-index.md` contains "Companion skills for vault evolution" sub-section pointing to `resolve-oq` / `vault-diff` / `drift-detect`.
```

- [ ] **Step 3: Replace inline schema reference with contract pointer**

In Step 3 of the workflow, find the `### Bonus output: vault.json machine-readable manifest (v0.11)` section. After the introductory paragraph (ending in "Markdown remains the human-authoritative source; JSON is a derived index."), replace the entire schema JSON block + field rules + "Why both formats" subsection with:

```markdown
**Schema, field rules, and regeneration trigger points** — see `references/vault-contract.md` §schema. Read this file before generating `vault.json`.

**Why both formats**:
- Humans review markdown — narrative, citations, nuance.
- AI consumers read `vault.json` — fast structural lookup, no token-heavy prose parsing, reliable enum-based status/priority filtering.
```

This removes the duplicated schema (now in contract) and the duplicated field-rules list. Skill instruction body shrinks ~50 lines.

- [ ] **Step 4: Replace inline OQ tagging convention with contract pointer**

Find the `### Open Question tagging convention` section (currently at the bottom under "Mandatory section template"). Replace the entire section content (everything between `### Open Question tagging convention` and the next `### 00-index.md Open Questions roll-up structure`) with:

```markdown
### Open Question tagging convention

See `references/vault-contract.md` §OQ-conventions for tag format, doc-code table, and priority definitions. Every Open Question generated by this skill MUST follow that convention.

```

- [ ] **Step 5: Verify edits applied correctly**

Run: `grep -n "version: 0.9.0" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md`
Expected: line 3.

Run: `grep -n "vault-contract.md" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md`
Expected: at least 2 hits (Step 3 + OQ tagging section).

Run: `grep -n "OQ_BLOCKER\|Halt protocol" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md`
Expected: matches the new self-check item plus the existing references.

- [ ] **Step 6: Commit**

```bash
git add plugins/grand-design-spec/skills/grand-design-spec/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.13): grand-design-spec skill 0.8.0 → 0.9.0

- Reference references/vault-contract.md for schema + OQ conventions
  instead of inlining (addresses M-1).
- Add Step 4 self-check items for OQ_BLOCKER halt protocol section,
  parallel-work guidance, companion-skills sub-section in 00-index.md
  (addresses M-6).
- Skill body shrinks ~60 lines as duplicated content moves to contract.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Update `resolve-oq/SKILL.md`

**Files:**
- Modify: `plugins/grand-design-spec/skills/resolve-oq/SKILL.md`

Four changes: remove `lock-vault` forward-references (H-3), add vault.json count-match self-check (M-8), reference vault-contract, bump skill version 0.2.0 → 0.3.0.

- [ ] **Step 1: Bump frontmatter version**

Edit `plugins/grand-design-spec/skills/resolve-oq/SKILL.md` line 3:

Replace `version: 0.2.0` with `version: 0.3.0`.

- [ ] **Step 2: Replace first lock-vault forward-reference (Step 0 step 3)**

Find the current text on line 66:
```
If user cancels → STOP. If proceeds → record in the resolution-round Changelog entry that the vault was unlocked for this round; user is responsible for re-locking via `lock-vault` (when available) or manual edit after.
```

Replace with:
```
If user cancels → STOP. If proceeds → record in the resolution-round Changelog entry that the vault was unlocked for this round. User is responsible for re-locking after the round: edit `00-index.md` Vault Lock Status — change `Status: ⚠️ DRAFT (unlocked for resolve-oq round)` back to `Status: 🔒 LOCKED for <scope>`, refresh `Locked at` / `Locked by`, append a Changelog entry confirming the relock.
```

- [ ] **Step 3: Replace second lock-vault forward-reference (Step 5)**

Find the current text on line 237:
```
5. Suggested next step: re-run `resolve-oq` after stakeholder follow-up, or run `lock-vault` (when available) to declare the vault locked.
```

Replace with:
```
5. Suggested next step: re-run `resolve-oq` after stakeholder follow-up. To lock the vault for sprint implementation, edit `00-index.md` Vault Lock Status manually (`Status: 🔒 LOCKED for <scope>`, fill `Locked at` / `Locked by`, append a Changelog entry).
```

- [ ] **Step 4: Add vault.json count-match self-check items to Step 4**

Find the existing Step 4 self-check list. After the last item (`No invented answers...`), append two new items:

Insert before the line `### Step 5: Present summary`:

```markdown
- [ ] `vault.json.open_questions_summary.total` matches the count of OQ entries in `00-index.md` roll-up after the round.
- [ ] Every OQ marked `[x]` / `[~]` / Deferred in markdown has matching `status` (`resolved` / `out_of_scope` / `deferred`) in `vault.json.open_questions[]`.
- [ ] If any resolution was Promoted to a new ADR, `vault.json.adrs[]` contains the new entry.
```

- [ ] **Step 5: Reference vault-contract for OQ conventions**

Find the References section at the bottom (line ~268 onward). Replace:
```
- For OQ tagging convention details, see the parent skill `grand-design-spec` SKILL.md, section "Open Question tagging convention".
```

With:
```
- OQ tagging conventions, status marker semantics, and `vault.json` field rules: see `../grand-design-spec/references/vault-contract.md` (§OQ-conventions, §schema).
```

- [ ] **Step 6: Verify edits applied correctly**

Run: `grep -n "lock-vault" plugins/grand-design-spec/skills/resolve-oq/SKILL.md`
Expected: 0 matches.

Run: `grep -n "version: 0.3.0" plugins/grand-design-spec/skills/resolve-oq/SKILL.md`
Expected: line 3.

Run: `grep -c "vault-contract.md" plugins/grand-design-spec/skills/resolve-oq/SKILL.md`
Expected: at least 1.

Run: `grep -n "open_questions_summary.total matches" plugins/grand-design-spec/skills/resolve-oq/SKILL.md`
Expected: 1 match (new self-check item).

- [ ] **Step 7: Commit**

```bash
git add plugins/grand-design-spec/skills/resolve-oq/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.13): resolve-oq skill 0.2.0 → 0.3.0

- Remove `lock-vault` forward-references; replace with manual-edit
  instructions for 00-index.md Vault Lock Status (addresses H-3).
- Add Step 4 self-check items for vault.json sync — totals match
  markdown roll-up; promoted ADRs appear in adrs[] (addresses M-8).
- Reference shared vault-contract.md instead of grand-design-spec
  SKILL.md for OQ conventions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Update `vault-diff/SKILL.md` — add Step 6.5 vault.json refresh

**Files:**
- Modify: `plugins/grand-design-spec/skills/vault-diff/SKILL.md`

Three changes: add Step 6.5 (the actual H-1 fix), add Step 8 self-check items, reference vault-contract, bump skill version 0.1.0 → 0.2.0.

- [ ] **Step 1: Bump frontmatter version**

Edit `plugins/grand-design-spec/skills/vault-diff/SKILL.md` line 3:

Replace `version: 0.1.0` with `version: 0.2.0`.

- [ ] **Step 2: Insert new Step 6.5 between current Step 6 and Step 7**

Find the end of `### Step 6: Apply approved changes` section. The last item in that section is currently item 7 (Decision conflicts).

After Step 6 ends (and before `### Step 7: Update vault metadata` begins), insert this new section:

```markdown
### Step 6.5: Refresh `vault.json` (v0.2)

After applying approved changes, regenerate `vault.json` from the now-updated markdown so AI consumers don't see stale state.

1. Read all 7 markdown files (post-apply state).
2. Rebuild the manifest fields per `references/vault-contract.md` §schema:
   - `entities[]` from `03-data-model.md` DBML — add new entries from this round, preserve existing.
   - `flows[]` from `04-flows.md` — add new flow IDs, mark removed flows with their banner annotation in metadata if useful (optional). Existing flow IDs stay even when their content changed.
   - `adrs[]` from `05-decisions.md` — new D-XXX entries from this round get added with `status: accepted` (or `superseded` if this round flipped a prior decision).
   - `open_questions[]` — refresh `status` per markdown checkbox state. Auto-resolved OQs flip `open` → `resolved`. New OQs added by this diff get `status: open`.
   - `open_questions_summary.total` and `by_priority` / `by_status` — recompute from the new array.
   - `vault_version` — match the post-bump version from Step 7 (this step writes both; sequence them so vault.json reflects the new version).
   - `generated_at` — update to current timestamp.
   - `source_documents[]` — replace prior PRD entry with the new source per Step 7 step 4.
3. Write to `<VAULT_DIR>/vault.json`. Overwrites prior manifest.

> **Idempotency**: re-running vault-diff against an unchanged source produces an unchanged `vault.json` (same field values, only `generated_at` updates). The Step 8 self-check verifies markdown ↔ JSON consistency.

> **Why a separate step**: the markdown edits in Step 6 are content; the JSON regen is structural. Keeping them adjacent but distinct lets self-check verify each independently.
```

- [ ] **Step 3: Add vault.json self-check items to Step 8**

Find the Step 8 self-check list. After the last existing item (`If git is available...`), append:

```markdown
- [ ] `vault.json` regenerated and reflects post-apply state. `entities[]` / `flows[]` / `adrs[]` / `open_questions[]` arrays match the markdown.
- [ ] `vault.json.open_questions_summary.total` equals the count of OQ entries in `00-index.md` roll-up.
- [ ] `vault.json.vault_version` equals the new version from Step 7. `generated_at` is updated to the current timestamp.
- [ ] `vault.json.source_documents[]` reflects the new PRD source from Step 7 step 4.
```

- [ ] **Step 4: Reference vault-contract**

Find the References section at the bottom. Replace the existing OQ tagging line:
```
- For OQ tagging convention details, see the parent skill `grand-design-spec` SKILL.md, section "Open Question tagging convention".
```

With:
```
- OQ tagging conventions, status marker semantics, and `vault.json` field rules + regeneration trigger points: see `../grand-design-spec/references/vault-contract.md` (§OQ-conventions, §schema).
```

- [ ] **Step 5: Verify edits applied correctly**

Run: `grep -n "Step 6.5" plugins/grand-design-spec/skills/vault-diff/SKILL.md`
Expected: 1 match in the workflow section.

Run: `grep -n "version: 0.2.0" plugins/grand-design-spec/skills/vault-diff/SKILL.md`
Expected: line 3.

Run: `grep -c "vault-contract.md" plugins/grand-design-spec/skills/vault-diff/SKILL.md`
Expected: at least 1.

Run: `grep -n "vault.json.*regenerated" plugins/grand-design-spec/skills/vault-diff/SKILL.md`
Expected: 1 match (new self-check).

- [ ] **Step 6: Commit**

```bash
git add plugins/grand-design-spec/skills/vault-diff/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.13): vault-diff skill 0.1.0 → 0.2.0 — vault.json write-back

Adds Step 6.5 "Refresh vault.json" that runs after Step 6 applies
markdown changes. Rebuilds entities[], flows[], adrs[], open_questions[]
from the post-apply markdown and writes the updated manifest.
Closes the H-1 ship-blocker — v0.11 added vault.json + write-back to
resolve-oq but missed vault-diff, leaving markdown ↔ JSON drift after
every diff round.

Step 8 self-check gains 4 vault.json invariants. References
vault-contract.md for the schema instead of duplicating it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update `drift-detect/SKILL.md` — explicit boundary doc for vault.json

**Files:**
- Modify: `plugins/grand-design-spec/skills/drift-detect/SKILL.md`

Two changes: document the no-auto-regen boundary in Step 6 (the H-2 fix per OQ-AUDIT-1 decision), reference vault-contract. **No version bump** — behavior unchanged, only documentation.

- [ ] **Step 1: Add boundary documentation to Step 6**

Find `### Step 6: Update vault metadata (only if interactive walkthrough captured vault-side actions)`. After the existing 3-numbered-list (currently ending with "Do NOT bump vault version yet — version bump happens when actions are actually applied to vault content."), append a new sub-section:

```markdown

### `vault.json` reconciliation boundary (v0.13)

`drift-detect` deliberately does NOT regenerate `vault.json`. The skill's core principle is *"no code execution, write reports only"* — auto-reconciling the manifest would contradict that.

**What this means in practice:**

- When the user accepts a vault-side action that *would* alter vault content (e.g., "promote unwritten decision to ADR"), the actual vault edit happens later, via `resolve-oq` (for OQ-tagged items) or direct manual edit followed by re-running `grand-design-spec` to regenerate the full vault.
- Until the edit lands and a regen runs, `vault.json` stays at the pre-drift-session state. AI consumers loading the manifest will not see the proposed-but-unlanded changes.
- The Changelog entry written in step 1 above flags this — it records the drift session, not vault content changes. Vault version stays unchanged.
- If a later manual edit lands the proposed change, the user is responsible for triggering `vault.json` regeneration: easiest path is to edit the markdown then re-run `/grand-design-spec:grand-design-spec` against the same PRD with the same flags, OR use `resolve-oq` if the change is OQ-driven (resolve-oq writes back vault.json automatically).

**Why this is acceptable**: drift-detect findings are always advisory. The action list in `DRIFT-ACTIONS.md` makes the boundary explicit so the user knows what's tentative vs landed.
```

- [ ] **Step 2: Reference vault-contract in References**

Find the References section. Replace the existing OQ tagging line:
```
- For OQ tagging convention details, see the parent skill `grand-design-spec` SKILL.md, section "Open Question tagging convention".
```

With:
```
- OQ tagging conventions and `vault.json` field rules: see `../grand-design-spec/references/vault-contract.md` (§OQ-conventions, §schema). Note: drift-detect reads vault.json but never writes to it — see "vault.json reconciliation boundary" in Step 6.
```

- [ ] **Step 3: Verify edits applied correctly**

Run: `grep -n "vault.json reconciliation boundary" plugins/grand-design-spec/skills/drift-detect/SKILL.md`
Expected: 1 match.

Run: `grep -c "vault-contract.md" plugins/grand-design-spec/skills/drift-detect/SKILL.md`
Expected: at least 1.

Run: `grep -n "version: 0.2.0" plugins/grand-design-spec/skills/drift-detect/SKILL.md`
Expected: line 3 (unchanged — version stays 0.2.0).

- [ ] **Step 4: Commit**

```bash
git add plugins/grand-design-spec/skills/drift-detect/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.13): drift-detect — document vault.json reconciliation boundary

Per audit OQ-AUDIT-1 decision: drift-detect deliberately does NOT
regenerate vault.json. The skill's core principle is "no code execution,
write reports only" — auto-reconciliation would contradict that.

This commit makes the boundary explicit in Step 6 so users understand
that DRIFT-REPORT findings are advisory; vault.json regen happens via
resolve-oq or manual + grand-design-spec re-run after the actual vault
edit lands. Closes H-2.

No skill version bump — behavior unchanged, documentation only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Annotate templates with compact/full markers

**Files:**
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/references/templates/01-overview.md`
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/references/templates/02-architecture.md`
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/references/templates/03-data-model.md`
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/references/templates/04-flows.md`
- Modify: `plugins/grand-design-spec/skills/grand-design-spec/references/templates/05-decisions.md`

Add `<!-- compact-skip -->` and `<!-- full-only -->` markers around content that's mode-conditional. Skill respects these mechanically instead of memorizing 5 transformation rules. Addresses M-5.

`00-index.md` and `06-constraints.md` templates have no compact-mode-conditional content — skip them.

- [ ] **Step 1: Annotate `01-overview.md` TL;DR**

The 3-line TL;DR header is a compact-mode candidate (collapse to 1 line in compact). Wrap lines 3-5 of the template:

Find:
```markdown
> **TL;DR**: What the product is, who it's for, why it's being built, and what success looks like.
> **Audience**: Product Manager, Business Owner, anyone newly joining the project.
> **Read when**: you need basic product context before looking at technical detail.
```

Replace with:
```markdown
<!-- compact-skip -->
> **TL;DR**: What the product is, who it's for, why it's being built, and what success looks like.
> **Audience**: Product Manager, Business Owner, anyone newly joining the project.
> **Read when**: you need basic product context before looking at technical detail.
<!-- /compact-skip -->
<!-- full-only -->
<!-- /full-only -->

<!-- compact-mode rendering: replace the 3-line block above with a single line:
> **TL;DR**: <doc summary> · <primary audience> · <when to read>.
-->
```

- [ ] **Step 2: Annotate `02-architecture.md` API contracts JSON blocks**

Find the API contracts section (currently ~line 102-128). Wrap the request/response JSON blocks to mark them full-only.

Find this block (within the `#### \`<METHOD> /path/to/endpoint\`` example):

```markdown
**Request / Input**:
```json
{
  "field": "type — note"
}
```

**Response / Output (success)**:
```json
{
  "field": "type — note"
}
```

**Errors / Failure modes**:
- `400` / `<error type>` — <when>
- `404` / `<error type>` — <when>
```

Replace with:

```markdown
<!-- full-only -->
**Request / Input**:
```json
{
  "field": "type — note"
}
```

**Response / Output (success)**:
```json
{
  "field": "type — note"
}
```
<!-- /full-only -->

**Errors / Failure modes**:
- `400` / `<error type>` — <when>
- `404` / `<error type>` — <when>

<!-- compact-mode rendering: replace JSON request/response with a table row in a per-group endpoints table:
| Endpoint | Method | Purpose | Auth | Errors | Source |
|----------|--------|---------|------|--------|--------|
-->
```

- [ ] **Step 3: Annotate `03-data-model.md` Entity descriptions section**

Find the `## Entity descriptions` section (line 31-44). Wrap the entire section as compact-skip:

Find:
```markdown
## Entity descriptions

### <entity_name>

- **Purpose**: <1 line>
- **Key fields**:
  - `<field>` — <type, why it exists>
- **Relations**:
  - belongs to `<other_entity>` via `<fk>`
  - has many `<other_entity>`

### <next_entity>

<repeat>
```

Replace with:
```markdown
<!-- compact-skip -->
## Entity descriptions

### <entity_name>

- **Purpose**: <1 line>
- **Key fields**:
  - `<field>` — <type, why it exists>
- **Relations**:
  - belongs to `<other_entity>` via `<fk>`
  - has many `<other_entity>`

### <next_entity>

<repeat>
<!-- /compact-skip -->

<!-- compact-mode rendering: omit the entire Entity descriptions section. DBML block + 1-line `Purpose:` per entity (added inline before each Table) is sufficient. -->
```

- [ ] **Step 4: Annotate `04-flows.md` Preconditions/Postconditions blocks**

The `04-flows.md` template has Preconditions / Postconditions in flow blocks. Wrap them.

Find (in the F-{prefix}-001 example, ~line 35-45):
```markdown
**Actor / Trigger**: <persona, or "scheduled cron at HH:MM", or "external API call">
**Preconditions**: <state required before flow starts>

**Steps**:
1. <action>
2. <action>
3. <action>

**Postconditions**: <state after flow completes>
```

Replace with:
```markdown
**Actor / Trigger**: <persona, or "scheduled cron at HH:MM", or "external API call">
<!-- full-only -->
**Preconditions**: <state required before flow starts>
<!-- /full-only -->

**Steps**:
1. <action>
2. <action>
3. <action>

<!-- full-only -->
**Postconditions**: <state after flow completes>
<!-- /full-only -->
```

Apply the same wrapping to other flow examples in the same template (Backend / system flows F-{prefix}-001 block, ~line 65-78):

Find:
```markdown
**Trigger**: <cron / event / manual>
**Inputs**: <what data the system reads>
**Steps**:
```

Leave that as-is — Inputs/Outputs are not Pre/Post-conditions and are required in both modes.

But find `**Failure handling**:` and wrap it:

Find:
```markdown
**Outputs**: <what data is written / emitted>
**Failure handling**: <retry / DLQ / alert>
```

Replace with:
```markdown
**Outputs**: <what data is written / emitted>
<!-- full-only -->
**Failure handling**: <retry / DLQ / alert>
<!-- /full-only -->
```

(per SKILL.md compact mode policy: "Skip Failure handling section unless the failure path is non-trivial".)

- [ ] **Step 5: Annotate `05-decisions.md` multi-section ADR format**

Find the D-001 example (~line 14-31). Wrap the multi-section format and add compact-mode rendering note:

Find:
```markdown
### D-001: <short decision title, e.g. "Use Redis for session cache">

**Status**: <Proposed / Accepted / Superseded by D-XXX>
**Date**: YYYY-MM

**Context**:
<Why this decision is needed. What problem it solves. What alternatives were considered.>

**Decision**:
<What was decided, in 1–3 sentences.>

**Consequences**:
- ✅ <positive consequence>
- ✅ <positive consequence>
- ⚠️ <trade-off / cost>
- ⚠️ <trade-off / cost>

**Source**: PRD §<X.Y> / explicit user instruction / meeting <date>
```

Replace with:
```markdown
### D-001: <short decision title, e.g. "Use Redis for session cache">

<!-- full-only -->
**Status**: <Proposed / Accepted / Superseded by D-XXX>
**Date**: YYYY-MM

**Context**:
<Why this decision is needed. What problem it solves. What alternatives were considered.>

**Decision**:
<What was decided, in 1–3 sentences.>

**Consequences**:
- ✅ <positive consequence>
- ✅ <positive consequence>
- ⚠️ <trade-off / cost>
- ⚠️ <trade-off / cost>

**Source**: PRD §<X.Y> / explicit user instruction / meeting <date>
<!-- /full-only -->

<!-- compact-mode rendering: replace the multi-section block above with a 1-paragraph format:
<Context in one sentence>. **Decision**: <what was decided, 1–2 sentences>. **Consequences**: <pros + tradeoffs, comma-separated, max 2 lines>. **Source**: <PRD §X>.
-->
```

- [ ] **Step 6: Verify all template annotations applied**

Run: `grep -c "compact-skip\|full-only" plugins/grand-design-spec/skills/grand-design-spec/references/templates/*.md`
Expected: at least 5 files with marker hits (01, 02, 03, 04, 05).

Run: `grep -L "compact-skip\|full-only" plugins/grand-design-spec/skills/grand-design-spec/references/templates/*.md`
Expected: only `00-index.md` and `06-constraints.md` (those don't have compact-conditional content).

- [ ] **Step 7: Commit**

```bash
git add plugins/grand-design-spec/skills/grand-design-spec/references/templates/01-overview.md plugins/grand-design-spec/skills/grand-design-spec/references/templates/02-architecture.md plugins/grand-design-spec/skills/grand-design-spec/references/templates/03-data-model.md plugins/grand-design-spec/skills/grand-design-spec/references/templates/04-flows.md plugins/grand-design-spec/skills/grand-design-spec/references/templates/05-decisions.md
git commit -m "$(cat <<'EOF'
feat(v0.13): annotate templates with compact/full markers

Templates default to full-mode prose. Compact mode (the default)
required the skill to memorize 5 transformation rules: collapse 3-line
TL;DR, drop Entity descriptions, convert API JSON to table, drop
Preconditions/Postconditions/Failure handling, collapse multi-section
ADRs.

Replace memorized rules with mechanical markers: <!-- compact-skip -->
and <!-- full-only --> wrap conditional blocks. Compact rendering notes
inline as HTML comments. Each template carries its own transformation
recipe — skill doesn't have to remember them.

Addresses M-5 + L-1 + L-2 + L-3 + L-4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `CONTRIBUTING.md` with skill-versioning rule

**Files:**
- Create: `CONTRIBUTING.md` (at repo root)

Document the skill-versioning rule decided per M-3: independent semver per skill, with stricter CHANGELOG discipline.

- [ ] **Step 1: Create `CONTRIBUTING.md`**

Create `CONTRIBUTING.md` at the repo root with this exact content:

```markdown
# Contributing to grand-design-spec

## Versioning rules

This repository contains two version axes that move independently:

### Plugin version (`plugin.json` + `marketplace.json`)

Tracks the **distribution unit**. Bumped on every release that ships to users via `/plugin marketplace update`.

- **Major** (1.0.0): breaking change to plugin install/uninstall behavior, command names, or marketplace structure.
- **Minor** (0.X.0): new commands, new skills, new feature areas. Examples: v0.7 added compact mode, v0.11 added vault.json, v0.12 added slash commands.
- **Patch** (0.X.Y): bug fixes, doc updates, version-pin examples.

### Skill version (`SKILL.md` frontmatter)

Tracks the **individual skill's behavior contract**. Bumped only when *that specific skill* changes.

- **Major**: breaking change to skill inputs/outputs (e.g., new mandatory question, removed step).
- **Minor**: new behavior, new self-check, new field written to vault. Bump on first release that adds it.
- **Patch**: bugfix or wording cleanup that doesn't change observable behavior.

**Rule**: skill versions and plugin versions are independent. Do NOT auto-bump every skill on a plugin release — only the skills that actually changed.

### CHANGELOG discipline

Every plugin release entry MUST enumerate per-skill version moves:

```markdown
## [0.13.0] — 2026-05-09

### Skill version moves
- `grand-design-spec`: 0.8.0 → 0.9.0 (referenced shared vault-contract.md, added OQ_BLOCKER self-check)
- `resolve-oq`: 0.2.0 → 0.3.0 (removed lock-vault forward-refs, added vault.json count-match self-check)
- `vault-diff`: 0.1.0 → 0.2.0 (added Step 6.5 vault.json refresh)
- `drift-detect`: unchanged (0.2.0) — boundary documentation only

### Added
...
```

This makes it obvious which skills are different vs the prior release. Without it, contributors and downstream tooling can't tell whether re-running the same skill on the new plugin will behave the same.

## Commit message convention

Use [conventional commits](https://www.conventionalcommits.org/) with version-tagged scopes when the change targets a specific release:

- `feat(v0.13): ...` — new feature for v0.13
- `fix(v0.13): ...` — bugfix for v0.13
- `docs: ...` — documentation only
- `chore: ...` — meta / tooling

## Tagging releases

After merging release commits to `main`:

```bash
git tag v0.13.0
git push origin v0.13.0
```

Tags enable `git#vX.Y.Z` pin examples in the README. Tagging is currently spotty (only v0.3-v0.6 exist on the remote); aim to tag every release going forward.

## Adding a new skill

When adding a new skill to the plugin:

1. Create directory under `plugins/grand-design-spec/skills/<skill-name>/`.
2. Add `SKILL.md` with frontmatter: `name`, `version: 0.1.0`, `description`.
3. Add a corresponding command at `plugins/grand-design-spec/commands/<skill-name>.md` so it appears in slash autocomplete.
4. Reference `references/vault-contract.md` for shared definitions instead of duplicating.
5. Add a CHANGELOG entry that includes the new skill at version 0.1.0.

## Audit + spec workflow

For non-trivial work, follow the spec → plan → implementation pipeline used in this repo:

1. **Audit** existing state, write to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
2. **Plan** the implementation, write to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`.
3. **Execute** via the `superpowers:subagent-driven-development` or `superpowers:executing-plans` skill.

Each phase commits independently — the spec and plan stay as durable artifacts.
```

- [ ] **Step 2: Verify file created**

Run: `ls -la CONTRIBUTING.md`
Expected: file exists, ~3KB.

Run: `head -5 CONTRIBUTING.md`
Expected: shows the title line.

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "$(cat <<'EOF'
docs(v0.13): add CONTRIBUTING.md with versioning + commit conventions

Documents the skill-versioning rule (independent semver per skill,
with CHANGELOG enumerating per-skill moves) decided per audit M-3.
Also captures commit-message scopes, tagging discipline, new-skill
checklist, and the spec/plan workflow.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Bump versions and add CHANGELOG entry

**Files:**
- Modify: `plugins/grand-design-spec/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md`

Final commit. Single atomic commit because version bumps + CHANGELOG must move together.

- [ ] **Step 1: Bump plugin.json version**

Edit `plugins/grand-design-spec/.claude-plugin/plugin.json`:

Replace `"version": "0.12.1"` with `"version": "0.13.0"`.

- [ ] **Step 2: Bump marketplace.json version**

Edit `.claude-plugin/marketplace.json`:

Replace `"version": "0.12.1"` with `"version": "0.13.0"` (in the `plugins[0]` entry).

- [ ] **Step 3: Add CHANGELOG v0.13.0 entry**

Edit `CHANGELOG.md`. Find the line `## [0.12.1] — 2026-05-09` (currently the most recent entry). Insert a new v0.13.0 block immediately before it:

```markdown
## [0.13.0] — 2026-05-09

Driven by the ship-readiness audit at `docs/superpowers/specs/2026-05-09-plugin-audit-design.md`. Closes 3 HIGH and 4 MED audit findings. Acknowledges that v0.11 vault.json parity was incomplete (only `resolve-oq` got write-back; `vault-diff` was missed) and lands the fix.

### Skill version moves

- `grand-design-spec`: 0.8.0 → 0.9.0 (references shared `vault-contract.md`, adds OQ_BLOCKER halt-protocol self-check)
- `resolve-oq`: 0.2.0 → 0.3.0 (removes `lock-vault` forward-references, adds vault.json count-match self-check)
- `vault-diff`: 0.1.0 → 0.2.0 (**adds Step 6.5 vault.json refresh** — closes the v0.11 parity gap)
- `drift-detect`: unchanged at 0.2.0 (documentation-only change: explicit `vault.json` reconciliation boundary)

### Added

- **`references/vault-contract.md`** (M-1, L-8, L-9) — single source of truth for the `vault.json` schema, OQ tagging conventions, status marker semantics, ID stability rules, and "Skill instruction language" boilerplate. All 4 skills now reference it instead of duplicating content.
- **`vault-diff` Step 6.5 — Refresh `vault.json`** (H-1) — after applying approved changes in Step 6, regenerate the manifest from post-apply markdown so `entities[]`, `flows[]`, `adrs[]`, `open_questions[]`, and `open_questions_summary` reflect the new state. Step 8 self-check gains 4 vault.json invariants.
- **`drift-detect` `vault.json` reconciliation boundary** (H-2) — Step 6 now explicitly documents that drift-detect produces reports only and never regenerates `vault.json`. Vault.json regen happens via `resolve-oq` (for OQ-tagged actions) or manual edit + `grand-design-spec` re-run (for entity/flow/ADR additions). Per audit OQ-AUDIT-1 decision: explicit boundary, not auto-reconcile.
- **Template compact/full markers** (M-5) — `01-overview`, `02-architecture`, `03-data-model`, `04-flows`, `05-decisions` templates now carry `<!-- compact-skip -->` and `<!-- full-only -->` HTML comments around mode-conditional content. Replaces 5 memorized runtime transformation rules with mechanical markers. `00-index` and `06-constraints` have no compact-conditional content (unchanged).
- **`grand-design-spec` Step 4 self-check** (M-6) — verifies `00-index.md` contains the "Halt protocol for autonomous runs", "Parallel-work guidance", and "Companion skills for vault evolution" sub-sections per template.
- **`resolve-oq` Step 4 self-check** (M-8) — verifies `vault.json.open_questions_summary.total` matches markdown roll-up; verifies promoted ADRs appear in `vault.json.adrs[]`.
- **`CONTRIBUTING.md`** (M-3) — documents the versioning rule (independent semver per skill, with CHANGELOG enumerating per-skill moves), commit-message scopes, tagging discipline, new-skill checklist, and spec/plan workflow.

### Removed

- **`lock-vault` forward-references** (H-3) — `resolve-oq/SKILL.md` previously mentioned a `lock-vault` skill "(when available)" twice. Replaced with explicit manual-edit instructions for `00-index.md` Vault Lock Status. Building a real `lock-vault` skill is a v0.14+ candidate.

### Changed

- `plugin.json` and `marketplace.json` plugins[0].version bumped 0.12.1 → 0.13.0 (skill behavior changes + new file structure).
- `grand-design-spec/SKILL.md` body shrinks ~60 lines as the duplicated `vault.json` schema and OQ tagging convention move to `vault-contract.md`. Net change: smaller skill body + one new reference file.

### Backward compatibility

- Existing v0.12 vaults continue to work read-only.
- Re-running `vault-diff` against a v0.12 vault now produces an updated `vault.json` (previously skipped). If the v0.12 vault was created before vault.json was introduced (pre-v0.11), Step 6.5 generates a fresh manifest from the markdown.
- Skills that don't bump (drift-detect) maintain the same input/output contract.
- The new `references/vault-contract.md` is referenced by skills but loaded on-demand — no eager-load cost on existing flows that don't touch the schema.

### Notes

- The v0.11 CHANGELOG entry implied vault.json parity that didn't exist for `vault-diff`. v0.13 explicitly closes that gap and the CHANGELOG now enumerates per-skill version moves to prevent the same drift.
- Audit findings deferred to v0.14+: a real `lock-vault` skill (H-3 alternative), template footer extraction (L-10), trigger-phrase canonical source (L-11), OQ category enumeration (M-2), `grand-design-spec/SKILL.md` progressive disclosure (L-12), tag backfill for v0.7-v0.12 (L-7).
```

- [ ] **Step 4: Verify edits applied**

Run: `grep -n "0.13.0" plugins/grand-design-spec/.claude-plugin/plugin.json`
Expected: 1 match.

Run: `grep -n "0.13.0" .claude-plugin/marketplace.json`
Expected: 1 match.

Run: `grep -n "## \[0.13.0\]" CHANGELOG.md`
Expected: 1 match (above the [0.12.1] entry).

Run: `head -50 CHANGELOG.md | grep "Skill version moves"`
Expected: 1 match.

- [ ] **Step 5: Verify all 7 audit findings are closed**

Run a final cross-check that each finding has a corresponding fix in the diff:

```bash
echo "H-1 (vault-diff vault.json write-back):"
grep -c "Step 6.5" plugins/grand-design-spec/skills/vault-diff/SKILL.md

echo "H-2 (drift-detect boundary doc):"
grep -c "vault.json reconciliation boundary" plugins/grand-design-spec/skills/drift-detect/SKILL.md

echo "H-3 (lock-vault refs removed):"
grep -c "lock-vault" plugins/grand-design-spec/skills/resolve-oq/SKILL.md

echo "M-1 (vault-contract.md exists):"
ls plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md && echo "exists"

echo "M-3 (CONTRIBUTING.md exists):"
ls CONTRIBUTING.md && echo "exists"

echo "M-5 (template markers):"
grep -c "compact-skip\|full-only" plugins/grand-design-spec/skills/grand-design-spec/references/templates/*.md | grep -v ":0$"

echo "M-6 (OQ_BLOCKER self-check):"
grep -c "Halt protocol for autonomous" plugins/grand-design-spec/skills/grand-design-spec/SKILL.md

echo "M-8 (resolve-oq vault.json count-match):"
grep -c "open_questions_summary.total matches" plugins/grand-design-spec/skills/resolve-oq/SKILL.md
```

Expected:
- H-1: ≥1
- H-2: ≥1
- H-3: 0 (removed)
- M-1: file exists
- M-3: file exists
- M-5: at least 5 templates with markers
- M-6: ≥1
- M-8: ≥1

- [ ] **Step 6: Commit**

```bash
git add plugins/grand-design-spec/.claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(v0.13): bump versions and add CHANGELOG entry

Plugin 0.12.1 → 0.13.0. Closes 3 HIGH (H-1 vault-diff write-back,
H-2 drift-detect boundary, H-3 lock-vault refs) and 4 MED (M-1 shared
contract, M-3 versioning rule, M-5 template markers, M-6/M-8 self-checks)
audit findings.

CHANGELOG v0.13.0 entry enumerates per-skill version moves —
grand-design-spec 0.9.0, resolve-oq 0.3.0, vault-diff 0.2.0,
drift-detect 0.2.0 unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

**Spec coverage:**

| Spec finding | Plan task | Covered? |
|--------------|-----------|----------|
| H-1 vault-diff vault.json write-back | Task 4 | ✅ Step 2 adds Step 6.5; Step 3 adds self-check |
| H-2 drift-detect vault.json reconciliation | Task 5 | ✅ explicit-boundary-doc per OQ-AUDIT-1 |
| H-3 lock-vault forward-references | Task 3 | ✅ both refs (resolve-oq lines 66 + 237) replaced |
| M-1 shared vault.json schema | Task 1 + Task 2 step 3 | ✅ contract file + skill references it |
| L-8 OQ tagging convention duplication | Task 1 + Task 2 step 4 | ✅ contract file + skill references it |
| L-9 "Skill instruction language" duplication | Task 1 §boilerplate | ✅ shared shim |
| M-3 skill-versioning rule | Task 7 | ✅ CONTRIBUTING.md |
| M-5 template compact/full markers | Task 6 | ✅ 5 templates annotated |
| M-6 OQ_BLOCKER self-check | Task 2 step 2 | ✅ added to grand-design-spec Step 4 |
| M-8 resolve-oq vault.json count match | Task 3 step 4 | ✅ added to resolve-oq Step 4 |

All 7 priority items covered.

**Placeholder scan:** none. Every step contains the actual content to insert.

**Type consistency:** the file paths used are absolute and consistent across tasks. Skill version targets match the CHANGELOG entry in Task 8 (gds 0.9.0, resolve-oq 0.3.0, vault-diff 0.2.0, drift-detect 0.2.0 unchanged).

---

Plan complete and saved to `docs/superpowers/plans/2026-05-09-v013-ship-readiness.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration. 8 tasks × ~2-3 minute review = ~20-30 min total.
2. **Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints. Single context, no fresh-eyes review.

Which approach?
