require "rails_helper"

# Product-owner feedback item #4 (ADR-0011). Same fan-out shape as
# FlagsChannel (M3) — site-scoped stream, sysadmin (no site_ref) rejected.
RSpec.describe NurseAlertsChannel, type: :channel do
  let(:site) { create(:site) }
  let(:nurse) { create(:user, role: "nurse", site: site) }

  before { stub_connection current_user: nurse }

  it "streams from the nurse's own site" do
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("nurse_alerts_site_#{site.id}")
  end

  it "rejects a connection whose user has no site_ref (matches FlagsChannel's existing defensive behavior)" do
    stub_connection current_user: instance_double(User, site_ref: nil)

    subscribe

    expect(subscription).to be_rejected
  end
end
