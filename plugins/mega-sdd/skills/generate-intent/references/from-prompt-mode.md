# From-Prompt Mode Reference

This document specifies the `--from-prompt` mode of `generate-intent`. When the user invokes `generate-intent --from-prompt "<brief>"` (or the agent infers free-text intent), this mode runs adaptive Q&A (≤10 questions) to fill brief gaps before producing the vault.

This was previously a standalone skill `from-prompt`; it is now absorbed as a mode of `generate-intent`. See `generate-intent/SKILL.md` for invocation rules.

# From-Prompt — Brief to Seed-PRD elaboration

Converts a free-text user brief into a structured `seed-PRD.md` ready for `/mega-sdd:generate-intent` to consume. Runs an adaptive Q&A elaboration loop (≤10 questions) to fill gaps the brief leaves open. Captures everything verbatim — no paraphrasing, no auto-fills.

> **Skill instruction language**: this skill is written in English for reasoning quality. Chat prompts (Q&A questions, summary) default to **Indonesian + English technical terms**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 tokens stay English (→ `plugins/mega-sdd/references/output-language.md`). Per `./vault-contract.md` §boilerplate.

## Contents

- When to use this skill
- Core principle
- Workflow (brief → Q&A elaboration → vault)
- §brief / §qa — captured-source template (sections A–I)
- Question taxonomy
- --auto flag
- Halt handling

## When to use this skill

Trigger this skill for:

- "spec out this idea" / "from this prompt" / "baku dari ide" / "I have a brief not a PRD"
- The user types a short description of a project and wants to skip writing a full PRD.
- The user is currently round-tripping to ChatGPT to get a structured prompt for generate-intent; this skill replaces that round-trip.
- Inside `/mega-sdd:orchestrate-flow` Rule 0 chain (auto-dispatched when prompt arg detected and no vault/PRD in CWD).

Do NOT use this skill when:

- A real PRD/BRD doc exists — use `generate-intent` directly with the doc.
- The user wants to evolve an existing vault from a new prompt — that's a future capability (use `diff-vault` against a manually-written new doc for now).

## Core principle

> **Brief is origin. seed-PRD is source-of-truth. Claude never invents answers.**

The user's typed brief is captured verbatim in `§brief`. The Q&A elaboration is captured verbatim in `§qa`. Every claim in the seed-PRD body cites either the brief or a specific Q&A answer. Gaps stay `(unspecified)` and propagate to vault Open Questions. Anti-halu rails are non-negotiable.

## Workflow

### Step 0: Inputs

Accept the brief:

- If `$ARGUMENTS` is non-empty → use as the brief.
- If `$ARGUMENTS` is empty → ask via plain chat: *"Tell me about your idea — a few sentences or a paragraph is fine."* Capture the user's reply as the brief.

Reject and ask again if:
- Brief is < 20 characters AND not invoked from `flow` (when invoked from flow with `--auto`, emit `blocker` instead — see Halt handling).
- Brief is gibberish/unparseable (e.g., "asdfgh") — same treatment.

Persist:
- `BRIEF=<verbatim user input>`
- `OUTPUT_DIR=<resolved path>` — slug-derived from brief content (e.g., "leave-management-spec" from "I want a leave management web app"). Default location is `./<slug>-spec/`.

### Step 1: Brief inventory

Parse the brief deterministically — no LLM judgment for skip decisions, just keyword matching.

For each of the 10 topics in the Question Taxonomy below, mark **covered** | **partially covered** | **silent** based on whether the brief contains keywords/phrases addressing that topic. Examples:

- Brief mentions "web app" / "mobile app" / "API" → topic 1 (project shape) **covered**.
- Brief mentions "for HR admins" / "for SMEs" → topic 2 (users) **partially covered** (need persona detail).
- Brief mentions "manage leave" / "tracking" → topic 3 (problem) **partially covered** (need motivation detail).
- Brief silent on tech stack → topic 6 **silent**.

Persist a `BRIEF_INVENTORY` map: topic → status. Announce to user before Step 2:

*"Reading your brief — I see you covered: [shape, users, problem]. I'll ask about: [flows, mode, tech stack, compliance, success metrics, OOS, anything else]."*

### Step 2: Adaptive Q&A loop

For each topic in the taxonomy (1–10), in order:

1. Read `BRIEF_INVENTORY[topic]`.
2. **If covered**: skip. Record `{topic: "skipped — covered in brief"}` in the Q&A transcript.
3. **If partially covered**: ask a refinement question targeting the missing detail.
4. **If silent**: ask the default question.

Use `AskUserQuestion` for each ask (one question per turn). Multi-choice preferred where the taxonomy specifies (shape, mode, compliance); free-text otherwise.

**Hard cap: stop asking after 10 questions** (counting refinement and default questions; not skips). Remaining topics → `(unspecified)` markers.

**Stop conditions**:
- All 10 topics covered (asked or skipped) → exit loop.
- User says "enough", "skip the rest", "proceed", "lanjut", "cukup" → exit loop, mark remaining topics `(unspecified)`.
- 10 questions asked → exit loop (hard cap).

After exit, record `Q&A_TRANSCRIPT` as a list of `{question_n, topic, asked, answer}` entries.

### Step 3: Compose seed-PRD.md

Build the seed-PRD content per the file structure below. Apply citation conventions on every claim.

```markdown
# Seed PRD — <slug>

> **Generated by**: `/mega-sdd:generate-intent`
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
| 1 | Project shape | <Skipped — brief covered | Asked> | <verbatim answer or "(skipped)"> |
| ... | ... | ... | ... |

---

## A. Product
<2–3 sentences> *(brief; Q&A §N)*

## B. Target users
- **<Persona>** — <1-line> *(Q&A §N)*

## C. Problem & motivation
<text> *(brief; Q&A §N)*

## D. Goals / success criteria
- <KPI> *(Q&A §N)*

## E. In-scope features (v1)
1. **<Flow>** — <description> *(Q&A §N)*

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
- <topic> — <what's still unclear> *(Q&A §N)*
```

### Step 3a — Citation conventions (apply on every claim)

| Citation marker | Means |
|----------------|-------|
| `(brief)` | Directly from user's typed brief |
| `(brief §N)` | Specific clause if multi-paragraph |
| `(Q&A §N)` | Answer to question N |
| `(brief; Q&A §N)` | Combined source |
| `(brief; Q&A §N inferred from "...")` | Light inference, transparently flagged |
| `(unspecified)` | Gap → becomes OQ in vault |

**Hard rule**: NEVER write a claim without one of these markers. If you can't cite, the claim doesn't belong in the seed-PRD body.

### Step 3b — Honoring `(unspecified)` markers

For every silent or skipped topic from Step 2, the corresponding section gets a `(unspecified)` placeholder OR is omitted from the body and listed in `## I. Mentioned but not specified` for downstream OQ propagation.

### Step 4: Write seed-PRD.md to disk

1. Create directory: `<OUTPUT_DIR>/source/` (use Bash `mkdir -p` if needed; Write tool will also create parent dirs).
2. Write content from Step 3 to `<OUTPUT_DIR>/source/seed-PRD.md`. Overwrite if exists (warn user once).
3. Verify file exists.

### Step 5: Self-check before exit

- [ ] `§brief` contains the user's brief **verbatim**. No paraphrasing.
- [ ] `§qa` has one row per topic 1–10 (asked, skipped, or "(skipped — hard cap)").
- [ ] Every body claim ends with a citation marker.
- [ ] `(unspecified)` topics appear in `## I` and not silently in body.
- [ ] `**Status**: DRAFT` is in the metadata block.
- [ ] File path is `<OUTPUT_DIR>/source/seed-PRD.md` exactly.
- [ ] No invented field values, no auto-defaulted answers.

### Step 6: Present summary

Output to chat (no further file generation):

```
seed-PRD generated

Path: <OUTPUT_DIR>/source/seed-PRD.md
Brief: "<first 80 chars of brief>..."
Q&A: <N> questions asked, <M> skipped (covered in brief), <K> (unspecified)

Topics not specified (will become P1 OQs in vault):
- <topic 1>
- <topic 2>
...

Suggested next step:
- /mega-sdd:generate-intent <OUTPUT_DIR>/source/seed-PRD.md
- OR /mega-sdd:orchestrate-flow <OUTPUT_DIR> (auto-chains generation + resolve-oq)
```

If invoked from `orchestrate-flow` Rule 0, control returns to orchestrate-flow which dispatches `generate-intent` next.

## Question taxonomy

| # | Topic | Why critical | Default question | Format |
|---|-------|--------------|------------------|--------|
| 1 | Project shape | Drives 02-arch + 04-flows structure | "What kind of system?" | multi-choice (mobile-app / web-app / api-only / multi-platform / data-pipeline / custom) |
| 2 | Primary users / personas | 01-overview personas | "Who's the primary user?" | free-text |
| 3 | Core problem | 01-overview Problem | "What problem does this solve?" | free-text |
| 4 | Top 2–3 user flows | 04-flows skeleton | "Top 2–3 things a user does?" | free-text |
| 5 | Implementation mode | Mode flag + detect-drift applicability | "Greenfield or extending existing codebase?" | multi-choice (`new` / `existing`) |
| 6 | Tech stack constraints | 02-arch tech stack | "Any tech stack constraints?" | free-text or "no constraints" |
| 7 | Regulatory / compliance | 06-constraints | "Any regulatory requirements?" | multi-choice (GDPR / HIPAA / OJK / PDP-Indonesia / none / other) |
| 8 | Success metrics | 01-overview success criteria | "How will you know it's working?" | free-text or "TBD" |
| 9 | Out of scope | Every doc OOS | "What's NOT in scope for v1?" | free-text or "nothing decided" |
| 10 | Anything else | Catch-all | "Anything else critical?" | free-text or "no, proceed" |

## --auto flag

The `--auto` flag is passed by upstream callers (typically `/mega-sdd:orchestrate-flow` via Rule 0 chain) to skip logistical prompts only. **Substance prompts — every Q&A question — ALWAYS stay interactive.** That's the entire point of this skill: capturing the user's actual answers, never Claude's guesses.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (brief input) | If $ARGUMENTS empty, ask via chat | If $ARGUMENTS empty, **emit `blocker`** (`type=oq_blocker`, tag=`OQ-FROMPROMPT-0`, context="--auto invoked without brief") |
| Step 0 (output dir) | Default to `./<slug>-spec/` | Same default. If dir exists & non-empty, **STILL ASK** (destructive — never auto-overwrite). |
| Step 1 (brief inventory announce) | Show user the skip plan | Same — informational, not interactive |
| Step 2 (Q&A loop) | Ask each topic | **Always ask** every topic (substance prompt — hard rule, no override) |
| Step 6 (final summary) | Print to chat | Same — informational |

What stays interactive even with `--auto`:
- **Every Q&A question** — captures stakeholder answers.
- **Destructive overwrite confirmation** when `<OUTPUT_DIR>/source/seed-PRD.md` exists and would be replaced.

What `--auto` does NOT do (anti-halu rails — NEVER bypass):
- ❌ Auto-fill answers user didn't give.
- ❌ Compress / paraphrase brief or Q&A in `§brief` / `§qa`.
- ❌ Skip Q&A questions the brief doesn't cover.
- ❌ Push past 10 questions to "fill in more".
- ❌ Pretend the seed-PRD is stakeholder-signed.

## Halt handling

When `--auto` and the brief is unparseable (< 20 chars, gibberish, or empty after Step 0), emit:

```yaml
blocker:
  type: oq_blocker
  tag: OQ-FROMPROMPT-0
  priority: P1
  context: "from-prompt cannot elaborate — brief is too short or unparseable"
  resolver_owner: null
  resolver_route: "user must provide a longer brief or invoke from-prompt directly without --auto"
  vault_version: "n/a"
  source_skill: from-prompt
```

Per `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol. Caller (orchestrator) catches and surfaces to user.

## Quality bar

- **Verbatim capture**: brief and Q&A answers are recorded as typed. No tightening, no paraphrasing.
- **Citation completeness**: every body claim has a citation marker. None are bare.
- **Honest gaps**: `(unspecified)` markers stay; never replaced with Claude's best guess.
- **Hard cap respected**: never exceed 10 questions even if user is engaged.
- **Idempotent (after first write)**: re-running with the same brief + same answers produces an identical seed-PRD (modulo `Date`).

## What from-prompt does NOT do

- ❌ Generate vault content. Only seed-PRD.
- ❌ Invoke generate-intent or any other sub-skill (orchestrate-flow does that).
- ❌ Modify any vault docs (`00-index.md` through `06-constraints.md`).
- ❌ Push to remote.
- ❌ Persist state beyond the seed-PRD.md file (no `.gds-state.json`).
- ❌ Re-ask topics already covered in the brief.

## When to push back on the user

### Always

- **Brief is empty or <20 chars after Step 0** → ask once for a longer brief; refuse to proceed if user insists on a one-word brief.
- **User says "answer the questions for me"** → refuse. The whole point is capturing the user's actual intent.
- **User wants Claude to invent flows / decisions / metrics not in the brief** → refuse politely; offer to mark `(unspecified)`.

### Conditional

- **Output dir exists and contains a seed-PRD.md** → ask before overwriting.
- **Brief mentions multiple unrelated products** ("a leave app, also a CRM") → ask user which one to spec; refuse to spec multiple in one seed-PRD.

## References

- Schema, OQ conventions, citation conventions: `./vault-contract.md` (§schema, §OQ-conventions, §boilerplate). Halt protocol: `plugins/mega-sdd/references/halt-protocol.md` (§halt-protocol).
- Downstream consumer: `../SKILL.md` (generate-intent) consumes the seed-PRD as a normal source. PRD_STATUS auto-set to `draft` based on the seed-PRD's `Status: DRAFT` metadata.
- Orchestrator: `orchestrate-flow/SKILL.md` Rule 0 dispatches this skill via `--auto` when prompt input detected.
- For `vault.json.source_documents[].type = "seed-PRD"` is the recommended value when this skill's output is consumed; vault-contract.md §schema treats `type` as a free-form string.
