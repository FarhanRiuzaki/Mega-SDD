---
description: Query the derived mega-sdd graph — impact/blast-radius over units, claims, modules, flows, KB domains, traced to code anchors.
argument-hint: "--impact <id|file[:line]> [--upstream|--downstream]"
---

Invoke the `mega-sdd:graph` skill via the Skill tool to query the project graph.

User arguments: $ARGUMENTS

Follow the skill exactly:
- The graph (`.mega-sdd/graph.json`) is derived and rebuilt lazily when stale — never authored.
- Run `scripts/query-graph.sh --root <project> --impact <target> [--upstream|--downstream]` and surface the output verbatim.
- Always surface the staleness banner if present and recommend `/mega-sdd:sync` when a binding is older than HEAD.
- Every reported edge cites its source artifact + field; never invent relationships.
