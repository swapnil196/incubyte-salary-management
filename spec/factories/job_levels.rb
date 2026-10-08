FactoryBot.define do
  factory :job_level do
    sequence(:name) { |n| "Level #{n}" }
    # Starts high so a spec that creates an explicit rank, as any realistic
    # ladder would (1..10), never collides with one the factory invents.
    sequence(:rank) { |n| 1_000 + n }
  end
end
