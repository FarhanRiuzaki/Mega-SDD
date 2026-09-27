# PRD: Release Notes Generator
## 1. Generator Output
The generator MUST emit markdown shaped like:
```md
## Highlights
- ...
## Out of scope
- items deferred to next release
```
### 1.1 Grouping
Entries MUST be grouped by type (feat/fix/chore).
### 1.2 Version Bump Rules
A breaking change MUST bump the major version.
## 2. Publishing
Notes MUST be published to the portal.
