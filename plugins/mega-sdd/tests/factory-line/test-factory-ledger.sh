#!/usr/bin/env bash
# CI entry — delegates to the fixture DoD for validate-factory-ledger.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
exec bash "${REPO_ROOT}/tests/fixtures/factory-line/verify.sh"
