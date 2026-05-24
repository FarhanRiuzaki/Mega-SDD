# Iter 34 Dynamic Model Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add curated model-tiers catalog mapping 17 named subagent roles → tier (haiku/sonnet/opus); orchestrate-flow Step 2.8 resolves override chain; sub-skills cite catalog instead of hardcoding. User overrides via CLI flag / project config / user preference.

**Architecture:** Static catalog at `plugins/mega-sdd/references/model-tiers.md` covering 17 roles across 4 dispatch categories. orchestrate-flow Step 2.8 (inserted between existing Iter 33 Step 2.7 routing preflight + Step 3 chain build) reads override chain + emits resolved tiers in handoff metadata. Sub-skills consume via existing Iter 33 handoff metadata propagation pattern (no new mechanism). Backward-compat: absent overrides → catalog default; absent catalog citation → inherit caller.

**Tech Stack:** Markdown-driven. Plugin v3.24.0 → v3.25.0. orchestrate-flow v3.0.0 → v3.1.0.

**Spec source:** `docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md`

---

## ⚠️ Step-number corrections (post-write deep-search audit)

Deep-search of actual orchestrate-flow SKILL.md confirms existing step structure after Iter 33:

`1 → 2 → 2.5 → 2.7 (Iter 33 F1) → 3 → 3.5 (Iter 33 F2) → 4 → 5 → 6 → 7 → 7.5 (Iter 33 F1 write) → 8`

**Step 2.8 inserts BETWEEN existing 2.7 + 3.** No conflict; clean placement.

Tasks unaffected by step-number ambiguity (catalog file is new; handoff schema extension is at well-defined section).

---

## File Structure

### New files (1)

| Path | Responsibility |
|---|---|
| `plugins/mega-sdd/references/model-tiers.md` | Catalog (17 roles × tier + rationale) + tier selection rubric + override syntax + adding-new-roles protocol |

### Modified files

| Path | Change | Version |
|---|---|---|
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | + Step 2.8 override-chain resolution; + handoff metadata model_tiers emission; + model_tier_unknown SOFT halt entry | 3.0.0 → 3.1.0 |
| `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` | + `model_tiers:` top-level block schema (REQUIRED/CONDITIONAL/OPTIONAL + TYPE per Iter 33 F3+F4) | — |
| `plugins/mega-sdd/skills/scan-codebase/SKILL.md` | Replace 4 hardcoded `model: sonnet` with catalog citations | 2.6.0 → 2.6.1 |
| `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` | Same replacement | — |
| `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` | Add catalog citations to 5 wave dispatches | 1.4.1 → 1.5.0 |
| `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` | Same | — |
| `plugins/mega-sdd/skills/memory/SKILL.md` | + preferences.md `## Model tiers` section documentation | 1.3.0 → 1.3.1 |
| `plugins/mega-sdd/skills/memory/references/memory-schema.md` | + preferences.md schema extension for model_tiers | — |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | + model_tier_unknown halt type to enum + description | — |
| `plugins/mega-sdd/references/paths.md` | + note: `.mega-sdd/config.yaml` model_tiers override location | — |
| `tests/skill-triggering/orchestrate-flow.test.md` | + 3 cases (OF-MT1/2/3) | — |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | 3.24.0 → 3.25.0 | — |
| `CHANGELOG.md` | + [3.25.0] - 2026-05-24 Iter 34 entry | — |
| `plugins/mega-sdd/README.md` | + "What's new in v3.25.0" subsection | — |
| `README.md` (repo root) | Version bump 3.24.0 → 3.25.0 (3 spots) | — |

---

## Task ordering

4 tasks, ~8hr total:

1. **Task 1 — Catalog creation** (~2hr): write model-tiers.md catalog
2. **Task 2 — orchestrate-flow Step 2.8 + handoff schema + halt** (~2hr): override resolution + schema extension + halt sync
3. **Task 3 — Dispatch citations + memory schema** (~2hr): update 4 dispatch categories to cite catalog + preferences.md schema
4. **Task 4 — Tests + release v3.25.0** (~2hr): trigger tests + plugin/CHANGELOG/READMEs + push

---

## Task 1: Catalog creation

**Files:**
- Create: `plugins/mega-sdd/references/model-tiers.md`

- [ ] **Step 1.1: Write model-tiers.md catalog**

Write to `plugins/mega-sdd/references/model-tiers.md`:

```markdown
# Model Tiers Catalog

> Single source of truth for which model tier each named subagent role uses across the mega-sdd plugin.

**Version:** 1.0
**Introduced:** v3.25.0 (Iter 34)
**Consumed by:** all SKILL.md subagent dispatch sites (cite via `references/model-tiers.md §<role-name>`)
**Resolved by:** `mega-sdd:orchestrate-flow` v3.1.0+ Step 2.8 (override chain: CLI > project config > user preference > catalog default)

---

## Tier selection rubric

Pick the LEAST powerful model that can handle the task. Each tier has clear criteria:

### haiku — pick when ALL of these hold
- Task is bounded scope (≤2 files read, ≤1KB output)
- Decision space is narrow (enum-like classification; ≤5 distinct outputs possible)
- No multi-document synthesis required
- No architectural reasoning required
- Speed/cost dominates quality requirement

**Examples:** per-skill intelligence probe scoring (0-3 scale); manifest-only lib detection; catalog lookup.

### sonnet — pick when ANY of these hold (default)
- Pattern recognition across multiple documents
- Fuzzy classification (e.g., "is this Sanctum or Breeze?" — multiple signals to weigh)
- Structured synthesis with known output schema
- Bounded reasoning depth (≤5 reasoning steps)
- Mid-range cost/quality tradeoff

**Examples:** deep-scan extractors (auth/rbac/ui-ux/libs); pipeline-audit per-skill; spec-reviewer; implementer for typical tasks.

### opus — pick when ANY of these hold
- Open-ended reasoning (no fixed output schema)
- Holistic synthesis across many sources (≥10 documents OR ≥5 categories)
- Architectural decisions (skill body design, schema design, halt taxonomy decisions)
- Deep code review (cross-cutting concerns, security, performance)
- Cross-cutting pattern detection across a codebase

**Examples:** extract-intelligence wave-5 synthesis; intelligence-audit deep dimension analysis; code-quality-reviewer; pipeline-audit consolidator.

### Default when in doubt: sonnet

Sonnet is the safe middle ground. Escalate to opus only with concrete evidence the task needs broader reasoning. Drop to haiku only when scope is provably bounded.

---

## Catalog

| # | Role | Tier | Rationale |
|---|---|---|---|
| 1 | `auth-extractor` | sonnet | Fuzzy detection across 5 auth libs + version + features; multi-file evidence (scan-codebase Iter 32) |
| 2 | `rbac-extractor` | sonnet | Same pattern; 3 RBAC libs + middleware + policies (scan-codebase Iter 32) |
| 3 | `ui-ux-extractor` | sonnet | Multi-domain (JS+CSS+notification+icon+datatable+idioms); empirically-grounded idiom inference needs reasoning (scan-codebase Iter 32) |
| 4 | `libs-extractor` | sonnet | Manifest parsing + category mapping + usage-hint grep across many libs (scan-codebase Iter 32) |
| 5 | `extract-intelligence-wave-1` | sonnet | Artifact extraction; bounded artifact-set per agent (extract-intelligence) |
| 6 | `extract-intelligence-wave-2` | sonnet | Domain extraction; pattern recognition + multi-source synthesis |
| 7 | `extract-intelligence-wave-3` | sonnet | Cross-reference resolution across domain docs |
| 8 | `extract-intelligence-wave-4` | sonnet | Mutability tier classification (LOCKED/INTENT/ARTIFACT) with criteria |
| 9 | `extract-intelligence-wave-5` | **opus** | Holistic synthesis across all prior waves; main-thread; needs broadest context |
| 10 | `pipeline-audit-per-skill` | sonnet | Forensic audit across 10 dimensions per skill; bounded scope per skill (Iter 31 style) |
| 11 | `pipeline-audit-consolidator` | **opus** | Cross-skill pattern detection; consolidates 13 YAML inputs; broad reasoning (Iter 31 style) |
| 12 | `intelligence-audit-deep` | sonnet | 6-dimension audit on orchestrate-flow + handoff-contract; bounded (Iter 33 Phase B) |
| 13 | `intelligence-audit-probe` | **haiku** | Per-skill 0-3 scoring + 1-sentence justification; narrow decision space (Iter 33 Phase B) |
| 14 | `implementer` | sonnet | Typical implementation task (subagent-driven-development pattern); user can override to opus for complex tasks |
| 15 | `spec-reviewer` | sonnet | Compliance verification against spec (subagent-driven-development pattern) |
| 16 | `code-quality-reviewer` | **opus** | Deep code review; cross-cutting concerns; security/performance (subagent-driven-development pattern) |
| 17 | `domain-research` | **haiku** | Web fetches + structured extraction; low reasoning depth |

**Distribution:** 3 opus + 11 sonnet + 3 haiku. Sonnet-dominant by design.

---

## Override syntax

### CLI flag (per-run override)

```bash
/mega-sdd:auto --model-tier=code-quality-reviewer:sonnet ./prd.md
# multiple overrides allowed:
/mega-sdd:auto --model-tier=audit-consolidator:opus --model-tier=audit-probe:sonnet
```

### Per-project config

`<project>/.mega-sdd/config.yaml`:
```yaml
model_tiers:
  code-quality-reviewer: sonnet  # team prefers cheaper reviews on this project
  intelligence-audit-probe: sonnet  # bump from haiku to sonnet for higher signal
```

### User-scope preference

`~/.mega-sdd/memory/preferences.md`:
```markdown
## Model tiers

- `code-quality-reviewer`: sonnet  # personal preference (overrides catalog default opus)
- `extract-intelligence-wave-5`: sonnet  # cost-sensitive default
```

### Override chain precedence

CLI flag > per-project config > user-scope preference > catalog default.

Highest applicable override wins. If no override applies, catalog default is used.

---

## Adding new roles

When a future iter introduces a new subagent dispatch:

1. Pick a tier using **Tier selection rubric** above
2. Add a catalog entry to **Catalog** with:
   - Role name (unique kebab-case)
   - Tier (haiku|sonnet|opus)
   - Rationale (1-sentence why this tier, not the others)
3. Update the skill's SKILL.md subagent dispatch instruction to cite the catalog:
   `Model: per references/model-tiers.md §<role-name>`
4. If the role is a candidate for user override, document the override path in the role rationale.

**DO NOT hardcode `model: <tier>` in SKILL.md procedures**; always cite the catalog. This keeps tier choices auditable + centrally tunable.

---

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 2.8 (override resolution)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` §`model_tiers:` (handoff metadata schema)
- `plugins/mega-sdd/skills/memory/references/memory-schema.md` §preferences.md (user-scope override location)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` §halt-protocol (`model_tier_unknown` halt definition)
```

- [ ] **Step 1.2: Verify catalog file**

```bash
test -f plugins/mega-sdd/references/model-tiers.md && wc -l plugins/mega-sdd/references/model-tiers.md
grep -c "^| [0-9]" plugins/mega-sdd/references/model-tiers.md
```

Expected: file ≥150 lines; 17 catalog rows (one per role).

- [ ] **Step 1.3: Commit Task 1**

```bash
git add plugins/mega-sdd/references/model-tiers.md
git commit -m "$(cat <<'EOF'
docs(iter-34): canonical model-tiers catalog (foundation)

NEW: plugins/mega-sdd/references/model-tiers.md

Maps 17 named subagent roles across 4 dispatch categories to model tier
(haiku/sonnet/opus) with explicit rationale per entry.

Distribution: 3 opus + 11 sonnet + 3 haiku (sonnet-dominant by design).

Includes:
- Tier selection rubric (haiku/sonnet/opus criteria for "find the best")
- Catalog (17 roles × tier + rationale)
- Override syntax (CLI flag + project config + user preference)
- Adding new roles protocol (for future iter contributors)

Foundation for Tasks 2-4 (orchestrate-flow Step 2.8 resolution + skill
dispatch citations + tests + release).
EOF
)"
```

---

## Task 2: orchestrate-flow Step 2.8 + handoff schema + halt sync

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (Step 2.8 + halt entry + version bump)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (model_tiers schema annotations)
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (model_tier_unknown halt enum + description)

- [ ] **Step 2.1: Bump orchestrate-flow version 3.0.0 → 3.1.0**

Edit frontmatter:
```yaml
version: 3.1.0
```

- [ ] **Step 2.2: Add Step 2.8 to orchestrate-flow SKILL.md**

Locate existing Step 2.7 (line ~77 — Iter 33 F1 memory-informed routing preflight) and Step 3 (line ~96 — Build proposed chain). Insert NEW Step 2.8 BETWEEN them:

```markdown
2.8. **Model-tier override resolution (v3.1.0+, Iter 34).**

Per `references/model-tiers.md` override syntax. Resolves model tier per named subagent role from override chain. Default-on; no flag needed to invoke.

a. **Read CLI flags from invocation**: collect all `--model-tier=<role>:<tier>` flags into a dict `cli_overrides`.

b. **Read `<project>/.mega-sdd/config.yaml`**: parse `model_tiers:` section if present; build `project_overrides` dict.

c. **Read `~/.mega-sdd/memory/preferences.md` `## Model tiers` section**: build `user_overrides` dict.

d. **Compute final resolved tier per role** (override chain precedence: CLI > project > user > catalog):
   - For each role mentioned in any override source:
     - If role in cli_overrides → use cli value
     - Else if role in project_overrides → use project value
     - Else if role in user_overrides → use user value
     - Else → use catalog default (read from `plugins/mega-sdd/references/model-tiers.md` §Catalog)

e. **Emit final `model_tiers:` dict in handoff metadata** for all downstream skills:
   ```yaml
   metadata:
     model_tiers:
       auth-extractor: sonnet
       rbac-extractor: sonnet
       code-quality-reviewer: sonnet  # override applied — was opus in catalog
       # ... (all 17 roles or subset that's in overrides)
     model_tier_sources:  # provenance trail for debugging (OPTIONAL)
       auth-extractor: catalog
       code-quality-reviewer: project-config
   ```

f. **Forward-compat tolerance**: if any role mentioned in override sources doesn't exist in catalog → emit SOFT halt `model_tier_unknown` (warn-only); log warning; ignore that override; chain proceeds with catalog default for unknown roles.

g. **Logging**: log resolved tier summary to chain output for user audit, e.g.:
   `Model tier overrides applied: code-quality-reviewer=sonnet (project-config); audit-probe=sonnet (cli-flag)`

h. **No file writes** — Step 2.8 is purely resolution; resolved tiers live in handoff metadata only.
```

- [ ] **Step 2.3: Update orchestrate-flow handoff emission to include model_tiers**

Locate orchestrate-flow's handoff emission YAML example. Add `metadata.model_tiers` to emitted block:

```yaml
metadata:
  memory_context: { ... }   # existing Iter 5
  memory_writes: [ ... ]    # existing Iter 5
  model_tiers:              # NEW v3.1.0+, Iter 34
    auth-extractor: sonnet
    code-quality-reviewer: opus
    # ... (all roles relevant to chain)
  model_tier_sources:       # NEW v3.1.0+ (optional, debug provenance)
    auth-extractor: catalog
    code-quality-reviewer: catalog
```

- [ ] **Step 2.4: Register model_tier_unknown SOFT halt in orchestrate-flow SKILL.md**

Locate SOFT halts subsection (added in Iter 32 Task 4). Append:

```markdown
- `model_tier_unknown` (v3.1.0+, Iter 34) — orchestrate-flow: override source references a role not in model-tiers.md catalog. Auto-ignore + log; chain proceeds with catalog default. Forward-compat.
```

Add halt YAML envelope inline near Step 2.8 procedure:

```yaml
# Example model_tier_unknown envelope:
type: model_tier_unknown
source_skill: orchestrate-flow
details:
  unknown_role: "some-future-role"
  override_source: "project-config"
  override_file: "<project>/.mega-sdd/config.yaml:line-N"
next_action:
  type: log_and_continue
  hint: "Role 'some-future-role' not found in references/model-tiers.md catalog. Override ignored. Either remove from override OR add the role to the catalog if it's a real subagent role."
```

- [ ] **Step 2.5: Add model_tier_unknown to vault-contract.md halt enum**

Edit `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`. Extend type enum line (already extended in Iter 33 with 4 + 15 halts):

```
type: ... | model_tier_unknown
```

Add description below the type enum:

```markdown
- `model_tier_unknown` — orchestrate-flow v3.1.0+, Iter 34: model-tier override references a role not in references/model-tiers.md catalog. SOFT halt: log + ignore override; chain proceeds with catalog default for unknown roles. Forward-compat for future role additions.
```

- [ ] **Step 2.6: Add model_tiers schema block to handoff-contract.md**

Edit `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`. Two changes:

(a) Add to §Handoff YAML schema (near top): add `model_tiers:` as a top-level field documented inline.

(b) Add to §Field-level schema annotations (line ~81, Iter 33 F3 section). Add new annotation block after `starterkit_context:`:

```markdown
### `model_tiers:` (CONDITIONAL — if v3.1.0+ orchestrate-flow resolved overrides; v3.25.0+, Iter 34)

TYPE: object {
  <role-name>: enum (haiku | sonnet | opus)
}

Resolved model tier per named subagent role. Sub-skills consult this block before each subagent dispatch; absent role-name → use catalog default per `references/model-tiers.md` §Catalog.

Companion field: `model_tier_sources:` (OPTIONAL) — same keys; values are the override source for each tier (`catalog` | `user` | `project` | `cli`) for debugging.
```

- [ ] **Step 2.7: Verify Task 2 deliverables**

```bash
echo "=== orchestrate-flow version + Step 2.8 ==="
grep "^version:\|^2.8\.\|Step 2.8" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -5
echo "=== model_tier_unknown halt across 3 surfaces ==="
grep -c "model_tier_unknown" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md plugins/mega-sdd/skills/generate-intent/references/vault-contract.md plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
echo "=== model_tiers schema in handoff-contract ==="
grep "model_tiers:" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | head -3
```

Expected: orchestrate-flow version 3.1.0; Step 2.8 ≥2 matches; halt present in vault-contract + orchestrate-flow; model_tiers in handoff-contract.

- [ ] **Step 2.8: Commit Task 2**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md \
        plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(iter-34): orchestrate-flow Step 2.8 — model-tier override resolution

orchestrate-flow v3.0.0 → v3.1.0 (Step 2.8 added).

NEW Step 2.8 (between Iter 33 Step 2.7 routing preflight + Step 3 chain build):
- Reads override chain (CLI > project config > user preference > catalog)
- Resolves final tier per named subagent role
- Emits metadata.model_tiers: + metadata.model_tier_sources: in handoff
- Forward-compat: unknown roles → soft halt model_tier_unknown + log + ignore

NEW soft halt model_tier_unknown synchronized across 3 surfaces:
- vault-contract.md type enum + description
- orchestrate-flow SOFT halts subsection + Step 2.8 envelope example
- handoff-contract.md model_tiers: schema block (REQUIRED/CONDITIONAL/OPTIONAL
  + TYPE per Iter 33 F3+F4)

Sub-skills consume metadata.model_tiers via existing Iter 33 handoff
propagation pattern (no new mechanism).
EOF
)"
```

---

## Task 3: Dispatch citations + memory schema

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/SKILL.md` (replace 4 hardcoded `model: sonnet` with catalog citations; bump 2.6.0 → 2.6.1)
- Modify: `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` (replace hardcoded model: sonnet)
- Modify: `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` (add catalog citations to 5 wave dispatches; bump 1.4.1 → 1.5.0)
- Modify: `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` (catalog citations per wave)
- Modify: `plugins/mega-sdd/skills/memory/SKILL.md` (preferences.md `## Model tiers` doc; bump 1.3.0 → 1.3.1)
- Modify: `plugins/mega-sdd/skills/memory/references/memory-schema.md` (extend preferences.md schema with `## Model tiers` section)
- Modify: `plugins/mega-sdd/references/paths.md` (note config.yaml model_tiers location)

- [ ] **Step 3.1: Update scan-codebase deep-scan dispatch citations**

Edit `plugins/mega-sdd/skills/scan-codebase/SKILL.md`. Locate lines 234-237 (4 named subagents with `model: sonnet`):

Replace:
```
1. **auth-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/auth-libs.md`
2. **rbac-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/rbac-libs.md`
3. **ui-ux-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/ui-libs.md`
4. **libs-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/generic-libs.md`
```

With:
```
1. **auth-extractor** — model: per `references/model-tiers.md §auth-extractor` (default sonnet); catalog: `lib-patterns/<framework>/auth-libs.md`
2. **rbac-extractor** — model: per `references/model-tiers.md §rbac-extractor` (default sonnet); catalog: `lib-patterns/<framework>/rbac-libs.md`
3. **ui-ux-extractor** — model: per `references/model-tiers.md §ui-ux-extractor` (default sonnet); catalog: `lib-patterns/<framework>/ui-libs.md`
4. **libs-extractor** — model: per `references/model-tiers.md §libs-extractor` (default sonnet); catalog: `lib-patterns/<framework>/generic-libs.md`
```

Add note immediately below:
> If invoked via orchestrate-flow chain, model tier may be overridden via handoff metadata.model_tiers per role (CLI flag / project config / user preference). Standalone invocation uses catalog default unconditionally.

Bump scan-codebase version 2.6.0 → 2.6.1.

- [ ] **Step 3.2: Update deep-scan-prompts.md citation**

Edit `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` line 277. Replace:
```
Each Agent call uses the appropriate prompt template above with placeholder substitutions, model: sonnet.
```

With:
```
Each Agent call uses the appropriate prompt template above with placeholder substitutions; model resolved from `plugins/mega-sdd/references/model-tiers.md` §<role-name> (default sonnet for all 4 extractors) OR from handoff metadata.model_tiers if override applied.
```

- [ ] **Step 3.3: Update extract-intelligence wave dispatch citations**

Edit `plugins/mega-sdd/skills/extract-intelligence/SKILL.md`. Locate wave-based execution section (~line 71-90; per Iter 32 deep-search). For each of 5 waves, add a model citation note in the wave description:

Locate the wave table or wave descriptions. After each wave name, add:
- Wave 1: `(model: per references/model-tiers.md §extract-intelligence-wave-1, default sonnet)`
- Wave 2: `(model: per references/model-tiers.md §extract-intelligence-wave-2, default sonnet)`
- Wave 3: `(model: per references/model-tiers.md §extract-intelligence-wave-3, default sonnet)`
- Wave 4: `(model: per references/model-tiers.md §extract-intelligence-wave-4, default sonnet)`
- Wave 5: `(model: per references/model-tiers.md §extract-intelligence-wave-5, default opus — synthesis needs holistic context)`

Use Read FIRST to find exact insertion points in current wave structure.

Bump extract-intelligence version 1.4.1 → 1.5.0.

- [ ] **Step 3.4: Update wave-dispatch-templates.md citations**

Edit `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md`. Add a header note near top (after existing introduction):

```markdown
## Model tier per wave (v3.25.0+, Iter 34)

Each wave dispatch consults `plugins/mega-sdd/references/model-tiers.md` for its model tier:

- **Wave 1** (artifact extraction): `extract-intelligence-wave-1` → default sonnet
- **Wave 2** (domain extraction): `extract-intelligence-wave-2` → default sonnet
- **Wave 3** (cross-reference): `extract-intelligence-wave-3` → default sonnet
- **Wave 4** (mutability classification): `extract-intelligence-wave-4` → default sonnet
- **Wave 5** (synthesis): `extract-intelligence-wave-5` → **default opus** (holistic synthesis)

Override per role via CLI flag / project config / user preference (see `references/model-tiers.md §Override syntax`).
```

- [ ] **Step 3.5: Add Model tiers section to memory-schema.md preferences.md schema**

Edit `plugins/mega-sdd/skills/memory/references/memory-schema.md`. Locate `### ~/.mega-sdd/memory/preferences.md` schema section (line ~85). Within the schema block (after `## Project-shape preferences` subsection), add:

```markdown
## Model tiers (v1.3.1+, Iter 34)

Per-role model tier override (user-scope). Lower precedence than CLI flag + project config; higher than catalog default.

Format (markdown list):

\`\`\`markdown
## Model tiers

- `code-quality-reviewer`: sonnet  # personal preference (overrides catalog default opus)
- `extract-intelligence-wave-5`: sonnet  # cost-sensitive default
- `intelligence-audit-probe`: sonnet  # bump from haiku for higher signal
\`\`\`

Format: one bullet per role override. `<role>: <tier>` where tier is `haiku | sonnet | opus`.

Role names MUST match `plugins/mega-sdd/references/model-tiers.md §Catalog`. Unknown roles trigger `model_tier_unknown` soft halt + log + ignored.
```

- [ ] **Step 3.6: Update memory SKILL.md to document preferences.md model_tiers**

Edit `plugins/mega-sdd/skills/memory/SKILL.md`. Locate `## Memory layer` or `## Memory architecture` section. Find the entry for `preferences.md` (user scope). Add a new sub-entry:

```markdown
### preferences.md `## Model tiers` section (v1.3.1+, Iter 34)

User-scope per-role model tier override. Format: markdown list with `- <role>: <tier>` per line. Schema: see `references/memory-schema.md §Model tiers`. Consumed by orchestrate-flow v3.1.0+ Step 2.8 override-chain resolution.
```

Bump memory version 1.3.0 → 1.3.1.

- [ ] **Step 3.7: Update paths.md**

Edit `plugins/mega-sdd/references/paths.md`. Locate per-skill path mapping table. Add a NEW row (or extend existing config.yaml row) for model_tiers location:

```markdown
| `orchestrate-flow` | model-tiers config | `.mega-sdd/config.yaml` (per-project `model_tiers:` section) | (no legacy back-compat — introduced v3.25.0+) |
```

If `.mega-sdd/config.yaml` already has a paths.md row, add a note about the `model_tiers:` section instead of creating a duplicate row.

- [ ] **Step 3.8: Verify Task 3 deliverables**

```bash
echo "=== Catalog citations across 4 dispatch sites ==="
grep "references/model-tiers.md" plugins/mega-sdd/skills/scan-codebase/SKILL.md plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md plugins/mega-sdd/skills/extract-intelligence/SKILL.md plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md | wc -l
echo "=== Skill versions ==="
grep "^version:" plugins/mega-sdd/skills/scan-codebase/SKILL.md plugins/mega-sdd/skills/extract-intelligence/SKILL.md plugins/mega-sdd/skills/memory/SKILL.md
echo "=== memory-schema model_tiers section ==="
grep "## Model tiers\|model_tiers" plugins/mega-sdd/skills/memory/references/memory-schema.md | head -3
echo "=== paths.md config.yaml row ==="
grep "config.yaml\|model_tiers" plugins/mega-sdd/references/paths.md | head -3
```

Expected: ≥8 catalog citations across 4 files; scan-codebase 2.6.1 + extract-intelligence 1.5.0 + memory 1.3.1; memory-schema has Model tiers section; paths.md has config.yaml note.

- [ ] **Step 3.9: Commit Task 3**

```bash
git add plugins/mega-sdd/skills/scan-codebase/SKILL.md \
        plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md \
        plugins/mega-sdd/skills/extract-intelligence/SKILL.md \
        plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md \
        plugins/mega-sdd/skills/memory/SKILL.md \
        plugins/mega-sdd/skills/memory/references/memory-schema.md \
        plugins/mega-sdd/references/paths.md
git commit -m "$(cat <<'EOF'
feat(iter-34): catalog citations across 4 dispatch categories + memory schema

scan-codebase v2.6.0 → v2.6.1: 4 deep-scan dispatches (auth/rbac/ui-ux/
libs-extractor) now cite references/model-tiers.md instead of hardcoded
'model: sonnet'. Same change applied to deep-scan-prompts.md note.

extract-intelligence v1.4.1 → v1.5.0: 5 wave dispatches (waves 1-5) cite
catalog. wave-5 defaults to opus (synthesis), others sonnet. wave-dispatch-
templates.md gains "Model tier per wave" section.

memory v1.3.0 → v1.3.1: preferences.md `## Model tiers` section documented
in both SKILL.md (consumer doc) and memory-schema.md (schema definition).

paths.md: notes .mega-sdd/config.yaml model_tiers: override location.

Coverage: 4 of 4 dispatch categories per spec acceptance #6.
Remaining categories (audit dispatches + subagent-driven-development
pattern) live in workflow docs (docs/superpowers/) not in skill bodies,
so no per-skill change needed there — catalog is the canonical reference.
EOF
)"
```

---

## Task 4: Tests + release v3.25.0

**Files:**
- Modify: `tests/skill-triggering/orchestrate-flow.test.md` (+ 3 cases OF-MT1/2/3)
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (3.24.0 → 3.25.0)
- Modify: `CHANGELOG.md` (+ Iter 34 entry)
- Modify: `plugins/mega-sdd/README.md` (+ "What's new in v3.25.0")
- Modify: `README.md` (repo root, version bump 3.24.0 → 3.25.0 — 3 spots)

- [ ] **Step 4.1: Add 3 OF-MT cases to orchestrate-flow.test.md**

Append to `tests/skill-triggering/orchestrate-flow.test.md` under `## Iter 34 — Model tier resolution (v3.1.0+)`:

```markdown
### OF-MT1 — Catalog defaults applied (no overrides)

**Setup:**
- No CLI `--model-tier` flag
- No `<project>/.mega-sdd/config.yaml` `model_tiers:` section
- No `~/.mega-sdd/memory/preferences.md` `## Model tiers` section

**Trigger:** `/mega-sdd:auto ./prd.md`

**Expected:**
- Step 2.8 reads all 3 override sources (cli_overrides, project_overrides, user_overrides) — all empty
- For each role mentioned in chain → use catalog default per `references/model-tiers.md §Catalog`
- handoff metadata.model_tiers emitted with catalog defaults
- metadata.model_tier_sources = {role: "catalog"} for every entry
- No `model_tier_unknown` halt fired
- Subagent dispatches (e.g., scan-codebase deep-scan) use catalog defaults (sonnet for auth/rbac/ui-ux/libs-extractors)

### OF-MT2 — CLI flag overrides project config + user preference

**Setup:**
- CLI flag: `--model-tier=code-quality-reviewer:sonnet`
- `<project>/.mega-sdd/config.yaml` has `model_tiers: { code-quality-reviewer: haiku }`
- `~/.mega-sdd/memory/preferences.md` `## Model tiers` has `- code-quality-reviewer: sonnet`

**Trigger:** `/mega-sdd:auto --model-tier=code-quality-reviewer:sonnet ./prd.md`

**Expected:**
- Step 2.8 override chain resolves code-quality-reviewer to `sonnet` (CLI wins; project=haiku ignored; user=sonnet ignored — same result but CLI takes precedence)
- metadata.model_tier_sources.code-quality-reviewer = "cli"
- Log output mentions: "Model tier overrides applied: code-quality-reviewer=sonnet (cli-flag)"
- All other roles use catalog defaults
- Subagent dispatch uses sonnet for code-quality-reviewer (NOT catalog opus default)

### OF-MT3 — Unknown role in override triggers soft halt + chain continues

**Setup:**
- `<project>/.mega-sdd/config.yaml` has `model_tiers: { future-unreleased-role: opus, audit-probe: sonnet }`
- `future-unreleased-role` is NOT in `references/model-tiers.md §Catalog`
- `audit-probe` IS in catalog (intelligence-audit-probe)

**Trigger:** `/mega-sdd:auto ./prd.md`

**Expected:**
- Step 2.8 processes project_overrides
- `future-unreleased-role` unknown → emit soft halt `model_tier_unknown` (warn-only)
- halt envelope: details.unknown_role="future-unreleased-role"; override_source="project-config"
- Log message: "Role 'future-unreleased-role' not found in catalog; override ignored"
- `audit-probe` (valid catalog entry: intelligence-audit-probe) override applied — sonnet (was haiku default)
- Chain PROCEEDS (soft halt; not chain-stopping)
- metadata.model_tiers does NOT include future-unreleased-role; DOES include audit-probe with sonnet
- Forward-compat: future iter adding `future-unreleased-role` to catalog would auto-pick up the project's existing override on next run
```

- [ ] **Step 4.2: Bump plugin.json version**

Edit `plugins/mega-sdd/.claude-plugin/plugin.json`:
```json
"version": "3.25.0",
```

- [ ] **Step 4.3: Add CHANGELOG entry**

Edit `CHANGELOG.md`. Add at TOP (after file header, above existing [3.24.0] entry):

```markdown
## [3.25.0] - 2026-05-24

### Iter 34 — Dynamic Model Selection per Subagent Dispatch

**Feature iter** (~8hr): adds curated model-tiers catalog + override chain so every named subagent role uses the right model tier.

**Skills bumped:**
- `orchestrate-flow` 3.0.0 → 3.1.0 (Step 2.8 override-chain resolution)
- `scan-codebase` 2.6.0 → 2.6.1 (catalog citation; no behavior change)
- `extract-intelligence` 1.4.1 → 1.5.0 (catalog citation; wave-5 default → opus)
- `memory` 1.3.0 → 1.3.1 (preferences.md `## Model tiers` schema)

**New plugin files (1):**
- `plugins/mega-sdd/references/model-tiers.md` — catalog (17 roles × tier + rationale) + tier selection rubric + override syntax + adding-new-roles protocol

**Modified reference docs:**
- `handoff-contract.md` — + `model_tiers:` top-level block schema (REQUIRED/CONDITIONAL/OPTIONAL + TYPE per Iter 33 F3+F4)
- `vault-contract.md` — + `model_tier_unknown` halt type + description
- `memory-schema.md` — + preferences.md `## Model tiers` section
- `paths.md` — note .mega-sdd/config.yaml model_tiers override location
- `scan-codebase/references/deep-scan-prompts.md` — model citation
- `extract-intelligence/references/wave-dispatch-templates.md` — per-wave catalog citation

**1 new halt type** (registered across 4 surfaces per audit-pattern-prevention):
- `model_tier_unknown` (SOFT, orchestrate-flow Step 2.8) — override references role not in catalog. Log + ignore + chain proceeds. Forward-compat for future role additions.

**Catalog coverage — 17 roles across 4 dispatch categories:**

| Category | Roles | Tier mix |
|---|---|---|
| scan-codebase deep-scan (Iter 32) | auth-extractor, rbac-extractor, ui-ux-extractor, libs-extractor | 4× sonnet |
| extract-intelligence waves | wave-1, wave-2, wave-3, wave-4 | 4× sonnet |
| extract-intelligence synthesis | wave-5 | **1× opus** |
| Audit patterns | pipeline-audit-per-skill, pipeline-audit-consolidator, intelligence-audit-deep, intelligence-audit-probe | 2× sonnet + 1× **opus** + 1× **haiku** |
| Subagent-driven-development | implementer, spec-reviewer, code-quality-reviewer | 2× sonnet + 1× **opus** |
| Other | domain-research | 1× **haiku** |

Distribution: **3 opus + 11 sonnet + 3 haiku** (sonnet-dominant by design per tier rubric).

**Override chain (highest precedence first):**
1. CLI flag: `--model-tier=<role>:<tier>` (multiple allowed)
2. Per-project: `<project>/.mega-sdd/config.yaml` `model_tiers:`
3. User-scope: `~/.mega-sdd/memory/preferences.md` `## Model tiers`
4. Catalog default: `plugins/mega-sdd/references/model-tiers.md §Catalog`

**Tier selection rubric** (guides "find the best" decisions when adding new roles):
- **haiku**: bounded scope, narrow decision space, speed/cost dominates
- **sonnet**: pattern recognition, fuzzy classification (default)
- **opus**: open-ended reasoning, holistic synthesis, deep code review

**Trigger test coverage (+3 cases):**
- OF-MT1: catalog defaults applied when no overrides
- OF-MT2: CLI flag wins precedence chain
- OF-MT3: unknown role → soft halt + chain proceeds

**Standing user directive applied:**
> "perlu yg complpex pake opus, klo yg ringaan web and research.. and find the best"

Catalog rationale + rubric explicit per entry. Users override anywhere in chain. opus reserved for genuinely complex reasoning (synthesis, deep review); haiku for genuinely bounded tasks (probe scoring, research fetches).

**Backward compatibility:**
- Absent overrides → catalog default (no behavior change for previously-hardcoded sonnet dispatches)
- Absent catalog citation in a skill → inherits caller model (current behavior)
- Existing pipelines unaffected unless user explicitly overrides

**Reuse-first patterns:**
- NO new propagation mechanism — handoff metadata.model_tiers flows through Iter 33's existing handoff-contract.md schema validation gate (already validates handoff fields per type)
- model_tier_unknown halt uses canonical halt-protocol envelope from vault-contract.md (source_skill + type + details + next_action)
- File-format conventions match existing memory-schema.md preferences.md format (markdown list, kebab-case keys)

**Plugin:** v3.24.0 → v3.25.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-34-dynamic-model-selection.md`
```

- [ ] **Step 4.4: Add README "What's new in v3.25.0" to plugins/mega-sdd/README.md**

Edit `plugins/mega-sdd/README.md`. Add at top of existing "What's new" section:

```markdown
### v3.25.0 (Iter 34) — Dynamic Model Selection

mega-sdd now picks the **best model per subagent dispatch** instead of inheriting the caller's model. Curated catalog maps 17 named subagent roles to tier (haiku / sonnet / opus) with explicit rationale per entry.

**What changed:**
- **Catalog at `plugins/mega-sdd/references/model-tiers.md`** — 17 roles + tier + rationale + selection rubric
- **orchestrate-flow Step 2.8** — resolves override chain (CLI flag > project config > user preference > catalog default); emits `metadata.model_tiers:` in handoff
- **3 opus + 11 sonnet + 3 haiku** distribution by design (sonnet-dominant)

**Why this matters:**
Before: every subagent dispatch silently inherited the main thread's model. Opus for everything (expensive) OR inconsistent (depending on caller). No way to express "this synthesis needs opus" vs "this probe scoring is fine on haiku".

After: catalog explicit. extract-intelligence wave-5 (holistic synthesis) → opus. intelligence-audit-probe (0-3 scoring) → haiku. Most fuzzy-classification work → sonnet. User can override any role at any level (CLI / project / user).

**Override examples:**
```bash
# CLI: cheap reviews this run
/mega-sdd:auto --model-tier=code-quality-reviewer:sonnet ./prd.md

# Project: team prefers cheaper synthesis
# <project>/.mega-sdd/config.yaml:
model_tiers:
  extract-intelligence-wave-5: sonnet
```

**Plugin v3.24.0 → v3.25.0.**

See [docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md](../../docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md) for full design.
```

- [ ] **Step 4.5: Bump repo root README version**

Edit `README.md` (repo root). Update 3 stale references:
- Line 9: `**Version:** 3.24.0` → `**Version:** 3.25.0`
- Folder layout tree comment: `# the plugin itself (v3.24.0)` → `# the plugin itself (v3.25.0)`
- Versioning section: `Currently 3.24.0.` → `Currently 3.25.0.`

- [ ] **Step 4.6: Final verification**

```bash
echo "=== plugin.json ==="
grep '"version"' plugins/mega-sdd/.claude-plugin/plugin.json
echo "=== orchestrate-flow Step 2.8 + version ==="
grep "Step 2.8\|^version:" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -3
echo "=== Catalog file ==="
test -f plugins/mega-sdd/references/model-tiers.md && echo "EXISTS ($(wc -l < plugins/mega-sdd/references/model-tiers.md) lines)" || echo "MISSING"
echo "=== model_tier_unknown halt 3 surfaces ==="
grep -c "model_tier_unknown" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md plugins/mega-sdd/skills/orchestrate-flow/SKILL.md plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
echo "=== OF-MT trigger tests ==="
grep "^### OF-MT" tests/skill-triggering/orchestrate-flow.test.md
echo "=== CHANGELOG top entry ==="
head -3 CHANGELOG.md
echo "=== Repo root README version (expect 3.25.0 not 3.24.0) ==="
grep "Version:\*\*\|Currently \|(v3.2" README.md | head -5
```

Expected: plugin 3.25.0; Step 2.8 + orchestrate-flow 3.1.0; catalog file present ≥150 lines; halt 3 matches; 3 OF-MT cases; CHANGELOG has [3.25.0]; README at 3.25.0 in 3 spots.

- [ ] **Step 4.7: Commit + push**

```bash
git add tests/skill-triggering/orchestrate-flow.test.md \
        plugins/mega-sdd/.claude-plugin/plugin.json \
        CHANGELOG.md \
        plugins/mega-sdd/README.md \
        README.md
git commit -m "$(cat <<'EOF'
release(iter-34): mega-sdd v3.25.0 — dynamic model selection

Feature iter (~8hr): curated model-tiers catalog + override chain so
every named subagent dispatch uses the right model tier (haiku/sonnet/opus).

orchestrate-flow v3.0.0 → v3.1.0 (Step 2.8 override resolution).
Plugin v3.24.0 → v3.25.0.

17 roles catalogued: 3 opus + 11 sonnet + 3 haiku (sonnet-dominant).
1 new soft halt: model_tier_unknown (forward-compat for future roles).
3 trigger tests (OF-MT1/2/3) covering catalog defaults + CLI override
precedence + unknown role tolerance.

User directive applied:
"perlu yg complpex pake opus, klo yg ringaan web and research"
- Catalog rationale + rubric explicit per entry
- Override anywhere in chain (CLI > project > user > catalog)
EOF
)"
git push origin main
```

- [ ] **Step 4.8: Verify push + final state**

```bash
git log --oneline -7
```

Expected: 5 Iter 34 commits at top (Task 1 catalog + Task 2 orchestrate-flow + Task 3 dispatch citations + Task 4 release), pushed to origin/main.

---

## Self-Review

### Spec coverage

All §sections in spec → tasks in plan:
- §1 Architecture → Task 1 (catalog) + Task 2 (orchestrate-flow + handoff schema)
- §2 Catalog → Task 1
- §3 orchestrate-flow Step 2.8 → Task 2
- §4 Halt + testing → Task 2 (halt sync) + Task 4 (tests)
- §5 Risks → covered by spec acceptance criteria 1-10
- Acceptance criteria 1-10 → distributed across Tasks 2-4

### Placeholder scan

No TBD/TODO/vague placeholders. Every step has concrete content.

### Type consistency

- Role names consistent (kebab-case): auth-extractor, rbac-extractor, etc.
- Tier names consistent (lowercase): haiku, sonnet, opus
- Halt type name consistent: model_tier_unknown
- Step number consistent: Step 2.8 (NOT Step 0.7 / Step 2.5 / others)
- Skill versions consistent across tasks: orchestrate-flow 3.1.0, scan-codebase 2.6.1, extract-intelligence 1.5.0, memory 1.3.1

---

**End of plan.**

Total tasks: 4
Estimated execution time: ~8 hours
- Task 1: ~2hr (catalog write)
- Task 2: ~2hr (Step 2.8 + halt sync + handoff schema)
- Task 3: ~2hr (4 dispatch sites + memory schema)
- Task 4: ~2hr (tests + plugin.json + CHANGELOG + READMEs + push)
