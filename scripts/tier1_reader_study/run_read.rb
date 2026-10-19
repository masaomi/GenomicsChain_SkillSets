# frozen_string_literal: true

# One read: one document, one configuration, one repetition.
#
#   ruby scripts/tier1_reader_study/run_read.rb <P|V0|V1> <config-id> <rep 1..3>
#   ruby scripts/tier1_reader_study/run_read.rb --pilot <config-id>
#
# Refuses to overwrite an existing read. The start is logged before the call
# and the end after it, so a read that dies midway still leaves a trace.

require_relative 'study'

S = ReaderStudy
pilot = ARGV.delete('--pilot')
if pilot
  doc = 'PILOT'
  cfg = S.config(ARGV[0] || abort('usage: --pilot <config-id>'))
  rep = 0
  dir = File.join(S::OUT, 'pilot', cfg[:id], S.now.tr(':', ''))
else
  doc, cfg_id, rep_s = ARGV
  abort 'usage: run_read.rb <P|V0|V1> <config-id> <rep>' unless S::DOC_ORDER.include?(doc) && rep_s
  cfg = S.config(cfg_id)
  rep = Integer(rep_s)
  abort 'rep must be 1..3' unless (1..3).cover?(rep)
  dir = File.join(S::OUT, 'reads', doc, cfg[:id], "rep#{rep}")
  abort "#{dir}/record.json exists; a read is never re-run" if File.exist?(File.join(dir, 'record.json'))
end
FileUtils.mkdir_p(dir)

expected_prompt_sha = pilot ? nil : S.manifest.dig('documents', doc, 'prompt_sha256')
log_path = File.join(S::OUT, pilot ? 'pilot_runs.jsonl' : 'runs.jsonl')
log = ->(h) { File.open(log_path, 'a') { |f| f.puts(JSON.generate(h)) } }
key = { 'doc' => doc, 'config' => cfg[:id], 'rep' => rep }
log.call(key.merge('event' => 'start', 'at' => S.now))

BACKOFF = [60, 300].freeze
attempts = []
prompt_sha = nil

llm = lambda do |payload|
  prompt = S.flatten(payload)
  prompt_sha = S.sha(prompt)
  if expected_prompt_sha && prompt_sha != expected_prompt_sha
    raise "prompt #{prompt_sha} differs from the frozen #{expected_prompt_sha}; not sent"
  end

  parsed = nil
  (BACKOFF.size + 1).times do |i|
    started = S.now
    cli = S.run_cli(cfg, prompt)
    File.binwrite(File.join(dir, "attempt#{i + 1}.stdout"), cli[:stdout])
    File.binwrite(File.join(dir, "attempt#{i + 1}.stderr"), cli[:stderr])
    parsed = S.parse(cfg, cli[:stdout])
    failed = S.transport_failure?(cli, parsed)
    attempts << { 'attempt' => i + 1, 'started_at' => started, 'finished_at' => S.now,
                  'argv' => cli[:argv], 'env' => cli[:env], 'exit' => cli[:exit], 'seconds' => cli[:seconds],
                  'timed_out' => cli[:timed_out], 'stdout_sha256' => S.sha(cli[:stdout]),
                  'stdout_bytes' => cli[:stdout].bytesize, 'stderr_tail' => cli[:stderr].to_s[-600..] || cli[:stderr],
                  'transport_failure' => failed,
                  'cli_report' => parsed.reject { |k, _| k == :text }.transform_keys(&:to_s) }
    break unless failed
    sleep BACKOFF[i] if BACKOFF[i]
  end

  if parsed[:text].to_s.strip.empty?
    { 'status' => 'error', 'error' => "no answer after #{attempts.size} attempt(s)" }
  else
    File.binwrite(File.join(dir, 'answer.txt'), parsed[:text])
    { 'status' => 'ok', 'response' => { 'content' => parsed[:text] }, 'provider' => "#{cfg[:family]}-cli",
      'model' => Array(parsed[:model_returned]).first || cfg[:model] }
  end
end

outcome = nil
error = nil
result = nil
begin
  result = S::A::Assessor.new(llm: llm).run(S.assess_args(doc))
  File.write(File.join(dir, 'report.json'), result['report_json'])
  outcome = 'assessed'
rescue StandardError => e
  error = { 'class' => e.class.name, 'message' => e.message.to_s[0, 2000] }
  outcome = attempts.empty? || attempts.last['transport_failure'] ? 'failed' : 'invalid'
end

record = key.merge(
  'study' => S::STUDY_ID, 'pilot' => !pilot.nil?, 'configuration' => cfg.transform_keys(&:to_s),
  'prompt_sha256' => prompt_sha, 'prompt_sha256_expected' => expected_prompt_sha,
  'outcome' => outcome, 'error' => error, 'attempts' => attempts,
  'report_sha256' => result && S.sha(result['report_json']),
  'counts' => result&.dig('derived', 'counts'), 'guards' => result&.dig('guards'),
  'recorded_at' => S.now
)
File.write(File.join(dir, 'record.json'), JSON.pretty_generate(record) + "\n")
log.call(key.merge('event' => 'end', 'at' => S.now, 'outcome' => outcome,
                   'counts' => record['counts'], 'attempts' => attempts.size))
puts "#{doc} #{cfg[:id]} rep#{rep}: #{outcome} #{record['counts']&.slice('S', 'n_RI', 'n_NI', 'n_X')} #{error&.dig('message')}"
