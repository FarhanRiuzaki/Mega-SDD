# /mega-sdd:emit-agents-md Trigger + Behavior Test

Iter 6 Swap #4 — AGENTS.md emitter skill. Tool-agnostic interop via Linux Foundation AAIF AGENTS.md format.

## Trigger cases

### AM1: Explicit invocation
- **Setup:** vault exists at `docs/mega-sdd/vaults/<slug>/`
- **Prompt:** `/mega-sdd:emit-agents-md`
- **Expect:** Skill invoked; AGENTS.md generated at repo root with mega-sdd marker HTML comment

### AM2: Sibling mode when AGENTS.md user-authored
- **Setup:** repo has user-authored AGENTS.md WITHOUT mega-sdd marker
- **Prompt:** `/mega-sdd:emit-agents-md`
- **Expect:** AskUserQuestion offers `overwrite / append / sibling`. Default selection `sibling`. User picks `sibling`. Mega-sdd writes `AGENTS.mega-sdd.md` instead of overwriting.

### AM3: Safe regeneration (marker-based)
- **Setup:** repo has mega-sdd-generated AGENTS.md (marker present)
- **Run vault update** (e.g., resolve OQs; vault version bumps)
- **Prompt:** `/mega-sdd:emit-agents-md`
- **Expect:** Re-generation succeeds without prompt (marker-detected); AGENTS.md updated with new vault content; user-authored content above marker (if append mode) preserved unchanged. NOTE: the render is model-produced — best-effort flatten, NOT byte-idempotent (same vault may render with cosmetic wording differences); the vault stays the sole source of truth

### AM4: Conditional section omission
- **Setup:** vault is greenfield; no `05-decisions.md` ADRs yet; no detected test framework
- **Prompt:** `/mega-sdd:emit-agents-md`
- **Expect:** AGENTS.md generated WITHOUT "Key decisions" section (no ADRs to flatten) and WITHOUT "Test commands" section (no framework). NOT faked with placeholders.

## Pass criteria

All AM1-AM4 succeed per `skills/emit-agents-md/SKILL.md` Procedure. Generated AGENTS.md is human-readable, machine-readable (Continue.dev import test), and safe to regenerate (marker-detected — best-effort flatten, not byte-idempotent).
