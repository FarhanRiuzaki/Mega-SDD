# Intelligence E2E Audit — 03: Upstream Phases (extract-intelligence, generate-intent, scan-codebase, bind-codebase)

**Date:** 2026-06-02 · **Plugin version:** v3.69.2 · **Scope:** reasoning intelligence of the 4 upstream phases
**Fixture (ground truth):** `new-tradefinance-import/.mega-sdd/` — real tradefinance rebuild through Phase 2.

## Framing reminders applied throughout

- **Fork A reality**: only hooks + deterministic validators enforce. SKILL.md prose is best-effort (0-for-4 track record). Each gap states `enforceable: Y/N`.
- **detect vs block**: a validator wired to **PostToolUse** writes a state file but **never stops the pipeline** (advisory). Only **PreToolUse Iter-78 branches** that gate `mega-sdd:execute-bolts` are *blocking*. The KB/codebase-map/conflict validators below are **detect-only** unless noted.
- **Grounding discipline**: any proposed sharpening must not loosen anti-hallucination. Validators proposed are pattern/structure checks, not LLM judgment.

## Baseline — validators that already exist + wire status (verified against `hooks/post-tool-use` + `hooks/pre-tool-use`)

| Validator | Phase | Hook-wired? | Block or detect? | Checks |
|---|---|---|---|---|
| `validate-kb-output.sh` | extract-intelligence | PostToolUse (KB write) | detect | frontmatter present; marker COUNT match (fm `locked_count` == body `[LOCKED]` count); 11-section presence; `depends_on` valid |
| `validate-kb-markers.sh` | extract-intelligence | PostToolUse (KB write) | detect | every `[VERIFIED]` claim has same-line / §11 / backtick citation (per-claim attribution) |
| `validate-kb-citations.sh` | extract-intelligence | PostToolUse (KB write) | detect | §11 citations resolve to real files in legacy root |
| `validate-kb-flows.sh` | extract-intelligence | PostToolUse (KB write) | detect | §3 Flow / §8 State-Machine mermaid heuristic-valid |
| `validate-vault-oqs.sh` | generate-intent | PostToolUse (vault write) + **PreToolUse Branch 10** | detect **and block** (block on `operator_surface_missing`/`design_source_oq_missing` COUNT) | per-OQ schema (tech→mode, scan→target, recommend→fields); vault-wide operator-surface + Design-Source OQ rails |
| `validate-codebase-map.sh` | scan-codebase | PostToolUse (map write) | detect | 7-section presence + frontmatter keys + §2 has ≥1 row |
| `validate-vault-binding-coverage.sh` | bind-codebase | PostToolUse | detect | vault sections → binding ISM coverage; units→bolts traceability |
| `validate-conflict-classification.sh` | bind-codebase | **NOT wired to any hook** | (would be detect) | greps `binding_conflict:` YAML for `conflict_class`+`resolution_complexity` |
| `validate-starterkit-conformance.sh` | scan→units | PostToolUse + PreToolUse | block | unit target_files vs starterkit-context patterns |

---

## Phase 1 — extract-intelligence (legacy → KB)

**Reasoning verdict: REASONING** (upgrade from iter-33's "pure producer, scored 0").

### Evidence (fixture, ground-truth)
- Dual-axis mutability markers are present in volume and discriminating, not boilerplate:
  `[VERIFIED][LOCKED]` ×112, `[VERIFIED][INTENT]` ×37, `[VERIFIED][ARTIFACT]` ×235, plus `[INFERRED][LOCKED]` ×27, `[OPEN][?]`/`[OPEN][INTENT]` etc. The ARTIFACT-heavy distribution means the phase is actively deciding *what the rebuild may discard* — a reasoning act, not transcription.
- `99-rebuild-architecture/data-mutation-policy.md` is 153 lines with 46 tier assignments — a genuine per-entity LOCKED/INTENT/ARTIFACT policy that downstream `generate-intent --kb` consumes to know what it may redesign.
- `suggested-erd.md` has ~20 explicit departure/normalize/discard reasoning hits (documents departures from legacy, not a 1:1 mirror).
- SKILL.md Axis-2 mutability section + Wave-5 synthesis (suggested-erd departures, dependency-graph, phasing) are real reasoning prompts. The phase produces analysis, not a transcript.

So the "smarter" output signature (mutability reasoning + reengineering proposals) **exists in the artifact**. The problem is enforcement, not capability.

### Gaps

| observed gap | evidence | root-cause | proposed output-signature | enforceable | existing-machinery-check |
|---|---|---|---|---|---|
| Reengineering REASONING artifacts are unvalidated — only transcription discipline is checked | `validate-kb-output.sh` checks marker-count-match (fm vs body), 11-section presence, citations, depends_on. NOTHING checks `99-rebuild-architecture/data-mutation-policy.md` exists, is non-empty, or that its tier distribution matches the domain-file tier distribution. A KB could ship with rich `[VERIFIED]` transcription and a stub/absent mutation-policy and pass every wired validator. | The 4 wired KB validators are all *grounding/transcription* gates (citations, marker counts, mermaid). The phase's actual reasoning output (Wave-5 synthesis) has zero validator. | New `validate-kb-reengineering.sh` (PostToolUse on KB write): assert `99-rebuild-architecture/{data-mutation-policy,suggested-erd,suggested-phasing}.md` exist AND non-trivial (≥1 tier row per LOCKED-bearing domain; ≥1 departure note in suggested-erd). FAIL→detect state, advisory. | **Y** (structure + presence + count cross-check; no judgment) | None — kb-output/markers/citations/flows all stop at transcription. This is the **top enforceable finding** for the phase. |
| Mutability tier can be silently dropped (single-axis only) | fixture also has 695 bare `[VERIFIED]` / 91 `[OPEN]` / 47 `[INFERRED]` with NO mutability tier. SKILL.md says "both axes mandatory" but no validator counts dual-axis coverage. A whole wave could emit confidence-only markers and pass. | "Both axes mandatory" is prose; `validate-kb-markers.sh` only checks that `[VERIFIED]` is *cited*, not that it carries a `[LOCKED/INTENT/ARTIFACT]` companion. | Extend kb-markers (or new check): ratio of dual-axis to single-axis markers per domain file ≥ threshold, else WARN. | **Y** (regex count ratio) | `validate-kb-markers.sh` exists but checks citation only, not tier-companion presence. |
| `[INTENT]` default-when-uncertain is invisible | SKILL.md §"Default tier when uncertain → [INTENT]"; no signal distinguishes a reasoned INTENT from a lazy default-INTENT. | Default is a prose instruction with no observable output difference. | (none cheap) — would need a `tier_rationale` field; flag as design-add, not validator. | **N** (aspirational — would need new producer field + judgment) | n/a |

---

## Phase 2 — generate-intent (brief/KB → 7-file vault)

**Reasoning verdict: PARTIAL** (reasons about flows + operator surfaces; OQ-classification *reasoning* is largely unenforced).

### Evidence
- Step 2 (extract before writing) + Step 3 operator-surface capture (slice G) are real reasoning prompts; the slice-G operator-surface + Design-Source OQ rails ARE enforced (`validate-vault-oqs.sh`, PostToolUse + **PreToolUse Branch 10 blocking**). Fixture 04-flows passes this gate.
- OQ auto-classification (Step 3.5) uses a **deterministic text-pattern heuristic table** (`vault-contract.md §Auto-classifier heuristics`) — genuinely machine-checkable, NOT LLM judgment.
- Grounding: Step 4 self-check ("every claim cites source") is **prose-only** — no validator confirms vault claims trace to PRD/KB.

### Gaps

| observed gap | evidence | root-cause | proposed output-signature | enforceable | existing-machinery-check |
|---|---|---|---|---|---|
| OQ mis-classification (lazy default to business) is invisible | `validate-vault-oqs.sh` only fires `oq_tech_missing_mode` for OQs **already tagged `[tech]`**. An OQ whose text clearly matches a tech pattern ("what test framework", "naming convention", "file location") but is left untagged/defaulted to `business` is never flagged. The conservative default (business/blocking/low) is the documented fallback — so the classifier can be silently no-op'd and nothing catches it. | The validator trusts the existing tag; it does not independently re-apply the heuristic table to detect a tag that contradicts the text. | New check in vault-oqs: independently apply the `vault-contract §Auto-classifier heuristics` text-pattern table to EVERY OQ; if OQ text matches a `tech` pattern but is tagged `business`/untagged → `oq_misclassified_tech` (WARN/detect). Same table the producer is told to use → no judgment. | **Y** (the heuristic table is literal text-patterns; re-applying it is deterministic) | `validate-vault-oqs.sh` exists but only validates *already-tech* OQs' completeness — it does not police the tag decision. **Top enforceable finding** for the phase. |
| Vault claim grounding (anti-halu) is prose-only | Step 4 checklist "every claim cites source" + "no invented entities" has no validator. `00-index Sources` section presence is unchecked. | Grounding is the phase's core promise but lives entirely in the self-check prose (0-for-4 prose track record). | New `validate-vault-grounding.sh`: assert each doc 01–06 has a non-empty `## Sources` and `## Out of Scope` section; (cheap, structural). Deep claim-tracing stays out of scope (needs source corpus). | **Y** for section presence; **N** for true claim-tracing | None checks Sources/Out-of-Scope presence. |
| `00-index ## Auto-Classification Review` section presence unenforced | Step 3.5.6 + Step 4 mandate the section; no validator asserts it exists. | prose mandate. | Add section-presence check to vault-oqs (when ≥1 tech OQ exists). | **Y** (header grep) | not currently checked. |

---

## Phase 3 — scan-codebase (repo → codebase-map)

**Reasoning verdict: MECHANICAL-by-design at the surface map; PARTIAL once deep-scan runs** — and the depth that downstream binding *needs* is not a checked signature.

### Evidence
- Surface map is deliberately heuristic (entities/routes/models/conventions) — appropriate. Deep-scan (Step 10.5) adds real pack-driven pattern reasoning (`starterkit-context.yaml patterns:` block with `_source` citations), which IS partially enforced by `validate-starterkit-conformance.sh`.
- `validate-codebase-map.sh` checks **only** 7-section presence + frontmatter + §2 has ≥1 row. It is pure schema — **zero depth**.

### Gaps

| observed gap | evidence | root-cause | proposed output-signature | enforceable | existing-machinery-check |
|---|---|---|---|---|---|
| No depth signature — a map with bare symbol names passes, but bind-codebase field-diff needs signatures | `bind-codebase` SKILL.md §field-level-diff: "Field-level diff REQUIRES tree-sitter precision (`precision_tier: ast`)... on regex, fall back to binary classification." So binding's reasoning silently degrades when the map lacks signatures — yet `validate-codebase-map.sh` only checks §2 has ≥1 *row*, not that rows carry param/field signatures. | The map validator was written as schema-completeness, decoupled from what its only consumer (binding) actually requires. | Extend `validate-codebase-map.sh`: assert frontmatter declares `precision_tier`; if `ast`, sample §2 rows must carry a signature token (param list / field list), not bare names. WARN when `precision_tier: regex` (binding will degrade). Motivated by the real downstream consumer, not an arbitrary threshold. | **Y** (frontmatter field + regex on §2 rows for `(...)`/field columns) | `validate-codebase-map.sh` exists but checks row *count* only, never row *depth*. **Top enforceable finding** for the phase. |
| Deep-scan partial/failure provenance not surfaced to binding | scan emits `partial: true` + `partial_slices` to starterkit-context.yaml on subagent failure; binding doesn't gate on it. | partial state is informational; no consumer asserts completeness. | binding pre-flight: WARN when starterkit-context `partial: true` (the pack it relies on is incomplete). | **Y** (yaml field check) | partial flag exists; unconsumed. |

---

## Phase 4 — bind-codebase (vault vs map/KB → binding) — THE GROUNDING GATE

**Reasoning verdict: REASONING (richest of the four) — but its conflict-classification "gate" is structurally vacuous against real output.**

### Evidence
- The CONFLICT-vs-CONFIRM-vs-OQ logic is genuinely intelligent: codebase-map = primary truth; KB = secondary (only when map silent); dual-axis marker-aware verdicts (LOCKED→HIGH-severity conflict, ARTIFACT→discard-recommendation); field-level set-diff (ADD/KEEP/REMOVE) producing PARTIAL_FIELDS_* states; CONFLICT never overridden by KB. Fixture `binding.md` shows this working: 14 CONFIRMED, 26 TO_CREATE, KB-locked claims, a real CONFLICT-1 (Product name collision) with resolution options, and Phase-2 NON-BLOCKING conflicts.
- The hard-gate (no bound-vault while conflicts exist; CONFLICT never auto-resolved) is the correct contract and is honored in the fixture (BLOCKING until resolved).

### Gaps

| observed gap | evidence | root-cause | proposed output-signature | enforceable | existing-machinery-check |
|---|---|---|---|---|---|
| `validate-conflict-classification.sh` SKIPs on REAL output — vacuous gate | Ran the validator on the fixture: `{"status":"SKIP","conflicts_total":0,"summary":"no CONFLICT YAML blocks found"}`. But the fixture binding.md **has conflicts** — written as markdown headings `### CONFLICT-1 —` and `**CONFLICT (NON-BLOCKING)**` + a `## Conflicts (N)` table (exactly the `binding-contract.md` template shape). The validator greps for ` ```yaml ... binding_conflict: ``` ` blocks that the producer template never instructs bind-codebase to emit. Structure mismatch → 0 conflicts seen → always SKIP. | Validator and producer template diverged: validator expects YAML conflict blocks; SKILL.md §4 template emits a `## Conflicts` markdown table + prose headings. The validator is checking a structure that does not exist in practice. | Two-part fix: (1) bind-codebase MUST emit each conflict as a structured block (`id: CONFLICT-N`, `conflict_class:`, `resolution_complexity:`) — amend `binding-contract.md` template; (2) point the validator at the `## Conflicts` table / `### CONFLICT-` headings it actually produces (or enforce the new structured block). Also wire it into a hook (currently wired to none). | **N today / Y after fix** — the mechanism is deterministic, but it is *practically unenforced*: it SKIPs on real output AND is wired to no hook. Do NOT count "validator exists" as "enforced." | `validate-conflict-classification.sh` exists; NOT hook-wired; SKIPs on the fixture. **Top enforceable finding** for the phase (it is the only conflict-reasoning validator and it currently checks nothing real). |
| `conflict_class` / `resolution_complexity` enrichment never produced | fixture binding.md: 0 occurrences of `conflict_class`/`resolution_complexity`. SKILL.md §4 template (the only producer guide) does not mention these fields at all. | The enrichment fields the validator wants exist only in the validator's expectation, not in any producer contract. | Add `conflict_class` (naming-collision / signature-drift / semantic / regulatory) + `resolution_complexity` to the binding-contract conflict template so the producer emits them. | **Y** (once template emits them; then the validator's check becomes live) | enrichment is orphaned — validator wants it, producer never writes it. |
| KB-secondary marker-aware verdicts unvalidated | SKILL.md §2 dual-axis routing (kb_locked→HIGH severity etc.) is sophisticated prose; no validator confirms binding.md records `mutability_source` when KB was consulted. | reasoning lives in prose; output field (`mutability_source`) is optional + unchecked. | check: for CONFIRMED-via-KB claims, binding.md carries `mutability_source: kb_*`. | **Y** (field presence on KB-confirmed rows) | none. |

---

## Cross-phase pattern

Every upstream phase has the **same shape of gap**: the *reasoning* output (mutability tiers + reengineering proposals; OQ classification decisions; map depth; conflict classification) is real in the artifact or producible, but the wired validators only check **transcription/structure discipline** (citations, marker counts, section presence, row counts). The one validator that targets reasoning enrichment (conflict-classification) checks a structure the producer never emits and is wired to no hook — so it is vacuous in practice. The fixes are uniformly **enforceable: Y** because the discriminating signal is countable/pattern-based, EXCEPT where it requires LLM judgment (default-tier rationale, deep claim-tracing), which are flagged **N / design-add**.
