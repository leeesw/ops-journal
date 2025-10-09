SHELL := /bin/bash
HOST ?= seoulmake-ec2
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
