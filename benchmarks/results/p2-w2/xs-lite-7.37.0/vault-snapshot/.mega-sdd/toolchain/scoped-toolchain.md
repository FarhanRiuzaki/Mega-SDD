# Scoped toolchain override (run-code-gates `--pack=`)

The detected toolchain runs `npx prettier --check .` / `npx prettier --write .`
repo-wide. This repo's baseline is not prettier-clean, so the repo-wide check
always fails and the fix rewrites files outside every unit's `target_files`
(observed on U-001: 62 unrelated files, incl. `pnpm-lock.yaml` and the PRD).

This override keeps every check but scopes format + lint to the bolt's own diff
(`$RCG_BASE..$RCG_HEAD`, exported by run-code-gates.sh), limited to the repo's own
`pnpm format` / `pnpm lint` scope (`src/**/*.{ts,tsx,js,jsx}`). Typecheck stays
project-wide. An empty diff is a pass (nothing of the bolt's to judge).

Kept outside `.mega-sdd/packs/` on purpose so the framework-pack resolver never
treats it as (or lets it shadow) the active `next` pack.

## Toolchain

```yaml
format_check_cmd: F=$(git diff --name-only --diff-filter=ACMR "$RCG_BASE" "$RCG_HEAD" -- 'src/*.ts' 'src/*.tsx' 'src/*.js' 'src/*.jsx'); [ -z "$F" ] || printf '%s\n' "$F" | tr '\n' '\0' | xargs -0 npx prettier --check
format_fix_cmd: F=$(git diff --name-only --diff-filter=ACMR "$RCG_BASE" "$RCG_HEAD" -- 'src/*.ts' 'src/*.tsx' 'src/*.js' 'src/*.jsx'); [ -z "$F" ] || printf '%s\n' "$F" | tr '\n' '\0' | xargs -0 npx prettier --write
lint_cmd: F=$(git diff --name-only --diff-filter=ACMR "$RCG_BASE" "$RCG_HEAD" -- 'src/*.ts' 'src/*.tsx' 'src/*.js' 'src/*.jsx'); [ -z "$F" ] || printf '%s\n' "$F" | tr '\n' '\0' | xargs -0 npx eslint
typecheck_cmd: npx tsc --noEmit
```
