FactoryBot.define do
  factory :employee do
    sequence(:employee_number) { |n| format("ACME-%05d", n) }
    first_name { "Ada" }
    last_name { "Lovelace" }
    sequence(:email) { |n| "employee#{n}@acme.example" }
    country_code { "DE" }
    gender { "undisclosed" }
    hired_on { Date.new(2020, 1, 1) }
    terminated_on { nil }

    department
    job_level

    trait :terminated do
      terminated_on { Date.new(2025, 6, 30) }
    end

    # Attaches an open salary record, which is what most specs actually want.
    trait :with_salary do
      transient do
        salary_cents { 60_000_00 }
        salary_currency { BASE_CURRENCY }
      end

      after(:create) do |employee, evaluator|
        create(:salary_record,
               employee: employee,
               amount_cents: evaluator.salary_cents,
               currency: evaluator.salary_currency,
               base_amount_cents: evaluator.salary_cents,
               effective_from: employee.hired_on)
      end
    end
  end
end
