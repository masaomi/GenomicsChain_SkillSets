# frozen_string_literal: true

require_relative 'rule'
require_relative 'failure'
require_relative 'gate'
require_relative 'budget'

module GenomicsChainProv
  module Reach
    # (2) and (4): which places are asked, in what order, and how the answers
    # are counted. The asking itself is a prober passed in, with two steps:
    #
    #   prober.target(category, locator) -> the host the locator names.
    #     Reads the locator only; raises Refused for what the gate refuses
    #     without resolving (scheme, userinfo, port, IP literal, a kind of
    #     locator there is no way to check).
    #   prober.ask(category, locator, host, seconds:) -> a bucket, or raises
    #     Failure / Refused. Passes every URL through Gate.check.
    #
    # The budget, the breaker, the host class and the counting stay here, so
    # every kind of locator is held to them the same way.
    module Observation
      module_function

      # Every item per category, in the adapter's order; a position in these
      # lists is the customer's per-item handle (design (3)). An item that
      # names no locator is nil: it counts in `items` and reads not_checkable,
      # but it is not a distinct locator.
      # workflow_commit's locator is {'repository', 'commit'}: the commit is
      # looked for in that repository's refs.
      # @param np [NormalizedProvenance]
      def items(np)
        wf = np.workflow
        rt = np.runtime
        {
          'workflow_repository' => wf ? [text(wf['repository'])] : [],
          'workflow_commit' => wf ? [commit_locator(wf)] : [],
          'runtime' => rt ? [text(rt['locator'])] : [],
          'containers' => Array(np.containers).map { |c| text(c['ref']) },
          # software_total − containers_total, as on the prov record (design
          # (2)): the adapter's own container rule, bco.rb `software_of` → 114.
          'software' => Array(np.software).reject { |s| container?(s) }.map { |s| text(s['locator']) }
        }
      end

      # @return [Hash] 'counts' per category (for the record) and 'items',
      #   per category the bucket of every item in order (for the submitting
      #   customer's response only — never the record, never a log)
      def observe(np, prober:, budget:)
        all = items(np)
        counts = {}
        per_item = {}
        CATEGORIES.each do |cat|
          list = all.fetch(cat)
          answers = list.compact.uniq.sort_by { |l| key(l) }.to_h { |l| [l, answer(cat, l, prober, budget)] }
          counts[cat] = tally(list, answers)
          per_item[cat] = list.map { |l| l.nil? ? 'not_checkable' : answers.fetch(l)['bucket'] }
        end
        { 'counts' => counts, 'items' => per_item }
      end

      # Design (3): a dry run asks nothing and resolves nothing. Per category,
      # the items, the distinct locators, and how many of those the gate
      # refuses on their face.
      def dry_run(np, prober:)
        all = items(np)
        CATEGORIES.to_h do |cat|
          list = all.fetch(cat)
          distinct = list.compact.uniq
          refused = distinct.count { |l| refused_on_its_face?(cat, l, prober) }
          [cat, { 'items' => list.length, 'distinct' => distinct.length, 'refused_without_resolving' => refused }]
        end
      end

      def host_class(host)
        PUBLIC_REGISTRY_HOSTS.include?(host) ? 'public_registry' : 'other_host'
      end

      def answer(cat, locator, prober, budget)
        host = Gate.normalise_host(Reach.guard { prober.target(cat, locator) })
        cls = host_class(host)
        return { 'bucket' => 'not_attempted', 'host_class' => cls } if budget.admit(host, cls)

        { 'bucket' => asked(cat, locator, host, prober, budget), 'host_class' => cls }
      rescue Refused, Failure
        { 'bucket' => 'not_checkable', 'host_class' => nil }
      end

      # A timeout under less than a full query's time is the observation's
      # budget running out, not the place: not_attempted, and no failure of
      # the host (review r1). Any other end of a query, a refusal included,
      # breaks a run of failures.
      def asked(cat, locator, host, prober, budget)
        seconds = budget.request_seconds
        bucket = Reach.guard { prober.ask(cat, locator, host, seconds: seconds) }
        budget.record(host, failed: false)
        BUCKETS.include?(bucket) ? bucket : 'error'
      rescue Failure => e
        return 'not_attempted' if e.code == 'timeout' && seconds < REQUEST_SECONDS

        budget.record(host, failed: Reach.breaker_failure?(e))
        Reach.bucket_for(e)
      rescue Refused
        budget.record(host, failed: false)
        'not_checkable'
      end

      def tally(list, answers)
        out = { 'items' => list.length, 'distinct' => answers.length }
        BUCKETS.each { |b| out[b] = SPLIT_BUCKETS.include?(b) ? HOST_CLASSES.to_h { |c| [c, 0] } : 0 }
        answers.each_value do |a|
          if SPLIT_BUCKETS.include?(a['bucket'])
            out[a['bucket']][a['host_class']] += 1
          else
            out[a['bucket']] += 1
          end
        end
        out
      end

      def refused_on_its_face?(cat, locator, prober)
        Reach.guard { prober.target(cat, locator) }
        false
      rescue Refused, Failure
        true
      end

      def container?(software)
        Adapters::Bco.oci_ref?(software['locator']) || (software['name'].nil? && software['locator'].nil?)
      end

      def commit_locator(workflow)
        repo = text(workflow['repository'])
        commit = text(workflow['commit'])
        repo && commit ? { 'repository' => repo, 'commit' => commit } : nil
      end

      def text(value)
        value.is_a?(String) && !value.strip.empty? ? value : nil
      end

      def key(locator)
        locator.is_a?(Hash) ? "#{locator['repository']} #{locator['commit']}" : locator
      end
    end
  end
end
