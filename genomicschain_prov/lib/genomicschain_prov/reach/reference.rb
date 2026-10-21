# frozen_string_literal: true

require_relative 'failure'
require_relative 'gate'

module GenomicsChainProv
  module Reach
    # (4) What a locator says, read without touching anything. Each kind of
    # place has one shape it is asked in; a locator that fits none is
    # refused here and reads not_checkable (local paths, absent, unhandled
    # schemes, a registry on another port).
    module Reference
      Oci = Struct.new(:registry, :name, :tag, :digest, keyword_init: true)
      Git = Struct.new(:url, keyword_init: true)
      Commit = Struct.new(:url, :commit, keyword_init: true)
      Https = Struct.new(:url, keyword_init: true)
      Conda = Struct.new(:channel, :name, :version, keyword_init: true)

      # OCI distribution spec, reference grammar.
      COMPONENT = /[a-z0-9]+(?:(?:[._]|__|-+)[a-z0-9]+)*/
      NAME = %r{\A#{COMPONENT}(?:/#{COMPONENT})*\z}
      TAG = /\A\w[\w.-]{0,127}\z/
      DIGEST = /\A(?:sha256:[a-f0-9]{64}|sha512:[a-f0-9]{128})\z/
      DOCKER_HUB = %w[docker.io index.docker.io registry-1.docker.io].freeze
      HEX_OBJECT_ID = /\A(?:\h{40}|\h{64})\z/
      # A git ref name as it can appear after refs/heads/ or refs/tags/.
      REF_NAME = %r{\A[A-Za-z0-9._/+-]{1,255}\z}
      CONDA = /\A([A-Za-z0-9._+-]+)::([A-Za-z0-9._+-]+)==([A-Za-z0-9._+-]+)\z/

      module_function

      # @param category [String] one of CATEGORIES
      # @param locator [String, Hash] as Observation.items gives it
      # @return [Oci, Git, Commit, Https, Conda]
      # @raise [Refused]
      def read(category, locator)
        case category
        when 'workflow_repository' then Git.new(url: git_url(locator))
        when 'workflow_commit' then commit(locator)
        when 'containers' then oci(locator)
        when 'runtime', 'software' then runtime_or_software(locator)
        else raise Refused.new('form')
        end
      end

      # The host the query goes to first: the host that decides the class.
      def host(ref)
        case ref
        when Oci then ref.registry
        when Conda then 'api.anaconda.org'
        else Gate.parse(ref.url).first
        end
      end

      # [registry/]name[:tag][@digest]; docker:// is a Docker Hub image as
      # Singularity writes it. Another scheme (shub://, oci://, a path) names
      # a place there is no way to ask.
      def oci(text)
        raise Refused.new('form') unless text.is_a?(String)

        s = text.delete_prefix('docker://')
        raise Refused.new('scheme') if s.include?('://')
        raise Refused.new('form') if s.empty? || s.start_with?('/')

        s, digest = s.split('@', 2)
        raise Refused.new('form') if digest && !DIGEST.match?(digest)

        first, rest = s.split('/', 2)
        if rest && (first.include?('.') || first.include?(':') || first == 'localhost')
          registry = first
          path = rest
        else
          registry = 'registry-1.docker.io'
          path = s
        end
        # The registry, and its port, are split off above, so a colon left in
        # the path can only start the tag.
        name, tag = path.split(':', 2)
        # The registry as the URL reads it (lowercase, no trailing dot, no
        # :443), so one registry is counted, classed and asked as one host
        # however it was written (review r1). Text a URL would read as a
        # query or a fragment is refused.
        raise Refused.new('form') if registry.match?(/[?#]/)

        registry = Gate.parse("https://#{registry}/").first # port, IP literal, host form
        if DOCKER_HUB.include?(registry)
          registry = 'registry-1.docker.io'
          name = "library/#{name}" unless name.include?('/')
        end
        raise Refused.new('form') unless name.length <= 255 && NAME.match?(name)
        raise Refused.new('form') if tag && !TAG.match?(tag)

        Oci.new(registry: registry, name: name, tag: digest ? nil : (tag || 'latest'), digest: digest)
      end

      # A canonical repository URL: https, no query, no fragment, no
      # trailing slash. Anything else is refused rather than rewritten.
      def git_url(text)
        raise Refused.new('form') unless text.is_a?(String) && !text.match?(/[?#]/)

        url = text.delete_suffix('/')
        _, _, path = Gate.parse(url)
        raise Refused.new('form') if path == '/' || path.include?('..')

        url
      end

      def commit(locator)
        raise Refused.new('form') unless locator.is_a?(Hash)

        c = locator['commit'].to_s
        raise Refused.new('form') unless HEX_OBJECT_ID.match?(c) || (REF_NAME.match?(c) && !c.match?(/\A\h{7,39}\z/))

        Commit.new(url: git_url(locator['repository']), commit: HEX_OBJECT_ID.match?(c) ? c.downcase : c)
      end

      # A URL or a conda spec. A bare tool name or a path is not asked: read
      # as an image it would send a tool's name to Docker Hub.
      def runtime_or_software(text)
        raise Refused.new('form') unless text.is_a?(String)
        return conda(text) if text.include?('::')
        raise Refused.new('form') unless text.match?(%r{\A[A-Za-z][A-Za-z0-9+.-]*://})

        Gate.parse(text)
        Https.new(url: text)
      end

      # channel::name==version, fully pinned and with a channel named
      # (design (4)); `=` alone is a prefix match in conda and is refused. A
      # part made of dots only would climb the API's path (review r1).
      def conda(text)
        m = CONDA.match(text) or raise Refused.new('form')
        raise Refused.new('form') if m[1] == 'defaults' || m.captures.any? { |c| c.match?(/\A\.+\z/) }

        Conda.new(channel: m[1], name: m[2], version: m[3])
      end
    end
  end
end
