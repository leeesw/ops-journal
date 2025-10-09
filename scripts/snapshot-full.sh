#!/usr/bin/env bash
# FULL: 대용량 증거는 저장소에 넣지 않고 evidence_uri 목록만 기록
# 사용법:
#   EVIDENCE_FILES="/var/log/syslog /var/log/dpkg.log" scripts/snapshot-full.sh HOST OUTDIR
#   또는
#   EVIDENCE_URI_PREFIX="s3://my-bucket/ops-journal/$(hostname)/$(date -u +%F)" \
#     EVIDENCE_FILES="/var/log/syslog /var/log/dpkg.log" scripts/snapshot-full.sh HOST OUTDIR
set -euo pipefail

HOST="${1:-seoulmake-ec2}"
OUT="${2:-hosts/${HOST}/$(date -u +"%Y-%m-%dT%H-%M-%SZ")-FULL}"
BUDGET="${3:-307200}"

mkdir -p "${OUT}/runbooks" "${OUT}/.collect"
timestamp_utc="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
local_tz="$(date +%Z)"

# evidence_uri 만들기
files=()
if [ -n "${EVIDENCE_FILES:-}" ]; then
  # 공백/개행 구분 지원
  while read -r f; do
    [ -z "$f" ] && continue
    files+=("$f")
  done < <(printf '%s\n' $EVIDENCE_FILES)
fi

uris=()
for f in "${files[@]:-}"; do
  if [ -n "${EVIDENCE_URI_PREFIX:-}" ]; then
    base="$(basename "$f")"
    uris+=("${EVIDENCE_URI_PREFIX%/}/$base")
  else
    # 기본은 file:// 스킴
    [ -e "$f" ] && uris+=("file://$f")
  fi
done

# components.json: FULL은 정보 최소화(스키마 충족용 빈 배열)
jq -n '{services:[],containers:[],systemd:[],workers:[]}' | jq -S > "${OUT}/components.json"

# graph.ndjson: 기본 비워둠(필요시 외부 시스템 관계를 URI로만 기록)
: > "${OUT}/graph.ndjson"

# 롤백 런북
jq -n '{
  name: "rollback.snapshot",
  steps: [
    "git revert -m 1 <merge_commit_sha>",
    "or: git checkout -B main <pin_sha> && git push -f origin main",
    "verify CI green, check size gate"
  ]
}' | jq -S > "${OUT}/runbooks/rollback.snapshot.json"

# manifest.json
jq -n --arg host "$HOST" --arg ts "$timestamp_utc" --arg ltz "$local_tz" --argjson uris "$(printf '%s\n' "${uris[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" '
{
  host: $host,
  timestamp_utc: $ts,
  local_tz: $ltz,
  version: "v1.2-full",
  collectors: ["(external evidence)"],
  size_guard: { bytes_total: 0, lite_budget_bytes: 307200 },
  evidence_uri: $uris
}' | jq -S > "${OUT}/manifest.json"

# 사이즈 기록(리포에 저장되는 파일만)
BYTES=$( (command -v gdu >/dev/null && gdu -sb "$OUT" || du -sb "$OUT") | awk '{print $1}')
jq --argjson bytes "$BYTES" '.size_guard.bytes_total = $bytes' "${OUT}/manifest.json" | jq -S > "${OUT}/.manifest.tmp"
mv "${OUT}/.manifest.tmp" "${OUT}/manifest.json"

echo "[snapshot-full] created ${OUT} (bytes=${BYTES}, evidence_uri=${#uris[@]})"
