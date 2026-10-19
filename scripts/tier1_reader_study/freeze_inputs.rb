# frozen_string_literal: true

# Freeze the study's inputs once, before registration: copy each document's
# transformed text into log/<study>/inputs/, build the prompt each document will
# be sent as, and write manifest.json naming every hash the reads depend on.
# Refuses to run twice — a second freeze would be a different study.
#
#   ruby scripts/tier1_reader_study/freeze_inputs.rb

require_relative 'study'

S = ReaderStudy
abort "#{S.manifest_path} exists; inputs are already frozen" if File.exist?(S.manifest_path)
FileUtils.mkdir_p(S::INPUTS)

def file_sha(rel) = Digest::SHA256.file(File.join(S::ROOT, rel)).hexdigest

def capture(*cmd)
  out, = Open3.capture2e(*cmd)
  out.strip.lines.first.to_s.strip
rescue StandardError => e
  "unavailable: #{e.class}"
end

documents = {}
S::DOCUMENTS.each do |doc, d|
  raw = File.binread(File.join(S::ROOT, d[:source]))
  text = S.transform(raw, d[:transform])
  File.binwrite(S.input_path(doc), text)
  prompt = S.prompt_for(doc)
  File.binwrite(File.join(S::INPUTS, "prompt_#{doc}.txt"), prompt)
  documents[doc] = {
    'source' => d[:source], 'source_sha256' => S.sha(raw), 'transform' => d[:transform],
    'content_sha256' => S.sha(text), 'content_bytes' => text.bytesize, 'ref' => d[:ref],
    'source_declares_sha256' => d[:declare_sha256],
    'prompt_sha256' => S.sha(prompt), 'prompt_bytes' => prompt.bytesize
  }
end

code_files = %w[
  genomicschain_tier1/skillset.json
  genomicschain_tier1/knowledge/repro_tier1_guide.md
  genomicschain_tier1/assets/report_schema_v0_2_6.json
  genomicschain_tier1/lib/genomicschain_tier1.rb
  genomicschain_tier1/lib/genomicschain_tier1/assess/assessor.rb
  genomicschain_tier1/lib/genomicschain_tier1/assess/derivation.rb
  genomicschain_tier1/lib/genomicschain_tier1/assess/pre_commit.rb
  genomicschain_tier1/lib/genomicschain_tier1/assess/prompts.rb
  genomicschain_tier1/lib/genomicschain_tier1/assess/validator.rb
  .kairos/skillsets/llm_client/lib/llm_client/codex_adapter.rb
  scripts/tier1_reader_study/study.rb
  scripts/tier1_reader_study/freeze_inputs.rb
  scripts/tier1_reader_study/run_read.rb
  scripts/tier1_reader_study/run_plan.rb
  scripts/tier1_reader_study/analyze.rb
  scripts/tier1_reader_study/pilot_text.md
]

manifest = {
  'study' => S::STUDY_ID,
  'frozen_at' => S.now,
  'git_head' => capture('git', '-C', S::ROOT, 'rev-parse', 'HEAD'),
  'documents' => documents,
  'configurations' => S.configs.map { |c| c.transform_keys(&:to_s) },
  'code_sha256' => code_files.to_h { |f| [f, file_sha(f)] },
  'cli_versions' => {
    'claude' => capture('claude', '--version'),
    'codex' => capture('codex', '--version'),
    'cursor-agent' => capture('cursor-agent', '--version'),
    'ruby' => RUBY_DESCRIPTION
  },
  'rubric_hash' => S::A::PreCommit.rubric_hash
}
File.write(S.manifest_path, JSON.pretty_generate(manifest) + "\n")
documents.each { |doc, d| puts "#{doc}: content #{d['content_sha256'][0, 12]}  prompt #{d['prompt_sha256'][0, 12]} (#{d['prompt_bytes']} B)" }
puts "manifest #{S.sha(File.read(S.manifest_path))}"
