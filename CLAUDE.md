# mega-sdd — the Mega-SDD plugin (repo)

This repository **is** the `mega-sdd` Claude Code plugin (plus its marketplace manifest). The plugin lives in [`plugins/mega-sdd/`](plugins/mega-sdd/).

## Before changing the plugin, read the contract

**[`plugins/mega-sdd/CLAUDE.md`](plugins/mega-sdd/CLAUDE.md)** is the contributor + AI-agent contract. It carries:

- The **5 non-negotiable invariants** (the spec↔code grounding moat — binding verdicts + the CONFLICT gate, citation discipline, halt taxonomy, no fabrication). They bind the guarded lane, and they are an audit mechanism, not a measured quality gain.
- The **enforcement doctrine** — *gates > rules > hooks*; "prose that says HALT enforces nothing."
- The **v4 architecture** (lean skills + progressive disclosure, Hybrid hook enforcement, first-class `agents/`, commands as CLI entry points). On top of it sits the **9.0 shape**:
  - the **lane router** (`route-lane.sh`): direct / assisted / guarded;
  - **ONE spec pipeline** inside guarded: `plan` (a PRD, a seed PRD from a brief, or `plan --kb` from extract-intelligence) → `execute-bolts` (JIT bind per unit, CONFLICT gate at dispatch);
  - the **result contract** every lane ends with: AC → test table, `delivery-check.sh` `VERDICT: PASS`, and the assumptions list.

  The classic chain (`generate-intent` / `scan-codebase` / `bind-codebase` / `generate-units`) was removed in 9.0. Don't re-introduce it.
- **Release evidence** — never claim mega-sdd is faster / cheaper / lighter / stronger than plain Claude Code without a measured `BETTER` vs the vanilla arm (n ≥ 3). The complexity budget is a ratchet.
- The **Authoring standards** — derived from current Claude Code / Anthropic guidance, NOT invented: SKILL.md ≤ 500 lines + progressive disclosure; description = what + when with **no version archaeology**; **valid-YAML frontmatter** (no bare `key: value` colon-space in a description); references one level deep; plugin-agent frontmatter constraints; canonical nested vault paths.

**Follow those standards; do not regress to the pre-v4 anti-patterns.** They exist because v4 was a ground-up modernization to align the plugin with how Claude Code skills/plugins are meant to work.

## Other entry points

- Human contributors: [`CONTRIBUTING.md`](CONTRIBUTING.md).
- The current shape and its evidence (9.0: lane router, one pipeline, result contract, what was removed and why): [`docs/superpowers/specs/2026-09-27-v9-simplification-design.md`](docs/superpowers/specs/2026-09-27-v9-simplification-design.md). The measured reports behind it: [`research/2026-09-27-vanilla-vs-megasdd-results.md`](research/2026-09-27-vanilla-vs-megasdd-results.md), [`research/2026-09-27-lane-router-results.md`](research/2026-09-27-lane-router-results.md), [`research/2026-09-27-brownfield-results.md`](research/2026-09-27-brownfield-results.md).
- The pipeline's origin (the 8.0.0 fused `plan` → bolts lane, layout-3 vault, binding per unit): [`docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md`](docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md).
- The full modernization analysis (why v4 exists, the gap vs current best practice): [`research/2026-06-04-architecture-modernization-audit.md`](research/2026-06-04-architecture-modernization-audit.md) · the v4 execution spec: [`docs/superpowers/specs/2026-06-04-v4-lean-core-design.md`](docs/superpowers/specs/2026-06-04-v4-lean-core-design.md).
