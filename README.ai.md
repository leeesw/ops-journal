[![schema-verify](https://github.com/leeesw/ops-journal/actions/workflows/schema-verify.yml/badge.svg)](https://github.com/leeesw/ops-journal/actions/workflows/schema-verify.yml)

# ops-journal · AI Onboarding (Day-0)

## TL;DR (3줄)
```bash
git clone https://github.com/leeesw/ops-journal
cd ops-journal
make snapshot-lite verify
```

---

## FULL 모드 (증거는 URI만 남김)
LITE 대비, FULL은 **원본 파일을 커밋하지 않고** `evidence_uri` 목록만 기록합니다.
- 허용 스킴: `https://`, `http://`, `s3://`, `gs://`
- 예시(로컬 로그 2개를 외부 보관소에 업로드해 URI로만 기록한다고 가정):
```bash
EVIDENCE_URI_PREFIX="https://evidence.example.local/ops" \
EVIDENCE_FILES="/var/log/syslog /var/log/dpkg.log" \
make publish-full MSG="chore: add FULL snapshot ($(date -u +%FT%TZ))"
