# frozen_string_literal: true

# v0.1.15 R2, the questions (design §6.3 (4)): reading locators, the OCI,
# git, https and conda queries, redirects and the token realm through the
# gate. The resolver and the transport are replaced; nothing leaves the
# machine. The one git advertisement is real bytes, captured from GitHub on
# 2026-10-18 (fixtures/git, sha256 dad64529…).
#
# Run: ruby -Ilib -Itest test/reach_prober_test.rb
require 'minitest/autorun'
require 'json'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'
require 'genomicschain_prov/reach'

class ReachProberTest < Minitest::Test
  R = GenomicsChainProv::Reach
  Ref = R::Reference
  Res = R::Transport::Response
  ADVERT = File.binread(File.expand_path('fixtures/git/nfcore_demo_info_refs_20261018.bin', __dir__))
  INDEX = 'application/vnd.oci.image.index.v1+json'
  D = "sha256:#{'a' * 64}"

  # Every host resolves to a public address unless listed.
  class Resolver
    def initialize(table = {}) = (@table = table)
    def addresses(host) = @table.fetch(host, ['93.184.215.14'])
  end

  # [method, host + request_target] -> Response, or an Exception to raise,
  # or an Array of those answered in turn.
  class Transport
    attr_reader :calls

    def initialize(script) = (@script = script) && (@calls = [])

    def exchange(pinned, method:, headers:, body_cap:)
      key = [method, "#{pinned.host}#{pinned.request_target}"]
      @calls << [key, headers, body_cap]
      v = @script.fetch(key) { raise "unscripted #{key.inspect}" }
      v = v.shift if v.is_a?(Array)
      raise v if v.is_a?(Exception)

      v
    end
  end

  def res(status, headers = {}, body = nil)
    Res.new(status: status, headers: headers.to_h { |k, v| [k.downcase, Array(v)] }, body: body)
  end

  def prober(script, resolver: Resolver.new)
    @transport = Transport.new(script)
    R::Prober.new(http_for: ->(_deadline) { R::Http.new(resolver: resolver, transport: @transport) })
  end

  def ask(script, category, locator, **kw)
    p = prober(script, **kw)
    R.guard { p.ask(category, locator, p.target(category, locator), seconds: 10) }
  end

  def failure(code)
    e = assert_raises(R::Failure) { yield }
    assert_equal code, e.code
  end

  # --- reading locators ----------------------------------------------------------

  def test_oci_references_are_read_by_the_distribution_grammar
    o = Ref.oci('ubuntu')
    assert_equal %w[registry-1.docker.io library/ubuntu latest], [o.registry, o.name, o.tag]
    o = Ref.oci('docker://Docker.io/biocontainers/star:2.7.10b')
    assert_equal %w[registry-1.docker.io biocontainers/star 2.7.10b], [o.registry, o.name, o.tag]
    o = Ref.oci("quay.io/biocontainers/samtools:1.19--h50ea8bc_0@#{D}")
    assert_equal ['quay.io', 'biocontainers/samtools', nil, D], [o.registry, o.name, o.tag, o.digest]
    o = Ref.oci('community.wave.seqera.io/library/cowpy:1.1.5--3db457ae1977a273')
    assert_equal ['community.wave.seqera.io', 'library/cowpy'], [o.registry, o.name]
    # Review r1: one registry is one host however its authority is written.
    { 'quay.io:443/a/b:1' => 'quay.io', 'Quay.IO./a/b:1' => 'quay.io', 'reg.example.org.:443/x:1' => 'reg.example.org',
      'Docker.io:443/library/ubuntu' => 'registry-1.docker.io' }.each do |l, host|
      assert_equal host, Ref.host(Ref.oci(l)), l
    end
  end

  def test_locators_that_name_no_place_to_ask_are_refused
    ['shub://x/y', 'oci://x/y:1', '/scratch/img.sif', '', 'Quay.io/Bad/Name:1', 'localhost:5000/x:1',
     'reg.example.org:5000/x:1', "x@sha256:#{'A' * 64}", 'x@md5:abc', '10.0.0.1/x:1',
     'quay.io/a/b:1?x=y', 'quay.io/a/b:1+2', "quay.io/a/b:#{'t' * 129}", 'quay.io/a/b:-1',
     'victim.example?1/a:1', 'quay.io#/a/b:1'].each do |l|
      assert_raises(R::Refused, l) { Ref.read('containers', l) }
    end
    ['samtools', '/usr/bin/sh', 'http://example.org/x', 'ftp://example.org/x', 'defaults::x==1',
     'bioconda::samtools=1.17', 'bioconda::samtools>=1.17', 'bioconda::samtools', 'bioconda::..==..',
     'bioconda::samtools==.', '..::samtools==1.19'].each do |l|
      assert_raises(R::Refused, l) { Ref.read('software', l) }
    end
    ['https://github.com/a/b?x=1', 'https://github.com/a/b#x', 'https://github.com/', 'git@github.com:a/b'].each do |l|
      assert_raises(R::Refused, l) { Ref.read('workflow_repository', l) }
    end
    assert_raises(R::Refused) { Ref.read('workflow_commit', { 'repository' => 'https://github.com/a/b', 'commit' => '555d145' }) }
  end

  def test_runtime_and_software_take_urls_and_full_conda_specs
    assert_equal 'https://github.com/x/y/releases/tag/v1', Ref.read('runtime', 'https://github.com/x/y/releases/tag/v1').url
    c = Ref.read('software', 'bioconda::samtools==1.19')
    assert_equal %w[bioconda samtools 1.19], [c.channel, c.name, c.version]
  end

  # --- OCI -------------------------------------------------------------------------

  def test_a_digest_answered_back_is_a_digest_match
    url = "quay.io/v2/biocontainers/samtools/manifests/#{D}"
    script = { ['HEAD', url] => res(200, 'Content-Type' => INDEX, 'Docker-Content-Digest' => D) }
    assert_equal 'digest_match', ask(script, 'containers', "quay.io/biocontainers/samtools@#{D}")
  end

  def test_a_tag_or_a_digest_not_echoed_is_exists_and_another_digest_is_no_answer
    tag = 'quay.io/v2/a/b/manifests/1'
    assert_equal 'exists', ask({ ['HEAD', tag] => res(200, 'Content-Type' => INDEX, 'Docker-Content-Digest' => D) },
                               'containers', 'quay.io/a/b:1')
    dig = "quay.io/v2/a/b/manifests/#{D}"
    assert_equal 'exists', ask({ ['HEAD', dig] => res(200, 'Content-Type' => INDEX) }, 'containers', "quay.io/a/b@#{D}")
    other = res(200, 'Content-Type' => INDEX, 'Docker-Content-Digest' => "sha256:#{'b' * 64}")
    failure('refused') { ask({ ['HEAD', dig] => other }, 'containers', "quay.io/a/b@#{D}") }
  end

  def test_an_answer_that_is_not_a_manifest_is_not_a_registrys_answer
    url = 'quay.io/v2/a/b/manifests/1'
    failure('refused') { ask({ ['HEAD', url] => res(200, 'Content-Type' => 'text/html') }, 'containers', 'quay.io/a/b:1') }
  end

  def test_the_anonymous_token_is_fetched_from_the_realm_and_sent_back
    url = 'registry-1.docker.io/v2/library/ubuntu/manifests/22.04'
    challenge = 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/ubuntu:pull"'
    token_path = 'auth.docker.io/token?service=registry.docker.io&scope=repository%3Alibrary%2Fubuntu%3Apull'
    script = { ['HEAD', url] => [res(401, 'WWW-Authenticate' => challenge), res(200, 'Content-Type' => INDEX)],
               ['GET', token_path] => res(200, {}, +'{"token":"tok123"}') }
    assert_equal 'exists', ask(script, 'containers', 'ubuntu:22.04')
    assert_equal ['HEAD', 'GET', 'HEAD'], @transport.calls.map { |c| c[0][0] }
    assert_equal 'Bearer tok123', @transport.calls.last[1]['Authorization']
    assert_equal R::JSON_BYTES, @transport.calls[1][2]
  end

  def test_a_denied_token_or_a_second_401_is_access_denied_and_404_is_not_found
    url = 'ghcr.io/v2/nf-core/x/manifests/1'
    ch = { 'WWW-Authenticate' => 'Bearer realm="https://ghcr.io/token",service="ghcr.io",scope="repository:nf-core/x:pull"' }
    script = { ['HEAD', url] => res(401, ch), ['GET', 'ghcr.io/token?service=ghcr.io&scope=repository%3Anf-core%2Fx%3Apull'] => res(403) }
    assert_equal 'access_denied', R.bucket_for(assert_raises(R::Failure) { ask(script, 'containers', 'ghcr.io/nf-core/x:1') })
    assert_equal 'not_found', R.bucket_for(assert_raises(R::Failure) { ask({ ['HEAD', url] => res(404) }, 'containers', 'ghcr.io/nf-core/x:1') })
    # Review r1: a token, then 401 again, is still a denial; a realm that
    # answers 404 is no answer about the image, never its not_found.
    token_url = 'ghcr.io/token?service=ghcr.io&scope=repository%3Anf-core%2Fx%3Apull'
    script = { ['HEAD', url] => [res(401, ch), res(401, ch)], ['GET', token_url] => res(200, {}, +'{"token":"t"}') }
    assert_equal 'access_denied', R.bucket_for(assert_raises(R::Failure) { ask(script, 'containers', 'ghcr.io/nf-core/x:1') })
    assert_equal 3, @transport.calls.length
    script = { ['HEAD', url] => res(401, ch), ['GET', token_url] => res(404) }
    assert_equal 'error', R.bucket_for(assert_raises(R::Failure) { ask(script, 'containers', 'ghcr.io/nf-core/x:1') })
    # Review r2 N2: a realm 5xx is still an error, and still a breaker failure.
    script = { ['HEAD', url] => res(401, ch), ['GET', token_url] => res(503) }
    e = assert_raises(R::Failure) { ask(script, 'containers', 'ghcr.io/nf-core/x:1') }
    assert_equal ['http_503', 'error', true], [e.code, R.bucket_for(e), R.breaker_failure?(e)]
    # A challenge that names no realm, or not Bearer, leaves nothing to ask.
    [{ 'WWW-Authenticate' => 'Bearer service="ghcr.io"' }, { 'WWW-Authenticate' => 'Basic realm="x"' }].each do |h|
      e = assert_raises(R::Failure) { ask({ ['HEAD', url] => res(401, h) }, 'containers', 'ghcr.io/nf-core/x:1') }
      assert_equal 'access_denied', R.bucket_for(e)
      assert_equal 1, @transport.calls.length
    end
  end

  # Acceptance test (iii): a realm or a redirect that points inside is refused
  # by the gate, and nothing is sent there.
  def test_a_realm_or_redirect_to_a_private_address_is_refused_without_a_second_request
    url = 'reg.example.org/v2/a/b/manifests/1'
    ch = { 'WWW-Authenticate' => 'Bearer realm="https://inside.example.org/token",service="x"' }
    resolver = Resolver.new('inside.example.org' => ['169.254.169.254'])
    assert_raises(R::Refused) { ask({ ['HEAD', url] => res(401, ch) }, 'containers', 'reg.example.org/a/b:1', resolver: resolver) }
    assert_equal 1, @transport.calls.length

    moved = res(302, 'Location' => 'https://inside.example.org/blob')
    assert_raises(R::Refused) { ask({ ['HEAD', 'example.org/tool.tar.gz'] => moved }, 'software', 'https://example.org/tool.tar.gz', resolver: resolver) }
    assert_equal 1, @transport.calls.length
    assert_raises(R::Refused) do
      ask({ ['HEAD', 'example.org/t'] => res(302, 'Location' => 'http://example.org/t') }, 'software', 'https://example.org/t')
    end
  end

  def test_redirects_and_the_realm_share_three_hops
    script = { ['HEAD', 'example.org/0'] => res(302, 'Location' => '/1'), ['HEAD', 'example.org/1'] => res(302, 'Location' => '/2'),
               ['HEAD', 'example.org/2'] => res(302, 'Location' => '/3'), ['HEAD', 'example.org/3'] => res(200) }
    assert_equal 'exists', ask(script, 'software', 'https://example.org/0')
    script[['HEAD', 'example.org/3']] = res(302, 'Location' => '/4')
    failure('refused') { ask(script, 'software', 'https://example.org/0') }
    assert_equal 4, @transport.calls.length
  end

  def test_the_realm_counts_as_a_hop
    url = 'reg.example.org/v2/a/b/manifests/1'
    script = { ['HEAD', url] => res(302, 'Location' => '/v2/a/b/manifests/1?r=1'),
               ['HEAD', "#{url}?r=1"] => res(302, 'Location' => '/v2/a/b/manifests/1?r=2'),
               ['HEAD', "#{url}?r=2"] => res(302, 'Location' => '/v2/a/b/manifests/1?r=3'),
               ['HEAD', "#{url}?r=3"] => res(401, 'WWW-Authenticate' => 'Bearer realm="https://reg.example.org/token"') }
    failure('refused') { ask(script, 'containers', 'reg.example.org/a/b:1') }
    assert_equal 4, @transport.calls.length
  end

  def test_a_challenge_without_a_scope_asks_for_pull_on_the_name_and_a_bad_token_is_refused
    url = 'reg.example.org/v2/a/b/manifests/1'
    tok = 'reg.example.org/token?scope=repository%3Aa%2Fb%3Apull'
    ch = { 'WWW-Authenticate' => 'Bearer realm="https://reg.example.org/token"' }
    script = { ['HEAD', url] => [res(401, ch), res(200, 'Content-Type' => INDEX)], ['GET', tok] => res(200, {}, +'{"access_token":"t"}') }
    assert_equal 'exists', ask(script, 'containers', 'reg.example.org/a/b:1')
    script = { ['HEAD', url] => res(401, ch), ['GET', tok] => res(200, {}, +"{\"token\":\"t\\r\\nX-Evil: 1\"}") }
    failure('refused') { ask(script, 'containers', 'reg.example.org/a/b:1') }
    script = { ['HEAD', url] => res(401, ch), ['GET', tok] => res(200, {}, +'not json') }
    failure('refused') { ask(script, 'containers', 'reg.example.org/a/b:1') }
  end

  def test_a_credential_is_not_carried_to_another_host
    http = R::Http.new(resolver: Resolver.new, transport: (t = Transport.new(
      ['HEAD', 'a.example.org/x'] => res(302, 'Location' => 'https://b.example.org/y'), ['HEAD', 'b.example.org/y'] => res(200)
    )))
    http.request('https://a.example.org/x', method: 'HEAD', headers: { 'Authorization' => 'Bearer t', 'Accept' => 'z' })
    assert_equal({ 'Authorization' => 'Bearer t', 'Accept' => 'z' }, t.calls[0][1])
    assert_equal({ 'Accept' => 'z' }, t.calls[1][1])
  end

  # --- git -------------------------------------------------------------------------

  def git(status: 200, type: 'application/x-git-upload-pack-advertisement', body: ADVERT)
    { ['GET', 'github.com/nf-core/demo/info/refs?service=git-upload-pack'] => res(status, { 'Content-Type' => type }, body) }
  end

  def commit(c) = { 'repository' => 'https://github.com/nf-core/demo', 'commit' => c }

  def test_the_real_advertisement_parses
    refs = R::Prober::Advertisement.parse(ADVERT)
    assert_equal '671a0726cb489b22636d90b7c7352baed473790d', refs['refs/heads/master']
    assert_equal refs['HEAD'], refs['refs/heads/master']
    assert_equal '32893afef8076a03a2767a020b3f0cab2e0b40b2', refs['refs/tags/1.2.0']
    assert_equal 'exists', ask(git, 'workflow_repository', 'https://github.com/nf-core/demo')
  end

  def test_a_commit_at_a_tip_matches_and_one_that_is_not_cannot_be_checked
    assert_equal 'digest_match', ask(git, 'workflow_commit', commit('671A0726CB489B22636D90B7C7352BAED473790D'))
    # The nf-core fixture's own commit: not at any tip on 2026-10-18.
    assert_equal 'not_checkable', ask(git, 'workflow_commit', commit('555d145b9e701c012f53996a2f17efb2daff5fe7'))
  end

  def test_a_ref_name_is_looked_for_under_heads_and_tags
    assert_equal 'exists', ask(git, 'workflow_commit', commit('1.2.0'))
    assert_equal 'exists', ask(git, 'workflow_commit', commit('dev'))
    assert_equal 'not_found', ask(git, 'workflow_commit', commit('9.9.9'))
  end

  def test_a_peeled_tag_matches
    oid = 'b' * 40
    tag = 'c' * 40
    lines = ["# service=git-upload-pack\n", nil, "#{'d' * 40} HEAD\0multi_ack\n", "#{tag} refs/tags/v1\n", "#{oid} refs/tags/v1^{}\n", nil]
    body = lines.map { |l| l.nil? ? '0000' : format('%04x', l.bytesize + 4) + l }.join
    assert_equal 'digest_match', ask(git(body: body), 'workflow_commit', commit(oid))
  end

  def test_what_is_not_an_advertisement_is_no_answer
    failure('refused') { ask(git(type: 'text/html'), 'workflow_repository', 'https://github.com/nf-core/demo') }
    failure('refused') { ask(git(body: ADVERT.byteslice(30..)), 'workflow_repository', 'https://github.com/nf-core/demo') }
    failure('refused') { ask(git(body: ADVERT.byteslice(0, ADVERT.bytesize - 4)), 'workflow_repository', 'https://github.com/nf-core/demo') }
    failure('refused') { ask(git(body: "#{ADVERT}zz"), 'workflow_repository', 'https://github.com/nf-core/demo') }
    # A line whose length runs past the end of the body.
    failure('refused') { ask(git(body: "#{ADVERT.byteslice(0, ADVERT.bytesize - 4)}0040#{'e' * 40} x\n0000"), 'workflow_repository', 'https://github.com/nf-core/demo') }
    assert_equal 'access_denied', R.bucket_for(assert_raises(R::Failure) { ask(git(status: 401), 'workflow_repository', 'https://github.com/nf-core/demo') })
  end

  def test_an_advertisement_over_eight_megabytes_is_not_attempted
    script = { ['GET', 'github.com/nf-core/demo/info/refs?service=git-upload-pack'] => R::Failure.new('too_large') }
    assert_equal 'not_attempted', ask(script, 'workflow_repository', 'https://github.com/nf-core/demo')
    assert_equal R::ADVERTISEMENT_BYTES, @transport.calls.first[2]
  end

  # --- https and conda ---------------------------------------------------------------

  def test_https_head_then_a_one_byte_get_never_read
    assert_equal 'exists', ask({ ['HEAD', 'example.org/t.tgz'] => res(200) }, 'software', 'https://example.org/t.tgz')
    script = { ['HEAD', 'example.org/t.tgz'] => res(405), ['GET', 'example.org/t.tgz'] => res(206) }
    assert_equal 'exists', ask(script, 'software', 'https://example.org/t.tgz')
    assert_equal({ 'Range' => 'bytes=0-0' }, @transport.calls.last[1])
    assert_nil @transport.calls.last[2]
    script = { ['HEAD', 'example.org/t.tgz'] => res(501), ['GET', 'example.org/t.tgz'] => res(200) }
    assert_equal 'exists', ask(script, 'software', 'https://example.org/t.tgz')
    assert_equal 'GET', @transport.calls.last[0][0]
    assert_equal 'not_found', R.bucket_for(assert_raises(R::Failure) { ask({ ['HEAD', 'example.org/t.tgz'] => res(404) }, 'software', 'https://example.org/t.tgz') })
  end

  def test_conda_asks_the_release
    script = { ['HEAD', 'api.anaconda.org/release/bioconda/samtools/1.19'] => res(200) }
    assert_equal 'exists', ask(script, 'software', 'bioconda::samtools==1.19')
    script = { ['HEAD', 'api.anaconda.org/release/bioconda/samtools/0.0'] => res(404) }
    assert_equal 'not_found', R.bucket_for(assert_raises(R::Failure) { ask(script, 'software', 'bioconda::samtools==0.0') })
  end

  # Review r1: the prober as the tool builds it, with no test transport,
  # hands the gate its options; the anchor's own name is refused before
  # anything is resolved or sent.
  def test_the_default_prober_passes_the_gate_options
    p = R::Prober.new(gate: { own_names: ['anchor.example.org'] })
    e = assert_raises(R::Refused) { p.ask('containers', 'anchor.example.org/x/y:1', 'anchor.example.org', seconds: 1) }
    assert_equal 'own_host', e.reason
  end

  # The prober plugged into the observation: hosts and classes come from the
  # locator, the anchor's own name is refused by the gate.
  def test_the_prober_in_an_observation
    n = GenomicsChainProv::NormalizedProvenance.new(
      workflow: { 'repository' => 'https://github.com/nf-core/demo', 'commit' => '671a0726cb489b22636d90b7c7352baed473790d' },
      containers: [{ 'ref' => 'quay.io/a/b:1' }, { 'ref' => 'anchor.example.org/x/y:1' }],
      software: [{ 'name' => 'b', 'locator' => 'quay.io/a/b:1' }, { 'name' => 'y', 'locator' => 'anchor.example.org/x/y:1' }]
    )
    script = git.merge(['HEAD', 'quay.io/v2/a/b/manifests/1'] => res(200, 'Content-Type' => INDEX))
    t = Transport.new(script)
    p = R::Prober.new(http_for: lambda { |_d|
      R::Http.new(resolver: Resolver.new, transport: t, gate: { own_names: ['anchor.example.org'] })
    })
    out = R::Observation.observe(n, prober: p, budget: R::Budget.new)
    assert_equal({ 'public_registry' => 1, 'other_host' => 0 }, out['counts']['workflow_commit']['digest_match'])
    assert_equal({ 'public_registry' => 1, 'other_host' => 0 }, out['counts']['containers']['exists'])
    assert_equal 1, out['counts']['containers']['not_checkable']
  end
end
