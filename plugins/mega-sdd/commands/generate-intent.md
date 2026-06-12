---
description: Generate a 7-file SDD intent vault from PRD/BRD/Figma OR free-text brief. Anti-hallucination guarantees.
argument-hint: '[<prd-path> | --from-prompt "<brief>" | --kb=<path>] [--scan=<path>|--greenfield] [--scope=<id>] [--out=<path>] [--auto]'
---

Invoke the `mega-sdd:generate-intent` skill via the Skill tool.

User arguments: $ARGUMENTS

Mode resolution (auto-detect per `skills/generate-intent/SKILL.md` §Detection rules):

- `--from-prompt` flag present → Mode B (explicit override)
- Positional arg resolves to existing file → Mode A
- Positional arg has `.md` / `.pdf` / `.docx` extension → Mode A (warn if file missing)
- Positional arg has whitespace, quotes, or no path separator → Mode B (free-text)
- No positional arg → CWD scan for PRD candidates; confirm Mode A on single hit, else prompt

The user typically does NOT need `--from-prompt`; just type the brief in quotes or the path. Flag is for explicit control.

Follow `skills/generate-intent/SKILL.md` invocation modes exactly. Output goes to `.mega-sdd/vaults/<auto-named>/` (canonical per `plugins/mega-sdd/references/paths.md`) unless user overrides via `--out=<path>`. Legacy `docs/mega-sdd/vaults/<auto-named>/` only honored when legacy layout already exists on disk.

Mode B (KB sub-mode):
- `--kb=<path>` reads KB as ANALYSIS INPUT (not 1:1 mirror)
- Tier-aware routing per claim's `[LOCKED]/[INTENT]/[ARTIFACT]` mutability marker (see `skills/generate-intent/SKILL.md` §Mode B routing table)
- Reads `<kb>/99-rebuild-architecture/data-mutation-policy.md` for ERD freedom
- Vault `02-architecture.md` uses rebuild-proposed shape; only `[LOCKED]` fields retain legacy shape verbatim
- Pre-v1.4 KBs without tier markers → all claims treated as `[INTENT]` (safe middle-ground)

Hard rails:
- Anti-hallucination: every claim cites source; ambiguities → Open Questions.
- Language: vault language matches input PRD language.
- Halt on critical gaps; do not invent.

## Flag combinations

| Flag combo | Behavior |
|---|---|
| (no flags, PRD has scopes block, 1 scope) | Silent → single-vault behavior |
| (no flags, PRD has scopes block, ≥2 scopes) | Interactive picker fires |
| (no flags, PRD lacks scopes block) | Retrofit bridge fires |
| `--scope=<id>` (valid id in PRD) | Silent → scoped vault |
| `--scope=<id>` (invalid id) | Halt `scope_not_declared_in_prd` |
| `--scope=all` | Legacy single-vault behavior + warning |
| `--greenfield` + scopes block | Warning (scopes ignored); stack-agnostic single vault |
| `--scope=<id>` + `--kb=<path>` | Multi-scope legacy rebuild: KB intent × target scaffold × scope filter |
| `--scope=<id>` + `--scan=<map>` + `--kb=<path>` | Full composition: pack-aware, mutability-tier-routed, scope-filtered vault |
| `--auto` + memory hit | Silent default scope from memory; no picker prompt |
