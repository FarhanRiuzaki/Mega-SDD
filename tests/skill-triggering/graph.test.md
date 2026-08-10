# graph Trigger + Behavior Test

Manual-run fixture for `graph` skill.

## Trigger cases

### G1: Blast radius (English)
- **Prompt:** `blast radius of src/services/payment.ts`
- **Expect:** Skill invocation; runs `scripts/query-graph.sh --impact` against the resolved project root

### G2: Natural English
- **Prompt:** `what breaks if I change U-004?`
- **Expect:** Skill invocation (downstream impact query on the unit node)

### G3: Natural Indonesian
- **Prompt:** `apa yang kena kalau ubah ini?` (a code path or node id in context)
- **Expect:** Skill invocation

### G4: Negative — plain chart-drawing request must NOT route here
- **Prompt:** `draw me a bar chart of monthly signups`
- **Expect:** NO graph invocation — the word "chart"/"graph" as a visualization request is not the impact lens; graph triggers on impact / blast-radius / depends-on phrasing, never on drawing requests

## Behavior checks

### B1: Lazy rebuild — never built by hand
- The query rebuilds `.mega-sdd/graph.json` whenever it is missing or any source artifact changed (path-set + content hash); the user is never told to build first.

### B2: Derived, never authored
- `graph.json` is a regenerated lens over the markdown artifacts — safe to delete; no answer invites hand-editing it.

### B3: Edge citations + no inferred edges
- Every edge in an answer cites its source artifact + field; a reference whose target is absent surfaces as a `[Pending]` node, never a fabricated link.

### B4: Staleness banner surfaced
- When a binding is older than HEAD, the query's staleness banner is surfaced verbatim with a recommendation to run `/mega-sdd:sync`; stale anchors are never silently trusted.

## Pass criteria

All positive trigger cases (G1-G3) invoke the skill; the chart-drawing request (G4) does not. Behavior checks confirm: automatic lazy rebuild (B1); graph stays derived, never authored (B2); cited edges with `[Pending]` for absent targets, no inferred links (B3); staleness banner surfaced with the sync recommendation (B4).
