SHELL := /bin/bash
HOST ?= seoulmake-ec2
N ?= 30
TYPE ?= full
STAMP := $(shell date -u +"%Y-%m-%dT%H-%M-%SZ")
OUTDIR ?= hosts/$(HOST)/$(STAMP)
LITE_BUDGET := 307200 # 300KB

.PHONY: snapshot-lite verify sample

snapshot-lite:
	@scripts/snapshot-lite.sh "$(HOST)" "$(OUTDIR)" "$(LITE_BUDGET)"

verify:
	@echo "[verify] schema + budget + ndjson line checks"
	@command -v jq >/dev/null || (echo "jq missing"; exit 1)
	@AJV="npx --yes ajv-cli@5 --spec=draft2020"; \
	OUT="$${OUTDIR:-$$(ls -d hosts/*/* 2>/dev/null | tail -n1)}"; \
	test -n "$$OUT" || { echo "no snapshot folder found under hosts/*/*"; exit 1; }; \
	echo "[verify] using $$OUT"; \
	test -s "$$OUT/manifest.json"   || { echo "missing $$OUT/manifest.json"; exit 1; }; \
	test -s "$$OUT/components.json" || { echo "missing $$OUT/components.json"; exit 1; }; \
	$$AJV validate -s schemas/manifest.schema.json -r schemas/evidence-pointer.schema.json -d "$$OUT/manifest.json"; \
	$$AJV validate -s schemas/components.schema.json -d "$$OUT/components.json"; \
	awk 'NF' "$$OUT/graph.ndjson" | while read -r line; do \
		printf '%s\n' "$$line" > .ajv_tmp.json; \
		$$AJV validate -s schemas/graph.schema.json -d .ajv_tmp.json >/dev/null || { \
			echo "[ndjson] invalid line: $$line"; rm -f .ajv_tmp.json; exit 1; }; \
	done; \
	rm -f .ajv_tmp.json; \
	for rb in "$$OUT"/runbooks/*.json; do \
		[ -f "$$rb" ] && $$AJV validate -s schemas/runbook.schema.json -d "$$rb"; \
	done; \
	tools/size_guard.sh "$$OUT" "$(LITE_BUDGET)"

sample:
	@SAMPLE=samples/hosts/seoulmake-ec2/2025-10-08T14-00-00Z ; \
	rm -rf "$$SAMPLE" && mkdir -p "$$SAMPLE" && \
	scripts/snapshot-lite.sh "seoulmake-ec2" "$$SAMPLE" "$(LITE_BUDGET)" >/dev/null 2>&1 || true && \
	echo "[sample] refreshed $$SAMPLE"

.PHONY: view publish publish-snapshot

view:
	@OUT="$${OUTDIR:-$$(ls -d hosts/*/* 2>/dev/null | tail -n1)}"; \
	test -n "$$OUT" || { echo "no snapshot under hosts/*/*; run 'make snapshot-lite' first"; exit 1; }; \
	tools/ai-snapshot-view.sh "$$OUT"

# 변경사항을 커밋하고 현재 브랜치로 push (메시지는 MSG= 로 오버라이드 가능)
publish:
	@set -e; \
	git rev-parse --is-inside-work-tree >/dev/null; \
	BR="$$(git rev-parse --abbrev-ref HEAD)"; \
	if git diff --quiet && git diff --cached --quiet; then \
	  echo "[publish] no changes to commit"; exit 0; \
	fi; \
	MSG="$${MSG:-chore: ops-journal autopush ($$(date -u +'%Y-%m-%dT%H:%M:%SZ'))}"; \
	git add -A; \
	git commit -m "$$MSG" || true; \
	git push -u origin "$$BR"; \
	echo "[publish] pushed $$BR"

# 스냅샷 생성+검증 후 방금 산출물만 commit & push
publish-snapshot:
	@set -e; \
	make snapshot-lite verify; \
	OUT="$$(ls -d hosts/*/* 2>/dev/null | tail -n1)"; \
	test -n "$$OUT"; \
	BR="$$(git rev-parse --abbrev-ref HEAD)"; \
	MSG="$${MSG:-chore: add LITE snapshot $$OUT}"; \
	git add "$$OUT/manifest.json" "$$OUT/components.json" "$$OUT/graph.ndjson" "$$OUT/runbooks/rollback.snapshot.json"; \
	git commit -m "$$MSG" || { echo "[publish-snapshot] nothing to commit"; exit 0; }; \
	git push -u origin "$$BR"; \
	echo "[publish-snapshot] pushed $$BR: $$OUT"

.PHONY: snapshot-full publish-full

snapshot-full:
	@scripts/snapshot-full.sh "$(HOST)" "$(OUTDIR)-FULL"

# FULL 산출물만 커밋/푸시 (evidence_uri만 기록)
publish-full:
	@set -e; \
	make snapshot-full; \
	OUT="$$(ls -d hosts/*/*-FULL 2>/dev/null | tail -n1)"; \
	test -n "$$OUT"; \
	make verify OUTDIR="$$OUT"; \
	BR="$$(git rev-parse --abbrev-ref HEAD)"; \
	MSG="$${MSG:-chore: add FULL snapshot $$OUT (evidence_uri only)}"; \
	git add "$$OUT/manifest.json" "$$OUT/components.json" "$$OUT/graph.ndjson" "$$OUT/runbooks/rollback.snapshot.json"; \
	git commit -m "$$MSG" || { echo "[publish-full] nothing to commit"; exit 0; }; \
	git push -u origin "$$BR"; \
	echo "[publish-full] pushed $$BR: $$OUT"

.PHONY: prune-old publish-prune-old
# 예) make prune-old                # HOST=$(HOST), N=30, TYPE=full
#     make prune-old HOST=seoulmake-ec2 N=50 TYPE=all DRY=1
prune-old:
	@HOST="${HOST}"; \
	N="${N:-30}"; \
	TYPE="${TYPE:-full}"; \
	DRY="${DRY:-0}"; \
	echo "[make prune-old] HOST=$$HOST N=$$N TYPE=$$TYPE DRY=$$DRY"; \
	DRY="$$DRY" tools/prune-old.sh "$$HOST" "$$N" "$$TYPE"

publish-prune-old:
	@set -e; \
	make prune-old N="${N:-30}" TYPE="${TYPE:-full}" ; \
	if git diff --quiet && git diff --cached --quiet; then \
	  echo "[publish-prune-old] no changes"; exit 0; \
	fi; \
	BR="$$(git rev-parse --abbrev-ref HEAD)"; \
	MSG="$${MSG:-chore: prune old snapshots (HOST=$${HOST:-*} TYPE=$${TYPE:-full} keep=$${N:-30})}"; \
	git add -A; \
	git commit -m "$$MSG" || true; \
	git push -u origin "$$BR"; \
	echo "[publish-prune-old] pushed $$BR"
