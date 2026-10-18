# frozen_string_literal: true

require 'json'
require_relative '../writer'

module GenomicsChainProv
  module Writer
    # ResourcesInput — the generic resources file, `gc-resources-input-0.1`
    # (design v0.1.14 §6.2 (4)). A pipeline that is not Nextflow, or a
    # measuring wrapper around one, writes this and `gc_prov_write --resources`
    # carries it into the bundle:
    #
    #   { "format": "gc-resources-input-0.1",
    #     "measured_by": "what measured these values (a tool and its version)",
    #     "steps": [ { "step_number": 1,
    #                  "requested": { "cpus": 4, "memory_bytes": 8589934592, ... },
    #                  "observed":  { "peak_memory_bytes": 5100000000, "realtime_seconds": 412.5, ... } } ] }
    #
    # Every field but `format` and `step_number` is optional. Values are plain
    # numbers in bytes and seconds; a unit string is not read, because a
    # rounded "11.2 MB" turned back into bytes is a number nobody measured.
    #
    # The file is the measuring tool's statement and the bundle says so: each
    # entry keeps `source: gc_resources_input` and the file's `measured_by`.
    # Pure: text in, entries out.
    module ResourcesInput
      FORMAT = 'gc-resources-input-0.1'
      REQUESTED = Writer::REQUESTED_KEYS
      OBSERVED = %w[peak_memory_bytes realtime_seconds cpu_percent read_bytes write_bytes].freeze

      module_function

      # @param text [String] the file's content
      # @param name [String] how the notes name the file
      # @return [Hash] 'steps' => [entry], 'notes' => [String]
      # @raise [Writer::PlanError] when the file is not this format
      def read(text, name: 'the resources file')
        doc = JSON.parse(text)
        raise PlanError, "#{name} is not a #{FORMAT} object" unless doc.is_a?(Hash) && doc['format'] == FORMAT
        raise PlanError, "#{name} has no steps array" unless doc['steps'].is_a?(Array)

        notes = []
        measured_by = doc['measured_by'].is_a?(String) && !doc['measured_by'].strip.empty? ? doc['measured_by'].strip : nil
        notes << "#{name} does not say what measured its values (measured_by)" if measured_by.nil?
        steps = doc['steps'].each_with_index.filter_map do |e, i|
          entry(e, i, measured_by, name, notes)
        end
        { 'steps' => steps, 'notes' => notes }
      rescue JSON::ParserError
        raise PlanError, "#{name} is not valid JSON"
      end

      def entry(raw, index, measured_by, name, notes)
        where = "#{name} step entry #{index + 1}"
        unless raw.is_a?(Hash) && raw['step_number'].is_a?(Integer)
          notes << "#{where} names no integer step_number; left out"
          return nil
        end

        requested = numbers(raw['requested'], REQUESTED, "#{where} requested", notes)
        observed = numbers(raw['observed'], OBSERVED, "#{where} observed", notes)
        cpu = raw['observed'].is_a?(Hash) ? raw['observed']['cpu_model'] : nil
        observed['cpu_model'] = cpu.strip if cpu.is_a?(String) && !cpu.strip.empty?
        return nil if requested.empty? && observed.empty?

        Writer.compact_h('step_number' => raw['step_number'], 'source' => 'gc_resources_input',
                         'measured_by' => measured_by,
                         'requested' => requested.empty? ? nil : requested,
                         'observed' => observed.empty? ? nil : observed)
      end

      # Known keys with a non-negative number are kept; anything else is left
      # out and named, so what the file meant and what was read can be compared.
      def numbers(raw, keys, where, notes)
        return {} if raw.nil?
        unless raw.is_a?(Hash)
          notes << "#{where} is not an object; left out"
          return {}
        end

        unknown = raw.keys - keys - ['cpu_model']
        notes << "#{where}: #{unknown.join(', ')} not read (not a field of #{FORMAT})" unless unknown.empty?
        keys.each_with_object({}) do |k, acc|
          next unless raw.key?(k)

          v = raw[k]
          if v.is_a?(Numeric) && v.finite? && v >= 0
            acc[k] = v
          else
            notes << "#{where}.#{k} is not a non-negative number; left out"
          end
        end
      end
    end
  end
end
