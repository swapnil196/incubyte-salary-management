require "rails_helper"

RSpec.describe "HTTP Basic authentication" do
  around do |example|
    original = ENV.to_h.slice("BASIC_AUTH_USERNAME", "BASIC_AUTH_PASSWORD")
    example.run
    ENV["BASIC_AUTH_USERNAME"] = original["BASIC_AUTH_USERNAME"]
    ENV["BASIC_AUTH_PASSWORD"] = original["BASIC_AUTH_PASSWORD"]
  end

  def credentials(user, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(user, password) }
  end

  context "when BASIC_AUTH_PASSWORD is not set" do
    before { ENV["BASIC_AUTH_PASSWORD"] = nil }

    it "lets requests through, so development and tests are unaffected" do
      get "/api/v1/employees"

      expect(response).to have_http_status(:ok)
    end
  end

  context "when BASIC_AUTH_PASSWORD is set" do
    before do
      ENV["BASIC_AUTH_USERNAME"] = "hr"
      ENV["BASIC_AUTH_PASSWORD"] = "correct-horse"
    end

    it "challenges an unauthenticated API request" do
      get "/api/v1/employees"

      expect(response).to have_http_status(:unauthorized)
    end

    it "challenges an unauthenticated page request" do
      get "/"

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts the right credentials" do
      get "/api/v1/employees", headers: credentials("hr", "correct-horse")

      expect(response).to have_http_status(:ok)
    end

    it "rejects a wrong password" do
      get "/api/v1/employees", headers: credentials("hr", "wrong")

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a wrong username" do
      get "/api/v1/employees", headers: credentials("intruder", "correct-horse")

      expect(response).to have_http_status(:unauthorized)
    end

    it "leaves the health check reachable, so the platform can still probe it" do
      get "/up"

      expect(response).to have_http_status(:ok)
    end
  end
end
