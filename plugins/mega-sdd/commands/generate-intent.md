---
description: Generate a 7-file SDD intent vault from PRD/BRD/Figma OR free-text brief. Anti-hallucination guarantees.
argument-hint: [path-to-prd.md OR --from-prompt "free-text brief"]
---

Invoke the `mega-sdd:generate-intent` skill via the Skill tool.

User arguments: $ARGUMENTS

Mode resolution:
- If `$ARGUMENTS` starts with `--from-prompt`, run Mode B (free-text, adaptive Q&A)
- If `$ARGUMENTS` is a path to a .md / .pdf file, run Mode A (structured parse)
- If `$ARGUMENTS` is empty, smart auto-detect: scan CWD for `prd.md`, `seed-PRD.md`, or `*.md` PRD candidates. If exactly one found, confirm with user. Otherwise prompt for path or free-text input.

Follow `skills/generate-intent/SKILL.md` invocation modes exactly. Output goes to `docs/mega-sdd/vaults/<auto-named>/` unless user overrides via `--out=<path>`.

Hard rails:
- Anti-hallucination: every claim cites source; ambiguities → Open Questions.
- Language: vault language matches input PRD language.
- Halt on critical gaps; do not invent.
