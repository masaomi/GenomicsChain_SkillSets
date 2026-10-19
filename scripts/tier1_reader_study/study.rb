# frozen_string_literal: true

# Tier-1 reader study (2026-10-18): shared definitions.
#
# Reuses the shipped genomicschain_tier1 package unchanged. Assessor#run takes the
# LLM as an injected callable, so everything except the call itself — gates,
# pre-commit, the prompt text, derivation, schema validation — is the package's
# own code. Only the reader varies: model, effort, and the CLI that carries the
# call. See PREREGISTRATION.md for what is fixed and why.

require 'json'
require 'digest'
require 'fileutils'
require 'open3'
require 'time'
require 'timeout'
require 'tmpdir'

module ReaderStudy
  ROOT = File.expand_path('../..', __dir__)
  STUDY_ID = 'tier1_reader_study_20261018'
  OUT = File.join(ROOT, 'log', STUDY_ID)
  INPUTS = File.join(OUT, 'inputs')

  $LOAD_PATH.unshift(File.join(ROOT, 'genomicschain_core', 'lib'))
  $LOAD_PATH.unshift(File.join(ROOT, 'genomicschain_tier1', 'lib'))
  require 'kairos_mcp/version'
  require 'kairos_mcp/tools/base_tool'
  require 'genomicschain_tier1'
  LLM_DIR = File.join(ROOT, '.kairos', 'skillsets', 'llm_client', 'lib', 'llm_client')
  require File.join(LLM_DIR, 'call_router')
  require File.join(LLM_DIR, 'codex_adapter')

  A = KairosMcp::SkillSets::GenomicschainTier1::Assess

  # One fixed input per document. `strip` reproduces genomicschain.ch's own
  # transform (ManuscriptText#call), so P carries the same identity as the hosted
  # run (6b1c5673…); V0/V1 are verbatim, as in self-application round 1.
  DOCUMENTS = {
    'P' => { source: 'docs/zenodo/genomicschain_tiers_preprint_v1.0/preprint.md', transform: 'strip',
             ref: 'preprint.md', declare_sha256: true },
    'V0' => { source: 'selfapp/synthetic_rnaseq_v1/synthetic_manuscript.md', transform: 'verbatim',
              ref: 'synthetic_manuscript.md', declare_sha256: false },
    'V1' => { source: 'selfapp/synthetic_rnaseq_v1_variants/V1/synthetic_manuscript.md', transform: 'verbatim',
              ref: 'synthetic_manuscript.md', declare_sha256: false },
    # Harness check only: a short fictional text, never part of the analysis.
    'PILOT' => { source: 'scripts/tier1_reader_study/pilot_text.md', transform: 'verbatim',
                 ref: 'pilot_text.md', declare_sha256: false }
  }.freeze
  DOC_ORDER = %w[P V0 V1].freeze

  EFFORTS = %w[low medium high xhigh].freeze
  CLAUDE_MODELS = { 'opus55' => 'claude-opus-5-5', 'fable51' => 'claude-fable-5-1',
                    'sonnet55' => 'claude-sonnet-5-5' }.freeze

  # Five streams run in parallel; reads within a stream run one at a time.
  def self.configs
    list = []
    CLAUDE_MODELS.each do |short, model|
      EFFORTS.each { |e| list << { id: "#{short}-#{e}", family: 'claude', stream: short, model: model, effort: e } }
    end
    EFFORTS.each { |e| list << { id: "astra-#{e}", family: 'codex', stream: 'astra', model: 'gpt-6-astra', effort: e } }
    list << { id: 'composer25', family: 'cursor', stream: 'composer25', model: 'composer-2.5', effort: nil }
    list
  end

  def self.config(id) = configs.find { |c| c[:id] == id } || abort("unknown config #{id}")

  def self.transform(bytes, how)
    text = bytes.dup.force_encoding('UTF-8').scrub
    how == 'strip' ? text.strip : text
  end

  def self.input_path(doc) = File.join(INPUTS, "#{doc}.txt")

  # Reads only the frozen copy, never the live source file.
  def self.content(doc)
    path = input_path(doc)
    # The pilot runs before the freeze, so it reads its (fictional) source.
    if doc == 'PILOT' && !File.exist?(path)
      return transform(File.binread(File.join(ROOT, DOCUMENTS['PILOT'][:source])), 'verbatim')
    end
    abort "missing frozen input #{path} (run freeze_inputs.rb)" unless File.exist?(path)
    File.binread(path).force_encoding('UTF-8')
  end

  def self.assess_args(doc)
    d = DOCUMENTS.fetch(doc)
    text = content(doc)
    sha = Digest::SHA256.hexdigest(text)
    source = { 'kind' => 'paper_text', 'ref' => d[:ref], 'content' => text }
    source['sha256'] = sha if d[:declare_sha256]
    {
      'canonical_id' => { 'value' => sha, 'kind' => 'text_sha256' },
      'sources' => [source],
      'funnel_stage' => 'stage1-prose-only',
      'assessor_id' => 'tier1_reader_study/0.1',
      'operator_id' => 'masaomi (author self-application)',
      'assessed_at' => '2026-10-18'
    }
  end

  # llm_client's CLI flattening (identical text in the claude_code, codex and
  # cursor adapters), so every configuration receives the same bytes.
  def self.flatten(payload)
    adapter = KairosMcp::SkillSets::LlmClient::CodexAdapter.new({})
    adapter.send(:build_prompt, payload['messages'], payload['system'], nil, payload['output_schema'])
  end

  # The prompt is a function of the document alone; computing it runs the
  # package's own gates and pre-commit through a callable that never sends.
  def self.prompt_for(doc)
    captured = nil
    probe = ->(payload) { captured = flatten(payload); raise 'probe-only' }
    begin
      A::Assessor.new(llm: probe).run(assess_args(doc))
    rescue RuntimeError => e
      raise unless e.message == 'probe-only'
    end
    captured
  end

  def self.manifest_path = File.join(OUT, 'manifest.json')

  def self.manifest
    abort "missing #{manifest_path} (run freeze_inputs.rb)" unless File.exist?(manifest_path)
    JSON.parse(File.read(manifest_path))
  end

  def self.sha(s) = Digest::SHA256.hexdigest(s)

  def self.now = Time.now.utc.iso8601(3)

  # Each call: a fresh empty working directory and, for Codex and Cursor, a
  # fresh home holding only what authenticates (see prepare_home). Prompt on
  # stdin. Returns { argv:, env:, stdout:, stderr:, exit:, seconds:, timed_out: }.
  def self.run_cli(cfg, prompt, timeout: 3600)
    Dir.mktmpdir('reader_study_') do |dir|
      Dir.mktmpdir('reader_study_home_') do |home|
        env = prepare_home(cfg, home)
        argv = argv_for(cfg).map { |a| a == :DIR ? dir : a }
        started = Time.now
        out = err = ''.b
        status = nil
        timed_out = false
        Open3.popen3(env, *argv, chdir: dir) do |stdin, stdout, stderr, wait|
          reader_out = Thread.new { stdout.read }
          reader_err = Thread.new { stderr.read }
          stdin.write(prompt)
          stdin.close
          unless wait.join(timeout)
            timed_out = true
            Process.kill('TERM', wait.pid) rescue nil
            sleep 5
            Process.kill('KILL', wait.pid) rescue nil
          end
          status = wait.value
          out = reader_out.value.to_s
          err = reader_err.value.to_s
        end
        { argv: argv.map { |a| a == dir ? '<fresh-empty-dir>' : a },
          env: env.transform_values { |v| v == home ? '<fresh-home>' : v }, stdout: out, stderr: err,
          exit: status&.exitstatus, seconds: (Time.now - started).round(1), timed_out: timed_out }
      end
    end
  end

  # What a fresh home contains, per family. In the 2026-10-18 harness check the
  # default homes leaked: Cursor read ~/.claude/skills/genomicschain_tier1/SKILL.md
  # on its own, and Codex listed the user's skills and plugins and had web search.
  #   claude  no home change (OAuth lives in the keychain; --tools "" leaves no tool)
  #   codex   CODEX_HOME = fresh dir with auth.json linked to ~/.codex/auth.json;
  #           config, rules, skills and plugins are therefore absent
  #   cursor  HOME = fresh dir with ~/Library/Keychains linked (auth) and a copy of
  #           ~/.cursor/cli-config.json whose permissions deny every read, write,
  #           shell, web fetch and MCP call, with web search not auto-accepted
  CURSOR_DENY = %w[Shell(*) Read(**) Write(**) WebFetch(*) Mcp(*:*)].freeze

  def self.prepare_home(cfg, home)
    case cfg[:family]
    when 'claude'
      CLAUDE_ENV.dup
    when 'codex'
      File.symlink(File.expand_path('~/.codex/auth.json'), File.join(home, 'auth.json'))
      { 'CODEX_HOME' => home }
    when 'cursor'
      FileUtils.mkdir_p([File.join(home, '.cursor'), File.join(home, 'Library')])
      File.symlink(File.expand_path('~/Library/Keychains'), File.join(home, 'Library', 'Keychains'))
      conf = JSON.parse(File.read(File.expand_path('~/.cursor/cli-config.json')))
      conf['permissions'] = { 'allow' => [], 'deny' => CURSOR_DENY }
      conf['autoAcceptWebSearch'] = false
      File.write(File.join(home, '.cursor', 'cli-config.json'), JSON.generate(conf))
      { 'HOME' => home }
    end
  end

  CODEX_DISABLED = %w[apps plugins skill_search browser_use browser_use_external computer_use shell_tool
                      multi_agent goals image_generation tool_suggest].freeze

  def self.argv_for(cfg)
    case cfg[:family]
    when 'claude'
      ['claude', '-p', '--system-prompt', '', '--model', cfg[:model], '--effort', cfg[:effort],
       '--tools', '', '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}', '--setting-sources', '',
       '--no-session-persistence', '--disable-slash-commands', '--output-format', 'json']
    when 'codex'
      ['codex', 'exec', '--sandbox', 'read-only', '--ignore-user-config', '--ignore-rules', '--ephemeral',
       '--skip-git-repo-check', '-C', :DIR, '-m', cfg[:model], '-c', "model_reasoning_effort=#{cfg[:effort]}",
       '-c', 'web_search=disabled', *CODEX_DISABLED.flat_map { |f| ['--disable', f] }, '--json', '-']
    when 'cursor'
      ['cursor-agent', '-p', '--model', cfg[:model], '--mode', 'ask', '--trust', '--workspace', :DIR,
       '--output-format', 'stream-json']
    end
  end

  CLAUDE_ENV = { 'CLAUDE_CODE_MAX_OUTPUT_TOKENS' => '64000' }.freeze

  # Parse each CLI's output into the answer text and what the CLI reports about
  # the call. Never guesses: a field the CLI does not report is nil.
  def self.parse(cfg, stdout)
    case cfg[:family]
    when 'claude' then parse_claude(stdout)
    when 'codex' then parse_codex(stdout)
    when 'cursor' then parse_cursor(stdout)
    end
  end

  def self.parse_claude(stdout)
    d = JSON.parse(stdout)
    { text: d['result'], model_returned: (d['modelUsage'] || {}).keys, usage: d['usage'],
      stop_reason: d['stop_reason'], is_error: d['is_error'], tool_calls: Array(d['permission_denials']),
      cost_usd_reported: d['total_cost_usd'], num_turns: d['num_turns'] }
  rescue JSON::ParserError
    { text: nil, parse_error: 'stdout is not JSON' }
  end

  def self.parse_codex(stdout)
    events = stdout.each_line.filter_map { |l| JSON.parse(l) rescue nil }
    items = events.select { |e| e['type'] == 'item.completed' }.map { |e| e['item'] }
    messages = items.select { |i| i['type'] == 'agent_message' }
    tools = items.reject { |i| %w[agent_message reasoning].include?(i['type']) }
    done = events.reverse.find { |e| e['type'] == 'turn.completed' }
    errors = events.select { |e| %w[error turn.failed].include?(e['type']) }
    { text: messages.last&.dig('text'), model_returned: nil, usage: done&.dig('usage'),
      stop_reason: done ? 'turn.completed' : nil, is_error: !errors.empty? || done.nil?,
      tool_calls: tools.map { |t| t.slice('type', 'server', 'tool', 'command', 'query', 'status', 'error') },
      errors: errors,
      n_agent_messages: messages.size }
  end

  def self.parse_cursor(stdout)
    events = stdout.each_line.filter_map { |l| JSON.parse(l) rescue nil }
    result = events.reverse.find { |e| e['type'] == 'result' }
    # One entry per completed tool call: which tool, on what, and how it ended
    # (success, error such as "Permission denied", or rejected).
    tools = events.select { |e| e['type'] == 'tool_call' && e['subtype'] == 'completed' }.map do |e|
      name, call = (e['tool_call'] || {}).find { |k, v| k.end_with?('ToolCall') && v.is_a?(Hash) }
      args = call&.dig('args') || {}
      { 'tool' => name, 'target' => args.values_at('path', 'targetDirectory', 'searchTerm', 'url', 'pattern').compact,
        'result' => (call&.dig('result') || {}).keys }
    end
    model = events.filter_map { |e| e['model'] }.uniq
    { text: result&.dig('result'), model_returned: model.empty? ? nil : model, usage: result&.dig('usage'),
      stop_reason: result&.dig('subtype'), is_error: result.nil? || result['is_error'],
      tool_calls: tools }
  end

  # A transport failure is one where no answer came back at all; it is retried.
  # An answer that does not score is a result, recorded and not retried.
  def self.transport_failure?(cli, parsed)
    cli[:timed_out] || cli[:exit] != 0 || parsed[:text].to_s.strip.empty?
  end
end
