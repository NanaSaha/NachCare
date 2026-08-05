require "rails_helper"

RSpec.describe CheckInPhoto do
  def attach_fake(photo, content_type: "image/jpeg")
    photo.image.attach(io: StringIO.new("x" * 10), filename: "test.jpg", content_type: content_type)
  end

  it "is invalid without an attached image" do
    photo = build(:check_in_photo)
    expect(photo).not_to be_valid
    expect(photo.errors[:image]).to be_present
  end

  it "is valid with an attached image of an allowed content type" do
    photo = build(:check_in_photo)
    attach_fake(photo)
    expect(photo).to be_valid
  end

  it "is valid with an attached video of an allowed content type" do
    photo = build(:check_in_photo)
    attach_fake(photo, content_type: "video/mp4")
    expect(photo).to be_valid
  end

  it "rejects a disallowed content type" do
    photo = build(:check_in_photo)
    attach_fake(photo, content_type: "application/pdf")
    expect(photo).not_to be_valid
    expect(photo.errors[:image]).to be_present
  end

  it "rejects a file over the size limit" do
    photo = build(:check_in_photo)
    attach_fake(photo)
    allow(photo.image).to receive(:byte_size).and_return(CheckInPhoto::MAX_BYTES + 1)
    expect(photo).not_to be_valid
    expect(photo.errors[:image]).to be_present
  end
end
