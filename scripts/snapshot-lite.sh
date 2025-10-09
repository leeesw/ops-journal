#!/usr/bin/env bash
set -euo pipefail
HOST="${1:-seoulmake-ec2}"
OUT="${2:-hosts/${HOST}/$(date -u +"%Y-%m-%dT%H-%M-%SZ")}"
BUDGET="${3:-307200}"

mkdir -p "${OUT}/runbooks" "${OUT}/.collect"
timestamp_utc="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
local_tz="$(date +%Z)"

# 1) collectors 실행 (소프트-페일, 타임아웃 1s)
if ls collectors.d/*.sh >/dev/null 2>&1; then
  while IFS= read -r f; do
    base="$(basename "$f")"
    if [[ "$base" == "99-assemble.sh" ]]; then continue; fi
    ( timeout 1s "$f" "$HOST" "$OUT" ) >/dev/null 2>&1 || true
  done < <(ls collectors.d/*.sh | sort)
fi

# 2) assemble (수집물 병합)
if [ -x collectors.d/99-assemble.sh ]; then
  collectors.d/99-assemble.sh "$HOST" "$OUT"
else
  # Fallback (collectors 부재 시 최소 산출물)
  jq -n '{services:[],containers:[],systemd:[],workers:[]}' | jq -S > "${OUT}/components.json"
  : > "${OUT}/graph.ndjson"
fi

# 3) 롤백 런북 (예시)
jq -n '{
  name: "rollback.snapshot",
  steps: [
    "git revert -m 1 <merge_commit_sha>",
    "or: git checkout -B main <pin_sha> && git push -f origin main",
    "verify CI green, check size gate"
  ]
}' | jq -S > "${OUT}/runbooks/rollback.snapshot.json"

# 4) manifest.json (size는 마지막에 계산)
jq -n --arg host "$HOST" --arg ts "$timestamp_utc" --arg ltz "$local_tz" \
'{
  host: $host,
  timestamp_utc: $ts,
  local_tz: $ltz,
  version: "v1.2-lite",
  collectors: ["collectors.d/*"],
  size_guard: { bytes_total: 0, lite_budget_bytes: 307200 },
  evidence_uri: []
}' | jq -S > "${OUT}/manifest.json"

# 5) 전체 크기 계산 후 manifest 패치
BYTES=$( (command -v gdu >/dev/null && gdu -sb "$OUT" || du -sb "$OUT") | awk '{print $1}')
jq --argjson bytes "$BYTES" \
  '.size_guard.bytes_total = $bytes' "${OUT}/manifest.json" | jq -S > "${OUT}/.manifest.tmp"
mv "${OUT}/.manifest.tmp" "${OUT}/manifest.json"

echo "[snapshot-lite] created ${OUT} (bytes=${BYTES}, budget=${BUDGET} )"
