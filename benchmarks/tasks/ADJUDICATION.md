# UNCERTAIN-entry adjudication policy (applied IDENTICALLY to both arms)

The two arm tracers (read-only agents, blind to each other) flagged files whose
loading was ambiguous. The benchmark author adjudicated every flagged entry with
the rules below; per-task TRACE.md records each call. The raw tracer reports are
preserved verbatim under `results/<arm>/context-trace-raw.md`.

| Rule | Policy | Direction |
|---|---|---|
| P-1 | Chain-entry machinery commanded on every router entry (`chain-execution.md` resolution preflight) → INCLUDE | conservative (inflates both arms) |
| P-2 | Per-hop handoff machinery on chains with ≥1 hop (`handoff-consumption.md`; `handoff-contract.md` at the b.iv conditional-field check) → INCLUDE | conservative |
| P-3 | Ref whose own text scopes it to a flag/state absent from the scenario → EXCLUDE (quote recorded) | neutral |
| P-4 | Pointer-only mentions ("full rules →", Related-skills) where the inline skeleton is declared authoritative for the unambiguous path → EXCLUDE | neutral; per the 6.3.0 loading contract |
| P-5 | Content consumed inside a SUBAGENT window (advisor checklist read by the Read-equipped agent itself; implementer dispatch) → EXCLUDE per trace rule 4; findings-schema only on non-zero findings → EXCLUDE in clean scenarios | neutral |
| P-6 | Mandatory numbered step whose OPERATIVE content lives in the ref (self-check Step 4, detection-and-shapes, decomposition-rails §Dependency-graph, oq-resolution 2.6/2.7, auto-and-handoff under `--auto`, sync-digest on the reconcile lane) → INCLUDE | conservative |
| P-7 | `context: fork` on detect-drift is IDENTICAL in both arms → INCLUDE in both (cannot be the measured delta) | neutral |
| P-8 | `[SECTION:…]` reads count the WHOLE file (upper bound); the count of such files per arm is reported next to every context figure | conservative AGAINST the optimization (section reads are an optimized-arm mechanism) |

Note on P-8: because the optimized arm uses §-named partial reads that baseline
does not, counting whole files OVERSTATES the optimized arm's load. The reported
optimized figures are therefore an UPPER BOUND; the true delta is at least as
large as reported.
