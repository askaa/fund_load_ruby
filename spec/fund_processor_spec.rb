# frozen_string_literal: true
require "spec_helper"

def line(id:, cid:, amount:, time:)
  %Q({"id":"#{id}","customer_id":"#{cid}","load_amount":"$#{amount}","time":"#{time}"})
end

RSpec.describe FundProcessor do
  # общий процессор: все правила включены
  let(:proc) { FundProcessor.new(enable_prime_rule: true, enable_monday_rule: true) }

  describe "happy flow" do
    it "accepts up to 3 loads per day within daily limits" do
      t = "2025-10-14T10:00:00Z" # Tue
      3.times do |i|
        out = proc.process_line(line(id: (100+i).to_s, cid: "u1", amount: "100.00", time: t))
        expect(out).to include('"accepted":true')
      end
    end

    it "independent customers do not affect each other" do
      t = "2025-10-14T10:00:00Z"
      out1 = proc.process_line(line(id: "1", cid: "A", amount: "3000.00", time: t))
      out2 = proc.process_line(line(id: "2", cid: "B", amount: "3000.00", time: t))
      expect(out1).to include('"accepted":true')
      expect(out2).to include('"accepted":true')
    end
  end

  describe "daily count limit (<= 3 per customer per day)" do
    it "declines the 4th load in the same day" do
      t = "2025-10-14T10:00:00Z"
      3.times { |i| expect(proc.process_line(line(id: (10+i).to_s, cid: "c1", amount: "1.00", time: t))).to include('"accepted":true') }
      out = proc.process_line(line(id: "99", cid: "c1", amount: "1.00", time: t))
      expect(out).to include('"accepted":false')
    end
  end

  describe "daily amount limit ($5,000 per day per customer)" do
    it "accepts exactly 5000 total" do
      t = "2025-10-14T09:00:00Z"
      expect(proc.process_line(line(id: "1", cid: "c2", amount: "3000.00", time: t))).to include('"accepted":true')
      expect(proc.process_line(line(id: "2", cid: "c2", amount: "2000.00", time: t))).to include('"accepted":true') # total = 5000 OK
    end

    it "declines when total exceeds 5000" do
      t = "2025-10-14T09:00:00Z"
      expect(proc.process_line(line(id: "3", cid: "c3", amount: "4999.99", time: t))).to include('"accepted":true')
      expect(proc.process_line(line(id: "4", cid: "c3", amount: "0.02",   time: t))).to include('"accepted":false') # 5000.01
    end
  end

  describe "weekly amount limit without Monday x2 ($20,000 per ISO-week per customer)" do
    # для weekly-тестов отключаем Monday ×2, чтобы проверить именно недельную сумму
    let(:proc) { FundProcessor.new(enable_prime_rule: true, enable_monday_rule: false) }

    it "accepts up to 20k in the same week, declines beyond" do
      # 5 дней * 4000 = 20k — ок; лишнее в той же ISO-неделе — decline
      base = Time.utc(2025, 10, 13) # Mon
      (0..4).each do |d|
        t = (base + (d * 86_400)).iso8601
        out = proc.process_line(line(id: "w#{d}", cid: "c4", amount: "4000.00", time: t))
        expect(out).to include('"accepted":true')
      end
      # суббота той же недели
      t6 = (base + 5 * 86_400).iso8601
      out = proc.process_line(line(id: "w5", cid: "c4", amount: "1.00", time: t6))
      expect(out).to include('"accepted":false')
    end

    it "handles ISO week/year boundary correctly" do
        # выключаем Monday ×2 в этом блоке выше через let(:proc)
        # Дни: Чт 2020-12-31 → Пт 2021-01-01 → Сб → Вс — всё одна ISO-неделя (53)
        days = %w[2020-12-31 2021-01-01 2021-01-02 2021-01-03]
        days.each_with_index do |d, i|
          t = "#{d}T10:00:00Z"
          out = proc.process_line(line(id: "b#{i}", cid: "c5", amount: "5000.00", time: t))
          expect(out).to include('"accepted":true') # 4 × $5k = $20k за ISO-неделю — ок
        end
      
        # Ещё 1 цент в ту же ISO-неделю → превышение $20k → decline
        extra = "2021-01-03T12:00:00Z"
        out = proc.process_line(line(id: "bX", cid: "c5", amount: "0.01", time: extra))
        expect(out).to include('"accepted":false')
      end
      
  end

  describe "weekly limit with Monday ×2 effect" do
    let(:proc) { FundProcessor.new(enable_prime_rule: true, enable_monday_rule: true) }
  
    it "counts Monday as doubled toward the weekly total" do
      base = Time.utc(2025, 10, 13) # Monday, ISO week 42
  
      # Пн: 2000 → eff = 4000 (в рамках дневного лимита)
      expect(proc.process_line(line(id: "wmon", cid: "w9", amount: "2000.00", time: base.iso8601)))
        .to include('"accepted":true')
  
      # Вт–Пт: по 4000 → суммарно +16000
      (1..4).each do |d|
        t = (base + d * 86_400).iso8601
        expect(proc.process_line(line(id: "w#{d}", cid: "w9", amount: "4000.00", time: t)))
          .to include('"accepted":true')
      end
  
      # Итого eff за неделю: 4000 + 16000 = 20000 → ровно лимит, ок
      # Ещё 1 цент в той же ISO-неделе → превышение → decline
      t6 = (base + 5 * 86_400).iso8601 # суббота
      out = proc.process_line(line(id: "w5", cid: "w9", amount: "0.01", time: t6))
      expect(out).to include('"accepted":false')
    end
  end
  
  describe "Monday rule (amount ×2 for checks)" do
    it "doubles only for Monday and affects daily limit" do
      mon = "2025-10-13T09:00:00Z" # Monday
      out1 = proc.process_line(line(id: "m1", cid: "c6", amount: "2500.00", time: mon))  # eff=5000
      expect(out1).to include('"accepted":true')
      out2 = proc.process_line(line(id: "m2", cid: "c6", amount: "1.00", time: mon))     # eff=2, total eff=5002 -> decline
      expect(out2).to include('"accepted":false')
    end

    it "does not double on non-Monday" do
      tue = "2025-10-14T09:00:00Z"
      out = proc.process_line(line(id: "t1", cid: "c7", amount: "5000.00", time: tue))
      expect(out).to include('"accepted":true') # eff stays 5000
    end
  end

  describe "Prime ID rule (global: ≤ 1 prime-id per calendar day, and amount ≤ 9999 after Monday ×2)" do
    it "allows a single prime-id that day, declines the second (even for another customer)" do
      day = "2025-10-14T10:00:00Z"
      expect(proc.process_line(line(id: "13", cid: "X", amount: "10.00", time: day))).to include('"accepted":true')
      expect(proc.process_line(line(id: "17", cid: "Y", amount: "10.00", time: day))).to include('"accepted":false')
    end

    it "declines a prime-id when effective amount > 9999" do
      day = "2025-10-14T10:00:00Z" # Tue (без ×2)
      expect(proc.process_line(line(id: "19", cid: "Z", amount: "10000.00", time: day))).to include('"accepted":false')
    end

    it "applies Monday ×2 before the 9999 check for prime ids" do
      mon = "2025-10-13T10:00:00Z" # Monday
      expect(proc.process_line(line(id: "29", cid: "Z2", amount: "5000.00", time: mon))).to include('"accepted":false') # 5000*2=10000>9999
    end

    it "non-numeric id is not prime" do
      day = "2025-10-14T10:00:00Z"
      expect(proc.process_line(line(id: "abc", cid: "N", amount: "100.00", time: day))).to include('"accepted":true')
      expect(proc.process_line(line(id: "def", cid: "N", amount: "100.00", time: day))).to include('"accepted":true')
    end
  end

  describe "money parsing and rounding" do
    it "handles cents precisely (integers under the hood)" do
      t = "2025-10-14T10:00:00Z"
      # 3 * 1666.67 = 5000.01 → третью должны отклонить
      expect(proc.process_line(line(id: "p1", cid: "c8", amount: "1666.67", time: t))).to include('"accepted":true')
      expect(proc.process_line(line(id: "p2", cid: "c8", amount: "1666.67", time: t))).to include('"accepted":true')
      expect(proc.process_line(line(id: "p3", cid: "c8", amount: "1666.67", time: t))).to include('"accepted":false')
    end
  end
end
