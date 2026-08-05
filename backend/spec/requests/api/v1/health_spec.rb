require "rails_helper"

RSpec.describe "GET /api/v1/health", type: :request do
  it "returns 200 with db and redis both ok" do
    get "/api/v1/health"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["status"]).to eq("ok")
    expect(body["db"]).to eq(true)
    expect(body["redis"]).to eq(true)
  end
end
