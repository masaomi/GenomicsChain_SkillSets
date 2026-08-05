# frozen_string_literal: true

# Live probe: run gc_tier1_assess's assessment path against a REAL provider.
#
# Not part of the test suite — it spends an LLM call and needs network. It exists
# because everything in assess_test.rb stubs the assessor, so the seam between
# llm_client's response envelope and Assessor#extract_fields is otherwise never
# exercised. That seam is where the first live run breaks.
#
#   ruby genomicschain_tier1/test/live_assess_probe.rb <jats.xml|paper.txt> <doi> [out.json]
#
# Compares nothing on its own; print the result beside the corpus report for the
# same DOI to see whether the tool and the hand-driven assessors agree.
#
# Prefer feeding it TEXT. genomicschain.ch's PaperRetrieval::JatsText is the real
# converter and the only one a submitted paper goes through; the XML path below
# is a fallback for a local file and is deliberately cruder.

require 'json'
require 'yaml'
require 'digest'

root = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(root, 'genomicschain_core', 'lib'))
$LOAD_PATH.unshift(File.join(root, 'genomicschain_tier1', 'lib'))

require 'kairos_mcp/version'
require 'kairos_mcp/tools/base_tool'
require 'genomicschain_tier1'

LLM_DIR = File.join(root, '.kairos', 'skillsets', 'llm_client')
require File.join(LLM_DIR, 'lib', 'llm_client', 'call_router')

A = KairosMcp::SkillSets::GenomicschainTier1::Assess

# JATS carries the sections the rubric actually reads (Methods, Data
# availability, Code availability). Strip markup, keep section titles, and let
# the assessor see the structure.
#
# <back> is KEPT. The availability statement lives there, not in <back>'s
# neighbours, and dropping it was silently removing the single most load-bearing
# passage in a Tier-1 assessment: the 2026-08-04 runs were scored against a paper
# whose data and code availability section had been deleted before the assessor
# saw it. Only <ref-list> goes.
def jats_to_text(xml)
  text = xml.dup
  text.gsub!(%r{<(ref-list|fn-group|table-wrap|graphic|xref)\b.*?</\1>}m, ' ')
  text.gsub!(/<title[^>]*>(.*?)<\/title>/m) { "\n\n## #{::Regexp.last_match(1)}\n" }
  text.gsub!(/<p[^>]*>/, "\n")
  text.gsub!(/<[^>]+>/, ' ')
  text.gsub!(/&lt;/, '<').gsub!(/&gt;/, '>').gsub!(/&amp;/, '&')
  text.gsub!(/[ \t]+/, ' ')
  text.gsub!(/\n{3,}/, "\n\n")
  text.strip
end

usage = 'usage: live_assess_probe.rb <jats.xml|paper.txt> <doi> [out.json]'
source_path = ARGV[0] or abort usage
doi = ARGV[1] or abort usage
out_path = ARGV[2]

raw = File.read(source_path)
xml = raw.lstrip.start_with?('<')
text = xml ? jats_to_text(raw) : raw.strip
warn "[probe] source: #{source_path} (#{xml ? 'JATS' : 'text'}) -> #{text.bytesize} bytes of text"
warn '[probe] WARNING: no availability section found in the text' unless text.match?(/availab/i)

config = YAML.safe_load(File.read(File.join(LLM_DIR, 'config', 'llm_client.yml'))) || {}
# A whole paper is far past the adapter's 120s default.
config['timeout_seconds'] = 1800
# The rubric is the assessor's whole brain; a downgraded model is a different
# assessor, so pin it rather than letting the CLI route.
warn "[probe] provider=#{config['provider']} model=#{config['model']} timeout=#{config['timeout_seconds']}s"

llm = lambda do |payload|
  started = Time.now
  result = KairosMcp::SkillSets::LlmClient::CallRouter.perform(payload.compact.transform_keys(&:to_s), config)
  warn "[probe] llm returned status=#{result['status']} in #{(Time.now - started).round}s"
  result
end

assessor = A::Assessor.new(llm: llm)
out = assessor.run(
  'canonical_id' => { 'value' => doi, 'kind' => 'doi' },
  'sources' => [{ 'kind' => 'paper_text', 'ref' => File.basename(source_path),
                  'content' => text, 'sha256' => Digest::SHA256.hexdigest(text) }],
  'funnel_stage' => 'stage1-prose-only',
  'assessor_id' => "gc_tier1_assess/0.1 live probe (#{config['provider']}:#{config['model']})",
  'operator_id' => 'masaomi'
)

File.write(out_path, JSON.pretty_generate(out)) if out_path
puts JSON.pretty_generate(
  'status' => out['status'],
  'counts' => out.dig('derived', 'counts'),
  'levers' => out.dig('derived', 'levers'),
  'capture_claim' => out.dig('derived', 'capture_claim'),
  'stage2_candidate' => out.dig('derived', 'stage2_candidate'),
  'static_readiness' => out.dig('derived', 'headline', 'static_readiness'),
  'guards' => out['guards']
)
