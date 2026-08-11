# bind-codebase — preflight, snapshot, scope, handoff & memory

## Contents
- Extraction-scorecard preflight (advisory)
- Halt YAML — `bind_inputs_missing`
- Codebase-map shared-snapshot reuse (Step 1)
- Scope propagation (Step 1)
- vault.json audit append (Step 6)
- Handoff emission (UNCONDITIONAL)
- Memory layer

## Extraction-scorecard preflight (advisory)

When a KB is present (legacy-rebuild lane), run the Extraction Completeness Contract check BEFORE processing KB claims so binding builds on extraction whose gaps are visible:

```bash
# Resolve $PLUGIN_ROOT to the LATEST cached version (defeats stale-version anchoring;
# see plugins/mega-sdd/references/plugin-root-resolution.md). DERIVED = this reference
# file's own absolute path truncated before /skills/.
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"

bash "$PLUGIN_ROOT/scripts/validate-extraction-scorecard.sh" --cwd="<project>" --kb-dir="<kb-dir>" --quiet
# M-05: branch on the exit code; read .mega-sdd/.extraction-scorecard-state.json ONLY on non-zero
```

Interpret the verdict (per `extract-intelligence/SKILL.md §Step 5.6`):
- **SKIP** (no scorecard — older KB, or none emitted) → proceed normally; absence is not a blocker.
- **PASS** → proceed. If the scorecard self-reports `overall_status: PARTIAL` with `[OPEN]` markers, carry those `[OPEN]`s through to `binding.md` as OQ candidates (honest gaps, not errors).
- **FAIL** (scorecard internally inconsistent, OR a PARTIAL/MISSING principle with NO `[OPEN]` markers — a hidden gap) → surface prominently in `binding.md` under `## Extraction quality (advisory)` and recommend re-running `extract-intelligence` for the failing principle. Advisory — does NOT hard-block binding.

> A blocking enforcement gate must be a deterministic validator wired to a hook — prose that says "HALT" enforces nothing. Do not add prose claiming to HALT here without a backing validator.

## Halt YAML — `bind_inputs_missing`

Emitted when a required bind input cannot be resolved deterministically, is **ambiguous**, or resolves anywhere that is **not a DIRECT CHILD** of the `<project-root>/.mega-sdd/vaults/` glob root — outside it, or nested one level too deep inside it (SKILL.md §Inputs Step 0 + §Halt conditions). bind never prompts on any of these branches, so this blocker is the *only* outcome — never `vaults[0]`, never a guess. After emit the bind stops; no `binding.md`, no `binding.json`, no `bound/`. The handoff YAML is STILL emitted before stopping — on EVERY invocation, chain or standalone (§Handoff emission) — with `status: halted`, this blocker in `blockers:`, and empty `artifacts:`. A Step-0 stop must never look like a completion to the chain, and on a standalone run the handoff is the only place the re-invocation command survives.

Two discriminators, each a closed set — `missing` says WHICH input, `reason` says WHY:

- `details.missing`: `vault` | `codebase_map` | `vault_index`
- `details.reason`: `not_found` | `vault_ambiguous` | `vault_outside_glob_root` | `malformed`

`details.candidates` is REQUIRED when `reason: vault_ambiguous` (every candidate path, so the caller can re-invoke with an explicit `--vault=`) and omitted otherwise.

```yaml
blocker:
  type: bind_inputs_missing
  emitted_at: <ISO8601>
  emitted_by: bind-codebase
  details:
    missing: vault                     # vault | codebase_map | vault_index
    reason: vault_ambiguous            # not_found | vault_ambiguous | vault_outside_glob_root | malformed
    resolved_from: "<--vault arg | derive-state probes.vaults[] | CWD probe>"
    candidates:                        # REQUIRED for vault_ambiguous; omit otherwise
      - <absolute path to candidate vault 1>
      - <absolute path to candidate vault 2>
    context: "<e.g. 'Step 0: 2 vaults under .mega-sdd/vaults/ and no --vault/positional arg'>"
  next_action: "Re-invoke with an explicit vault: bind-codebase <vault> [--auto]"
  # next_action per reason:
  #   vault_ambiguous          → re-invoke with an explicit --vault=<path>/positional (list candidates above)
  #   not_found                → run generate-intent (no vault yet), or pass --vault=<path>
  #   vault_outside_glob_root  → run /mega-sdd:migrate-paths (legacy layout → canonical .mega-sdd/vaults/)
  #   codebase_map (missing)   → run scan-codebase first
  #   vault_index (malformed)  → repair <vault>/00-index.md / vault.json, then re-bind
```

The `vault_outside_glob_root` branch is a **moat-visibility** rail, not a tidiness rule: `validate-handoff-binding-units.sh` scans four non-recursive globs rooted at `<cwd>/.mega-sdd/vaults/` — `vaults/binding.md`, `vaults/binding-*.md`, `vaults/*/binding.md`, `vaults/*/binding-*.md` — whose deepest reach is that single `*` level. A `binding.md` outside the root, OR under a vault nested deeper than one level inside it, is invisible to the validator and the gate reports PASS with an active CONFLICT. The blocker's name is historical; its condition is "not a direct child", which is strictly tighter than "outside". Absence of a vault is separately hook-blocked upstream (`validate-preflight.sh` FATAL `binding_input_vault_missing`); this blocker exists for the ambiguity and location cases that hook does not see.

## Codebase-map shared-snapshot reuse (Step 1)

> **`--express` override:** the express lane reads NO codebase-map, so this whole snapshot/currency check is SKIPPED and the provenance is FIXED at `"no-snapshot"` (`express-bind.md §Frontmatter + audit recording`) — never `"snapshot-verified"` on an express bind, even when a fresh snapshot exists on disk (this binding attests nothing about a map it did not read).

Check `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` (per `plugins/mega-sdd/references/shared-snapshot-schema.md`). Parse and compare its `codebase_map_sha256` to the just-read codebase-map's actual sha256, THEN check map currency against the repo (S4 — the sha256 alone proves only that the map FILE is unchanged, not that the CODE hasn't moved):
- **Currency check**: read the map frontmatter's `last_scanned_commit`. If `git rev-parse HEAD` resolves and differs from the stamp → the code moved since the scan; provenance is `"snapshot-stale"` REGARDLESS of the sha256 match, and the bind surfaces a warning recommending `/mega-sdd:sync` (or `scan-codebase --changed-only`) first. Stamp missing / literal `HEAD` / not a git repo → currency is UNKNOWN: never stamp `snapshot-verified`; use `"no-snapshot"` semantics for the provenance and note why.
- **MATCH + current** → record `binding_metadata.codebase_map_provenance = "snapshot-verified"`. Downstream consumers can trust the map is current; orchestrate-flow may remove scan-codebase from the chain when verified AND source files unchanged.
- **MISMATCH** → `"snapshot-stale"`; suggest re-running scan-codebase before the next bind.
- **Absent** → `"no-snapshot"`.
- **Map failed writer-provenance** (SKILL Step 1's external-map check: `.mega-sdd/.codebase-map-state.json` records `status: FAIL` or a `codebase_map_fm_missing` issue — the map was authored outside mega-sdd) → `"unverified-external"`, OVERRIDING any sha256/currency match (a map with no trustworthy `generated_by`/`engine` frontmatter can never attest freshness). Surface the WARN keterangan from SKILL Step 1; the bind still proceeds — binding precision degrades to binary classification (no field-level diff without a trusted `precision_tier`).

Snapshot reuse is a freshness attestation, NOT a parsing shortcut. Binding correctness is unchanged whether reuse confirms or rejects.

## Scope propagation (Step 1)

When `vault.json` has a `scope` field (multi-scope vault), persist `scope_metadata` to the `binding.md` header and emit a `scope:` block in the handoff YAML. If `scope_metadata.prd_sections_used` lists sections → constrain claim validation to those sections (skip other scopes' claims). No scope (legacy single-vault) → proceed as before. Header gains `**Scope**: <name> (<id>)` when applicable.

## vault.json audit append (Step 6)

The `bind` event is appended by **running** `derive-vault-json.sh --vault <vault> --event '{"event":"bind","at":"<iso>",…}'` — the script acquires and releases the `<vault>/vault.json.lock` itself (per `generate-intent/references/vault-contract.md §Concurrency contract`) and re-derives the structural mirror from the vault markdown in the same pass. Exit 4 (lock held after backoff) → surface the `memory_in_use` halt. Never append to vault.json by hand — concurrent-tab hand-writes are exactly the corruption the script-held lock closes.

## Handoff emission (UNCONDITIONAL)

**Emitted at the end of output on EVERY invocation** — chain (`--auto`, typically
`orchestrate-flow --deep` / `/mega-sdd`) *and* standalone. It is deliberately NOT `--auto`-gated:
a direct `bind-codebase <vault>` run never injects `--auto` (a standalone dispatch
adds no flags), and this skill is non-interactive by contract (`SKILL.md` §Anti-hallucination
rails) — so the handoff is the ONLY channel by which the caller learns `next_action`,
`artifacts[]` and `blockers[]`. Gating it on `--auto` would make a standalone run emit nothing at
all, and that is exactly the defect the scan side already closed (`scan-codebase/references/halts-flags-handoff.md`
§Handoff YAML emission). It matters most on the two branches a human most needs routed: a
`bind_conflict` stop whose only exit is `resolve-oq`, and a Step-0 `bind_inputs_missing` stop
whose only exit is a re-invocation with an explicit vault. Template below is the OPERATIVE spec
(`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: <ISO8601>
  status: completed | paused | halted
  artifacts:
    - <absolute path to binding.md>
    - <absolute path to binding.json>
    - <absolute path to <vault>/bound/>   # only if no CONFLICTs
  next_action:
    suggested_skill: mega-sdd:generate-units   # completed
    # OR mega-sdd:resolve-oq                    # halted on conflict
    # suggested_args for the completed → generate-units path are STATE-AWARE —
    # they key on WHAT THIS BIND ACTUALLY DID, not on whether --paths was passed:
    #   full re-bind                         → ["--auto"]
    #     (a plain --auto run, OR a --paths run that DEGRADED to the full re-bind
    #      fallback per binding-contract.md "Fallback to full re-bind": prior
    #      binding.md unparseable / vault regenerated since last bind WITHOUT a
    #      diff-vault patch record (a diff-vault apply's bump + present
    #      VAULT-DIFF.md + no post-patch doc edit is a PATCH — it does NOT fire
    #      this trigger; the delta lane depends on that) / changed
    #      paths >40% of anchored files / a carried-forward anchor file vanished —
    #      each rewrites binding.md WHOLE, identical to a plain full re-bind)
    #   claim-scoped re-bind executed (no fallback fired; S4 living-vault sync lane
    #     per 2026-06-10-living-vault-continuous-sync-design.md §3.3/§3.6)
    #                                        → ["--reconcile", "--auto"]
    # In the sync lane (a claim-scoped re-bind that actually ran) generate-units
    # MUST reconcile — UPDATE existing unit IDs in place (id-stability) + recompute
    # status/stale/superseded — never a fresh generation (a bare ["--auto"] there
    # breaks id-stability + stale/superseded handling). Conversely a --paths run
    # that fell back MUST emit bare ["--auto"]: keying off the flag alone would
    # wrongly reconcile a fresh full re-bind. The halted → resolve-oq branch is
    # unaffected: its args do NOT gain --reconcile regardless of whether this bind
    # ran with --paths.
    suggested_args: ["--auto"]                 # full re-bind (incl. --paths fallback); ["--reconcile", "--auto"] only when a claim-scoped re-bind actually executed
    rationale: "<1-sentence>"
  blockers: []                                  # populated on bind_conflict
  metrics:
    items_processed: <N claims>
    items_blocked: <N CONFLICTs>
  scope:                                        # when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
  mutability:                                   # when claims have mutability tiers
    tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
    locked_claims_touched: []
    artifact_discards_proposed: <N>
  constitution:                                 # when constitution.md exists
    constitution_hash: <sha256>
    clauses_referenced: []
```

The `scope:` / `mutability:` / `constitution:` blocks are CONDITIONAL — emit only when applicable. Status `halted` on `bind_conflict` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` / `bind_inputs_missing` (a Step-0 stop is a halt, not a completion — see the `bind_inputs_missing` section above; its handoff carries `artifacts: []`, `blockers:` with the blocker, and `next_action.suggested_skill` per the blocker's `next_action`). Tech-OQ recommendations do NOT change the status: they are surfaced in binding.md ("## Tech-OQ Recommendations (review required)") for post-binding review, the OQ stays `open` in vault.json (carried into generate-units as an ungrounded OQ, never a baked-in decision), and bind emits `status: completed` so the chain proceeds to generate-units — recommendations are advisory and never block (see `bind-codebase/references/oq-resolution.md` §2.7).

The handoff is **required on every invocation**, not only under `--auto` — see the section intro for why (a standalone run injects no `--auto`, and a non-interactive skill has no other channel to its caller).

## Memory layer

When memory is enabled (default; opt-out `--memory-off`), participate per `mega-sdd:memory/references/memory-schema.md`.

**Writes:** after binding completes → append a run summary (claims/confirmed/conflict/oq counts + Implementation State Map distribution + Tech-OQ resolution counts) to `<vault>/.memory/bind-history.md`; new convention detected → append (additive) to `<project>/.mega-sdd/memory/conventions.md`. Each append goes **directly via `bash <plugin>/scripts/memory-write.sh --file=<resolved-path> --scope=<vault|project> --cwd=<project-root>` at emission time** (scan + lock + atomic append inside the script); the handoff carries only the receipt `metadata.memory_writes: {files_written: [...], rows_appended: N}`. Write failure → log and continue.

**Reads:** past CONFLICT resolutions matching the current conflict pattern (`<project>/.mega-sdd/memory/decisions.md`) → SUGGEST the same resolution via the blocker YAML `next_action.suggested_resolution` (user still picks via resolve-oq); cross-project CONFLICT patterns (`~/.mega-sdd/memory/patterns.md`) → suggest when project memory has no match AND ≥3 cross-project matches exist; past Hard Rule violation patterns (`<vault>/.memory/bolt-outcomes.json`) → when emitting Suggested Unit Hard Rules, DOWNGRADE rules violated+reverted ≥3 times to Anti-patterns. Under `--auto` the handoff passes POINTER slices (`{file, rows, digest}`) — consult the rows already in session context from the chain-start read; when they are NOT in context (fresh-session `--resume` re-entry, **or any forked skill — no conversation history, so the pointed rows are never in context and the targeted Read is unconditional**), **do a targeted Read of the pointed files — both ≥3 thresholds need the actual match/violation counts, never the digest alone.** The three pointed paths are canonical and named in the same sentence, so a fork can reach them without the handoff; and per the rails below memory only ever *suggests* — a missing read degrades suggestion quality, never a CONFLICT verdict.

**Anti-halu rails:** memory suggestions surface in `binding.md` `## Past Resolution Suggestions` AND the halt blocker YAML; every suggestion cites its source entry; the CONFLICT verdict is NEVER bypassed by memory (memory only suggests a resolution direction); `--memory-off` disables reads + writes; suggestions never override current codebase-map evidence.
