# frozen_string_literal: true

# Canonical b1_manifest_hash for Tier-1 Stage-1 reports (report_schema v0.2.5).
#
# Pre-scoring provenance digest, fixed before scoring from four identity fields.
# Stage-2 appends "stage2" as a fifth field (see stage2_assessor_prompt.md).
#
# Normalization (2026-07-29): survey_v1_1 had two assessor conventions — bare
# concatenation vs pipe-delimited. Calibration n=40 was already pipe-delimited;
# pipe-delimited is the canonical convention going forward.
require 'digest'

module B1ManifestHash
  FIELDS = %i[canonical_id rubric_hash assessor_id assessed_at].freeze
  DELIMITER = '|'

  module_function

  def precommit_string(report, stage: nil)
    parts = [
      report.dig('canonical_id', 'value'),
      report['rubric_hash'],
      report['assessor_id'],
      report['assessed_at']
    ]
    stage ||= 'stage2' if %w[stage2-code-verified].include?(report['funnel_stage'].to_s) ||
                          %w[stage2-code-verified].include?(report.dig('assessor_stack', 'stage').to_s)
    parts << stage.to_s if stage
    parts.join(DELIMITER)
  end

  def compute(report, stage: nil)
    Digest::SHA256.hexdigest(precommit_string(report, stage: stage))
  end

  def stored(report)
    report.dig('manifest', 'b1_manifest_hash')
  end

  def matches?(report, stage: nil)
    stored(report) == compute(report, stage: stage)
  end
end
