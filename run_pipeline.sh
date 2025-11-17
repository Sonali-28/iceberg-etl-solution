#!/usr/bin/env bash
# Lightweight wrapper to run the full pipeline from repo root.
# Usage: ./run_pipeline.sh
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
PYTHONPATH="$ROOT_DIR/src"

echo "Running pipeline (config: config/pipeline_config.yml)"
PYTHONPATH="$PYTHONPATH" /usr/local/bin/python3 -m jobber_pipeline.main --config "$ROOT_DIR/config/pipeline_config.yml"
