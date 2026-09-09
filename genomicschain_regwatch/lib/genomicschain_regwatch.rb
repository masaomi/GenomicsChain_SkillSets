# frozen_string_literal: true

# genomicschain_regwatch — the watching tier.
#
# Everything this package exists for was learned in one survey (2026-09-01, ten
# independent primary-source passes). Three findings from that survey are built
# into the design rather than written down beside it:
#
#   1. Dated and undated obligations behave differently and must not share a
#      mechanism. "IVDR class C notified-body agreement, 2026-09-26" is a
#      countdown. "EU GMP Annex 22 finalisation" has NO date at all — EMA is
#      still weighing the consultation outcome — so the only way to notice it
#      is to watch the bytes.
#
#   2. A source that cannot be fetched is a FINDING, not a pass. EUR-Lex,
#      ich.org and edps.europa.eu each blocked automated retrieval during the
#      survey. A watcher that reports those as "unchanged" is worse than no
#      watcher, because it converts a blind spot into a green light. This is
#      the same discipline as Tier-3 reporting `no_target_declared` as a
#      complete result instead of quietly scoring a pass.
#
#   3. The scanner reports; the operator judges. Whether a diff is material is
#      a judgement, and the context that produced the finding must not be the
#      one that rules on it (INV-5; and independently, BSI C5:2026 OPS-33.01AC
#      grades "provider verifies in its own service and returns only the
#      result" as the weakest of four attestation arrangements). So this tool
#      emits changed / unchanged / unreachable and stops.
require 'digest'

# Constants first, requires after: Fetcher builds its user-agent string from
# VERSION at class-definition time, so the constant has to exist before the
# file that reads it is loaded.
module GenomicsChainRegwatch
  VERSION = '0.1.0'

  # Bumped when the meaning of a status changes, so a stored baseline written
  # under an older rule set is recognisably not comparable.
  SCAN_RULES_VERSION = 'regwatch-scan-0.1.0'

  # The five statuses a watched source can be in. Deliberately small, and
  # deliberately without a "probably fine".
  #
  # `not_checked` exists because the first version of this package did not have
  # it, and an offline pass consequently reported every source as `unchanged` —
  # committing, in its own offline path, precisely the error the package was
  # built to prevent. Nothing was fetched, so nothing was compared, so the only
  # honest status is that no check happened.
  STATUSES = %w[unchanged changed unreachable new not_checked].freeze

  class Error < StandardError; end
end

require_relative 'genomicschain_regwatch/watchlist'
require_relative 'genomicschain_regwatch/fetcher'
require_relative 'genomicschain_regwatch/scanner'
require_relative 'genomicschain_regwatch/renderer'
