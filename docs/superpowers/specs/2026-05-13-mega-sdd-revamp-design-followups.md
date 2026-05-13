# Mega-SDD v1.0 Followups

Tracker for items deferred past v1.0.0.

## Planned for v1.1

- Plugin alias support (e.g., `msdd:` shortcut) — depends on Claude Code feature availability
- Unit dependency graph user-editable view
- Custom unit templates per project

## Planned for v1.2

- Multi-harness mirrors (`.codex-plugin/`, `.opencode/`, `.cursor-plugin/`) via sync script
- AST-level codebase scanning (current is heuristic)
- Remove deprecated `from-prompt` command alias

## Planned for v2.0

- Cross-vault federation
- Bolt rollback / undo (beyond git)
- Real-time PRD ingestion (Notion/Confluence webhook)
- Auto-conflict-resolution suggestions in bind-codebase (still human-confirmed)

## Sunset schedule for grand-design-spec

- v1.0.0 (mega-sdd) released: 2026-05-13
- v1.1.x releases: keep grand-design-spec deprecated entry in marketplace
- v1.2.0: remove grand-design-spec entry from marketplace.json

## Known limitations of v1.0

- Codebase scan is heuristic (regex/grep); may miss dynamic routes, magic methods
- Binding gate requires structured codebase-map (manual scan-codebase prerequisite)
- No state file — orchestrate-flow re-inspects each invocation (deliberate; resumption is re-invocation)
- Marketplace `source` field external-git-URL support is unverified — assumes manual install of superpowers
