# Orchestrate-Flow Routing Rules

`orchestrate-flow` inspects CWD and proposes a chain of skills based on detected state. This document specifies the decision matrix.

## CWD inspection (deterministic, in order)

1. **PRD/seed detection.** Does CWD contain `prd.md`, `seed-PRD.md`, or `*.md` PRD candidates?
2. **Vault detection.** Does CWD contain `docs/mega-sdd/vaults/*/vault.json` or `vaults/*/vault.json`?
3. **Bound-vault detection.** Same dirs but with `-bound` suffix?
4. **Units detection.** Any `units/U-*.md` files?
5. **Bolts detection.** Any `bolts/U-*/bolt-report.md`?
6. **Repo detection.** Is CWD inside a git repo? Any package manifests?
7. **Codebase-map detection.** `codebase-map.md` exists?
8. **Open Questions count.** Aggregate P0/P1 OQ count across vault files.
9. **Drift signals.** Has detect-drift been run recently?

## Decision matrix

| State (from inspection) | Proposed chain |
|---|---|
| Brief only (no vault, no PRD) | `generate-intent --from-prompt` (Q&A first) |
| PRD exists, no vault | `generate-intent <prd>` |
| Vault exists, mode=greenfield, no units | `generate-units` |
| Vault exists, mode=existing, no codebase-map | `scan-codebase` → `bind-codebase` → `generate-units` |
| Vault exists, codebase-map exists, no bound-vault | `bind-codebase` (alone if blocking; chain if clean) |
| Bound-vault exists, no units | `generate-units` |
| Units exist, some not in bolts | `execute-bolts --all` |
| (v1.1+) Vault has `squad_count: ≥2`, units exist, some not in bolts | `execute-bolts --per-squad` |
| (v1.1+) Vault has `squad_count: ≥2`, units exist, user invokes from a single-squad context (e.g., on a dev's laptop with a specific role) | Ask: "Run for which squad?" then propose `execute-bolts --squad=<answer>` |
| (v1.1+) Vault has `squad_count: ≥2` but `interfaces_count: 0` and ≥1 unit has cross-squad coupling hint in vault_source | `generate-units` (re-run, will surface `interface_ref_missing` halts as needed) |
| All units executed, no recent drift check | `detect-drift` |
| Vault has unresolved P0/P1 OQs with status != deferred | `resolve-oq` first (intent gate, before any other chain) |
| Vault has only deferred P0/P1 OQs + brownfield context | `scan-codebase` → `bind-codebase` (which auto-resolves deferred OQs) |
| New PRD revision detected (file newer than vault) | `diff-vault <new-prd>` first |

**OQ counting note (v1.1+):** When inspecting vault for P0/P1 OQ counts, distinguish:
- `pending_p0_p1_count`: OQs with `status: pending` (or status field absent) at P0/P1 priority. These gate the chain via the intent rule above.
- `deferred_p0_p1_count`: OQs with `status: deferred`. These do NOT gate; they propagate to binding phase.

## Multi-squad detection (v1.1+)

When CWD inspection finds `<vault>/_meta/squads.yaml` with ≥2 squads:

- Set `squad_count` in state snapshot to the count
- Read declared squad IDs to validate any `--squad=<id>` user input
- Adjust execute-bolts proposal:
  - Default to `--per-squad` (parallel subagent fan-out)
  - If user is running in a context that suggests single-squad focus
    (e.g., explicit `--squad=<id>` arg passed to orchestrate-flow, or
    a hint like "I'm on the FE team"), use `--squad=<id>` instead

If the count is exactly 1 (or file absent): treat as single-squad mode,
do NOT propose `--per-squad` (it would halt). Use `--all` or unit-by-unit.

If interface files exist (`<vault>/interfaces/*.md`):
- Report `interfaces_count` in state snapshot
- Don't read content (cheap inspection); just count files
- Trust execute-bolts pre-flight to validate interface lock states at run time

## Chain depth limit

Hard cap: **3 sub-skills per chain**. Beyond that, user must explicitly request next chain.

## Resume + skip

User options on chain proposal:
- **Run** — execute all proposed steps
- **Edit** — `skip step N` or `stop after step N` only
- **Cancel** — abort

## Single confirmation

User confirms ONCE before chain starts. Sub-skills run with `--auto`. Substance prompts (per-OQ choices, conflict resolutions) ALWAYS surface to human regardless of `--auto`.

## Halt-pause behavior

When a sub-skill emits a blocker YAML:
- Chain pauses (does NOT continue)
- Blocker surfaced verbatim
- User decides next: retry, fix, cancel
- Final summary lists completed/paused/skipped per step

## Greenfield vs brownfield detection

| Signals | Mode inferred |
|---|---|
| No `.git`, no package manifests | greenfield (warn if vault says existing) |
| `.git` + package manifest | brownfield (warn if vault says greenfield) |
| Vault explicit `mode:` overrides inference if user confirmed during generate-intent | — |

If detection conflicts with vault `mode:`, halt with mode-migration prompt.

## First-run dependency check

On first invocation in a session that will reach `execute-bolts`, perform pre-flight:
- If neither superpowers nor `_vendored/` is ready → halt, offer install
- Defer the check until bolt phase is actually proposed (cheap check, runs once)
