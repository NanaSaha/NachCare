require "rails_helper"

RSpec.describe Domain::Ai::Pseudonymizer do
  it "builds PATIENT_{uuid8} from the patient's id" do
    patient = create(:patient, id: "12345678-90ab-cdef-1234-567890abcdef")
    expect(described_class.for_patient(patient)).to eq("PATIENT_12345678")
  end

  it "never includes initials, pseudonym_code, or birth_year" do
    patient = create(:patient)
    result = described_class.for_patient(patient)
    expect(result).not_to include(patient.initials)
    expect(result).not_to include(patient.pseudonym_code)
  end
end
