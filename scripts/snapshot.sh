#!/usr/bin/env bash
set -euo pipefail
HOST=$(hostname -s)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="snapshots/${HOST}/${STAMP}"
mkdir -p "$OUT"

# 서비스 요약
systemctl --no-pager --type=service \
  'flagship-seoulmake.service' 'sidekiq@*.service' 'sidekiq-flagship@*.service' \
  > "$OUT/services.txt" || true

# 리슨 포트
ss -ltnp > "$OUT/ports.txt" || true

# ENV(민감정보 마스킹)
if [ -f /etc/flagship-seoulmake.env ]; then
  sed -E 's/(OPS_READ_TOKEN=).*/\1[REDACTED]/' /etc/flagship-seoulmake.env \
    > "$OUT/env.flagship-seoulmake.env" || true
fi

# 운영 엔드포인트 스냅샷
TOK="$(grep -oP '^OPS_READ_TOKEN=\K.*' /etc/flagship-seoulmake.env || true)"
if [ -n "$TOK" ]; then
  curl -s -H "X-Ops-Token: $TOK" http://127.0.0.1:3000/atr/admin/ops \
    > "$OUT/ops.json" || true
fi

echo "OK: $OUT"
