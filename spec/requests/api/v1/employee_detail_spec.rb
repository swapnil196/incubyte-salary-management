require "rails_helper"

RSpec.describe "GET /api/v1/employees/:id" do
  let(:level) { create(:job_level, name: "Senior", rank: 4) }
  let(:employee) do
    create(:employee, first_name: "Ada", last_name: "Lovelace",
                      country_code: "DE", job_level: level, hired_on: Date.new(2023, 1, 1))
  end

  def json = response.parsed_body["data"]

  before do
    create(:pay_band, job_level: level, country_code: "DE",
                      min_cents: 50_000_00, mid_cents: 60_000_00, max_cents: 70_000_00)
  end

  context "with a salary history" do
    before do
      create(:salary_record, employee: employee, amount_cents: 50_000_00,
                             base_amount_cents: 50_000_00, change_reason: "hire",
                             effective_from: Date.new(2023, 1, 1),
                             effective_to: Date.new(2024, 1, 1))
      create(:salary_record, employee: employee, amount_cents: 55_000_00,
                             base_amount_cents: 55_000_00, change_reason: "merit",
                             effective_from: Date.new(2024, 1, 1),
                             effective_to: Date.new(2025, 1, 1))
      create(:salary_record, employee: employee, amount_cents: 66_000_00,
                             base_amount_cents: 66_000_00, change_reason: "promotion",
                             effective_from: Date.new(2025, 1, 1))
      get "/api/v1/employees/#{employee.id}"
    end

    it "returns the profile" do
      expect(response).to have_http_status(:ok)
      expect(json).to include("full_name" => "Ada Lovelace", "status" => "active",
                              "country_code" => "DE")
      expect(json["job_level"]).to include("name" => "Senior", "rank" => 4)
    end

    it "returns the salary currently in force" do
      expect(json["current_salary"]).to include("amount_cents" => 66_000_00)
    end

    it "returns the whole history, newest first" do
      expect(json["salary_history"].map { |r| r["amount_cents"] })
        .to eq([ 66_000_00, 55_000_00, 50_000_00 ])
      expect(json["salary_history"].map { |r| r["change_reason"] })
        .to eq(%w[promotion merit hire])
    end

    it "marks exactly one history entry as current" do
      expect(json["salary_history"].count { |r| r["current"] }).to eq(1)
    end

    it "reports the percentage rise over the previous record" do
      promotion, merit, hire = json["salary_history"]

      expect(promotion["change_from_previous"]).to eq(20.0)
      expect(merit["change_from_previous"]).to eq(10.0)
      # Nothing preceded the hire, so there is no rise to report.
      expect(hire["change_from_previous"]).to be_nil
    end

    it "reports where the current salary sits in the band" do
      expect(json["band"]).to include("compa_ratio" => 1.1, "status" => "within_band",
                                      "mid_cents" => 60_000_00)
    end

    it "exposes the rate used for each record, so a conversion can be explained" do
      expect(json["salary_history"].first).to include("fx_rate" => "1.0",
                                                      "base_currency" => BASE_CURRENCY)
    end
  end

  context "when the employee has no salary recorded" do
    before { get "/api/v1/employees/#{employee.id}" }

    it "returns the profile with nulls rather than failing" do
      expect(response).to have_http_status(:ok)
      expect(json["current_salary"]).to be_nil
      expect(json["salary_history"]).to be_empty
      expect(json["band"]).to include("status" => nil, "compa_ratio" => nil)
    end
  end

  context "when the employee does not exist" do
    it "returns 404 with a message, not an HTML error page" do
      get "/api/v1/employees/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end
  end
end
