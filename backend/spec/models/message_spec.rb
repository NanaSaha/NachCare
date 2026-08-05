require "rails_helper"

RSpec.describe Message do
  it "is valid with a known sender and a body" do
    message = build(:message)
    expect(message).to be_valid
  end

  it "rejects an unknown sender" do
    message = build(:message, sender: "not_a_real_sender")
    expect(message).not_to be_valid
  end

  it "requires body_source" do
    message = build(:message, body_source: nil)
    expect(message).not_to be_valid
  end

  # ADR-0011: caregiver status-update media attachment (item #3).
  it "is valid with only media attached and no body_source (media-only status update)" do
    message = build(:message, body_source: nil)
    message.media.attach(io: StringIO.new("x" * 10), filename: "test.jpg", content_type: "image/jpeg")
    expect(message).to be_valid
  end

  it "rejects a disallowed media content type" do
    message = build(:message)
    message.media.attach(io: StringIO.new("x" * 10), filename: "test.pdf", content_type: "application/pdf")
    expect(message).not_to be_valid
    expect(message.errors[:media]).to be_present
  end

  it "rejects media over the size limit" do
    message = build(:message)
    message.media.attach(io: StringIO.new("x" * 10), filename: "test.jpg", content_type: "image/jpeg")
    allow(message.media).to receive(:byte_size).and_return(Message::MAX_MEDIA_BYTES + 1)
    expect(message).not_to be_valid
    expect(message.errors[:media]).to be_present
  end
end
