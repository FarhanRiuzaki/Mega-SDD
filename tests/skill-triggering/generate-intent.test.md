# generate-intent Triggering Test

Manual-run fixture for Mode A (structured) and Mode B (free-text).

## Mode A — Structured input

### Case A1: Explicit slash with PRD path
- **Prompt:** `/mega-sdd:generate-intent ./prd.md`
- **Expect:** Skill invocation, Mode A, no Q&A unless PRD is incomplete

### Case A2: Indonesian trigger phrase + PRD in CWD
- **Setup:** `prd.md` exists in CWD
- **Prompt:** `pecah PRD ini buat dev`
- **Expect:** Skill invocation, Mode A on the detected PRD

## Mode B — Free-text input

### Case B1: Explicit --from-prompt flag
- **Prompt:** `/mega-sdd:generate-intent --from-prompt "build a clinic appointment system"`
- **Expect:** Skill invocation, Mode B, ≤10 adaptive Q&A questions

### Case B2: Natural language brief, no PRD in CWD
- **Setup:** empty CWD (no .md files)
- **Prompt:** `I only have an idea, not a PRD. Let me describe it...`
- **Expect:** Skill invocation, Mode B, opens Q&A flow

## Pass criteria

All 4 cases invoke `generate-intent` skill with correct mode selected.

## Mode auto-detect (v1.2+)

Manual-run fixture for the 6 detection rules. Each case maps to one rule.

### AD1: Rule 1 — Explicit flag wins
- **Prompt:** `/mega-sdd:generate-intent --from-prompt "build a TODO CLI"`
- **Expect:** Mode B activates; no path-detection attempted on the flag value

### AD2: Rule 2 — Existing file path → Mode A
- **Setup:** Create `./prd.md` in CWD
- **Prompt:** `/mega-sdd:generate-intent ./prd.md`
- **Expect:** Mode A activates; parses the existing file

### AD3: Rule 3 — Path-like with missing file → Mode A with warning
- **Setup:** No file at `./missing-prd.md`
- **Prompt:** `/mega-sdd:generate-intent ./missing-prd.md`
- **Expect:** Skill warns `"File ./missing-prd.md not found. Treating as Mode A path. To use free-text, wrap in quotes or use --from-prompt."` and offers to abort. If user proceeds, Mode A attempted on the missing path (which will fail downstream — but the detection is correct).

### AD4: Rule 4 — Quoted brief → Mode B
- **Prompt:** `/mega-sdd:generate-intent "build a TODO CLI in python"`
- **Expect:** Mode B activates; treats the quoted string as a brief; opens Q&A flow

### AD5: Rule 4 — Whitespace brief → Mode B
- **Prompt:** `/mega-sdd:generate-intent build a TODO CLI in python`
- **Expect:** Mode B activates (positional has whitespace, no path-like chars); treats as brief

### AD6: Rule 5 — Bare single word → Mode B
- **Prompt:** `/mega-sdd:generate-intent dashboard`
- **Expect:** Mode B activates (no path separator, no extension); treats `dashboard` as brief. Skill may prompt for more detail since the brief is sparse.

### AD7: Rule 6 — Empty arg, single PRD in CWD → Mode A
- **Setup:** Exactly one `.md` file (e.g., `prd.md`) in CWD
- **Prompt:** `/mega-sdd:generate-intent`
- **Expect:** Skill auto-detects the candidate, confirms with user, then Mode A on confirmation

### AD8: Rule 6 — Empty arg, multiple candidates → prompt
- **Setup:** CWD has `prd.md`, `seed-PRD.md`, and `notes.md`
- **Prompt:** `/mega-sdd:generate-intent`
- **Expect:** Skill prompts user to pick which to use as Mode A input, or offers Mode B brief input

### AD9: Edge case — Quoted single word
- **Prompt:** `/mega-sdd:generate-intent "buildTodoCLI"`
- **Expect:** Mode B (Rule 4 matches: wrapped in quotes); does NOT treat as path

### AD10: Edge case — Flag + positional
- **Prompt:** `/mega-sdd:generate-intent --from-prompt "build X" ./prd.md`
- **Expect:** Mode B (Rule 1 wins); skill warns `"--from-prompt set; ignoring positional ./prd.md. Provide just the brief or just a path, not both."`

## Pass criteria (Mode auto-detect)

All 10 cases above invoke the correct mode per the rule table. No false positives where a path-looking string opens Q&A, or a brief gets treated as a file path. Ambiguous cases (AD3, AD8) prompt the user; do not silently proceed.
