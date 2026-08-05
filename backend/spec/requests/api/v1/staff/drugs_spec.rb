require "rails_helper"

RSpec.describe "Api::V1::Staff::Drugs", type: :request do
  let(:user) { create(:user) }

  before do
    Drug.find_or_create_by!(name: "Ramipril") { |d| d.category = "ACE inhibitor" }
    Drug.find_or_create_by!(name: "Rivaroxaban") { |d| d.category = "Anticoagulant" }
    Drug.find_or_create_by!(name: "Bisoprolol") { |d| d.category = "Beta blocker" }
  end

  it "requires authentication" do
    get "/api/v1/staff/drugs", params: { q: "ram" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "matches case-insensitively on a substring" do
    get "/api/v1/staff/drugs", params: { q: "ram" }, headers: staff_auth_header(user)

    expect(response).to have_http_status(:ok)
    names = response.parsed_body.map { |d| d["name"] }
    expect(names).to eq([ "Ramipril" ])
  end

  it "matches a substring anywhere in the name, not just the prefix" do
    get "/api/v1/staff/drugs", params: { q: "varo" }, headers: staff_auth_header(user)

    names = response.parsed_body.map { |d| d["name"] }
    expect(names).to eq([ "Rivaroxaban" ])
  end

  it "returns an empty list for a blank query rather than the whole table" do
    get "/api/v1/staff/drugs", params: { q: "" }, headers: staff_auth_header(user)

    expect(response.parsed_body).to eq([])
  end

  it "returns an empty list, not an error, for no matches" do
    get "/api/v1/staff/drugs", params: { q: "zzz-not-a-drug" }, headers: staff_auth_header(user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([])
  end
end
