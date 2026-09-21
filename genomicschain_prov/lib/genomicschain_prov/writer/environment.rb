# frozen_string_literal: true

require 'digest'
require 'open3'
require 'rbconfig'
require_relative '../predicate'

module GenomicsChainProv
  module Writer
    # Environment — the half of `gc_prov_write` that touches the machine: it
    # hashes the files a plan names, asks a tool for its version, asks Docker
    # for an image digest, and looks for the Nextflow framework jar.
    #
    # Design §4.1 splits the work this way on purpose. The customer writes the
    # stages, because only they know what ran; everything that can be MEASURED
    # on the machine that ran it — versions, digests, checksums — is collected
    # here, so the bundle's grade reflects what was there rather than what
    # somebody remembered to type.
    #
    # Two rules this module holds to:
    #
    #   Never substitute. A file that is not there, a `docker` that is not
    #   running, a jar that cannot be found — each leaves the field empty and
    #   adds a note. §5's scale is built so that an empty field grades below a
    #   filled one; filling it with a guess would invert exactly that.
    #
    #   Never run a plan's commands unless asked. A plan is a data file, and a
    #   `version_command` in it is a command line. `run_version_commands:` is
    #   off by default and the caller has to turn it on, so reading somebody
    #   else's plan cannot execute their shell. `docker image inspect` is a
    #   fixed argv, not a shell line, and stays on.
    module Environment
      module_function

      # Fills in what the plan left for the machine to supply, in place — the
      # plan at this point is this process's own normalised copy — and returns
      # the checksum map `Writer.build` keys the extension block by, together
      # with what could not be collected.
      #
      # @return [Hash] {'checksums' => {locator => {'sha1','sha256'}}, 'notes' => [String]}
      def resolve!(plan, base_dir: Dir.pwd, checksums: true, run_version_commands: false,
                   docker: true, digest_map: {})
        notes = []
        sums = {}

        resolve_tool!(plan['runtime'], base_dir, notes, run_version_commands, docker, digest_map, 'runtime')
        plan['stages'].each do |stage|
          stage['tools'].each_with_index do |tool, i|
            resolve_tool!(tool, base_dir, notes, run_version_commands, docker, digest_map,
                          "stage #{stage['step_number']} tool #{i + 1}")
          end
        end

        if checksums
          hashable(plan).each do |locator, path|
            full = absolute(path, base_dir)
            digests = digest_file(full)
            if digests.nil?
              notes << "no checksum for #{locator}: #{full} is not a readable file"
            else
              sums[locator] = digests
            end
          end
        else
          notes << 'checksums were skipped (--no-checksums): nothing in this bundle can grade above floating'
        end

        { 'checksums' => sums, 'notes' => notes }
      end

      # A locator naming somewhere other than this filesystem. Hashing it would
      # need the network, and fetching bytes to digest them would mean the
      # bundle asserts a checksum of something this machine never ran with.
      # Left alone, §5 grades a URL `floating` and a DOI `versioned`, which is
      # the truth about what those locators permit.
      REMOTE_SCHEME = %r{\A(?:https?|ftp|s3|gs|docker|oci|shub)://}i

      # Every locator this bundle can hang a checksum on, paired with where the
      # bytes are. A tool that names an image has no file here — its pin is the
      # image digest, through the container route (§5, §10-8).
      def hashable(plan)
        out = {}
        add = lambda do |item|
          next if item.nil? || item['uri'].nil? || item['path'].nil? || item['image']
          next if item['uri'] =~ REMOTE_SCHEME

          out[item['uri']] ||= item['path']
        end
        add.call(plan['script'])
        add.call(plan['runtime'])
        plan['stages'].each do |stage|
          stage['tools'].each { |t| add.call(t) }
          (stage['inputs'] + stage['outputs']).each { |f| add.call(f) }
        end
        (plan['inputs'] || []).each { |f| add.call(f) }
        (plan['outputs'] || []).each { |f| add.call(f) }
        out
      end

      # --- one item ---------------------------------------------------------

      def resolve_tool!(tool, base_dir, notes, run_version_commands, docker, digest_map, where)
        return if tool.nil?

        if tool['version'].nil? && tool['version_command']
          if run_version_commands
            banner = version_banner(tool['version_command'], base_dir)
            if banner
              tool['version'] = banner
            else
              notes << "#{where}: `#{tool['version_command']}` gave no version"
            end
          else
            notes << "#{where}: version_command not run (pass --run-version-commands to collect it)"
          end
        end
        resolve_image!(tool, notes, docker, digest_map, where) if tool['image']
      end

      # The locator an image-backed tool carries is the image reference with a
      # digest — the one form the container route reads as `immutable` (§5).
      # A reference that cannot be pinned is written as the customer declared
      # it and noted: the grade then shows `versioned` for a tag, which is the
      # truth about what that reference lets a stranger fetch.
      def resolve_image!(tool, notes, docker, digest_map, where)
        ref = tool['image']
        pinned = if ref =~ /@sha256:[0-9a-f]{64}\z/i
                   ref
                 else
                   digest = digest_map[ref] || (docker ? repo_digest(ref) : nil)
                   digest ? "#{ref}@#{digest}" : nil
                 end
        if pinned.nil?
          notes << "#{where}: no digest for image #{ref} (Docker not reachable, or the image is not pulled)"
          tool['uri'] ||= ref
          return
        end

        unless pinned =~ GenomicsChainProv::Predicate::OCI_IMAGE_DIGEST
          # §5 leaves this slack on purpose: an unschemed, non-registry-shaped
          # name is indistinguishable from a repo-relative path, and the digest
          # route is the only one that reaches `immutable`. Say so rather than
          # prepending a scheme the customer did not write — which registry a
          # bare name resolves to is theirs to state, not this writer's to guess.
          notes << "#{where}: #{ref} is not registry-shaped, so the digest will not grade as an image " \
                   '— write docker://<ref> if it is a Docker Hub name'
        end
        tool['uri'] = pinned
      end

      # --- the machine ------------------------------------------------------

      def digest_file(path)
        return nil unless File.file?(path) && File.readable?(path)

        sha1 = Digest::SHA1.new
        sha256 = Digest::SHA256.new
        File.open(path, 'rb') do |f|
          while (chunk = f.read(1 << 20))
            sha1 << chunk
            sha256 << chunk
          end
        end
        { 'sha1' => sha1.hexdigest, 'sha256' => sha256.hexdigest }
      rescue SystemCallError
        nil
      end

      # The first non-empty line of what the command printed, on either stream
      # — `bash --version` writes a banner to stdout, plenty of tools write
      # theirs to stderr, and §5's version rule is built to read a banner
      # ("GNU bash, version 5.2.21" is `versioned`) rather than demand a bare
      # number.
      def version_banner(command, base_dir)
        out, err, status = Open3.capture3(command, chdir: base_dir)
        return nil unless status.success?

        "#{out}\n#{err}".lines.map(&:strip).find { |l| !l.empty? }
      rescue SystemCallError, Errno::ENOENT
        nil
      end

      # `docker image inspect` on a reference that is pulled locally. Fixed
      # argv, no shell. A repo digest looks like `repo@sha256:…`; what is
      # wanted is the digest itself, to be appended to the reference the run
      # actually named (which keeps the tag visible beside it).
      def repo_digest(ref, runner: method(:docker_inspect))
        raw = runner.call(ref)
        return nil if raw.nil?

        raw[/@(sha256:[0-9a-f]{64})/i, 1] || raw[/(sha256:[0-9a-f]{64})/i, 1]
      end

      def docker_inspect(ref)
        out, _err, status = Open3.capture3('docker', 'image', 'inspect', '--format',
                                           '{{json .RepoDigests}}', ref)
        status.success? ? out : nil
      rescue Errno::ENOENT
        nil
      end

      # Design §10-9: the runtime reaches `immutable` when the bundle carries a
      # checksum of the engine itself. For Nextflow that is the framework jar,
      # and where it sits depends on how Nextflow was installed — the launcher
      # puts it under NXF_HOME, conda under the environment's share tree. Both
      # are looked for; neither found means the checksum stays empty and the
      # runtime grades `versioned`, which is what a version alone permits.
      def nextflow_jar(version, nxf_home: ENV.fetch('NXF_HOME', nil), nextflow_bin: nil)
        return nil if version.nil? || version.strip.empty?

        jar = "nextflow-#{version}-one.jar"
        candidates = [File.join(nxf_home || File.join(Dir.home, '.nextflow'), 'framework', version, jar)]
        bin = nextflow_bin || which('nextflow')
        if bin
          prefix = File.expand_path('..', File.dirname(File.realpath(bin)))
          candidates << File.join(prefix, 'share', 'nextflow', 'dist', version, jar)
        end
        candidates.find { |p| File.file?(p) }
      rescue SystemCallError
        nil
      end

      def which(name)
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
          path = File.join(dir, name)
          return path if File.file?(path) && File.executable?(path)
        end
        nil
      end

      # `file:///tmp/x` and `/tmp/x` name the same bytes; a relative locator is
      # relative to where the computation ran, which is what --base-dir says.
      def absolute(path, base_dir)
        File.expand_path(path.sub(%r{\Afile://}i, ''), base_dir)
      end
    end
  end
end
