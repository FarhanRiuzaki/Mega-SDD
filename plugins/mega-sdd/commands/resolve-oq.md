---
description: Interactively resolve Open Questions in an existing vault and write answers back into the right docs + vault.json.
argument-hint: [path/to/vault] [optional OQ tag like OQ-FLOWS-3]
---

Invoke the `mega-sdd:resolve-oq` skill via the Skill tool to walk through unresolved Open Questions in a generated vault.

User arguments (vault path, specific OQ tag, priority filter): $ARGUMENTS

Follow the skill exactly:
- Read `00-index.md` OQ roll-up + `vault.json` to enumerate unresolved OQs.
- For each OQ, ask the user the question with concise context; capture the answer verbatim.
- Land the answer in the correct doc(s) — single landing for scoped OQs, cross-cutting landing pattern for OQs spanning multiple docs.
- Update `vault.json` resolved/unresolved counts and last_updated timestamps.
- Refuse to overwrite a LOCKED vault unless user explicitly confirms unlock.
