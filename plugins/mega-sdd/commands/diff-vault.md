---
description: Diff a vault against a new PRD revision and produce a structured change report (added / changed / removed / OQ delta).
argument-hint: [path/to/old-vault] [path/to/new-prd]
---

Invoke the `mega-sdd:diff-vault` skill via the Skill tool to compare an existing vault against a revised PRD/BRD.

User arguments (old vault path, new PRD path, output report path): $ARGUMENTS

Follow the skill exactly:
- Load the existing vault and read the new PRD fully.
- Map differences across all 7 docs: added entities/flows/decisions, changed semantics, removed scope, new/closed Open Questions.
- Produce a `VAULT-DIFF.md` report grouped per doc with cited evidence from the new PRD.
- Never silently mutate the existing vault — diff is read-only by default.
