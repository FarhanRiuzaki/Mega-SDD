# Advisor Findings Schema

> What `phase-advisor` returns and the dispatching skill materializes. Used by `bind-codebase` + `generate-intent`.

## Schema

```yaml
phase: bind | intent
advisor_model: opus
findings:
  - id: ADV-001
    type: false_confirmed | missed_match | false_conflict | fabrication | missed_oq | misclassification | coverage_gap | state_map_error
    severity: high | medium | low
    target: "<verdict-id | claim ref | OQ-id | vault file:section>"
    issue: "<one-line statement of what is wrong>"
    evidence: "<source cite — codebase-map entry / PRD §X / file:line>"
    suggested_action: "<reclassify to CONFLICT | raise OQ | drop fabricated claim | retag business->tech | ...>"
    confidence: high | medium | low
summary: { high: N, medium: N, low: N }
```

## Rails
1. **Evidence required.** No finding without an `evidence` cite. Evidenceless findings are dropped at materialization (anti-fabrication symmetry with producer rails).
2. **Read-only advisor.** The advisor proposes; the skill materializes. The advisor never writes the artifact.
3. **Moat-asymmetry (protects invariant #2).** The advisor may ADD a blocker autonomously (a high-confidence `false_confirmed`/`missed_match` → a real `### CONFLICT-NNN`, fail-safe). It may NEVER auto-remove or auto-downgrade an existing CONFLICT — a `false_conflict` finding is FLAGGED ONLY; downgrade is human-only (via `resolve-oq`). A planner/implementer must NOT make `false_conflict` materialization symmetric with `false_confirmed`.
4. **Confidence-gated materialization (binding):** HIGH → canonical `### CONFLICT-NNN`; MED/LOW → an OQ (non-blocking, surfaced).
5. **Distinct provenance:** advisor-skipped (`--no-advisor`), advisor-clean (0 findings), and advisor-unavailable (agent error/timeout) are THREE distinct recorded states — a skipped/failed advisor is NEVER reported as "reviewed, no issues".
