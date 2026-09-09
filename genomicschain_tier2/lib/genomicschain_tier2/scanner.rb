# frozen_string_literal: true

require 'digest'
require_relative 'parsers'

module GenomicsChainTier2
  # Walks a checked-out workflow repository and reports what it declares.
  #
  # Reads. Never evaluates. That boundary is what keeps this layer cheap enough
  # to run on a laptop, and it is also a trust boundary: `snakemake --dry-run`
  # and `nextflow -stub-run` give better answers than parsing, and both of them
  # execute arbitrary code out of the repository being examined. The moment a
  # scan evaluates the thing it is scanning it has joined the execution tier in
  # both cost and trust, so the line is drawn here explicitly rather than
  # discovered later.
  class Scanner
    MAX_FILE_BYTES = 2 * 1024 * 1024
    SKIP_DIRS = %w[.git .github node_modules .snakemake images .venv __pycache__].freeze
    TEXT_EXT = /\.(ya?ml|smk|lock|md|rst|txt|cfg|toml|json)\z/i

    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
    end

    def scan
      raise ArgumentError, "not a directory: #{@root}" unless File.directory?(@root)

      declarations = []
      prose = []
      rules = []
      parsed = []
      skipped = []
      unparsed = []

      each_file do |abs, rel|
        unless scannable?(abs, rel)
          skipped << rel
          next
        end

        text = File.read(abs, encoding: 'UTF-8', invalid: :replace, undef: :replace)
        unparsed << rel if rel =~ /\.ya?ml\z/i && Parsers.yaml_status(text) == :unparseable
        found = dispatch(rel, text).each { |d| d[:scope] = scope_of(rel) }
        declarations.concat(found)
        prose.concat(Parsers.prose_locators(rel, text))
        rules.concat(Parsers.snakemake_rules(rel, text)) if snakemake?(rel) && scope_of(rel) == 'shipped'
        parsed << [rel, Digest::SHA256.hexdigest(text)]
      end

      build_report(declarations, prose.uniq { |p| p[:locator] }, rules, parsed, skipped, unparsed)
    end

    private

    def each_file(&block)
      Dir.glob(File.join(@root, '**', '*'), File::FNM_DOTMATCH).sort.each do |abs|
        next unless File.file?(abs)

        rel = abs.delete_prefix("#{@root}/")
        next if rel.split('/').any? { |seg| SKIP_DIRS.include?(seg) }

        block.call(abs, rel)
      end
    end

    def scannable?(abs, rel)
      base = File.basename(rel)
      return false if File.size(abs) > MAX_FILE_BYTES

      base == 'Snakefile' || base.start_with?('Dockerfile') || rel =~ TEXT_EXT ? true : false
    end

    # A repository's own test fixtures usually contain a copy of the shipped
    # config, so counting both doubles every data finding and mixes a fixture
    # with the thing that actually runs. They are scanned and reported, but
    # separately: a fixture that fails to pin its data is not a defect.
    FIXTURE_SEG = %w[test tests .test .tests testing fixtures vignettes].freeze

    def scope_of(rel)
      rel.split('/').any? { |seg| FIXTURE_SEG.include?(seg.downcase) } ? 'fixture' : 'shipped'
    end

    def snakemake?(rel)
      File.basename(rel) == 'Snakefile' || rel =~ /\.smk\z/i ? true : false
    end

    def dispatch(rel, text)
      base = File.basename(rel)

      return Parsers.conda_lock(rel, text)          if rel =~ /\.lock\z/i || base.include?('conda-lock')
      return Parsers.snakemake(rel, text)           if snakemake?(rel)
      return Parsers.dockerfile(rel, text)          if base.start_with?('Dockerfile')
      return [] unless rel =~ /\.ya?ml\z/i

      env = Parsers.conda_env(rel, text)
      env.empty? ? Parsers.config_yaml(rel, text, @root) : env
    end

    def build_report(declarations, prose, rules, parsed, skipped, unparsed)
      {
        'target' => {
          'root' => @root,
          'files_parsed' => parsed.length,
          'files_skipped' => skipped.length,
          # YAML files read but not parseable. Listed, because a file that
          # cannot be read declares nothing and that changes the verdict.
          'files_unparsed' => unparsed,
          # sha256 over (path, content-hash) pairs of everything actually read.
          # This is the evidence digest: it lets a third party establish that a
          # re-scan saw the same bytes, which a verdict without it cannot.
          'evidence_digest' => Digest::SHA256.hexdigest(parsed.sort.map { |p, h| "#{p}\t#{h}" }.join("\n")),
          # The scan is deterministic given the bytes AND the interpreter: the
          # same repository scanned under Ruby 3.2.3 and 3.4.10 gave 11 and 2204
          # declarations (2026-09-09, 28 papers), with identical evidence
          # digests. So the toolchain is part of the record's identity and goes
          # into whatever is signed. Author's decision 2026-09-09: results are
          # taken from 3.4.10, and the version travels with them.
          'toolchain' => toolchain
        },
        'counts_by_pin' => tally(declarations.select { |d| d[:scope] == 'shipped' }) { |d| d[:pin] },
        'counts_by_kind' => tally(declarations.select { |d| d[:scope] == 'shipped' }) { |d| "#{d[:kind]}/#{d[:pin]}" },
        'counts_in_fixtures' => tally(declarations.select { |d| d[:scope] == 'fixture' }) { |d| d[:kind] },
        'findings' => findings(declarations, prose),
        'declarations' => declarations,
        'prose_locators' => prose,
        'rules' => rules
      }
    end

    def toolchain
      {
        'ruby' => RUBY_VERSION,
        'ruby_platform' => RUBY_PLATFORM,
        'psych' => Psych::VERSION,
        'codescan_rubric_version' => (defined?(GenomicsChainTier2::RUBRIC_VERSION) ? GenomicsChainTier2::RUBRIC_VERSION : nil)
      }
    end

    def tally(list)
      list.each_with_object(Hash.new(0)) { |d, h| h[yield(d)] += 1 }
                                        .sort_by { |_, v| -v }.to_h
    end

    # Findings are structural observations, each carrying the declarations it
    # was derived from. None of them says whether the paper was wrong — that
    # comparison needs the Tier-1 report and is a separate layer.
    def findings(all, prose)
      out = []
      decls = all.select { |d| d[:scope] == 'shipped' }
      containers = decls.select { |d| d[:kind] == 'container' }
      data = decls.select { |d| d[:kind] == 'data' }
      software = decls.select { |d| d[:kind] == 'software_env' }
      unobtainable = data.select { |d| d[:pin] == 'local_path' && d[:present_in_repo] == false }
      locked = software.select { |d| d[:pin] == 'immutable' }

      loose = containers.reject { |d| d[:pin] == 'immutable' }
      if loose.any?
        out << finding('container_not_digest_pinned',
                       "#{loose.length} of #{containers.length} container reference(s) are not pinned to a digest, " \
                       'so a later pull can return different bytes.', loose)
      end

      if unobtainable.any?
        out << finding('data_declared_but_not_obtainable',
                       "#{unobtainable.length} data locator(s) are filesystem paths that do not exist in the " \
                       'repository and carry no URL, DOI or hash. Nothing here says how to get them.', unobtainable)
      end

      if locked.any? && unobtainable.any?
        out << finding('software_pinned_data_not',
                       "Asymmetry: #{locked.length} software package(s) are pinned by content hash while " \
                       "#{unobtainable.length} data locator(s) are unobtainable. The environment is reproducible; " \
                       'what it runs on is not.', unobtainable.first(3))
      end

      # Restricted to DOIs. The first run reported 24 "prose-only" locators, of
      # which 19 were badge images, tool homepages and install instructions —
      # noise that buries the 5 that matter. A DOI is by construction an
      # identifier for a deposit, so a DOI in the README of a repository whose
      # data is unobtainable is a claim about where that data lives. A link to
      # readthedocs is not the same kind of thing and is no longer counted as one.
      declared = all.map { |d| PinStrength.normalise(d[:locator]) }
      prose_dois = prose.select { |p| PinStrength.doi?(p[:locator]) }
                        .reject { |p| declared.any? { |l| l.include?(p[:locator]) } }
      if prose_dois.any? && unobtainable.any?
        out << finding('data_source_named_only_in_prose',
                       "#{unobtainable.length} data locator(s) cannot be obtained from the repository, while " \
                       "#{prose_dois.length} DOI(s) appear only in documentation or comments. Nothing machine-read " \
                       'connects the two: the prose names a source the code never resolves.',
                       unobtainable.map { |d| d.slice(:name, :locator, :source, :line) } +
                       prose_dois.map { |p| p.merge(role: 'named in prose only') })
      end

      unpinned_sw = software.select { |d| %w[floating ranged].include?(d[:pin]) }
      if unpinned_sw.any?
        out << finding('software_env_unpinned',
                       "#{unpinned_sw.length} of #{software.length} software declaration(s) name no exact " \
                       'version.' + (locked.any? ? ' A lock file is present and may cover them.' : ''),
                       unpinned_sw.first(5))
      end

      out
    end

    def finding(code, statement, evidence)
      { 'code' => code, 'statement' => statement, 'evidence_count' => evidence.length,
        'evidence' => evidence }
    end
  end
end
