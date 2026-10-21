# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'genomicschain_core'
require 'genomicschain_tier3_record/records'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      # ProcessRecord — gc-t3-process-0.1 (design §6.1, §9-6): the one
      # directory the executor keeps, which Tier 4 distils. Six items and a
      # manifest:
      #
      #   01_declaration.json  ① the signed declaration, its envelope, and the
      #                          plain description the attempts need (a key
      #                          path at most, never key bytes)
      #   02_build.jsonl       ② per attempt: commands, exit codes, and each pin
      #                          as observed (the material of ①'s rule, §3.1)
      #   03_runs.jsonl        ③ per built attempt: the command and runs = 1
      #   04_logs.jsonl        ④ per attempt: fingerprints of the logs
      #   05_inference.json    ⑤ the inferred proposals, labelled, adopted or not
      #   06_scores.jsonl      ⑥ the rows the attestation signs
      #   manifest.json        path and fingerprint of the six, canonical JSON
      #
      # Failed attempts stay (§6.1). Only the manifest's digest reaches a
      # record (§4.1). The state between the three tool actions lives here
      # (one synchronous call per action, C15). The directory is 0700 and every
      # file 0600 (review r1 F3): it may hold sample names and paths.
      #
      # An attempt is recorded as started by an empty marker whose name holds
      # its number and backend, made atomically and removed when its score row
      # is written. A marker left behind is an interrupted attempt, which the
      # next call closes (§3.4〔実装〕, operator 2026-10-21 question 6).
      class ProcessRecord
        ITEMS = %w[01_declaration.json 02_build.jsonl 03_runs.jsonl 04_logs.jsonl 05_inference.json
                   06_scores.jsonl].freeze
        DECLARATION, BUILD, RUNS, LOGS, INFERENCE, SCORES = ITEMS
        MANIFEST = 'manifest.json'
        STARTED = /\Aattempt-(\d+)\.(local|thoa)\.started\z/
        FORMAT = GenomicschainTier3Record::Records::PROCESS_FORMAT

        attr_reader :dir

        def self.create(dir, declaration:, operator:, job:, inference:)
          FileUtils.mkdir_p(File.dirname(dir))
          Dir.mkdir(dir, 0o700)
          File.chmod(0o700, dir)
          record = new(dir)
          record.write_json(DECLARATION, 'format' => FORMAT, 'declaration' => declaration, 'operator' => operator,
                                         'job' => job)
          record.write_json(INFERENCE, inference)
          [BUILD, RUNS, LOGS, SCORES].each { |item| record.write(item, '') }
          record
        end

        def initialize(dir)
          @dir = dir
        end

        def path(item) = File.join(@dir, item)
        def declared? = File.file?(path(DECLARATION))
        def read_json(item) = JSON.parse(File.read(path(item)))
        def write_json(item, obj) = write(item, KairosMcp::Manifest.canonical_json(obj))

        def write(item, bytes)
          File.open(path(item), File::WRONLY | File::CREAT | File::TRUNC | File::BINARY, 0o600) { |f| f.write(bytes) }
          File.chmod(0o600, path(item))
        end

        def append(item, obj)
          File.open(path(item), File::WRONLY | File::CREAT | File::APPEND, 0o600) do |f|
            f.write(KairosMcp::Manifest.canonical_json(obj), "\n")
          end
        end

        def lines(item)
          File.readlines(path(item)).map(&:strip).reject(&:empty?).map { |l| JSON.parse(l) }
        end

        # One call at a time per record (review r1 H5): an exclusive flock on
        # the directory itself, so no lock file is left behind, and a killed
        # holder releases it.
        def locked
          File.open(@dir, File::RDONLY) do |d|
            d.flock(File::LOCK_EX)
            yield
          end
        end

        def mark_started(number, backend)
          File.open(path("attempt-#{number}.#{backend}.started"), File::WRONLY | File::CREAT | File::EXCL, 0o600, &:close)
        end

        def clear_started(number, backend) = File.delete(path("attempt-#{number}.#{backend}.started"))

        # [[number, backend], ...] of the attempts started and not finished.
        def started
          Dir.children(@dir).filter_map { |n| (m = STARTED.match(n)) && [m[1].to_i, m[2]] }.sort
        end

        # Rewritten by every attest, since the items grow with each attempt.
        # @param fingerprint [Fingerprint] the job's rule (C(f) when salted)
        # @return [String] the manifest's path
        def write_manifest(fingerprint)
          files = ITEMS.sort.map { |item| { 'path' => item, 'fingerprint' => fingerprint.file(path(item)) } }
          write(MANIFEST, KairosMcp::Manifest.canonical_json('format' => FORMAT, 'files' => files))
          path(MANIFEST)
        end
      end
    end
  end
end
