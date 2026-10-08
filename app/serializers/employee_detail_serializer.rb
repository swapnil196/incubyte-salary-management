# The full employee profile: who they are, what they are paid now, how that
# compares to their band, and every salary they have ever had.
class EmployeeDetailSerializer
  def initialize(employee)
    @employee = employee
  end

  def as_json
    {
      id: employee.id,
      employee_number: employee.employee_number,
      first_name: employee.first_name,
      last_name: employee.last_name,
      full_name: employee.full_name,
      email: employee.email,
      country_code: employee.country_code,
      gender: employee.gender,
      department: { id: employee.department.id, name: employee.department.name },
      job_level: { id: employee.job_level.id, name: employee.job_level.name,
                   rank: employee.job_level.rank },
      status: employee.active? ? "active" : "terminated",
      hired_on: employee.hired_on,
      terminated_on: employee.terminated_on,
      current_salary: current_salary && salary_json(current_salary),
      band: band_json,
      salary_history: history
    }
  end

  private

  attr_reader :employee

  def current_salary = @current_salary ||= employee.current_salary

  def band = @band ||= employee.pay_band

  # Newest first: the recent history is what anyone opening the page is
  # looking for, and the hire record is rarely the interesting one.
  def history
    records = employee.salary_records.most_recent_first.to_a

    records.each_with_index.map do |record, index|
      salary_json(record).merge(
        effective_to: record.effective_to,
        change_reason: record.change_reason,
        current: record.current?,
        change_from_previous: percentage_change(record, records[index + 1]),
      )
    end
  end

  # The rise over the record this one replaced, which is the number HR actually
  # discusses. Computed over the base amount, so an employee who relocated to
  # another currency does not appear to have received a 900% rise.
  def percentage_change(record, previous)
    return nil if previous.nil? || previous.base_amount_cents.zero?

    before = BigDecimal(previous.base_amount_cents, 0)
    (((BigDecimal(record.base_amount_cents, 0) - before) / before) * 100).round(2).to_f
  end

  def salary_json(record)
    {
      id: record.id,
      amount_cents: record.amount_cents,
      currency: record.currency,
      base_amount_cents: record.base_amount_cents,
      base_currency: BASE_CURRENCY,
      fx_rate: record.fx_rate.to_s("F"),
      fx_rate_date: record.fx_rate_date,
      effective_from: record.effective_from
    }
  end

  def band_json
    return nil if band.nil?

    position = current_salary && band.position_for(current_salary.base_amount)

    {
      min_cents: band.min_cents,
      mid_cents: band.mid_cents,
      max_cents: band.max_cents,
      currency: BASE_CURRENCY,
      compa_ratio: position&.compa_ratio&.to_f,
      status: position&.status
    }
  end
end
