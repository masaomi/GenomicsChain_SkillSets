# frozen_string_literal: true

# v0.1.15 R1 (design §6.3 (2), (4), (5)): the gate, the seven buckets, the
# budgets and the error coding, with the resolver and the prober replaced.
# Nothing here opens a socket or resolves a name.
#
# Run: ruby -Ilib -Itest test/reach_test.rb
require 'minitest/autorun'
require 'json'
require 'csv'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'
require 'genomicschain_prov/reach'

class ReachTest < Minitest::Test
  R = GenomicsChainProv::Reach
  Gate = R::Gate
  Obs = R::Observation
  NP = GenomicsChainProv::NormalizedProvenance
  IANA = File.expand_path('fixtures/iana', __dir__)
  NFCORE = File.expand_path('fixtures/nfcore_demo_1_2_0/bco.json', __dir__)

  # host -> answers; a host not listed does not resolve.
  class FakeResolver
    attr_reader :asked

    def initialize(table) = (@table = table) && (@asked = [])

    def addresses(host)
      @asked << host
      v = @table.fetch(host, [])
      raise v if v.is_a?(Exception)

      v
    end
  end

  # locator -> what ask does: a bucket String, or an Exception to raise.
  # target reads the host from "https://host/..." or "host/..." the way a
  # registry reference names it; :refuse makes target refuse.
  class FakeProber
    attr_reader :asked

    def initialize(script = {}, refuse: [])
      @script = script
      @refuse = refuse
      @asked = []
    end

    def target(_cat, locator)
      raise R::Refused.new('scheme') if @refuse.include?(locator)

      text = locator.is_a?(Hash) ? locator['repository'] : locator
      url = text.start_with?('https://') ? text : "https://#{text}"
      Gate.parse(url).first
    end

    def ask(_cat, locator, _host, seconds:)
      @asked << [locator, seconds]
      v = @script.fetch(locator, 'exists')
      raise v if v.is_a?(Exception)

      v
    end
  end

  PUBLIC = { 'registry.example.org' => ['93.184.215.14', '2606:2800:21f:cb07:6820:80da:af6b:8b2c'] }.freeze

  def check(url, table = PUBLIC, **kw)
    Gate.check(url, resolver: FakeResolver.new(table), **kw)
  end

  def refused(reason)
    e = yield
    flunk "expected refusal #{reason}, got #{e.inspect}"
  rescue R::Refused => e
    assert_equal reason, e.reason
  end

  def np(containers: [], software: [], workflow: nil, runtime: nil)
    NP.new(workflow: workflow, runtime: runtime, software: software,
           containers: containers.map { |c| { 'ref' => c, 'name' => 'x', 'stage' => 1 } })
  end

  def containers_only(refs) = np(containers: refs, software: refs.map { |r| { 'name' => 'x', 'locator' => r } })

  def observe(n, prober, budget = R::Budget.new) = Obs.observe(n, prober: prober, budget: budget)

  # --- the gate (acceptance test (iii)) ------------------------------------------

  def test_a_public_name_passes_and_is_pinned_to_its_first_answer
    pinned = check('https://Registry.Example.org./v2/x/manifests/latest')
    assert_equal 'registry.example.org', pinned.host
    assert_equal '93.184.215.14', pinned.address
    assert_equal 443, pinned.port
    assert_equal '/v2/x/manifests/latest', pinned.request_target
    assert_equal '/?q=1', check('https://registry.example.org?q=1').request_target
  end

  def test_every_address_of_the_design_list_is_refused_written_in_the_url
    %w[0.0.0.0 127.0.0.1 100.100.100.200 169.254.169.254 10.0.0.1 198.18.0.1
       [::ffff:169.254.169.254] [64:ff9b::a9fe:a9fe] [2002:a9fe:a9fe::] [::1] [fd00::1]].each do |h|
      refused('ip_literal') { check("https://#{h}/") }
    end
  end

  def test_every_address_of_the_design_list_is_refused_behind_a_name
    %w[0.0.0.0 127.0.0.1 100.100.100.200 169.254.169.254 10.0.0.1 198.18.0.1
       ::ffff:169.254.169.254 64:ff9b::a9fe:a9fe 2002:a9fe:a9fe:: ::1 fd00::1].each do |a|
      refused('address') { check('https://evil.example.org/', { 'evil.example.org' => [a] }) }
    end
  end

  def test_ip_literals_in_other_notations_are_refused_before_resolving
    resolver = FakeResolver.new({})
    %w[127.1 0x7f000001 0177.0.0.1 2130706433 a.b.0x7f.1].each do |h|
      refused('ip_literal') { Gate.check("https://#{h}/", resolver: resolver) }
    end
    assert_empty resolver.asked
  end

  def test_one_private_answer_among_public_ones_refuses_the_name
    table = { 'mixed.example.org' => ['93.184.215.14', 'fd00::1'] }
    refused('address') { check('https://mixed.example.org/', table) }
  end

  def test_nat64_carrying_a_public_address_passes_and_carrying_a_private_one_does_not
    assert check('https://n.example.org/', { 'n.example.org' => ['64:ff9b::5db8:d70e'] })
    refused('address') { check('https://n.example.org/', { 'n.example.org' => ['64:ff9b::a00:1'] }) }
    refused('address') { check('https://n.example.org/', { 'n.example.org' => ['::a9fe:a9fe'] }) }
  end

  def test_teredo_and_local_nat64_are_refused_whatever_they_carry
    refused('address') { check('https://t.example.org/', { 't.example.org' => ['2001:0:5db8:d70e::1'] }) }
    refused('address') { check('https://t.example.org/', { 't.example.org' => ['64:ff9b:1::5db8:d70e'] }) }
  end

  def test_multicast_and_broadcast_are_refused
    %w[224.0.0.1 239.255.255.250 255.255.255.255 ff02::1].each do |a|
      refused('address') { check('https://m.example.org/', { 'm.example.org' => [a] }) }
    end
  end

  def test_the_url_form_userinfo_port_and_scheme_are_refused
    refused('userinfo') { check('https://user:pw@registry.example.org/') }
    refused('port') { check('https://registry.example.org:6379/') }
    refused('port') { check('https://registry.example.org:/') }
    assert check('https://registry.example.org:443/')
    refused('scheme') { check('http://registry.example.org/') }
    refused('scheme') { check('file:///etc/passwd') }
    refused('form') { check('registry.example.org/x') }
    refused('form') { check("https://registry.example.org/a b") }
    refused('form') { check('https://rëgistry.example.org/') }
    refused('host_form') { check('https://localhost/') }
    refused('host_form') { check('https:///x') }
    refused('host_form') { check('https://-bad.example.org/') }
  end

  def test_the_anchors_own_name_and_addresses_and_the_denylist_are_refused
    refused('own_host') { check('https://Anchor.Example.org./', own_names: ['anchor.example.org']) }
    table = { 'self.example.org' => ['93.184.215.14'] }
    refused('address') { check('https://self.example.org/', table, own_addresses: ['93.184.215.14']) }
    refused('address') { check('https://self.example.org/', table, denylist: ['93.184.215.0/24']) }
    refused('address') do
      check('https://self.example.org/', { 'self.example.org' => ['::ffff:93.184.215.14'] }, own_addresses: ['93.184.215.14'])
    end
  end

  def test_a_name_that_does_not_resolve_is_refused_like_the_gate_refuses
    refused('unresolvable') { check('https://nowhere.example.org/', {}) }
  end

  # (5) step 4: the table is what the IANA CSVs give, every block whose
  # Globally Reachable is not True.
  def test_the_special_ranges_are_derived_from_the_iana_csvs
    from_csv = lambda do |file|
      CSV.read(File.join(IANA, file), headers: true).flat_map do |r|
        next [] if r['Globally Reachable'].to_s.sub(/\s*\[\d+\]\z/, '').strip == 'True'

        r['Address Block'].split(',').map { |b| b.sub(/\s*\[\d+\]\z/, '').strip }
      end
    end
    assert_equal from_csv.call('iana-ipv4-special-registry-1.csv'), R::SpecialRanges::IPV4
    assert_equal from_csv.call('iana-ipv6-special-registry-1.csv'), R::SpecialRanges::IPV6
  end

  # --- what is asked, and in what order (design (2)) ------------------------------

  def test_items_from_the_nfcore_fixture
    n = GenomicsChainProv::Adapters::Bco.parse(File.read(NFCORE))
    items = Obs.items(n)
    assert_equal ['https://github.com/nf-core/demo'], items['workflow_repository']
    assert_equal [{ 'repository' => 'https://github.com/nf-core/demo',
                    'commit' => '555d145b9e701c012f53996a2f17efb2daff5fe7' }], items['workflow_commit']
    assert_equal ['https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6'], items['runtime']
    assert_equal [], items['containers']
    assert_equal [], items['software']
  end

  # A commit needs its repository to be looked for in, and a repository with
  # no commit leaves nothing to look for: either way the item has no locator.
  def test_a_commit_item_needs_both_the_repository_and_the_commit
    only_repo = Obs.items(NP.new(workflow: { 'repository' => 'https://github.com/a/b', 'commit' => nil }))
    assert_equal [nil], only_repo['workflow_commit']
    only_commit = Obs.items(NP.new(workflow: { 'repository' => ' ', 'commit' => 'c' * 40 }))
    assert_equal [[nil], [nil]], [only_commit['workflow_repository'], only_commit['workflow_commit']]
  end

  def test_software_excludes_the_containers_and_counts_like_the_record
    sw = [{ 'name' => 'star', 'locator' => 'quay.io/biocontainers/star:2.7.10b--h9ee0642_0' },
          { 'name' => 'samtools', 'locator' => 'https://example.org/samtools-1.19.tar.bz2' },
          { 'name' => nil, 'locator' => nil },
          { 'name' => 'local', 'locator' => nil }]
    n = NP.new(software: sw, containers: [{ 'ref' => sw[0]['locator'] }, { 'ref' => nil }])
    items = Obs.items(n)
    assert_equal [sw[0]['locator'], nil], items['containers']
    assert_equal ['https://example.org/samtools-1.19.tar.bz2', nil], items['software']
    assert_equal n.software.length - n.containers.length, items['software'].length
  end

  def test_categories_go_repository_first_and_locators_in_dictionary_order
    n = NP.new(workflow: { 'repository' => 'https://github.com/a/b', 'commit' => 'c' * 40 },
               runtime: { 'locator' => 'https://github.com/r/t' },
               containers: [{ 'ref' => 'quay.io/z:1' }, { 'ref' => 'quay.io/a:1' }],
               software: [{ 'name' => 'z', 'locator' => 'quay.io/z:1' }, { 'name' => 'a', 'locator' => 'quay.io/a:1' },
                          { 'name' => 't', 'locator' => 'https://example.org/t' }])
    prober = FakeProber.new
    observe(n, prober)
    assert_equal ['https://github.com/a/b', { 'repository' => 'https://github.com/a/b', 'commit' => 'c' * 40 },
                  'https://github.com/r/t', 'quay.io/a:1', 'quay.io/z:1', 'https://example.org/t'],
                 prober.asked.map(&:first)
  end

  # --- the seven buckets and the host class (acceptance test (iv)) ------------------

  def test_each_answer_lands_in_its_bucket_and_the_buckets_sum_to_distinct
    script = {
      'quay.io/dm:1' => 'digest_match', 'other.example.org/dm:1' => 'digest_match',
      'quay.io/ex:1' => 'exists', 'other.example.org/ex:1' => 'exists',
      'quay.io/u401:1' => R::Failure.new('http_401'), 'quay.io/u403:1' => R::Failure.new('http_403'),
      'quay.io/nf:1' => R::Failure.new('http_404'), 'quay.io/nf2:1' => 'not_found',
      'quay.io/to:1' => R::Failure.new('timeout'), 'ghcr.io/rl:1' => R::Failure.new('http_429'),
      'ghcr.io/tls:1' => R::Failure.new('tls'), 'ghcr.io/big:1' => 'not_attempted',
      'ghcr.io/dns:1' => R::Failure.new('dns'), 'ghcr.io/gate:1' => R::Refused.new('address'),
      'ghcr.io/odd:1' => 'nonsense'
    }
    refs = script.keys + ['oci://refused:1', 'quay.io/dm:1']
    out = observe(containers_only(refs), FakeProber.new(script, refuse: ['oci://refused:1']))
    c = out['counts']['containers']
    assert_equal 17, c['items']
    assert_equal 16, c['distinct']
    assert_equal({ 'public_registry' => 1, 'other_host' => 1 }, c['digest_match'])
    assert_equal({ 'public_registry' => 1, 'other_host' => 1 }, c['exists'])
    assert_equal 2, c['access_denied']
    assert_equal 2, c['not_found']
    assert_equal 4, c['error'] # timeout, 429, tls, an answer that is not a bucket
    assert_equal 1, c['not_attempted']
    assert_equal 3, c['not_checkable'] # dns, the gate on ask, refused by target
    sum = R::BUCKETS.sum { |b| c[b].is_a?(Hash) ? c[b].values.sum : c[b] }
    assert_equal c['distinct'], sum
  end

  def test_items_without_a_locator_count_as_items_only_and_read_not_checkable
    out = observe(containers_only(['quay.io/a:1', nil, 'quay.io/a:1']), FakeProber.new)
    c = out['counts']['containers']
    assert_equal [3, 1, 1], [c['items'], c['distinct'], c['exists']['public_registry']]
    assert_equal 0, c['not_checkable']
    assert_equal %w[exists not_checkable exists], out['items']['containers']
  end

  def test_the_same_locator_is_asked_once
    prober = FakeProber.new
    observe(containers_only(['quay.io/a:1'] * 5), prober)
    assert_equal 1, prober.asked.length
  end

  # --- budgets (acceptance test (iv)) ----------------------------------------------

  def test_at_most_two_hundred_distinct_locators_are_asked
    refs = (1..100).map { |i| "quay.io/q#{i}:1" } + (1..100).map { |i| "ghcr.io/g#{i}:1" } +
           (1..5).map { |i| "public.ecr.aws/e#{i}:1" }
    prober = FakeProber.new
    c = observe(containers_only(refs), prober)['counts']['containers']
    assert_equal 200, prober.asked.length
    assert_equal 5, c['not_attempted']
  end

  def test_per_host_caps_are_a_hundred_public_and_twenty_other
    refs = (1..105).map { |i| "quay.io/q#{i}:1" } + (1..25).map { |i| "own.example.org/o#{i}:1" }
    c = observe(containers_only(refs), FakeProber.new)['counts']['containers']
    assert_equal 100, c['exists']['public_registry']
    assert_equal 20, c['exists']['other_host']
    assert_equal 10, c['not_attempted']
  end

  def test_three_failures_in_a_row_stop_a_host_and_an_answer_resets_the_count
    script = { 'own.example.org/a1:1' => R::Failure.new('timeout'), 'own.example.org/a2:1' => R::Failure.new('http_503'),
               'own.example.org/a3:1' => 'exists', 'own.example.org/a4:1' => R::Failure.new('timeout'),
               'own.example.org/a5:1' => R::Failure.new('http_502'), 'own.example.org/a6:1' => R::Failure.new('timeout'),
               'own.example.org/a7:1' => 'exists', 'quay.io/b:1' => 'exists' }
    prober = FakeProber.new(script)
    out = observe(containers_only(script.keys), prober)
    assert_equal %w[error error exists error error error not_attempted exists], out['items']['containers']
    refute_includes prober.asked.map(&:first), 'own.example.org/a7:1'
  end

  # Each code three times in a row (review r1: alternating them reset the
  # count either way, so counting one of them went unnoticed).
  def test_404_and_429_do_not_trip_the_breaker
    script = (1..7).to_h { |i| ["own.example.org/n#{i}:1", i < 7 ? R::Failure.new(i < 4 ? 'http_404' : 'http_429') : 'exists'] }
    out = observe(containers_only(script.keys), FakeProber.new(script))
    assert_equal %w[not_found not_found not_found error error error exists], out['items']['containers']
  end

  def test_a_refusal_between_failures_breaks_the_run
    script = { 'own.example.org/a1:1' => R::Failure.new('timeout'), 'own.example.org/a2:1' => R::Refused.new('unresolvable'),
               'own.example.org/a3:1' => R::Failure.new('timeout'), 'own.example.org/a4:1' => R::Refused.new('unresolvable'),
               'own.example.org/a5:1' => R::Failure.new('timeout'), 'own.example.org/a6:1' => 'exists' }
    out = observe(containers_only(script.keys), FakeProber.new(script))
    assert_equal %w[error not_checkable error not_checkable error exists], out['items']['containers']
  end

  # Review r1: the query the observation's budget cut short is the anchor's
  # limit, not the place's failure.
  def test_a_timeout_under_a_cut_budget_is_not_attempted
    now = 0.0
    budget = R::Budget.new(clock: -> { now })
    now = 52.0
    prober = FakeProber.new
    prober.define_singleton_method(:ask) do |_cat, loc, _host, seconds:|
      @asked << [loc, seconds]
      now += seconds
      raise R::Failure.new('timeout')
    end
    out = observe(containers_only(%w[own.example.org/a:1 own.example.org/b:1]), prober, budget)
    assert_equal [8.0], prober.asked.map(&:last)
    assert_equal %w[not_attempted not_attempted], out['items']['containers']
  end

  # The resolver's share of the deadline is split across the nameservers,
  # which Resolv asks one after another (review r1): three silent ones must
  # not stretch a two-second deadline to six.
  def test_the_resolver_keeps_to_the_deadline_with_silent_nameservers
    silent = UDPSocket.new.tap { |s| s.bind('127.0.0.1', 0) }
    config = { nameserver_port: [['127.0.0.1', silent.addr[1]]] * 3 }
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    resolver = R::Resolver.new(deadline: t + 2.0, config: config)
    begin
      resolver.addresses('registry.example.org')
    rescue R::Failure
      nil
    end
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - t, :<, 2.6
  ensure
    silent&.close
  end

  def test_the_observation_ends_at_sixty_seconds_and_each_query_gets_at_most_ten
    now = 0.0
    budget = R::Budget.new(clock: -> { now })
    prober = FakeProber.new
    prober.define_singleton_method(:ask) do |cat, loc, host, seconds:|
      @asked << [loc, seconds]
      now += 25
      'exists'
    end
    out = observe(containers_only(%w[quay.io/a:1 quay.io/b:1 quay.io/c:1 quay.io/d:1]), prober, budget)
    assert_equal [10.0, 10.0, 10.0], prober.asked.map(&:last)
    assert_equal %w[exists exists exists not_attempted], out['items']['containers']
  end

  def test_the_last_query_gets_only_what_is_left_of_the_sixty_seconds
    now = 0.0
    budget = R::Budget.new(clock: -> { now })
    now = 55.0
    assert_in_delta 5.0, budget.request_seconds
  end

  def test_anchor_wide_admission
    now = 0.0
    adm = R::Admission.new(clock: -> { now })
    busy = ->(key) { assert_raises(R::Admission::Busy) { adm.hold(key) {} }.reason }

    adm.hold('k1') do
      assert_equal 'key', busy.call('k1')
      adm.hold('k2') { assert_equal 'anchor', busy.call('k3') }
    end
    24.times { adm.hold('k4') {} }
    assert_equal 'daily', busy.call('k4')
    now += 86_401
    adm.hold('k4') {}
    assert_raises(RuntimeError) { adm.hold('k5') { raise 'inside' } }
    adm.hold('k5') {} # the failed one was left, not held
  end

  # --- nothing leaks (acceptance test (vi)) ------------------------------------------

  def test_the_guard_drops_the_message_and_the_cause
    [[SocketError.new('getaddrinfo: secret-host.example.org'), 'dns'],
     [Errno::ECONNREFUSED.new('connect(2) for secret-host.example.org port 443'), 'refused'],
     [Timeout::Error.new('execution expired secret-host.example.org'), 'timeout'],
     [OpenSSL::SSL::SSLError.new('hostname "secret-host.example.org" does not match'), 'tls'],
     [NoMethodError.new("undefined method for #<URI::HTTPS https://secret-host.example.org/>"), 'refused']].each do |err, code|
      e = assert_raises(R::Failure) { R.guard { raise err } }
      assert_equal code, e.code
      assert_equal code, e.message
      assert_nil e.cause
    end
    e = assert_raises(R::Refused) { R.guard { raise R::Refused.new('address') } }
    assert_nil e.cause
  end

  def test_the_observation_carries_no_locator_or_host
    script = { 'secret-host.example.org/x:1' => SocketError.new('getaddrinfo: secret-host.example.org') }
    out = observe(containers_only(script.keys + ['quay.io/secret-image:1']), FakeProber.new(script))
    refute_match(/secret/, JSON.generate(out))
  end

  def test_a_dry_run_asks_nothing
    prober = FakeProber.new({}, refuse: ['oci://x:1'])
    out = Obs.dry_run(containers_only(['quay.io/a:1', 'quay.io/a:1', 'oci://x:1', '10.0.0.1/x:1', nil]), prober: prober)
    assert_equal({ 'items' => 5, 'distinct' => 3, 'refused_without_resolving' => 2 }, out['containers'])
    assert_empty prober.asked
  end
end
