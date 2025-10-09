#!/usr/bin/env bash
set -euo pipefail
DIR="${1:?dir}"; BUDGET="${2:?budget_bytes}"
BYTES=$( (command -v gdu >/dev/null && gdu -sb "$DIR" || du -sb "$DIR") | awk '{print $1}')
if (( BYTES > BUDGET )); then
  echo "[size_guard] FAIL: ${BYTES} > ${BUDGET} bytes"
  exit 1
fi
echo "[size_guard] OK: ${BYTES}/${BUDGET} bytes"
