module Seeds
  # The shape of the fictional organisation. Kept as data so the generator
  # stays readable and the numbers are all in one place to argue with.
  module Catalog
    # Rate is how many BASE_CURRENCY units one unit of the currency buys,
    # matching FxRate's convention. Roughly realistic for 2026, and fixed:
    # a seeded rate that moved would make every report irreproducible.
    COUNTRIES = [
      { code: "DE", currency: "EUR", rate: "1.0",     weight: 26, cost_factor: "1.00" },
      { code: "FR", currency: "EUR", rate: "1.0",     weight: 12, cost_factor: "0.95" },
      { code: "ES", currency: "EUR", rate: "1.0",     weight: 10, cost_factor: "0.78" },
      { code: "GB", currency: "GBP", rate: "1.17",    weight: 14, cost_factor: "1.10" },
      { code: "US", currency: "USD", rate: "0.92",    weight: 18, cost_factor: "1.38" },
      { code: "PL", currency: "PLN", rate: "0.23",    weight: 10, cost_factor: "0.55" },
      { code: "IN", currency: "INR", rate: "0.011",   weight: 10, cost_factor: "0.26" }
    ].freeze

    # Midpoint pay in BASE_CURRENCY for a country with cost_factor 1.0.
    # Gaps widen with seniority, which is how real ladders behave.
    JOB_LEVELS = [
      { name: "Intern",      rank: 1, midpoint: 24_000,  weight: 3 },
      { name: "Junior",      rank: 2, midpoint: 38_000,  weight: 14 },
      { name: "Mid",         rank: 3, midpoint: 52_000,  weight: 26 },
      { name: "Senior",      rank: 4, midpoint: 70_000,  weight: 24 },
      { name: "Staff",       rank: 5, midpoint: 92_000,  weight: 14 },
      { name: "Principal",   rank: 6, midpoint: 120_000, weight: 8 },
      { name: "Director",    rank: 7, midpoint: 155_000, weight: 8 },
      { name: "VP",          rank: 8, midpoint: 200_000, weight: 3 }
    ].freeze

    DEPARTMENTS = [
      { name: "Engineering",      weight: 32 },
      { name: "Sales",            weight: 15 },
      { name: "Customer Support", weight: 12 },
      { name: "Product",          weight: 8 },
      { name: "Marketing",        weight: 8 },
      { name: "Operations",       weight: 7 },
      { name: "Finance",          weight: 6 },
      { name: "Design",           weight: 5 },
      { name: "People",           weight: 4 },
      { name: "Legal",            weight: 3 }
    ].freeze

    GENDERS = [
      { value: "female",      weight: 44 },
      { value: "male",        weight: 48 },
      { value: "non_binary",  weight: 3 },
      { value: "undisclosed", weight: 5 }
    ].freeze

    CHANGE_REASONS = [
      { value: "merit",             weight: 55 },
      { value: "promotion",         weight: 22 },
      { value: "market_adjustment", weight: 18 },
      { value: "correction",        weight: 5 }
    ].freeze

    BAND_MIN_FACTOR = 0.80
    BAND_MAX_FACTOR = 1.20
  end
end
