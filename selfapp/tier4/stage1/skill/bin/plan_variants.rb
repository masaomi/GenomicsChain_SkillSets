#!/usr/bin/env ruby
# frozen_string_literal: true

# SYNTHETIC -- FICTIONAL STUDY. GenomicsChain self-application demonstration.
#
# Helper of run.rb, run in its own process so that parameter code never
# shares a process with the computation. Loads the make_variants.rb named by
# parameter 1 and calls MakeVariants.plan on the spec read from stdin, rooted
# at ROOT. MakeVariants.plan computes every variant in memory and writes
# nothing; MakeVariants.write and MakeVariants.run are not called (the loaded
# file runs its own CLI only when it is the program, which it is not here).
#
#   ruby plan_variants.rb MAKE_VARIANTS ROOT < SPEC_JSON
#
# Prints {variant id => {relpath => sha256 of the planned bytes}} as JSON,
# naming only the files a variant changes.

require 'digest'
require 'json'

make_variants, root = ARGV
abort 'usage: plan_variants.rb MAKE_VARIANTS ROOT < SPEC_JSON' unless make_variants && root
ARGV.clear
spec = JSON.parse($stdin.read)
load File.expand_path(make_variants)
planned = MakeVariants.plan(spec, File.expand_path(root))
puts JSON.generate(planned.to_h { |id, _out_dir, changed| [id, changed.transform_values { |t| Digest::SHA256.hexdigest(t) }] })
