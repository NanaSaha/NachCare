require "rails_helper"

RSpec.describe "Api::V1::FeatureFlags", type: :request do
  it "exposes the AI kill-switch state without requiring auth" do
    get "/api/v1/feature_flags"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("assistant_enabled" => true, "copilot_enabled" => true)
  end
end
