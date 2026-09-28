# plan — post-write validation passes (Step 12.x)

> Relocated from `skills/generate-units/references/validation-passes.md` in 9.0 (P1), with the §12.4.5 pack overlay sentence + pack→bolt translation table from `skills/bind-codebase/references/hard-rules-and-packs.md` §2.8 / §2.9a; tuned text kept verbatim.

## Contents
- 12.3 — Per-anchor verification
- 12.4 — Inject constitution clauses
- 12.4.5 — Framework pack provenance citation (+ the pack→bolt translation table)
- 12.5 — Polished-prompt render pass (a–e, g, h)
- 12.6 — Deduplication check
- 12.7 — Sibling-consistency sweep

Loaded by `plan/SKILL.md` Step 4 (the unit walk's Step 12). The 12.x sub-procedures run in declared order, then plan Step 5 runs the validators and logs the `units_generated` event (`derive-vault-json.sh --event`) so it reflects all post-write validation outcomes. The emitted YAML for every blocker named here is in the halt-protocol reference listed in the skill router.

## 12.3 — Per-anchor verification (runs FIRST as a precondition check before constitution inject + render)

For each Anchor entry in each unit's `## Anchors` section:

1. Parse `<file>:<line-range> — <description>` format
2. Probe file existence (filesystem)
3. Apply outcome:
   - **File MISSING + greenfield unit** → WARNING in unit body footer (HTML comment): "anchor aspirational for new file; verify before bolt"
   - **File MISSING + brownfield unit** → stronger WARNING: "anchor points to non-existent file; binding may be incomplete; review"
   - **File EXISTS, line out of bounds** → WARNING: "anchor line-range may have drifted; current file has N lines"
   - **File EXISTS, line valid** → ✓ verified

Anchor warnings are SOFT — they do NOT halt generation. Anchors can be aspirational (especially for new files in `create` units). Warnings surface visually in chat output + unit body footer so user can review.

## 12.4 — Inject constitution clauses

Per `plugins/mega-sdd/references/vault-core.md §constitution`.

For each unit, read `<vault>/constitution.md` + identify clauses relevant to the unit's:
- target_files paths (matches §A clauses for files in those paths)
- task_type (different clauses apply for create vs extend vs verify)
- module (per `_meta/modules.yaml` if multi-module)
- context_source (clauses referenced in that `context.md` section)

Inject relevant clauses into the unit's `## Hard rules` section:

```yaml
id: constitution-A-001
language: <unit's primary language>
message: "All API endpoints MUST use Sanctum auth middleware (constitution §A-001)"
rule:
  pattern: |
    Route::$$$('/api/$$$', $$$)
  not:
    inside:
      pattern: |
        ->middleware(['auth:sanctum', $$$])
```

Format:
- Rule `id` prefix `constitution-` + clause ID
- `message` cites clause source
- Pattern detection: convert clause text to ast-grep YAML when feasible; fall back to text-match grep when not
- Severity: `error` (constitution clauses are non-negotiable; halts bolt commit if violated)

**Anti-halu rails**:
- Constitution clauses NEVER silently apply — surface in unit body for user review
- Clauses that can't translate to ast-grep grammar are flagged in unit body as `## Constitution warnings` informational section (not Hard Rule)
- Anti-pattern (§D) clauses always inject as Anti-patterns (informational), not Hard Rules (machine-validated), unless mechanically detectable
- Constitution version + hash tracked: if constitution drifts between unit generation and bolt execution → halt `constitution_drift_detected`

## 12.4.5 — Framework pack provenance citation

**plan promotes no framework-pack rule into a unit's `## Hard rules`.** No pack slice is injected into the bolt: pack rules reach execution only through the unit content `plan` authors (a carried Hard rule, below) and the pack-driven gates, never as a B1 obligation of their own. The rest of this pass governs a unit that DOES carry pack-derived Hard rules (a unit from a migrated layout-2 vault, whose `binding.md` §Suggested Unit Hard Rules pulled them in): each pack-derived Hard Rule sits in the unit's `## Hard rules` section WITH explicit provenance citation. Tools consuming the unit must see WHICH framework pack rule applies (audit trail, debugging, override decisions).

**One grammar per unit.** A unit's `## Hard rules` carries EITHER v1 dash productions OR v2 fenced ast-grep YAML — never both (`hard_rule_mixed_grammar` halts at bolt time). Pack rules translate per the pack→bolt table below: when the unit's other rules are v1 (e.g. `DO NOT modify …`), emit the pack rule as its v1 production (or Anti-pattern) — do NOT drop a fenced YAML block into a v1 unit; when the pack carries a real ast-grep `rule:` body and the unit has no v1 rules, emit v2 fenced YAML (the shape below) for ALL of the unit's rules — v2 rules require `ast-grep` at bolt pre-flight (HALTs `dep_missing` if absent); run `/mega-sdd:install-deps --tools=ast-grep` ahead of execute-bolts if it isn't installed yet.

**Pack chain overlay** (the chain protocol a carried pack rule's citation follows). Read the pack file completely; extract its `## Hard Rules emitted` section into structured records; if the pack has `extends: <parent>` frontmatter, load the parent first then overlay (child rules override parent on `path_glob` conflict).

**Pack→bolt translation table (packs ship `rule_type` inventories, NOT ready-made ast-grep blocks; a pack rule reaches a unit's `## Hard rules` ONLY through one of these productions, so the bolt-stage scan can always execute what the unit carries):**

| Pack `rule_type` | Emitted into the unit as | Bolt-time check |
|---|---|---|
| `NAMING_RULE` (has `path_glob` + case style) | v1 `<path-glob> MUST follow <case-style> naming` | deterministic (filename regex) |
| `LOCATION_RULE` (files-belong-here) | v1 `<path-glob> MUST follow …` when expressible; else Anti-pattern | deterministic / advisory |
| `DEP_RULE` (no new deps / pinned manifest) | v1 `DO NOT add new <manifest> dependencies` | deterministic (manifest diff) |
| `LOCK_RULE` (do-not-touch file) | v1 `DO NOT modify <path>` | deterministic (commit-touch / sha) |
| `SIGNATURE_RULE` | v1 `function <name> MUST preserve signature: <sig>` | deterministic (decl compare) |
| rule carrying a real ast-grep `rule:` body | v2 fenced YAML block (verbatim) | deterministic (`ast-grep scan`) |
| `CUSTOM` / `SECURITY` / `PERFORMANCE` prose | `## Anti-patterns` (informational) by default; a generic `MUST/DO NOT` directive line ONLY when the obligation is genuinely load-bearing (honest tier — post-flight records it `directive_unverified` unless attested) | advisory / attested |

A pack rule that fits NO row is an Anti-pattern, never a Hard rule — emitting prose the scan cannot execute breaks the chain of custody (`unit-spec` counts it, the bolt scan can't check it, B1 then demands a verdict nothing can produce).

Format inside unit's `## Hard rules` section:

```yaml
- id: framework-pack-naming-001
  source: "framework-conventions/laravel-base-26.md §Hard Rules — UUID PK enforcement"
  framework: laravel-base-26
  framework_pack_version: 1.0  # framework_version_range when last_verified_against passed
  message: "Domain entity migrations MUST use UUID primary key per starterkit convention"
  severity: error
  rule:
    pattern: |
      $table->id()
    inside:
      pattern: |
        Schema::create($_, function (Blueprint $table) { $$$ })
```

Aggregate in unit body:

```markdown
## Framework pack source

Conventions enforced from: `plugins/mega-sdd/references/framework-conventions/laravel-base-26.md` (v1.0, extends `laravel.md` extends `_universal.md`)
Rules pulled into this unit's Hard Rules: N (see §Hard rules for line-level enforcement)
```

**Anti-halu rails**:
- Framework pack rules NEVER silently apply — citation mandatory so user can audit + override
- Rules whose `path_glob` doesn't match this unit's `target_files` are SKIPPED (not all pack rules apply to every unit)
- When pack `extends:` chain → cite the SPECIFIC pack file the rule lives in (not the chain head), so override edits are traceable

## 12.5 — Polished-prompt render pass

After all units written but BEFORE the dedup check, sweep each unit and validate the prompt-shape contract per the unit-schema reference (listed in the skill router):

a. **Anchors presence rule**:
   - `task_type: verify` OR `task_type: extend` → `## Anchors` section MUST have ≥1 entry. Missing → halt `unit_underspecified`.
   - `task_type: create` AND ≥1 `binding_refs` entry pointing to a related pattern → `## Anchors` MUST have ≥1 entry citing the closest pattern. Missing → halt `unit_underspecified`.
   - `task_type: create` AND fully greenfield (no binding) → Anchors section optional.

b. **Hard rules grammar parse**: each DASH line under `## Hard rules` MUST match one of the 5 strict v1 productions OR the generic-directive tier (`MUST/MUST NOT/DO NOT/NEVER/ALWAYS …` — accepted but counted `hard_rules_directive_prose`; not machine-checkable at bolt time, so post-flight records it `directive_unverified` unless attested). Fenced ```yaml blocks are v2 ast-grep rules (validated by parse-via-scan at bolt pre-flight). A line matching neither → halt `hard_rule_unparseable` with the offending line. Mixing v1 dash rules and v2 fenced blocks in ONE unit → the bolt-time `hard_rule_mixed_grammar` halt — emit one grammar per unit (12.4.5).

c. **Directive prose check on Implementation steps**:
   - Extract the body of `## Implementation steps`
   - If body is pure bullet list (no sentence >15 words detected) → emit WARNING (not halt) in chat: "Unit U-XXX Implementation steps is bullet-only. Consider directive prose for AI coding consumption."
   - For `task_type: verify`: the single-line "No code changes..." sentence is acceptable as-is (special case).

d. **Migration notes rule**:
   - `task_type: extend` → `## Migration notes` MUST exist AND have all three sub-lists (REMOVE / KEEP / ADD) populated (any can be `none` but must be present). Missing → halt `unit_underspecified`.
   - `task_type: create` OR `task_type: verify` → `## Migration notes` section MUST be absent.

e. **Anti-patterns harvesting (suggestion, not requirement)**:
   - If the KB (`plan --kb`) has gotchas in domains this unit covers → suggest filling `## Anti-patterns` section with the relevant items
   - Auto-populate from the Anti-pattern suggestions in `plan/references/kb-input.md` §KB-derived Hard rules + Anti-patterns and the KB module PRD `## 5. Edge Cases & Gotchas` sections (`<kb>/modules/*.prd.md`, PRD-kontrak; a legacy numbered-tree KB carries them as `## 9. Edge Cases & Gotchas`) when applicable
   - Anti-patterns are guidance only — no halt if absent

g. **OQ-ID propagation check**:

   Every Open Question that influenced this unit's content MUST appear in `binding_refs:` frontmatter. An OQ "influenced" the unit when its resolution (per `context.md` `## Open Questions`, mirrored in `vault.json` `open_questions`) corresponds to design choices reflected in the unit body, target_files, hard rules, or migration notes.

   ```
   FOR EACH unit being written:
     oq_table = parse context.md ## Open Questions (or vault.json open_questions)
     oq_ids_in_table = collect all OQ-* IDs from oq_table
     oq_ids_in_binding_refs = unit.frontmatter.binding_refs intersect (OQ-* prefix)

     # An OQ is "implementation-relevant" to this unit when:
     # - the OQ's resolution touches files in unit.target_files, OR
     # - the OQ's resolution text appears semantically in unit.body (anchors, hard rules, migration notes), OR
     # - the OQ's `priority: P1` (P1 OQs are always implementation-critical per vault-core)

     relevant_oqs = filter oq_ids_in_table by above criteria
     missing = relevant_oqs - oq_ids_in_binding_refs

     IF missing is non-empty:
       → HALT `unit_oq_trace_missing`  (blocker YAML in the halt-protocol reference)
   ```

   **Why this rail exists:** a field audit traced OQ-DM-P2-1 from vault → binding-phase-2.md (correctly carried) → units/U-005 + U-014 (resolution semantics carried as `lc_amount + goods_total` fields, but the OQ-ID itself was DROPPED). CONFLICTs already propagate via this same mechanism; this rail extends the discipline to OQs.

### h. PBT properties citation check (when `properties:` present)

Every entry in a unit's `properties:` array MUST carry a non-empty `cites:` field resolving to a vault section / binding claim / KB rule (per `plan/references/pbt-integration.md` §Anti-halu rails). A property with no citation is an INVENTED invariant — reject the unit write and re-derive or drop the property (no-fabrication rail). Model-executed check (no deterministic validator; the bolt-side B1 postflight cite-check is the backstop).

## 12.6 — Deduplication check

After all units written, sanity-check `task_type: create` units against the filesystem:

- For each `task_type: create` unit where EVERY `target_files` entry's path already exists — probe the FILESYSTEM — AND its operation is `create`:
  - This signals a likely mistake — the unit wants to create a file that already exists.
  - **Exception (7.6 reconciliation):** a collision the user ALREADY accepted at Step 7.6 (option 4 force-create, recorded in the unit body's collision note) does NOT re-halt here — 12.6 is the backstop for collisions that never got a 7.6 decision, not a second vote on one the user made.
  - Otherwise halt with structured `dedup_ambiguous` blocker (per DESIGN-OQ-2). NEVER silent-rewrite. (YAML in the halt-protocol reference listed in the skill router.)

## 12.7 — Sibling-consistency sweep (code-delivery slice B, defense-in-depth)

After units are written, reason about SIBLING units *together*, not one at a time. Group units by `module` + `scope`. For each cross-cutting concern the active framework pack declares (`## Cross-cutting concerns` — e.g. a tenant/branch-scoping key, soft-delete, audit-trail) whose `applies_when` matches a unit's model, EVERY sibling in the group the concern applies to MUST declare the SAME mechanism (the concern's `spec_obligation`) — one consistent mechanism per shared concern. A sibling that scopes "a different way" or omits it is **fan-out divergence** (the golden exemplar is correct, the siblings drift — the exact failure proven in the tradefinance Phase-2 run, where one model scoped "via lc_id" while its siblings used the shared trait).

Likewise, every FK column a unit declares (`<name>_id`) MUST declare its derived relation accessor (pack `## Relation derivation`; universal default: the camelCase singular of `<name>`).

This sweep is ENFORCED by `scripts/validate-sibling-consistency.sh` (writes `.sibling-consistency-state.json`; the PreToolUse gate recomputes it and Branch 7 blocks `execute-bolts` on FAIL) — this prose is defense-in-depth; the validator is the gate. Tech-agnostic + anti-hallucination: never invent a concern the active pack does not declare.
