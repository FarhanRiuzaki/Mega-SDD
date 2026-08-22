# Headless / CI recipe — spec-gated pipeline in automation

How to run mega-sdd gates in CI (GitHub Actions / GitLab / any runner) and in headless `claude -p`. The plugin needs no re-architecture for this: it is a filesystem plugin the Agent SDK / claude-code-action loads as-is.

## The two CI surfaces (know which one you're on)

| Surface | Hooks fire? | AskUserQuestion? | Use for |
|---|---|---|---|
| `claude -p "<prompt>"` (or claude-code-action) | YES | NO — pass `--auto` on every mega-sdd invocation | full pipeline phases, drift checks |
| `claude -p --bare` | **NO — hook gates are bypassed** | NO | nothing mega-sdd-gated; if you must use it, gate with the scripts below |
| plain shell step (no Claude) | n/a | n/a | deterministic gate checks via `scripts/` — the CI-stable surface |

**Rule of thumb:** decisions belong to Claude phases with `--auto` (they QUEUE, never prompt); pass/fail belongs to script steps (exit codes).

## Recipe 1 — PR drift gate (spec-gated PR bot)

```yaml
# .github/workflows/megasdd-drift.yml (sketch)
- uses: anthropics/claude-code-action@v1
  with:
    prompt: "use the mega-sdd detect-drift skill: detect-drift --auto"   # findings queue to PENDING-SYNC.md; report at <vault>/DRIFT-REPORT.md
- name: Gate on binding state (deterministic)
  run: |
    bash plugins/mega-sdd/scripts/validate-handoff-binding-units.sh --cwd="$PWD" --quiet
    # exit 0 = no unresolved CONFLICT blocking units; exit 1 = gate closed → fail the job
```

## Recipe 2 — sync on merge to main

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    prompt: "/mega-sdd:sync --auto"   # one confirmation is skipped under -p; decisions queue
- name: Fail if sync left blocking conflicts
  run: |
    ! grep -q '^- \[ \] CONFLICT-' .mega-sdd/vaults/*/PENDING-SYNC.md 2>/dev/null
```

## Recipe 3 — pure-script gate (no Claude tokens; survives --bare)

```bash
bash plugins/mega-sdd/scripts/validate-handoff-binding-units.sh --cwd="$PWD" --quiet || exit 1
bash plugins/mega-sdd/scripts/compute-unit-staleness.sh --vault=.mega-sdd/vaults/<slug> | grep -q 'stale=0' || exit 1
```

## CI environment checklist

- `--auto` on EVERY mega-sdd invocation (interactive steps otherwise hang the runner; every phase has an `--auto` path — decisions queue to PENDING-SYNC.md / the OQ roll-up).
- git identity set (`user.name`/`user.email`) when the job runs `execute-bolts` (bolts commit); read-only gates (drift, binding validation) need none.
- `python3` on the runner (hooks + validators use it; the moat additionally fails CLOSED without it — see `hooks/pre-tool-use` fallback — but CI should just install it).
- Worktree runners: all probes are worktree-safe (`git rev-parse --git-path …`); nothing assumes `.git` is a directory.

## What NOT to do

- Don't run gated work under `--bare` (hooks off = prose-only enforcement). If a vendor pipeline forces `--bare`, add Recipe 3's script gate as a separate step — scripts survive every runtime (plugin doctrine: gates as scripts).
- Don't auto-resolve PENDING-SYNC.md in CI — direction calls are human-only (the moat). CI's job is to FAIL LOUDLY while the queue has blocking items.
