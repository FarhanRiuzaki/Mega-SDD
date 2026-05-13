# scan-codebase Triggering Test

## Trigger cases

### S1: Explicit
- **Prompt:** `/mega-sdd:scan-codebase`
- **Expect:** Skill invoked, scan begins with CWD

### S2: Natural prompt
- **Prompt:** `siapkan context codebase buat AI dev`
- **Expect:** Skill invoked

### S3: orchestrate-flow auto-route
- **Setup:** CWD has `.git`, no `codebase-map.md`, vault exists
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes scan-codebase as next step

## Behavior checks

### B1: Output presence
- After invocation: `codebase-map.md` exists in repo root.

### B2: Schema compliance
- Output has all 6 required sections per `codebase-map-schema.md`.
- Frontmatter has `generated_by: mega-sdd:scan-codebase`.

### B3: Anti-hallucination
- Test on a repo with NO routes: section reads "None detected", not invented endpoints.

## Pass criteria

All triggers fire. Output exists, schema-compliant, no hallucinations.
