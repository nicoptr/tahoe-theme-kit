#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bats tests/
env -u GDK_PIXBUF_MODULE_FILE python3 -m unittest tests/test_app.py
shellcheck -x install.sh tahoe-engine tahoe-kit lib/*.sh lib/steps/*.sh runtime/*.sh tests/run.sh tests/stubs/_stub tests/stubs/sudo
echo "shellcheck: clean"
