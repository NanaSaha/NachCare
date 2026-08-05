require "rails_helper"

RSpec.describe Domain::Audit::Recorder do
  let(:user) { create(:user) }
  let(:caregiver) { create(:caregiver) }
  let(:patient) { create(:patient) }

  it "records a user-actor event resolving type/ref from the AR object" do
    event = described_class.record!(actor: user, action: "viewed_patient", entity: patient, payload: {})

    expect(event.actor_type).to eq("user")
    expect(event.actor_ref).to eq(user.id.to_s)
    expect(event.entity_type).to eq("patient")
    expect(event.entity_ref).to eq(patient.id.to_s)
  end

  it "records a caregiver actor" do
    event = described_class.record!(actor: caregiver, action: "submitted_check_in", entity: caregiver, payload: {})

    expect(event.actor_type).to eq("caregiver")
    expect(event.actor_ref).to eq(caregiver.id.to_s)
  end

  it "records system and ai actors without an actor_ref" do
    system_event = described_class.record!(actor: :system, action: "missed_checkin_scan", entity: patient, payload: {})
    ai_event = described_class.record!(actor: :ai, action: "drafted_triage_note", entity: patient, payload: {})

    expect(system_event.actor_type).to eq("system")
    expect(system_event.actor_ref).to be_nil
    expect(ai_event.actor_type).to eq("ai")
    expect(ai_event.actor_ref).to be_nil
  end

  it "raises for an unrecognized actor rather than silently guessing" do
    expect {
      described_class.record!(actor: "not-an-actor", action: "x", entity: patient, payload: {})
    }.to raise_error(Domain::Audit::Recorder::UnknownActor)
  end

  it "produces a payload_sha256 independent of hash key order (canonical form)" do
    a = described_class.record!(actor: user, action: "viewed_patient", entity: patient, payload: { b: 1, a: { z: 1, y: 2 } })
    b = described_class.record!(actor: user, action: "viewed_patient", entity: patient, payload: { a: { y: 2, z: 1 }, b: 1 })

    expect(a.payload_sha256).to eq(b.payload_sha256)
  end

  it "is deterministic: identical input produces identical payload_sha256 across repeated runs" do
    hashes = Array.new(20) do
      described_class.record!(
        actor: user, action: "viewed_patient", entity: patient,
        payload: { x: 1, nested: { z: 1, a: 2 } }
      ).payload_sha256
    end

    expect(hashes.uniq.size).to eq(1)
  end
end
