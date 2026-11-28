#!/usr/bin/env bash
# Lance le dashboard FastAPI en production (via uvicorn).
# Utilisé par systemd : ExecStart=/opt/market-regime/dashboard/start.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "${PROJECT_DIR}/venv/bin/activate"

exec uvicorn dashboard.app:app \
  --app-dir "${PROJECT_DIR}" \
  --host 127.0.0.1 \
  --port 8000 \
  --workers 1 \
  --no-access-log
