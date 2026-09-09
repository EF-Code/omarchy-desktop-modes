#!/usr/bin/env bash
set -u
set -o pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$ROOT" || exit 1
failed=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok - %s\n' "$label"
  else
    printf 'not ok - %s\n' "$label" >&2
    failed=1
  fi
}

check "manifest JSON" jq -e '.schemaVersion == 1 and .id == "io.github.ef-code.desktop-modes"' manifest.json
check "no symlinks" test -z "$(find . -path './.git' -prune -o -type l -print -quit)"
check "agent instructions are not tracked" test -z "$(git ls-files -- AGENTS.md '**/AGENTS.md')"
check "build guide is not tracked" test -z "$(git ls-files -- '*BUILD_GUIDE.md')"
check "release checklist is not tracked" test -z "$(git ls-files -- RELEASE_CHECKLIST.md)"
check "no developer home path" test -z "$(rg -l '/home/hiro|/Users/' --glob '!tests/repository-check.sh' --glob '!AGENTS.md' . | head -1)"
check "helper syntax" bash -n scripts/desktop-modesctl
check "test runner syntax" bash -n tests/run.sh

printf '\nRepository checks: %s\n' "$([[ "$failed" -eq 0 ]] && echo passed || echo failed)"
exit "$failed"
