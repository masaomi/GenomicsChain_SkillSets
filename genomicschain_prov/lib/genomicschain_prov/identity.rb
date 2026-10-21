# frozen_string_literal: true

require 'json'
require 'digest'
require_relative 'adapters/bco'
require_relative 'predicate'
require_relative 'resources'

# The bundle digest is core's canonical JSON (design §2, `kairos-sorted-json-0.1`)
# — the same function the anchor uses, never a copy, so the customer's
# gc_prov_check and the anchor cannot drift apart on the digest subject. Core
# sits beside prov in a dev clone and under .kairos/skillsets/ when installed;
# prov depends on it either way (skillset.json).
begin
  require 'genomicschain_core/manifest'
rescue LoadError
  sibling = File.expand_path('../../../genomicschain_core/lib', __dir__)
  raise unless File.directory?(sibling)

  $LOAD_PATH.unshift(sibling)
  require 'genomicschain_core/manifest'
end

module GenomicsChainProv
  # Identity — a bundle's bytes → the signed identity of its Tier-2.5 record
  # (design v0.1 §6; record_version 0.3 per v0.1.12 §6.1, 0.4 per v0.1.14 §6.2,
  # 0.5 per v0.1.16 §6.4).
  #
  # One function for every party: the customer's gc_prov_check computes the
  # params to sign with it, the anchor derives them again from the bytes it
  # received and refuses a submission that disagrees, and the verifier rebuilds
  # them to check the submitter's signature. Nothing here reads a clock, a file
  # or the network.
  #
  # What it does NOT do is decide admission. Whether the anchor will issue a
  # record (the ZK checks) is `admission`, reported beside the identity,
  # because a customer needs both answers and the anchor needs them in a fixed
  # order.
  module Identity
    # What a record issued now carries. 0.3 records stay readable: the sets
    # below are kept per version, and the verifier picks by the record's own.
    RECORD_VERSION = '0.5'
    BUNDLE_DIGEST_CANONICALIZATION = 'kairos-sorted-json-0.1'
    ADMISSION_RULE = 'prov-admission-0.2'
    # What each rule an anchor has issued under means, for the verifier's
    # "the anchor says" line (§6.1 (1), v0.1.13). 0.1 stays: records were made
    # under it on disposable local anchors, and an old record must not be read
    # by the new rule.
    ADMISSION_RULES = {
      'prov-admission-0.1' => 'issued only at grade immutable, with every declared zk receipt verified ' \
                              'and bound to its step',
      'prov-admission-0.2' => 'issued at any grade, the grade carried as computed, with every declared zk ' \
                              'receipt verified and bound to its step'
    }.freeze
    MAX_ZK_RECEIPTS = 4

    LEVELS = Predicate::LEVELS
    COUNT_FIELDS = (%w[stages_total stages_with_environment stages_with_own_environment
                       scripts_total scripts_with_checksum software_total] +
                    LEVELS.map { |l| "software_#{l}" } + %w[containers_total] +
                    LEVELS.map { |l| "containers_#{l}" } +
                    %w[inputs_total inputs_with_checksum inputs_internal
                       outputs_total outputs_with_checksum outputs_digest params_count params_total]).freeze

    # The set of signed fields is fixed by record_version (§6): a verifier
    # builds `params` from the manifest with the set its record_version names,
    # and treats an unknown record_version as "different version" (§8).
    BASE_SIGNED_FIELDS = (%w[subject_ref bundle_format bundle_format_version bundle_digest
                             bundle_digest_canonicalization outputs_digest_rule
                             producer_name producer_version adapter_version predicate_version pin_strength_version
                             grade_overall grade_software grade_container grade_environment grade_inputs
                             grade_workflow grade_runtime] +
                          COUNT_FIELDS +
                          %w[workflow_repository_sha256 workflow_commit
                             platform_cpu_architecture platform_os_name platform_os_release
                             zk_receipts]).freeze
    SIGNED_FIELDS = {
      '0.3' => BASE_SIGNED_FIELDS,
      # v0.1.14 §6.2 (3): the 0.3 fields unchanged, and the nine resource fields after them
      '0.4' => (BASE_SIGNED_FIELDS + Resources::SIGNED_FIELDS).freeze,
      # v0.1.16 §6.4: the 0.4 fields unchanged. zk_receipts[].journal_convention
      # may now be gc-zk-journal-0.2; the key_id and the salted fingerprints are
      # never signed fields (C5).
      '0.5' => (BASE_SIGNED_FIELDS + Resources::SIGNED_FIELDS).freeze
    }.freeze

    # The record's not_checked list (§6, §6.1 (4), §6.2 (3)): fixed by the
    # builder, never taken from a client, the same items on every record of a
    # record_version whether or not it carries a receipt or a resource.
    NOT_CHECKED_BY_VERSION = {
      '0.3' => %w[
        locator_reachability bundle_truthfulness bundle_schema_conformance checksum_values_as_written
        reference_genome_identification seed_identification
        platform_as_written zk_guest_program_semantics zk_inputs_are_raw_data
      ].freeze,
      '0.4' => %w[
        locator_reachability bundle_truthfulness bundle_schema_conformance checksum_values_as_written
        reference_genome_identification seed_identification
        platform_as_written zk_guest_program_semantics zk_inputs_are_raw_data
        resources_as_written
      ].freeze,
      # v0.1.16 §6.4: what a receipt reveals outside its journal is RISC Zero's
      # zero-knowledge property, which GenomicsChain has not tested. On every
      # 0.5 record, option 1 included (§6.1 (4): the same items per version).
      '0.5' => %w[
        locator_reachability bundle_truthfulness bundle_schema_conformance checksum_values_as_written
        reference_genome_identification seed_identification
        platform_as_written zk_guest_program_semantics zk_inputs_are_raw_data
        resources_as_written zk_zero_knowledge_property
      ].freeze
    }.freeze
    NOT_CHECKED = NOT_CHECKED_BY_VERSION.fetch(RECORD_VERSION)

    # Design v0.1.12 §6.1, the two sentences every verifier output and every
    # description of not_checked carries verbatim (memory warranty-scope,
    # operator instruction 2026-10-12).
    STATEMENTS = [
      'A ZK receipt shows only that the named steps were computed correctly from the recorded inputs. ' \
      'It covers only those steps and does not show that the recorded inputs are the raw data.',
      'GenomicsChain guarantees its own procedure and record only. A Tier 3 record is a dated observation ' \
      'that the declared result was reached that day, not a promise of future reproduction.'
    ].freeze

    module_function

    # @param bundle [String, Hash] the bundle verbatim (JSON text or object)
    # @return [Hash] 'signed' (the identity, string keys), 'graded' (the
    #   predicate's full output, for the customer — never for the anchor's
    #   logs, §6), 'resources' (the resource reader's output, the same
    #   reservation), 'np' (the normalised provenance), 'bundle_digest'
    # @raise [Adapters::Bco::FormatError]
    def derive(bundle)
      text = bundle.is_a?(String) ? bundle : JSON.generate(bundle)
      digest = bundle_digest(text)
      np = Adapters::Bco.parse(text)
      graded = Predicate.grade(np)
      # After the adapter, which refuses what is not a BCO: the resource
      # reader itself refuses nothing (§6.2).
      resources = Resources.derive(text, np.stages)
      { 'signed' => signed(np, graded, digest).merge(resources['signed']), 'graded' => graded,
        'resources' => resources, 'np' => np, 'bundle_digest' => digest }
    end

    # The procedure versions the seven grades and the counts are derived
    # under (§6, §8), and the two the resource fields are (§6.2 (5)): the
    # adapter, because it fixes the stage positions, and the resource rule.
    def procedure_versions
      { 'adapter_version' => Adapters::Bco::VERSION, 'predicate_version' => Predicate::PREDICATE_VERSION,
        'pin_strength_version' => Predicate::PIN_STRENGTH_VERSION }
    end

    def resources_versions
      { 'adapter_version' => Adapters::Bco::VERSION, 'resources_rule_version' => Resources::RULE_VERSION }
    end

    # The canonical-JSON SHA-256 of the bundle as parsed from its own bytes —
    # not of the adapter's normalised copy, and not the file's sha256 (§2).
    def bundle_digest(text)
      parsed = JSON.parse(text)
      KairosMcp::Manifest.canonical_json_sha256(parsed)
    rescue JSON::ParserError
      raise Adapters::Bco::FormatError, 'bundle is not valid JSON', cause: nil
    end

    def signed(np, graded, digest)
      g = graded['grades']
      c = graded['counts']
      w = np.workflow || {}
      platform = np.platform || {}
      out = {
        'subject_ref' => "prov:sha256:#{digest}",
        'bundle_format' => np.format,
        'bundle_format_version' => np.format_version,
        'bundle_digest' => digest,
        'bundle_digest_canonicalization' => BUNDLE_DIGEST_CANONICALIZATION,
        'outputs_digest_rule' => graded['outputs_digest_rule'],
        'producer_name' => np.producer && np.producer['name'],
        'producer_version' => np.producer && np.producer['version'],
        'adapter_version' => Adapters::Bco::VERSION,
        'predicate_version' => graded['predicate_version'],
        'pin_strength_version' => graded['pin_strength_version'],
        'grade_overall' => graded['grade_overall']
      }
      %w[software container environment inputs workflow runtime].each { |k| out["grade_#{k}"] = g[k] }
      COUNT_FIELDS.each { |k| out[k] = c[k] }
      repo = w['repository']
      out['workflow_repository_sha256'] = repo.nil? || repo.to_s.empty? ? nil : Digest::SHA256.hexdigest(repo.to_s)
      out['workflow_commit'] = w['commit']
      out['platform_cpu_architecture'] = platform['cpu_architecture']
      out['platform_os_name'] = platform['os_name']
      out['platform_os_release'] = platform['os_release']
      out['zk_receipts'] = zk_identities(np)
      out
    end

    # Per receipt: fingerprints and names only (§6.1). Never the input/output
    # locators or digests the declaration binds — those stay in the bundle.
    def zk_identities(np)
      Array(np.zk_receipts).map do |r|
        { 'receipt_sha256' => r['receipt_sha256'], 'image_id' => r['image_id'],
          'zkvm_name' => r['zkvm_name'], 'zkvm_version' => r['zkvm_version'],
          'stage' => r['stage'], 'journal_convention' => r['journal_convention'] }
      end.sort_by { |r| [r['stage'].to_i, r['receipt_sha256'].to_s] }
    end

    # What stands between this bundle and a record, as far as the bundle alone
    # can tell (§6.1 (3)). The grade is not among them: since v0.1.13 a record
    # is issued at any grade and carries it, and whoever reads the record —
    # Tier 3's route B, a third party — draws its own line on the signed grade.
    # The ZK checks that need the receipt bytes are ZkVerifier.check; this
    # reports the declarations' own defects.
    #
    #
    # v0.1.16: the adapter's option-2 refusals (§6.1, S2) are among them, and
    # the journal conventions the declarations name are reported so the
    # anchor can apply its own setting (S4). No configuration is read here:
    # a customer's gc_prov_check says "issuable" for a 0.2 bundle that an
    # anchor with the option closed refuses.
    #
    # @return [Hash] 'issuable' (bool, bundle-side only), 'grade_overall' (for
    #   the reader, not a condition), 'zk_receipts_declared',
    #   'zk_defects' [{'stage','defects'}], 'too_many_zk_receipts',
    #   'bundle_refusals' [code], 'journal_conventions' [declared, distinct]
    def admission(derived)
      np = derived['np']
      receipts = Array(np.zk_receipts)
      defects = receipts.reject { |r| r['defects'].empty? }
                        .map { |r| { 'stage' => r['stage'], 'defects' => r['defects'] } }
      too_many = receipts.length > MAX_ZK_RECEIPTS
      refusals = Array(np.refusals)
      { 'issuable' => defects.empty? && !too_many && refusals.empty?,
        'grade_overall' => derived['graded']['grade_overall'], 'zk_receipts_declared' => receipts.length,
        'zk_defects' => defects, 'too_many_zk_receipts' => too_many, 'bundle_refusals' => refusals,
        'journal_conventions' => receipts.filter_map { |r| r['journal_convention'] }.uniq.sort }
    end

    # The params a verifier rebuilds from a stored manifest, by its own
    # record_version. nil for a record_version this code does not know.
    def params_from_manifest(manifest)
      fields = SIGNED_FIELDS[manifest['record_version']]
      fields && fields.to_h { |k| [k, manifest[k]] }
    end

    # §6 claim string; the anchor and the verifier build it the same way.
    def claim(signed, submission_key)
      "prov:#{signed['predicate_version']}:#{signed['grade_overall']}:" \
        "#{signed['stages_with_own_environment']}/#{signed['stages_total']}:#{signed['bundle_digest']}:#{submission_key}"
    end
  end
end
