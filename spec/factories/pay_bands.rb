FactoryBot.define do
  factory :pay_band do
    job_level
    country_code { "DE" }
    min_cents { 50_000_00 }
    mid_cents { 65_000_00 }
    max_cents { 80_000_00 }
  end
end
