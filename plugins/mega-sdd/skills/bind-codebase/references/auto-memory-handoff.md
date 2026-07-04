# bind-codebase — preflight, snapshot, scope, handoff & memory

## Contents
- Extraction-scorecard preflight (advisory)
- Codebase-map shared-snapshot reuse (Step 1)
- Scope propagation (Step 1)
- vault.json advisory lock (Step 6)
- Handoff emission (--auto)
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

bash "$PLUGIN_ROOT/scripts/validate-extraction-scorecard.sh" --cwd="<project>" --kb-dir="<kb-dir>"
```

Interpret the verdict (per `extract-intelligence/SKILL.md §Step 5.6`):
- **SKIP** (no scorecard — older KB, or none emitted) → proceed normally; absence is not a blocker.
- **PASS** → proceed. If the scorecard self-reports `overall_status: PARTIAL` with `[OPEN]` markers, carry those `[OPEN]`s through to `binding.md` as OQ candidates (honest gaps, not errors).
- **FAIL** (scorecard internally inconsistent, OR a PARTIAL/MISSING principle with NO `[OPEN]` markers — a hidden gap) → surface prominently in `binding.md` under `## Extraction quality (advisory)` and recommend re-running `extract-intelligence` for the failing principle. Advisory — does NOT hard-block binding.

> A blocking enforcement gate must be a deterministic validator wired to a hook — prose that says "HALT" enforces nothing. Do not add prose claiming to HALT here without a backing validator.

## Codebase-map shared-snapshot reuse (Step 1)

Check `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` (per `plugins/mega-sdd/references/shared-snapshot-schema.md`). Parse and compare its `codebase_map_sha256` to the just-read codebase-map's actual sha256, THEN check map currency against the repo (S4 — the sha256 alone proves only that the map FILE is unchanged, not that the CODE hasn't moved):
- **Currency check**: read the map frontmatter's `last_scanned_commit`. If `git rev-parse HEAD` resolves and differs from the stamp → the code moved since the scan; provenance is `"snapshot-stale"` REGARDLESS of the sha256 match, and the bind surfaces a warning recommending `/mega-sdd:sync` (or `scan-codebase --changed-only`) first. Stamp missing / literal `HEAD` / not a git repo → currency is UNKNOWN: never stamp `snapshot-verified`; use `"no-snapshot"` semantics for the provenance and note why.
- **MATCH + current** → record `binding_metadata.codebase_map_provenance = "snapshot-verified"`. Downstream consumers can trust the map is current; orchestrate-flow may remove scan-codebase from the chain when verified AND source files unchanged.
- **MISMATCH** → `"snapshot-stale"`; suggest re-running scan-codebase before the next bind.
- **Absent** → `"no-snapshot"`.

Snapshot reuse is a freshness attestation, NOT a parsing shortcut. Binding correctness is unchanged whether reuse confirms or rejects.

## Scope propagation (Step 1)

When `vault.json` has a `scope` field (multi-scope vault), persist `scope_metadata` to the `binding.md` header and emit a `scope:` block in the handoff YAML. If `scope_metadata.prd_sections_used` lists sections → constrain claim validation to those sections (skip other scopes' claims). No scope (legacy single-vault) → proceed as before. Header gains `**Scope**: <name> (<id>)` when applicable.

## vault.json advisory lock (Step 6)

Before appending the `bind` event to `vault.json`, acquire an exclusive lock on `<vault>/vault.json.lock` (per `generate-intent/references/vault-contract.md §Concurrency contract`): backoff + retry 3×; fail with the `memory_in_use` halt if all retries fail; release after the write. Lock acquisition is REQUIRED — concurrent-tab writes would corrupt the JSON.

## Handoff emission (--auto)

When invoked with `--auto` (typically `orchestrate-flow --deep` / `/mega-sdd:auto`), emit a handoff YAML at the end of output per `orchestrate-flow/references/handoff-contract.md`:

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
    suggested_args: ["--auto"]
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

The `scope:` / `mutability:` / `constitution:` blocks are CONDITIONAL — emit only when applicable. Status `halted` on `bind_conflict` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid`. Tech-OQ recommendations do NOT change the status: they are surfaced in binding.md ("## Tech-OQ Recommendations (review required)") for post-binding review, the OQ stays `pending` in vault.json (carried into generate-units as an ungrounded OQ, never a baked-in decision), and bind emits `status: completed` so the chain proceeds to generate-units — recommendations are advisory and never block (see `bind-codebase/references/oq-resolution.md` §2.7). Required ONLY under `--auto`.

## Memory layer

When memory is enabled (default; opt-out `--memory-off`), participate per `mega-sdd:memory/references/memory-schema.md`.

**Writes:** after binding completes → append a run summary (claims/confirmed/conflict/oq counts + Implementation State Map distribution + Tech-OQ resolution counts) to `<vault>/.memory/bind-history.md`; new convention detected → append (additive) to `<project>/.mega-sdd/memory/conventions.md`.

**Reads:** past CONFLICT resolutions matching the current conflict pattern (`<project>/.mega-sdd/memory/decisions.md`) → SUGGEST the same resolution via the blocker YAML `next_action.suggested_resolution` (user still picks via resolve-oq); cross-project CONFLICT patterns (`~/.mega-sdd/memory/patterns.md`) → suggest when project memory has no match AND ≥3 cross-project matches exist; past Hard Rule violation patterns (`<vault>/.memory/bolt-outcomes.json`) → when emitting Suggested Unit Hard Rules, DOWNGRADE rules violated+reverted ≥3 times to Anti-patterns.

**Anti-halu rails:** memory suggestions surface in `binding.md` `## Past Resolution Suggestions` AND the halt blocker YAML; every suggestion cites its source entry; the CONFLICT verdict is NEVER bypassed by memory (memory only suggests a resolution direction); `--memory-off` disables reads + writes; suggestions never override current codebase-map evidence.
