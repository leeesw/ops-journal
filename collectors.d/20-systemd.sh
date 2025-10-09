#!/usr/bin/env bash
# LITE: systemd 요약 (running/failed 카운트 + 재시작 상위 N)
set -euo pipefail
HOST="${1:-unknown}"; OUT="${2:-hosts/${HOST}/unknown}"
COL="$OUT/.collect"; mkdir -p "$COL"

running=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l || echo 0)
failed=$(systemctl list-units --type=service --state=failed  --no-legend 2>/dev/null | wc -l || echo 0)

# 재시작 상위 N (최대 5, 스캔 상한 100)
N=5
mapfile -t units < <(systemctl list-units --type=service --all --no-legend 2>/dev/null | awk '{print $1}' | head -n 100 || true)
tmp="$(mktemp)"; : > "$tmp"
for u in "${units[@]}"; do
  nr="$(systemctl show "$u" -p NRestarts --value 2>/dev/null || echo 0)"
  [[ "$nr" =~ ^[0-9]+$ ]] || nr=0
  if (( nr > 0 )); then
    printf "%s %s\n" "$nr" "$u" >>"$tmp"
  fi
done
top_json=$( (sort -rn "$tmp" 2>/dev/null | head -n "$N" | awk '{printf "{\"unit\":\"%s\",\"n_restarts\":%s}\n",$2,$1}' | jq -s .) 2>/dev/null || echo '[]' )
rm -f "$tmp"

jq -n --argjson top "${top_json:-[]}" --argjson running "$running" --argjson failed "$failed" \
'{
  systemd: (
    [ {summary:true, running:$running, failed:$failed} ]
    + $top
  )
}' | jq -S > "$COL/components.20-systemd.json"
