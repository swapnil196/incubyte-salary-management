# Reproducible performance measurements against whatever is in the database.
#
#   bin/rails benchmark
#
# Committed so the numbers in docs/PERFORMANCE.md can be checked rather than
# taken on trust, and so a regression shows up as a number rather than a
# feeling.
namespace :benchmark do
  REPEATS = 20

  def measure(label)
    2.times { yield } # warm the query cache and the method caches
    # Without this, garbage left by earlier measurements is collected during a
    # later one and charged to it. It made a 1.3ms query report as 54ms purely
    # because of where it sat in the sequence.
    GC.start
    elapsed = Benchmark.realtime { REPEATS.times { yield } }
    puts format("  %-50s %7.1f ms", label, (elapsed / REPEATS) * 1000)
  end

  def explain(label, relation)
    puts "\n#{label}"
    ActiveRecord::Base.connection
                      .select_all("EXPLAIN QUERY PLAN #{relation.to_sql}")
                      .rows.each { |row| puts "   #{row.last}" }
  end

  desc "Time the endpoints that matter against the current dataset"
  task timings: :environment do
    require "benchmark"

    # Development logs every statement, which costs more than some of the
    # queries being measured.
    ActiveRecord::Base.logger = nil

    # The query cache MUST be off, or this measures the cache instead of the
    # database. `rails runner` turns it on, and repeating one identical query
    # in a loop then returns a memoised result: a 54ms query reported as 1.3ms.
    # A real HTTP request starts with an empty cache and issues each distinct
    # query once, so uncached is the accurate model.
    ActiveRecord::Base.connection.disable_query_cache!

    puts "#{Employee.count} employees, #{SalaryRecord.count} salary records " \
         "(#{Employee.active.count} active)\n\n"
    department = Department.first&.id

    puts "Directory"
    measure("default page (25, active, by name)") do
      result = Employees::Query.call({})
      EmployeeSerializer.list(result.records)
      result.total_count
    end
    measure("sorted by salary, descending") do
      EmployeeSerializer.list(Employees::Query.call(sort: "salary", direction: "desc").records)
    end
    measure("sorted by compa-ratio, descending") do
      EmployeeSerializer.list(Employees::Query.call(sort: "compa_ratio", direction: "desc").records)
    end
    measure("filtered by country and department") do
      EmployeeSerializer.list(
        Employees::Query.call(country_code: "DE", department_id: department).records,
      )
    end
    measure("search term") { EmployeeSerializer.list(Employees::Query.call(q: "ann").records) }
    measure("deep page (page 300)") { Employees::Query.call(page: 300).records.to_a }
    measure("maximum page size (100 rows)") do
      EmployeeSerializer.list(Employees::Query.call(per_page: 100).records)
    end

    puts "\nDashboard"
    measure("full insights payload") { Insights::Overview.call({}) }

    puts "\nExport"
    measure("CSV, every employee") { Exports::EmployeesCsv.call(status: "all") }
  end

  desc "Show the query plan for each significant query"
  task plans: :environment do
    explain("Directory count (filters only)", Employee.active)
    explain("Directory page", Employees::Query.new({}).call.records)
    explain("Directory filtered by country and department",
            Employees::Query.new(country_code: "DE", department_id: Department.first&.id)
                            .call.records)
    explain("Insights projection",
            SalaryRecord.current.joins(:employee).merge(Employee.active)
                        .joins(employee: %i[department job_level])
                        .select("salary_records.base_amount_cents"))
    explain("Salary history for one employee", SalaryRecord.where(employee_id: 1).most_recent_first)
  end
end

desc "Run all performance measurements"
task benchmark: %w[benchmark:timings benchmark:plans]
