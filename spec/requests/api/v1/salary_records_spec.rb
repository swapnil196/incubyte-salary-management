require "rails_helper"

RSpec.describe "POST /api/v1/employees/:employee_id/salary_records" do
  let(:employee) { create(:employee, hired_on: Date.new(2023, 1, 1)) }

  def post_change(**attrs)
    post "/api/v1/employees/#{employee.id}/salary_records",
         params: { salary_record: { amount: "70000", currency: BASE_CURRENCY,
                                    effective_from: "2025-01-01",
                                    change_reason: "merit" }.merge(attrs) },
         as: :json
  end

  def json = response.parsed_body

  before do
    create(:salary_record, employee: employee, amount_cents: 60_000_00,
                           base_amount_cents: 60_000_00,
                           effective_from: Date.new(2023, 1, 1), change_reason: "hire")
  end

  context "with a valid change" do
    it "returns 201 with the new record" do
      post_change

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("amount_cents" => 70_000_00, "change_reason" => "merit")
    end

    it "closes the previous record and leaves exactly one in force" do
      post_change

      expect(employee.salary_records.count).to eq(2)
      expect(employee.salary_records.current.count).to eq(1)
      expect(employee.reload.current_salary.amount_cents).to eq(70_000_00)
    end

    it "converts a foreign currency and records the rate used" do
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.92"),
                       rate_date: Date.new(2024, 12, 1))

      post_change(amount: "100000", currency: "USD")

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("base_amount_cents" => 92_000_00, "fx_rate" => "0.92")
    end

    it "accepts a decimal amount without losing precision" do
      post_change(amount: "70000.55")

      expect(json["data"]["amount_cents"]).to eq(70_000_55)
    end
  end

  context "with an invalid change" do
    it "rejects a date before the salary currently in force" do
      post_change(effective_from: "2022-06-01")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to be_present
      expect(employee.salary_records.count).to eq(1)
    end

    it "rejects a future effective date" do
      post_change(effective_from: (Date.current + 30).to_s)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to match(/future/i)
    end

    it "rejects an unrecognised change reason" do
      post_change(change_reason: "vibes")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to match(/reason/i)
    end

    it "rejects a zero amount" do
      post_change(amount: "0")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to match(/positive/i)
    end

    it "rejects a malformed amount rather than coercing it to zero" do
      post_change(amount: "seventy thousand")

      expect(response).to have_http_status(:unprocessable_content)
      expect(employee.salary_records.count).to eq(1)
    end

    it "rejects an unknown currency" do
      post_change(currency: "EURO")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to match(/ISO 4217/)
    end

    it "reports a missing effective date instead of raising" do
      post_change(effective_from: "not-a-date")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to match(/date/i)
    end

    it "fails cleanly when no exchange rate exists for the currency" do
      post_change(amount: "100000", currency: "JPY")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to match(/rate/i)
      expect(employee.salary_records.count).to eq(1)
    end

    it "returns 404 for an employee that does not exist" do
      post "/api/v1/employees/999999/salary_records",
           params: { salary_record: { amount: "1", currency: BASE_CURRENCY,
                                      effective_from: "2025-01-01",
                                      change_reason: "merit" } },
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  context "mass assignment" do
    it "ignores attributes the client is not allowed to set" do
      post "/api/v1/employees/#{employee.id}/salary_records",
           params: { salary_record: { amount: "70000", currency: BASE_CURRENCY,
                                      effective_from: "2025-01-01", change_reason: "merit",
                                      base_amount_cents: 1, fx_rate: "99.0",
                                      employee_id: 12_345 } },
           as: :json

      expect(response).to have_http_status(:created)
      # The base amount and rate are derived server-side, never taken from the
      # request, so a client cannot write a salary that converts to anything it
      # likes.
      expect(json["data"]).to include("base_amount_cents" => 70_000_00, "fx_rate" => "1.0",
                                      "employee_id" => employee.id)
    end
  end
end
