#!/usr/bin/env bash
set -u
err=0
grep -q 'reuse_candidates' plugins/mega-sdd/skills/generate-units/references/unit-schema.md || { echo "unit-schema missing reuse_candidates"; err=1; }
grep -q 'reuse-index' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "derivation does not read reuse-index"; err=1; }
grep -q 'reuse_candidates' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "derivation does not emit reuse_candidates"; err=1; }
grep -qiE 'fast-path|hint, not|primary lookup|primary surface' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "missing fast-path-hint framing"; err=1; }
exit $err
