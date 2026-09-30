#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate the fictional RNA-seq subject (design §4, unit S1).
#
#   ruby selfapp/generator/bin/generate.rb --pins PINS.json --lock LOCK --out selfapp [--seed 20260929]
#
# Writes <out>/synthetic_rnaseq_v1/ (the subject, with generator_manifest.json)
# and <out>/synthetic_truth_v1.json (the answer key, outside the subject).
# The pins file supplies tool versions, the base image and the per-rule
# containers; the lock is the conda-lock output copied to envs/rnaseq.lock.

require 'json'
require 'optparse'
require_relative '../lib/synthetic_rnaseq'

opts = { seed: 20_260_929 }
OptionParser.new do |o|
  o.on('--seed N', Integer) { |v| opts[:seed] = v }
  o.on('--pins PATH') { |v| opts[:pins] = v }
  o.on('--lock PATH') { |v| opts[:lock] = v }
  o.on('--out DIR') { |v| opts[:out] = v }
  o.on('--reads-per-sample N', Integer) { |v| opts[:reads_per_sample] = v }
end.parse!

abort 'usage: generate.rb --pins PINS.json --lock LOCK --out DIR [--seed N] [--reads-per-sample N]' unless opts[:pins] && opts[:lock] && opts[:out]

pins = JSON.parse(File.read(opts[:pins], encoding: 'UTF-8'))
manifest = SyntheticRnaseq::Generator.new(
  seed: opts[:seed], pins: pins, lock: File.binread(opts[:lock]), out: opts[:out], reads_per_sample: opts[:reads_per_sample]
).run

puts "subject #{File.join(opts[:out], SyntheticRnaseq::SUBJECT_DIR)}"
puts "  files #{manifest[:files].length}, subject_tree_sha256 #{manifest[:subject_tree_sha256]}"
puts "  generator #{manifest[:generator][:tree_sha256]}, pins #{manifest[:pins_kind]} #{manifest[:pins_sha256][0, 12]}"
puts "truth   #{File.join(opts[:out], SyntheticRnaseq::TRUTH_FILE)} (outside the subject)"
