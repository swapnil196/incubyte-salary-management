require "rails_helper"

RSpec.describe Employee do
  it { is_expected.to belong_to(:department) }
  it { is_expected.to belong_to(:job_level) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:employee_number) }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:hired_on) }

    it "requires a two-letter ISO 3166-1 country code" do
      expect(build(:employee, country_code: "DEU")).not_to be_valid
      expect(build(:employee, country_code: "de")).not_to be_valid
      expect(build(:employee, country_code: "DE")).to be_valid
    end

    it "rejects a malformed email" do
      expect(build(:employee, email: "not-an-email")).not_to be_valid
    end

    it "rejects a duplicate email regardless of casing" do
      create(:employee, email: "ada@acme.example")

      expect(build(:employee, email: "ADA@acme.example")).not_to be_valid
    end

    it "accepts a nil gender but rejects an unrecognised one" do
      expect(build(:employee, gender: nil)).to be_valid
      expect(build(:employee, gender: "unspecified-value")).not_to be_valid
    end

    it "rejects a termination date before the hire date" do
      employee = build(:employee, hired_on: Date.new(2024, 1, 1),
                                  terminated_on: Date.new(2023, 12, 31))

      expect(employee).not_to be_valid
      expect(employee.errors[:terminated_on]).to be_present
    end

    it "allows termination on the hire date itself" do
      expect(build(:employee, hired_on: Date.new(2024, 1, 1),
                              terminated_on: Date.new(2024, 1, 1))).to be_valid
    end
  end

  describe "database constraints" do
    it "rejects a termination before hire even when validations are bypassed" do
      employee = create(:employee, hired_on: Date.new(2024, 1, 1))

      expect { employee.update_column(:terminated_on, Date.new(2023, 1, 1)) }
        .to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "scopes" do
    it "separates active from terminated employees" do
      active = create(:employee)
      gone = create(:employee, :terminated)

      expect(described_class.active).to contain_exactly(active)
      expect(described_class.terminated).to contain_exactly(gone)
    end
  end

  describe "#current_salary" do
    it "returns only the open record" do
      employee = create(:employee)
      create(:salary_record, employee: employee, amount_cents: 50_000_00,
                             effective_from: Date.new(2024, 1, 1),
                             effective_to: Date.new(2025, 1, 1))
      open = create(:salary_record, employee: employee, amount_cents: 60_000_00,
                                    effective_from: Date.new(2025, 1, 1))

      expect(employee.reload.current_salary).to eq(open)
    end

    it "is eager-loadable, so a directory page does not issue one query per row" do
      create_list(:employee, 3, :with_salary)

      employees = described_class.with_directory_associations.to_a

      expect do
        employees.each { |e| [ e.department.name, e.job_level.name, e.current_salary&.amount_cents ] }
      end.not_to make_database_queries
    end
  end

  describe "#salary_on" do
    let(:employee) { create(:employee) }

    before do
      create(:salary_record, employee: employee, amount_cents: 50_000_00,
                             effective_from: Date.new(2024, 1, 1),
                             effective_to: Date.new(2025, 1, 1))
      create(:salary_record, employee: employee, amount_cents: 60_000_00,
                             effective_from: Date.new(2025, 1, 1))
    end

    it "returns the record in force on that date" do
      expect(employee.salary_on(Date.new(2024, 6, 1)).amount_cents).to eq(50_000_00)
    end

    it "treats the end date as exclusive, so the successor applies from that day" do
      expect(employee.salary_on(Date.new(2025, 1, 1)).amount_cents).to eq(60_000_00)
    end

    it "returns the open record for any later date" do
      expect(employee.salary_on(Date.new(2030, 1, 1)).amount_cents).to eq(60_000_00)
    end

    it "returns nothing for a date before the employee had any salary" do
      expect(employee.salary_on(Date.new(2023, 1, 1))).to be_nil
    end
  end

  describe "#full_name" do
    it "joins the given and family names" do
      expect(build(:employee, first_name: "Ada", last_name: "Lovelace").full_name)
        .to eq("Ada Lovelace")
    end
  end
end
