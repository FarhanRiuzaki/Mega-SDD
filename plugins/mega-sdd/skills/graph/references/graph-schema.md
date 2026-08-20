# graph.json schema (derived, project-scope cache)

Pure JSON root object at `.mega-sdd/graph.json`. Never hand-edited. Regenerated
by the builder. Safe to delete.

## Top level

```json
{
  "schema_version": "1.0",
  "_meta": {
    "derived": true,
    "generated_by": "build-graph@<version>",
    "built_at": "<ISO8601 UTC>",
    "head": "<git HEAD sha at build, or null>",
    "source_glob": ["<glob patterns walked>"],
    "source_hashes": {"<repo-relative artifact path>": "<sha256>"},
    "binding_stamps": {
      "<vault-id>": {
        "provenance": "snapshot-verified|snapshot-stale|no-snapshot",
        "head_at_bind": "<sha|null>",
        "stale_vs_head": false
      }
    }
  },
  "nodes": [
    {
      "id": "...",
      "type": "...",
      "label": "...",
      "attrs": {},
      "source": {"artifact": "...", "field": "..."}
    }
  ],
  "edges": [
    {
      "source": "...",
      "target": "...",
      "relation": "...",
      "confidence": "VERIFIED|CONFIRMED|...",
      "evidence": {"artifact": "...", "field": "..."}
    }
  ]
}
```

## Node types (v1)

`code_anchor`, `claim`, `unit`, `module`, `flow`, `kb_domain`, `oq`, `vault`,
and `symbol` (the code layer). (`interface` deferred.)

## `symbol` — the code layer

The vault layer records what was INTENDED; the code layer records what actually
exists and what it is for, derived from `codebase/reuse-index.yaml` (the scan's
function map). Both layers meet on the SAME `code_anchor` node, which is what
makes a cross-layer question one hop.

- id `sym:<file-path>#<name>` — **line-independent by design**: a line-keyed id
  churns on every edit above the symbol, which would defeat delta-by-sha on the
  publish side. `~<line>` is appended only to disambiguate an overload.
- attrs: `signature`, `purpose`, `purpose_confidence` (`stated`|`inferred`),
  `category`, `class` (methods), `line`.
- **`purpose_confidence` is non-strippable.** Most purposes are `inferred` — a
  purpose surfaced without its marker is the unmarked-`[INFERRED]` fabrication
  class. `_meta.code_layer.truncated` likewise flags a capped scan, so a partial
  function map is never presented as complete.
- Source is reuse-index ONLY. `codebase/symbol-index.json` (the structural
  ast-grep tier) has no `purpose`; purposeless nodes add payload, not knowledge.

## ID namespacing

Vault-scoped node ids are `<vault-id>:<local-id>` (`unit`, `claim`, `oq`, `flow`).
Global ids stay bare: `code_anchor` (file path), `module` (M-*), `vault` (slug),
`kb_domain` (kebab id — project-global KB).

## `code_anchor` identity

id = file path only; `attrs.line` carries the line hint. A `file:line` string is
normalized to its file when minting/matching.

## Edge relations (v1)

| relation | from → to | source field |
|---|---|---|
| implements | claim → code_anchor | binding.json `claims[].anchor` |
| honors | unit → claim/oq | unit frontmatter `binding_refs` |
| depends_on | unit → unit | unit frontmatter `depends_on` |
| in_module | unit → module | modules.yaml vault_sections match (or unit `module:`) |
| blocks | module → module | modules.yaml `blocks`/`blocked_by` |
| kb_source | flow → kb_domain | vault flow `_kb_source` |
| domain_dep | kb_domain → kb_domain | KB frontmatter `depends_on` |
| covers | claim → flow | binding.json `claims[].vault_source` |
| defined_in | symbol → code_anchor | reuse-index `_source` (confidence mirrors `purpose_confidence`) |
| touches | unit → code_anchor | unit frontmatter `target_files[]` (`operation: none` skipped; `operation` carried on the edge) |

`covers` targets a `flow` only in v1: the builder emits it only when `vault_source`
resolves to a known flow node, and omits it otherwise. A `vault-section` node type
(covering a claim to a non-flow vault section) is deferred — there is no such node
type in v1.

## Confidence derivation (honest-confidence rule)

`implements` inherits the claim verdict/confidence from binding.json. All
structurally-declared edges (`honors`, `depends_on`, `in_module`, `blocks`,
`kb_source`, `domain_dep`, `covers`) are `VERIFIED` — read verbatim from an
authored field. No edge is ever `INFERRED` in v1.

## Anti-hallucination

An edge is emitted ONLY from a present, cited field. If a referenced target id
does not resolve to a node, mint a `[Pending]` placeholder node
(`type` unchanged, `attrs.pending=true`) — NEVER drop the citation and NEVER
fabricate a non-cited edge.
