# frozen_string_literal: true

# The environment the GenomicsChain SkillSets are run and tested in.
# Versions are exact: they are the versions the installed checker resolved on
# 2026-09-29 (S0 of docs/design/self_application_design_v0_1.md), so a rebuild
# from this file loads the same code. json and psych are default gems; they are
# listed because canonical JSON and the Tier-2 toolchain record depend on them.

source 'https://rubygems.org'

ruby file: '.ruby-version'

gem 'kairos-chain', '3.87.1'

gem 'ed25519', '1.4.0'
gem 'json', '2.9.1'
gem 'json-schema', '6.2.0'
gem 'json_schemer', '2.5.0'
gem 'psych', '5.2.2'

group :test do
  gem 'minitest', '5.25.4'
end
