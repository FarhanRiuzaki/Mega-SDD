# mega-sdd — the Mega-SDD plugin (repo)

This repository **is** the `mega-sdd` Claude Code plugin (plus its marketplace manifest). The plugin lives in [`plugins/mega-sdd/`](plugins/mega-sdd/).

## Before changing the plugin, read the contract

**[`plugins/mega-sdd/CLAUDE.md`](plugins/mega-sdd/CLAUDE.md)** is the contributor + AI-agent contract. It carries:

- The **5 non-negotiable invariants** (the spec↔code grounding moat — binding verdicts + the CONFLICT gate, citation discipline, halt taxonomy, no fabrication).
- The **enforcement doctrine** — *gates > rules > hooks*; "prose that says HALT enforces nothing."
- The **v4 architecture** (lean skills + progressive disclosure, Hybrid hook enforcement, first-class `agents/`, commands as CLI entry points) and the **two 8.x lanes** (classic default chain + the opt-in `--lite` plan → bolts lane, JIT bind per unit).
- The **Authoring standards** — derived from current Claude Code / Anthropic guidance, NOT invented: SKILL.md ≤ 500 lines + progressive disclosure; description = what + when with **no version archaeology**; **valid-YAML frontmatter** (no bare `key: value` colon-space in a description); references one level deep; plugin-agent frontmatter constraints; canonical nested vault paths.

**Follow those standards; do not regress to the pre-v4 anti-patterns.** They exist because v4 was a ground-up modernization to align the plugin with how Claude Code skills/plugins are meant to work.

## Other entry points

- Human contributors: [`CONTRIBUTING.md`](CONTRIBUTING.md).
- The full modernization analysis (why v4 exists, the gap vs current best practice): [`research/2026-06-04-architecture-modernization-audit.md`](research/2026-06-04-architecture-modernization-audit.md).
- The v4 execution spec: [`docs/superpowers/specs/2026-06-04-v4-lean-core-design.md`](docs/superpowers/specs/2026-06-04-v4-lean-core-design.md).
- The current pipeline shape (8.0.0 fused pipeline, `--lite` lane, layout-3 vault, binding per unit): [`docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md`](docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md); its measured verdict lives in `CHANGELOG.md` `## [8.0.0]`.
