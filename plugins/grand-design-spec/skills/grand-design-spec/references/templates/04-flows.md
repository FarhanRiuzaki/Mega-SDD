# 04 — Flows

> **TL;DR**: Step-by-step user flows, system flows, and per-flow Definition of Done. Organized **per type** according to PROJECT_SHAPE.
> **Audience**: Developers per layer (Mobile/FE/BE/Data), QA, UI/UX.
> **Read when**: you're building/testing a specific feature or need to see end-to-end behavior.

> **Note**: TL;DR placeholders shown in English. At runtime, render them in the PRD's language.

---

> Sub-sections below are derived from `PROJECT_SHAPE` (see `00-index.md` Vault Lock Status).
> Replace section headers with the relevant flow types.
>
> Common flow type sets:
> - mobile-app: User flows (mobile-facing), Backend / system flows, Cross-cutting flows
> - web-app: User flows (web), Backend / system flows, Cross-cutting flows
> - api-only: Backend / system flows, Consumer-facing flows
> - multi-platform: User flows (web), User flows (mobile), Backend / system flows, Cross-cutting flows
> - data-pipeline: Pipeline flows, Error/recovery flows, Operational flows
> - custom: flow categories per user description

## {Flow Type 1, e.g. "User flows (mobile-facing)" or "Pipeline flows"}

> Section description: e.g. "Flows triggered by the user from Mobile" or "Daily ETL processes from source to sink".

### F-{prefix}-001: <flow name>

> Prefix convention:
> - `F-U-` = User-facing flow
> - `F-S-` = System / backend flow
> - `F-C-` = Cross-cutting (multi-layer)
> - `F-P-` = Pipeline flow (for data-pipeline shape)
> - `F-X-` = Custom prefix per project shape

**Actor / Trigger**: <persona, or "scheduled cron at HH:MM", or "external API call">
<!-- full-only -->
**Preconditions**: <state required before flow starts>
<!-- /full-only -->

**Steps**:
1. <action>
2. <action>
3. <action>

<!-- full-only -->
**Postconditions**: <state after flow completes>
<!-- /full-only -->

**Definition of Done**:
- [ ] <observable behavior 1>
- [ ] <observable behavior 2>
- [ ] <data state change>

**Figma reference** (if applicable): <frame-name>
**Source**: PRD §<X.Y>

---

### F-{prefix}-002: <next flow>

<repeat>

---

## {Flow Type 2, e.g. "Backend / system flows" or "Error/recovery flows"}

### F-{prefix}-001: <flow name>

**Trigger**: <cron / event / manual>
**Inputs**: <what data the system reads>
**Steps**:
1. <action>
2. <action>

**Outputs**: <what data is written / emitted>
<!-- full-only -->
**Failure handling**: <retry / DLQ / alert>
<!-- /full-only -->

**Definition of Done**:
- [ ] <observable behavior>
- [ ] <data outcome>

**Source**: PRD §<X.Y>

---

## {Flow Type 3, e.g. "Cross-cutting flows" — if applicable to PROJECT_SHAPE}

> Flows that involve multiple layers with explicit handoff points. Architects jump here.

### F-C-001: <flow name>

**Actor**: <persona>
**Layers involved**: <list layers per PROJECT_SHAPE>

**Steps with handoff points**:
1. **[Layer A]** <action>
2. **[Layer A → Layer B]** <data passed, protocol, what's expected>
3. **[Layer B]** <action>
4. **[Layer B → Layer A]** <response>
5. **[Layer A]** <render / final action>

**Definition of Done**:
- [ ] All handoff points succeed under happy path
- [ ] Failure at any handoff: appropriate error handling per layer
- [ ] Async events do not block sync response (if applicable)

**Source**: PRD §<X.Y>

---

## Sources

- PRD §<X.Y>
- Figma: <frame-set name>

## Out of Scope

- <e.g. "Bulk import flow — not in v1">
- <if unknown: "TBD - confirm with PO">

## Open Questions

- [ ] **OQ-FL-1** [P{1|2|3}]: <e.g. "PRD describes happy path only — what is the flow when payment fails after order creation?">
- [ ] **OQ-FL-2** [P{1|2|3}]: <e.g. "Email notifications mentioned but content/template not specified">
