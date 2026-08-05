require "rails_helper"

RSpec.describe Domain::Enrollment::CodeSheetPdf do
  it "renders a valid PDF" do
    episode = create(:episode)

    bytes = described_class.render(
      episode: episode, plaintext_code: "ABCD2345", role: "primary", expires_at: 14.days.from_now
    )

    expect(bytes).to start_with("%PDF")
    expect(bytes.bytesize).to be > 500
  end
end
