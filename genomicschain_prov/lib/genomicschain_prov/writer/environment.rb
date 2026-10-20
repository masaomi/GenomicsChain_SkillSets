# frozen_string_literal: true

require 'digest'
require 'json'
require 'etc'
require 'open3'
require 'rbconfig'
require_relative '../predicate'
require_relative '../commitment'

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
      # With `commitment_key:` (option 2, v0.1.16 §6.1) each file gets its
      # gc-commitment-0.1 fingerprint only — {'hmac_sha256'} — and no plain
      # digest is computed at all.
      #
      # @return [Hash] {'checksums' => {locator => {'sha1','sha256'} or {'hmac_sha256'}}, 'notes' => [String]}
      def resolve!(plan, base_dir: Dir.pwd, checksums: true, run_version_commands: false,
                   docker: true, digest_map: {}, commitment_key: nil)
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
            digests = digest_file(full, commitment_key: commitment_key)
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

      # What this machine is, for the bundle's `platform` (design v0.1.12
      # §6.1): the kernel's own answer, no subprocess. `nodename` — the host
      # name — is deliberately left out: it identifies a machine, not a
      # platform, and the record has no use for it.
      def platform(uname: Etc.uname)
        { 'cpu_architecture' => uname[:machine].to_s, 'os_name' => uname[:sysname].to_s,
          'os_release' => uname[:release].to_s }.reject { |_, v| v.strip.empty? }
      end

      # The machine this writer runs on, for the bundle's `resources.machine`
      # (design v0.1.14 §6.2 (1)): the CPU model, the logical cores, the
      # memory, the free space where the computation's files are, and what a
      # GPU probe found. Nothing that names the machine or a person is written
      # — no host name, no user, no serial, UUID, MAC or PCI bus id. nvidia-smi
      # is asked for the kept fields only; system_profiler and rocm-smi print
      # more (system_profiler includes monitor serials), which is parsed in
      # memory and never accessed beyond model, vendor and VRAM.
      #
      # `gpus` is written when some probe answered `ok` (§6.2 (1)): `[]` then
      # means "looked, none" for the vendors in `gpu_vendors_probed`. A probe
      # that cannot read a GPU it reported is `failed` and contributes no GPU,
      # so on Linux a failed rocm-smi beside an answering nvidia-smi writes the
      # NVIDIA GPUs only, and the record names nvidia alone as probed. When no
      # probe answers, `gpus` is left out and the note says so, because "not
      # looked for" and "none" are different answers.
      #
      # @param runner [#call] argv => [stdout or nil, :ok | :not_found | :failed]
      # @param read [#call] path => content or nil (Linux /proc)
      # @return [Hash] 'machine' => {...,'source' => 'probe'}, 'notes' => [String]
      def machine(work_dir: Dir.pwd, uname: Etc.uname, runner: method(:run_fixed), read: method(:read_file))
        notes = []
        m = {}
        os = uname[:sysname].to_s
        if os == 'Linux'
          cpu = read.call('/proc/cpuinfo').to_s[/^model name\s*:\s*(.+)$/, 1]
          kb = read.call('/proc/meminfo').to_s[/^MemTotal:\s*(\d+)\s*kB/, 1]
          m['cpu_model'] = cpu.strip if cpu
          m['memory_total_bytes'] = kb.to_i * 1024 if kb
        elsif os == 'Darwin'
          cpu, = runner.call(%w[sysctl -n machdep.cpu.brand_string])
          mem, = runner.call(%w[sysctl -n hw.memsize])
          m['cpu_model'] = cpu.strip if cpu && !cpu.strip.empty?
          m['memory_total_bytes'] = mem.strip.to_i if mem && mem.strip =~ /\A\d+\z/
        end
        notes << 'the CPU model could not be read on this machine' unless m['cpu_model']
        m['logical_cores'] = Etc.nprocessors
        free = disk_free(work_dir, runner)
        m['disk_free_bytes'] = free if free
        probes, gpus = probe_gpus(os, runner)
        m['gpu_probe'] = probes unless probes.empty?
        if probes.any? { |p| p['result'] == 'ok' }
          m['gpus'] = gpus
        else
          notes << "no GPU probe answered here (#{probes.map { |p| "#{p['tool']}: #{p['result']}" }.join(', ')}): " \
                   'gpus not written, so the resources grade cannot reach full'
        end
        { 'machine' => m.merge('source' => 'probe'), 'notes' => notes }
      end

      # §6.2 (1), named at the freeze: the machine is the writer's, not
      # necessarily what a task could use. A container on macOS runs inside a
      # Linux virtual machine and cannot reach the host's GPU, so for a run
      # whose stages used containers there, the GPU lines are dropped rather
      # than written as if the tasks had them.
      def without_host_gpus(machine, notes)
        return machine unless machine&.key?('gpus') || machine&.key?('gpu_probe')

        notes << 'stages ran in containers on macOS, which cannot use this machine\'s GPU: gpus not written'
        machine.reject { |k, _| %w[gpus gpu_probe].include?(k) }
      end

      def probe_gpus(os, runner)
        if os == 'Linux'
          n_probe, n_gpus = probe_nvidia(runner)
          r_probe, r_gpus = probe_rocm(runner)
          [[n_probe, r_probe], n_gpus + r_gpus]
        elsif os == 'Darwin'
          probe, gpus = probe_system_profiler(runner)
          [[probe], gpus]
        else
          [[], []]
        end
      end

      # A probe answers `ok` only when every GPU it reported could be read in
      # full; a line or a card it could not read makes it `failed`, so a parse
      # miss is never signed as "looked, none" (implementation review r1).
      def probe_nvidia(runner)
        out, state = runner.call(%w[nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits])
        return [{ 'tool' => 'nvidia-smi', 'result' => state.to_s }, []] unless state == :ok

        rows = out.to_s.lines.map(&:strip).reject(&:empty?).map { |l| l.split(',').map(&:strip) }
        return [{ 'tool' => 'nvidia-smi', 'result' => 'failed' }, []] unless rows.all? { |r| r.length == 3 && !r[0].empty? }

        # `--version` prints the versions alone; the bare table would also
        # print bus ids and process names that are never kept.
        versions, = runner.call(%w[nvidia-smi --version])
        cuda = versions.to_s[/CUDA Version\s*:\s*([\d.]+)/, 1]
        gpus = rows.map do |name, mib, driver|
          Writer.compact_h('vendor' => 'nvidia', 'model' => name,
                           'memory_bytes' => mib =~ /\A\d+\z/ ? mib.to_i * 1024 * 1024 : nil,
                           'driver_version' => driver.empty? ? nil : driver,
                           'runtime' => cuda ? { 'name' => 'CUDA', 'version' => cuda } : nil)
        end
        [Writer.compact_h('tool' => 'nvidia-smi', 'version' => versions.to_s[/NVIDIA-SMI version\s*:\s*([\d.]+)/, 1],
                          'result' => 'ok'), gpus]
      end

      # Keys are matched without regard to case: ROCm releases have printed
      # both `Card series` and `Card Series` [unverified which prints which].
      def probe_rocm(runner)
        out, state = runner.call(%w[rocm-smi --showproductname --json])
        return [{ 'tool' => 'rocm-smi', 'result' => state.to_s }, []] unless state == :ok

        # Output in a shape this code cannot read is `failed`, never "none"
        # (implementation review r2): the top level must be an object, and
        # every `card…` entry an object naming a series or a model. `Card
        # Series` is preferred — `Card Model` is the PCI device id.
        top = JSON.parse(out.to_s)
        return [{ 'tool' => 'rocm-smi', 'result' => 'failed' }, []] unless top.is_a?(Hash)

        cards = top.select { |k, _| k.to_s.downcase.start_with?('card') }.values
        models = cards.map do |c|
          next nil unless c.is_a?(Hash)

          %w[card\ series card\ model].filter_map do |want|
            v = c.find { |k, val| k.to_s.downcase == want && val.is_a?(String) && !val.strip.empty? }
            v && v[1].strip
          end.first
        end
        return [{ 'tool' => 'rocm-smi', 'result' => 'failed' }, []] if models.any?(&:nil?)

        [{ 'tool' => 'rocm-smi', 'result' => 'ok' }, models.map { |m| { 'vendor' => 'amd', 'model' => m } }]
      rescue JSON::ParserError
        [{ 'tool' => 'rocm-smi', 'result' => 'failed' }, []]
      end

      # `system_profiler SPDisplaysDataType -json`: only the GPU's own model,
      # vendor and VRAM are taken. The nested display list (`spdisplays_ndrvs`)
      # names monitors by serial number; it is parsed with the rest of the
      # output and never accessed.
      def probe_system_profiler(runner)
        out, state = runner.call(%w[system_profiler SPDisplaysDataType -json])
        return [{ 'tool' => 'system_profiler', 'result' => state.to_s }, []] unless state == :ok

        # The list must be there as a list (an explicit `[]` is "none"); an
        # entry must name its model (implementation review r2).
        list = JSON.parse(out.to_s)['SPDisplaysDataType']
        return [{ 'tool' => 'system_profiler', 'result' => 'failed' }, []] unless list.is_a?(Array)

        gpus = list.map do |g|
          next nil unless g.is_a?(Hash) && g['sppci_model'].is_a?(String) && !g['sppci_model'].strip.empty?

          Writer.compact_h('vendor' => gpu_vendor("#{g['spdisplays_vendor']} #{g['sppci_model']}"),
                           'model' => g['sppci_model'].strip,
                           'memory_bytes' => vram_bytes(g['spdisplays_vram'] || g['_spdisplays_vram']))
        end
        return [{ 'tool' => 'system_profiler', 'result' => 'failed' }, []] if gpus.any? { |g| g.nil? || g['vendor'].nil? }

        [{ 'tool' => 'system_profiler', 'result' => 'ok' }, gpus]
      rescue JSON::ParserError, NoMethodError, TypeError
        [{ 'tool' => 'system_profiler', 'result' => 'failed' }, []]
      end

      def gpu_vendor(text)
        t = text.downcase
        return 'apple' if t.include?('apple')
        return 'nvidia' if t.include?('nvidia')
        return 'intel' if t.include?('intel')
        return 'amd' if t.include?('amd') || t =~ /\bati\b/

        nil
      end

      def vram_bytes(text)
        m = text.to_s.match(/\A\s*(\d+)\s*(MB|GB)\s*\z/i)
        m && m[1].to_i * (m[2].casecmp?('GB') ? 1024**3 : 1024**2)
      end

      # `df -Pk -- DIR`: the POSIX form, so the columns are the same on Linux
      # and macOS. The space available is the column before the capacity
      # percentage — counted from there, because a file system name may
      # contain a space (macOS `map auto_home`).
      def disk_free(dir, runner)
        out, state = runner.call(['df', '-Pk', '--', File.absolute_path(dir)])
        return nil unless state == :ok

        fields = out.to_s.lines[1].to_s.split
        at = fields.index { |f| f =~ /\A\d+%\z/ }
        kb = at && at.positive? ? fields[at - 1] : nil
        kb =~ /\A\d+\z/ ? kb.to_i * 1024 : nil
      end

      # Fixed argv, no shell; a missing program is :not_found, not an error.
      # A command whose own process has not exited after PROBE_TIMEOUT seconds
      # is killed and recorded `timeout` (a wedged GPU driver or a stale NFS
      # mount would otherwise hold `gc_prov_write --plan`; operator,
      # 2026-10-17). What this does not bound: a child the command left behind
      # that keeps the output pipes open, or a process SIGKILL cannot end — the
      # read then waits for them. None of the probe commands is known to do
      # either [unverified].
      PROBE_TIMEOUT = 10

      def run_fixed(argv, timeout: PROBE_TIMEOUT)
        Open3.popen3(*argv) do |stdin, stdout, stderr, wait|
          stdin.close
          reader = Thread.new { stdout.read }
          drain = Thread.new { stderr.read }
          unless wait.join(timeout)
            begin
              Process.kill('KILL', wait.pid)
            rescue SystemCallError
              nil
            end
            wait.join
            [reader, drain].each { |t| t.join(1) || t.kill }
            return [nil, :timeout]
          end
          drain.join
          [reader.value, wait.value.success? ? :ok : :failed]
        end
      rescue Errno::ENOENT
        [nil, :not_found]
      rescue SystemCallError
        [nil, :failed]
      end

      def read_file(path)
        File.file?(path) ? File.read(path) : nil
      rescue SystemCallError
        nil
      end

      # Declarations for the receipts a plan names, each with the SHA-256 of
      # the receipt file measured here. A receipt that is not a readable file
      # is left out and noted — the same rule as a missing input: never write
      # a digest of bytes this machine did not see.
      #
      # @param journal [String] the bundle's one convention (Writer::ZK_JOURNAL or ZK_JOURNAL_V02)
      # @return [Hash] {'zk_receipts' => [declaration], 'notes' => [String]}
      def zk_declarations(entries, base_dir: Dir.pwd, journal: Writer::ZK_JOURNAL)
        notes = []
        decls = Array(entries).filter_map do |e|
          sums = digest_file(absolute(e['receipt'], base_dir))
          if sums.nil?
            notes << "zk receipt for step #{e['step_number']} left out: #{e['receipt']} is not a readable file"
            next nil
          end
          Writer.zk_declaration(e, sums['sha256'], journal: journal)
        end
        { 'zk_receipts' => decls, 'notes' => notes }
      end

      # The receipt's own sha256 is always plain (it names the receipt file,
      # not a data file); `commitment_key:` is for the bundle's file
      # fingerprints only.
      def digest_file(path, commitment_key: nil)
        return nil unless File.file?(path) && File.readable?(path)

        if commitment_key
          c = GenomicsChainProv::Commitment.commit_file(commitment_key, path)
          return c && { 'hmac_sha256' => c }
        end

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
