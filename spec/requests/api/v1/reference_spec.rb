require "rails_helper"

RSpec.describe "GET /api/v1/reference" do
  def json = response.parsed_body["data"]

  let(:engineering) { create(:department, name: "Engineering") }
  let(:sales) { create(:department, name: "Sales") }
  let(:junior) { create(:job_level, name: "Junior", rank: 2) }
  let(:senior) { create(:job_level, name: "Senior", rank: 4) }

  before do
    create(:fx_rate, currency: "USD")
    # Reuse the explicit records, so the factory does not invent extra
    # departments and levels that would appear in these lists.
    create(:employee, country_code: "FR", department: sales, job_level: senior)
    create(:employee, country_code: "DE", department: engineering, job_level: junior)
  end

  it "returns departments alphabetically" do
    get "/api/v1/reference"

    expect(json["departments"].map { |d| d["name"] }).to eq(%w[Engineering Sales])
  end

  it "returns job levels in seniority order, not alphabetical order" do
    get "/api/v1/reference"

    expect(json["job_levels"].map { |l| l["name"] }).to eq(%w[Junior Senior])
  end

  it "returns only countries that actually have employees" do
    get "/api/v1/reference"

    expect(json["countries"]).to eq(%w[DE FR])
  end

  it "returns the currencies a salary can be recorded in" do
    get "/api/v1/reference"

    expect(json["currencies"]).to contain_exactly(BASE_CURRENCY, "USD")
    expect(json["base_currency"]).to eq(BASE_CURRENCY)
  end

  it "returns the permitted change reasons" do
    get "/api/v1/reference"

    expect(json["change_reasons"]).to eq(SalaryRecord::CHANGE_REASONS)
  end
end
