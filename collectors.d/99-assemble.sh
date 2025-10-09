#!/usr/bin/env bash
# 수집 조각 병합 -> components.json / graph.ndjson (결정적 정렬)
set -euo pipefail
HOST="${1:-unknown}"; OUT="${2:-hosts/${HOST}/unknown}"
COL="$OUT/.collect"; mkdir -p "$COL"

# components.*.json 병합
if ls "$COL"/components.*.json >/dev/null 2>&1; then
  jq -s '
    reduce .[] as $x (
      {services:[], containers:[], systemd:[], workers:[]};
      .services   += ($x.services   // [])
    | .containers += ($x.containers // [])
    | .systemd    += ($x.systemd    // [])
    | .workers    += ($x.workers    // [])
    )
    | .services   |= sort_by(tostring)
    | .containers |= sort_by(tostring)
    | .systemd    |= sort_by(tostring)
    | .workers    |= sort_by(tostring)
  ' "$COL"/components.*.json | jq -S > "$OUT/components.json"
else
  jq -n '{services:[],containers:[],systemd:[],workers:[]}' | jq -S > "$OUT/components.json"
fi

# graph 병합 (있으면 uniq 정렬, 없으면 빈 파일)
if [ -f "$COL/graph.ndjson" ]; then
  awk 'NF' "$COL/graph.ndjson" | sort -u > "$OUT/graph.ndjson"
else
  : > "$OUT/graph.ndjson"
fi
