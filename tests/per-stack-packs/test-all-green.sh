#!/usr/bin/env bash
set -u
bash plugins/mega-sdd/scripts/validate-pack.sh --all >/dev/null 2>&1 || { echo "--all not green"; exit 1; }
bash plugins/mega-sdd/scripts/validate-pack.sh --check-registry >/dev/null 2>&1 || { echo "registry stale"; exit 1; }
exit 0
