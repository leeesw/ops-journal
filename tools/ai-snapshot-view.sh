#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-}"
if [ -z "$OUT" ]; then
  OUT="$(ls -d hosts/*/* 2>/dev/null | tail -n1 || true)"
fi
if [ -z "${OUT:-}" ] || [ ! -d "$OUT" ]; then
  echo "no snapshot under hosts/*/*; run 'make snapshot-lite' first" >&2
  exit 1
fi
echo "== OUT: $OUT =="
echo
echo "== manifest =="
jq '{host, timestamp_utc, version, size_guard}' "$OUT/manifest.json"

echo
echo "== systemd summary =="
jq '.systemd | map(select(.summary==true))[0]' "$OUT/components.json"

echo
echo "== docker (first 5) =="
jq '.containers | .[:5]' "$OUT/components.json"
