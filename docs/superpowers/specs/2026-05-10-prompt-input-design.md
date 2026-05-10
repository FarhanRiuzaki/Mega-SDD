# Prompt-Input + Default-On Chain — v0.15 Design

**Date**: 2026-05-10
**Plugin version target**: v0.15.0
**New skill**: `from-prompt` (brief → seed-PRD elaboration)
**Modified skill**: `flow` (Rule 0 + default-on chain across all rules)
**Goal**: Eliminate the ChatGPT-to-Claude prompt-engineering round-trip. Let users start from a free-text brief, run an in-Claude-Code Q&A elaboration, produce a seed-PRD that the existing pipeline consumes — while preserving every anti-halu rail in the corridor.

---

## Why this design

Today the plugin requires a PRD/BRD doc as input. Users without a doc currently:
1. Type their idea into ChatGPT.
2. Ask ChatGPT to write a structured prompt for Claude.
3. Paste the structured prompt back into Claude Code.
4. Run grand-design-spec.

That's a round-trip. v0.15 collapses steps 1–3 into a single in-Claude-Code interaction:

```
User types brief
  ↓
from-prompt runs adaptive Q&A (≤10 questions)
  ↓
seed-PRD.md written to disk
  ↓
grand-design-spec consumes seed-PRD as a normal source
  ↓
resolve-oq walks the P1 OQs (default-on chain)
  ↓
Vault ready
```

**Constraints (non-negotiable):**

- **Anti-halu rails preserved.** Sparse input → OQ-rich vault. Claude never auto-fills user answers. Brief and Q&A captured verbatim.
- **seed-PRD becomes the source-of-truth artifact.** Vault claims cite `seed-PRD §X`, which in turn cites `(brief)` or `(Q&A §N)` — chain of provenance unbroken.
- **`flow` chains everything applicable by default.** Reduces "did I forget the next step?" friction. User edits the plan to skip steps they don't want.

---

## Section 1 — Skill identity

- **Slash command**: `/grand-design-spec:from-prompt`
- **Skill file**: `plugins/grand-design-spec/skills/from-prompt/SKILL.md`
- **Frontmatter description**:

  > *"Converts a free-text brief into a seed-PRD.md ready for vault generation. Runs adaptive Q&A (capped at 10 questions) to fill gaps the brief leaves open. Writes a structured seed-PRD with citations to brief and Q&A. Output is a normal source artifact for grand-design-spec. Triggers — 'spec out this idea', 'from this prompt', 'buat dari ide', 'I have a brief not a PRD', or paraphrases."*

- **Arguments**: `[optional: brief text]`
  - No args → skill prompts: *"Tell me about your idea — a few sentences or a paragraph."*
  - Args = brief text → captured directly from `$ARGUMENTS`
- **Companion command file**: `plugins/grand-design-spec/commands/from-prompt.md`
- **Output location**: `<output-dir>/source/seed-PRD.md`. Output-dir defaults to `./<slug>-spec/` (slug derived from brief content).
- **Skill version**: NEW at **0.1.0**.

---

## Section 2 — Q&A structure

### Three rules

1. **Adaptive, not fixed.** Skill reads brief first, only asks about gaps.
2. **Hard cap: 10 questions** across all rounds. Beyond that, remaining gaps become `(unspecified)` markers.
3. **One question per turn.** `AskUserQuestion`, multi-choice preferred.

### Question taxonomy (asked only if not covered in brief)

| # | Topic | Why critical | Default question |
|---|-------|--------------|------------------|
| 1 | Project shape | Drives 02-arch + 04-flows structure | "What kind of system?" → multi-choice (mobile-app / web-app / api-only / multi-platform / data-pipeline / custom) |
| 2 | Primary users / personas | 01-overview personas | "Who's the primary user?" → free-text |
| 3 | Core problem | 01-overview Problem | "What problem does this solve?" → free-text |
| 4 | 2–3 most important user flows | 04-flows skeleton | "Top 2–3 things a user does?" → free-text |
| 5 | Implementation mode | Mode flag + drift-detect applicability | "Greenfield or extending existing codebase?" → multi-choice |
| 6 | Tech stack constraints | 02-arch tech stack | "Any tech stack constraints?" → free-text or "no constraints" |
| 7 | Regulatory / compliance | 06-constraints | "Any regulatory requirements? (GDPR / HIPAA / OJK / none)" → multi-choice |
| 8 | Success metrics | 01-overview success criteria | "How will you know it's working?" → free-text or "TBD" |
| 9 | Out of scope | Every doc OOS | "What's NOT in scope for v1?" → free-text or "nothing decided" |
| 10 | Anything else | Catch-all | "Anything else critical?" → free-text or "no, proceed" |

### Skip rules

For each question, decide BEFORE asking:
- Brief explicitly states/implies answer with reasonable specificity → skip.
- Brief silent → ask.
- Brief partially covers → ask refinement question.

Announce skip decisions: *"Reading your brief — I see you covered shape, users, problem. I'll ask about the gaps."*

### Stop conditions

- All 10 topics covered (asked or skipped via brief), OR
- User says "enough", "skip the rest", "proceed", OR
- 10 questions hit (hard cap).

Remaining unanswered topics → `(unspecified)` markers in seed-PRD → vault OQs.

### Hard rules

- ❌ No auto-fill of user answers. Silence stays silence.
- ❌ No leading or solution-shaped questions ("Should we use Redis?").
- ❌ No code/schema generation during Q&A.
- ❌ No paraphrasing brief or Q&A answers — verbatim capture only.
- ❌ No pushing past 10 questions.

---

## Section 3 — `seed-PRD.md` format

### File structure

```markdown
# Seed PRD — <project name slug>

> **Generated by**: `/grand-design-spec:from-prompt` v0.1.0
> **Date**: YYYY-MM-DD
> **Source**: user brief + interactive Q&A (10 questions max, capped)
> **Status**: DRAFT — not stakeholder-signed. Triggers PRD_STATUS=draft downstream.

---

## §brief — User brief (verbatim)

> "<exact text user typed, no paraphrasing>"

---

## §qa — Q&A elaboration session

| # | Topic | Question asked? | User answer |
|---|-------|-----------------|-------------|
| 1 | Project shape | Skipped — brief says "web app" | `web-app` |
| 2 | Primary users | Asked | "<verbatim answer>" |
| ... | ... | ... | ... |

---

## A. Product
<2–3 sentences> *(brief; Q&A §N)*

## B. Target users
- **<Persona>** — <1-line> *(Q&A §N)*

## C. Problem & motivation
<text> *(brief; Q&A §N)*
> *(Why-now / market timing — `(unspecified)`)*

## D. Goals / success criteria
- <KPI> *(Q&A §N)*

## E. In-scope features (v1)
1. **<Flow>** — <description> *(Q&A §N)*

> *(Detailed steps, edge cases, DoD — `(unspecified)`. Become OQs in vault.)*

## F. Out of scope (v1)
- <non-goal> *(Q&A §N)*

## G. Constraints
### Technical
- <constraint> *(brief / Q&A §N)*
### Regulatory & compliance
- <requirement> *(Q&A §N)*
### Business
> *(Timeline / budget — `(unspecified)`)*

## H. Implementation mode
**`new` | `existing`** *(Q&A §N)*

## I. Mentioned but not specified (downstream OQs)
- <topic> — <what's still unclear> *(Q&A §N noted but not resolved)*
```

### Citation conventions

| Citation | Means |
|----------|-------|
| `(brief)` | Directly from user's typed brief |
| `(brief §N)` | Specific clause if multi-paragraph |
| `(Q&A §N)` | Answer to question N |
| `(brief; Q&A §N)` | Combined source |
| `(brief; Q&A §N inferred from "...")` | Light inference, transparently flagged |
| `(unspecified)` | Gap → becomes OQ in vault |

**Anti-halu rule**: Claude NEVER writes a claim without one of these markers.

### Vault Sources reflection

Eventual vault `00-index.md` Sources section:

```
## Source documents
- **Seed PRD**: `source/seed-PRD.md` (generated by `from-prompt` v0.1.0 on YYYY-MM-DD)
  - Original brief: <verbatim>
  - Q&A: N questions asked, M skipped (already covered in brief)
- **Original user brief**: captured verbatim in §brief of seed-PRD
```

---

## Section 4 — Flow integration (default-on chaining across ALL rules)

`flow` v0.2.0 makes downstream chains default-on across the decision matrix. User skips individual steps via "Edit plan: skip step N" but doesn't have to opt in.

### Updated decision matrix

```
RULE 0 (NEW) — no vault AND no PRD AND prompt given:
    → chain: from-prompt → grand-design-spec → resolve-oq (scope=p1-only)
    → drift-detect not applicable (mode=new, no codebase yet)

RULE 1 (was opt-in, now default-on) — no vault AND PRD detected:
    → chain: grand-design-spec → resolve-oq (scope=p1-only)
    → drift-detect chained IF user selected mode=existing during gds

RULE 2 (was conditional, now default-on) — vault + new PRD detected:
    → chain: vault-diff → resolve-oq (scope=p1-only, only if new P1s introduced)
    → drift-detect chained IF mode=existing AND codebase available in CWD

RULE 3 (unchanged) — vault + vault.json missing:
    → chain: grand-design-spec re-run (regenerates manifest only, no further chain)

RULE 4 (was solo, now default-on) — vault + P1 > 0 + no new PRD:
    → chain: resolve-oq (scope=p1-only)
    → drift-detect chained IF mode=existing AND codebase available

RULE 5 (was conditional, now default-on) — vault + mode=existing + codebase:
    → chain: drift-detect → resolve-oq (scope=p1-only, only if vault-side actions queued)

RULE 6 (was conditional, now default-on) — mode=new + trigger fired:
    → chain: vault-diff (with mode flip) → resolve-oq (only if new P1s)

RULE 7 (unchanged) — nothing matched → STOP
```

**Hard cap**: stays at 3 skills per chain (verified across all 7 rules).

### Arg-parsing extension (Step 0 in flow)

v0.14 detection (paths only) extends:

- No args, no vault, no PRD in CWD → STOP per Rule 7.
- Arg = directory path → vault path. (unchanged)
- Arg = file path (`.pdf`/`.docx`/`.md`) → PRD path. (unchanged)
- Arg is free text (>20 chars, no path-like characters) → treat as prompt → `EXPLICIT_PROMPT=<arg>`.

### `from-prompt --auto` semantics inside flow

- **Logistical prompts auto-defaulted**: output-dir slug from brief content, skipped questions auto-marked "covered in brief".
- **Substance prompts ALWAYS interactive**: every Q&A question is a substance prompt — `--auto` does NOT skip. Hard rule.
- **`blocker` artifact emitted only if**: brief is unparseable (e.g., "asdfgh"). Emits `blocker` (type=`oq_blocker`, tag=`OQ-FROMPROMPT-1`, context="Brief is too short or unparseable to elaborate").

### Behavioral delta from v0.14

- v0.14 Rules 1, 2, 4, 5, 6 left resolve-oq as opt-in/conditional. Users had to remember to chain it.
- v0.15 makes it default-on. User who *doesn't* want resolve-oq skips via "Edit plan: skip 2" (or 3).
- Friction shifts from "remember to opt in" to "edit out if not wanted."
- Plan-confirmation step still surfaces full chain before execution; Edit/Cancel always work.
- **Not breaking**: same anti-halu rails, same per-skill behavior; just the default chain composition changes.

### Plan output example (Rule 0 / prompt-input)

```
grand-design-spec:flow — proposed chain

Detected state:
  • Vault: not found
  • PRD source: not found
  • Prompt provided: "I want a leave-management web app for SMEs..." (157 chars)
  • Codebase: not detected

Plan (3 steps):
  [1] from-prompt "<your brief>"
        Why: prompt detected, no PRD or vault in CWD
        Output: ./<slug>-spec/source/seed-PRD.md

  [2] grand-design-spec ./<slug>-spec/source/seed-PRD.md
        Why: chains automatically after seed-PRD is written
        --auto mode: yes (consumes seed-PRD; PRD_STATUS=draft)

  [3] resolve-oq ./<slug>-spec/ (scope=p1-only)
        Why: seed-PRD has unspecified gaps that will become P1 OQs
        --auto mode: NO. Always interactive — captures stakeholder answers.

Proceed? [y / edit / cancel]
```

---

## Section 5 — Anti-halu rails (the corridor)

The hybrid mode is designed so adding prompt input doesn't widen the corridor; it narrows it where it counts.

### Five rails

**Rail 1 — Source-of-truth is the seed-PRD.md, not the prompt.**
User's brief is the *origin* but not the *citation target* for vault content. Vault claims cite `seed-PRD.md §<X>`, which cites `(brief)` or `(Q&A §N)`. Chain of provenance unbroken.

**Rail 2 — Claude NEVER answers Q&A questions on behalf of the user.**
Even in `--auto` mode, every Q&A question is a substance prompt — always interactive. Skipped topic → `(unspecified)` in seed-PRD, never Claude-invented.

**Rail 3 — `(unspecified)` markers are first-class.**
Every gap propagates: seed-PRD → grand-design-spec Step 2 (Extract) → tagged as gap → Step 3 routes to relevant doc's Open Questions section. Final vault Sources line cites the unspecified marker explicitly.

**Rail 4 — No "industry default" insertions during elaboration.**
User silent on tech stack ("your call") → `(Q&A §6)` records that → vault generates `OQ-AR-1 [P1]: Tech stack not specified`. Same for compliance, NFRs, success metrics. Silence stays silence.

**Rail 5 — Brief verbatim, Q&A transcript verbatim.**
seed-PRD's `§brief` and `§qa` capture user input *as typed*. No paraphrasing, no tightening up.

### What this means in practice

| Brief quality | seed-PRD shape | Resulting vault |
|---------------|----------------|-----------------|
| Detailed (200+ words) | Most sections populated, ~2–3 `(unspecified)` markers | ~5–10 P1/P2 OQs (normal) |
| Sparse (1–2 sentences) | Q&A fills 6–8 topics, ~2–4 `(unspecified)` | ~10–20 OQs (mostly P1) |
| Tiny ("a thing for tracking leave") | Q&A gets through 3–4 topics, 6–7 `(unspecified)` | ~25+ OQs — vault is OQ-driven |

The plugin makes brief-quality visible. Sparse input produces honest gaps, not invented content.

### What `from-prompt` explicitly refuses

- ❌ Auto-fill answers user didn't give.
- ❌ Suggest defaults during Q&A ("most apps use Postgres — should we put that?").
- ❌ Compress / paraphrase the user's brief in `§brief`.
- ❌ Skip questions the brief doesn't cover (only skip when brief explicitly addresses).
- ❌ Push past 10 questions to "fill in more".
- ❌ Pretend the seed-PRD is a stakeholder-signed PRD (Status: DRAFT flag explicit).

---

## Section 6 — Implementation footprint

### New files (2)

| File | Purpose |
|------|---------|
| `plugins/grand-design-spec/skills/from-prompt/SKILL.md` | Elaboration skill |
| `plugins/grand-design-spec/commands/from-prompt.md` | Slash command wrapper |

### Modified files (6)

| File | Change |
|------|--------|
| `skills/flow/SKILL.md` | Add Rule 0 + revise Rules 1, 2, 4, 5, 6 to default-on chaining; bump 0.1.0 → 0.2.0 |
| `.claude-plugin/marketplace.json` | Plugin 0.14.0 → 0.15.0 |
| `plugins/grand-design-spec/.claude-plugin/plugin.json` | Plugin 0.14.0 → 0.15.0 |
| `CHANGELOG.md` | v0.15.0 entry — note default-on chaining as a CHANGED item |
| `README.md` | Add `/grand-design-spec:from-prompt` row + repo structure + changelog footer |
| `plugins/grand-design-spec/README.md` | Add from-prompt row + lifecycle diagram update |

### Skill version moves

- `from-prompt`: NEW at **0.1.0**
- `flow`: 0.1.0 → **0.2.0** (Rule 0 + default-on chaining)
- All other skills: unchanged
- Plugin: 0.14.0 → **0.15.0**

### Estimated commit chain (~6 atomic commits)

1. Add `from-prompt/SKILL.md` (new at 0.1.0)
2. Add `commands/from-prompt.md`
3. Update `flow/SKILL.md` — Rule 0 + revise Rules 1/2/4/5/6 to default-on (0.1 → 0.2)
4. Update READMEs (root + plugin) — atomic commit covering both
5. Bump plugin to 0.15.0 + CHANGELOG entry
6. (Optional) Minor note in `vault-contract.md` about `source_documents[].type = "seed-PRD"` as a valid value

---

## Out of scope (deferred to v0.16+)

- **Vault evolution from a new prompt** (i.e., prompt → seed-PRD-v2 → vault-diff). Manual composition works (`from-prompt` then `vault-diff`); flow auto-chain is v0.16+ candidate.
- **Multi-turn brief refinement** — show interpretation back to user, edit, repeat. Out of scope for v0.15. Single-pass Q&A is the v0.15 contract.
- **Seed-PRD diffing across runs** — running from-prompt twice in the same dir would overwrite seed-PRD.md. v0.15 keeps it simple. Versioning (`source/seed-PRD-v2.md`) is v0.16+.
- **Voice-input briefs / transcript ingestion** — users with audio briefs need to transcribe first. Future scope.
- **Reorder-and-edit-args plan editing** in flow — still v0.16+.

---

## Open Questions

- **OQ-PROMPT-1** [P2]: Should `from-prompt` write the verbatim brief to `<output-dir>/source/brief.txt` separately, OR keep it embedded in `seed-PRD.md §brief`? Embedded keeps single-artifact simplicity. Lean embedded.
- **OQ-PROMPT-2** [P3]: For Rule 0 chain, should `resolve-oq` chain run with `scope=p1-only` (default) or `scope=p1-then-p2`? P1-only is faster; user can re-invoke for P2s. Lean p1-only — captures the urgent set, leaves room.
- **OQ-PROMPT-3** [P3]: For ambiguous prompt detection (e.g., 18-char input — borderline below the 20-char threshold), should `flow` ask user to confirm "treat as prompt?" or just refuse and fall back to Rule 7? Lean ask — surfaces ambiguity transparently.

---

## Sources

- Brainstorming session 2026-05-10 (post-v0.14): user picked Hybrid mode + Approach 1 (two-step composition) + Default-on chaining.
- v0.14 spec at `docs/superpowers/specs/2026-05-10-flow-orchestrator-design.md` — informs the flow integration baseline.
- Per-skill SKILL.md files (v0.14 state).
- v0.13/v0.14 contract `plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md`.
