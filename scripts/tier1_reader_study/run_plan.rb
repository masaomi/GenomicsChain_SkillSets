# frozen_string_literal: true

# Run the registered plan: 153 reads in five parallel streams (opus55, fable51,
# sonnet55, astra, composer25). Within a stream reads run one at a time, in the
# registered order: repetition, then document (P, V0, V1), then effort
# (low, medium, high, xhigh). Each read is its own process (run_read.rb), so no
# state passes from one read to the next. Already-recorded reads are skipped,
# which makes an interrupted run resumable without re-running anything.
#
#   ruby scripts/tier1_reader_study/run_plan.rb [--list]

require_relative 'study'

S = ReaderStudy

def plan
  streams = S.configs.group_by { |c| c[:stream] }
  streams.transform_values do |cfgs|
    (1..3).flat_map do |rep|
      S::DOC_ORDER.flat_map { |doc| cfgs.map { |c| { doc: doc, config: c[:id], rep: rep } } }
    end
  end
end

if ARGV.include?('--list')
  plan.each { |stream, reads| reads.each_with_index { |r, i| puts "#{stream}\t#{i + 1}\t#{r[:doc]}\t#{r[:config]}\t#{r[:rep]}" } }
  puts "total #{plan.values.sum(&:size)}"
  exit
end

S.manifest # refuses to start before the freeze
runner = File.join(__dir__, 'run_read.rb')
threads = plan.map do |stream, reads|
  Thread.new do
    log = File.join(S::OUT, "plan_#{stream}.log")
    reads.each do |r|
      done = File.join(S::OUT, 'reads', r[:doc], r[:config], "rep#{r[:rep]}", 'record.json')
      next if File.exist?(done)

      out, = Open3.capture2e('ruby', runner, r[:doc], r[:config], r[:rep].to_s)
      File.open(log, 'a') { |f| f.puts("#{S.now} #{out.strip}") }
    end
  end
end
threads.each(&:join)
puts 'plan complete'
