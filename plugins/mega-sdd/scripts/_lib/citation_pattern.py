"""Canonical source-citation grammar shared by the KB grounding validators.

ONE place for "what is a real file citation", so the citations surface (§11
resolution — god-review H1) and the markers surface of validate-kb.sh (per-[VERIFIED]-claim inline
anchor — god-review M7) cannot drift. This is the same divergence class the moat
keeps flagging: two validators, one grammar.

Key rule (M7): a citation's file EXTENSION must start with a LETTER. This rejects
regulation / version / time tokens (`23.2:2021`, `1.5:1`, `09.30:00`) that a bare
`\\w+:\\d+` pattern wrongly scored as citations, while accepting any REAL extension
(H1: generic, no hardcoded language list — `.cs` / `.cshtml` / `.kt` / `.tsx` /
`.scala` / `.twig` / `.xml` / `.ini` / `.sh` all resolve, not just php/js/py/…).
"""
import re

# File extension: letter-led, 1-10 chars (php, cs, ts, kt, tsx, cshtml, yaml, sh, …).
SRC_EXT = r"[A-Za-z][A-Za-z0-9]{0,9}"

# A source "leaf" is one of three real-file shapes (never a reg/version/time token):
#   1. path.ext with a LETTER-led extension          → src/User.cs, cfg.yaml, app.blade.php
#   2. a known EXTENSIONLESS build/CI/container file  → Gemfile, Dockerfile, Makefile
#   3. a dotfile                                      → .env, .gitignore
# Extensionless + dotfile support is required for tech-agnosticism (a Ruby legacy
# legitimately cites `Gemfile:3`); the letter-led-ext rule on the dotted shape is
# what keeps `23.2:2021` / `1.5:1` / `09.30:00` OUT (M7).
_DOTTED = r"[\w/.-]+\." + SRC_EXT
_EXTLESS = (r"(?:[\w/-]*/)?\b(?:Dockerfile|Containerfile|Makefile|Gemfile|Rakefile|"
            r"Jenkinsfile|Procfile|Vagrantfile|Brewfile|Caddyfile|Justfile)")
_DOTFILE = r"(?:[\w/-]*/)?\.[A-Za-z][\w.-]*"
_LEAF = r"(?:" + _DOTTED + r"|" + _EXTLESS + r"|" + _DOTFILE + r")"

# `<leaf>:line` — a source anchor that carries a line number (per-claim gate).
PATH_LINE_RE = re.compile(_LEAF + r":\d+")

# `<leaf>[:line[-range]]` — a file reference, line/range optional (§11 resolution).
# The trailing range uses ASCII '-' or en-dash (–).
PATH_REF_RE = re.compile(_LEAF + r"(?::\d+[-–]?\d*)?")
