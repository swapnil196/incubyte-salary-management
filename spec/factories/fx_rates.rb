FactoryBot.define do
  factory :fx_rate do
    currency { "USD" }
    base_currency { BASE_CURRENCY }
    rate { BigDecimal("0.92") }
    rate_date { Date.new(2026, 1, 1) }
  end
end
