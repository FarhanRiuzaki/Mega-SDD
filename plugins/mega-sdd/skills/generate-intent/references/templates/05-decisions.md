---
type: prose
doc_id: 05-decisions
vault_version: "{{VAULT_VERSION}}"
aliases: [Decisions, ADRs, ADR Log]
tags: ["vault/{{PROJECT_SLUG}}", "doc/decisions"]
---

# 05 — Decisions

> **TL;DR**: Locked technical and business decisions, plus their rationale and consequences.
> **Audience**: Architect, Tech Lead, PM, anyone who needs to challenge "why X and not Y".
> **Read when**: you need to know the reason behind a decision, or want to propose a change.

> **Note**: TL;DR placeholders shown in English. At runtime, render them in the PRD's language.

> ADR-lite. One entry per technical decision with an explicit source.
> If a decision has no explicit source, it's not an ADR — it goes to Open Questions in [[00-index]].

---

### D-001: <short decision title, e.g. "Use Redis for session cache">

<!-- full-only -->
**Status**: <Proposed / Accepted / Superseded by D-XXX>
**Date**: YYYY-MM

**Context**:
<Why this decision is needed. What problem it solves. What alternatives were considered.>

**Decision**:
<What was decided, in 1–3 sentences.>

**Consequences**:
- ✅ <positive consequence>
- ✅ <positive consequence>
- ⚠️ <trade-off / cost>
- ⚠️ <trade-off / cost>

**Source**: PRD §<X.Y> / explicit user instruction / meeting <date>
<!-- /full-only -->

<!-- compact-mode rendering: replace the multi-section block above with a 1-paragraph format:
<Context in one sentence>. **Decision**: <what was decided, 1–2 sentences>. **Consequences**: <pros + tradeoffs, comma-separated, max 2 lines>. **Source**: <PRD §X>.
-->

---

### D-002: <next decision>

<repeat>

---

## Sources

- PRD §<X.Y>
- Architecture review notes

## Out of Scope

- <decisions deferred to later phases>
- <if unknown: "TBD - confirm with architecture team">

## Open Questions

- [ ] **OQ-DC-1** [P{1|2|3}]: <decision needed but no source yet, e.g. "Choice of message broker: RabbitMQ vs Kafka — no decision in PRD">
