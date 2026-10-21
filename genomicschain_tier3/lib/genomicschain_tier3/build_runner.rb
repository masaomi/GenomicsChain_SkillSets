# frozen_string_literal: true

require 'open3'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      # BuildRunner — ① 再構築, the rule of design §3.1: built means every step
      # of the declared plan exited 0 and every version, digest and source it
      # pins was obtained as pinned. A plan that pins nothing cannot build.
      #
      # "Obtained as pinned" is observed in its smallest form (〔実装の読み〕):
      # after a step, each of its pins runs its `observe` command in the same
      # directory, and the stripped stdout must equal `expected` byte for byte.
      # After the last step every pin is observed once more, so a later step
      # that changes a pinned version does not build (review r1 F5). Steps,
      # observations and the run share one fresh directory per attempt, so
      # what a step fetched sits in the pre-run snapshot and is not counted
      # as output (§3.1 F5). The first failure stops the build: nothing is
      # built on top of a step that did not build.
      #
      # Every command runs as an argv, never through a shell, even a
      # one-element array (review r1 H9); one that cannot be started is a
      # failed step. Output is read as bytes, so no encoding stops an attempt.
      module BuildRunner
        Outcome = Struct.new(:built, :steps, :pins, :logs, keyword_init: true)

        module_function

        # @param plan [Hash] {env, steps: [{name, command, pins: [{name, kind,
        #   expected, observe, origin}]}]}
        # @return [Outcome] pins hold one entry per observed pin (its last
        #   observation); logs are [what, bytes] pairs, for fingerprinting only
        def run(plan, dir)
          steps = []
          pins = {}
          logs = []
          failed = false
          plan['steps'].each do |step|
            code, out, err = capture(step['command'], dir)
            steps << { 'name' => step['name'], 'command' => step['command'], 'exit_code' => code }
            logs << ["build #{step['name']} stdout", out] << ["build #{step['name']} stderr", err]
            failed = true unless code&.zero?
            break if failed

            step['pins'].each { |pin| failed |= !observe(step, pin, dir, pins, logs, 'observe') }
            break if failed
          end
          unless failed
            plan['steps'].each do |step|
              step['pins'].each { |pin| failed |= !observe(step, pin, dir, pins, logs, 'final observe') }
            end
          end
          pinned = plan['steps'].sum { |s| s['pins'].length }.positive?
          Outcome.new(built: !failed && pinned, steps: steps, pins: pins.values, logs: logs)
        end

        # One observation of one pin. A pin seen twice keeps its last
        # observation, and holds only if every one of them held.
        def observe(step, pin, dir, pins, logs, label)
          code, out, err = capture(pin['observe'], dir)
          bytes = out.strip
          ok = code == 0 && bytes == pin['expected'].to_s.b
          id = [step['name'], pin['name']]
          ok &&= pins.fetch(id, { 'ok' => true })['ok']
          pins[id] = { 'step' => step['name'], 'name' => pin['name'], 'kind' => pin['kind'],
                       'expected' => pin['expected'], 'observed' => readable(bytes), 'ok' => ok,
                       'origin' => pin['origin'] }
          logs << ["#{label} #{step['name']}/#{pin['name']} stdout", out] <<
            ["#{label} #{step['name']}/#{pin['name']} stderr", err]
          ok
        end

        # [argv0, argv0] forces exec without a shell for any argument count.
        def capture(command, dir)
          program, *args = command
          out, err, status = Open3.capture3([program, program], *args, chdir: dir, binmode: true)
          [status.exitstatus, out, err]
        rescue SystemCallError => e
          [nil, ''.b, e.class.name.b]
        end

        # The observed bytes as JSON can hold them: as they are when they are
        # UTF-8, with replacement characters otherwise (such a pin never holds).
        def readable(bytes)
          text = bytes.dup.force_encoding(Encoding::UTF_8)
          text.valid_encoding? ? text : text.scrub("\uFFFD")
        end
      end
    end
  end
end
