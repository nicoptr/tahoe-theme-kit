#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bats tests/
shellcheck -x install.sh lib/*.sh lib/steps/*.sh runtime/*.sh tests/run.sh tests/stubs/_stub tests/stubs/sudo
echo "shellcheck: clean"
