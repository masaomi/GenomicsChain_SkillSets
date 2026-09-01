# frozen_string_literal: true

require 'date'

module GenomicsChainRegwatch
  # Parses the watchlist, which is a markdown file so that it can be read and
  # edited by a person without a tool. One `## <id>` section per watched item,
  # then `- key: value` lines.
  #
  # The format is flat on purpose. A watchlist that needs a schema to edit
  # stops being edited.
  class Watchlist
    Item = Struct.new(
      :id, :kind, :due, :title, :url, :watch, :binds, :why, :source_line,
      keyword_init: true
    ) do
      def dated?
        kind == 'dated'
      end

      # Days from `today` until the due date. nil for undated items.
      def days_remaining(today = Date.today)
        return nil unless dated? && due
        (due - today).to_i
      end

      def to_h
        {
          'id' => id, 'kind' => kind, 'due' => due&.to_s, 'title' => title,
          'url' => url, 'watch' => watch, 'binds' => binds, 'why' => why
        }.compact
      end
    end

    KNOWN_KINDS = %w[dated undated].freeze
    KNOWN_KEYS = %w[kind due title url watch binds why].freeze

    attr_reader :items, :warnings

    def self.load(path)
      raise Error, "watchlist not found: #{path}" unless File.file?(path)
      new(File.read(path), path)
    end

    def initialize(text, path = '(string)')
      @path = path
      @items = []
      @warnings = []
      parse(text)
    end

    # Items whose deadline falls inside `within` days, soonest first. Items
    # already past are included with a negative count — a missed deadline is
    # more worth surfacing than an approaching one, not less.
    def due_within(days, today = Date.today)
      items.select { |i| i.dated? && i.due }
           .select { |i| i.days_remaining(today) <= days }
           .sort_by { |i| i.days_remaining(today) }
    end

    def undated
      items.reject(&:dated?)
    end

    private

    def parse(text)
      current = nil
      text.each_line.with_index(1) do |line, lineno|
        case line
        when /\A##\s+([A-Za-z0-9][\w.-]*)\s*\z/
          flush(current)
          current = { id: Regexp.last_match(1), source_line: lineno, fields: {} }
        when /\A\s*-\s+([a-z_]+)\s*:\s*(.+?)\s*\z/
          key = Regexp.last_match(1)
          value = Regexp.last_match(2)
          if current.nil?
            @warnings << "line #{lineno}: `#{key}` before any `## <id>` heading — ignored"
          elsif !KNOWN_KEYS.include?(key)
            @warnings << "line #{lineno}: unknown key `#{key}` in #{current[:id]} — ignored"
          else
            current[:fields][key] = value
          end
        end
      end
      flush(current)
    end

    def flush(current)
      return if current.nil?

      f = current[:fields]
      kind = f['kind'] || 'undated'
      unless KNOWN_KINDS.include?(kind)
        @warnings << "#{current[:id]}: unknown kind `#{kind}` — treated as undated"
        kind = 'undated'
      end

      due = nil
      if f['due']
        begin
          due = Date.iso8601(f['due'])
        rescue ArgumentError
          @warnings << "#{current[:id]}: due `#{f['due']}` is not an ISO date — ignored"
        end
      end

      if kind == 'dated' && due.nil?
        @warnings << "#{current[:id]}: kind is dated but no valid `due` — it will never count down"
      end

      @items << Item.new(
        id: current[:id], kind: kind, due: due,
        title: f['title'] || current[:id], url: f['url'],
        watch: f['watch'] || 'text', binds: f['binds'], why: f['why'],
        source_line: current[:source_line]
      )
    end
  end
end
