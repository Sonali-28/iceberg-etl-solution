#!/usr/bin/env bash
# Run any module under the package as a module so relative imports work.
# Usage: ./run_module.sh jobber_pipeline.extract [--config ...]
set -euo pipefail
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <module> [args...]"
  exit 2
fi
ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
MODULE="$1"
shift
PYTHONPATH="$ROOT_DIR/src" /usr/local/bin/python3 -m "$MODULE" "$@"
