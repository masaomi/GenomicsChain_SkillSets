#!/usr/bin/env ruby
# frozen_string_literal: true

# Resolve the pins the self-application generator needs (design §4.3; the first
# step of S2): each tool's version and build, the per-rule container by registry
# digest, and the base image by digest. Nothing is written from memory — every
# value comes from a conda-lock explicit lock or from a registry answer, and the
# pins file records where each came from.
#
#   ruby scripts/selfapp/resolve_pins.rb --lock resolve-linux-64.lock \
#        --base-image mambaorg/micromamba:2.9.0-debian13 --out selfapp/pins_v0.json
#
# Read-only network use: quay.io (biocontainers tags) and hub.docker.com (tags).

require 'digest'
require 'json'
require 'net/http'
require 'optparse'
require 'time'
require 'uri'

TOOLS = %w[fastp salmon r-base bioconductor-tximport bioconductor-deseq2 multiqc snakemake-minimal].freeze
# Each rule's per-tool image (the Apptainer route). Both R rules need only
# their own package: tximport.R writes a plain list, deseq2.R reads it.
RULE_TOOL = {
  'trim' => 'fastp', 'salmon_index' => 'salmon', 'salmon_quant' => 'salmon',
  'tximport' => 'bioconductor-tximport', 'deseq2' => 'bioconductor-deseq2', 'report' => 'multiqc'
}.freeze

def get_json(url)
  res = Net::HTTP.get_response(URI(url))
  raise "#{url}: HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

  JSON.parse(res.body)
end

def tools_from_lock(text)
  TOOLS.to_h do |t|
    line = text.lines.find { |l| l =~ %r{/#{Regexp.escape(t)}-\d[^-/]*-[^-/]+\.(conda|tar\.bz2)#} }
    raise "#{t} not in the lock" unless line

    url = line.split('#').first
    version, build = File.basename(url).sub(/\.(conda|tar\.bz2)\z/, '').delete_prefix("#{t}-").split('-', 2)
    [t, { 'version' => version, 'build' => build, 'package_url' => url }]
  end
end

# biocontainers tags an image "<version>--<build>". Some releases appear only
# under the bare version; that tag is taken, still by digest, and recorded as
# not confirming the build (fastp 1.3.7 on 2026-09-30).
def biocontainer(tool, version, build)
  ["#{version}--#{build}", version].each do |tag|
    url = "https://quay.io/api/v1/repository/biocontainers/#{tool}/tag/?specificTag=#{tag}&onlyActiveTags=true"
    hit = get_json(url)['tags'].find { |t| t['name'] == tag }
    next unless hit

    entry = { 'ref' => "docker://quay.io/biocontainers/#{tool}:#{tag}@#{hit['manifest_digest']}", 'source' => url }
    entry['note'] = "tag names no build; the lock's build #{build} is not confirmed by it" if tag == version
    return entry
  end
  raise "quay.io/biocontainers/#{tool}: neither #{version}--#{build} nor #{version} found"
end

def docker_hub(image)
  repo, tag = image.split(':', 2)
  repo = "library/#{repo}" unless repo.include?('/')
  url = "https://hub.docker.com/v2/repositories/#{repo}/tags/#{tag}"
  digest = get_json(url).fetch('digest')
  { 'ref' => "docker.io/#{repo}:#{tag}@#{digest}", 'source' => url }
end

opts = {}
OptionParser.new do |o|
  o.on('--lock PATH') { |v| opts[:lock] = v }
  o.on('--base-image REF') { |v| opts[:base] = v }
  o.on('--out PATH') { |v| opts[:out] = v }
end.parse!
abort 'usage: resolve_pins.rb --lock LOCK --base-image REPO:TAG --out PINS.json' unless opts.values_at(:lock, :base, :out).all?
abort "#{opts[:out]} exists; pins are resolved once — move it aside deliberately" if File.exist?(opts[:out])

lock = File.read(opts[:lock])
tools = tools_from_lock(lock)
containers = RULE_TOOL.to_h do |rule, tool|
  t = tools.fetch(tool)
  [rule, biocontainer(tool, t['version'], t['build'])]
end
base = docker_hub(opts[:base])

pins = {
  'kind' => 'resolved for V0',
  'resolved_at' => Time.now.utc.iso8601,
  'resolved_from' => {
    'lock_sha256' => Digest::SHA256.hexdigest(lock),
    'lock_input_hash' => lock[/^# input_hash: (\h+)$/, 1],
    'lock_platform' => lock[/^# platform: (\S+)$/, 1],
    'base_image_source' => base['source'],
    'container_sources' => containers.transform_values { |c| c['source'] },
    'container_notes' => containers.transform_values { |c| c['note'] }.compact
  },
  'tools' => tools.transform_values { |t| t.slice('version', 'build') },
  'base_image' => base['ref'],
  'rule_containers' => containers.transform_values { |c| c['ref'] }
}
File.write(opts[:out], "#{JSON.pretty_generate(pins)}\n")
puts JSON.pretty_generate(pins.slice('tools', 'base_image', 'rule_containers'))
