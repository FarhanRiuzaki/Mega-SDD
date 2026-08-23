# Halt guidance — scan family

Per-type guidance for halts emitted by: scan-codebase (deep-scan, engines, starterkit capture).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### deep_scan_subagent_failed

- `deep_scan_subagent_failed` — scan-codebase: a deep-scan slice subagent (auth/authz/ui-ux/libs/reuse) failed once. Soft halt: auto-retried; on second failure emits partial starterkit-context.yaml with `partial: true`. Pipeline continues (warn-only).

### deep_scan_cache_corrupt

- `deep_scan_cache_corrupt` — scan-codebase: starterkit-context.yaml exists but fails YAML parse. Soft halt: cache auto-invalidated; subagents re-dispatched. Transparent to user.

### deep_scan_subagent_all_failed

- `deep_scan_subagent_all_failed` — scan-codebase: ALL 5 deep-scan slice subagents failed (likely API outage). ALWAYS STOP: user re-runs scan-codebase later. Existing starterkit-context.yaml (if any) preserved untouched.

### dep_missing

- `dep_missing` — scan-codebase: a FORCED engine's binary not found (ast-grep under --engine=ast-grep; the tree-sitter lane was removed v7.4.0). ALWAYS STOP.
