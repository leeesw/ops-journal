#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'

path = ARGV[0] || '/home/ubuntu/ops-journal/Makefile'
abort "Makefile not found: #{path}" unless File.file?(path)

orig = File.read(path, mode: 'r', encoding: 'UTF-8')
backup = "#{path}.bak.#{Time.now.utc.strftime('%Y%m%d%H%M%S')}"
FileUtils.cp(path, backup)

content = orig.dup
changed = false

# ① snapshot-full: OUTDIR → OUTDIR-FULL (레시피 라인 어디서든)
content.gsub!(%r{^(\s*@?\s*scripts/snapshot-full\.sh\s+"?\$\((?:HOST)\)"?\s+"?\$\((?:OUTDIR)\)"?)(\s*(?:\\)?\s*)$}m) do
  changed = true
  pre, suf = $1, $2
  pre.sub('$(OUTDIR)"', '$(OUTDIR)-FULL"').sub("$(OUTDIR)'", "$(OUTDIR)-FULL'").sub('$(OUTDIR)', '$(OUTDIR)-FULL') + suf
end

# ② publish-full 블록 통째 교체
new_block = [
  "publish-full:",
  "\t@set -e; \\",
  "\tmake snapshot-full; \\",
  "\tOUT=\"$$(ls -d hosts/*/*-FULL 2>/dev/null | tail -n1)\"; \\",
  "\ttest -n \"$$OUT\"; \\",
  "\tmake verify OUTDIR=\"$$OUT\"; \\",
  "\tBR=\"$$(git rev-parse --abbrev-ref HEAD)\"; \\",
  "\tMSG=\"$$\{MSG:-chore: add FULL snapshot $$OUT (evidence_uri only)\}\"; \\",
  "\tgit add \"$$OUT/manifest.json\" \"$$OUT/components.json\" \"$$OUT/graph.ndjson\" \"$$OUT/runbooks/rollback.snapshot.json\"; \\",
  "\tgit commit -m \"$$MSG\" || { echo \"[publish-full] nothing to commit\"; exit 0; }; \\",
  "\tgit push -u origin \"$$BR\"; \\",
  "\techo \"[publish-full] pushed $$BR: $$OUT\"",
  ""
].join("\n")

content.sub!(/(?m)^publish-full:\n(?:\t.*\n)+/) do
  changed = true
  new_block
end

if changed
  File.write(path, content, mode: 'w', encoding: 'UTF-8')
  puts "[OK] Patched #{path}"
  puts "     - Backup: #{backup}"
else
  puts "[NOOP] Nothing changed in #{path}"
  puts "       (already patched?)"
end
