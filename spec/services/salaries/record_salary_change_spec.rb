require "rails_helper"

RSpec.describe Salaries::RecordSalaryChange do
  subject(:service) { described_class }

  let(:employee) { create(:employee, hired_on: Date.new(2024, 1, 1), country_code: "DE") }

  def call(amount: Money.from_major("60000", BASE_CURRENCY),
           effective_from: Date.new(2025, 1, 1),
           change_reason: "merit",
           for_employee: employee)
    service.call(employee: for_employee, amount: amount,
                 effective_from: effective_from, change_reason: change_reason)
  end

  describe "the first salary" do
    it "opens a record with no predecessor to close" do
      result = call(amount: Money.from_major("60000", BASE_CURRENCY),
                    effective_from: Date.new(2024, 1, 1), change_reason: "hire")

      expect(result).to be_success
      expect(employee.salary_records.count).to eq(1)
      expect(result.record).to have_attributes(
        amount_cents: 60_000_00,
        currency: BASE_CURRENCY,
        effective_from: Date.new(2024, 1, 1),
        effective_to: nil,
        change_reason: "hire",
      )
    end
  end

  describe "a subsequent change" do
    before do
      call(amount: Money.from_major("60000", BASE_CURRENCY),
           effective_from: Date.new(2024, 1, 1), change_reason: "hire")
    end

    it "closes the open record and opens a new one, in a single transaction" do
      result = call(amount: Money.from_major("66000", BASE_CURRENCY),
                    effective_from: Date.new(2025, 1, 1), change_reason: "merit")

      expect(result).to be_success

      history = employee.salary_records.chronological.to_a
      expect(history.size).to eq(2)
      expect(history.first).to have_attributes(
        amount_cents: 60_000_00, effective_to: Date.new(2025, 1, 1)
      )
      expect(history.last).to have_attributes(amount_cents: 66_000_00, effective_to: nil)
    end

    it "leaves exactly one record in force" do
      call(effective_from: Date.new(2025, 1, 1))

      expect(employee.salary_records.current.count).to eq(1)
    end

    it "never mutates the amount of the superseded record" do
      call(amount: Money.from_major("66000", BASE_CURRENCY), effective_from: Date.new(2025, 1, 1))

      expect(employee.salary_records.chronological.first.amount_cents).to eq(60_000_00)
    end

    it "allows a same-day change, leaving the superseded record covering zero days" do
      result = call(amount: Money.from_major("70000", BASE_CURRENCY),
                    effective_from: Date.new(2024, 1, 1), change_reason: "correction")

      expect(result).to be_success

      superseded = employee.salary_records.chronological.first
      expect(superseded.effective_from).to eq(superseded.effective_to)
      expect(employee.reload.current_salary.amount_cents).to eq(70_000_00)
    end

    it "rejects a change dated before the salary currently in force" do
      # Backdating into a period that has already been closed would mean
      # splitting history, which needs a correction workflow we have scoped out.
      # The date below is after the hire, so this exercises the in-force check
      # rather than the hire-date check.
      call(amount: Money.from_major("66000", BASE_CURRENCY),
           effective_from: Date.new(2025, 1, 1), change_reason: "merit")

      result = call(effective_from: Date.new(2024, 6, 1))

      expect(result).not_to be_success
      expect(result.error).to match(/before the salary currently in force/i)
      expect(employee.salary_records.count).to eq(2)
    end
  end

  describe "validation" do
    it "rejects an effective date before the employee was hired" do
      result = call(effective_from: Date.new(2023, 1, 1), change_reason: "hire")

      expect(result).not_to be_success
      expect(result.error).to match(/before.*hired/i)
    end

    it "rejects a future effective date" do
      # Scheduling a raise ahead of time would mean the open record is not yet
      # in force, which contradicts "effective_to IS NULL means current".
      # Out of scope deliberately; see the engineering notes.
      result = call(effective_from: Date.current + 1)

      expect(result).not_to be_success
      expect(result.error).to match(/future/i)
    end

    it "rejects a non-positive amount" do
      result = call(amount: Money.new(0, BASE_CURRENCY))

      expect(result).not_to be_success
      expect(result.error).to match(/positive/i)
    end

    it "rejects an unrecognised change reason" do
      result = call(change_reason: "vibes")

      expect(result).not_to be_success
      expect(result.error).to match(/reason/i)
    end

    it "writes nothing when validation fails" do
      expect { call(change_reason: "vibes") }.not_to change(SalaryRecord, :count)
    end
  end

  describe "currency conversion" do
    it "stores the base amount, the rate used, and the date that rate was published" do
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.92"),
                       rate_date: Date.new(2024, 12, 1))

      result = call(amount: Money.from_major("100000", "USD"),
                    effective_from: Date.new(2025, 1, 1), change_reason: "hire")

      expect(result).to be_success
      expect(result.record).to have_attributes(
        amount_cents: 100_000_00,
        currency: "USD",
        base_amount_cents: 92_000_00,
        fx_rate: BigDecimal("0.92"),
        # The date the rate was published, not the date of the change. This is
        # what makes a conversion explainable after the fact.
        fx_rate_date: Date.new(2024, 12, 1),
      )
    end

    it "stores a rate of exactly 1 when the salary is already in the base currency" do
      result = call(amount: Money.from_major("60000", BASE_CURRENCY),
                    effective_from: Date.new(2024, 1, 1), change_reason: "hire")

      expect(result.record.fx_rate).to eq(BigDecimal(1))
      expect(result.record.base_amount_cents).to eq(result.record.amount_cents)
    end

    it "fails cleanly when no rate has been published for the currency" do
      result = call(amount: Money.from_major("100000", "JPY"),
                    effective_from: Date.new(2025, 1, 1), change_reason: "hire")

      expect(result).not_to be_success
      expect(result.error).to match(/rate/i)
      expect(SalaryRecord.count).to eq(0)
    end

    it "allows the currency to change, for an employee who relocates" do
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.92"), rate_date: Date.new(2024, 1, 1))
      call(amount: Money.from_major("60000", BASE_CURRENCY),
           effective_from: Date.new(2024, 1, 1), change_reason: "hire")

      result = call(amount: Money.from_major("90000", "USD"),
                    effective_from: Date.new(2025, 1, 1), change_reason: "market_adjustment")

      expect(result).to be_success
      expect(employee.reload.current_salary.currency).to eq("USD")
    end
  end

  describe "atomicity" do
    it "rolls the close back if the insert fails, so the employee is never left unpaid" do
      call(amount: Money.from_major("60000", BASE_CURRENCY),
           effective_from: Date.new(2024, 1, 1), change_reason: "hire")

      allow(SalaryRecord).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique, "boom")

      expect { call(effective_from: Date.new(2025, 1, 1)) }
        .to raise_error(ActiveRecord::RecordNotUnique)

      # The previously open record must still be open.
      expect(employee.reload.current_salary).to be_present
      expect(employee.current_salary.amount_cents).to eq(60_000_00)
    end
  end
end
