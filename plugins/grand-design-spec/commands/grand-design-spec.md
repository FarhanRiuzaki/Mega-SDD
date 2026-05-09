---
description: Convert PRD/BRD (+ optional Figma) into a 7-file dev handoff vault with anti-hallucination guarantees.
argument-hint: [path/to/prd.pdf] [optional figma URL]
---

Invoke the `grand-design-spec:grand-design-spec` skill via the Skill tool to generate a 7-file vault from the user's PRD/BRD inputs.

User arguments (PRD path, Figma URL, output folder, etc.) if provided: $ARGUMENTS

Follow the skill exactly:
- Ask for output folder, IMPLEMENTATION_MODE (new/existing), OUTPUT_MODE (compact/full), and PRD_STATUS before generating.
- Read every input fully — never skim, never invent requirements.
- Every claim must cite its source; every gap becomes an Open Question (P1/P2/P3).
- Write all 7 files (00-index through 06-constraints) plus `vault.json` manifest to the resolved OUTPUT_DIR.
- Surface top P1 Open Questions as blockers in the final summary.
