# frozen_string_literal: true
require_relative "utils"
require_relative "limit_tracker"
require_relative "models"

class FundProcessor
  include Utils

  DAILY_LIMIT_CENTS  = 5_000_00
  WEEKLY_LIMIT_CENTS = 20_000_00
  DAILY_COUNT_LIMIT  = 3
  PRIME_AMOUNT_MAX   = 9_999_00

  def initialize(enable_prime_rule: true, enable_monday_rule: true)
    @limits = LimitTracker.new
    @enable_prime_rule  = enable_prime_rule
    @enable_monday_rule = enable_monday_rule
  end

  def process_line(line)
    load = Models::LoadAttempt.from_json_line(line)
    date_key = Utils.date_key(load.time)
    week_key = Utils.iso_week_key(load.time)

    effective_amount = load.amount_cents
    effective_amount *= 2 if @enable_monday_rule && Utils.monday?(load.time)

    prime_defer = nil
    if @enable_prime_rule && Utils.prime?(load.id)
      return decline_json(load) if @limits.prime_taken_today?(date_key)
      return decline_json(load) if effective_amount > PRIME_AMOUNT_MAX
      prime_defer = date_key
    end

    return decline_json(load) if @limits.day_total_cents(load.customer_id, date_key) + effective_amount > DAILY_LIMIT_CENTS
    return decline_json(load) if @limits.week_total_cents(load.customer_id, week_key) + effective_amount > WEEKLY_LIMIT_CENTS
    return decline_json(load) if @limits.day_count(load.customer_id, date_key) >= DAILY_COUNT_LIMIT

    @limits.record!(load.customer_id, date_key, week_key, effective_amount)
    @limits.mark_prime_today!(prime_defer) if prime_defer
    accept_json(load)
  end

  private

  def accept_json(load)
    %Q({"id":"#{load.id}","customer_id":"#{load.customer_id}","accepted":true})
  end

  def decline_json(load)
    %Q({"id":"#{load.id}","customer_id":"#{load.customer_id}","accepted":false})
  end
end
