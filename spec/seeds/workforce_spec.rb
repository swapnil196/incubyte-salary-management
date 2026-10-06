require "rails_helper"
require Rails.root.join("db/seeds/reference_data")
require Rails.root.join("db/seeds/workforce")

# Runs the real generator at a small size. The seed is demonstration data, but
# the invariants it has to satisfy are the same ones the application relies on,
# and a generator that quietly produces two open salaries would break the
# dashboard in a way no unit test would catch.
RSpec.describe Seeds::Workforce do
  let(:count) { 60 }
  let(:silent) { StringIO.new }

  def generate(seed: 42)
    reference = Seeds::ReferenceData.call(logger: silent)
    described_class.call(reference: reference, count: count, seed: seed, logger: silent)
  end

  describe "determinism" do
    it "produces identical data for the same seed" do
      generate(seed: 7)
      first = Employee.order(:id).pluck(:email, :country_code, :hired_on) +
              SalaryRecord.order(:id).pluck(:employee_id, :amount_cents, :effective_from)

      [ SalaryRecord, PayBand, Employee, FxRate, JobLevel, Department ].each(&:delete_all)

      generate(seed: 7)
      second = Employee.order(:id).pluck(:email, :country_code, :hired_on) +
               SalaryRecord.order(:id).pluck(:employee_id, :amount_cents, :effective_from)

      expect(second).to eq(first)
    end

    it "produces different data for a different seed" do
      generate(seed: 1)
      first = Employee.order(:id).pluck(:email)

      [ SalaryRecord, PayBand, Employee, FxRate, JobLevel, Department ].each(&:delete_all)

      generate(seed: 2)

      expect(Employee.order(:id).pluck(:email)).not_to eq(first)
    end
  end

  describe "the data it produces" do
    before { generate }

    it "creates the requested number of employees" do
      expect(Employee.count).to eq(count)
    end

    it "gives every active employee exactly one salary in force" do
      expect(Employee.active.where.missing(:current_salary)).to be_empty
      expect(SalaryRecord.current.count).to eq(Employee.active.count)
    end

    it "leaves no terminated employee with an open salary record" do
      expect(Employee.terminated.joins(:current_salary)).to be_empty
    end

    it "gives everyone a salary history that starts on their hire date" do
      Employee.includes(:salary_records).find_each do |employee|
        first = employee.salary_records.min_by(&:effective_from)

        expect(first.effective_from).to eq(employee.hired_on)
        expect(first.change_reason).to eq("hire")
      end
    end

    it "produces a contiguous history with no gaps and no overlaps" do
      Employee.includes(:salary_records).find_each do |employee|
        periods = employee.salary_records.sort_by(&:effective_from)

        periods.each_cons(2) do |earlier, later|
          expect(earlier.effective_to).to eq(later.effective_from),
            "employee #{employee.id} has a gap or overlap at #{earlier.effective_to}"
        end
      end
    end

    it "keeps the stored base amount consistent with the local amount and rate" do
      SalaryRecord.find_each do |record|
        expected = record.amount.convert_to(BASE_CURRENCY, rate: record.fx_rate)

        expect(record.base_amount).to eq(expected)
      end
    end

    it "defines a pay band for every level and country combination in use" do
      in_use = Employee.distinct.pluck(:job_level_id, :country_code)
      defined = PayBand.pluck(:job_level_id, :country_code)

      expect(in_use - defined).to be_empty
    end

    it "spreads people across countries, levels and departments" do
      expect(Employee.distinct.count(:country_code)).to be > 1
      expect(Employee.distinct.count(:job_level_id)).to be > 1
      expect(Employee.distinct.count(:department_id)).to be > 1
    end
  end

  describe "planted outliers" do
    # The exceptions report cannot be demonstrated or tested against a dataset
    # with no exceptions in it, so the generator puts some there on purpose.
    let(:count) { 400 }

    before { generate }

    it "places some people outside their pay band in both directions" do
      out_of_band = SalaryRecord.current
                                .joins(:employee)
                                .joins(<<~SQL.squish)
                                  JOIN pay_bands
                                    ON pay_bands.job_level_id = employees.job_level_id
                                   AND pay_bands.country_code = employees.country_code
                                SQL
                                .pluck(Arel.sql(<<~SQL.squish))
                                  CASE
                                    WHEN salary_records.base_amount_cents < pay_bands.min_cents THEN 'below'
                                    WHEN salary_records.base_amount_cents > pay_bands.max_cents THEN 'above'
                                    ELSE 'within'
                                  END
                                SQL
                                .tally

      expect(out_of_band["below"]).to be_positive
      expect(out_of_band["above"]).to be_positive
      # The great majority should still sit inside their band, or the dashboard
      # is reporting noise rather than exceptions.
      expect(out_of_band["within"]).to be > (count * 0.8)
    end
  end
end
