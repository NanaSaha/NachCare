require "rails_helper"

RSpec.describe "Security headers (M7 hardening)", type: :request do
  it "sets baseline security headers on every response" do
    get "/api/v1/health"

    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    expect(response.headers["X-Frame-Options"]).to eq("DENY")
    expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
    expect(response.headers["Content-Security-Policy"]).to eq("default-src 'none'")
  end

  it "does not set HSTS outside production (no HTTPS locally/in test)" do
    get "/api/v1/health"

    expect(response.headers["Strict-Transport-Security"]).to be_nil
  end
end
