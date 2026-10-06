# Shapes an Employee row for the JSON API.
#
# Reads the aliased columns that Employees::Query selects, so rendering a page
# of 25 employees issues no further queries. Passing a plain Employee works too;
# the salary and band sections are simply absent.
class EmployeeSerializer
  def self.list(records) = records.map { |record| new(record).as_list_item }

  def initialize(employee)
    @employee = employee
  end

  def as_list_item
    {
      id: employee.id,
      employee_number: employee.employee_number,
      full_name: employee.full_name,
      email: employee.email,
      country_code: employee.country_code,
      department: attribute(:department_name),
      job_level: attribute(:job_level_name),
      status: employee.active? ? "active" : "terminated",
      hired_on: employee.hired_on,
      terminated_on: employee.terminated_on,
      salary: salary,
      band: band
    }
  end

  private

  attr_reader :employee

  def salary
    return nil if attribute(:salary_amount_cents).blank?

    {
      amount_cents: attribute(:salary_amount_cents),
      currency: attribute(:salary_currency),
      base_amount_cents: attribute(:salary_base_amount_cents),
      base_currency: BASE_CURRENCY,
      effective_from: attribute(:salary_effective_from)
    }
  end

  def band
    mid = attribute(:band_mid_cents)
    amount = attribute(:salary_base_amount_cents)
    return nil if mid.blank?

    {
      min_cents: attribute(:band_min_cents),
      mid_cents: mid,
      max_cents: attribute(:band_max_cents),
      currency: BASE_CURRENCY,
      compa_ratio: amount && (BigDecimal(amount, 0) / mid).round(4).to_f,
      status: band_status(amount)
    }
  end

  def band_status(amount)
    return nil if amount.blank?
    return "below_minimum" if amount < attribute(:band_min_cents)
    return "above_maximum" if amount > attribute(:band_max_cents)

    "within_band"
  end

  def attribute(name)
    employee[name] if employee.has_attribute?(name)
  end
end
