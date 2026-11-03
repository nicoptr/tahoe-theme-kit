#!/usr/bin/env bash
set -euo pipefail
REPO_DIR=$(cd "$(dirname "$0")" && pwd)
source "$REPO_DIR/lib/common.sh"
for step_file in "$REPO_DIR"/lib/steps/*.sh; do source "$step_file"; done

STEPS=(preflight packages upstream assets theme icons extensions settings switchcraft gtk4 ghostty gdm plymouth nvidia finish)

load_variant "${1:-}"
for i in "${!STEPS[@]}"; do
  log "==> [$((i + 1))/${#STEPS[@]}] ${STEPS[i]}"
  "step_${STEPS[i]}"
done
