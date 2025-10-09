# ops-journal · AI Onboarding (Day-0)

## TL;DR (3줄)
```bash
git clone https://github.com/leeesw/ops-journal
cd ops-journal
make snapshot-lite verify
```

## 이게 뭘 하죠?
- **snapshot-lite**: 현재 호스트의 운영 요약을 스냅샷으로 생성  
  - `components.json`: host / systemd / docker 요약
  - `manifest.json`: 메타데이터(타임스탬프/버전/크기 가드)
  - `graph.ndjson`: 관계(지금은 LITE라 최소)
  - `runbooks/rollback.snapshot.json`: 롤백 절차 예시
- **verify**: 위 산출물을 **JSON Schema(AJV, draft2020)** + **NDJSON 라인별 검증** + **300KB 가드**로 점검

## 결과 빠르게 보기
```bash
OUT="$(ls -d hosts/*/* | tail -n1)"
jq '.host,.timestamp_utc,.size_guard' "$OUT/manifest.json"
jq '.systemd | map(select(.summary==true))[0]' "$OUT/components.json"
# (있으면) 요약 뷰어
make view
```
