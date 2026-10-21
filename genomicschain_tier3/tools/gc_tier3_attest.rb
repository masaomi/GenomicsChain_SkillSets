# frozen_string_literal: true

require 'json'
require 'digest'
require 'base64'
require 'securerandom'
require 'pathname'
require 'ed25519'
require 'genomicschain_tier3'
require 'genomicschain_tier3_record/records'
require 'genomicschain_tier3/fingerprint'
require 'genomicschain_tier3/process_record'
require 'genomicschain_tier3/build_runner'
require_relative 'gc_tier3_execute'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      module Tools
        # gc_tier3_attest — the Tier 3 executor's side (design §3.2, §9-3):
        # declares, attempts, and signs the scores. Runs on the machine of
        # whoever can receive the input data; the anchor never sees it, and
        # never loads this package (§3.2〔実装〕).
        #
        #   declare  the plan, the targets and the binding list, signed before
        #            anything is built (§3.3); the process record is opened
        #   attempt  one attempt (§3.1): ① build the plan once in a fresh
        #            work_root/attempt-<n>; if it built, ② gc_tier3_execute
        #            once with runs = 1 there; if that completed, ③ compare the
        #            declared target paths absent before the run or changed by
        #            it. A row per attempt, failures included
        #   attest   every row signed under the declaration's key (§4.1)
        #
        # attempt and attest hold the process record's lock, and take policy,
        # plan and targets from the signed declaration: the local copy they run
        # is used only after its bindings recompute to the declaration's
        # (review r1 H6), and the commitment key only after its key_id does
        # (H7). An attempt interrupted earlier is closed first (§3.4〔実装〕).
        #
        # Both keys — the signing key and the job's commitment key — are read
        # by path and used in memory here only: never in a response, the
        # process record, a log line or an error message (§4.2). Signing and
        # recording are separate: what this signs, gc_tier3_record_submit
        # records on the anchor.
        class GcTier3Attest < KairosMcp::Tools::BaseTool
          R = GenomicschainTier3Record::Records
          C = ::GenomicsChainProv::Commitment
          M = KairosMcp::Manifest
          PR = ProcessRecord

          TOOL_VERSION = 'gc_tier3_attest-0.1.0'
          ACTIONS = %w[declare attempt attest].freeze
          ROUTES = %w[A B].freeze
          FORMS = %w[plain salted].freeze
          DATA_CLASSES = %w[non_human human].freeze
          PIN_KINDS = %w[version digest source].freeze
          PIN_ORIGINS = %w[declared inferred].freeze
          # §3.1: a target is a path inside the attempt's fresh output location
          # (preflight K3).
          INSIDE = 'must be a relative path inside the attempt directory (not empty, no leading / or ~, no .., ' \
                   'no control character)'
          # The attempt directory is the tool's; a pipeline does not name its own (review r2 G4).
          PIPELINE_DIRS = %w[workdir download_dir].freeze
          HEX64 = /\A[0-9a-f]{64}\z/
          ISO = /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/

          # Fixed decision 4: the comparators are this tool's own table, never
          # comparator.rb's REGISTRY — there they would be callable by id from
          # 12:142–146 with plain fingerprints, and a comparison that never
          # computed an HMAC would reach record 0.3 under this name (§3.2).
          #
          # exact_sha256 0.2.0 is ExactSha256 (11:59–92) itself, called on one file.
          module ExactSha256File
            RULE = Execution::Comparator::ExactSha256
            ID = RULE::ID
            VERSION = RULE::VERSION
            ALGORITHM = 'sha256'

            def self.match?(path:, value:, key: nil) # rubocop:disable Lint/UnusedMethodArgument
              file = { 'relative_path' => 'target', 'sha256' => Digest::SHA256.file(path).hexdigest }
              RULE.compare(result_hash: nil, output_files: [file],
                           expected_output: { 'sha256' => value, 'target' => 'file:target' }).match
            end
          end

          # exact_commitment 0.1.0 (operator, question 4): C(f) of the
          # executor's own output under the job's commitment key equals the
          # target value. gc-commitment-0.1 (14:49–64) unchanged.
          module ExactCommitmentFile
            ID = 'exact_commitment'
            VERSION = '0.1.0'
            ALGORITHM = 'hmac_sha256'

            def self.match?(path:, value:, key: nil)
              raise ArgumentError, 'exact_commitment needs the job\'s commitment key' if key.nil?

              commitment = ::GenomicsChainProv::Commitment.commit_file(key, path)
              !commitment.nil? && commitment == value
            end
          end

          COMPARATORS = { ExactSha256File::ID => ExactSha256File, ExactCommitmentFile::ID => ExactCommitmentFile }.freeze

          # A bad or missing argument, or a process record that does not hold
          # what was signed; the message names it.
          class Refused < StandardError; end

          # What attempt and attest act on: the signed declaration, and the
          # parts of the local copy whose bindings recompute to it.
          Job = Struct.new(:declaration, :plan, :data, :pipeline, :compare, :comparator, :key, :fp, keyword_init: true) do
            # It holds the commitment key; no form of it is printed (review r3).
            def inspect = "#<#{self.class.name} (commitment key withheld)>"
            alias_method :to_s, :inspect
            # pp / pretty_inspect too: Struct's own pretty_print lists every member.
            def pretty_print(q) = q.text(inspect)
          end

          def name
            'gc_tier3_attest'
          end

          def description
            'Tier-3 executor side: declare a build plan and its targets (signed before building), run one attempt ' \
              '(build the plan once in a fresh directory; if it built, run gc_tier3_execute once and compare the ' \
              'declared target files), and sign every attempt row as the attestation. Keys are read by path and ' \
              'never leave this tool. Returns what to pass to gc_tier3_record_submit on the anchor; records nothing.'
          end

          def category
            :utility
          end

          def usecase_tags
            %w[tier3 reproducibility declaration attestation rebuild rerun reproduce signed]
          end

          def related_tools
            %w[gc_tier3_record_submit gc_tier3_execute gc_tier3_estimate]
          end

          def harness_requirement
            { tier: :harness_assisted, requires_externals: %w[thoa conda],
              reason: 'builds the declared plan and runs the pipeline through local commands or the thoa CLI' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                action: { type: 'string', enum: ACTIONS,
                          description: 'declare (sign before building), attempt (one build + run + compare), ' \
                                       'attest (sign every attempt row).' },
                process_dir: { type: 'string',
                               description: 'Absolute. The process record (gc-t3-process-0.1). declare: must not ' \
                                            'exist; attempt / attest: the one declare made.' },
                signing_key_path: { type: 'string',
                                    description: 'declare / attest: the executor\'s ed25519 submission key (base64 ' \
                                                 'of the 32-byte seed, or 64 hex; the gc_submit_client format).' },
                chain_tip_hash: { type: 'string', description: 'declare / attest: the anchor\'s proofs-chain tip.' },
                subject_ref: { type: 'string', description: 'declare: e.g. "repro://656122/C9".' },
                route: { type: 'string', enum: ROUTES,
                         description: 'declare: A = Tier 1 + Tier 2 (G1–G8), B = a Tier-2.5 record.' },
                route_ref: { type: 'string', description: 'declare, route A: carried and signed, not resolved.' },
                route_proof_id: { type: 'string',
                                  description: 'declare, route B: the Tier-2.5 record\'s proof_id. The declaration ' \
                                               'carries its SHA-256; the proof_id goes to the anchor beside it.' },
                fingerprint_form: { type: 'string', enum: FORMS,
                                    description: 'declare: salted = every fingerprint and digest field is ' \
                                                 'gc-commitment-0.1 under the job\'s commitment key.' },
                commitment_key_path: { type: 'string',
                                       description: 'declare: absolute path of a 32-byte key file. Required when ' \
                                                    'salted or when the bundle rows are hmac_sha256 (option 2: the ' \
                                                    'bundle\'s key). Make one with gc_prov_write --new-commitment-key.' },
                data_class: { type: 'string', enum: DATA_CLASSES, description: 'declare.' },
                build_plan: { type: 'object',
                              description: 'declare: {env, steps: [{name, command: [...], pins: [{name, kind: ' \
                                           'version|digest|source, expected, observe: [...], origin: ' \
                                           'declared|inferred}]}]}. Commands run as argv, never through a shell. ' \
                                           'A plan that pins nothing cannot build.' },
                rejected_proposals: { type: 'array', items: { type: 'object' },
                                      description: 'declare: inferred proposals not adopted, [{step, name, kind, ' \
                                                   'expected}]; kept in the process record.' },
                data: { type: 'object', description: 'declare: the data resolution, as for gc_tier3_execute.' },
                pipeline: { type: 'object',
                            description: 'declare: as for gc_tier3_execute (local: {command: [...]}); the ' \
                                         'directory is set per attempt.' },
                inputs: { type: 'array', items: { type: 'string' },
                          description: 'declare: absolute paths of the input files received.' },
                targets: { type: 'array', items: { type: 'object' },
                           description: 'declare, route A: [{path, sha256}] as the paper declares them; [] if none. ' \
                                        'A path is relative, inside the attempt directory (no leading / or ~, no ..).' },
                source: { type: 'string', description: 'declare, route A: paper_declared.' },
                source_citation: { type: 'string', description: 'declare, route A. No names, paths or sample names.' },
                validated_by: { type: 'string', description: 'declare, route A.' },
                bundle_digest: { type: 'string', description: 'declare, route B: the Tier-2.5 bundle digest.' },
                bundle_rows: { type: 'array', items: { type: 'array' },
                               description: 'declare, route B: the bundle\'s output rows [name, algorithm, hex], ' \
                                            'verbatim; at least one.' },
                target_paths: { type: 'array',
                                description: 'declare, route B: one entry per bundle row, a relative path inside the ' \
                                             'attempt directory or null for the row\'s name.' },
                attempts_max: { type: 'integer', description: 'declare: required, >= 1.' },
                expires_at: { type: 'string', description: 'declare: required, e.g. 2026-11-19T00:00:00Z.' },
                work_root: { type: 'string', description: 'attempt: absolute, existing; attempt-<n> is made in it.' },
                backend: { type: 'string', enum: GcTier3Execute::BACKENDS,
                           description: 'attempt: local (default) or thoa. thoa is refused for salted and ' \
                                        'option-2 declarations (it sends the inputs to a service).' },
                declaration_ref: { type: 'object',
                                   description: 'attest: {declaration_digest, recorded_at} from the anchor\'s ' \
                                                'declaration response.' }
              },
              required: %w[action process_dir]
            }
          end

          def call(arguments)
            args = (arguments || {}).transform_keys(&:to_s)
            out = case args['action']
                  when 'declare' then declare(args)
                  when 'attempt' then attempt(args)
                  when 'attest' then attest(args)
                  else raise Refused, "action must be one of #{ACTIONS.join(', ')}"
                  end
            text_content(JSON.pretty_generate(out))
          rescue Refused => e
            text_content("Error: #{e.message}")
          rescue StandardError => e
            # The class only: a message from below could quote a value.
            text_content("Error: gc_tier3_attest failed — #{e.class}")
          end

          private

          # --- declare (§3.3) ------------------------------------------------------------

          def declare(args)
            pdir = absolute!(args, 'process_dir')
            raise Refused, "process_dir already exists: #{pdir}" if File.exist?(pdir)

            signing_key = signing_key!(args)
            tip = string!(args, 'chain_tip_hash')
            subject_ref = string!(args, 'subject_ref')
            route = one_of!(args, 'route', ROUTES)
            form = one_of!(args, 'fingerprint_form', FORMS)
            data_class = one_of!(args, 'data_class', DATA_CLASSES)
            plan = build_plan!(args['build_plan'])
            data = json_object!(args, 'data')
            pipeline = json_object!(args, 'pipeline')
            given_dirs = PIPELINE_DIRS & pipeline.keys
            unless given_dirs.empty?
              raise Refused, "pipeline must not carry #{given_dirs.join(', ')}: each attempt runs in its own fresh " \
                             'directory, which the tool sets'
            end
            inputs = inputs!(args['inputs'])
            attempts_max = args['attempts_max']
            raise Refused, 'attempts_max is required: an integer >= 1' unless attempts_max.is_a?(Integer) && attempts_max >= 1

            expires_at = args['expires_at']
            raise Refused, 'expires_at is required: a UTC time, e.g. 2026-11-19T00:00:00Z' unless ISO.match?(expires_at.to_s)

            rejected = rejected_proposals!(args['rejected_proposals'])
            rows = route == 'B' ? bundle_rows!(args['bundle_rows']) : nil
            # 〔実装の読み〕 the row algorithm picks the comparator (E1).
            comparator = rows&.any? { |_, algo, _| algo == ExactCommitmentFile::ALGORITHM } ? ExactCommitmentFile : ExactSha256File
            # F3: the path is stored and re-read by every later call, so it is
            # absolute, never resolved against a working directory.
            key_path = (form == 'salted' || comparator == ExactCommitmentFile) ? absolute!(args, 'commitment_key_path') : nil
            key = key_path && commitment_key!(key_path)
            fp = Fingerprint.new(form == 'salted' ? key : nil)

            build_plan_digest = fp.value(plan)
            params = {
              'subject_ref' => subject_ref,
              'job_identity' => { 'rule' => R::JOB_IDENTITY_RULE,
                                  'digest' => fp.value('build_plan_digest' => build_plan_digest, 'data' => data,
                                                       'pipeline' => pipeline) },
              'inputs_commitment' => fp.value(inputs.map { |p| fp.file(p) }.sort),
              'comparator' => { 'id' => comparator::ID, 'version' => comparator::VERSION },
              'tolerance' => 'exact',
              'build_plan_digest' => build_plan_digest,
              'fingerprint_form' => form,
              'data_class' => data_class,
              'route' => route,
              'scored_items' => R::SCORED_ITEMS,
              'expires_at' => expires_at,
              'attempts_max' => attempts_max,
              'checker' => { 'tool' => TOOL_VERSION, 'tree_digest' => tree_digest }
            }
            params['commitment'] = C.declaration(key) if form == 'salted'
            # The local copy keeps only what the attempts need that the
            # declaration does not hold in plain; each part is re-checked
            # against the declaration before use.
            job = { 'build_plan' => plan, 'data' => data, 'pipeline' => pipeline, 'commitment_key_path' => key_path }
            proof_id = nil
            if route == 'A'
              targets = route_a_targets!(args['targets'])
              %w[route_ref source source_citation validated_by].each { |f| params[f] = string!(args, f) }
              # 〔実装の読み〕 salted: C over the declared hex, the paper's file being absent.
              items = targets.map do |t|
                { 'path' => t['path'], 'algorithm' => 'sha256', 'value' => fp.salted? ? fp.value(t['sha256']) : t['sha256'] }
              end
              params['targets'] = { 'kind' => 'paper_declared', 'items' => items }
              job['compare'] = targets.map { |t| { 'path' => t['path'], 'value' => t['sha256'] } }
            else
              proof_id = string!(args, 'route_proof_id')
              params['route_ref'] = GenomicschainCore::ProvProofRef.for(proof_id)
              params['targets'] = route_b_targets!(args, rows, comparator)
            end

            operator = envelope(signing_key, params, tip)
            PR.create(pdir, declaration: params, operator: operator, job: job.compact, inference: inference(plan, rejected))

            arguments = { 'action' => 'declaration', 'declaration' => params, 'operator' => operator }
            arguments['route_proof_id'] = proof_id if proof_id
            { 'status' => 'declaration_signed', 'declaration' => params, 'operator' => operator,
              'submit' => { 'tool' => R::MCP_TOOL, 'arguments' => arguments } }
          end

          # Route B (§3.2): the bundle rows verbatim, the recount the anchor
          # will make, and one path per row (review r1 H3: two outputs sharing a
          # name each keep their own) — a relative path for every row the
          # comparator compares, nil for the others.
          def route_b_targets!(args, rows, comparator)
            bundle_digest = args['bundle_digest']
            raise Refused, 'bundle_digest is required for route B: 64 lowercase hex' unless HEX64.match?(bundle_digest.to_s)

            given = args['target_paths'] || Array.new(rows.length)
            unless given.is_a?(Array) && given.length == rows.length
              raise Refused, 'target_paths must be an array with one entry per bundle row (null = the row\'s name)'
            end

            paths = rows.each_with_index.map do |(name, algo, _), i|
              unless algo == comparator::ALGORITHM
                # Fable L3: a path belongs to a row the comparator compares.
                raise Refused, "target_paths[#{i}]: row #{i} is not compared (#{algo}); its entry must be null" unless given[i].nil?

                next nil
              end

              # A row name is a path only when no target_paths entry replaces it.
              path, from = given[i].nil? ? [name, 'bundle_rows'] : [given[i], 'target_paths']
              raise Refused, "#{from}[#{i}]: the path #{INSIDE}" unless inside_path?(path)

              path
            end
            # Pre-flight r2 §2.3: two compared rows on one effective path would
            # compare one file against two values (H3 again, through defaults).
            seen = paths.compact.map { |p| Pathname.new(p).cleanpath.to_s }
            dup = seen.find { |p| seen.count(p) > 1 }
            if dup
              raise Refused, "target_paths: two compared rows share the path #{dup.inspect}; give each its own " \
                             'target_paths entry'
            end
            { 'kind' => 'tier2_5_bundle', 'bundle_digest' => bundle_digest, 'outputs_digest' => R.rows_outputs_digest(rows),
              'rows' => rows, 'paths' => paths }
          end

          # ⑤: what an inference proposed, labelled, with whether it was taken.
          def inference(plan, rejected)
            adopted = plan['steps'].flat_map do |s|
              s['pins'].select { |p| p['origin'] == 'inferred' }.map do |p|
                { 'step' => s['name'], 'name' => p['name'], 'kind' => p['kind'], 'expected' => p['expected'],
                  'origin' => 'inferred', 'adopted' => true }
              end
            end
            not_adopted = rejected.map { |p| p.slice('step', 'name', 'kind', 'expected').merge('origin' => 'inferred', 'adopted' => false) }
            { 'label' => 'inferred', 'proposals' => adopted + not_adopted }
          end

          # The checker's own trees, which built, ran, compared and shaped the
          # signed params (pre-flight r2): tier3 lib/ and tools/, and
          # tier3_record lib/, tools/ and schemas/, found where its loaded code
          # lives. Entries are {path, sha256}, the path prefixed by the package.
          def tree_digest
            record_root = File.expand_path('../../..', Object.const_source_location(R.name).first)
            trees = [[File.expand_path('..', __dir__), %w[lib tools]], [record_root, %w[lib tools schemas]]]
            files = trees.flat_map do |root, subs|
              subs.flat_map do |sub|
                M.walk_files(File.join(root, sub)).map do |f|
                  { 'path' => "#{File.basename(root)}/#{sub}/#{f[:relative_path]}", 'sha256' => f[:sha256] }
                end
              end
            end
            M.canonical_json_sha256(files)
          end

          # --- what attempt and attest act on (review r1 F3) --------------------------------

          # Policy (fingerprint_form, comparator) is the signed declaration's;
          # plan, data, pipeline and targets are the local copy's only once they
          # recompute to the declaration's bindings. The refusal names the
          # binding that differs.
          def verified_job!(copy)
            decl = copy['declaration']
            local = copy['job'] || {}
            comparator = COMPARATORS[decl.dig('comparator', 'id')]
            raise Refused, 'comparator: the declaration names none this tool has' unless comparator

            salted = decl['fingerprint_form'] == 'salted'
            key = (salted || comparator == ExactCommitmentFile) ? job_key!(decl, local) : nil
            fp = Fingerprint.new(salted ? key : nil)
            plan = local['build_plan']
            unless plan.is_a?(Hash) && fp.value(plan) == decl['build_plan_digest']
              raise Refused, 'build_plan: the process record\'s plan is not the one the declaration\'s ' \
                             'build_plan_digest signs; nothing was run'
            end
            identity = { 'build_plan_digest' => decl['build_plan_digest'], 'data' => local['data'],
                         'pipeline' => local['pipeline'] }
            unless fp.value(identity) == decl.dig('job_identity', 'digest')
              raise Refused, 'job_identity: the process record\'s data or pipeline is not what the declaration ' \
                             'signs; nothing was run'
            end

            Job.new(declaration: decl, plan: plan, data: local['data'], pipeline: local['pipeline'],
                    compare: signed_targets!(decl, local, fp, comparator), comparator: comparator, key: key, fp: fp)
          end

          # H7: the key the copy names is used only if it is the key the
          # declaration's commitment.key_id names. A plain declaration over
          # hmac rows declares no key_id, so there is none to compare.
          def job_key!(decl, local)
            path = local['commitment_key_path']
            unless path.is_a?(String) && path.start_with?('/')
              raise Refused, 'commitment_key_path: the process record names no key file for this declaration'
            end

            key = commitment_key!(path)
            declared = decl.dig('commitment', 'key_id')
            if declared && C.key_id(key) != declared
              raise Refused, 'key_id: the commitment key is not the one the declaration\'s commitment.key_id names'
            end

            key
          end

          # The targets to compare, [{path, value}] in declared order. Route B
          # reads them from the declaration (rows and paths are plain there);
          # route A's plain values are the copy's, checked against the signed
          # items (salted: their H).
          def signed_targets!(decl, local, fp, comparator)
            targets = decl['targets']
            if targets['kind'] == 'tier2_5_bundle'
              rows = targets['rows'].each_with_index.select { |(_, algo, _), _| algo == comparator::ALGORITHM }
              return rows.map { |(_, _, hex), i| { 'path' => targets['paths'][i], 'value' => hex } }
            end

            items = targets['items']
            copy = local['compare']
            ok = copy.is_a?(Array) && copy.length == items.length && items.zip(copy).all? do |item, t|
              t.is_a?(Hash) && t['path'] == item['path'] && (fp.salted? ? fp.value(t['value']) : t['value']) == item['value']
            end
            raise Refused, 'targets: the process record\'s targets are not the ones the declaration signs' unless ok

            copy
          end

          # Operator Q6 (§3.4〔実装〕): an attempt started and never scored is
          # scored now, from what the record holds and nothing else — rebuild
          # as recorded (cannot_build if the build never completed), the run's
          # recorded verdict or env_failed, comparison not_attempted. Its number
          # stays used and it counts toward attempts_max.
          def close_interrupted!(record, job)
            scored = record.lines(PR::SCORES).map { |r| r['attempt'] }
            record.started.each do |number, backend|
              record.append(PR::SCORES, closed_row(record, job, number, backend)) unless scored.include?(number)
              record.clear_started(number, backend)
            end
          end

          def closed_row(record, job, number, backend)
            build = record.lines(PR::BUILD).find { |b| b['attempt'] == number }
            row = { 'attempt' => number, 'backend_id' => backend }
            return row.merge('rebuild' => 'cannot_build') unless build && build['rebuild'] == 'built'

            run = record.lines(PR::RUNS).find { |r| r['attempt'] == number }
            row.merge('rebuild' => 'built', 'env_digest' => env_digest(job, build['pins']),
                      'execution_verdict' => run ? run['execution_verdict'] : 'env_failed',
                      'comparison_verdict' => 'not_attempted', 'm' => 0, 'n' => job.compare.length,
                      'output_fingerprints' => [])
          end

          def env_digest(job, pins)
            job.fp.value('env' => job.plan['env'] || {}, 'pins' => pins.map { |p| [p['name'], p['observed']] })
          end

          # --- attempt (§3.1) -------------------------------------------------------------

          def attempt(args)
            record = process_record!(args)
            root = absolute!(args, 'work_root')
            raise Refused, "work_root is not an existing directory: #{root}" unless Dir.exist?(root)

            # Review r3, r4: attempts write into work_root, so it is not the
            # process record nor inside it — compared by identity, which sees
            # through links and macOS firmlinks where a path string does not.
            if within?(root, record.dir) || within?(File.realpath(root), record.dir)
              raise Refused, 'work_root must not be process_dir or lie inside it; no attempt was started'
            end

            backend = (args['backend'] || 'local').to_s
            unless GcTier3Execute::BACKENDS.include?(backend)
              raise Refused, "backend must be one of #{GcTier3Execute::BACKENDS.join(', ')}"
            end

            record.locked { attempt_locked(record, root, backend) }
          end

          def attempt_locked(record, root, backend)
            job = verified_job!(record.read_json(PR::DECLARATION))
            close_interrupted!(record, job)
            # §4.3: the record may be salted, but thoa would still send the inputs out.
            if backend == 'thoa' && (job.fp.salted? || job.comparator == ExactCommitmentFile)
              raise Refused, 'backend thoa is refused for a salted or option-2 declaration: thoa sends the inputs ' \
                             'to a third-party service (design §4.3); use backend local'
            end

            # Operator, Q4 「実行者の側で断る」: attest signs every row, so a row past
            # attempts_max would make an attestation the anchor refuses (§3.4).
            done = record.lines(PR::SCORES).length
            max = job.declaration['attempts_max'].to_i
            if done >= max
              raise Refused, "the process record holds attempts_max (#{max}) attempts already; more attempts need " \
                             'a new declaration (§3.4)'
            end

            n = done + 1
            dir = File.join(root, "attempt-#{n}")
            if File.directory?(dir) && Dir.empty?(dir)
              # No marker and no row of this record name it (review r3). Another
              # record sharing the work_root may own it, so the advice is
              # conditional (review r4 M1; one work_root per process record).
              raise Refused, "work_root holds an empty attempt-#{n} that this process record did not start. It is a " \
                             'removable leftover only if no other process record uses this work_root; then remove it ' \
                             "(rmdir #{dir}) and run attempt again"
            end
            raise Refused, "the attempt location exists already: #{dir}" if File.exist?(dir)

            real_dir = make_attempt_dir!(dir)
            begin
              # The number is used from here on, whatever happens next (§3.4).
              record.mark_started(n, backend)
            rescue SystemCallError => e
              Dir.rmdir(dir) # nothing ran in it; no leftover (review r3)
              raise Refused, "process_dir cannot record the attempt as started (#{e.class.name.split('::').last}); " \
                             'no attempt was started'
            end
            build = BuildRunner.run(job.plan, dir)
            logs = build.logs.map { |what, bytes| { 'what' => what, 'fingerprint' => job.fp.bytes(bytes) } }
            row = { 'attempt' => n, 'backend_id' => backend, 'rebuild' => build.built ? 'built' : 'cannot_build' }
            record.append(PR::BUILD, 'attempt' => n, 'steps' => build.steps, 'pins' => build.pins, 'rebuild' => row['rebuild'])
            if build.built
              run = run_once(job, dir, real_dir, backend)
              logs << { 'what' => 'gc_tier3_execute response', 'fingerprint' => job.fp.bytes(run[:response]) }
              # The run's fact is recorded before the comparison, which may refuse.
              record.append(PR::RUNS, 'attempt' => n, 'backend_id' => backend,
                                      'command' => job.pipeline['command'] || job.pipeline['cmd'], 'runs' => 1,
                                      'execution_verdict' => run[:verdict], 'result_hash' => run[:result_hash])
              if run[:verdict] == 'completed' && one_file_twice?(job, real_dir)
                # Review r3, r4: refused; its logs are kept and the next call
                # closes it as run and not compared (§3.4〔実装〕).
                record.append(PR::LOGS, 'attempt' => n, 'logs' => logs)
                raise Refused, 'targets: two declared targets are one file after the run (a link or a case alias), so ' \
                               "nothing was compared. Attempt #{n} is used; the next call closes it as run and not compared"
              end
              row.merge!('env_digest' => env_digest(job, build.pins))
              row.merge!(compare(job, real_dir, run))
            end
            record.append(PR::LOGS, 'attempt' => n, 'logs' => logs)
            record.append(PR::SCORES, row)
            record.clear_started(n, backend)
            { 'status' => 'attempted', 'attempt' => row, 'workdir' => dir }
          end

          # The attempt directory and its real path come first (review r2 G4): a
          # work_root that cannot take it is refused with no number used, and a
          # directory made but not settled is removed again (review r4).
          def make_attempt_dir!(dir)
            Dir.mkdir(dir, 0o700) # owner-only, like the process record (Fable L5)
            begin
              File.chmod(0o700, dir)
              File.realpath(dir) # fixed before anything runs in it (review r1 F4)
            rescue SystemCallError
              Dir.rmdir(dir)
              raise
            end
          rescue SystemCallError => e
            raise Refused, "work_root cannot take the attempt directory (#{e.class.name.split('::').last}); " \
                           'no attempt was started'
          end

          # Whether path is dir, or lies inside it, by file identity.
          def within?(path, dir)
            loop do
              return true if File.identical?(path, dir)

              parent = File.dirname(path)
              return false if parent == path

              path = parent
            end
          end

          # ② once, runs = 1, in the attempt's own directory, after a snapshot
          # of the declared targets (§3.1 F5).
          def run_once(job, dir, real_dir, backend)
            before = job.compare.to_h { |t| [t['path'], inside_digest(real_dir, t['path'])] }
            # §3.3: the declared pipeline names no directory and the job identity
            # is the declared spec's; the directory is supplied at run time. thoa
            # takes it as pipeline.download_dir (26:66–67), the attempt dir itself.
            pipeline = backend == 'thoa' ? job.pipeline.merge('download_dir' => dir) : job.pipeline
            exec_args = { 'subject_ref' => job.declaration['subject_ref'], 'backend' => backend, 'workdir' => dir,
                          'runs' => 1, 'env' => job.plan['env'] || {}, 'data' => job.data, 'pipeline' => pipeline }
            exec_args['environment_provenance'] = 'authored_by_operator' if inferred?(job.plan)
            text = GcTier3Execute.new(@safety).call(exec_args).first[:text].to_s
            # 〔実装の読み〕 an Error from gc_tier3_execute is a run that did not complete.
            response = text.start_with?('Error:') ? {} : JSON.parse(text)
            { verdict: response['execution_verdict'] || 'env_failed', response: text, before: before,
              result_hash: response.dig('verdict_result', 'result_hash') }
          end

          # ③ only if the run completed, over the declared paths absent before
          # the run or changed by it (§3.1 F5). n is every declared target; m the
          # matches. Targets resolve against the real path fixed before the run,
          # so a pipeline that swaps the directory for a link reads nothing
          # outside.
          def compare(job, real_dir, run)
            targets = job.compare
            row = { 'execution_verdict' => run[:verdict], 'comparison_verdict' => 'not_attempted', 'm' => 0,
                    'n' => targets.length, 'output_fingerprints' => [] }
            return row unless run[:verdict] == 'completed'

            compared = targets.filter_map do |t|
              real = inside_file(real_dir, t['path'])
              next unless real && run[:before][t['path']] != Digest::SHA256.file(real).hexdigest

              # The declared relative path, never the machine's (K3).
              [{ 'path' => t['path'], 'value' => job.fp.file(real) },
               job.comparator.match?(path: real, value: t['value'], key: job.key)]
            end
            m = compared.count(&:last)
            row.merge('comparison_verdict' => comparison_verdict(m, targets.length), 'm' => m,
                      'output_fingerprints' => compared.map(&:first))
          end

          # Two declared targets that are one file after the run (a link, a
          # case alias): the comparison is refused (review r3).
          def one_file_twice?(job, real_dir)
            files = job.compare.filter_map { |t| inside_file(real_dir, t['path']) }
                       .map { |p| File.stat(p).then { |st| [st.dev, st.ino] } }
            files.uniq.length != files.length
          end

          def comparison_verdict(matched, declared)
            return 'no_target_declared' if declared.zero?

            matched == declared ? 'match_exact' : 'mismatch'
          end

          def inferred?(plan) = plan['steps'].any? { |s| s['pins'].any? { |p| p['origin'] == 'inferred' } }

          # --- attest (§4.1) --------------------------------------------------------------

          def attest(args)
            record = process_record!(args)
            signing_key = signing_key!(args)
            tip = string!(args, 'chain_tip_hash')
            ref = args['declaration_ref']
            unless ref.is_a?(Hash) && HEX64.match?(ref['declaration_digest'].to_s) && ISO.match?(ref['recorded_at'].to_s)
              raise Refused, 'declaration_ref is required: {declaration_digest, recorded_at} from the anchor\'s ' \
                             'declaration response'
            end

            record.locked { attest_locked(record, signing_key, tip, ref) }
          end

          def attest_locked(record, signing_key, tip, ref)
            job = verified_job!(record.read_json(PR::DECLARATION))
            unless ref['declaration_digest'] == M.canonical_json_sha256(job.declaration)
              raise Refused, 'declaration_ref: its declaration_digest is not this process record\'s declaration'
            end

            close_interrupted!(record, job)
            rows = record.lines(PR::SCORES)
            raise Refused, 'attest needs at least one attempt row; run action attempt first' if rows.empty?

            runs = record.lines(PR::RUNS).to_h { |r| [r['attempt'], r] }
            results = rows.map do |row|
              run = runs[row['attempt']]
              run && run['execution_verdict'] == 'completed' ? run['result_hash'] : nil
            end
            manifest = record.write_manifest(job.fp)
            params = job.declaration.slice(*R::BINDING_FIELDS, 'commitment').merge(
              'declaration_ref' => { 'declaration_digest' => ref['declaration_digest'], 'recorded_at' => ref['recorded_at'] },
              'attempts' => rows, 'environment_provenance' => environment_provenance(job),
              'result_commitment' => job.fp.value(results), 'process_record_digest' => job.fp.file(manifest),
              'not_checked' => R::NOT_CHECKED
            )
            operator = envelope(signing_key, params, tip)
            { 'status' => 'attestation_signed', 'attestation' => params, 'operator' => operator,
              'submit' => { 'tool' => R::MCP_TOOL,
                            'arguments' => { 'action' => 'attestation', 'attestation' => params, 'operator' => operator } } }
          end

          # §4.1 table: an inferred pin makes the environment the operator's;
          # otherwise it is derived as gc_tier3_execute derives it (13:186–194).
          def environment_provenance(job)
            return 'authored_by_operator' if inferred?(job.plan)

            spec = Execution::JobSpec.new(subject_ref: job.declaration['subject_ref'], env: job.plan['env'] || {},
                                          data: job.data, pipeline: job.pipeline, backend_id: nil, resources: {})
            Tier3Executor.derive_environment_provenance(spec)
          end

          # --- signing and keys (§4.2) ------------------------------------------------------

          # The envelope SubmitCore verifies (Signer#verify_signed!), built as
          # scripts/gc_submit_client.rb builds it.
          def envelope(signing_key, params, tip)
            nonce = SecureRandom.hex(16)
            payload = M.canonical_json('mcp_tool_name' => R::MCP_TOOL, 'params' => params, 'nonce' => nonce,
                                       'chain_tip_hash' => tip)
            { 'mode' => 'signed',
              'pubkey' => 'ed25519:' + Base64.urlsafe_encode64(signing_key.verify_key.to_bytes, padding: false),
              'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                               'value' => Base64.urlsafe_encode64(signing_key.sign(payload), padding: false),
                               'nonce' => nonce, 'chain_tip_hash' => tip } }
          end

          # The gc_submit_client key format: base64 of the 32-byte seed, or 64 hex.
          def signing_key!(args)
            path = string!(args, 'signing_key_path')
            raw = File.read(path).strip
            seed = raw.length == 64 && raw.match?(/\A[0-9a-f]+\z/i) ? [raw].pack('H*') : Base64.decode64(raw)
            raise Refused, 'signing_key_path does not hold a 32-byte ed25519 seed' unless seed.bytesize == 32

            Ed25519::SigningKey.new(seed)
          rescue SystemCallError => e
            raise Refused, "signing_key_path cannot be read (#{e.class.name.split('::').last})"
          end

          # C's own messages name the rule and the byte count, never a byte.
          def commitment_key!(path)
            C.read_key_file(path)
          rescue C::KeyError => e
            raise Refused, "commitment_key_path: #{e.message}"
          end

          # --- arguments -----------------------------------------------------------------

          def process_record!(args)
            record = PR.new(absolute!(args, 'process_dir'))
            raise Refused, 'process_dir holds no declaration; run action declare first' unless record.declared?

            record
          end

          def absolute!(args, name)
            value = args[name]
            raise Refused, "#{name} is required: an absolute path" unless value.is_a?(String) && value.start_with?('/')

            File.expand_path(value)
          end

          def string!(args, name)
            value = args[name]
            raise Refused, "#{name} is required" unless value.is_a?(String) && !value.empty?

            value
          end

          def one_of!(args, name, allowed)
            value = args[name]
            raise Refused, "#{name} must be one of #{allowed.join(', ')}" unless allowed.include?(value)

            value
          end

          # Values are signed as the anchor will re-serialise them: plain JSON.
          def json_object!(args, name)
            value = args[name]
            raise Refused, "#{name} is required: an object" unless value.is_a?(Hash)

            JSON.parse(JSON.generate(value))
          end

          def strings?(value) = value.is_a?(Array) && !value.empty? && value.all?(String)

          def inside_path?(path)
            path.is_a?(String) && !path.empty? && !path.start_with?('/', '~') && !path.split('/').include?('..') &&
              !path.match?(/[\x00-\x1f\x7f\u0080-\u009f]/)
          end

          # K3: the target's real path when it is a file inside the attempt
          # dir's fixed real path; nil otherwise — absent, dangling, or a link
          # leading out (planted by a build step or the pipeline), never read.
          def inside_file(real_dir, rel)
            return nil unless rel.is_a?(String)

            real = File.realpath(File.join(real_dir, rel))
            real.start_with?(real_dir + File::SEPARATOR) && File.file?(real) ? real : nil
          rescue SystemCallError
            nil
          end

          def inside_digest(real_dir, rel)
            real = inside_file(real_dir, rel)
            real && Digest::SHA256.file(real).hexdigest
          end

          def build_plan!(raw)
            plan = raw.is_a?(Hash) ? JSON.parse(JSON.generate(raw)) : nil
            raise Refused, 'build_plan is required: an object with steps' unless plan && plan['steps'].is_a?(Array)
            raise Refused, 'build_plan.env must be an object' unless plan['env'].nil? || plan['env'].is_a?(Hash)

            plan['steps'].each_with_index do |s, i|
              at = "build_plan.steps[#{i}]"
              raise Refused, "#{at} must be an object" unless s.is_a?(Hash)
              raise Refused, "#{at}.name is required" unless s['name'].is_a?(String) && !s['name'].empty?
              raise Refused, "#{at}.command must be a non-empty array of strings" unless strings?(s['command'])
              raise Refused, "#{at}.command holds a NUL byte" if s['command'].any? { |a| a.include?("\0") }
              raise Refused, "#{at}.pins must be an array" unless s['pins'].is_a?(Array)

              s['pins'].each_with_index { |p, j| pin!(p, "#{at}.pins[#{j}]") }
            end
            # A (step name, pin name) pair names one pin: its observations and
            # its env_digest entry (review r2 G4).
            ids = plan['steps'].flat_map { |s| s['pins'].map { |p| [s['name'], p['name']] } }
            dup = ids.find { |id| ids.count(id) > 1 }
            raise Refused, "build_plan: the pin #{dup.last.inspect} of step #{dup.first.inspect} is declared twice" if dup

            plan
          end

          def pin!(pin, at)
            raise Refused, "#{at} must be an object" unless pin.is_a?(Hash)
            raise Refused, "#{at}.name is required" unless pin['name'].is_a?(String) && !pin['name'].empty?
            raise Refused, "#{at}.kind must be one of #{PIN_KINDS.join(', ')}" unless PIN_KINDS.include?(pin['kind'])
            raise Refused, "#{at}.expected is required" unless pin['expected'].is_a?(String)
            raise Refused, "#{at}.observe must be a non-empty array of strings" unless strings?(pin['observe'])
            raise Refused, "#{at}.observe holds a NUL byte" if pin['observe'].any? { |a| a.include?("\0") }
            raise Refused, "#{at}.origin must be one of #{PIN_ORIGINS.join(', ')}" unless PIN_ORIGINS.include?(pin['origin'])
          end

          # An input that cannot be read has no fingerprint in either form
          # (review r1 F3); refused before anything is made.
          def inputs!(raw)
            raise Refused, 'inputs is required: an array of absolute file paths' unless raw.is_a?(Array)

            raw.each_with_index do |p, i|
              unless p.is_a?(String) && p.start_with?('/') && File.file?(p) && File.readable?(p)
                raise Refused, "inputs[#{i}] is not an absolute path of a readable file"
              end
            end
            raw
          end

          def route_a_targets!(raw)
            raise Refused, 'targets is required for route A: [{path, sha256}], [] when none is declared' unless raw.is_a?(Array)

            raw.each_with_index.map do |t, i|
              t = t.is_a?(Hash) ? t.transform_keys(&:to_s) : {}
              raise Refused, "targets[#{i}].path #{INSIDE}" unless inside_path?(t['path'])
              raise Refused, "targets[#{i}].sha256 must be 64 lowercase hex" unless HEX64.match?(t['sha256'].to_s)

              t.slice('path', 'sha256')
            end.tap do |targets|
              # Two items on one file would compare it against two values (review r2 G4).
              clean = targets.map { |t| Pathname.new(t['path']).cleanpath.to_s }
              dup = clean.find { |p| clean.count(p) > 1 }
              raise Refused, "targets: two items name the path #{dup.inspect}" if dup
            end
          end

          def bundle_rows!(raw)
            ok = raw.is_a?(Array) && !raw.empty? && raw.all? { |r| r.is_a?(Array) && r.length == 3 && r.all?(String) }
            raise Refused, 'bundle_rows is required for route B: [[name, algorithm, hex], ...] verbatim, at least one' unless ok

            raw
          end

          def rejected_proposals!(raw)
            return [] if raw.nil?

            ok = raw.is_a?(Array) && raw.all?(Hash)
            raise Refused, 'rejected_proposals must be an array of {step, name, kind, expected}' unless ok

            raw.map { |p| p.transform_keys(&:to_s) }
          end
        end
      end
    end
  end
end
