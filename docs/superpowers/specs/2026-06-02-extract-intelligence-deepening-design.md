# Extract-Intelligence Deepening — Design Spec

- **Date:** 2026-06-02
- **Iter:** 80 (semantic-depth follow-on)
- **Status:** ACTIVE
- **Plugin version target:** 3.72.0 (MINOR — skill-body deepening + new optional schema fields + new advisory validator; no breaking renames, no halt-enum removal, no new skill dir)
- **Skill version targets:** `extract-intelligence` 1.7.0 → 1.8.0

## North star (user intent)

> "intinya gue pengen extract lebih pinter, bisa nangkep banyak case. penalaran nya lebih kuat dan in depth detail otomatis"
> — User, 2026-06-02

Make `extract-intelligence` **reason more deeply and catch more cases — automatically**, every run, without the operator having to prompt for it. The emphasis on *otomatis* (automatically) is load-bearing: the deepened reasoning MUST fire inside the Wave 1–5 subagent dispatch, not sit as advice in a SKILL.md body that the extraction subagents never read.

## Provenance

This spec adapts a bridging prompt distilled from a deep audit run against a real legacy PHP trade-finance codebase (`new-tradefinance-import`):

- Source audit: `new-tradefinance-import/.mega-sdd/audit/2026-06-02-extract-quality-audit.md` (22 findings: 3 HIGH, 11 MEDIUM, 8 LOW)
- Source improvement spec: `new-tradefinance-import/docs/superpowers/specs/2026-06-02-mega-sdd-extract-improvement.md`

The bridging prompt proposed 4 verbatim skill-body patches. On contact with the **current** plugin (v3.71.0) two facts changed the plan:

1. **Fork A doctrine (plugin `CLAUDE.md`):** prose that tells the model "HALT if X" enforces nothing — *"the failure mode was 'prose tells the model to invoke a script; model may or may not.' The fix is moving the trigger out of prose: hooks fire deterministically; validators run deterministically."* The bridging prompt's enforcement gates (B1–B3, E1–E3) were prose-only and would be no-ops.
2. **The bridging prompt's "CRITICAL" item (§7.2 multi-stage progressive disclosure) is already shipped** as the v3.71.0 semantic-depth staged-input mechanism (`## 3a. stages:` schema + `validate-vault-flow-staging.sh` Branch 14 + `validate-kb-flows.sh` advisory + `/mega-sdd:enrich-semantics`). A parallel `progressive_disclosure_audit.json` would be reinvention.

User decisions (2026-06-02, via AskUserQuestion):
- **Approach:** make extract smarter / catch more cases / deeper reasoning, automatically (a reframe — the goal, not a paste-path).
- **Gates:** "Validator + prose stub now" — real `validate-*.sh`, not no-op prose.
- **§7.2:** "Enrich existing §3a schema" — extend the shipped `stages:` block (per-field mutability/visibility + explicit delta fields), NOT a parallel artifact.

## Priority reframe (supersedes the source audit's HIGH-finding emphasis)

> "Status berbeda tidak masalah — itu penyesuaian yang lebih rapih. Grounded-nya from LC ke KB sudah ke-capture, improvement bisa dilakukan tanpa merubah kerangka seharusnya." — User

**Principle: KB captures business intent + flow; rebuild owns implementation cleanliness.** Status-naming drift between legacy and rebuild (legacy `flag_amend='4'` → rebuild `workflow_state='Forward3'`) is NOT a gap to chase. What the disciplines must surface is the *business outcome* and *flow distinction*, framed so the rebuild is free to normalize the encoding.

## The 5 extraction principles (stack-agnostic)

Collapsed from the audit's 7 PHP-specific patterns. P1–P4 are reasoning *disciplines* (legitimately skill+dispatch prose — they tell the agent how to look). P5/P5-extension map onto the already-shipped staged-input mechanism + the §3a enrichment.

| # | Principle | Audit failure mode it fixes |
|---|---|---|
| **P1** | Trace full state + data provenance — for every state *writer*, find the *reader*; for every clone-style copy (`INSERT…SELECT`, snapshot, deep-copy), trace inherited (bareword / non-overwritten) fields. | Extractor read writers thoroughly, never cross-checked readers → invented a state transition the read-side never honors; clone-inherited cross-domain coupling stayed invisible. |
| **P2** | Enumerate ALL sites of a rule or flow — same rule in N places → document EVERY site + diff them; scan controller/form tops for entry-point dispatchers (each branch = a distinct flow entry with its own initial state). | Stopped at first occurrence; drifted duplicate definitions and multi-entry-point divergence (teller-retail vs back-office-corporate) merged silently. |
| **P3** | Extract behaviour-as-EXECUTED, not as-INTENDED — unconditional `die()`/`exit()` halts, conditional-rollback policy, hardcoded test flags, silent-success catches. | Debug-code-as-feature (a `var_dump+die` guard that always triggers) was treated as artefact; intentional ROLLBACK-skip undocumented. |
| **P4** | Classify files by structure, not naming — template/output ratio, form-tag presence, early-return action gates determine role (view / action_handler / dual_purpose / dispatcher / service). | Dual-purpose file named action-only; role mis-read from filename prefix. |
| **P5** | FE rendering completeness — every field, conditional render, JS handler, AJAX endpoint, hidden state-pass field. | Under-sampled FE. **Already covered** by §3a staged-input per-stage `input_fields` + signals. |
| **P5-ext** | Multi-stage progressive disclosure — per-stage field set + *delta semantics* (new-vs-prior, hidden-vs-prior, promoted-to-mutable) + per-field mutability/visibility + within-stage dynamic disclosure. | **Partially shipped** (§3a captures staging + per-stage `input_fields`; new-fields-vs-prior is derivable). The delta/mutability/dynamic-disclosure dimensions are the §3a enrichment in this spec. |

§7.1 framing applied to the HIGH findings: A-G01/A-G02/A-G11 are reframed from "make rebuild match legacy status codes" to "capture the business outcome + flow distinction; rebuild owns the encoding." P1's writer/reader + clone-inheritance discipline still surfaces the *coupling* (e.g. "amendment must trigger MT707 dispatch + facility re-balance") — as a business requirement, not an implementation accident.

## Design — where each piece lands (Fork A discipline)

Mirrors the v3.71.0 staged-input wiring: **dispatch-prompt (fires automatically) + SKILL.md (design vocabulary) + between-wave gate (catches drift) + schema (structures the output) + validator (real script, not prose).**

### Track 1 — P1–P4 deep disciplines wired to fire automatically (THE CORE)

- `references/wave-dispatch-templates.md` — extend the **generic agent prompt skeleton's `EXTRACTION DEPTH` block** (the block every wave subagent receives) with P1–P4 probes. This is the "otomatis" mechanism: each subagent runs the deeper reasoning by construction. Frame P1 with the §7.1 business-intent lens (capture coupling as a business outcome; do NOT flag status-naming drift).
- Add per-wave **gate greps** mirroring the staged-input advisory pattern: a workflow/state file that documents a state *writer* with no corresponding *reader* (or vice versa) and no `[OPEN]` annotation → advisory, non-blocking, re-dispatch hint.
- `SKILL.md` — new `## Deep extraction disciplines (P1–P4)` section as design vocabulary, cross-referencing the dispatch template (the authoritative copy) + the §7.1 framing. Update `## Quality gates between waves` to name the new advisory.

### Track 2 — §3a schema enrichment (reuse-compliant, user's choice)

- `references/knowledge-base-schema.md §3a` — extend the EXISTING `stages:` block (do NOT add a parallel artifact) with OPTIONAL fields:
  - per-field shape inside `input_fields` (string → object with `name` + optional `mutability` ∈ {required, optional, display-only, dual-key-re-entry} + `visibility` ∈ {shown, hidden, conditional} + `conditional` trigger expr) — back-compat: bare-string entries still valid.
  - explicit deltas per stage: `new_fields_vs_prior`, `hidden_fields_vs_prior`, `promoted_to_mutable_vs_prior` (all optional lists; new-fields is derivable but recording it makes the delta auditable).
  - `dynamic_disclosures`: within-stage show/hide (`trigger` + `fields_shown`).
- `SKILL.md` staged-input section + the dispatch staged-input prompt — mention the enriched fields (best-effort capture).
- Enforcement stance: these dimensions stay **best-effort / advisory** (consistent with CLAUDE.md semantic-depth invariant #7 — the conditional/role-matrix/transition dims are Fork-B-future for hard enforcement). Optional fields break no consumer (invariant #7).

### Track 3 — Extraction Completeness Contract + scorecard (real validator, reuse-first)

- `SKILL.md` — `## Extraction Completeness Contract` describing the 5-principle scorecard, emitted by Wave 5 synthesis (deterministic main-thread step, alongside the existing snapshot emission) as `.mega-sdd/knowledge-base/.extraction-scorecard.json` + `EXTRACTION-SCORECARD.md`.
- new `scripts/validate-extraction-scorecard.sh` — a **real, runnable** validator (bash+Python, same shape as `validate-kb-flows.sh`): given a KB dir, checks scorecard presence + that each PARTIAL/MISSING principle has corresponding `[OPEN]` markers; writes `.extraction-scorecard-state.json`; exit 0/1/2. Wired as a **final-gate / advisory** check — NOT a new PreToolUse hook branch (avoids blast radius against Iter-78.1 / Iter-79 / semantic-depth #6/#7 invariants; keystone B1 does not need a blocking branch to be real).
- `bind-codebase/SKILL.md` — scorecard-preflight as documented advisory consult (reads the scorecard; surfaces FAIL/absent; does not hard-block in this iter).
- B2/B3 (handshake) and E1/E2/E3 (post-flight) — land as **clearly-marked Fork-B-future advisory stubs** with the validator follow-up explicitly scoped. No prose pretending to enforce.

### Track 4 — Proof

- `tests/fixtures/iter80-extract-deepening/` — assertions: (a) the dispatch EXTRACTION DEPTH block contains the P1–P4 probe markers; (b) `validate-extraction-scorecard.sh` PASSes a complete fixture scorecard and FAILs a gappy one (PARTIAL principle without `[OPEN]`); (c) §3a enriched fields parse as optional (a bare-string `input_fields` KB still validates). Fork-B (LLM actually performing the deeper reasoning) is documented as NOT script-asserted.

## Explicitly DEFERRED (not re-endorsed by the user; out of scope this iter)

- **generate-units Hard-Rule anchor-verification** (bridging §3.3) and **execute-bolts post-flight provenance scan** (bridging §3.4). The user's reframe narrowed scope to making *extract* smarter. These downstream pipeline gates are a clean, separable follow-up; building them now under "they said continue" would over-reach. Tracked as follow-up.
- **Hard-blocking scorecard preflight** in bind-codebase (a new PreToolUse branch). Deferred pending the advisory version proving out, to protect the hard hook invariants.

## Commit plan (atomic, individually revertible — per CLAUDE.md slice discipline)

1. This spec doc.
2. Track 1 — P1–P4 dispatch-prompt wiring + SKILL.md disciplines + between-wave advisory gate; bump extract-intelligence 1.7.0→1.8.0.
3. Track 2 — §3a schema enrichment + SKILL.md/dispatch staged-input mention; skill bump if not already in commit 2's range.
4. Track 3 — scorecard contract prose + `validate-extraction-scorecard.sh` + bind-codebase preflight advisory + Fork-B stubs.
5. Track 4 + release — fixture; plugin.json 3.71.0→3.72.0; CHANGELOG; README + fork-a-recovery-map note.

## Non-regression invariants (do NOT break)

- Iter-78.1 #1: advisory signals never flip a gate's blocking `status`.
- Iter-79 #5: new advisory signals are telemetry/WARN only.
- Semantic-depth #6/#7: dedicated single-purpose validators; `stages:` (and new sub-fields) stay OPTIONAL → no consumer breaks.
- No `--no-verify`; one commit per track; no rewording of existing rails for style.
