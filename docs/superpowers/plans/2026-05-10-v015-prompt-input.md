# v0.15 Prompt-Input + Default-On Chain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the v0.15 prompt-input feature per the spec at `docs/superpowers/specs/2026-05-10-prompt-input-design.md`. Adds a new `from-prompt` skill (brief → seed-PRD), extends the `flow` orchestrator with Rule 0 + default-on chaining across all rules, ships as plugin v0.15.0.

**Architecture:** Documentation/skill-instruction edits only — no runtime code. New top-level skill (`from-prompt`) plus a focused `flow` SKILL.md edit (Step 0 arg parsing + entire Decision matrix block). Each task ends in an atomic commit. Order: new skill first (Task 1) so flow has something to chain to (Task 3); user-facing docs (Task 4); version bump + CHANGELOG last (Task 5).

**Tech Stack:** Markdown, YAML frontmatter. No build tooling. Skill orchestration via the `Skill` tool inside Claude Code.

**Source spec:** `docs/superpowers/specs/2026-05-10-prompt-input-design.md`

**Decisions locked from spec:**
- Hybrid mode (prompt → seed-PRD → vault). Anti-halu rails attach to seed-PRD.
- 10-question hard cap on Q&A elaboration.
- seed-PRD location: `<output-dir>/source/seed-PRD.md`.
- Default-on chaining for ALL rules in flow — resolve-oq + drift-detect (when applicable) auto-chain.
- `>20 chars + no path-like chars` heuristic for prompt detection in flow Step 0.
- OQ-PROMPT-1: brief embedded in seed-PRD `§brief` (no separate `brief.txt`).
- OQ-PROMPT-2: Rule 0 chain uses `scope=p1-only` for resolve-oq.
- OQ-PROMPT-3: borderline prompt detection → ask user to confirm.

---

## File Structure

| File | Action | Why |
|------|--------|-----|
| `plugins/grand-design-spec/skills/from-prompt/SKILL.md` | **Create** | New elaboration skill (NEW at 0.1.0) |
| `plugins/grand-design-spec/commands/from-prompt.md` | **Create** | Slash command wrapper |
| `plugins/grand-design-spec/skills/flow/SKILL.md` | Modify | Add Rule 0; revise Rules 1, 2, 4, 5, 6 to default-on chaining; extend Step 0 arg parsing; bump version 0.1.0 → 0.2.0 |
| `README.md` | Modify | Add `/grand-design-spec:from-prompt` row + repo structure + changelog footer |
| `plugins/grand-design-spec/README.md` | Modify | Add from-prompt row + lifecycle diagram update |
| `plugins/grand-design-spec/.claude-plugin/plugin.json` | Modify | Plugin 0.14.0 → 0.15.0 |
| `.claude-plugin/marketplace.json` | Modify | Plugin 0.14.0 → 0.15.0 |
| `CHANGELOG.md` | Modify | v0.15.0 entry |

5 commits total. 2 new files, 6 modified files.

---

## Task 1: Create `from-prompt/SKILL.md`

**Files:**
- Create: `plugins/grand-design-spec/skills/from-prompt/SKILL.md`

The new elaboration skill. Reads brief, runs adaptive Q&A, writes seed-PRD.md.

- [ ] **Step 1: Create the file with EXACT content**

Use the Write tool. Create `plugins/grand-design-spec/skills/from-prompt/SKILL.md` with this content (everything between START/END markers, exclusive — do not include the markers):

START-OF-FILE-CONTENT
---
name: from-prompt
version: 0.1.0
description: Converts a free-text brief into a seed-PRD.md ready for vault generation. Runs adaptive Q&A (capped at 10 questions) to fill gaps the brief leaves open. Writes a structured seed-PRD with citations to brief and Q&A. Output is a normal source artifact for grand-design-spec. Triggers — "spec out this idea", "from this prompt", "buat dari ide", "I have a brief not a PRD", or paraphrases.
---

# From-Prompt — Brief to Seed-PRD elaboration

Converts a free-text user brief into a structured `seed-PRD.md` ready for `/grand-design-spec:grand-design-spec` to consume. Runs an adaptive Q&A elaboration loop (≤10 questions) to fill gaps the brief leaves open. Captures everything verbatim — no paraphrasing, no auto-fills.

> **Skill instruction language**: this skill is written in English for reasoning quality. Chat prompts (Q&A questions, summary) adapt to the user's language at runtime. Per `../grand-design-spec/references/vault-contract.md` §boilerplate.

## When to use this skill

Trigger this skill for:

- "spec out this idea" / "from this prompt" / "buat dari ide" / "I have a brief not a PRD"
- The user types a short description of a project and wants to skip writing a full PRD.
- The user is currently round-tripping to ChatGPT to get a structured prompt for grand-design-spec; this skill replaces that round-trip.
- Inside `/grand-design-spec:flow` Rule 0 chain (auto-dispatched when prompt arg detected and no vault/PRD in CWD).

Do NOT use this skill when:

- A real PRD/BRD doc exists — use `grand-design-spec` directly with the doc.
- The user wants to evolve an existing vault from a new prompt — that's a future capability (use `vault-diff` against a manually-written new doc for now).

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
- /grand-design-spec:grand-design-spec <OUTPUT_DIR>/source/seed-PRD.md
- OR /grand-design-spec:flow <OUTPUT_DIR> (auto-chains generation + resolve-oq)
```

If invoked from `flow` Rule 0, control returns to flow which dispatches `grand-design-spec` next.

## Question taxonomy

| # | Topic | Why critical | Default question | Format |
|---|-------|--------------|------------------|--------|
| 1 | Project shape | Drives 02-arch + 04-flows structure | "What kind of system?" | multi-choice (mobile-app / web-app / api-only / multi-platform / data-pipeline / custom) |
| 2 | Primary users / personas | 01-overview personas | "Who's the primary user?" | free-text |
| 3 | Core problem | 01-overview Problem | "What problem does this solve?" | free-text |
| 4 | Top 2–3 user flows | 04-flows skeleton | "Top 2–3 things a user does?" | free-text |
| 5 | Implementation mode | Mode flag + drift-detect applicability | "Greenfield or extending existing codebase?" | multi-choice (`new` / `existing`) |
| 6 | Tech stack constraints | 02-arch tech stack | "Any tech stack constraints?" | free-text or "no constraints" |
| 7 | Regulatory / compliance | 06-constraints | "Any regulatory requirements?" | multi-choice (GDPR / HIPAA / OJK / PDP-Indonesia / none / other) |
| 8 | Success metrics | 01-overview success criteria | "How will you know it's working?" | free-text or "TBD" |
| 9 | Out of scope | Every doc OOS | "What's NOT in scope for v1?" | free-text or "nothing decided" |
| 10 | Anything else | Catch-all | "Anything else critical?" | free-text or "no, proceed" |

## --auto flag (v0.1+)

The `--auto` flag is passed by upstream callers (typically `/grand-design-spec:flow` via Rule 0 chain) to skip logistical prompts only. **Substance prompts — every Q&A question — ALWAYS stay interactive.** That's the entire point of this skill: capturing the user's actual answers, never Claude's guesses.

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

Per `../grand-design-spec/references/vault-contract.md` §halt-protocol. Caller (orchestrator) catches and surfaces to user.

## Quality bar

- **Verbatim capture**: brief and Q&A answers are recorded as typed. No tightening, no paraphrasing.
- **Citation completeness**: every body claim has a citation marker. None are bare.
- **Honest gaps**: `(unspecified)` markers stay; never replaced with Claude's best guess.
- **Hard cap respected**: never exceed 10 questions even if user is engaged.
- **Idempotent (after first write)**: re-running with the same brief + same answers produces an identical seed-PRD (modulo `Date`).

## What from-prompt does NOT do

- ❌ Generate vault content. Only seed-PRD.
- ❌ Invoke grand-design-spec or any other sub-skill (flow does that).
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

- Schema, OQ conventions, halt protocol, citation conventions: `../grand-design-spec/references/vault-contract.md` (§schema, §OQ-conventions, §halt-protocol, §boilerplate).
- Downstream consumer: `../grand-design-spec/SKILL.md` consumes the seed-PRD as a normal source. PRD_STATUS auto-set to `draft` based on the seed-PRD's `Status: DRAFT` metadata.
- Orchestrator: `../flow/SKILL.md` Rule 0 dispatches this skill via `--auto` when prompt input detected.
- For `vault.json.source_documents[].type = "seed-PRD"` is the recommended value when this skill's output is consumed; vault-contract.md §schema treats `type` as a free-form string.
END-OF-FILE-CONTENT

- [ ] **Step 2: Verify**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
ls -la plugins/grand-design-spec/skills/from-prompt/SKILL.md
wc -l plugins/grand-design-spec/skills/from-prompt/SKILL.md
grep -n "version: 0.1.0" plugins/grand-design-spec/skills/from-prompt/SKILL.md
grep -c "## Workflow\|## Core principle\|## Question taxonomy\|## --auto flag\|## Halt handling\|## Quality bar\|## When to push back\|## References" plugins/grand-design-spec/skills/from-prompt/SKILL.md
grep -c "Hard rule\|hard rule\|hard cap\|Hard cap" plugins/grand-design-spec/skills/from-prompt/SKILL.md
```

Expected:
- file exists, ~250-300 lines, ~14-18K
- `version: 0.1.0` at line 3
- ≥7 hits for major section headers
- ≥3 hits for "hard rule"/"hard cap" (anti-halu language)

- [ ] **Step 3: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/from-prompt/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.15): add from-prompt skill (0.1.0) — brief to seed-PRD

New skill /grand-design-spec:from-prompt that converts a free-text
brief into a structured seed-PRD.md ready for grand-design-spec
consumption.

Workflow: capture brief verbatim → adaptive Q&A elaboration (≤10
questions, skip topics already covered in brief) → compose seed-PRD
with citation markers on every claim → write to <output-dir>/source/
seed-PRD.md.

Anti-halu rails: brief and Q&A captured verbatim, every claim cites
(brief) or (Q&A §N), gaps stay (unspecified) and propagate to vault
OQs. Claude NEVER auto-fills answers.

Eliminates the ChatGPT-to-Claude prompt-engineering round-trip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Create `commands/from-prompt.md`

**Files:**
- Create: `plugins/grand-design-spec/commands/from-prompt.md`

Slash command wrapper so `/grand-design-spec:from-prompt` appears in autocomplete.

- [ ] **Step 1: Create the file**

Use the Write tool. Content (everything between START/END markers, exclusive):

START-OF-FILE-CONTENT
---
description: Convert a free-text brief into a seed-PRD.md ready for vault generation. Runs adaptive Q&A (≤10 questions) to fill gaps, writes seed-PRD with verbatim brief + Q&A + cited body sections.
argument-hint: [optional brief text]
---

Invoke the `grand-design-spec:from-prompt` skill via the Skill tool to convert a user brief into a seed-PRD.md.

User arguments (brief text, or empty to be prompted in chat): $ARGUMENTS

Follow the skill exactly:

- Step 0: capture BRIEF from $ARGUMENTS or chat input. Reject < 20 chars or gibberish (emit `blocker` if `--auto` invoked).
- Step 1: deterministic brief inventory across 10 taxonomy topics — covered / partially covered / silent.
- Step 2: adaptive Q&A loop. Hard cap of 10 questions. Skip topics already covered. Substance prompts ALWAYS interactive even in `--auto`.
- Step 3: compose seed-PRD per file structure (§brief verbatim, §qa table, sections A–I with citation markers on every claim).
- Step 4: write to `<output-dir>/source/seed-PRD.md`.
- Step 5: self-check (verbatim capture, citation completeness, unspecified markers).
- Step 6: chat summary + suggested next step (grand-design-spec or flow).

Hard rails:
- Brief and Q&A captured verbatim — no paraphrasing.
- Every body claim has a citation marker.
- (unspecified) markers stay — propagate to vault OQs.
- Hard cap of 10 questions — never exceed.
- No auto-fill of user answers in `--auto` mode (substance prompts always interactive).
END-OF-FILE-CONTENT

- [ ] **Step 2: Verify**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
ls -la plugins/grand-design-spec/commands/from-prompt.md
grep -n "description:" plugins/grand-design-spec/commands/from-prompt.md
grep -c "argument-hint:" plugins/grand-design-spec/commands/from-prompt.md
grep -c "Hard rails" plugins/grand-design-spec/commands/from-prompt.md
```

Expected: file exists ~1.5KB; 1 hit for description, argument-hint, Hard rails.

- [ ] **Step 3: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/commands/from-prompt.md
git commit -m "$(cat <<'EOF'
feat(v0.15): add /grand-design-spec:from-prompt slash command

Thin wrapper around the new from-prompt skill so it appears in the
/ autocomplete menu alongside the existing 6 commands (flow,
grand-design-spec, resolve-oq, vault-diff, drift-detect, update).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Update `flow/SKILL.md` — Rule 0 + default-on chaining + arg-parsing extension

**Files:**
- Modify: `plugins/grand-design-spec/skills/flow/SKILL.md`

Three coordinated changes:
1. Bump version 0.1.0 → 0.2.0.
2. Extend Step 0 arg parsing to recognize free-text args >20 chars as prompts.
3. Replace the entire Decision matrix block with the v0.15 7-rule revision (adds Rule 0, makes Rules 1/2/4/5/6 default-on chained).

- [ ] **Step 1: Bump frontmatter version**

Use Edit tool. Replace `version: 0.1.0` with `version: 0.2.0` (line 3 of frontmatter).

- [ ] **Step 2: Extend Step 0 arg parsing**

Find the existing Step 0 inputs block. Use Edit.

OLD STRING:
```
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
```

NEW STRING:
```
### Step 0: Inputs

Accept arguments:

- **No args** → operate on CWD.
- **One arg = directory path** → operate on this vault.
- **One arg = file path** (`.pdf`/`.docx`/`.md`) → bias toward "vault-diff this PRD against the closest vault in CWD".
- **One arg = free text** (>20 chars, no path-like characters such as `/`, `.`, or starting with `~`) → treat as prompt for Rule 0 chain.
- **Borderline ambiguous arg** (e.g., 15-char input, or contains both file-like and prose-like content) → ask user via `AskUserQuestion`: "Treat this as a prompt or look for it as a file path?".

Persist:

- `WORK_DIR=<resolved CWD>`
- `EXPLICIT_VAULT_PATH=<path or null>`
- `EXPLICIT_PRD_PATH=<path or null>`
- `EXPLICIT_PROMPT=<text or null>` (v0.2+)

If WORK_DIR is empty (no files at all) and no args, STOP and tell the user: *"No vault, no PRD, no prompt detected. Point me at one: `/grand-design-spec:flow ./vault-dir/`, `/grand-design-spec:flow PRD-v2.pdf`, or `/grand-design-spec:flow \"<your brief>\"`."*
```

- [ ] **Step 3: Replace the Decision matrix block**

Find the entire Decision matrix from `### Step 2: Build proposed chain` through the end of its decision-rules code block. Use Edit tool.

OLD STRING:
```
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
```

NEW STRING:
```
### Step 2: Build proposed chain

Apply the decision matrix in order. First match wins; chains include all applicable downstream skills by default. User can skip individual steps via `Edit plan: skip step N` in Step 3 confirmation.

```
RULE 0 (NEW v0.2) — IF no vault AND no PRD file detected AND prompt arg given:
    → chain: from-prompt → grand-design-spec → resolve-oq (scope=p1-only)
    → drift-detect not applicable (mode=new vault, no codebase yet)

RULE 1 (default-on v0.2) — IF no vault AND PRD detected:
    → chain: grand-design-spec → resolve-oq (scope=p1-only)
    → drift-detect chained ONLY IF user selected mode=existing during gds

RULE 2 (default-on v0.2) — IF vault exists AND new PRD detected
    (filename or version differs from vault's PRD source):
    → chain: vault-diff → resolve-oq (scope=p1-only, only if new P1s introduced)
    → drift-detect chained ONLY IF mode=existing AND codebase available in CWD

RULE 3 (unchanged) — IF vault exists AND vault.json missing:
    → chain: grand-design-spec re-run with vault's existing flags (regenerates manifest only)

RULE 4 (default-on v0.2) — IF vault exists AND P1 count > 0 AND no new PRD:
    → chain: resolve-oq (scope=p1-only)
    → drift-detect chained ONLY IF mode=existing AND codebase available

RULE 5 (default-on v0.2) — IF vault exists AND mode=existing AND codebase detected:
    → chain: drift-detect → resolve-oq (scope=p1-only, only if vault-side actions queued)

RULE 6 (default-on v0.2) — IF vault exists AND mode=new AND mode_migrate_after trigger has fired:
    → chain: vault-diff with mode flip prompt OR manual edit instruction → resolve-oq (only if new P1s introduced)
      (only if trigger is auto-detectable — e.g., "first commit on main")

RULE 7 (unchanged) — IF nothing matched:
    → STOP, surface "no vault or PRD found, or no actionable state — point me at a PRD or vault dir"
```

**Default-on behavior change** (v0.1 → v0.2): Rules 1, 2, 4, 5, 6 previously had opt-in / conditional chaining for `resolve-oq` and `drift-detect`. v0.2 makes those chains default-on. User skips via `Edit plan: skip N` in the Step 3 confirmation. Friction shifts from "remember to opt in" to "edit out if not wanted." Plan-confirmation step still surfaces full chain before any skill runs.
```

- [ ] **Step 4: Verify**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -n "version: 0.2.0" plugins/grand-design-spec/skills/flow/SKILL.md
grep -n "EXPLICIT_PROMPT" plugins/grand-design-spec/skills/flow/SKILL.md
grep -c "RULE 0" plugins/grand-design-spec/skills/flow/SKILL.md
grep -c "default-on v0.2\|NEW v0.2" plugins/grand-design-spec/skills/flow/SKILL.md
grep -c "Default-on behavior change" plugins/grand-design-spec/skills/flow/SKILL.md
grep -c "from-prompt" plugins/grand-design-spec/skills/flow/SKILL.md
```

Expected:
- `version: 0.2.0` at line 3
- `EXPLICIT_PROMPT` ≥ 1 hit (Step 0 persist line)
- `RULE 0` ≥ 1 hit
- "default-on v0.2" or "NEW v0.2" ≥ 5 hits (Rules 0, 1, 2, 4, 5, 6 — at least 5 markers)
- "Default-on behavior change" 1 hit
- `from-prompt` ≥ 1 hit (Rule 0 chain)

- [ ] **Step 5: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/skills/flow/SKILL.md
git commit -m "$(cat <<'EOF'
feat(v0.15): flow skill 0.1.0 → 0.2.0 — Rule 0 + default-on chaining

Adds Rule 0 to the decision matrix: when no vault + no PRD file is
detected and a prompt arg is given, chains from-prompt →
grand-design-spec → resolve-oq automatically.

Extends Step 0 arg parsing to recognize free-text args >20 chars (no
path-like characters) as prompts, persisted as EXPLICIT_PROMPT.
Borderline ambiguous args trigger an AskUserQuestion clarification.

Revises Rules 1, 2, 4, 5, 6 from opt-in/conditional resolve-oq +
drift-detect chaining to default-on. User skips individual steps via
"Edit plan: skip N" in the confirmation step. Plan-confirmation still
surfaces the full chain before any skill runs — anti-halu rails
preserved.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Update READMEs (root + plugin)

**Files:**
- Modify: `README.md`
- Modify: `plugins/grand-design-spec/README.md`

Two coordinated edits in a single atomic commit.

- [ ] **Step 1: Add from-prompt to root README commands table**

Use Edit. Find the existing v0.14 commands table.

OLD STRING:
```
| Slash command | Use when | Skill |
|---------------|----------|-------|
| `/grand-design-spec:flow` ⭐ (v0.14) | "Do the next thing" — inspects state, proposes a chain, runs sub-skills with `--auto` | lifecycle orchestrator |
| `/grand-design-spec:grand-design-spec` | Initial vault from PRD/BRD/Figma | vault generator |
| `/grand-design-spec:resolve-oq` | Stakeholder meeting answered some OQs | OQ resolver |
| `/grand-design-spec:vault-diff` | PRD got a new version | vault evolution |
| `/grand-design-spec:drift-detect` | `mode=existing` — reconcile against live codebase | vault ↔ code drift |
| `/grand-design-spec:update` | Pull latest plugin from `origin/main` and refresh cache | plugin maintenance |
```

NEW STRING:
```
| Slash command | Use when | Skill |
|---------------|----------|-------|
| `/grand-design-spec:flow` ⭐ (v0.14, chains all v0.15) | "Do the next thing" — inspects state, proposes a chain, runs sub-skills with `--auto`. v0.15 chains all applicable skills by default. | lifecycle orchestrator |
| `/grand-design-spec:from-prompt` 🆕 (v0.15) | No PRD doc — just a free-text brief. Skill runs adaptive Q&A, writes seed-PRD.md as source for grand-design-spec | brief → seed-PRD elaborator |
| `/grand-design-spec:grand-design-spec` | Initial vault from PRD/BRD/Figma (or seed-PRD.md from from-prompt) | vault generator |
| `/grand-design-spec:resolve-oq` | Stakeholder meeting answered some OQs | OQ resolver |
| `/grand-design-spec:vault-diff` | PRD got a new version | vault evolution |
| `/grand-design-spec:drift-detect` | `mode=existing` — reconcile against live codebase | vault ↔ code drift |
| `/grand-design-spec:update` | Pull latest plugin from `origin/main` and refresh cache | plugin maintenance |
```

- [ ] **Step 2: Update root README repo structure**

OLD STRING:
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
```

NEW STRING:
```
│       ├── commands/                         # user-typeable slash commands
│       │   ├── flow.md                       # → orchestrator skill (v0.14)
│       │   ├── from-prompt.md                # → brief→seed-PRD skill (v0.15)
│       │   ├── grand-design-spec.md          # → main vault generator skill
│       │   ├── resolve-oq.md                 # → OQ resolver skill
│       │   ├── vault-diff.md                 # → vault evolution skill
│       │   ├── drift-detect.md               # → vault ↔ code drift skill
│       │   └── update.md                     # plugin maintenance: git pull + cache nudge
│       ├── skills/
│       │   ├── flow/                         # orchestrator skill (v0.14, chains all v0.15)
│       │   │   └── SKILL.md
│       │   ├── from-prompt/                  # brief→seed-PRD elaborator (v0.15)
│       │   │   └── SKILL.md
```

- [ ] **Step 3: Update root README Changelog footer**

OLD STRING:
```
## Changelog

See [CHANGELOG.md](./CHANGELOG.md). Latest: **v0.14.0** — adds `/grand-design-spec:flow`, the multi-skill lifecycle orchestrator. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms with user once, then executes in `--auto` mode. Existing skills gain a `--auto` flag that skips logistical prompts but never substance prompts (anti-halu rails preserved by composition). The v0.11 `OQ_BLOCKER` halt-artifact unifies into a `blocker` envelope with new `diff_conflict` and `drift_framework_mismatch` types. Earlier highlights: v0.13 closed audit findings + extracted shared `vault-contract.md`; v0.12.x exposed lifecycle skills as slash commands; v0.11 introduced `vault.json` + halt protocol + mode-migration trigger.
```

NEW STRING:
```
## Changelog

See [CHANGELOG.md](./CHANGELOG.md). Latest: **v0.15.0** — adds `/grand-design-spec:from-prompt` for prompt-input mode (eliminates ChatGPT-to-Claude round-trip — type a brief, skill runs ≤10-question Q&A, writes seed-PRD.md as source for the existing pipeline). `flow` orchestrator gains Rule 0 (auto-chain from-prompt → grand-design-spec → resolve-oq when prompt detected) and shifts Rules 1, 2, 4, 5, 6 from opt-in/conditional chaining to default-on — every flow invocation now naturally walks the lifecycle to its endpoint. Anti-halu rails preserved by composition. Earlier highlights: v0.14 introduced the flow orchestrator + `--auto` flag + unified `blocker` envelope; v0.13 closed audit findings + extracted shared `vault-contract.md`; v0.11 introduced `vault.json` + halt protocol + mode-migration trigger.
```

- [ ] **Step 4: Update plugin README skills+commands table**

Find the v0.14 plugin README skills table.

OLD STRING:
```
| Slash command | Skill | Purpose |
|---------------|-------|---------|
| `/grand-design-spec:flow` ⭐ | **`flow`** (v0.14) | Lifecycle orchestrator. Inspects CWD, proposes a chain of sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms with user once, then executes the chain in `--auto` mode. Stateless. Pauses on `blocker` artifacts. Anti-halu rails preserved by composition. |
| `/grand-design-spec:grand-design-spec` | **`grand-design-spec`** | Initial vault generation. PRD/BRD/Figma → 7-file dev handoff folder with anti-hallucination guarantees. Also writes a `vault.json` manifest for machine consumption. Supports `--auto` (v0.10+). |
| `/grand-design-spec:resolve-oq` | **`resolve-oq`** | Interactive Open Questions resolver. Walks the OQ roll-up by priority, captures stakeholder answers, updates the vault with version bump + Changelog. Preserves OQ tag identity as audit trail. Cross-cutting OQs land in a primary doc with cross-refs in others. Supports `--auto` for logistical prompts (v0.4+); per-OQ choices stay interactive. |
| `/grand-design-spec:vault-diff` | **`vault-diff`** | Vault evolution when the PRD/BRD source revisions. Computes structured diff, surfaces conflicts (Resolved-OQ vs new PRD, ADR vs new PRD) for explicit user resolution, applies approved changes without losing prior history. Supports `--auto` (v0.3+); conflicts emit `blocker` (type=`diff_conflict`) and pause. |
| `/grand-design-spec:drift-detect` | **`drift-detect`** | For `mode=existing` vaults: scans the live codebase, compares against vault, flags drift (entity rename, type changed, decision violated, code shipped without ADR). For `mode=new` vaults, surfaces the `mode_migrate_after` trigger so you know what to do before re-running. Supports `--auto` (v0.3+); skips interactive walkthrough, writes `DRIFT-REPORT.md` only. |
| `/grand-design-spec:update` | _(no skill — bash wrapper)_ | Plugin maintenance. `git pull --ff-only` inside `~/.claude/plugins/marketplaces/grand-design-spec/`, prints before/after version, then prompts you to run the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. |
```

NEW STRING:
```
| Slash command | Skill | Purpose |
|---------------|-------|---------|
| `/grand-design-spec:flow` ⭐ | **`flow`** (v0.14, chains all v0.15) | Lifecycle orchestrator. Inspects CWD, proposes a chain of sub-skills, confirms once, executes in `--auto` mode. v0.15 chains all applicable skills by default — every flow invocation walks the lifecycle to its endpoint. Stateless. Pauses on `blocker` artifacts. Anti-halu rails preserved by composition. |
| `/grand-design-spec:from-prompt` 🆕 | **`from-prompt`** (v0.15) | Brief → seed-PRD elaborator. Captures user's free-text brief, runs adaptive Q&A (≤10 questions, skips topics already in brief), writes `seed-PRD.md` with verbatim brief + Q&A + cited body sections. seed-PRD becomes a normal source artifact for grand-design-spec. Eliminates the ChatGPT round-trip for users without a full PRD doc. Substance prompts always interactive even with `--auto`. |
| `/grand-design-spec:grand-design-spec` | **`grand-design-spec`** | Initial vault generation. PRD/BRD/Figma (or seed-PRD.md from from-prompt) → 7-file dev handoff folder with anti-hallucination guarantees. Also writes a `vault.json` manifest for machine consumption. Supports `--auto` (v0.10+). |
| `/grand-design-spec:resolve-oq` | **`resolve-oq`** | Interactive Open Questions resolver. Walks the OQ roll-up by priority, captures stakeholder answers, updates the vault with version bump + Changelog. Preserves OQ tag identity as audit trail. Cross-cutting OQs land in a primary doc with cross-refs in others. Supports `--auto` for logistical prompts (v0.4+); per-OQ choices stay interactive. |
| `/grand-design-spec:vault-diff` | **`vault-diff`** | Vault evolution when the PRD/BRD source revisions. Computes structured diff, surfaces conflicts (Resolved-OQ vs new PRD, ADR vs new PRD) for explicit user resolution, applies approved changes without losing prior history. Supports `--auto` (v0.3+); conflicts emit `blocker` (type=`diff_conflict`) and pause. |
| `/grand-design-spec:drift-detect` | **`drift-detect`** | For `mode=existing` vaults: scans the live codebase, compares against vault, flags drift (entity rename, type changed, decision violated, code shipped without ADR). For `mode=new` vaults, surfaces the `mode_migrate_after` trigger so you know what to do before re-running. Supports `--auto` (v0.3+); skips interactive walkthrough, writes `DRIFT-REPORT.md` only. |
| `/grand-design-spec:update` | _(no skill — bash wrapper)_ | Plugin maintenance. `git pull --ff-only` inside `~/.claude/plugins/marketplaces/grand-design-spec/`, prints before/after version, then prompts you to run the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. |
```

- [ ] **Step 5: Update plugin README lifecycle diagram**

Find the v0.14 diagram showing flow over the row of sub-skills.

OLD STRING:
````
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
````

NEW STRING:
````
## Lifecycle at a glance

```
                              flow (v0.14, chains all v0.15)
                      ──────────────────────────────────────────
                      Inspects CWD, proposes chain, runs in --auto.
                      v0.15 chains all applicable skills by default.

   No PRD —       Initial PRD      Stakeholder mtg    PRD revisi     Live codebase
   just a brief        │                 │                 │                │
       │               │                 │                 │                │
       ▼               ▼                 ▼                 ▼                ▼
  from-prompt → grand-design-spec → resolve-oq     →   vault-diff   →   drift-detect
   (v0.15)                                                              (existing only)
       │               │                 │                 │                │
       ▼               ▼                 ▼                 ▼                ▼
  seed-PRD.md      vault v1.0        vault v1.1        vault v1.2     DRIFT-REPORT.md
                                                                       DRIFT-ACTIONS.md
```

`flow` is the recommended entry point: type a brief or point at a PRD/vault, and the orchestrator chains the right sub-skills automatically. Direct invocation of any sub-skill still works (and bypasses orchestration when you want full interactive control).
````

- [ ] **Step 6: Verify all 5 edits applied**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -c "/grand-design-spec:from-prompt" README.md
grep -c "/grand-design-spec:from-prompt" plugins/grand-design-spec/README.md
grep -c "v0.15" README.md
grep -c "v0.15" plugins/grand-design-spec/README.md
grep -c "from-prompt/" README.md
grep -c "seed-PRD" README.md
grep -c "seed-PRD" plugins/grand-design-spec/README.md
```

Expected:
- ≥2 hits for `/grand-design-spec:from-prompt` in each README
- ≥2 v0.15 mentions in each README
- ≥1 hit for `from-prompt/` directory in root README
- ≥1 hit for `seed-PRD` in each README

- [ ] **Step 7: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add README.md plugins/grand-design-spec/README.md
git commit -m "$(cat <<'EOF'
docs(v0.15): update READMEs for from-prompt + default-on chaining

- Root README: add /grand-design-spec:from-prompt row to commands
  table (with 🆕 v0.15 marker), add from-prompt/ skill dir to repo
  structure, bump changelog footer to v0.15.0.
- Plugin README: add from-prompt row + flow note about default-on
  chaining; update lifecycle diagram to show from-prompt as a new
  entry point (no-PRD column) feeding into the chain.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Bump versions to 0.15.0 + CHANGELOG entry

**Files:**
- Modify: `plugins/grand-design-spec/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md`

Final atomic commit. Plugin/marketplace bumps + CHANGELOG entry move together.

- [ ] **Step 1: Bump plugin.json**

Use Edit. Replace `"version": "0.14.0"` with `"version": "0.15.0"`.

- [ ] **Step 2: Bump marketplace.json**

Use Edit. Replace `"version": "0.14.0"` with `"version": "0.15.0"` (in `plugins[0]` entry).

- [ ] **Step 3: Add v0.15.0 CHANGELOG entry**

Find the line `## [0.14.0] — 2026-05-09` and insert the new v0.15.0 block immediately above it.

OLD STRING:
```
## [0.14.0] — 2026-05-09
```

NEW STRING:
```
## [0.15.0] — 2026-05-10

The prompt-input release. Adds `/grand-design-spec:from-prompt` so users can start from a free-text brief instead of a PRD doc — eliminating the ChatGPT-to-Claude round-trip for prompt engineering. The orchestrator's `flow` chain becomes default-on across all rules: every invocation now walks the lifecycle to its natural endpoint without opt-in friction.

### Skill version moves

- `from-prompt`: **NEW at 0.1.0** (brief → seed-PRD elaborator)
- `flow`: 0.1.0 → **0.2.0** (Rule 0 + default-on chaining for Rules 1, 2, 4, 5, 6 + arg parsing extension for free-text prompts)
- `grand-design-spec`: unchanged at 0.10.0 (consumes seed-PRD.md as a normal source — no behavior change needed)
- `resolve-oq`: unchanged at 0.4.0
- `vault-diff`: unchanged at 0.3.0
- `drift-detect`: unchanged at 0.3.0

### Added

- **`/grand-design-spec:from-prompt`** — converts a free-text brief into `<output-dir>/source/seed-PRD.md`. Workflow: capture brief verbatim → adaptive Q&A across 10 fixed taxonomy topics (skip topics already covered in brief, hard cap at 10 questions) → compose seed-PRD with citation markers (`(brief)` / `(Q&A §N)` / `(unspecified)`) on every claim → write to disk. Substance prompts always interactive even with `--auto`. Halt protocol: emits `blocker` (type=`oq_blocker`, tag=`OQ-FROMPROMPT-0`) when brief is unparseable in `--auto` mode.
- **Rule 0 in `flow`'s decision matrix** — fires when no vault and no PRD file detected and prompt arg given. Auto-chains `from-prompt → grand-design-spec → resolve-oq (scope=p1-only)`. drift-detect not applicable (mode=new for prompt-input vaults).
- **Default-on chaining for `flow` Rules 1, 2, 4, 5, 6** — `resolve-oq` and `drift-detect` (when applicable) now chain automatically instead of being opt-in/conditional. User skips individual steps via `Edit plan: skip step N` in Step 3 confirmation. Plan-confirmation step still surfaces full chain before any skill runs.
- **Free-text arg parsing in `flow` Step 0** — args >20 chars without path-like characters are recognized as prompts (persisted as `EXPLICIT_PROMPT`). Borderline ambiguous args trigger `AskUserQuestion` clarification.
- **`seed-PRD` as a recognized `vault.json.source_documents[].type`** value — documented in `from-prompt/SKILL.md` references; `vault-contract.md` §schema treats `type` as free-form so no contract change required.

### Changed

- **`flow/SKILL.md`** Step 0 arg-parsing block extended to recognize free-text prompts; Decision matrix block fully replaced with v0.2 7-rule revision (adds Rule 0, marks Rules 1/2/4/5/6 as default-on); version 0.1.0 → 0.2.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.14.0 → 0.15.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:from-prompt` row, update lifecycle diagram (from-prompt as new entry point), update repo structure with `from-prompt/` skill dir, bump changelog footer.

### Backward compatibility

- v0.14 vaults continue to work unchanged. seed-PRD.md is just another source for `grand-design-spec` — no schema or vault structure changes.
- Direct invocation of `flow` with file/dir args works exactly as v0.14 (Rule 0 only fires when args are free text).
- Direct invocation of `flow` without args produces a Rule 7 STOP if WORK_DIR is empty — same as v0.14, with updated error message mentioning prompt option.
- Default-on chaining is a behavior change for users who relied on opt-in chains in v0.14. Mitigation: plan-confirmation step shows the full chain; user edits to skip steps they don't want. No anti-halu rail changes.
- Direct invocation of any sub-skill (`from-prompt`, `grand-design-spec`, etc.) without `flow` is unchanged — full interactive behavior when `--auto` is not passed.

### Notes

- The orchestrator stays **stateless by design**. Re-running `flow` re-inspects CWD; no `.gds-state.json` is written.
- **Hard cap of 3 skills per chain** stays at 3 (verified across all 7 rules including the new Rule 0).
- **`flow` does NOT run sub-skills in parallel** — sequential only.
- Audit findings deferred to v0.16+: vault evolution from a new prompt (`from-prompt → vault-diff` chain), multi-turn brief refinement, seed-PRD versioning across runs, voice-input briefs, reorder-and-edit-args plan editing in flow.

## [0.14.0] — 2026-05-09
```

- [ ] **Step 4: Verify**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -c "0.15.0" plugins/grand-design-spec/.claude-plugin/plugin.json
grep -c "0.15.0" .claude-plugin/marketplace.json
grep -n "## \[0.15.0\]" CHANGELOG.md
grep -c "Skill version moves" CHANGELOG.md
grep -A3 "## \[0.15.0\]" CHANGELOG.md | head -5
```

Expected:
- 1 hit each in plugin.json and marketplace.json
- 1 hit for "## [0.15.0]" heading (above [0.14.0])
- ≥3 hits for "Skill version moves" (this entry + v0.14 + v0.13)

- [ ] **Step 5: Final cross-check that v0.15 is fully wired**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
echo "--- from-prompt skill exists ---"
test -f plugins/grand-design-spec/skills/from-prompt/SKILL.md && echo OK
echo "--- from-prompt command exists ---"
test -f plugins/grand-design-spec/commands/from-prompt.md && echo OK
echo "--- flow has Rule 0 ---"
grep -c "RULE 0" plugins/grand-design-spec/skills/flow/SKILL.md
echo "--- flow has default-on markers ---"
grep -c "default-on v0.2\|NEW v0.2" plugins/grand-design-spec/skills/flow/SKILL.md
echo "--- flow has EXPLICIT_PROMPT ---"
grep -c "EXPLICIT_PROMPT" plugins/grand-design-spec/skills/flow/SKILL.md
echo "--- skill versions ---"
for skill in flow from-prompt grand-design-spec resolve-oq vault-diff drift-detect; do
  echo -n "$skill: "
  grep "^version:" plugins/grand-design-spec/skills/$skill/SKILL.md
done
echo "--- plugin version ---"
grep '"version"' plugins/grand-design-spec/.claude-plugin/plugin.json | head -1
echo "--- READMEs contain from-prompt ---"
grep -c "/grand-design-spec:from-prompt" README.md
grep -c "/grand-design-spec:from-prompt" plugins/grand-design-spec/README.md
echo "--- CHANGELOG has v0.15 entry ---"
grep -c "## \[0.15.0\]" CHANGELOG.md
```

Expected:
- both files exist
- Rule 0 ≥ 1 hit
- default-on markers ≥ 5 hits
- EXPLICIT_PROMPT ≥ 1 hit
- Skill versions: flow 0.2.0, from-prompt 0.1.0, grand-design-spec 0.10.0, resolve-oq 0.4.0, vault-diff 0.3.0, drift-detect 0.3.0
- Plugin version: 0.15.0
- READMEs: ≥2 hits each
- CHANGELOG: 1 hit for v0.15.0 heading

- [ ] **Step 6: Commit**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
git add plugins/grand-design-spec/.claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(v0.15): bump versions and add CHANGELOG entry

Plugin 0.14.0 → 0.15.0. The prompt-input release — adds
/grand-design-spec:from-prompt + extends flow with Rule 0 and
default-on chaining across all rules.

Skill version moves enumerated:
- from-prompt: NEW at 0.1.0
- flow: 0.1.0 → 0.2.0
- grand-design-spec / resolve-oq / vault-diff / drift-detect: unchanged

Default-on chaining is the only v0.14 → v0.15 behavior change. User
skips via "Edit plan: skip N" in flow's confirmation step.
Anti-halu rails preserved by composition.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

**Spec coverage:**

| Spec section | Plan task | Covered? |
|--------------|-----------|----------|
| Section 1 (skill identity, output location, slug-derived dir) | Task 1 (frontmatter + Step 4 dir creation) + Task 2 (command) | ✅ |
| Section 2 (Q&A taxonomy, skip rules, hard cap, stop conditions) | Task 1 (Steps 1, 2 + Question taxonomy table) | ✅ |
| Section 3 (seed-PRD format, citation conventions, vault Sources reflection) | Task 1 (Step 3 file structure + Step 3a citations) | ✅ |
| Section 4 (Rule 0, default-on Rules 1–6, arg parsing, plan format example) | Task 3 (Steps 2, 3) | ✅ |
| Section 5 (5 anti-halu rails) | Task 1 (Core principle + --auto flag + Quality bar + What does NOT do + push back rules) | ✅ |
| Section 6 (file count, version moves, commit chain) | Task 1–5 directly map | ✅ |
| OQ-PROMPT-1 (embedded brief in §brief) | Task 1 (file structure shows §brief, no separate brief.txt) | ✅ |
| OQ-PROMPT-2 (Rule 0 chain uses scope=p1-only) | Task 3 (Rule 0 explicitly states `scope=p1-only`) | ✅ |
| OQ-PROMPT-3 (borderline prompt → ask user) | Task 3 (Step 0 arg parsing addition: "Borderline ambiguous arg → ask user") | ✅ |

All 9 spec items + 3 OQs covered.

**Placeholder scan:** none. Every step contains the actual content to insert. No "TBD", "TODO", "implement later", or vague directives.

**Type consistency:**
- `EXPLICIT_PROMPT` (variable name) consistent across Task 3 Step 2 and the verification grep.
- Skill version targets (Tasks 1, 3) match the CHANGELOG entry (Task 5).
- File paths absolute and consistent across tasks.
- Citation markers `(brief)` / `(Q&A §N)` / `(unspecified)` consistent across Task 1 file content.
- Rule numbering (0–7) consistent between Task 3 NEW STRING and Task 5 CHANGELOG description.

---

Plan complete and saved to `docs/superpowers/plans/2026-05-10-v015-prompt-input.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh haiku subagent per task, two-stage review between tasks. Pattern proven across v0.13 (10 tasks) and v0.14 (10 tasks). v0.15 has 5 tasks; should run fast.

2. **Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batched with checkpoints.

Which approach?
