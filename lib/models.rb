# frozen_string_literal: true
require "json"
require "time"

module Models
  LoadAttempt = Struct.new(:id, :customer_id, :amount_cents, :time) do
    def self.from_json_line(line)
      h = JSON.parse(line)
      amount_cents = Utils.parse_money_cents(h.fetch("load_amount"))
      t = Time.iso8601(h.fetch("time"))
      new(h.fetch("id").to_s, h.fetch("customer_id").to_s, amount_cents, t)
    end
  end
end