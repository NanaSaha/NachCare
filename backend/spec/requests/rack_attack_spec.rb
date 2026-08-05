require "rails_helper"

RSpec.describe "Rack::Attack rate limiting (M7 hardening)", type: :request do
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    example.run
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = false
  end

  describe "caregiver activation-code exchange" do
    it "throttles after 5 attempts from the same IP within the window" do
      episode = create(:episode)
      create(:caregiver, episode: episode)

      6.times { post "/api/v1/caregiver/activations", params: { code: "WRONGCODE" }, as: :json }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body["error"]).to eq("rate_limited")
    end

    it "allows requests under the limit" do
      episode = create(:episode)
      create(:caregiver, episode: episode)

      4.times { post "/api/v1/caregiver/activations", params: { code: "WRONGCODE" }, as: :json }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "staff sign-in" do
    it "throttles after 5 attempts from the same IP within the window" do
      user = create(:user)

      6.times { post "/api/v1/staff/sign_in", params: { user: { email: user.email, password: "wrong" } }, as: :json }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
