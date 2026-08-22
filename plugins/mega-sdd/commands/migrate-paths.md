---
description: "Maintenance one-timer — migrate legacy scattered outputs to the canonical .mega-sdd/ layout (git mv + reference rewrite); dry-run preview; idempotent."
argument-hint: "[--dry-run] [--from=auto|<layout>] [--to=new] [--auto-confirm]"
---

Migrate mega-sdd outputs to the canonical layout per `plugins/mega-sdd/references/paths.md`.

User arguments: $ARGUMENTS

The destructive core — path moves (`git mv` / `mv`), the per-vault `<vault>/.mega-sdd/` → `<vault>/.internal/` rename, and the `sed` reference rewrites in `vault.json` / `binding.md` — is a single **vetted script**: `plugins/mega-sdd/scripts/migrate-paths.sh`. This command owns the **interactive confirm gate** and surfaces the **dirty-tree HALT**; the script self-guards (idempotent no-op, dirty-tree refusal, target-exists conflict) so it stays safe even under `--auto-confirm`.

Flag parsing:
- `--dry-run` — Preview moves without writing (forwarded to the script)
- `--from=auto|legacy|mixed` — Source layout (default: auto-detect). `--from=legacy` confirms intent to migrate into a pre-existing, non-empty `.mega-sdd/vaults/`.
- `--to=new` — Target layout (default: new; canonical `.mega-sdd/` consolidation). The reverse `--to=legacy` rollback is **NOT YET IMPLEMENTED** (manual file moves required — see the rollback note below); it is intentionally omitted from the argument-hint until the reverse direction ships.
- `--auto-confirm` — Skip the per-move AskUserQuestion (DANGEROUS without `--dry-run` first). The script's dirty-tree guard remains the backstop.

## Procedure

### Step 1 — Pre-flight: dirty-tree HALT

If the working tree has uncommitted changes (`git status --porcelain` non-empty), HALT and ask the user to commit or stash first. The script enforces the same refusal (exit 2), but surface it here so the user resolves it before reaching the confirm gate.

### Step 2 — Preview (dry-run)

Run the script in preview mode to produce the migration plan (this mutates nothing):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/migrate-paths.sh" --dry-run --from=<from> --cwd="$(pwd)"
```

Show its output (the per-artifact `FROM → TO` plan, reference rewrites, config creation) in chat. If the user passed `--dry-run` explicitly → STOP here (preview only).

### Step 3 — Confirm (AskUserQuestion)

Unless `--auto-confirm` is set, ask via AskUserQuestion:

```
Proposed migration: <N> vaults + KB / codebase-map moved to ./.mega-sdd/

Options:
  1. Proceed (git mv where in git; otherwise mv)
  2. Dry-run preview only (no changes)
  3. Cancel
```

### Step 4 — Execute

On **Proceed** (or when `--auto-confirm` is set), run the script for real:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/migrate-paths.sh" --from=<from> --cwd="$(pwd)"
```

The script performs, in order: per-vault moves (`git mv` → history preserved; empty legacy parents tidied), the `<vault>/.mega-sdd/` → `<vault>/.internal/` rename on the post-move location, `vault.json` / `binding.md` reference rewrites (`.bak` backups cleaned on success), `config.yaml` creation (clobber-guarded), verification, and a `migration-log.md` append. Relay the script's summary to the user.

### Rollback

If the migration was committed to git: `git revert HEAD`. The forward script does not implement `--to=legacy`; a manual reverse move is required until that direction ships.

## Hard rails (anti-data-loss) — enforced by the script

- **Idempotent**: re-running on an already-migrated project is a no-op — the script detects the canonical layout and exits 0 **before** the dirty-tree guard (so a post-migration, pre-commit re-run does not falsely trip on the staged renames).
- **git mv in git repos** — file history preserved (staged `R old -> new`); plain `mv` fallback outside git.
- **`.bak` backups** for every `sed` in-place edit, removed after success.
- **Dirty-tree refusal**: the script refuses to mutate an uncommitted tree unless `--dry-run` (exit 2) — the safety backstop for `--auto-confirm`.
- **Target-exists conflict**: a non-empty `.mega-sdd/vaults/` under `--from=auto` is refused (exit 1); pass `--from=legacy` to confirm overwrite intent.
- **config.yaml clobber-guard**: an existing user `config.yaml` is never overwritten.

## Halt conditions

- Working tree dirty (uncommitted changes) → command HALTs (Step 1); the script also refuses (exit 2).
- Target path exists AND non-empty AND `--from=auto` → script exits 1; re-run with explicit `--from=legacy`.
- Reference-update or move failure → the script aborts via `set -e` (non-zero exit); resolve the named file manually.

## See also

- `plugins/mega-sdd/scripts/migrate-paths.sh` — the vetted destructive core (covered by `tests/migrate-paths/test-migrate-paths.sh`)
- `plugins/mega-sdd/references/paths.md` — canonical layout definition
