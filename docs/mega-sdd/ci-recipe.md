# Headless / CI recipe — spec-gated pipeline in automation

How to run mega-sdd gates in CI (GitHub Actions / GitLab / any runner) and in headless `claude -p`. The plugin needs no re-architecture for this: it is a filesystem plugin the Agent SDK / claude-code-action loads as-is.

The script paths below use `$MEGA_SDD` for the plugin root on the runner (for a checkout of this marketplace repo: `MEGA_SDD=plugins/mega-sdd`).

## The two CI surfaces (know which one you're on)

| Surface | Hooks fire? | AskUserQuestion? | Use for |
|---|---|---|---|
| `claude -p "<prompt>"` (or claude-code-action) | YES | NO — pass `--auto` on every mega-sdd invocation | full pipeline phases, drift checks |
| `claude -p --bare` | **NO — hook gates are bypassed** | NO | nothing mega-sdd-gated; if you must use it, gate with the scripts below |
| plain shell step (no Claude) | n/a | n/a | deterministic gate checks via `scripts/` — the CI-stable surface |

**Rule of thumb:** decisions belong to Claude phases with `--auto` (they QUEUE, never prompt); pass/fail belongs to script steps (exit codes).

## The CONFLICT gate is per unit — always pass `--units=all`

Binding verdicts live per unit in `<vault>/bolts/U-XXX/binding.json`, and `scripts/validate-handoff-binding-units.sh` blocks only on the units it is told about. Without `--units=`, an open per-unit CONFLICT is reported as an advisory extra (`conflict_unit_unresolved`) and the script still exits 0, so a CI gate written that way passes with open CONFLICTs. `--units=all` lists every unit of every vault: any open CONFLICT is a blocking drop and the script exits 1. A layout-2 `binding.md` (read-only in 9.0) is checked either way.

`validate-handoff-binding-units.sh --units=all` gates on the verdicts already recorded. To re-verdict every unit against the checked-out code first, run the full audit (Recipe 4, `scripts/rebind-units.sh --units=all`).

## Recipe 1 — PR drift gate (spec-gated PR bot)

```yaml
# .github/workflows/megasdd-drift.yml (sketch)
- uses: anthropics/claude-code-action@v1
  with:
    prompt: "use the mega-sdd detect-drift skill: detect-drift --auto"   # findings queue to PENDING-SYNC.md; report at <vault>/DRIFT-REPORT.md
- name: Gate on binding state (deterministic)
  run: |
    bash "$MEGA_SDD/scripts/validate-handoff-binding-units.sh" --cwd="$PWD" --units=all --quiet
    # exit 0 = no unresolved CONFLICT in any unit; exit 1 = gate closed → fail the job
```

## Recipe 2 — sync on merge to main

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    prompt: "/mega-sdd:sync --auto"   # one confirmation is skipped under -p; decisions queue
- name: Fail if sync left blocking conflicts
  run: |
    # The gate reads bolts/U-*/binding.json, never the PENDING-SYNC.md queue.
    bash "$MEGA_SDD/scripts/validate-handoff-binding-units.sh" --cwd="$PWD" --units=all --quiet
    # Optional, log only: the queued CONFLICT rows (layout-3 `- [ ] C-U004-01 …`, legacy `- [ ] CONFLICT-N`).
    grep -n '^- \[ \] C' .mega-sdd/vaults/*/PENDING-SYNC.md 2>/dev/null || true
```

`sync` re-binds only the units whose files changed. Units outside that set keep their recorded verdicts, and `--units=all` still blocks on any open CONFLICT they carry. For a full re-verdict inside the Claude step, use `/mega-sdd:sync --full-bind --auto`.

## Recipe 3 — pure-script gate (no Claude tokens; survives --bare)

```bash
bash "$MEGA_SDD/scripts/validate-handoff-binding-units.sh" --cwd="$PWD" --units=all --quiet || exit 1
# compute-unit-staleness.sh prints JSON ({units[].status, counts}) and always exits 0 — gate on counts.stale
bash "$MEGA_SDD/scripts/compute-unit-staleness.sh" --vault=.mega-sdd/vaults/<slug> \
  | python3 -c 'import json,sys; sys.exit(1 if json.load(sys.stdin)["counts"].get("stale") else 0)' || exit 1
```

## Recipe 4 — full sync audit (nightly / pre-release; no Claude tokens)

Re-verdicts every unit of every layout-3 vault against the checked-out code with the same writers the JIT bind uses, then gates. This is the script form of `/mega-sdd:sync --full-bind`. A pre-9.0 vault without `context.md` (layout-2 `vault.md`, or the legacy 7-file shape) is read-only in 9.0 and is not re-bound in place: migrate it first (`/mega-sdd:migrate-paths --vault-layout=3`, which ends with this same full re-bind). The final gate still reads its `binding.md`.

```bash
for v in .mega-sdd/vaults/*/; do
  [ -d "${v}units" ] || continue
  [ -f "${v}context.md" ] || { echo "skip ${v%/}: not layout-3 (migrate-paths --vault-layout=3 first)" >&2; continue; }
  rc=0; bash "$MEGA_SDD/scripts/rebind-units.sh" --cwd="$PWD" --vault="${v%/}" --units=all || rc=$?
  # prints one JSON line (affected, conflicts, oq, text_pending, gate)
  # exit 0 = no units · 4 = re-bound (read `gate`) · 2 = usage/unreadable input · 3 = claim derivation or a binding writer failed
  [ "$rc" -eq 0 ] || [ "$rc" -eq 4 ] || exit 1   # 2/3 fail closed, never "in sync"
done
bash "$MEGA_SDD/scripts/validate-handoff-binding-units.sh" --cwd="$PWD" --units=all --quiet || exit 1
```

What a script-only audit verdicts: `fs` claims always; `symbol` claims only when `ast-grep` is on the runner (without it they stay OQ, never CONFIRMED); `text` claims stay OQ (`text_pending`) until a Claude step runs the E3 ladder, so run `/mega-sdd:sync --full-bind --auto` when those matter. The audit rewrites `bolts/U-*/binding.json` in the runner's checkout; the job does not need to commit them.

## CI environment checklist

- `--auto` on EVERY mega-sdd invocation (interactive steps otherwise hang the runner; every phase has an `--auto` path — decisions queue to PENDING-SYNC.md / the OQ roll-up).
- `--units=all` on every `validate-handoff-binding-units.sh` gate step (see above).
- git identity set (`user.name`/`user.email`) when the job runs `execute-bolts` (bolts commit); read-only gates (drift, binding validation) need none.
- `python3` on the runner (hooks + validators use it; the moat additionally fails CLOSED without it — see `hooks/pre-tool-use` fallback — but CI should just install it). `ast-grep` for the Recipe 4 symbol verdicts.
- Worktree runners: the rebase / hooks-dir probes in `execute-bolts` and `sync` resolve via `git rev-parse --git-path …`; nothing assumes `.git` is a directory.

## What NOT to do

- Don't run gated work under `--bare` (hooks off = prose-only enforcement). If a vendor pipeline forces `--bare`, add Recipe 3's script gate as a separate step — scripts survive every runtime (plugin doctrine: gates as scripts).
- Don't auto-resolve PENDING-SYNC.md in CI — direction calls are human-only (the moat). CI's job is to FAIL LOUDLY while the queue has blocking items.
- Don't gate on `validate-handoff-binding-units.sh` without `--units=all`: per-unit CONFLICTs are then advisory and the job passes.
