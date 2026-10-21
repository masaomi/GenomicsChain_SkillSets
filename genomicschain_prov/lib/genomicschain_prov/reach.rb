# frozen_string_literal: true

# The anchor's reachability observation (design v0.1.15, §6.3). Required by
# the anchor-side tool, never by genomicschain_prov.rb: the customer's side
# of this package reads bundles and touches nothing. The gem loads every
# tools/*.rb on every node, so this code is loaded there too; it reaches the
# network only when the anchor's tool runs an observation.
require_relative 'reach/rule'
require_relative 'reach/special_ranges'
require_relative 'reach/failure'
require_relative 'reach/gate'
require_relative 'reach/budget'
require_relative 'reach/observation'
require_relative 'reach/reference'
require_relative 'reach/resolver'
require_relative 'reach/transport'
require_relative 'reach/http'
require_relative 'reach/prober'
require_relative 'reach/signed_params'
