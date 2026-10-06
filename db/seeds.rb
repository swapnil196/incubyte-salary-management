require_relative "seeds/reference_data"
require_relative "seeds/workforce"

# Rebuilds the whole dataset from scratch, deterministically.
#
# Idempotent by truncation rather than by upsert: this is demonstration data, so
# "run it again and get exactly the same thing" is more useful than merging into
# whatever happens to be there.
started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
count = Integer(ENV.fetch("SEED_EMPLOYEE_COUNT", Seeds::Workforce::DEFAULT_COUNT))

puts "Seeding #{count} employees..."

ActiveRecord::Base.transaction do
  # Children first: foreign keys are enforced.
  SalaryRecord.delete_all
  PayBand.delete_all
  Employee.delete_all
  FxRate.delete_all
  JobLevel.delete_all
  Department.delete_all

  reference = Seeds::ReferenceData.call
  Seeds::Workforce.call(reference: reference, count: count)
end

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
puts format("Done in %.2fs", elapsed)
