require "rails_helper"

RSpec.describe "Api::V1::Caregiver::ContentItems", type: :request do
  let(:episode) { create(:episode, start_date: 10.days.ago.to_date) }
  let!(:caregiver) { create(:caregiver, episode: episode, language: "en") }
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  it "requires authentication" do
    get "/api/v1/caregiver/content_items"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns only approved items, each with unlock and completion state" do
    create(:content_item, kind: "article", week_no: 1, status: "approved",
      language_variants: { "en" => { "title" => "Week 1", "body" => "[PLACEHOLDER_CLINICAL] body" } })
    locked = create(:content_item, kind: "article", week_no: 5, status: "approved",
      language_variants: { "en" => { "title" => "Week 5", "body" => "later" } })
    create(:content_item, kind: "article", week_no: 1, status: "draft")

    get "/api/v1/caregiver/content_items", headers: auth_header

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body.size).to eq(2)

    week1 = body.find { |i| i["week_no"] == 1 }
    expect(week1["title"]).to eq("Week 1")
    expect(week1["unlocked"]).to be true
    expect(week1["completed"]).to be false

    week5 = body.find { |i| i["id"] == locked.id }
    expect(week5["unlocked"]).to be false
  end

  it "falls back to english when the caregiver's language has no authored variant" do
    caregiver.update!(language: "tr")
    create(:content_item, kind: "article", week_no: 1, status: "approved",
      language_variants: { "en" => { "title" => "English Title", "body" => "text" } })

    get "/api/v1/caregiver/content_items", headers: auth_header

    expect(response.parsed_body.first["title"]).to eq("English Title")
  end

  describe "POST /api/v1/caregiver/content_items/:id/complete" do
    it "records a completion event, idempotently" do
      item = create(:content_item, kind: "article", week_no: 1, status: "approved",
        language_variants: { "en" => { "title" => "T", "body" => "B" } })

      post "/api/v1/caregiver/content_items/#{item.id}/complete", headers: auth_header
      expect(response.parsed_body["completed"]).to be true

      expect {
        post "/api/v1/caregiver/content_items/#{item.id}/complete", headers: auth_header
      }.not_to change(AnalyticsEvent, :count)
    end
  end
end
