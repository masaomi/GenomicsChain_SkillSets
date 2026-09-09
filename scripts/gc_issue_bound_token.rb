#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gc_issue_bound_token — issue a Bearer token bound to an operator's pubkey.
#
# The submit tools fail closed unless the Bearer carries pubkey_hash and it
# equals sha256(operator.pubkey). TokenStore#create accepts pubkey_hash, but
# neither the token_manage tool nor the CLI exposes it, so this is the one
# place that sets it. Run it on the anchor, inside the container, with
# KAIROS_DATA_DIR set (the store path is resolved from it):
#
#   sudo docker exec -e KAIROS_DATA_DIR=/app/.kairos kairos-meeting-place \
#     ruby /tmp/gc-skillsets/scripts/gc_issue_bound_token.rb \
#       --user masaomi --pubkey ed25519:<from gc_submit_client --keygen> --expires 7d
#
# Prints the raw token ONCE. It is never stored in clear.

require 'json'
require 'digest'
require 'optparse'
require 'kairos_mcp'
require 'kairos_mcp/auth/token_store'

opts = { role: 'member', expires: '7d', issued_by: 'gc_issue_bound_token' }
OptionParser.new do |o|
  o.on('--user USER') { |v| opts[:user] = v }
  o.on('--pubkey PUBKEY', 'ed25519:<urlsafe base64>') { |v| opts[:pubkey] = v }
  o.on('--role ROLE', %w[owner member guest]) { |v| opts[:role] = v }
  o.on('--expires DUR', '90d / 24h / 7d / never') { |v| opts[:expires] = v }
  o.on('--token-store PATH') { |v| opts[:store] = v }
end.parse!

abort '--user and --pubkey are required' unless opts[:user] && opts[:pubkey]
abort 'pubkey must look like ed25519:<base64>' unless opts[:pubkey] =~ /\Aed25519:[A-Za-z0-9_\-+\/=]+\z/

store = KairosMcp::Auth::TokenStore.new(opts[:store])
entry = store.create(
  user: opts[:user], role: opts[:role], issued_by: opts[:issued_by],
  expires_in: opts[:expires], pubkey_hash: Digest::SHA256.hexdigest(opts[:pubkey])
)

puts JSON.pretty_generate(
  'user' => entry['user'], 'role' => entry['role'], 'expires_at' => entry['expires_at'],
  'pubkey_hash' => entry['pubkey_hash'], 'raw_token' => entry['raw_token'],
  'note' => 'raw_token is shown once; the store keeps only its hash'
)
