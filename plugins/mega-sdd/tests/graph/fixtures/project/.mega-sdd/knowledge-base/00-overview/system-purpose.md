---
title: System Purpose Overview
---
# System Purpose

Overview / index file with NO `domain:` key — contributes no kb_domain node, but
DOES match the knowledge-base/**/*.md source glob. The builder must still hash it
so the freshness pre-check's set(cur)==set(old) holds and the cache is reused.
