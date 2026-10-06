require "rails_helper"

RSpec.describe "GET /api/v1/employees" do
  let(:engineering) { create(:department, name: "Engineering") }
  let(:sales) { create(:department, name: "Sales") }
  let(:senior) { create(:job_level, name: "Senior", rank: 4) }
  let(:junior) { create(:job_level, name: "Junior", rank: 2) }

  def json = response.parsed_body

  def employee(**overrides)
    defaults = { department: engineering, job_level: senior, country_code: "DE" }
    create(:employee, :with_salary, **defaults.merge(overrides))
  end

  describe "the payload" do
    before do
      create(:pay_band, job_level: senior, country_code: "DE",
                        min_cents: 50_000_00, mid_cents: 60_000_00, max_cents: 70_000_00)
      employee(first_name: "Ada", last_name: "Lovelace", salary_cents: 66_000_00)
      get "/api/v1/employees"
    end

    it "returns 200 with a data array and pagination metadata" do
      expect(response).to have_http_status(:ok)
      expect(json["data"].size).to eq(1)
      expect(json["meta"]).to include("page" => 1, "total_count" => 1, "total_pages" => 1)
    end

    it "includes the employee, their salary and their position in the band" do
      row = json["data"].first

      expect(row).to include("full_name" => "Ada Lovelace", "department" => "Engineering",
                             "job_level" => "Senior", "status" => "active")
      expect(row["salary"]).to include("amount_cents" => 66_000_00, "currency" => BASE_CURRENCY)
      expect(row["band"]).to include("compa_ratio" => 1.1, "status" => "within_band")
    end

    it "renders JSON, never the HTML shell" do
      expect(response.media_type).to eq("application/json")
    end
  end

  describe "pagination" do
    before { create_list(:employee, 7, :with_salary, department: engineering, job_level: senior) }

    it "defaults to the first page" do
      get "/api/v1/employees"

      expect(json["meta"]).to include("page" => 1, "per_page" => 25, "total_count" => 7)
    end

    it "returns the requested page" do
      get "/api/v1/employees", params: { per_page: 3, page: 3 }

      expect(json["data"].size).to eq(1)
      expect(json["meta"]).to include("page" => 3, "total_pages" => 3)
    end

    it "caps per_page, so one request cannot dump the whole salary table" do
      get "/api/v1/employees", params: { per_page: 999_999 }

      expect(json["meta"]["per_page"]).to eq(Employees::Query::MAX_PER_PAGE)
    end

    it "falls back to the default for a nonsense per_page" do
      get "/api/v1/employees", params: { per_page: "-5" }

      expect(json["meta"]["per_page"]).to eq(Employees::Query::DEFAULT_PER_PAGE)
    end

    it "treats a page below 1 as the first page" do
      get "/api/v1/employees", params: { page: "0" }

      expect(json["meta"]["page"]).to eq(1)
    end
  end

  describe "filtering" do
    before do
      employee(first_name: "Dee", country_code: "DE", department: engineering, job_level: senior)
      employee(first_name: "Fran", country_code: "FR", department: sales, job_level: junior)
      create(:employee, :terminated, :with_salary, first_name: "Gone",
                                                   department: engineering, job_level: senior)
    end

    it "returns only active employees by default" do
      get "/api/v1/employees"

      expect(json["data"].map { |r| r["full_name"] }).not_to include(a_string_starting_with("Gone"))
      expect(json["meta"]["status"]).to eq("active")
    end

    it "can return terminated employees" do
      get "/api/v1/employees", params: { status: "terminated" }

      expect(json["data"].size).to eq(1)
      expect(json["data"].first["status"]).to eq("terminated")
    end

    it "can return everyone" do
      get "/api/v1/employees", params: { status: "all" }

      expect(json["meta"]["total_count"]).to eq(3)
    end

    it "ignores an unrecognised status rather than returning nothing" do
      get "/api/v1/employees", params: { status: "banana" }

      expect(json["meta"]["status"]).to eq("active")
    end

    it "filters by country" do
      get "/api/v1/employees", params: { country_code: "FR" }

      expect(json["data"].size).to eq(1)
      expect(json["data"].first["country_code"]).to eq("FR")
    end

    it "filters by department and by job level" do
      get "/api/v1/employees", params: { department_id: sales.id }
      expect(json["data"].map { |r| r["department"] }).to all(eq("Sales"))

      get "/api/v1/employees", params: { job_level_id: junior.id }
      expect(json["data"].map { |r| r["job_level"] }).to all(eq("Junior"))
    end
  end

  describe "search" do
    before do
      employee(first_name: "Ada", last_name: "Lovelace", email: "ada@acme.example")
      employee(first_name: "Grace", last_name: "Hopper", email: "grace@acme.example")
    end

    it "matches on name" do
      get "/api/v1/employees", params: { q: "hopp" }

      expect(json["data"].map { |r| r["full_name"] }).to eq([ "Grace Hopper" ])
    end

    it "matches on email" do
      get "/api/v1/employees", params: { q: "ada@" }

      expect(json["data"].size).to eq(1)
    end

    it "treats a LIKE wildcard as a literal character" do
      # Without escaping, "%" matches every row and the user silently gets the
      # whole directory back instead of nothing.
      get "/api/v1/employees", params: { q: "%" }

      expect(json["data"]).to be_empty
    end

    it "ignores a blank search" do
      get "/api/v1/employees", params: { q: "   " }

      expect(json["meta"]["total_count"]).to eq(2)
    end
  end

  describe "sorting" do
    before do
      employee(last_name: "Zeta", salary_cents: 40_000_00)
      employee(last_name: "Alpha", salary_cents: 90_000_00)
    end

    it "sorts by name ascending by default" do
      get "/api/v1/employees"

      expect(json["data"].map { |r| r["full_name"] }).to eq([ "Ada Alpha", "Ada Zeta" ])
    end

    it "sorts by salary descending when asked" do
      get "/api/v1/employees", params: { sort: "salary", direction: "desc" }

      expect(json["data"].map { |r| r["salary"]["amount_cents"] }).to eq([ 90_000_00, 40_000_00 ])
    end

    it "falls back to the default sort for an unrecognised column" do
      get "/api/v1/employees", params: { sort: "favourite_colour" }

      expect(json["meta"]["sort"]).to eq("name")
    end

    it "does not execute SQL smuggled through the sort parameter" do
      get "/api/v1/employees",
          params: { sort: "employees.id; DROP TABLE employees--", direction: "asc" }

      expect(response).to have_http_status(:ok)
      expect(json["meta"]["sort"]).to eq("name")
      expect(Employee.count).to eq(2)
    end

    it "ignores an unrecognised sort direction" do
      get "/api/v1/employees", params: { direction: "sideways" }

      expect(json["meta"]["direction"]).to eq("asc")
    end
  end

  describe "query count" do
    it "does not issue a query per row" do
      create_list(:employee, 20, :with_salary, department: engineering, job_level: senior)

      # One count, one page fetch. Everything the serializer needs is selected
      # in that single query, so adding rows must not add queries.
      expect { get "/api/v1/employees", params: { per_page: 20 } }
        .to make_database_queries(count: 2)
    end
  end
end
