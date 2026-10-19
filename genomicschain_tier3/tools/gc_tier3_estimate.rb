# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'
require 'genomicschain_tier3'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      module Tools
        # gc_tier3_estimate — what a Tier-3 run would cost, before running it.
        #
        # Exists because a Tier-3 certificate that costs more to produce than it
        # sells for is not a product. Cost scales with two operator choices —
        # compute size and number of runs — so both are inputs here, and the
        # answer is produced BEFORE any credits are spent.
        #
        # The authoritative rate comes from `thoa run --dry-run`, which returns
        # an estimate and validates against the account's limits without
        # submitting a job. When thoa is unavailable the tool falls back to
        # rates measured on 2026-08-17 and says so; it does NOT interpolate,
        # because the measured points do not fit a linear model (8c/32GB is
        # exactly half of 16c/64GB, but 4c/16GB is not half of 8c/32GB), which
        # means thoa maps requests onto discrete VM types. Inventing a curve
        # through those points would produce confident wrong numbers.
        class GcTier3Estimate < KairosMcp::Tools::BaseTool
          # Measured 2026-08-17 via `thoa run --dry-run` on the project account.
          # cores, ram_gb, storage_gb => credits/hr
          MEASURED_RATES = [
            { cores: 16, ram_gb: 64, storage_gb: 100, credits_per_hour: 261.4, range_high: 327.2 },
            { cores: 16, ram_gb: 32, storage_gb: 100, credits_per_hour: 208.1 },
            { cores: 8,  ram_gb: 32, storage_gb: 50,  credits_per_hour: 130.7 },
            { cores: 4,  ram_gb: 16, storage_gb: 50,  credits_per_hour: 58.7 },
            { cores: 2,  ram_gb: 8,  storage_gb: 20,  credits_per_hour: 32.7 },
            { cores: 1,  ram_gb: 2,  storage_gb: 10,  credits_per_hour: 9.4 }
          ].freeze
          MEASURED_AT = '2026-08-17'

          # Published plans. usd_per_token is DERIVED, and is why the plans are
          # worth reading twice: Starter has the CHEAPEST token ($0.0140) and Pro
          # the most expensive ($0.0182). The upper plans are not bulk discounts;
          # they are sold to raise the RAM / runtime / concurrency ceilings.
          PLANS = [
            { name: 'starter', monthly_usd: 35,  tokens: 2500,  max_ram_gb: 128,  max_cores: 16,
              max_storage_gb: 200,  max_runtime_hours: 24 },
            { name: 'pro',     monthly_usd: 109, tokens: 6000,  max_ram_gb: 512,  max_cores: 64,
              max_storage_gb: 1024, max_runtime_hours: 72 },
            { name: 'team',    monthly_usd: 480, tokens: 28_000, max_ram_gb: 2048, max_cores: 96,
              max_storage_gb: 4096, max_runtime_hours: 168 }
          ].freeze

          # AWS eu-central-1 on-demand Linux, from the AWS Price List API,
          # retrieved 2026-08-17. Present so the estimate can be read against the
          # unmanaged floor rather than in isolation.
          AWS_REFERENCE = [
            { instance: 'm5.4xlarge',     vcpu: 16, ram_gb: 64,   usd_per_hour: 0.9200 },
            { instance: 'r5.4xlarge',     vcpu: 16, ram_gb: 128,  usd_per_hour: 1.2160 },
            { instance: 'r6i.8xlarge',    vcpu: 32, ram_gb: 256,  usd_per_hour: 2.4320 },
            { instance: 'x2idn.16xlarge', vcpu: 64, ram_gb: 1024, usd_per_hour: 9.3370 }
          ].freeze
          AWS_REGION = 'eu-central-1 (Frankfurt)'
          AWS_PRICED_AT = '2026-08-17'

          DRY_RUN_TIMEOUT = 180

          def name
            'gc_tier3_estimate'
          end

          def description
            'Estimate what a Tier-3 run would cost before running it, from compute size and number of ' \
              'runs. Queries `thoa run --dry-run` for the authoritative rate and account limits when ' \
              'available (spends nothing), otherwise reports rates measured on 2026-08-17. Includes the ' \
              'AWS on-demand equivalent for comparison. Submits no job.'
          end

          def category
            :utility
          end

          def usecase_tags
            %w[tier3 cost estimate thoa credits budget pricing]
          end

          def related_tools
            %w[gc_tier3_execute gc_tier3_submit]
          end

          def harness_requirement
            { tier: :harness_assisted, requires_externals: %w[thoa],
              reason: 'queries the thoa CLI for the authoritative rate; falls back to measured rates without it' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                n_cores: { type: 'integer', description: 'CPU cores per run (thoa default 16).' },
                ram_gb: { type: 'integer', description: 'RAM in GB per run (thoa default 64).' },
                storage_gb: {
                  type: 'integer',
                  description: 'Disk in GB per run. The thoa CLI default is 200, which exceeds some ' \
                               'accounts\' allocation and fails closed — set it explicitly.'
                },
                estimated_hours: {
                  type: 'number',
                  description: 'Expected wall-clock hours for ONE run. Cost is per hour of allocation, ' \
                               'and a Snakemake workflow holds one allocation for its whole DAG, so this ' \
                               'is the full pipeline duration, not the duration of its largest step.'
                },
                runs: {
                  type: 'integer',
                  description: 'Number of independent runs (default 1). Multiplies the total directly. ' \
                               '1 establishes only that it ran; >=2 also reports whether the runs agreed.'
                },
                offline: {
                  type: 'boolean',
                  description: 'Skip the thoa query and use the measured table only (default false).'
                },
                reachability_proof_id: {
                  type: 'string',
                  description: 'A reachability observation (gc_prov_reach) of the bundle to rebuild: its date and, ' \
                               'per category, the places that did not answer are shown beside the estimate. Read ' \
                               'from this node\'s Synoptis registry; elsewhere the tool says it cannot read it.'
                }
              },
              required: %w[estimated_hours]
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)
            cores = (args['n_cores'] || 16).to_i
            ram = (args['ram_gb'] || 64).to_i
            storage = (args['storage_gb'] || 100).to_i
            hours = args['estimated_hours'].to_f
            runs = (args['runs'] || 1).to_i

            return text_content('Error: estimated_hours must be > 0') unless hours.positive?
            return text_content("Error: runs must be >= 1 (got #{runs})") if runs < 1
            return text_content('Error: n_cores, ram_gb and storage_gb must be > 0') if [cores, ram, storage].any?(&:zero?)

            rate = args['offline'] ? nil : thoa_rate(cores, ram, storage)
            rate ||= measured_rate(cores, ram, storage)

            out = render(cores: cores, ram: ram, storage: storage, hours: hours, runs: runs, rate: rate)
            out['reachability'] = reachability(args['reachability_proof_id'].to_s) if args['reachability_proof_id']
            text_content(JSON.pretty_generate(out))
          rescue StandardError => e
            text_content("Error: gc_tier3_estimate failed — #{e.class}: #{e.message}")
          end

          # prov design v0.1.15 §6.3 (8): the observation beside the estimate,
          # never a gate. The four results that mean "not had when asked",
          # per category (counts are never added across categories).
          NOT_ANSWERING = %w[not_found access_denied error not_attempted].freeze

          private

          def reachability(proof_id)
            registry = reach_registry
            return { 'proof_id' => proof_id, 'note' => 'cannot be read on this node: no Synoptis registry here' } unless registry

            envelope = registry.find_proof(proof_id)
            evidence = envelope && JSON.parse(envelope.evidence.to_s)
            manifest = evidence.is_a?(Hash) ? evidence['manifest'] : nil
            unless manifest.is_a?(Hash) && manifest['record_type'] == 'prov_reachability'
              return { 'proof_id' => proof_id, 'note' => 'no reachability observation under this proof_id on this node' }
            end

            per_category = manifest['counts'].to_h do |cat, c|
              [cat, NOT_ANSWERING.to_h { |b| [b, c.is_a?(Hash) ? c[b].to_i : 0] }.select { |_, n| n.positive? }]
            end
            { 'proof_id' => proof_id, 'observed_at' => manifest['observed_at'], 'observer' => manifest['observer'],
              'revoked' => registry.revoked?(proof_id) ? true : false,
              'not_answering_per_category' => per_category.reject { |_, v| v.empty? },
              'note' => 'Places that did not answer as asked when the anchor observed them, by category. A Tier-3 ' \
                        'run on GenomicsChain\'s side cannot fetch what was access_denied. Not a gate; the date ' \
                        'says how old the observation is.' }
          # Whatever goes wrong in reading the registry or the record stays here,
          # named by its class only: the estimate is returned regardless (§6.3
          # (8), review r1).
          rescue StandardError => e
            { 'proof_id' => proof_id, 'note' => "the record under this proof_id cannot be read here (#{e.class})" }
          end

          # This node's Synoptis registry, or nil where there is none.
          def reach_registry
            return nil unless KairosMcp.respond_to?(:data_dir)

            dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            return nil unless File.directory?(dir)

            require 'synoptis/registry/file_registry'
            ::Synoptis::Registry::FileRegistry.new(data_dir: dir)
          rescue LoadError
            nil
          end

          # Asks thoa. --dry-run submits nothing, so this costs no credits, and
          # it also reports account-limit violations that a measured table
          # cannot know about (limits are per account, not per service).
          def thoa_rate(cores, ram, storage)
            return nil unless cli_available? && api_key_set?

            cmd = cmd_prefix + ['run', '--dry-run', '--n-cores', cores.to_s, '--ram', ram.to_s,
                                '--storage', storage.to_s, '--tools', 'python',
                                '--cmd', 'true', '--job-name', 'gc-estimate']
            output = nil
            begin
              Timeout.timeout(DRY_RUN_TIMEOUT) { output, = Open3.capture2e(*cmd) }
            rescue Timeout::Error
              return nil
            end
            return nil if output.nil?

            if (m = output.match(/Estimated cost\s+([0-9.]+)\s+credits\/hr/))
              high = output[/Price range\s+[0-9.]+\s*[–-]\s*([0-9.]+)\s+credits\/hr/, 1]
              return { 'credits_per_hour' => m[1].to_f, 'range_high' => high&.to_f,
                       'source' => 'thoa_dry_run', 'account_limits_ok' => true }
            end

            if (m = output.match(/SERVER MESSAGE:\s*\n(.+)/))
              return { 'credits_per_hour' => nil, 'source' => 'thoa_dry_run',
                       'account_limits_ok' => false, 'refused_because' => m[1].strip }
            end

            nil
          end

          # Nearest measured point that is at least as large on every dimension.
          # Deliberately NOT an interpolation: see the class comment.
          def measured_rate(cores, ram, storage)
            covering = MEASURED_RATES.select do |r|
              r[:cores] >= cores && r[:ram_gb] >= ram && r[:storage_gb] >= storage
            end
            point = covering.min_by { |r| r[:credits_per_hour] }
            unless point
              return { 'credits_per_hour' => nil, 'source' => 'measured_table',
                       'account_limits_ok' => nil,
                       'refused_because' => "no measured point covers #{cores}c/#{ram}GB/#{storage}GB " \
                                            "(largest measured is 16c/64GB/100GB). Run with thoa available " \
                                            "for an authoritative figure." }
            end

            { 'credits_per_hour' => point[:credits_per_hour], 'range_high' => point[:range_high],
              'source' => 'measured_table', 'measured_at' => MEASURED_AT,
              'measured_point' => "#{point[:cores]}c/#{point[:ram_gb]}GB/#{point[:storage_gb]}GB",
              'is_upper_bound' => !(point[:cores] == cores && point[:ram_gb] == ram && point[:storage_gb] == storage),
              'account_limits_ok' => nil }
          end

          def render(cores:, ram:, storage:, hours:, runs:, rate:)
            per_hour = rate['credits_per_hour']
            out = {
              'request' => { 'n_cores' => cores, 'ram_gb' => ram, 'storage_gb' => storage,
                             'estimated_hours_per_run' => hours, 'runs' => runs,
                             'total_allocation_hours' => (hours * runs).round(2) },
              'rate' => rate
            }

            if per_hour.nil?
              out['total_credits'] = nil
              out['warnings'] = ['No rate available — see rate.refused_because. No cost could be computed.']
              return out
            end

            per_run = (per_hour * hours).round(1)
            total = (per_run * runs).round(1)
            out['credits'] = { 'per_run' => per_run, 'total' => total,
                               'high_estimate' => rate['range_high'] ? (rate['range_high'] * hours * runs).round(1) : nil }.compact

            out['plans'] = PLANS.map do |p|
              usd_per_token = (p[:monthly_usd].to_f / p[:tokens]).round(6)
              fits = ram <= p[:max_ram_gb] && cores <= p[:max_cores] &&
                     storage <= p[:max_storage_gb] && hours <= p[:max_runtime_hours]
              {
                'name' => p[:name], 'monthly_usd' => p[:monthly_usd],
                'tokens_per_month' => p[:tokens], 'usd_per_token' => usd_per_token,
                'usd_for_this_job' => (total * usd_per_token).round(2),
                'job_fits_plan_limits' => fits,
                'months_of_allowance_consumed' => (total / p[:tokens].to_f).round(2)
              }
            end

            aws = AWS_REFERENCE.select { |i| i[:vcpu] >= cores && i[:ram_gb] >= ram }
                               .min_by { |i| i[:usd_per_hour] }
            if aws
              aws_total = (aws[:usd_per_hour] * hours * runs).round(2)
              cheapest_plan = out['plans'].select { |p| p['job_fits_plan_limits'] }
                                          .min_by { |p| p['usd_for_this_job'] }
              out['aws_on_demand_reference'] = {
                'region' => AWS_REGION, 'priced_at' => AWS_PRICED_AT,
                'instance' => aws[:instance], 'usd_per_hour' => aws[:usd_per_hour],
                'usd_for_this_job' => aws_total,
                'thoa_over_aws' => cheapest_plan ? (cheapest_plan['usd_for_this_job'] / aws_total).round(1) : nil,
                'note' => 'On-demand compute only. Excludes EBS, egress, and the engineering time thoa ' \
                          'absorbs (environment building, dataset management, job orchestration). AWS ' \
                          'costs nothing while idle; a thoa subscription does not.'
              }
            end

            out['warnings'] = warnings(cores: cores, ram: ram, storage: storage, hours: hours,
                                       runs: runs, rate: rate, plans: out['plans'])
            out
          end

          def warnings(cores:, ram:, storage:, hours:, runs:, rate:, plans:)
            w = []
            if rate['source'] == 'measured_table'
              w << "Rate is from the #{MEASURED_AT} measured table, not a live quote. Account limits were " \
                   'NOT checked — they are per account and a request within these sizes can still be refused.'
              w << "The rate used is the nearest measured point that covers the request " \
                   "(#{rate['measured_point']}), so it is an UPPER bound, not the price of this exact size." if rate['is_upper_bound']
            end
            w << "thoa refused this size: #{rate['refused_because']}" if rate['refused_because']
            if plans.none? { |p| p['job_fits_plan_limits'] }
              w << 'No published plan admits this job (check ram/cores/storage/runtime against the limits).'
            end
            if runs == 1
              w << 'runs=1 establishes only that the pipeline ran. It cannot report whether repeated ' \
                   'execution yields the same result; that needs runs >= 2, at double the cost.'
            end
            if hours > 24
              w << "estimated_hours=#{hours} exceeds the Starter plan's 24h maximum runtime."
            end
            w
          end

          def cli_available?
            system('which thoa > /dev/null 2>&1') ||
              system('conda run -n thoa_py3.11 which thoa > /dev/null 2>&1')
          end

          def api_key_set?
            key = ENV['THOA_API_KEY']
            !key.nil? && !key.strip.empty?
          end

          def cmd_prefix
            system('which thoa > /dev/null 2>&1') ? ['thoa'] : ['conda', 'run', '-n', 'thoa_py3.11', 'thoa']
          end
        end
      end
    end
  end
end
