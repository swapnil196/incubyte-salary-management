FactoryBot.define do
  factory :salary_record do
    employee
    amount_cents { 60_000_00 }
    currency { BASE_CURRENCY }
    base_amount_cents { 60_000_00 }
    fx_rate { BigDecimal(1) }
    fx_rate_date { Date.new(2026, 1, 1) }
    effective_from { Date.new(2026, 1, 1) }
    effective_to { nil }
    change_reason { "hire" }
  end
end
