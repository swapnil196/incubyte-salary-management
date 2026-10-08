require "rails_helper"

RSpec.describe Insights::Overview do
  let(:engineering) { create(:department, name: "Engineering") }
  let(:sales) { create(:department, name: "Sales") }
  let(:junior) { create(:job_level, name: "Junior", rank: 2) }
  let(:senior) { create(:job_level, name: "Senior", rank: 4) }

  def employee_paid(cents, country: "DE", department: engineering, level: senior,
                    gender: "female", status: :active)
    employee = create(:employee, country_code: country, department: department,
                                 job_level: level, gender: gender,
                                 terminated_on: status == :active ? nil : Date.new(2025, 6, 1))
    create(:salary_record, employee: employee, amount_cents: cents, base_amount_cents: cents,
                           effective_from: employee.hired_on,
                           effective_to: status == :active ? nil : Date.new(2025, 6, 1))
    employee
  end

  describe "summary" do
    before do
      employee_paid(50_000_00)
      employee_paid(60_000_00)
      employee_paid(70_000_00)
    end

    it "totals the annual payroll from salaries currently in force" do
      expect(described_class.call[:summary][:annual_payroll_cents]).to eq(180_000_00)
    end

    it "reports the median rather than the mean" do
      employee_paid(10_000_000_00) # an executive

      summary = described_class.call[:summary]

      expect(summary[:median_cents]).to eq(65_000_00)
      expect(summary[:headcount]).to eq(4)
    end

    it "excludes employees who have left" do
      employee_paid(99_000_00, status: :terminated)

      expect(described_class.call[:summary]).to include(headcount: 3,
                                                        annual_payroll_cents: 180_000_00)
    end
  end

  describe "breakdowns" do
    before do
      5.times { |i| employee_paid(50_000_00 + (i * 1_000_00), country: "DE") }
      5.times { |i| employee_paid(80_000_00 + (i * 1_000_00), country: "US") }
    end

    it "reports quartiles per country" do
      germany = described_class.call[:by_country].find { |r| r[:key] == "DE" }

      expect(germany).to include(headcount: 5, median_cents: 52_000_00, suppressed: false)
      expect(germany[:p25_cents]).to be < germany[:median_cents]
      expect(germany[:p75_cents]).to be > germany[:median_cents]
    end

    it "orders levels by seniority rather than by size" do
      5.times { employee_paid(30_000_00, level: junior) }

      keys = described_class.call[:by_level].map { |r| r[:key] }

      expect(keys).to eq(%w[Junior Senior])
    end

    it "orders countries and departments by headcount" do
      3.times { employee_paid(40_000_00, department: sales) }

      expect(described_class.call[:by_department].first[:key]).to eq("Engineering")
    end
  end

  describe "small group suppression" do
    before do
      5.times { employee_paid(60_000_00, country: "DE") }
      # Four people in France: enough to exist, not enough to be anonymous.
      4.times { employee_paid(90_000_00, country: "FR") }
    end

    it "withholds statistics for a group below the minimum size" do
      france = described_class.call[:by_country].find { |r| r[:key] == "FR" }

      expect(france).to include(headcount: 4, suppressed: true)
      expect(france).not_to have_key(:median_cents)
    end

    it "still reports that the group exists" do
      expect(described_class.call[:by_country].map { |r| r[:key] }).to include("FR")
    end

    it "reports statistics once the group is large enough" do
      employee_paid(90_000_00, country: "FR")

      france = described_class.call[:by_country].find { |r| r[:key] == "FR" }

      expect(france).to include(headcount: 5, suppressed: false)
      expect(france[:median_cents]).to eq(90_000_00)
    end
  end

  describe "band status" do
    before do
      create(:pay_band, job_level: senior, country_code: "DE",
                        min_cents: 50_000_00, mid_cents: 60_000_00, max_cents: 70_000_00)
      employee_paid(40_000_00)
      employee_paid(60_000_00)
      employee_paid(80_000_00)
    end

    it "counts who sits below, within and above their band" do
      expect(described_class.call[:band_status])
        .to eq(below_minimum: 1, within_band: 1, above_maximum: 1)
    end

    it "ignores employees with no band defined for their level and country" do
      employee_paid(60_000_00, country: "JP")

      expect(described_class.call[:band_status].values.sum).to eq(3)
    end
  end

  describe "pay equity" do
    before do
      5.times { employee_paid(60_000_00, gender: "male", level: senior, country: "DE") }
      5.times { employee_paid(54_000_00, gender: "female", level: senior, country: "DE") }
    end

    it "compares within job level and country, not pooled across the organisation" do
      cells = described_class.call[:pay_equity]

      expect(cells.map { |c| c.values_at(:job_level, :country_code) }.uniq)
        .to eq([ %w[Senior DE] ])
    end

    it "reports the gap against the largest group in the cell" do
      female = described_class.call[:pay_equity].find { |c| c[:gender] == "female" }

      expect(female[:median_cents]).to eq(54_000_00)
      expect(female[:difference_from_reference_pct]).to eq(-10.0)
    end

    it "suppresses a gender group too small to be anonymous" do
      2.times { employee_paid(90_000_00, gender: "non_binary", level: senior, country: "DE") }

      cell = described_class.call[:pay_equity].find { |c| c[:gender] == "non_binary" }

      expect(cell).to include(headcount: 2, suppressed: true)
      expect(cell).not_to have_key(:median_cents)
      expect(cell[:difference_from_reference_pct]).to be_nil
    end
  end

  describe "filtering" do
    before do
      5.times { employee_paid(50_000_00, country: "DE") }
      5.times { employee_paid(90_000_00, country: "US") }
    end

    it "narrows every figure to the filtered population" do
      result = described_class.call(country_code: "US")

      expect(result[:summary]).to include(headcount: 5, annual_payroll_cents: 450_000_00)
      expect(result[:by_country].map { |r| r[:key] }).to eq([ "US" ])
    end
  end
end
