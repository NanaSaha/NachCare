require "rails_helper"

RSpec.describe "Api::V1::Caregiver::Trends", type: :request do
  let(:episode) { create(:episode, start_date: 20.days.ago.to_date) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  it "requires authentication" do
    get "/api/v1/caregiver/trends"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns weight/symptom/adherence points within the episode window, oldest first" do
    create(:check_in, episode: episode, caregiver: caregiver, effective_date: 3.days.ago.to_date,
      weight_kg: 70.0, symptoms: { "breathless_at_rest" => true, "fatigue_increased" => false },
      med_status: { "1" => "taken", "2" => "missed" })
    create(:check_in, episode: episode, caregiver: caregiver, effective_date: 1.day.ago.to_date,
      weight_kg: 71.5, symptoms: {}, med_status: {})

    get "/api/v1/caregiver/trends", headers: auth_header

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["window_days"]).to eq(20)
    expect(body["points"].size).to eq(2)

    first = body["points"].first
    expect(first["weight_kg"]).to eq("70.0")
    expect(first["symptom_count"]).to eq(1)
    expect(first["adherence_pct"]).to eq(50)

    second = body["points"].second
    expect(second["adherence_pct"]).to be_nil
  end
end
