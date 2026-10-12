# frozen_string_literal: true

require 'json'
require_relative '../writer'
require_relative 'environment'

module GenomicsChainProv
  module Writer
    # NextflowRun — the enricher half of `gc_prov_write`
    # (`--from-nextflow-run <launch_dir>`, design §13.4-1).
    #
    # U0 measured what nf-prov 1.7.0 actually writes (design §13, fixture
    # `test/fixtures/nfcore_demo_1_2_0`): the SCM extension, the parameters,
    # the URIs and one runtime line. No tool versions, no containers, no
    # checksums — not because the run lacked them but because the renderer has
    # no field for them. Graded as it stands, that bundle is `absent`: honest,
    # and useless as a headline.
    #
    # Everything missing is still in the run directory. This module reads it
    # back out:
    #
    #   results/pipeline_info/*_versions.yml   tool names and versions, per process
    #   work/<hash>/.command.run               the image each task actually ran
    #   docker image inspect                   that image's digest
    #   the framework jar                      the runtime's own checksum (§10-9)
    #   the files themselves                   input and output checksums
    #
    # Where it puts them matters as much as what it collects:
    #
    #   per-stage tools → that stage's `prerequisite[]` ONLY. Copied up to
    #     `software_prerequisites[]` they become a fallback covering every
    #     stage, and `stages_with_own_environment/stages_total` — the coverage
    #     the claim carries — stops meaning anything (review round 2).
    #   `software_prerequisites[]` → left exactly as nf-prov wrote it: one
    #     runtime line.
    #   every SHA-256 → the GenomicsChain extension's `checksums[]`, keyed by
    #     the locator of the thing digested, because that exact-locator join is
    #     what the adapter reads for a tool, the runtime and the script alike
    #     (round 3: until then there was somewhere to write them and nowhere
    #     that read them).
    #   an io entry's SHA-1 → its own `sha1_checksum`, the standard's field.
    #
    # Nothing here fetches anything. A locator naming a remote file is left as
    # it is: a checksum this machine did not compute from bytes it had is not
    # a checksum of the run.
    module NextflowRun
      module_function

      # --- pure readers -------------------------------------------------------

      # `NFCORE_DEMO:DEMO:FASTQC (SAMPLE1_PE)` → `FASTQC`. The suffix in
      # parentheses is the tag of one task among several of the same process,
      # and versions.yml is keyed by the process.
      def process_name(description)
        s = description.to_s.sub(/\s*\([^)]*\)\s*\z/, '').strip
        s.split(':').last
      end

      # nf-core writes `<PROCESS>:\n  <tool>: <version>` and a `Workflow:`
      # block for the pipeline and the engine. Read line by line rather than
      # through YAML on purpose: Psych turns an unquoted `1.10` into the Float
      # 1.1, and a version string quietly losing a digit would be signed.
      def tools_from_versions_yml(text)
        out = {}
        current = nil
        text.each_line do |line|
          next if line.strip.empty? || line.strip.start_with?('#')

          if (m = line.match(/\A(\S[^:]*):\s*\z/))
            current = m[1].strip
            out[current] ||= []
          elsif current && (m = line.match(/\A\s+(\S[^:]*?):\s*(\S.*?)\s*\z/))
            out[current] << { 'name' => m[1].strip, 'version' => unquote(m[2]) }
          end
        end
        out
      end

      # Docker's `run` line inside `nxf_launch()`. The image is the first
      # non-flag token after `run`. Flags that take a value are listed because
      # skipping one wrongly would return its VALUE as the image, so the token
      # is checked against an image shape before it is believed — an ambiguous
      # line yields nothing and says so rather than naming the wrong image in
      # a record somebody will sign.
      DOCKER_VALUE_FLAGS = %w[
        --add-host --annotation --attach --blkio-weight --cap-add --cap-drop --cgroup-parent --cgroupns
        --cidfile --cpu-period --cpu-quota --cpu-rt-period --cpu-rt-runtime --cpu-shares --cpus
        --cpuset-cpus --cpuset-mems --device --device-cgroup-rule --dns --dns-option --dns-search
        --entrypoint --env --env-file --expose --gpus --group-add --health-cmd --health-interval
        --health-retries --health-start-period --health-timeout --hostname --ip --ip6 --ipc --isolation
        --kernel-memory --label --label-file --link --log-driver --log-opt --mac-address --memory
        --memory-reservation --memory-swap --memory-swappiness --mount --name --network --network-alias
        --oom-score-adj --pid --pids-limit --platform --publish --pull --restart --runtime --security-opt
        --shm-size --stop-signal --stop-timeout --storage-opt --sysctl --tmpfs --ulimit --user --userns
        --uts --volume --volume-driver --volumes-from --workdir
      ].freeze
      DOCKER_SHORT_VALUE_FLAGS = %w[-a -c -e -h -l -m -p -u -v -w].freeze
      # registry[:port]/repo…[:tag][@sha256:…]. Deliberately loose about the
      # registry — what matters here is telling an image apart from a path, a
      # `KEY=value` and a flag.
      IMAGE_LIKE = %r{
        \A(?!-)(?![./])
        [A-Za-z0-9][A-Za-z0-9._-]*(?::[0-9]+)?
        (?:/[A-Za-z0-9._-]+)*
        (?::[A-Za-z0-9._-]+)?
        (?:@sha256:[0-9a-f]{64})?\z
      }x

      def image_from_command_run(text)
        line = text.lines.find { |l| l =~ /(?:\A|\s|\()(?:docker|podman)\s+run\s/ }
        return nil if line.nil?

        tokens = shell_split(line[/(?:docker|podman)\s+run\s.*/].to_s)
        return nil if tokens.nil? || tokens.length < 3

        candidate = skip_flags(tokens.drop(2), DOCKER_VALUE_FLAGS, DOCKER_SHORT_VALUE_FLAGS)
        return nil if candidate.nil? || candidate.include?('=') || candidate !~ IMAGE_LIKE

        candidate
      end

      # Walks argv from the first argument after the subcommand and returns the
      # first token that is not a flag or a flag's value. `--flag=value` takes
      # no separate value; a long flag not in the list is taken as a boolean.
      def skip_flags(tokens, value_flags, short_value_flags)
        i = 0
        while i < tokens.length
          t = tokens[i]
          if t.start_with?('--')
            i += t.include?('=') || !value_flags.include?(t) ? 1 : 2
          elsif t.start_with?('-') && t.length > 1
            i += short_value_flags.include?(t) ? 2 : 1
          else
            return t
          end
        end
        nil
      end

      def shell_split(line)
        require 'shellwords'
        Shellwords.split(line)
      rescue ArgumentError
        nil
      end

      # `docker images --digests`, or any capture of it: a line naming a
      # reference and a `sha256:…` on the same line. Comments and extra columns
      # are ignored, so a hand-kept file and the command's own output both
      # read — the command prints REPOSITORY and TAG in separate columns, a
      # kept file usually writes them joined.
      def digests_from(text)
        out = {}
        text.each_line do |line|
          next if line.strip.empty? || line.strip.start_with?('#')

          digest = line[/\bsha256:[0-9a-f]{64}\b/i]
          next if digest.nil?

          tokens = line.split(/\s+/).reject(&:empty?)
          ref = tokens.find { |t| t != digest && t.include?(':') && t =~ IMAGE_LIKE }
          ref ||= joined_repo_tag(tokens, tokens.index(digest))
          out[ref] = digest if ref
        end
        out
      end

      def joined_repo_tag(tokens, at)
        return nil if at.nil? || at < 2

        repo, tag = tokens[at - 2], tokens[at - 1]
        return nil unless repo =~ IMAGE_LIKE && tag =~ /\A[A-Za-z0-9._-]+\z/

        "#{repo}:#{tag}"
      end

      # A trace with a `container` column (`trace.fields` has to be told to add
      # it; the default 14 columns have no such column — U0, design §13.3).
      # Keyed by the short task hash the trace prints, e.g. `7a/51f65b`.
      def containers_from_trace(text)
        rows = text.lines.reject { |l| l.strip.empty? }
        return {} if rows.empty?

        header = rows.first.chomp.split("\t")
        hash_at = header.index('hash')
        container_at = header.index('container')
        return {} if hash_at.nil? || container_at.nil?

        rows.drop(1).each_with_object({}) do |line, acc|
          cells = line.chomp.split("\t")
          ref = cells[container_at].to_s.strip
          acc[cells[hash_at].to_s.strip] = ref unless ref.empty? || ref == '-'
        end
      end

      # `work/7a/51f65ba…` for a step. nf-prov names a step by its full task
      # hash; when it does not, the work path is in the step's own io lists.
      def work_dir_of(step)
        name = step['name'].to_s
        return "work/#{name[0, 2]}/#{name[2..]}" if name =~ /\A[0-9a-f]{32}\z/i

        (Array(step['output_list']) + Array(step['input_list'])).each do |e|
          next unless e.is_a?(Hash)

          m = e['uri'].to_s.match(%r{\A(.*\bwork/[0-9a-f]{2}/[0-9a-f]+)/}i)
          return m[1] if m
        end
        nil
      end

      def unquote(value)
        value.to_s.strip.sub(/\A(['"])(.*)\1\z/m, '\2')
      end

      # --- enrichment (pure) --------------------------------------------------

      # @param bco [Hash] the bundle as the producer wrote it
      # @param tools_by_step [Hash] step_number => [{'name','version'}]
      # @param image_by_step [Hash] step_number => an image reference, digest-pinned where one was found
      # @param checksums [Hash] locator => {'sha1' =>, 'sha256' =>}
      # @param platform [Hash, nil] written only when the caller asked for it (design
      #   v0.1.12 §6.1: the machine running the enricher need not be the one the
      #   tasks ran on)
      # @param zk_receipts [Array<Hash>] receipt declarations (Writer.zk_declaration)
      # @return [Hash] a new bundle; the argument is not touched, because the
      #   digest subject is the bytes that were read (§4)
      # @return [Array(Hash, Array<String>)] the new bundle and what it refused
      #   to do. Refusals matter here: a field the standard defines as an array
      #   and the bundle writes as something else is a bundle the adapter
      #   rejects, and an enricher that quietly replaced it would turn a
      #   malformed bundle into one that parses — laundering the very defect
      #   the boundary rule exists to surface (§5, round 7).
      def enrich(bco, tools_by_step: {}, image_by_step: {}, checksums: {}, platform: nil, zk_receipts: [])
        out = JSON.parse(JSON.generate(bco))
        refused = []
        steps = out.dig('description_domain', 'pipeline_steps')
        Array(steps).each do |step|
          next unless step.is_a?(Hash)

          number = step['step_number']
          entries = stage_prerequisites(tools_by_step[number], image_by_step[number], step)
          next if entries.empty?

          if step.key?('prerequisite') && !step['prerequisite'].is_a?(Array)
            refused << "step #{number}: prerequisite is not an array; left untouched"
            next
          end
          existing = Array(step['prerequisite']).select { |e| e.is_a?(Hash) }
          keep = existing.reject { |e| entries.any? { |n| n['name'] == e['name'] } }
          step['prerequisite'] = keep + entries
        end
        apply_io_checksums!(out['io_domain'], checksums)
        refused.concat(set_extension!(out, checksums, platform: platform, zk_receipts: zk_receipts))
        [out, refused]
      end

      # One `{name, version, uri}` per tool the process declared, each carrying
      # the image the task ran in. When versions.yml knows no tool for the
      # process but the image is known, the process's own name is used — it is
      # in the bundle already, so nothing is invented — and the stage still
      # declares an environment of its own through the container route.
      def stage_prerequisites(tools, image, step)
        list = Array(tools)
        if list.empty?
          return [] if image.nil?

          list = [{ 'name' => process_name(step['description']) }]
        end
        list.map do |t|
          Writer.compact_h('name' => t['name'], 'version' => t['version'],
                           'uri' => (image ? { 'uri' => image } : nil))
        end
      end

      def apply_io_checksums!(io, checksums)
        return unless io.is_a?(Hash)

        %w[input_subdomain output_subdomain].each do |key|
          Array(io[key]).each do |entry|
            next unless entry.is_a?(Hash) && entry['uri'].is_a?(Hash)

            sha1 = checksums.dig(entry['uri']['uri'].to_s, 'sha1')
            entry['uri']['sha1_checksum'] = sha1 if sha1
          end
        end
      end

      # Replaces this writer's own block rather than adding a second one: run
      # twice, two blocks naming the same producer would merge (round 6) but
      # two naming DIFFERENT producers cancel each other out, and a bundle
      # whose enrichment history is visible in its array length is a bundle
      # whose grade depends on how many times a command was run.
      def set_extension!(bco, checksums, platform: nil, zk_receipts: [])
        if bco.key?('extension_domain') && !bco['extension_domain'].is_a?(Array)
          return ['extension_domain is not an array; left untouched, and no checksum was written']
        end

        block = Writer.extension_block(checksums, platform: platform, zk_receipts: zk_receipts)
        list = bco['extension_domain'] || []
        at = list.index do |e|
          e.is_a?(Hash) && e.dig('genomicschain_extension', 'producer', 'name') == Writer::PRODUCER_NAME
        end
        at ? list[at] = block : list << block
        bco['extension_domain'] = list
        []
      end

      # --- reading a launch directory ----------------------------------------

      # @return [Hash] {'bco' => the enriched bundle, 'notes' => [String]}
      def read(launch_dir, bco:, versions_path: nil, trace_path: nil, work_root: 'work',
               digest_map: {}, script_path: nil, jar_path: nil, checksums: true, docker: true,
               platform: nil, zk_receipts: [])
        notes = []
        steps = Array(bco.dig('description_domain', 'pipeline_steps')).select { |s| s.is_a?(Hash) }

        tools_by_step = tools_by_step(steps, launch_dir, versions_path, notes)
        image_by_step = image_by_step(steps, launch_dir, work_root, trace_path, digest_map, docker, notes)
        sums = checksums ? collect_checksums(bco, launch_dir, script_path, jar_path, notes) : {}
        notes << 'checksums were skipped (--no-checksums)' unless checksums

        enriched, refused = enrich(bco, tools_by_step: tools_by_step, image_by_step: image_by_step,
                                        checksums: sums, platform: platform, zk_receipts: zk_receipts)
        { 'bco' => enriched, 'notes' => notes + refused }
      end

      def tools_by_step(steps, launch_dir, versions_path, notes)
        path = versions_path || Dir[File.join(launch_dir, '**', '*_versions.yml')].sort.first
        if path.nil? || !File.file?(path)
          notes << 'no *_versions.yml under the launch directory: no tool versions collected'
          return {}
        end

        by_process = tools_from_versions_yml(File.read(path))
        steps.each_with_object({}) do |step, acc|
          found = by_process[process_name(step['description'])]
          if found.nil? || found.empty?
            notes << "step #{step['step_number']}: versions.yml names no tool for " \
                     "#{process_name(step['description'])}"
            next
          end
          acc[step['step_number']] = found
        end
      end

      def image_by_step(steps, launch_dir, work_root, trace_path, digest_map, docker, notes)
        trace = trace_path && File.file?(trace_path) ? containers_from_trace(File.read(trace_path)) : {}
        notes << 'the trace has no container column: images come from .command.run only' if trace_path && trace.empty?
        digests = digest_map.dup

        steps.each_with_object({}) do |step, acc|
          dir = work_dir_of(step)
          ref = image_from_work_dir(launch_dir, work_root, dir)
          ref ||= trace_image(trace, dir)
          if ref.nil?
            notes << "step #{step['step_number']}: no container found (no .command.run, no trace column)"
            next
          end
          acc[step['step_number']] = pin(ref, digests, docker, step['step_number'], notes)
        end
      end

      def image_from_work_dir(launch_dir, work_root, dir)
        return nil if dir.nil?

        path = File.join(launch_dir, dir.sub(%r{\Awork/}, "#{work_root}/"), '.command.run')
        File.file?(path) ? image_from_command_run(File.read(path)) : nil
      end

      # The trace prints an abbreviated hash (`7a/51f65b`) where the bundle
      # carries the full one, so the abbreviation is matched as a prefix.
      def trace_image(trace, dir)
        return nil if dir.nil? || trace.empty?

        key = dir.sub(%r{\A.*\bwork/}, '')
        _, ref = trace.find { |short, _| key.start_with?(short) }
        ref
      end

      def pin(ref, digests, docker, step_number, notes)
        return ref if ref =~ /@sha256:[0-9a-f]{64}\z/i

        digest = digests[ref] || (docker ? Environment.repo_digest(ref) : nil)
        if digest.nil?
          notes << "step #{step_number}: no digest for #{ref}; the tag alone grades `versioned`"
          return ref
        end
        digests[ref] = digest
        "#{ref}@#{digest}"
      end

      # Checksums for everything this machine can still read: the io entries,
      # the workflow script, and the framework jar keyed by the runtime's own
      # locator (§10-9 — the jar is the engine, and the release URL the bundle
      # names is what the record joins it to).
      def collect_checksums(bco, launch_dir, script_path, jar_path, notes)
        sums = {}
        io = bco['io_domain'].is_a?(Hash) ? bco['io_domain'] : {}
        %w[input_subdomain output_subdomain].each do |key|
          Array(io[key]).each do |entry|
            next unless entry.is_a?(Hash) && entry['uri'].is_a?(Hash)

            locator = entry['uri']['uri'].to_s
            next if locator.empty? || locator =~ Environment::REMOTE_SCHEME

            digests = Environment.digest_file(Environment.absolute(locator, launch_dir))
            sums[locator] = digests if digests
          end
        end
        notes << 'no io file under the launch directory could be read: the run directory is gone' if sums.empty?

        add_file_checksum(sums, script_locator(bco), script_path, notes,
                          'workflow script', '--script PATH')
        add_file_checksum(sums, runtime_locator(bco), jar_path || runtime_jar(bco), notes,
                          'runtime (the framework jar)', '--nextflow-jar PATH')
        sums
      end

      def add_file_checksum(sums, locator, path, notes, what, flag)
        return if locator.nil? || locator.empty?

        if path.nil?
          notes << "no checksum for the #{what}: it was not found on this machine — pass #{flag}"
          return
        end
        unless File.file?(path)
          notes << "no checksum for the #{what}: #{path} is not a readable file"
          return
        end

        digests = Environment.digest_file(path)
        sums[locator] = digests if digests
      end

      def script_locator(bco)
        first = Array(bco.dig('execution_domain', 'script')).first
        return first if first.is_a?(String)

        first.is_a?(Hash) ? (first['uri'].is_a?(Hash) ? first['uri']['uri'] : first['uri']).to_s : nil
      end

      def runtime_entry(bco)
        ed = bco['execution_domain']
        return nil unless ed.is_a?(Hash)

        engine = ed['script_driver'].to_s
        Array(ed['software_prerequisites']).find { |s| s.is_a?(Hash) && s['name'].to_s.casecmp?(engine) }
      end

      def runtime_locator(bco)
        entry = runtime_entry(bco)
        return nil if entry.nil?

        (entry['uri'].is_a?(Hash) ? entry['uri']['uri'] : entry['uri']).to_s
      end

      def runtime_jar(bco)
        entry = runtime_entry(bco)
        entry && Environment.nextflow_jar(entry['version'].to_s)
      end
    end
  end
end
