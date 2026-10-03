#!/usr/bin/env ruby
# frozen_string_literal: true

# S4c of the self-application design (docs/design/self_application_design_v0_1.md
# §10; selfapp/expected_v1.json): one launch of the checker A after the
# timestamp boundary, with its exact arguments and its exact output on disk.
#
#   ruby scripts/selfapp/s4c_launch.rb --tool gc_tier1_assess --args ARGS.json --label V0_t1_1
#   ruby scripts/selfapp/s4c_launch.rb --grade-bco BCO.json --label V0_t25
#
# --tool starts a fresh `kairos-chain` stdio server on the instance at
# --data-dir (so it loads the packages installed by S4b, not whatever an
# already running server loaded), sends initialize and one tools/call whose
# arguments are the bytes of ARGS.json parsed as JSON, and stops the server.
# Arguments are never retyped: a Tier-1 run's paper_text must be the
# manuscript byte for byte, because its sha256 is the canonical_id.
#
# --grade-bco is Tier 2.5, which has no MCP tool: it loads A from
# <data-dir>/skillsets and calls the same function the DDC harness calls,
# GenomicsChainProv::Predicate.grade(Adapters::Bco.parse(bco)).
#
# Before anything starts, a "start" line is appended to the launch log
# (append-only, never edited); an "end" line follows. The order of start
# lines is the order of launches, which is what decides the counted runs
# (expected_v1.json rules.tier1_k). Writes to --out-root/<seq>_<label>/:
# args.json (copy), request.jsonl (what was sent), response.json (the raw
# tools/call response or the grade), result.txt (the tool's text), meta.json.

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'timeout'

opts = { data_dir: '.kairos', out_root: 'log/selfapp/s4c/launches', log: 'log/selfapp/s4c/launches.jsonl',
         timeout: 3600 }
OptionParser.new do |o|
  o.on('--tool NAME') { |v| opts[:tool] = v }
  o.on('--args FILE') { |v| opts[:args] = v }
  o.on('--grade-bco FILE') { |v| opts[:bco] = v }
  o.on('--label LABEL') { |v| opts[:label] = v }
  o.on('--data-dir DIR') { |v| opts[:data_dir] = v }
  o.on('--out-root DIR') { |v| opts[:out_root] = v }
  o.on('--log FILE') { |v| opts[:log] = v }
  o.on('--timeout SECONDS', Integer) { |v| opts[:timeout] = v }
end.parse!

abort 'run from the repository root' unless File.directory?('.git')
abort 'give --label' unless opts[:label]&.match?(/\A[A-Za-z0-9_.-]+\z/)
abort 'give exactly one of --tool (with --args) or --grade-bco' unless opts[:tool].nil? ^ opts[:bco].nil?
abort '--tool needs --args' if opts[:tool] && !opts[:args]

data_dir = File.realpath(opts[:data_dir])
input_file = opts[:args] || opts[:bco]
input_bytes = File.binread(input_file)
input_json = JSON.parse(input_bytes)
kind = opts[:tool] || 'tier25_grade'

FileUtils.mkdir_p(opts[:out_root])
FileUtils.mkdir_p(File.dirname(opts[:log]))
seq = File.exist?(opts[:log]) ? File.readlines(opts[:log]).count { |l| JSON.parse(l)['event'] == 'start' } + 1 : 1
out = File.join(opts[:out_root], format('%03d_%s', seq, opts[:label]))
abort "#{out} exists" if File.exist?(out)

log_line = lambda do |h|
  File.open(opts[:log], 'a') { |f| f.flock(File::LOCK_EX); f.write("#{JSON.generate(h)}\n") }
end

started = Time.now.utc
log_line.call('event' => 'start', 'seq' => seq, 'utc' => started.iso8601(3), 'kind' => kind, 'label' => opts[:label],
              'input_file' => input_file, 'input_sha256' => Digest::SHA256.hexdigest(input_bytes), 'out' => out)
FileUtils.mkdir_p(out)
File.binwrite(File.join(out, opts[:tool] ? 'args.json' : 'bco.json'), input_bytes)

meta = { 'seq' => seq, 'label' => opts[:label], 'kind' => kind, 'started_at' => started.iso8601(3),
         'input_file' => input_file, 'input_sha256' => Digest::SHA256.hexdigest(input_bytes),
         'data_dir' => data_dir, 'launcher_sha256' => Digest::SHA256.file(__FILE__).hexdigest,
         'ruby' => RUBY_VERSION }
status = 'error'

begin
  if opts[:tool]
    requests = [
      { 'jsonrpc' => '2.0', 'id' => 1, 'method' => 'initialize',
        'params' => { 'protocolVersion' => '2025-06-18', 'capabilities' => {},
                      'clientInfo' => { 'name' => 'selfapp_s4c_launch', 'version' => '0.1.0' } } },
      { 'jsonrpc' => '2.0', 'method' => 'notifications/initialized' },
      { 'jsonrpc' => '2.0', 'id' => 2, 'method' => 'tools/call',
        'params' => { 'name' => opts[:tool], 'arguments' => input_json } }
    ]
    File.write(File.join(out, 'request.jsonl'), requests.map { |r| "#{JSON.generate(r)}\n" }.join)
    responses = {}
    stderr_text = +''
    Open3.popen3('kairos-chain', '--data-dir', data_dir) do |stdin, stdout, stderr, wait|
      meta['server_pid'] = wait.pid
      err_reader = Thread.new { stderr_text << stderr.read.to_s }
      reader = lambda do |id|
        Timeout.timeout(opts[:timeout]) do
          loop do
            line = stdout.gets or raise "server closed stdout before response #{id}"
            msg = (JSON.parse(line) rescue nil)
            next unless msg.is_a?(Hash) && msg['id'] == id

            return msg
          end
        end
      end
      stdin.write("#{JSON.generate(requests[0])}\n")
      stdin.flush
      responses['initialize'] = reader.call(1)
      stdin.write("#{JSON.generate(requests[1])}\n#{JSON.generate(requests[2])}\n")
      stdin.flush
      responses['tools_call'] = reader.call(2)
      stdin.close
      Process.kill('TERM', wait.pid) unless wait.join(10)
      err_reader.join(5)
    end
    File.write(File.join(out, 'server_stderr.txt'), stderr_text)
    meta['server_info'] = responses['initialize'].dig('result', 'serverInfo')
    call = responses['tools_call']
    File.write(File.join(out, 'response.json'), "#{JSON.pretty_generate(call)}\n")
    text = Array(call.dig('result', 'content')).map { |c| c['text'].to_s }.join
    File.write(File.join(out, 'result.txt'), text)
    status = if call['error'] then 'jsonrpc_error'
             elsif text.start_with?('Error:') then 'tool_error'
             else 'ok'
             end
    meta['result_sha256'] = Digest::SHA256.hexdigest(text)
  else
    # Loaded as ddc_harness.rb loads them, so the grade runs on the same code.
    root = File.join(data_dir, 'skillsets')
    require_relative 'ddc_common'
    DdcCommon::PACKAGES.each { |p| $LOAD_PATH.unshift(File.join(root, p, 'lib')) }
    %w[genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_tier3 genomicschain_prov].each { |f| require f }
    graded = GenomicsChainProv::Predicate.grade(GenomicsChainProv::Adapters::Bco.parse(input_json))
    text = "#{JSON.pretty_generate(graded)}\n"
    File.write(File.join(out, 'response.json'), text)
    File.write(File.join(out, 'result.txt'), text)
    meta['loaded_from'] = $LOADED_FEATURES.select { |f| f.start_with?("#{root}/") }.sort
    meta['result_sha256'] = Digest::SHA256.hexdigest(text)
    status = 'ok'
  end
rescue StandardError, Timeout::Error => e
  meta['exception'] = "#{e.class}: #{e.message}"
  File.write(File.join(out, 'exception.txt'), "#{e.class}: #{e.message}\n#{Array(e.backtrace).first(20).join("\n")}\n")
ensure
  finished = Time.now.utc
  meta['finished_at'] = finished.iso8601(3)
  meta['status'] = status
  File.write(File.join(out, 'meta.json'), "#{JSON.pretty_generate(meta)}\n")
  log_line.call('event' => 'end', 'seq' => seq, 'utc' => finished.iso8601(3), 'status' => status,
                'result_sha256' => meta['result_sha256'])
end

puts "#{seq} #{opts[:label]} #{kind}: #{status} (#{(Time.now.utc - started).round(1)} s) -> #{out}"
exit(status == 'ok' ? 0 : 1)
