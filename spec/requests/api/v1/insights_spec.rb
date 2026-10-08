require "rails_helper"

RSpec.describe "GET /api/v1/insights" do
  let(:senior) { create(:job_level, name: "Senior", rank: 4) }
  let(:engineering) { create(:department, name: "Engineering") }

  def json = response.parsed_body["data"]

  before do
    create(:pay_band, job_level: senior, country_code: "DE",
                      min_cents: 50_000_00, mid_cents: 60_000_00, max_cents: 70_000_00)
    6.times do |i|
      employee = create(:employee, country_code: "DE", department: engineering,
                                   job_level: senior, gender: "female")
      create(:salary_record, employee: employee, amount_cents: 55_000_00 + (i * 1_000_00),
                             base_amount_cents: 55_000_00 + (i * 1_000_00),
                             effective_from: employee.hired_on)
    end
  end

  it "returns the dashboard payload" do
    get "/api/v1/insights"

    expect(response).to have_http_status(:ok)
    expect(json.keys).to include("summary", "by_country", "by_department", "by_level",
                                 "band_status", "pay_equity", "meta")
  end

  it "reports the payroll total and median in the base currency" do
    get "/api/v1/insights"

    expect(json["summary"]).to include("headcount" => 6, "currency" => BASE_CURRENCY)
    expect(json["summary"]["annual_payroll_cents"]).to eq(6 * 55_000_00 + (15 * 1_000_00))
  end

  it "states the suppression threshold, so the UI can explain a blank cell" do
    get "/api/v1/insights"

    expect(json["meta"]).to include("minimum_group_size" => Insights::Overview::MINIMUM_GROUP_SIZE,
                                    "base_currency" => BASE_CURRENCY)
  end

  it "applies filters" do
    get "/api/v1/insights", params: { country_code: "FR" }

    expect(json["summary"]).to include("headcount" => 0, "annual_payroll_cents" => 0)
  end

  it "returns zeroes rather than failing when there is no data at all" do
    SalaryRecord.delete_all

    get "/api/v1/insights"

    expect(response).to have_http_status(:ok)
    expect(json["summary"]).to include("headcount" => 0, "median_cents" => nil)
    expect(json["by_country"]).to be_empty
  end
end
