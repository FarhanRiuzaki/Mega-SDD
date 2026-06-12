# Routing Outcomes Schema

> Schema for `<project>/.mega-sdd/memory/routing-outcomes.md` — orchestrator routing decisions log.

**Version:** 1.0
**Produced by:** `mega-sdd:orchestrate-flow` Step 7.5 end-of-chain memory write
**Consumed by:** `mega-sdd:orchestrate-flow` Step 2.7 routing preflight

---

## Contents

- Purpose
- File format
- Schema
- Entries
- Project fingerprint computation
- Read protocol (Step 2.7)
- Write protocol (Step 7.5)
- Anti-halu rails
- See also

## Purpose

Append-only log of orchestrator routing decisions + outcomes. Orchestrator consults this log at routing time to override default routing-rules.md when prior runs show a consistent successful chain for the same project fingerprint.

---

## File format

Markdown with a single table-style append-only entries section.

```markdown
# Routing Outcomes

## Schema

Per row: `<date> | <project-fingerprint> | <chain-used> | <duration-min> | <converged> | <halts-fired>`

- date: ISO8601 date (YYYY-MM-DD)
- project-fingerprint: sha256(composer.json + package.json + framework_pack_path)[:16]
- chain-used: short label, e.g., "starterkit-first (scan→intent→bind→units→bolts)"
- duration-min: integer (wall-clock minutes for full chain)
- converged: yes | no
- halts-fired: int (count of halts in this chain) OR "0" if clean

## Entries

2026-05-24 | abc1234567890abc | starterkit-first | 12 | yes | 0
2026-05-25 | abc1234567890abc | starterkit-first | 8 | yes | 0
```

## Project fingerprint computation

```
fingerprint = sha256(
  read(composer.json) || "" +
  read(package.json) || "" +
  framework_pack_path || ""
)[:16]
```

Stable fingerprint = same manifests + same framework pack = same project shape.

Fingerprint INVALIDATES when:
- composer.json changes (added/removed deps)
- package.json changes
- framework_pack_path changes (starterkit pack swapped)

## Read protocol (Step 2.7)

```
1. Read .mega-sdd/memory/routing-outcomes.md (if exists; else fall through to default routing)
2. Compute current project fingerprint
3. Filter rows matching current fingerprint
4. Apply decision rules:
   a. If ≥3 prior rows with converged=yes AND same chain-used:
      → recommend that chain as default (override routing-rules.md)
      → log to orchestrator output: "Routing recommendation from past N runs (all converged)"
   b. If ≥2 prior rows with converged=no AND same chain-used:
      → warn user: "Past N runs with this chain failed; suggest alternate chain"
      → fall through to routing-rules.md default; user decides
   c. If mixed results OR <3 prior rows OR no rows match:
      → fall through to routing-rules.md default (no override)
```

## Write protocol (Step 7.5)

```
1. After chain completes (Step 7 emit final summary), compute:
   - chain-used: short label of executed chain
   - duration-min: integer
   - converged: yes if status==completed AND blockers==[]; no otherwise
   - halts-fired: count of unique halt types fired during chain
2. Acquire file lock on routing-outcomes.md (reuse memory file-lock pattern; backoff retry 3x)
3. Append new row to ## Entries section
4. Release lock
5. On lock collision after 3 retries → halt memory_in_use (existing halt; no new halt type needed)
6. On YAML/markdown parse error of existing file → emit routing_outcome_corrupt (SOFT halt; auto-invalidate file by renaming to .corrupt; next run starts fresh log)
```

## Anti-halu rails

1. NEVER append a row if chain did not actually execute (no speculative writes)
2. Fingerprint MUST be computed at chain START, not end (so re-routing decisions can use stable fingerprint)
3. `halts-fired` count MUST match actual halts in chain handoffs — not estimated
4. `chain-used` MUST be the ACTUAL skill sequence dispatched, not the proposed one

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 2.7 (consumer) + §Step 7.5 (producer)
- `plugins/mega-sdd/references/paths.md` (canonical path)
- `plugins/mega-sdd/skills/memory/SKILL.md` §Memory layer §file-lock (reused pattern)
