require "rails_helper"

RSpec.describe "Api::V1::Caregiver::Home", type: :request do
  let(:episode) { create(:episode) }
  let!(:caregiver) { create(:caregiver, episode: episode, display_name: "Sabine") }
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  it "requires authentication" do
    get "/api/v1/caregiver/home"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the caregiver profile, active care plan medications, and last weight" do
    care_plan = create(:care_plan, episode: episode, active: true)
    med = create(:medication, care_plan: care_plan, name: "Ramipril", critical: true)
    create(:check_in, episode: episode, caregiver: caregiver, effective_date: 2.days.ago.to_date, weight_kg: 71.2)
    create(:check_in, episode: episode, caregiver: caregiver, effective_date: 1.day.ago.to_date, weight_kg: 70.5)

    get "/api/v1/caregiver/home", headers: auth_header

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["caregiver"]["display_name"]).to eq("Sabine")
    expect(body["medications"]).to contain_exactly(
      { "id" => med.id, "name" => "Ramipril", "critical" => true, "schedule" => { "times" => [], "instructions" => nil } }
    )
    expect(body["last_weight_kg"]).to eq("70.5")
  end

  it "handles no care plan / no check-ins gracefully" do
    get "/api/v1/caregiver/home", headers: auth_header

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["medications"]).to eq([])
    expect(body["last_weight_kg"]).to be_nil
    expect(body["diet_rules"]).to be_nil
    expect(body["care_instructions"]).to be_nil
  end

  # Product-owner request (post-M7, ADR-0010): "when the caregiver logs in
  # they see all information uploaded by the nurse/dr" — diet rules, home
  # care instructions, and each medication's full schedule.
  it "returns diet_rules, care_instructions, and each medication's schedule" do
    care_plan = create(:care_plan, episode: episode, active: true,
      diet_rules: "Low salt, 1.5L fluid limit", care_instructions: "Weigh every morning before breakfast.")
    create(:medication, care_plan: care_plan, name: "Furosemide", critical: true,
      schedule: { "times" => [ "20:00", "08:00" ], "instructions" => "1 tablet with food" })

    get "/api/v1/caregiver/home", headers: auth_header

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["diet_rules"]).to eq("Low salt, 1.5L fluid limit")
    expect(body["care_instructions"]).to eq("Weigh every morning before breakfast.")
    med = body["medications"].first
    expect(med["schedule"]).to eq({ "times" => [ "08:00", "20:00" ], "instructions" => "1 tablet with food" })
  end
end
