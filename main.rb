# frozen_string_literal: true
require_relative "lib/fund_processor"

input_path = ARGV[0] || "input.txt"
processor = FundProcessor.new(enable_prime_rule: true, enable_monday_rule: true)

File.foreach(input_path) do |line|
  line = line.strip
  next if line.empty?
  puts processor.process_line(line)
end