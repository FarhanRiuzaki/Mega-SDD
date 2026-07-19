---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[vault-path] [--module=<id>] [--mark-dod=<module>] [--format=table|json]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:list-modules` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Display module progress + DoD status for the current vault.

User arguments: $ARGUMENTS

The read-only rollup — per-module unit completion (from `bolt-outcomes.json`), DoD marked-count, `blocked_by` resolution, and status label — is a single script: `plugins/mega-sdd/scripts/list-modules.sh`. This command runs it for the display, and owns the **interactive `--mark-dod` flow** (which mutates `modules.yaml` and may re-run DoD test commands — neither belongs in the read-only script).

## Procedure

### Step 1 — Display the rollup

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-modules.sh" $ARGUMENTS --cwd="$(pwd)"
```

The script resolves the vault (positional `[vault-path]`, else auto-probe `.mega-sdd/vaults/` then legacy `docs/mega-sdd/vaults/`), reads `_meta/modules.yaml` (or `modules.yaml.auto`, or falls back to a single implicit `M-default`), and emits per module: ID, name, status (`not-started` / `in-progress` / `units-complete` / `completed`), units `completed/total`, DoD `done/total`, priority, and `blocked_by` resolution — plus an `M-unassigned` warning for units whose `module:` matches no defined module, and the deterministic `Unblocked & actionable:` set. `--format=json` emits the same structured. Relay the output.

> When `modules.yaml` is absent but `modules.yaml.auto` exists, suggest the user rename it to lock the grouping in (`mv _meta/modules.yaml.auto _meta/modules.yaml` — generate-units Step 4.5 auto-derivation produced it).

### Step 2 — `--mark-dod=<module-id>` interactive flow (this command's job)

The script's DoD column reflects the **marked** state only (a `dod:` item written as `[x] …` in `modules.yaml`). The fresh, canonical form is a plain string = unchecked. To mark items, run this flow (NOT the script — it mutates state and runs commands):

1. Read the module's `dod:` checklist from `_meta/modules.yaml` (halt with the valid module IDs if the id is unknown).
2. For each **unmarked** item, ask via `AskUserQuestion`: *"DoD item: `<text>` — mark passing?"* — options: (1) Mark passing, (2) Skip, (3) Run associated test command (when the item text looks like a command, e.g. `phpunit …`).
3. On **Run** → invoke the command via Bash; exit code is the verdict (deterministic pass/fail — never "looks done"). On success, mark passing.
4. On **Mark passing** → rewrite that `dod:` item in `modules.yaml` to `[x] <text>`; log the outcome to memory (`outcomes.md`).
5. After review, if **all** DoD items are marked AND all units are complete → the module is `completed`; congratulate and suggest the next module. (Re-run Step 1 to show the updated counts.)

### Step 3 — Hand-off (judgment, keyed on the script output)

- Some module is in the `Unblocked & actionable:` set → suggest a specific `/mega-sdd:execute-bolts --module=<id>`.
- All remaining modules are blocked → suggest the unblocking path (complete the blocking module / resolve an OQ).
- All modules complete → suggest `/mega-sdd:detect-drift` for periodic drift verification.

## Anti-halu rails

- Module status is derived from **objective signals** — unit membership from each unit's `module:` frontmatter, completion from `<vault>/.memory/bolt-outcomes.json` (`status: completed` / `halted_*`), DoD marked-state from `modules.yaml` — **never inferred**.
- **DoD test commands are never auto-marked from the read-only display.** They are only re-run in the `--mark-dod` flow above, via Bash, where the exit code (not an LLM guess) decides pass/fail.
- `blocked_by` is resolved against each blocking module's computed status; a blocker is "ok" only when that module is itself `completed`.

## Halt conditions

- Vault not found / `vault.json` corrupt → script exits **1**; relay and stop.
- `--module=<id>` / `--mark-dod=<id>` names an unknown module → halt with the list of valid module IDs (the script exits **2** on an unknown `--module`).
- A `--mark-dod` test command fails → do **not** auto-mark; the user resolves it manually.

## References

- `plugins/mega-sdd/scripts/list-modules.sh` — the read-only rollup core (covered by `tests/list-modules/test-list-modules.sh`)
- `plugins/mega-sdd/skills/generate-units/references/modules-schema.md` — module schema (`dod`, `blocked_by`, `priority`)
- `plugins/mega-sdd/skills/memory/SKILL.md` — `bolt-outcomes.json` storage
