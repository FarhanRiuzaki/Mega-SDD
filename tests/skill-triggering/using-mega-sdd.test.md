# using-mega-sdd Triggering Test

Manual-run test fixture. Open a fresh Claude Code session in a dir matching trigger criteria, then paste each `Prompt` line below. Expected behavior described inline.

## Trigger cases (must invoke using-mega-sdd or downstream skill)

### Case T1: Explicit slash command
- **Prompt:** `/mega-sdd:generate-intent ./prd.md`
- **Expect:** Skill tool call with `generate-intent` skill invoked

### Case T2: SDD keyword
- **Prompt:** `Tolong spec out fitur ini buat dev`
- **Expect:** Skill tool call with `generate-intent` or `orchestrate-flow`

### Case T3: CWD signal only
- **Setup:** Run from a dir containing `docs/mega-sdd/`
- **Prompt:** `What's next?`
- **Expect:** Hook injects anchor; agent suggests running `orchestrate-flow`

### Case T4: Indonesian variant
- **Prompt:** `pecah PRD ini buat AI dev`
- **Expect:** Skill tool call with `generate-intent`

## Non-trigger cases (must NOT invoke mega-sdd)

### Case NT1: Casual question
- **Prompt:** `What's the difference between TypeScript and JavaScript?`
- **Expect:** Direct answer, no skill invocation

### Case NT2: Unrelated debugging
- **Prompt:** `My React component is rendering twice, help debug`
- **Expect:** Investigation via Read/Grep, no mega-sdd skill

### Case NT3: General architecture
- **Prompt:** `How should I structure a microservices project?`
- **Expect:** Discussion, no skill (no specific PRD/vault attached)

## Pass criteria

All T1-T4 invoke a mega-sdd skill. None of NT1-NT3 invokes one.
