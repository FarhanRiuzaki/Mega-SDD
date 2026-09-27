# fc15 — the natural coverage exclusions (test sidecar: the vault's context.md)

## Coverage exclusions

- "Author: Jane Status: Draft" — document metadata (author, status) over '---' — CommonMark reads it as an H2; no behaviour
- "Prepared by the product team" — an authorship line set as a setext heading (CommonMark reads it as an H2), no behaviour
- "Appendix" — reference material, not a requirement
