#!/usr/bin/env bash
set -euo pipefail
HOST="${1:-seoulmake-ec2}"
OUT="${2:-hosts/${HOST}/$(date -u +"%Y-%m-%dT%H-%M-%SZ")}"
BUDGET="${3:-307200}"

mkdir -p "${OUT}/runbooks"
timestamp_utc="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
local_tz="$(date +%Z)"

# --- minimal signals (keep tiny & deterministic) ---
os="$(uname -s || true)"; kernel="$(uname -r || true)"
containers_json='[]'
systemd_json='[]'
services_json='[]'
workers_json='[]'

# components.json
jq -n --argjson services "$services_json" \
      --argjson containers "$containers_json" \
      --argjson systemd "$systemd_json" \
      --argjson workers "$workers_json" \
'{
  services: $services,
  containers: $containers,
  systemd: $systemd,
  workers: $workers
}' | jq -S > "${OUT}/components.json"

# graph.ndjson (example)
{
  echo '{"src":"web","dst":"traefik","kind":"depends_on"}'
  echo '{"src":"web","dst":"wp-mariadb","kind":"reads_from"}'
  echo '{"src":"jobs","dst":"redis","kind":"talks_to"}'
} > "${OUT}/graph.ndjson"

# runbook example
jq -n '{
  name: "rollback.snapshot",
  steps: [
    "git revert -m 1 <merge_commit_sha>",
    "or: git checkout -B main <pin_sha> && git push -f origin main",
    "verify CI green, check size gate"
  ]
}' | jq -S > "${OUT}/runbooks/rollback.snapshot.json"

# manifest.json (size filled later)
jq -n --arg host "$HOST" --arg ts "$timestamp_utc" --arg ltz "$local_tz" \
'{
  host: $host,
  timestamp_utc: $ts,
  local_tz: $ltz,
  version: "v1.1",
  collectors: ["snapshot-lite.sh"],
  size_guard: { bytes_total: 0, lite_budget_bytes: 307200 },
  evidence_uri: []
}' | jq -S > "${OUT}/manifest.json"

# compute size and patch manifest
BYTES=$( (command -v gdu >/dev/null && gdu -sb "$OUT" || du -sb "$OUT") | awk '{print $1}')
jq --argjson bytes "$BYTES" \
  '.size_guard.bytes_total = $bytes' "${OUT}/manifest.json" | jq -S > "${OUT}/.manifest.tmp"
mv "${OUT}/.manifest.tmp" "${OUT}/manifest.json"

echo "[snapshot-lite] created ${OUT} (bytes=${BYTES}, budget=${BUDGET})"
