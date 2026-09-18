#!/usr/bin/env sh
set -eu
target=${1:?target copy required}
printf '%s\n' 'PHASE_1_EVIDENCE' 'state=baseline' > "$target"
