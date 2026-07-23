# diff-vault — --auto, conflicts, chain integration & handoff

## Contents
- `--auto` behavior table
- What stays interactive under `--auto`
- `diff_conflict` blocker emission
- Canonical diff via `jd`
- Handoff YAML emission (incl. scope block)

Loaded when diff-vault runs under `--auto` or as an orchestrate-flow chain phase. The core rule: **substance prompts (Resolved-OQ conflicts, Decision conflicts) ALWAYS stay interactive OR emit a blocker** — auto-deciding would silently overwrite stakeholder choices.

## `--auto` behavior

The `--auto` flag is passed by upstream callers (typically `/mega-sdd`) to skip logistical prompts. Conflicts represent disagreement between vault state and new source; the skill never auto-decides them.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (vault path) | Auto-detect or ask | Use auto-detected if exactly 1 vault in CWD. |
| Step 0 (git safety check) | Ask if uncommitted | Continue but record uncommitted state in the diff report's metadata. |
| Step 0.5 (diff scope) | Ask | Default to `full`. |
| Step 1 (old source path) | Ask once | Skip — use vault-state-only. |
| Step 5 (per-conflict resolution) | Ask Supersede/Keep/Both/Skip | **Emit `blocker` (type=`diff_conflict`)** per conflict and pause. Caller decides next steps. |
| Step 5 (auto-resolved OQs batch confirm) | Ask "Apply all / one-by-one / skip" | Default to "Apply all". |
| Step 5 (added/changed/removed batch confirm) | Ask | Auto-apply if total change count ≤ 50; otherwise pause and emit `blocker` (type=`diff_conflict`, tag=`OQ-FLOW-3-cap`, context="change count exceeds auto-apply cap"). |
| Step 6 (apply changes Y/N) | Ask | Skip — apply approved (non-conflict) changes. |
| Step 7 (vault version bump type) | Ask patch vs minor | Use heuristic: minor if any conflicts had user input OR added entities/flows ≥ 5; patch otherwise. |

## What stays interactive even with `--auto`

- **Resolved-OQ conflicts** — emit `blocker` per conflict, never auto-decide.
- **Decision conflicts** — same.
- **Major scope shift detection** — the push-back rule (e.g., >50% entity churn) still triggers.
- **LOCKED vault confirmation** — destructive, audit-significant.

## `diff_conflict` blocker emission

When a conflict is hit in `--auto` mode, instead of `AskUserQuestion`, emit:

```yaml
blocker:
  type: diff_conflict
  tag: <OQ-DC-2 | D-007 | etc.>
  priority: n/a
  context: "<e.g. 'diff-vault Step 5: Resolved-OQ conflict on idempotency strategy'>"
  resolver_owner: "<from vault metadata or null>"
  resolver_route: "<from vault metadata or null>"
  vault_version: "<current>"
  source_skill: diff-vault
  conflict_old: "<vault state, verbatim from VAULT-DIFF.md>"
  conflict_new: "<new PRD state, verbatim from VAULT-DIFF.md>"
  options:                             # {code, keterangan} pairs per halt-protocol §Field rules —
    - {code: supersede, keterangan: "keputusan baru menggantikan yang di vault"}
    - {code: keep_vault, keterangan: "tolak perubahan PRD; vault tetap"}
    - {code: capture_both, keterangan: "catat keduanya sebagai OQ untuk stakeholder"}
  # propose-and-confirm discipline (this block IS the `recommended:` carrier — richer form,
  # same contract slot; the displayer renders proposed_action as the recommended default):
  recommendation:
    proposed_action: "supersede"
    rationale: "PRD revision is the newer source-of-truth; vault should follow unless the change is destructive (e.g., dropping a field the vault references elsewhere). Capture-both used only when both old and new are valid interpretations."
    confidence: "medium"
    alternatives: ["supersede", "keep_vault", "capture_both"]
  user_response_required: true
```

After emit, halt the apply phase. The diff report (`VAULT-DIFF.md`) is still written with the conflict surfaced. The caller (orchestrator or human) handles resolution and re-invokes `diff-vault` (without `--auto`) to walk it interactively.

When the skill is invoked without `--auto`, conflict handling is fully interactive (Step 5 walkthrough).

## Canonical diff via `jd`

Use `jd` (RFC-7386/6902 compliant JSON/YAML diff with patch generation) for canonical structural diff of vault.json between revisions, replacing the ad-hoc Read+compare approach. Install is OPTIONAL — the skill works without it — or run `/mega-sdd:install-deps` to install automatically.

```bash
if command -v jd >/dev/null; then
  # Generate canonical patch (RFC-6902 JSON Patch by default)
  jd <old-vault>/vault.json <new-vault>/vault.json > <vault>/.mega-sdd/vault-diffs/<timestamp>.patch
  # Apply later if needed:
  # jd -p <patch-file> <old-vault>/vault.json > <vault>/vault.json
else
  # Fallback: skill-internal Read + compare (preserves prior behavior)
fi
```

Patch artifact storage:
- Location: `<vault>/.mega-sdd/vault-diffs/<ISO8601>.patch`
- Format: RFC-6902 JSON Patch (default jd output)
- Use case: audit trail of vault evolution; can replay or revert via `jd -p`
- Backward compat: skip storage when jd is absent; skill-internal Read+compare proceeds.

See `plugins/mega-sdd/references/tooling-install.md` §jd for install commands per platform.

## Handoff YAML emission

When invoked with `--auto`, emit a handoff YAML record at the end of skill output per the local template below — the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

```yaml
handoff:
  emitted_by: diff-vault
  emitted_at: <ISO8601 timestamp>
  status: completed | paused | halted
  artifacts:
    - <absolute path to <vault>/VAULT-DIFF.md>            # primary output artifact
    - <absolute path to <vault>/vault.json (updated)>
    - <absolute path to <vault>/00-index.md (updated)>
    - <absolute path to <vault>/.mega-sdd/vault-diffs/<ISO8601>.patch>
  scope:                                  # when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <CURRENT_SHA>  # the new hash, not the recorded one
  next_action:
    # THREE guarded branches — emit exactly ONE per outcome; suggested_args differs per branch.
    # (a) status halted on diff_conflict (a Resolved-OQ [x] vs new PRD contradiction whose
    #     content lives ONLY in VAULT-DIFF.md): re-invoke diff-vault WITHOUT --auto so Step 5
    #     resolves it interactively. resolve-oq CANNOT consume this — it walks only [ ] OQ
    #     entries and reads vault docs 00-06, never VAULT-DIFF.md; keeping --auto here would
    #     re-hit the same contradiction and re-halt (an operator loop).
    suggested_skill: mega-sdd:diff-vault        # interactive re-invoke
    suggested_args: []                          # NO --auto — interactive Step 5 walkthrough
    # (b) status completed AND new [ ] OQs were materialized into the vault (New-OQ rows,
    #     OQ-{CODE}-{N+1}): those [ ] entries ARE consumable by resolve-oq's [ ]-walk.
    suggested_skill: mega-sdd:resolve-oq        # new open questions to walk
    suggested_args: ["--auto"]
    # (c) status completed AND diff clean: chain may resume to bind/units/bolts.
    suggested_skill: mega-sdd:orchestrate-flow  # diff clean
    suggested_args: ["--auto"]
    rationale: "<1-sentence — e.g., 'diff_conflict surfaced; re-run diff-vault interactively (no --auto) to resolve' OR 'N new OQs materialized; resolve-oq walks them' OR 'Diff clean; vault updated; binding may need re-run'>"
  blockers: []
  metrics:
    items_processed: <N changes detected: added + removed + modified>
    items_blocked: <N CONFLICTs requiring resolution>
```

Omit the `scope:` block when the vault is legacy (no `scope_metadata` in vault.json). Status `halted` on `diff_conflict` (Resolved-OQ `[x]` vs new PRD contradiction) — resolve it by re-invoking `diff-vault` WITHOUT `--auto` (the interactive Step 5 walkthrough; see the blocker-envelope resolution note above), NOT via `resolve-oq`, which cannot read a `VAULT-DIFF.md` conflict (`handoff-contract.md §Anti-halu invariants` — a halted `next_action` must point to the true resolution path). Standalone invocation emits an informational chat hint only.
