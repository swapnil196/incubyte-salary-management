require "csv"

module Exports
  # The directory as a CSV, honouring whatever filters were applied on screen.
  #
  # Reuses Employees::Query#filtered_scope rather than reimplementing the
  # filters, so the file always contains exactly the rows the user was looking
  # at. Pagination is deliberately not applied: an export of page 1 of 369
  # would be useless.
  class EmployeesCsv
    HEADERS = [
      "Employee number", "First name", "Last name", "Email", "Country",
      "Department", "Job level", "Status", "Hired on", "Terminated on",
      "Salary amount", "Salary currency", "Salary (#{BASE_CURRENCY})",
      "Band minimum (#{BASE_CURRENCY})", "Band midpoint (#{BASE_CURRENCY})",
      "Band maximum (#{BASE_CURRENCY})", "Compa-ratio", "Band status"
    ].freeze

    # Rows are fetched in slices rather than all at once. At 10,000 employees
    # the whole set is only a few MB, but the memory cost of an export grows
    # with the organisation while the page size does not.
    BATCH_SIZE = 1_000

    def self.call(...) = new(...).call

    def initialize(params = {})
      @query = Employees::Query.new(params)
    end

    def call
      CSV.generate do |csv|
        csv << HEADERS
        each_row { |row| csv << CsvSafe.row(row) }
      end
    end

    def filename
      "employees-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
    end

    private

    attr_reader :query

    def each_row
      scope = query.filtered_scope
      offset = 0

      loop do
        batch = scope.limit(BATCH_SIZE).offset(offset).to_a
        break if batch.empty?

        batch.each { |employee| yield row_for(employee) }
        offset += BATCH_SIZE
      end
    end

    def row_for(employee)
      amount = employee[:salary_amount_cents]
      base = employee[:salary_base_amount_cents]
      mid = employee[:band_mid_cents]

      [
        employee.employee_number,
        employee.first_name,
        employee.last_name,
        employee.email,
        employee.country_code,
        employee[:department_name],
        employee[:job_level_name],
        employee.active? ? "active" : "terminated",
        employee.hired_on,
        employee.terminated_on,
        major(amount),
        employee[:salary_currency],
        major(base),
        major(employee[:band_min_cents]),
        major(mid),
        major(employee[:band_max_cents]),
        compa_ratio(base, mid),
        band_status(base, employee)
      ]
    end

    def major(cents) = cents && (BigDecimal(cents, 0) / 100).to_s("F")

    def compa_ratio(base, mid)
      return nil if base.blank? || mid.blank? || mid.zero?

      (BigDecimal(base, 0) / mid).round(4).to_s("F")
    end

    def band_status(base, employee)
      return nil if base.blank? || employee[:band_mid_cents].blank?
      return "below_minimum" if base < employee[:band_min_cents]
      return "above_maximum" if base > employee[:band_max_cents]

      "within_band"
    end
  end
end
