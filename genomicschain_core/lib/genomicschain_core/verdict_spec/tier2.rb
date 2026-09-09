# frozen_string_literal: true

require 'digest'
require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module VerdictSpec
        # Tier2VerdictSpec — Tier-2 (code-reading) hooks for SubmitCore.
        #
        # Same shape as Tier-1 and Tier-3, same recording path (a Synoptis
        # proof on the anchor), no new chain. What differs is only what the
        # digest subject is and which fields the operator signs:
        #
        #   Tier-1  digest subject = report.json      identity = report fields
        #   Tier-3  digest subject = jobspec_json     identity = verdict_result
        #   Tier-2  digest subject = the adjudication identity = derived from it
        #
        # The adjudication is the output of gc_tier2_adjudicate, submitted
        # VERBATIM. The server recomputes its canonical sha256, derives every
        # signed field from it again, and rejects the submit if either differs
        # from what the operator signed. Nothing about the identity is taken on
        # the client's word — which is possible here precisely because the
        # code-reading tier is deterministic (2026-09-09): the same bytes and
        # the same interpreter yield the same adjudication, so the interpreter
        # version is part of the signed identity too.
        #
        # What the record asserts is narrow and stated in the claim string: a
        # named operator ran the static code read of THIS evidence against
        # THIS Tier-1 report and it proposed THESE dispositions. It is a
        # self_reported proposal. It does not apply the stage transition
        # (stage_transition.applied stays false) and it does not say the
        # paper is reproducible.
        class Tier2
          SIGNED_IDENTITY_FIELDS = %w[
            subject_ref
            tier1_report_content_hash tier1_rubric_version
            codescan_evidence_digest codescan_rubric_version
            adjudication_rubric_version adjudication_digest
            lever1_declared_lock lever1_byte_fixed_lock lever2_in_code_db_pin_classA
            tier1_steps steps_linked proposed_demotions
            toolchain_ruby
            repository_url repository_commit
          ].freeze

          MCP_TOOL = 'gc_tier2_submit'
          ADJUDICATION_MAX_BYTES = 2 * 1024 * 1024

          # @param adjudication [Hash, String] gc_tier2_adjudicate output, verbatim
          # @param identity [Hash] the signed identity the operator claims (see
          #   .identity_for); every field is re-derived server-side
          # @param repository [Hash, nil] {url, commit} of the checkout that was
          #   scanned. The scanner records no commit (it skips .git), so this is
          #   the operator's statement and is signed as such when given.
          def initialize(adjudication:, identity:, repository: nil)
            @raw = adjudication
            @identity = (identity || {}).transform_keys(&:to_s)
            @repository = (repository || {}).transform_keys(&:to_s)
            @adjudication = nil
            @digest = nil
          end

          attr_reader :adjudication, :identity, :repository

          def subject_ref
            derived['subject_ref']
          end

          def parse_digest_subject!
            @adjudication =
              if @raw.is_a?(Hash)
                gate_a!(JSON.generate(@raw))
                JSON.parse(JSON.generate(@raw)) # string keys throughout
              else
                gate_a!(@raw.to_s)
                JSON.parse(@raw.to_s)
              end
            raise SubmitCore::DigestMismatch, 'adjudication must be a JSON object' unless @adjudication.is_a?(Hash)

            @adjudication
          rescue JSON::ParserError => e
            raise SubmitCore::DigestMismatch, "adjudication is not valid JSON: #{e.message}"
          end

          def recompute_digest!(parsed)
            @digest = self.class.adjudication_digest(parsed)
          end

          def claimed_digest
            claimed = @identity['adjudication_digest']
            if claimed.nil? || claimed.to_s.empty?
              raise SubmitCore::DigestMismatch, 'identity.adjudication_digest missing'
            end

            claimed.to_s
          end

          def signed_identity_params
            derived
          end

          # Every signed field is derived from the adjudication again and
          # compared with what the client says it signed. A client cannot sign
          # one lever reading and submit an adjudication that says another.
          def assert_submitted_matches_signed!
            derived.each do |k, expected|
              actual = @identity[k]
              next if actual == expected

              raise SubmitCore::IdentityMismatch,
                    "#{k} (#{actual.inspect}) != derived from adjudication (#{expected.inspect})"
            end
          end

          def reject_client_server_set_fields!(adjudication)
            return unless adjudication.key?('trust_tier')

            raise SubmitCore::TrustTierError, 'trust_tier is server-set; must not appear in the adjudication'
          end

          def server_set_fields(_pubkey)
            { 'trust_tier' => 'self_reported' }
          end

          def build_manifest(operator:, submission_key:, server_fields:)
            record = KairosMcp::Manifest.build_tier2_adjudication(
              self.class.record_fields(@adjudication, derived, @repository).merge(
                'trust_tier' => server_fields['trust_tier'],
                'submission_key' => submission_key,
                'operator' => operator
              )
            )
            KairosMcp::Manifest.validate_tier2!(record)
            record
          end

          # Lock state and proposal count are in the claim string so a reader
          # scanning the registry sees what was found, not just that a scan
          # happened. The count is a lower bound and the record says so.
          def claim_for(submission_key:)
            "tier2:#{self.class.lock_state(derived)}:#{derived['proposed_demotions']}:#{@digest}:#{submission_key}"
          end

          def trust_tier_gate!
            # trust_tier is server-set on the record; the adjudication must not carry it.
          end

          def apply_gates!(parsed)
            KairosMcp::Manifest.dos_gate!(parsed)
            KairosMcp::Manifest.restricted_subset!(parsed)
            validate_required_shape!(parsed)
          end

          class << self
            # The identity the operator signs, derived from the adjudication and
            # the (optional) repository statement. Deterministic: the same
            # adjudication yields the same params, which is what lets the server
            # re-derive rather than trust.
            def identity_for(adjudication, repository = nil)
              a = adjudication.is_a?(String) ? JSON.parse(adjudication) : JSON.parse(JSON.generate(adjudication))
              repo = (repository || {}).transform_keys(&:to_s)
              subj = a['subject'] || {}
              lever1 = a.dig('levers', 'lever1_environment_lock') || {}
              counts = a['counts'] || {}
              cid = subj['canonical_id']
              raise SubmitCore::SubmitError, 'adjudication.subject.canonical_id missing' if cid.nil? || cid.to_s.empty?

              {
                'subject_ref' => "doi:#{cid}",
                'tier1_report_content_hash' => subj['tier1_report_content_hash'],
                'tier1_rubric_version' => subj['tier1_rubric_version'],
                'codescan_evidence_digest' => subj['codescan_evidence_digest'],
                'codescan_rubric_version' => subj.dig('codescan_toolchain', 'codescan_rubric_version'),
                'adjudication_rubric_version' => a['adjudication_rubric_version'],
                'adjudication_digest' => adjudication_digest(a),
                'lever1_declared_lock' => lever1.dig('declared_lock', 'value'),
                'lever1_byte_fixed_lock' => lever1.dig('byte_fixed_lock', 'value'),
                'lever2_in_code_db_pin_classA' => a.dig('levers', 'code_derived', 'in_code_db_pin_classA'),
                'tier1_steps' => counts['tier1_steps'],
                'steps_linked' => counts['steps_linked'],
                'proposed_demotions' => counts['proposed_demotions'],
                'toolchain_ruby' => subj.dig('codescan_toolchain', 'ruby'),
                'repository_url' => blank_to_nil(repo['url']),
                'repository_commit' => blank_to_nil(repo['commit'])
              }
            end

            def adjudication_digest(adjudication)
              KairosMcp::Manifest.canonical_json_sha256(adjudication)
            end

            def lock_state(identity)
              return 'byte_fixed_lock' if identity['lever1_byte_fixed_lock']
              return 'declared_lock' if identity['lever1_declared_lock']

              'no_lock'
            end

            # Fields of the record beyond the signed identity: counts and codes
            # a reader needs to weigh the proposal, never the per-resource
            # lists (those stay with the operator, referenced by the digest).
            def record_fields(adjudication, identity, repository)
              a = adjudication
              subj = a['subject'] || {}
              counts = a['counts'] || {}
              lever1 = a.dig('levers', 'lever1_environment_lock') || {}
              st = a['stage_transition'] || {}
              out = {
                'subject_ref' => identity['subject_ref'],
                'canonical_id_value' => subj['canonical_id'],
                'tier1_report_content_hash' => identity['tier1_report_content_hash'],
                'tier1_rubric_version' => identity['tier1_rubric_version'],
                'tier1_funnel_stage' => st['from'],
                'codescan_evidence_digest' => identity['codescan_evidence_digest'],
                'codescan_rubric_version' => identity['codescan_rubric_version'],
                'adjudication_rubric_version' => identity['adjudication_rubric_version'],
                'adjudication_digest' => identity['adjudication_digest'],
                'levers' => {
                  'declared_lock' => identity['lever1_declared_lock'],
                  'byte_fixed_lock' => identity['lever1_byte_fixed_lock'],
                  'in_code_db_pin_classA' => identity['lever2_in_code_db_pin_classA'],
                  'headline' => lever1['headline']
                },
                'counts' => {
                  'rules_in_code' => counts['rules_in_code'],
                  'rules_unique' => counts['rules_unique'],
                  'tier1_steps' => counts['tier1_steps'],
                  'steps_linked' => counts['steps_linked'],
                  'steps_unlinked' => counts['steps_unlinked'],
                  'proposed_demotions' => counts['proposed_demotions'],
                  'demotion_proposal_is_a_lower_bound' => counts['demotion_proposal_is_a_lower_bound']
                },
                'ambiguous_links' => Array(a['ambiguous_links']).length,
                'discrepancy_codes' => Array(a['discrepancies']).map { |d| (d['code'] || d[:code]).to_s },
                'toolchain' => subj['codescan_toolchain'],
                'adjudication_toolchain' => subj['adjudication_toolchain'],
                'stage_transition' => { 'from' => st['from'], 'to' => st['to'], 'applied' => false }
              }
              repo = (repository || {}).transform_keys(&:to_s)
              if identity['repository_url'] || identity['repository_commit']
                out['repository'] = { 'url' => identity['repository_url'],
                                      'commit' => identity['repository_commit'] }.compact
                out['repository']['provenance'] = repo['provenance'] || 'operator_stated'
              end
              out
            end

            def blank_to_nil(v)
              v.nil? || v.to_s.strip.empty? ? nil : v.to_s
            end
          end

          private

          def derived
            @derived ||= self.class.identity_for(@adjudication || parse_digest_subject!, @repository)
          end

          def gate_a!(raw)
            size = raw.bytesize
            return if size <= ADJUDICATION_MAX_BYTES

            raise SubmitCore::EvidenceTooLarge,
                  "adjudication size #{size} exceeds Gate A limit #{ADJUDICATION_MAX_BYTES}"
          end

          # The fields a Tier-2 record cannot exist without. A Tier-1 report
          # with no content hash (the older v0.2.5 stage-2 reports) yields an
          # adjudication that cannot be bound to what it adjudicated, and is
          # refused here rather than recorded with a hole where the binding goes.
          def validate_required_shape!(a)
            %w[adjudication_rubric_version subject levers counts stage_transition].each do |k|
              raise SubmitCore::SubmitError, "adjudication missing required field #{k}" unless a.key?(k) && !a[k].nil?
            end
            subj = a['subject']
            %w[canonical_id tier1_report_content_hash codescan_evidence_digest codescan_toolchain].each do |k|
              v = subj[k]
              next unless v.nil? || (v.respond_to?(:empty?) && v.empty?)

              raise SubmitCore::SubmitError, "adjudication.subject.#{k} missing — a Tier-2 record must bind to " \
                                             'a Tier-1 report identity and to the bytes that were read'
            end
            return if a.dig('stage_transition', 'applied') == false

            raise SubmitCore::SubmitError, 'stage_transition.applied must be false: Tier-2 proposes, the ' \
                                           'rubric\'s human sign-off applies'
          end
        end
      end
    end
  end
end
