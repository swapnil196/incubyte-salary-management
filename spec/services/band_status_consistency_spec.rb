require "rails_helper"

# The dashboard counts who is outside their band; the directory lists them.
# They are computed by different objects through different SQL, so they can
# drift apart — and a dashboard saying 525 next to a list of 524 destroys trust
# in both. This pins them together.
RSpec.describe "Band status consistency between the dashboard and the directory" do
  let(:level) { create(:job_level, name: "Senior", rank: 4) }
  let(:other_level) { create(:job_level, name: "Junior", rank: 2) }

  def paid(cents, job_level: level, country: "DE", active: true)
    employee = create(:employee, country_code: country, job_level: job_level,
                                 terminated_on: active ? nil : Date.new(2025, 6, 1))
    create(:salary_record, employee: employee, amount_cents: cents, base_amount_cents: cents,
                           effective_from: employee.hired_on,
                           effective_to: active ? nil : Date.new(2025, 6, 1))
    employee
  end

  before do
    create(:pay_band, job_level: level, country_code: "DE",
                      min_cents: 50_000_00, mid_cents: 60_000_00, max_cents: 70_000_00)

    3.times { paid(40_000_00) }           # below
    5.times { paid(60_000_00) }           # within
    2.times { paid(90_000_00) }           # above
    paid(10_000_00, active: false)        # left: must not be counted anywhere
    paid(10_000_00, job_level: other_level) # no band defined for this level
    create(:employee, country_code: "DE", job_level: level) # no salary at all
  end

  let(:dashboard) { Insights::Overview.call({})[:band_status] }

  def directory_count(status) = Employees::Query.new(band_status: status).call.total_count

  it "reports the same number of people below the minimum" do
    expect(directory_count("below_minimum")).to eq(dashboard[:below_minimum])
    expect(dashboard[:below_minimum]).to eq(3)
  end

  it "reports the same number within the band" do
    expect(directory_count("within_band")).to eq(dashboard[:within_band])
  end

  it "reports the same number above the maximum" do
    expect(directory_count("above_maximum")).to eq(dashboard[:above_maximum])
  end

  it "treats out_of_band as exactly the two ends added together" do
    expect(directory_count("out_of_band"))
      .to eq(dashboard[:below_minimum] + dashboard[:above_maximum])
  end

  it "classifies every employee who can be classified exactly once" do
    classifiable = Employee.active
                           .joins(:current_salary)
                           .joins(Employees::Query::PAY_BAND_JOIN.sub("LEFT JOIN", "JOIN"))
                           .count

    expect(dashboard.values.sum).to eq(classifiable)
  end

  it "counts nobody who has left, no salary, or no band" do
    # 10 classifiable people were created; the other three are excluded for a
    # different reason each.
    expect(dashboard.values.sum).to eq(10)
  end
end
