# extract-intelligence — Handoff emission (--auto)

This is the OPERATIVE emission spec for extract-intelligence's handoff YAML (per `orchestrate-flow/references/handoff-contract.md` §Precedence — each skill's own handoff reference is the operative copy; the contract owns only the base schema + the cross-skill routing index).

When invoked with `--auto` (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit this record as a YAML code fence in the LAST assistant message before exiting (chat-block semantics — NOT to a file on disk). The orchestrator parses it to decide auto-continue. Emit it verbatim with runtime values filled in (artifacts, metrics, scope, tier distribution). The `scope:` and `mutability:` blocks are part of the canonical record — extract-intelligence is the PRIMARY mutability-tier producer (`tier_distribution`, `locked_claims_touched`, `artifact_discards_proposed`).

```yaml
handoff:
  emitted_by: extract-intelligence
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - /path/to/.mega-sdd/knowledge-base/
    - /path/to/.mega-sdd/knowledge-base/README.md
  next_action:
    suggested_skill: mega-sdd:generate-intent
    suggested_args: ["--kb=.mega-sdd/knowledge-base/", "--auto"]
    rationale: "Knowledge base extracted; generate vault using KB as Mode B brief."
  blockers: []
  metrics:
    items_processed: 35    # MD files written
    items_blocked: 0
  scope:                                  # when target vault will have scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from PRD if available>
  mutability:                             # extract-intelligence is PRIMARY tier producer
    tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
    locked_claims_touched: []
    artifact_discards_proposed: <N>
```

Status `halted` when quality gate fails twice (per `references/wave-dispatch-templates.md` §gate failures) — populate `blockers:` with ≥1 entry per halt-protocol §blocker envelope (a halt with an empty envelope FAILs `invalid_handoff`).

Required ONLY under `--auto`; standalone invocations may emit informationally. Every path listed in `artifacts:` must exist on disk at emission time (the orchestrator existence-checks them).
