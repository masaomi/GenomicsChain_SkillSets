# frozen_string_literal: true

require 'json'

module GenomicsChainProv
  # Resources — the computing resources a bundle states, and the grade they
  # earn (design v0.1.14 §6.2, rule `gc-resources-0.1`).
  #
  # Tier 3 needs to know what each stage asked for and used before it can
  # choose a machine to rebuild on: most nf-core failures are a stage asking
  # for more than the machine has, and in machine learning the GPU vendor and
  # model decide whether a run starts at all.
  #
  # A reader of its own, beside the adapter rather than inside it. The adapter
  # (0.4.0) and the predicate (0.3.7) are left exactly as they were, so the
  # seven pin-strength grades of every existing record still re-derive under
  # the new verifier; this rule carries its own version in the record and can
  # move without touching them. It takes the stage list from the adapter —
  # the positions after sorting on step_number — and nothing else.
  #
  # Never refuses. A `resources` block that is not an object, a `steps` that
  # is not an array, a value that is not a number: each reads as absent, and
  # the grade falls. A bundle that a 0.3 anchor would record must stay
  # recordable (queue item, frozen review).
  #
  # Self-reported: the anchor re-derives the grade from what the bundle says
  # and never checks that it is true (`resources_as_written` on the record).
  # Nothing here reads a clock, a file, the network or the environment.
  module Resources
    RULE_VERSION = 'gc-resources-0.1'
    LEVELS = %w[absent partial steps full].freeze

    # The nine fields record_version 0.4 adds to the signed identity (§6.2 (3)).
    SIGNED_FIELDS = %w[resources_rule_version grade_resources
                       stages_with_requested_resources stages_with_observed_resources
                       gpus_total gpu_models gpu_vendors_probed machine_source resources_sources].freeze

    SOURCES = %w[nextflow_trace snakemake_benchmark gnu_time bsd_time gc_resources_input plan].freeze
    REQUESTED_KEYS = %w[cpus memory_bytes time_seconds disk_bytes accelerators].freeze
    # §6.2 (2): several values for one stage (retries, scatter, one benchmark
    # file per job) reduce to the largest single job for everything that
    # sizes a machine, and to the sum for what was read and written.
    OBSERVED_MAX = %w[peak_memory_bytes realtime_seconds cpu_percent].freeze
    OBSERVED_SUM = %w[read_bytes write_bytes].freeze
    MACHINE_NUMBERS = %w[logical_cores memory_total_bytes disk_free_bytes].freeze
    MACHINE_SOURCES = %w[probe plan].freeze

    # The vendors a probe covers, by the probe's name (§6.2 (3)). Taken from
    # this table, never from the bundle, so a bundle cannot claim to have
    # looked for a vendor its probe cannot see. Linux has no Intel probe.
    PROBE_VENDORS = { 'nvidia-smi' => %w[nvidia], 'rocm-smi' => %w[amd],
                      'system_profiler' => %w[amd apple intel] }.freeze
    GPU_VENDORS = %w[amd apple intel nvidia].freeze
    MAX_GPU_MODELS = 16
    MAX_GPU_COUNT = 64
    MAX_MODEL_CHARS = 128

    # The anchor publishes a model name only when it cannot be an identifier
    # of a machine or a person (§6.2 (3), extended at implementation by the
    # operator's choices on 2026-10-17: a closed vendor list; the shapes of a
    # serial, a host name, an IP address and a MAC; a string starting with
    # `/`; a run of eight or more digits). The serial, host, IP, MAC, hex and
    # digit shapes are matched wherever they sit in the string, whatever
    # delimiter surrounds them (implementation review r1: `NVIDIA (node3.local)`
    # passed); the path shape only at the start, as the operator worded it.
    # A dropped model is still counted in gpus_total; the difference between
    # the two is what was withheld.
    #
    # Known residue, named for the reader (operator, 2026-10-17, and review
    # r2): a host name without a dot (`Johns-MacBook-Pro`), a short service
    # tag, a path inside the string (`A100 /scratch/jdoe`), a serial in
    # dash-separated groups of four (`Z9Y8-X7W6-V5U4`) and a MAC in three dashed
    # quads (`001a-2b3c-4d5e`) cannot be told from model text and pass. AMD
    # names in the bracketed PCI form (`Navi 31 [Radeon RX 7900 XT]`) are
    # withheld, since `[` `]` are not allowed characters.
    MODEL_CHARS = %r{\A[A-Za-z0-9 ._\-()+/]+\z}
    # A UUID always holds a run of twelve hex digits, so this one rule drops
    # both (a separate UUID rule could never change the result).
    HEX_RUN = /[0-9a-f]{12,}/i
    LONG_DIGITS = /\d{8,}/
    # dotted, dashed or underscored: 10.0.0.17, ip-10-0-1-23, 10_0_0_17
    IPV4_SHAPE = /\d{1,3}(?:[._-]\d{1,3}){3}/
    # six pairs joined by -, _ or a space, or the dotted three-quad form
    MAC_SHAPE = /[0-9a-f]{2}(?:[-_ ][0-9a-f]{2}){5}|[0-9a-f]{4}\.[0-9a-f]{4}\.[0-9a-f]{4}/i
    # a word with two dots, or a dot followed by a name: gpu17.cluster.uzh.ch, node3.local
    HOST_SHAPE = /[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+|[A-Za-z0-9-]+\.[A-Za-z]{2,}(?![A-Za-z0-9])/
    PATH_SHAPE = %r{\A/}
    # a serial: eight or more letters and digits in one word, at least three of each
    SERIAL_WORD = 8

    module_function

    # @param text [String] the bundle as JSON text, already readable by the adapter
    # @param stages [Array<Hash>] NormalizedProvenance#stages ('id' = position, 'step_number')
    # @return [Hash] 'signed' (the nine fields), 'machine' and 'steps' as read
    #   (for the customer's own view, never for the anchor's logs), 'notes'
    def derive(text, stages)
      notes = []
      blocks = resource_blocks(text)
      by_number = stages.to_h { |s| [s['step_number'], s['id']] }
      machine = merge_machines(blocks.filter_map { |b| read_machine(b['machine'], notes) }, notes)
      steps = merge_steps(blocks.map { |b| read_steps(b['steps'], by_number, notes) }, notes)
      { 'signed' => signed(machine, steps, stages.length), 'machine' => machine, 'steps' => steps, 'notes' => notes }
    end

    # --- reading -------------------------------------------------------------

    # Every `genomicschain_extension.resources` object in the bundle, in
    # array order. The adapter has already refused a bundle whose
    # extension_domain is not an array, so anything else here is a shape
    # that says nothing about resources.
    def resource_blocks(text)
      bco = JSON.parse(text)
      list = bco.is_a?(Hash) ? bco['extension_domain'] : nil
      return [] unless list.is_a?(Array)

      list.filter_map do |e|
        res = e.is_a?(Hash) && e['genomicschain_extension'].is_a?(Hash) ? e['genomicschain_extension']['resources'] : nil
        res.is_a?(Hash) ? res : nil
      end
    rescue JSON::ParserError
      []
    end

    # The machine as far as it can be read, or nil when nothing in it is
    # readable. `source` alone is not a statement about a machine. A machine
    # that names no source of its own is read as `plan`: `probe` is the
    # stronger claim and is not made for the writer.
    #
    # `gpus` is read only when every element is an object: `[1, "x"]` is not a
    # list of GPUs, and reading it as `[]` would sign "looked, none"
    # (implementation review r1).
    def read_machine(raw, notes = [])
      return nil unless raw.is_a?(Hash)

      m = {}
      m['cpu_model'] = text_value(raw['cpu_model']) if text_value(raw['cpu_model'])
      MACHINE_NUMBERS.each { |k| m[k] = number_value(raw[k]) unless number_value(raw[k]).nil? }
      if raw['gpus'].is_a?(Array) && raw['gpus'].all? { |g| g.is_a?(Hash) }
        m['gpus'] = raw['gpus'].map { |g| gpu_entry(g) }
      elsif raw.key?('gpus')
        notes << 'machine.gpus is not a list of objects; it is not read'
      end
      m['gpu_probe'] = raw['gpu_probe'].select { |p| p.is_a?(Hash) }.map { |p| probe_entry(p) } if raw['gpu_probe'].is_a?(Array)
      return nil if m.empty?

      m['source'] = MACHINE_SOURCES.include?(raw['source']) ? raw['source'] : 'plan'
      m
    end

    def gpu_entry(raw)
      g = {}
      %w[vendor model driver_version].each { |k| g[k] = text_value(raw[k]) if text_value(raw[k]) }
      g['memory_bytes'] = number_value(raw['memory_bytes']) unless number_value(raw['memory_bytes']).nil?
      g
    end

    def probe_entry(raw)
      %w[tool version result].to_h { |k| [k, text_value(raw[k])] }.compact
    end

    # Two blocks that state different machines are the bundle saying two
    # things, and neither is read — the rule `platform` and `producer` follow.
    def merge_machines(machines, notes)
      distinct = machines.uniq
      return distinct.first if distinct.length <= 1

      notes << 'the extension blocks state different machines; neither is read'
      nil
    end

    # @return [Hash] position => {'requested' => {}, 'observed' => {}, 'from' => {}}
    #   for one block, every entry for the same stage already reduced; 'from'
    #   names, per field, the sources that gave it
    #
    # `cpu_model` is never a stated value of its own (implementation review
    # r1): it decides no grade, so an entry carrying only a CPU name is not
    # read, and two jobs on different CPUs drop the name without touching the
    # rest of the stage — more information in one block never lowers the
    # grade (§6.2 (2)). At most two distinct names are kept per stage, which
    # is all the rule needs and keeps the work linear in the bundle.
    def read_steps(raw, by_number, notes)
      return {} if raw.nil?

      unless raw.is_a?(Array)
        notes << 'resources.steps is not an array; no stage value is read from that block'
        return {}
      end

      out = {}
      raw.each do |e|
        next unless e.is_a?(Hash)

        pos = by_number[integer_value(e['step_number'])]
        if pos.nil?
          notes << 'a resources entry names no step of the bundle; it is not read'
          next
        end
        unless SOURCES.include?(e['source'])
          notes << "a resources entry for stage #{pos} names no known source; it is not read"
          next
        end
        req = numbers_of(e['requested'], REQUESTED_KEYS)
        obs = numbers_of(e['observed'], OBSERVED_MAX + OBSERVED_SUM)
        next if req.empty? && obs.empty?

        s = (out[pos] ||= { 'requested' => {}, 'observed' => {}, 'from' => {}, 'cpu' => [] })
        req.each { |k, v| reduce!(s, 'requested', k, v, e['source']) }
        obs.each { |k, v| reduce!(s, 'observed', k, v, e['source']) }
        cpu = e['observed'].is_a?(Hash) ? text_value(e['observed']['cpu_model']) : nil
        s['cpu'] << cpu if cpu && s['cpu'].length < 2 && !s['cpu'].include?(cpu)
      end
      out.each_value do |s|
        cpu = s.delete('cpu')
        if cpu.length == 1
          s['observed']['cpu_model'] = cpu.first
        elsif cpu.length > 1
          notes << 'one stage ran on more than one CPU model; no cpu_model is read for it'
        end
      end
      out
    end

    # One value into a stage's field (§6.2 (2)): the largest for a requested
    # or sizing value, the sum for bytes read and written. The sources kept
    # for the field are the ones whose value the field now holds — the source
    # of the larger value, both on a tie, every one for a sum (implementation
    # review r2: a plan's smaller request was listed beside the measured
    # value that replaced it). A sum is compared as a number like any other.
    def reduce!(stage, part, key, value, source)
      field = "#{part}.#{key}"
      old = stage[part][key]
      if part == 'observed' && OBSERVED_SUM.include?(key)
        stage[part][key] = number_value((old || 0) + value)
        stage['from'][field] = (stage['from'][field] || []) | [source]
      elsif old.nil? || value > old
        stage[part][key] = value
        stage['from'][field] = [source]
      elsif value == old
        stage['from'][field] |= [source]
      end
    end

    # Across blocks, field by field: a field the blocks agree on is read, a
    # field they disagree on is not, and the rest of the stage stands. A
    # source is listed for a stage only when a value it gave survived. One
    # pass over the blocks, grouped by stage.
    def merge_steps(per_block, notes)
      by_pos = Hash.new { |h, k| h[k] = [] }
      per_block.each { |b| b.each { |pos, s| by_pos[pos] << s } }
      by_pos.keys.sort.to_h do |pos|
        present = by_pos[pos]
        merged = { 'requested' => {}, 'observed' => {}, 'sources' => [] }
        %w[requested observed].each do |part|
          present.flat_map { |s| s[part].keys }.uniq.each do |k|
            having = present.select { |s| s[part].key?(k) }
            values = having.map { |s| s[part][k] }.uniq
            if values.length == 1
              merged[part][k] = values.first
              merged['sources'] |= having.flat_map { |s| s['from']["#{part}.#{k}"] || [] }
            else
              notes << "the extension blocks disagree on #{part} #{k} for stage #{pos}; it is not read"
            end
          end
        end
        merged['sources'].sort!
        [pos, merged]
      end
    end

    # --- grading ---------------------------------------------------------------

    def requested?(step) = step && step['requested'].key?('cpus') && step['requested'].key?('memory_bytes')
    def observed?(step) = step && step['observed'].key?('peak_memory_bytes') && step['observed'].key?('realtime_seconds')

    # A stage states something when it has a number; a CPU name alone is not
    # a statement (see read_steps).
    def stage_stated?(step) = !step['requested'].empty? || !(step['observed'].keys - ['cpu_model']).empty?

    def machine_complete?(machine)
      !machine.nil? && %w[cpu_model logical_cores memory_total_bytes gpus].all? { |k| machine.key?(k) }
    end

    # §6.2 (2). Each level contains the one below it, so within one block more
    # information never lowers the grade. With no stage, "every stage" holds
    # vacuously and would grade without looking at anything, so a bundle
    # with no stage reaches `partial` at most.
    def grade(machine, steps, stages_total)
      stated = !(machine || {}).slice('cpu_model', 'gpus', *MACHINE_NUMBERS).empty? ||
               steps.values.any? { |s| stage_stated?(s) }
      return 'absent' unless stated
      return 'partial' if stages_total.zero?

      all = (1..stages_total).map { |pos| steps[pos] }
      return 'full' if all.all? { |s| requested?(s) && observed?(s) } && machine_complete?(machine)
      return 'steps' if all.all? { |s| requested?(s) || observed?(s) }

      'partial'
    end

    def signed(machine, steps, stages_total)
      read = steps.select { |_, s| stage_stated?(s) }
      gpus = machine && machine['gpus']
      {
        'resources_rule_version' => RULE_VERSION,
        'grade_resources' => grade(machine, steps, stages_total),
        'stages_with_requested_resources' => (1..stages_total).count { |pos| requested?(steps[pos]) },
        'stages_with_observed_resources' => (1..stages_total).count { |pos| observed?(steps[pos]) },
        'gpus_total' => gpus&.length,
        'gpu_models' => gpus && gpu_models(gpus),
        'gpu_vendors_probed' => vendors_probed(machine),
        'machine_source' => machine && machine['source'],
        'resources_sources' => read.empty? ? nil : read.values.flat_map { |s| s['sources'] }.uniq.sort
      }
    end

    # Grouped by (vendor, model), one entry per GPU. What does not pass the
    # filter is left out of the list and stays in the total.
    def gpu_models(gpus)
      groups = gpus.filter_map do |g|
        vendor = g['vendor']&.strip&.downcase
        [vendor, g['model'].strip] if GPU_VENDORS.include?(vendor) && publishable_model?(g['model'])
      end.tally
      groups.select { |_, n| n <= MAX_GPU_COUNT }
            .map { |(vendor, model), n| { 'vendor' => vendor, 'model' => model, 'count' => n } }
            .sort_by { |h| [h['vendor'], h['model']] }
            .first(MAX_GPU_MODELS)
    end

    def publishable_model?(model)
      return false unless model.is_a?(String)

      m = model.strip
      return false if m.empty? || m.length > MAX_MODEL_CHARS || m !~ MODEL_CHARS
      return false if [HEX_RUN, LONG_DIGITS, IPV4_SHAPE, MAC_SHAPE, HOST_SHAPE, PATH_SHAPE].any? { |re| m =~ re }

      m.split(/[^A-Za-z0-9]+/).none? do |w|
        w.length >= SERIAL_WORD && w.count('0-9') >= 3 && w.count('A-Za-z') >= 3
      end
    end

    # Only beside a GPU list: "probed for nvidia" next to "GPUs not looked
    # for" would say two things (implementation review r1).
    def vendors_probed(machine)
      return nil unless machine&.key?('gpus')

      ran = Array(machine['gpu_probe']).select { |p| p['result'] == 'ok' }
      vendors = ran.flat_map { |p| PROBE_VENDORS.fetch(p['tool'], []) }.uniq.sort
      vendors.empty? ? nil : vendors
    end

    # --- values ----------------------------------------------------------------

    # §6.2 (2): a value that is not a number, or is negative, is not there.
    # true/false are not numbers here (Ruby's Numeric excludes them).
    def number?(v)
      v.is_a?(Numeric) && v.finite? && v >= 0
    end

    # A number as the rule compares it: a whole Float is the Integer it equals,
    # so 4 and 4.0 from two blocks agree (implementation review r1).
    def number_value(v)
      return nil unless number?(v)

      v.is_a?(Float) && v == v.truncate && v < 2**53 ? v.to_i : v
    end

    def numbers_of(raw, keys)
      return {} unless raw.is_a?(Hash)

      keys.each_with_object({}) { |k, acc| acc[k] = number_value(raw[k]) unless number_value(raw[k]).nil? }
    end

    def text_value(v)
      v.is_a?(String) && !v.strip.empty? ? v.strip : nil
    end

    # The adapter's integer rule for a step_number: an Integer, or a string of digits.
    def integer_value(v)
      return v if v.is_a?(Integer)

      v.is_a?(String) && v =~ /\A-?\d+\z/ ? v.to_i : nil
    end
  end
end
