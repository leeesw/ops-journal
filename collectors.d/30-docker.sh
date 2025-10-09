#!/usr/bin/env bash
# LITE: docker ps 요약 (없으면 빈 배열)
set -euo pipefail
HOST="${1:-unknown}"; OUT="${2:-hosts/${HOST}/unknown}"
COL="$OUT/.collect"; mkdir -p "$COL"

if ! command -v docker >/dev/null 2>&1; then
  jq -n '{containers: []}' > "$COL/components.30-docker.json"
  exit 0
fi

# Docker daemon 접근 실패해도 빈 배열
if ! docker info >/dev/null 2>&1; then
  jq -n '{containers: []}' > "$COL/components.30-docker.json"
  exit 0
fi

# 필요한 소수 필드만 추출 (이름, 이미지(tag), 상태, 포트 개수)
data="$(docker ps --format '{{json .}}' | jq -r '. | {name:.Names, image:.Image, status:.Status, ports: ( (.Ports // "") | split(",") | length ) }' 2>/dev/null | jq -s . 2>/dev/null || echo '[]')"

jq -n --argjson arr "${data:-[]}" '{containers: $arr}' | jq -S > "$COL/components.30-docker.json"

# (옵션) 그래프 엣지 생성은 이후 필요 시 추가. 지금은 LITE 안정성 우선으로 생략.
# 예: echo '{"src":"web","dst":"traefik","kind":"depends_on"}' >> "$COL/graph.ndjson"
