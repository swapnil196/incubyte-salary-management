FactoryBot.define do
  factory :job_level do
    sequence(:name) { |n| "Level #{n}" }
    sequence(:rank) { |n| n }
  end
end
