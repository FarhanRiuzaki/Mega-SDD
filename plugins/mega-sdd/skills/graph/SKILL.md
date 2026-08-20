---
name: graph
version: 1.1.0
description: Queries the derived mega-sdd graph — impact / blast-radius over units, claims, modules, flows, KB domains, traced to code anchors; rebuilt lazily when stale, never authored. Use when the user asks "what breaks if I change X", "blast radius", "impact of this code", "apa yang kena kalau ubah ini", "what depends on this unit", or asks for the graph / impact lens.
---

# mega-sdd:graph

A derived, project-scope graph (`.mega-sdd/graph.json`) over existing mega-sdd
artifacts. Markdown stays the source of truth — the graph is a queryable lens,
regenerated on demand, safe to delete. Schema → `references/graph-schema.md`.

## What it answers (v1)

Impact / blast-radius: given a code path or a node id (`U-NNN`, `C-NNN`,
`<vault>:U-NNN`, a `kb_domain`), what is affected downstream ("what breaks if I
touch this") or upstream ("what this rests on").

## How to run

1. **Build is automatic.** The query rebuilds `graph.json` whenever it is missing
   or any source artifact changed (path-set + content hash). You never build by hand.
2. **Run the query:**
   `Run: scripts/query-graph.sh --root <project> --impact <id|file[:line]> [--upstream|--downstream]`
   (defaults to `--downstream`). Surface the output verbatim, including any
   staleness banner.

## Anti-hallucination contract

- Every edge in an answer cites its source artifact + field — surface those chains.
- The graph emits NO inferred edges (v1). A reference whose target is absent
  appears as a `[Pending]` node, never a fabricated link.
- If the staleness banner fires (a binding is older than HEAD), tell the user the
  impact may be incomplete and recommend `/mega-sdd:sync` — do NOT silently trust
  stale anchors.

## Freshness

Lazy rebuild is the correctness mechanism: the query catches every mutation
(any writer, manual edit, git pull) via source-glob path-set + hashes. `sync`
also warms `graph.json` at end-of-run, but that is convenience, not correctness.

## Scope (v1) & roadmap

v1 node types: code_anchor, claim, unit, module, flow, kb_domain, oq, vault,
symbol (`interface` deferred to multi-squad). `symbol` is the code layer — the
scan's function map (signature + purpose + `purpose_confidence`, never stripped)
joined to the vault layer through the shared code_anchor node; see
`references/graph-schema.md`. Future lenses on the same graph.json:
visualization (Mermaid/HTML) and a global cross-artifact validation gate
(dangling refs, orphans, broken anchors). Optional v2 seam: ingest an external
code graph (e.g. graphify) as EXTRACTED-only secondary evidence to enrich
code_anchor — never trusted for inferred edges, never a required dependency.
