require "rails_helper"
require "csv"

RSpec.describe "GET /api/v1/employees/export" do
  let(:senior) { create(:job_level, name: "Senior", rank: 4) }
  let(:engineering) { create(:department, name: "Engineering") }

  def csv = CSV.parse(response.body, headers: true)

  before do
    create(:pay_band, job_level: senior, country_code: "DE",
                      min_cents: 50_000_00, mid_cents: 60_000_00, max_cents: 70_000_00)
  end

  def employee(**overrides)
    defaults = { department: engineering, job_level: senior, country_code: "DE" }
    create(:employee, :with_salary, **defaults.merge(overrides))
  end

  it "returns a CSV attachment with a timestamped filename" do
    employee
    get "/api/v1/employees/export"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to match(/attachment; filename=.*employees-\d{8}-\d{6}\.csv/)
  end

  it "includes the employee, their salary and their band position" do
    employee(first_name: "Ada", last_name: "Lovelace", salary_cents: 66_000_00)
    get "/api/v1/employees/export"

    row = csv.first

    expect(row["First name"]).to eq("Ada")
    expect(row["Department"]).to eq("Engineering")
    expect(row["Salary (#{BASE_CURRENCY})"]).to eq("66000.0")
    expect(row["Compa-ratio"]).to eq("1.1")
    expect(row["Band status"]).to eq("within_band")
  end

  it "exports every matching row, not just the first page" do
    create_list(:employee, 30, :with_salary, department: engineering, job_level: senior)

    get "/api/v1/employees/export"

    expect(csv.length).to eq(30)
  end

  it "honours the filters that were applied on screen" do
    employee(country_code: "DE")
    employee(country_code: "FR")

    get "/api/v1/employees/export", params: { country_code: "FR" }

    expect(csv.length).to eq(1)
    expect(csv.first["Country"]).to eq("FR")
  end

  it "neutralises a formula smuggled in through an employee name" do
    # HR opens these in Excel. Without escaping, this cell executes.
    employee(first_name: "=cmd|' /C calc'!A0", last_name: "Exploit")

    get "/api/v1/employees/export"

    expect(csv.first["First name"]).to start_with("'=")
    expect(response.body).not_to match(/^=cmd/)
  end

  it "keeps amounts numeric so the spreadsheet can sum them" do
    employee(salary_cents: 66_000_00)

    get "/api/v1/employees/export"

    expect(csv.first["Salary amount"]).to eq("66000.0")
  end
end
