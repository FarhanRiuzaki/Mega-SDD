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
