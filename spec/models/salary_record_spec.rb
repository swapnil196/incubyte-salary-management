require "rails_helper"

RSpec.describe SalaryRecord do
  it { is_expected.to belong_to(:employee) }

  describe "validations" do
    it "rejects a non-positive amount" do
      expect(build(:salary_record, amount_cents: 0)).not_to be_valid
      expect(build(:salary_record, amount_cents: -1)).not_to be_valid
    end

    it "rejects an unrecognised change reason" do
      expect(build(:salary_record, change_reason: "vibes")).not_to be_valid
      expect(build(:salary_record, change_reason: "promotion")).to be_valid
    end

    it "rejects a period that ends before it starts" do
      record = build(:salary_record, effective_from: Date.new(2026, 6, 1),
                                     effective_to: Date.new(2026, 1, 1))

      expect(record).not_to be_valid
      expect(record.errors[:effective_to]).to be_present
    end

    it "allows a period that ends the day it starts, meaning it never applied" do
      expect(build(:salary_record, effective_from: Date.new(2026, 6, 1),
                                   effective_to: Date.new(2026, 6, 1))).to be_valid
    end
  end

  describe "the one-current-salary invariant" do
    # This is the single most important guarantee in the schema. It is enforced
    # by a partial unique index, not by application code, so a concurrent double
    # submit cannot produce two live salaries for one employee.
    it "refuses a second open record for the same employee, at the database level" do
      employee = create(:employee)
      create(:salary_record, employee: employee, effective_to: nil)

      second = build(:salary_record, employee: employee, effective_to: nil)

      expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows many closed records alongside one open record" do
      employee = create(:employee)
      create(:salary_record, employee: employee, effective_from: Date.new(2023, 1, 1),
                             effective_to: Date.new(2024, 1, 1))
      create(:salary_record, employee: employee, effective_from: Date.new(2024, 1, 1),
                             effective_to: Date.new(2025, 1, 1))
      create(:salary_record, employee: employee, effective_from: Date.new(2025, 1, 1))

      expect(employee.salary_records.count).to eq(3)
      expect(employee.salary_records.current.count).to eq(1)
    end

    it "allows a different employee to have their own open record" do
      create(:salary_record, employee: create(:employee))

      expect { create(:salary_record, employee: create(:employee)) }.not_to raise_error
    end
  end

  describe "database constraints" do
    it "rejects a non-positive amount even when validations are bypassed" do
      record = create(:salary_record)

      expect { record.update_column(:amount_cents, 0) }
        .to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects an inverted period even when validations are bypassed" do
      record = create(:salary_record, effective_from: Date.new(2026, 6, 1))

      expect { record.update_column(:effective_to, Date.new(2026, 1, 1)) }
        .to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "scopes" do
    let(:employee) { create(:employee) }

    before do
      create(:salary_record, employee: employee, amount_cents: 50_000_00,
                             effective_from: Date.new(2024, 1, 1),
                             effective_to: Date.new(2025, 1, 1))
      create(:salary_record, employee: employee, amount_cents: 60_000_00,
                             effective_from: Date.new(2025, 1, 1))
    end

    it "finds only open records with .current" do
      expect(described_class.current.pluck(:amount_cents)).to eq([ 60_000_00 ])
    end

    it "orders oldest first with .chronological" do
      expect(described_class.chronological.pluck(:amount_cents)).to eq([ 50_000_00, 60_000_00 ])
    end

    it "finds the record in force on a date, treating the end date as exclusive" do
      expect(described_class.in_force_on(Date.new(2024, 12, 31)).pluck(:amount_cents))
        .to eq([ 50_000_00 ])
      expect(described_class.in_force_on(Date.new(2025, 1, 1)).pluck(:amount_cents))
        .to eq([ 60_000_00 ])
    end
  end

  describe "money accessors" do
    it "exposes the amount as a Money in the employee's own currency" do
      record = build(:salary_record, amount_cents: 75_000_00, currency: "USD")

      expect(record.amount).to eq(Money.new(75_000_00, "USD"))
    end

    it "exposes the converted amount as a Money in the base currency" do
      record = build(:salary_record, base_amount_cents: 69_000_00)

      expect(record.base_amount).to eq(Money.new(69_000_00, BASE_CURRENCY))
    end
  end
end
