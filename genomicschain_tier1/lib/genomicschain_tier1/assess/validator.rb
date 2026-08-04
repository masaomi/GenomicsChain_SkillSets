# frozen_string_literal: true

require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      module Assess
        # Phase 4 of gc_tier1_assess (spec v0.2 §2, §8, §11).
        #
        # This phase is not ceremony. The same assessor procedure, run by hand 201
        # times to build the survey corpus, produced output that fails this schema
        # 59 times (29%) — chiefly version_subtier values outside its enum. Nothing
        # was validating it, and the Rails dashboard never had to parse the field,
        # so the failures stayed invisible until this tool was specified.
        module Validator
          MAX_BYTES = 2 * 1024 * 1024 # VerdictSpec::Tier1::REPORT_JSON_MAX_BYTES

          class ValidationError < StandardError; end

          Outcome = Struct.new(:backend, :errors, keyword_init: true) do
            def ok? = errors.empty?
          end

          module_function

          def schema
            @schema ||= JSON.parse(File.read(GenomicschainTier1::SCHEMA_V0_2_6))
          end

          # Ordered by fidelity to the artifact's own declaration.
          #
          #   json_schemer  — reads the draft 2020-12 the schema declares.
          #   json-schema   — CANNOT read 2020-12 (raises "Schema not found"). It can be
          #                   coerced by dropping $schema and forcing draft6, which
          #                   validates against a different draft than the artifact
          #                   declares. Usable, but the outcome says so.
          #   structural    — last resort: required keys and enums only.
          def validate(report)
            return schemer(report) if available?('json_schemer')
            return coerced_json_schema(report) if available?('json-schema')

            structural(report)
          end

          def validate!(report_json, report)
            bytes = report_json.bytesize
            if bytes > MAX_BYTES
              raise ValidationError,
                    "report_json is #{bytes} bytes, over the #{MAX_BYTES}-byte ceiling gc_tier1_submit accepts"
            end

            GenomicschainCore::B1ManifestHash.assert_matches!(report)

            outcome = validate(report)
            raise ValidationError, "schema: #{outcome.errors.first(5).join('; ')}" unless outcome.ok?

            outcome
          end

          def available?(gem_name)
            @available ||= {}
            @available.fetch(gem_name) do
              @available[gem_name] = begin
                require gem_name
                true
              rescue LoadError
                false
              end
            end
          end

          def schemer(report)
            errors = JSONSchemer.schema(schema).validate(report).map do |e|
              "#{e['data_pointer'].empty? ? '#' : e['data_pointer']}: #{e['type']}"
            end
            Outcome.new(backend: 'json_schemer', errors: errors)
          end

          def coerced_json_schema(report)
            draft6 = schema.reject { |k, _| k == '$schema' }
            errors = JSON::Validator.fully_validate(draft6, report, version: :draft6)
            Outcome.new(backend: 'json-schema (draft6-coerced; schema declares 2020-12)', errors: errors)
          end

          # Deliberately thin. It exists so the tool still fails closed on the shapes
          # the corpus actually got wrong, not so it can stand in for a real validator.
          def structural(report)
            errors = []
            %w[rubric_version metric_semantics_version rubric_hash canonical_id paper_type
               assessor_id assessed_at funnel_stage steps counts headline levers gaps
               liveness human_signoff manifest assessor_stack].each do |key|
              errors << "#: missing required key #{key}" if report[key].nil?
            end
            errors << '#/gaps: not an array' unless report['gaps'].is_a?(Array)
            errors << '#/liveness: not an array' unless report['liveness'].is_a?(Array)

            Array(report['steps']).each_with_index do |step, i|
              axes = step['axes'] || {}
              Derivation::AXES.each do |axis|
                errors << "#/steps/#{i}/axes/#{axis}: not an integer 0..2" unless (0..2).cover?(axes[axis])
              end
              unless %w[R RI NI X OOS].include?(step['verdict'])
                errors << "#/steps/#{i}/verdict: #{step['verdict'].inspect} outside enum"
              end
              subtier = step['version_subtier']
              if subtier && !Derivation::VERSION_SUBTIERS.include?(subtier)
                errors << "#/steps/#{i}/version_subtier: #{subtier.inspect} outside enum"
              end
            end

            Outcome.new(backend: 'structural (no schema gem installed)', errors: errors)
          end
        end
      end
    end
  end
end
