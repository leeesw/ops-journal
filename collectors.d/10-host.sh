#!/usr/bin/env bash
# LITE: 호스트 요약(아주 소량) -> components.services 배열에 1개 요약 객체
set -euo pipefail
HOST="${1:-unknown}"; OUT="${2:-hosts/${HOST}/unknown}"
COL="$OUT/.collect"; mkdir -p "$COL"

os="$(uname -s 2>/dev/null || true)"
kernel="$(uname -r 2>/dev/null || true)"
pretty="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"

jq -n --arg host "$HOST" --arg os "$os" --arg kernel "$kernel" --arg pretty "$pretty" \
'{
  services: [
    { name:"host", host:$host, os:$os, kernel:$kernel, distro:$pretty }
  ]
}' | jq -S > "$COL/components.10-host.json"
