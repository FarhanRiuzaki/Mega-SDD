---
description: Generate a 7-file SDD intent vault from PRD/BRD/Figma OR free-text brief. Anti-hallucination guarantees.
argument-hint: [path-to-prd.md OR "free-text brief" OR --from-prompt "<brief>" for explicit]
---

Invoke the `mega-sdd:generate-intent` skill via the Skill tool.

User arguments: $ARGUMENTS

Mode resolution (v1.2+ — auto-detect per `skills/generate-intent/SKILL.md` §Detection rules):

- `--from-prompt` flag present → Mode B (explicit override)
- Positional arg resolves to existing file → Mode A
- Positional arg has `.md` / `.pdf` / `.docx` extension → Mode A (warn if file missing)
- Positional arg has whitespace, quotes, or no path separator → Mode B (free-text)
- No positional arg → CWD scan for PRD candidates; confirm Mode A on single hit, else prompt

The user typically does NOT need `--from-prompt`; just type the brief in quotes or the path. Flag is for explicit control.

Follow `skills/generate-intent/SKILL.md` invocation modes exactly. Output goes to `docs/mega-sdd/vaults/<auto-named>/` unless user overrides via `--out=<path>`.

Hard rails:
- Anti-hallucination: every claim cites source; ambiguities → Open Questions.
- Language: vault language matches input PRD language.
- Halt on critical gaps; do not invent.
