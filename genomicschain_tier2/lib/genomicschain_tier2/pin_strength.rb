# frozen_string_literal: true

module GenomicsChainTier2
  # The rubric. Every resource a repository declares is reduced to one of six
  # strengths, and the reduction is DETERMINISTIC on purpose: the subject of a
  # scan can re-run it and get the same answer. That is what separates a
  # contestable finding from a disputable one, and contestability is the thing
  # this project claims to be building.
  #
  # The levels are ordered by what a third party holding only the repository
  # can actually do with the locator:
  #
  #   immutable   the bytes are named by their own hash. A re-fetch cannot differ.
  #   versioned   a name that should not move, but nothing enforces that it will
  #               not (a container tag, an exact conda version, a DOI).
  #   ranged      a constraint admitting more than one answer, today and later.
  #   floating    a bare name, a branch, `:latest`. Resolves to whatever is
  #               current at the moment of fetch.
  #   local_path  a filesystem path, with nothing saying how to obtain it.
  #   absent      referenced but never declared.
  #
  # Note what is NOT here: any judgement about whether the paper's claims match
  # these findings. That comparison needs the Tier-1 report as its other half
  # and is a separate layer. This file only reads what the code ships.
  module PinStrength
    LEVELS = %w[immutable versioned ranged floating local_path absent].freeze

    DOI       = %r{\b(?:doi\.org/|doi:)?(10\.\d{4,9}/[^\s"'<>)\]]+)}i
    URL       = %r{\A(?:https?|ftp|s3|gs)://}i
    URL_ANY   = %r{(?:https?|ftp|s3|gs)://[^\s"'<>)\]]+}i
    HASHED    = /\b(?:sha256|sha512|md5)[:=][0-9a-f]{32,}/i
    DATA_EXT  = /\.(?:tsv|csv|tab|fa|fasta|fq|fastq|gz|bz2|bam|sam|vcf|gtf|gff3?|bed|map|dmp|h5|zip|tar|parquet|rds)\z/i

    module_function

    # A container reference: `docker://x`, a Snakemake `container:` value, a
    # Dockerfile `FROM`. Returns [level, reason].
    def container(ref)
      r = ref.to_s.strip.gsub(/\A["']|["']\z/, '').sub(%r{\A(?:docker|oci|shub)://}, '')
      return ['absent', 'empty container reference'] if r.empty?
      return ['immutable', 'digest-pinned: the reference names its own bytes'] if r =~ /@sha256:[0-9a-f]{64}/

      tag = tag_of(r)
      return ['floating', 'no tag at all — resolves to :latest at pull time'] if tag.nil?
      return ['floating', 'tag :latest moves whenever the publisher pushes'] if tag == 'latest'

      ['versioned', "tag :#{tag} — stable by convention only; a tag can be repointed at new bytes"]
    end

    # One entry of a conda `dependencies:` list. Returns [level, reason].
    def conda_spec(spec)
      s = spec.to_s.strip
      return ['absent', 'empty dependency entry'] if s.empty?

      # `pip:` sub-lists arrive here as "pip:<requirement>" (see Parsers#flatten_deps).
      # The colon is load-bearing: `pip` is also an ordinary conda package, and
      # almost every exported environment lists it. Matching the bare prefix
      # classified `pip=24.2=pyh8b19718_1` — name=version=build, the strongest pin
      # conda offers — as an unpinned pip requirement, and did the same to any
      # package whose name merely starts with "pip" (pipx, pipenv).
      return ['floating', 'pip requirement without a hash'] if s.start_with?('pip:')
      return ['ranged', 'version constraint — admits more than one release, now and later'] if s =~ /[<>~!]|,/

      parts = s.split(/={1,2}/)
      case parts.length
      when 3 then ['versioned', 'name=version=build — the build string is the closest conda comes to a pin']
      when 2 then ['versioned', 'exact version, but the build behind that version can be rebuilt']
      else ['floating', 'bare package name — resolves to whatever is current at solve time']
      end
    end

    # A value from a configuration file that looks like it points at data.
    # Returns [level, reason].
    def data_locator(value)
      v = value.to_s.strip
      return ['absent', 'empty value'] if v.empty?
      return ['immutable', 'carries a content hash'] if v =~ HASHED
      return ['versioned', 'DOI — persistent, but nothing here verifies the bytes behind it'] if v =~ DOI
      return ['floating', 'URL — retrievable, but its content can change without notice'] if v =~ URL

      ['local_path', 'a filesystem path; nothing in the repository says how to obtain it']
    end

    # Structural test only: is this string shaped like something that points
    # somewhere? Deliberately NOT a test on the key name — `krakenuniq_db` and
    # `bowtie2_db` would pass a key heuristic, but so would a key called
    # `preload_db_size` holding "32G". Shape is checkable; naming is a guess.
    #
    # The exclusions below were not designed. Each one is a false positive the
    # first run against a real repository produced, and each is written as the
    # narrowest rule that removes it:
    #
    #   `#/definitions/x`   a JSON Schema pointer into its own document. Has a
    #                       slash, points at nothing outside the file.
    #   `*fastqc*`          a MultiQC path filter. A glob is a pattern, not a
    #                       locator; it names zero or many things, never one.
    #   `key` = `$ref`      the same pointers reached by their key, for schemas
    #                       that write the target without a leading `#`.
    def locator_shaped?(str, key = nil)
      return false unless str.is_a?(String)

      t = str.strip
      return false if t.empty?
      return false if t.start_with?('#/') # JSON Schema pointer, not a location
      return false if key.to_s.split('.').last.to_s.start_with?('$') # $ref / $schema
      return false if t.include?('*') || t.include?('?') # a glob matches, it does not point
      return true if t =~ URL || t =~ DOI
      return false if t =~ /\s/ # a sentence, not a locator

      t.include?('/') || t =~ DATA_EXT
    end

    # Is this locator a DOI? Used to separate persistent deposit identifiers
    # from ordinary documentation links, which behave nothing alike: a DOI in a
    # README beside an unobtainable dataset is a claim about where the data is;
    # a link to readthedocs is not.
    def doi?(locator)
      locator.to_s =~ /\A10\.\d{4,9}\// ? true : false
    end

    # Every DOI and URL appearing anywhere in a blob of text, normalised so the
    # same identifier written two ways compares equal.
    def locators_in(text)
      (text.to_s.scan(URL_ANY) + text.to_s.scan(DOI).flatten).map { |l| normalise(l) }.uniq
    end

    def normalise(locator)
      locator.to_s.strip.downcase
             .sub(%r{\Ahttps?://(?:dx\.)?doi\.org/}, '')
             .sub(/\Adoi:/, '')
             .sub(%r{[.,;)\]]+\z}, '')
    end

    # The last path segment carries the tag; a `registry:5000/image` colon does not.
    def tag_of(ref)
      last = ref.split('/').last.to_s
      return nil unless last.include?(':')

      last.split(':', 2).last
    end
  end
end
