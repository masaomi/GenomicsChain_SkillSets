# frozen_string_literal: true

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      module Assess
        # Phase 3 of gc_tier1_assess (spec v0.2 §6).
        #
        # Everything the assessor LLM is NOT allowed to author: field-shape
        # normalisation, the stage guards, counts, headline, levers, and
        # stage2_candidate. All of it is a fixed function of `steps` plus
        # `capture_claim`, so deriving it here removes an error class and makes
        # the emitted report internally consistent by construction.
        module Derivation
          STAGE1 = PreCommit::STAGE1
          STAGE2 = PreCommit::STAGE2

          # Collection protocol §3 / stage-1 prompt line 40.
          CAPTURE_CLAIMS = %w[
            none floating exact_pins_partial release_snapshot env_lock_claimed container_digest_claimed
          ].freeze

          # Protocol v0.2.6 tightened positive gate. exact_pins_partial is
          # deliberately absent: a correctly-classified exact_pins_partial paper is
          # capped at version=1 by the prose read, so a code check yields zero R*
          # gain. Those papers reach stage 2 only through the stratified audit gate,
          # which the orchestrator draws separately — never through this flag.
          STAGE2_POSITIVE = %w[env_lock_claimed container_digest_claimed release_snapshot].freeze

          VERSION_SUBTIERS = %w[release_snapshot exact_pins_partial floating].freeze
          ENV_CAPTURE_CLASSES = %w[A_verified_in_code B_pin_prose_only C_mutable_latest n/a].freeze
          AXES = %w[data code version params].freeze

          class DerivationError < StandardError; end

          Result = Struct.new(
            :steps, :counts, :headline, :levers, :capture_claim, :stage2_candidate, :demotions,
            keyword_init: true
          )

          module_function

          # @param llm [Hash] the assessor's fields (string-keyed)
          # @param funnel_stage [String]
          # @param lock_cited_in_sources [Boolean] stage 2 only — did the Lever-1
          #   citation name a source the caller actually supplied?
          def apply(llm:, funnel_stage:, lock_cited_in_sources: false)
            stage = funnel_stage.to_s
            demotions = []

            capture_claim = check_capture_claim!(llm['capture_claim'])
            steps = normalise_steps(Array(llm['steps']), demotions)

            stage == STAGE1 ? stage1_guard!(steps, demotions) : stage2_guard!(steps, demotions)

            counts = count(steps, stage: stage, demotions: demotions)
            levers = levers(
              steps: steps, counts: counts, stage: stage,
              evidence: llm['lever_evidence'] || {}, lock_cited_in_sources: lock_cited_in_sources
            )

            Result.new(
              steps: steps.map { |s| s.reject { |k, _| k == 'lock_covers_toolchain' } },
              counts: counts,
              headline: headline(counts, levers, stage),
              levers: levers,
              capture_claim: capture_claim,
              stage2_candidate: STAGE2_POSITIVE.include?(capture_claim),
              demotions: demotions
            )
          end

          # capture_claim drives stage2_candidate, so an out-of-enum value is not
          # something to coerce quietly — fail closed (spec §8).
          def check_capture_claim!(value)
            claim = value.to_s
            return claim if CAPTURE_CLAIMS.include?(claim)

            raise DerivationError,
                  "capture_claim #{value.inspect} is outside the enum (#{CAPTURE_CLAIMS.join(', ')})"
          end

          # §6b-2 — the three shapes the 201-report corpus got wrong 59 times.
          def normalise_steps(raw, demotions)
            raw.each_with_index.map do |step, i|
              s = step.transform_keys(&:to_s)
              s['step_id'] ||= "S#{i + 1}"
              s['layer'] = %w[C W].include?(s['layer'].to_s) ? s['layer'].to_s : 'C'
              s['subflags'] = Array(s['subflags'])
              s['axes'] = normalise_axes(s, demotions)

              # A wet-lab step is out of scope for scoring, not partially scored.
              if s['layer'] == 'W'
                s['axes'] = AXES.to_h { |a| [a, 0] }
                s['verdict'] = 'OOS'
              end

              normalise_version_subtier!(s, demotions)
              unless ENV_CAPTURE_CLASSES.include?(s['env_capture_class'].to_s)
                s.delete('env_capture_class')
              end
              s
            end
          end

          def normalise_axes(step, demotions)
            given = (step['axes'] || {}).transform_keys(&:to_s)
            AXES.to_h do |axis|
              value = given[axis]
              if value.nil?
                note(demotions, step, "axes.#{axis}", nil, 0, 'unscored-axis-filled')
                [axis, 0]
              else
                [axis, value.to_i.clamp(0, 2)]
              end
            end
          end

          # Rubric line 45: version_subtier is reported WHEN version=1. Otherwise the
          # key is omitted — not "none", not null. That single misreading accounts for
          # 464 of the corpus's 526 subtier violations.
          def normalise_version_subtier!(step, demotions)
            subtier = step['version_subtier']
            return step.delete('version_subtier') unless step.dig('axes', 'version') == 1

            return if VERSION_SUBTIERS.include?(subtier.to_s)

            note(demotions, step, 'version_subtier', subtier, 'floating', 'subtier-outside-enum')
            step['version_subtier'] = 'floating'
          end

          # §6a — at stage 1 a lockfile or container is only a CLAIM, so no step can
          # carry version=2, and therefore none can reach R*.
          def stage1_guard!(steps, demotions)
            steps.each do |s|
              next if s['layer'] == 'W'

              if s['axes']['version'] > 1
                note(demotions, s, 'axes.version', s['axes']['version'], 1, 'stage1-claim-only')
                s['axes']['version'] = 1
              end
              if s['env_capture_class'] && s['env_capture_class'] != 'n/a'
                note(demotions, s, 'env_capture_class', s['env_capture_class'], 'n/a', 'stage1-no-code-check')
              end
              s['env_capture_class'] = 'n/a'
              normalise_version_subtier!(s, demotions)
              # The version cap already makes R unreachable; the explicit cap is a
              # backstop so a malformed axes block cannot slip one through.
              settle_verdict!(s, demotions, 'stage1-ceiling-demoted', cap: 'RI')
            end
          end

          # §6b — R* is promotable only where the code evidence carries it.
          def stage2_guard!(steps, demotions)
            steps.each do |s|
              next if s['layer'] == 'W'

              # Failing the R* gate must CAP the step below R. Without the cap a step
              # whose axes are all 2 but whose DB pin lives in prose only would be
              # re-promoted to R by axis-min alone — exactly the prose-optimism the
              # code check exists to catch.
              settle_verdict!(s, demotions, 'stage2-r-gate', cap: 'RI') unless r_star_eligible?(s)
              normalise_version_subtier!(s, demotions)
            end
          end

          def r_star_eligible?(step)
            axes = step['axes']
            axes['data'] >= 1 && axes['code'] == 2 && axes['version'] == 2 &&
              step['env_capture_class'] == 'A_verified_in_code' &&
              step['lock_covers_toolchain'] == true
          end

          # Verdict follows axis-min. Where the min is 0 the rubric distinguishes
          # recoverable (NI) from unrecoverable (X), which is a judgement the axes do
          # not carry — so the assessor's choice is kept there, defaulting to NI.
          def settle_verdict!(step, demotions, reason, cap: nil)
            was = step['verdict']
            now = axis_min_verdict(step['axes'], was)
            now = cap if cap == 'RI' && now == 'R'
            return if was == now

            note(demotions, step, 'verdict', was, now, reason)
            step['verdict'] = now
            step['subflags'] |= [reason] if reason == 'stage1-ceiling-demoted' && was == 'R'
          end

          def axis_min_verdict(axes, llm_verdict)
            min = AXES.map { |a| axes[a] }.min
            return 'R' if min == 2
            return 'RI' if min >= 1

            %w[NI X].include?(llm_verdict.to_s) ? llm_verdict.to_s : 'NI'
          end

          def count(steps, stage:, demotions:)
            c = steps.select { |s| s['layer'] == 'C' }
            counts = {
              'n_R' => c.count { |s| s['verdict'] == 'R' },
              'n_RI' => c.count { |s| s['verdict'] == 'RI' },
              'n_NI' => c.count { |s| s['verdict'] == 'NI' },
              'n_X' => c.count { |s| s['verdict'] == 'X' },
              'S' => c.size,
              'W' => steps.count { |s| s['layer'] == 'W' },
              'n_fetch_required' => c.count { |s| s['subflags'].include?('fetch-required') },
              'n_exact_capture_unexecuted' => c.count { |s| s['axes']['version'] == 2 }
            }

            # The stage-1 prompt prescribes both as 0. Four of the 201 corpus reports
            # emitted a non-zero n_fetch_required anyway, so force the rule but record
            # what was forced rather than zeroing silently.
            if stage == STAGE1
              %w[n_fetch_required n_exact_capture_unexecuted].each do |key|
                next if counts[key].zero?

                demotions << { 'step_id' => nil, 'field' => "counts.#{key}", 'from' => counts[key],
                               'to' => 0, 'reason' => 'stage1-forced-zero' }
                counts[key] = 0
              end
            end
            counts
          end

          def levers(steps:, counts:, stage:, evidence:, lock_cited_in_sources:)
            if stage == STAGE1
              return {
                'software_env_lock' => false,
                'in_code_db_pin_classA' => false,
                'has_validated_env_capture' => false,
                'software_env_platform_coverage' => 'unverified (stage1)'
              }
            end

            lock = evidence['software_env_lock'] == true && lock_cited_in_sources
            c = steps.select { |s| s['layer'] == 'C' }
            {
              'software_env_lock' => lock,
              'in_code_db_pin_classA' =>
                c.none? { |s| %w[B_pin_prose_only C_mutable_latest].include?(s['env_capture_class']) },
              # NOT an alias for software_env_lock: a lock can be upheld while every
              # step still falls short of R* on the data or DB-pin axis. That is the
              # aMeta shape (lock genuine, zero class-A DB pins).
              'has_validated_env_capture' => counts['n_R'] >= 1,
              'software_env_platform_coverage' => evidence['platform_coverage'].to_s.empty? ? 'unstated' : evidence['platform_coverage'].to_s
            }
          end

          def headline(counts, levers, stage)
            s = counts['S']
            {
              'static_readiness' => static_readiness(counts, levers, stage),
              'inference_inclusive_upper_bound' =>
                "#{counts['n_R'] + counts['n_RI']}/#{s} (#{pct(counts['n_R'] + counts['n_RI'], s)}) " \
                'readiness upper bound - never "reproducible"',
              'coverage' => "#{s}/#{s + counts['W']} (#{pct(s, s + counts['W'])}) computational coverage",
              'repro_index' => repro_index(counts)
            }
          end

          # Rubric line 64 forbids presenting static_readiness without the inline
          # qualifier and without co-reporting the two capture counts.
          def static_readiness(counts, levers, stage)
            n = counts['n_R']
            s = counts['S']
            ratio = "#{n}/#{s} (#{pct(n, s)})"

            if !levers['has_validated_env_capture'] && stage == STAGE1
              return "#{ratio} - stage1 ceiling only, no R-star (R-star needs stage-2 code verification)"
            end
            return "#{ratio} - no R-star reached under code verification" unless levers['has_validated_env_capture']

            "#{ratio} - unexecuted; declared environment statically valid but not " \
              'verified as the env that produced the results; ' \
              "n_exact_capture_unexecuted=#{counts['n_exact_capture_unexecuted']}, " \
              "n_fetch_required=#{counts['n_fetch_required']}"
          end

          # Rubric line 67: weights are guesses until Tier-2; refuse when |S| < 4;
          # emit only as a tuple, 1 significant figure.
          def repro_index(counts)
            s = counts['S']
            return nil if s < 4

            raw = ((1.0 * counts['n_R']) + (0.6 * counts['n_RI']) + (0.2 * counts['n_NI'])) / s
            { 'index' => sig1(raw), 'coverage' => sig1(s.to_f / (s + counts['W'])), 'S' => s,
              'note' => 'weights are guesses until Tier-2' }
          end

          def sig1(value)
            return 0.0 if value.nil? || value.zero?

            magnitude = Math.log10(value.abs).floor
            ((value / (10.0**magnitude)).round * (10.0**magnitude)).round(10)
          end

          def pct(numerator, denominator)
            denominator.zero? ? 'n/a' : "#{((numerator.to_f / denominator) * 100).round}%"
          end

          def note(list, step, field, from, to, reason)
            list << { 'step_id' => step['step_id'], 'field' => field, 'from' => from,
                      'to' => to, 'reason' => reason }
          end
        end
      end
    end
  end
end
