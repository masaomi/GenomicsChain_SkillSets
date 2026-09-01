# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'genomicschain_regwatch'

module KairosMcp
  module SkillSets
    module GenomicschainRegwatch
      module Tools
        # gc_regwatch_report — turn a scan into something a person reads.
        #
        # Two languages, because the audience is two audiences: the operator
        # reads Japanese, and anything that goes to a Swiss collaborator, a
        # clinical trial unit or a funder reads English. Rendering both from
        # one scan keeps them from drifting apart, which is what happens when
        # a translation is made once and then the source moves.
        #
        # Standalone HTML: no external CSS, no fonts, no data fetches. A report
        # that needs a network to render is a report that stops rendering.
        class GcRegwatchReport < KairosMcp::Tools::BaseTool
          def name
            'gc_regwatch_report'
          end

          def description
            'Render a gc_regwatch_scan result as standalone HTML in English, Japanese, or both. Colour ' \
              'never carries status alone — every status pairs a glyph and a word with its colour. Writes ' \
              'the files and returns their paths; pass scan_json inline or point at a saved scan.'
          end

          def category
            :analysis
          end

          def usecase_tags
            %w[regulatory watch report html bilingual visualisation genomicschain kairoschain]
          end

          def related_tools
            %w[gc_regwatch_scan context_save]
          end

          def harness_requirement
            { tier: :self_contained, requires_externals: [],
              reason: 'renders a JSON scan result to HTML on disk; no network, no subprocess' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                scan_json: {
                  type: 'string',
                  description: 'The scan result as a JSON string, exactly as gc_regwatch_scan returned it.'
                },
                scan_path: {
                  type: 'string',
                  description: 'Path to a saved scan result JSON. Used when scan_json is not given.'
                },
                out_dir: {
                  type: 'string',
                  description: 'Directory to write the report(s) into. Created if absent. Defaults to ' \
                               'log/research/regwatch under the current working directory.'
                },
                lang: {
                  type: 'string', enum: %w[en ja both],
                  description: 'Which language(s) to render (default both).'
                },
                basename: {
                  type: 'string',
                  description: 'Filename stem. Defaults to regwatch_<scan date>. The language tag and ' \
                               '.html are appended.'
                }
              },
              required: []
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)

            raw = args['scan_json']
            if (raw.nil? || raw.strip.empty?) && args['scan_path']
              path = args['scan_path']
              return text_content("Error: scan_path not found: #{path}") unless File.file?(path)
              raw = File.read(path)
            end
            return text_content('Error: give scan_json or scan_path') if raw.nil? || raw.strip.empty?

            begin
              scan = JSON.parse(raw)
            rescue JSON::ParserError => e
              return text_content("Error: scan JSON did not parse — #{e.message}")
            end
            unless scan.is_a?(Hash) && scan['findings']
              return text_content('Error: that JSON is not a gc_regwatch_scan result (no `findings` key)')
            end

            out_dir = args['out_dir'] || File.join(Dir.pwd, 'log', 'research', 'regwatch')
            FileUtils.mkdir_p(out_dir)

            stem = args['basename'] || "regwatch_#{(scan['scanned_at'] || Time.now.utc.iso8601)[0, 10]}"
            langs = case args['lang']
                    when 'en' then %w[en]
                    when 'ja' then %w[ja]
                    else %w[en ja]
                    end

            written = langs.map do |lang|
              html = ::GenomicsChainRegwatch::Renderer.new(scan, lang: lang).render
              file = File.join(out_dir, "#{stem}.#{lang}.html")
              File.write(file, html)
              { 'lang' => lang, 'path' => file, 'bytes' => html.bytesize }
            end

            text_content(JSON.pretty_generate(
                           'wrote' => written,
                           'scanned_at' => scan['scanned_at'],
                           'counts' => scan['counts'],
                           'deadlines' => (scan['deadlines'] || []).length
                         ))
          rescue StandardError => e
            text_content("Error: gc_regwatch_report failed — #{e.class}: #{e.message}")
          end
        end
      end
    end
  end
end
