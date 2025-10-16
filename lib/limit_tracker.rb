# frozen_string_literal: true

class LimitTracker
    Daily  = Struct.new(:total_cents, :count)
    Weekly = Struct.new(:total_cents)
  
    def initialize
      @daily_totals  = Hash.new { |h,k| h[k] = Hash.new { |hh,dk| hh[dk] = Daily.new(0,0) } }
      @weekly_totals = Hash.new { |h,k| h[k] = Hash.new { |hh,wk| hh[wk] = Weekly.new(0) } }
      @prime_seen_by_date = Hash.new { |h,dk| h[dk] = false }
    end
  
    def day_total_cents(customer_id, date_key) 
        @daily_totals[customer_id][date_key].total_cents
    end

    def day_count(customer_id, date_key)        
        @daily_totals[customer_id][date_key].count
    end

    def week_total_cents(customer_id, week_key) 
        @weekly_totals[customer_id][week_key].total_cents
    end
  
    def record!(customer_id, date_key, week_key, amount_cents)
      d = @daily_totals[customer_id][date_key]
      w = @weekly_totals[customer_id][week_key]
      d.total_cents += amount_cents
      d.count       += 1
      w.total_cents += amount_cents
    end
  
    def prime_taken_today?(date_key) 
        @prime_seen_by_date[date_key]
    end

    def mark_prime_today!(date_key)
        @prime_seen_by_date[date_key] = true
    end
end