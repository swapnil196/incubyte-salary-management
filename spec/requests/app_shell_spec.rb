require "rails_helper"

RSpec.describe "Application shell", type: :request do
  it "serves the React mount point at the root" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="root"')
  end

  it "serves the same shell for a client-side route so reloads work" do
    get "/employees/42"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="root"')
  end

  it "does not swallow unknown API paths into the SPA fallback" do
    get "/api/v1/nope"

    # An unrouted API path must 404, not quietly render the HTML shell. A
    # frontend calling a mistyped endpoint should fail loudly, not receive a
    # 200 full of markup it will try to parse as JSON.
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include('id="root"')
  end

  it "reports health" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
