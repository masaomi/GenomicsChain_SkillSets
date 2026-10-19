# frozen_string_literal: true

module GenomicsChainProv
  # Reach — the anchor asks the places a bundle names for its environment
  # whether they still answer, and records a dated count (design v0.1.15,
  # §6.3, rule `gc-reachability-0.1`). Nothing is fetched: the answer is the
  # place's own, given to the anchor, on that day, from the anchor's network.
  #
  # This file holds the rule's fixed parts. Changing any value here changes
  # what the rule means, so it changes RULE_VERSION.
  module Reach
    RULE_VERSION = 'gc-reachability-0.1'

    # (4) One answer per distinct locator. digest_match and exists are counted
    # per host class (a place the customer runs can say "exists" to anything);
    # the other five are not.
    BUCKETS = %w[digest_match exists access_denied not_found error not_attempted not_checkable].freeze
    SPLIT_BUCKETS = %w[digest_match exists].freeze
    HOST_CLASSES = %w[public_registry other_host].freeze

    # (4) The class is decided by the host the bundle wrote (operator,
    # 2026-10-18). A token realm or a redirect target is chosen by that host,
    # not by the customer, so it does not change the class. docker.io stands
    # for registry-1.docker.io, as a reference without a registry does.
    PUBLIC_REGISTRY_HOSTS = %w[
      registry-1.docker.io docker.io quay.io ghcr.io public.ecr.aws mcr.microsoft.com registry.gitlab.com
      community.wave.seqera.io github.com gitlab.com bitbucket.org codeberg.org api.anaconda.org
    ].freeze

    # (2) as revised (operator, 2026-10-18): the few entries Tier 3 cannot do
    # without come before the many container images, so a budget that runs
    # out cuts images, not the repository. Within a category, locators are
    # asked in dictionary order.
    CATEGORIES = %w[workflow_repository workflow_commit runtime containers software].freeze

    # (5) Time, size and budgets. Queries inside one observation run one at a
    # time, so (5)'s "at most two at once per host" holds by construction.
    REQUEST_SECONDS = 10
    OBSERVATION_SECONDS = 60
    MAX_DISTINCT = 200
    PER_HOST = { 'public_registry' => 100, 'other_host' => 20 }.freeze
    BREAKER_FAILURES = 3
    MAX_REDIRECTS = 3
    HEADER_BYTES = 64 * 1024
    JSON_BYTES = 1024 * 1024
    ADVERTISEMENT_BYTES = 8 * 1024 * 1024
    ANCHOR_CONCURRENT_OBSERVATIONS = 2
    KEY_CONCURRENT_OBSERVATIONS = 1
    KEY_DAILY_OBSERVATIONS = 24
  end
end
