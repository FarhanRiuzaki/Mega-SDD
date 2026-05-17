---
id: "{{INTERFACE_ID}}"                    # e.g., api-leave-request-submit (kebab-case)
type: interface
interface_id: "{{INTERFACE_NUMERIC_ID}}"  # e.g., I-API-001 (zero-padded, monotonic per kind)
contract_kind: "{{CONTRACT_KIND}}"        # rest | graphql | rpc | event | webhook | schema
producer: "{{PRODUCER_SQUAD_ID}}"         # one squad ID from squads.yaml
consumers: ["{{CONSUMER_SQUAD_ID_1}}"]    # list of squad IDs (one or more)
status: draft                              # draft | locked  — start as draft; lock after stakeholder review
version: "1.0"
locked_at: null                            # ISO8601 date when first locked; preserved across edits
related_flows: []                          # e.g., [[04-flows#F-U-001]]
related_entities: []                       # e.g., [[03-data-model#leave_request]]
tags: [interface, "squad/{{PRODUCER_SQUAD_SLUG}}"]
---

# {{INTERFACE_NUMERIC_ID}} — {{INTERFACE_TITLE}}

> **Producer:** {{PRODUCER_SQUAD_LABEL}}
> **Consumers:** {{CONSUMER_LIST}}
> **Status:** draft
> **Related:** {{RELATED_FLOWS_AND_ENTITIES}}

## Contract

<!-- Concrete schema below. Choose the right format for contract_kind:
     - rest      → YAML with HTTP method, path, request/response body
     - graphql   → GraphQL SDL fragment
     - rpc       → method signature + payload
     - event     → event name + payload JSON schema
     - webhook   → endpoint + headers + body schema
     - schema    → DBML excerpt or JSON Schema for shared data shape
-->

```yaml
# Example — REST endpoint contract:
POST /api/v1/<resource>
auth: bearer-token
request:
  body:
    field_1: <type>
    field_2: <type>
response:
  200: { ... }
  400: validation errors
  409: business-rule conflict
```

## Definition of Done — producer ({{PRODUCER_SQUAD_LABEL}})

- [ ] <verifiable criterion 1, references vault section>
- [ ] <criterion 2>

## Definition of Done — consumer (each consumer squad)

- [ ] <verifiable criterion 1 — how consumer detects "interface honored">
- [ ] <criterion 2>

## Blocked by

<list of [[06-constraints#OQ-XX-N]] references for OQs that must resolve
before this interface can move from draft → locked. Empty list = ready
to lock pending review.>

## Changelog

- v1.0 (YYYY-MM-DD): initial draft
