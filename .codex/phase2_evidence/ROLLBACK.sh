#!/usr/bin/env sh
set -eu
target=${1:?target copy required}
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
printf '%s\n' 'phase1 fixture' > "$target"
cmp -s "$target" "$dir/PRISTINE_FILE.txt"
