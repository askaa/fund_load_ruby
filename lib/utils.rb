# frozen_string_literal: true
require "date"  # важно для Date/ISO недели

module Utils
  module_function

  def parse_money_cents(str)
    s = str.delete("$").strip
    (Float(s) * 100).round
  end

  def iso_week_key(t)
    d = t.getutc.to_date
    format("%04d-W%02d", d.cwyear, d.cweek)
  end

  def date_key(t)
    t.getutc.strftime("%Y-%m-%d")
  end

  def monday?(t)
    t.getutc.wday == 1
  end

  def prime?(s)
    n = Integer(s) rescue nil
    return false unless n && n > 1
    (2..Math.sqrt(n)).none? { |i| n % i == 0 }
  end
end
