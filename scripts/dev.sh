#!/usr/bin/env bash
# Deploy + compile in one shot.
set -euo pipefail
HERE="$(dirname "$0")"
"$HERE/deploy.sh" && "$HERE/compile.sh"
