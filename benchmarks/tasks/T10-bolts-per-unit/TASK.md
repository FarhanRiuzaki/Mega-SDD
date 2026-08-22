# T10 — bolts per unit (execute-bolts, ONE unit, chain-realistic)

Added by v7 Fase 4 R5 (2026-08-22): the per-unit bolt lane is the plugin's
largest repeated cost (multiplied by unit count) and had no trace. Derivation:
the Fase-4 scoping lane map (`research/2026-08-22-v7-fase4-scoping.md` §2,
lane 4) — main-thread controller COMMANDED set on the chain-realistic path
(`--all --parallel --auto`) + the review-panel subagent md (fresh windows,
first attempt, standard 4-lens set). Script-owned specs (context-enrichment,
bolt-dispatch-prompt) and the runtime inline_core are EXCLUDED — executed,
not model-loaded. Conditional design/resolution lenses excluded (UI/fix-round
only).
