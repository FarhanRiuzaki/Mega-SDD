# 05 — Decisions

> **TL;DR**: Keputusan teknis & bisnis yang sudah locked, plus alasan & konsekuensinya.
> **Untuk siapa**: Architect, Tech Lead, PM, semua role yang challenge "kenapa milih X bukan Y".
> **Baca kalau**: lo perlu tahu alasan di balik keputusan, atau mau propose perubahan.

> ADR-lite. One entry per technical decision with explicit source.
> Kalau decision tidak ada source eksplisit, dia bukan ADR — masuk ke Open Questions di `00-index.md`.

---

### D-001: <short decision title, e.g. "Use Redis for session cache">

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
