require "rails_helper"

RSpec.describe WeeklyDigestJob do
  let(:site) { create(:site) }

  it "emails every site_admin/physician at the site a weekly pilot-metrics digest" do
    admin = create(:user, role: "site_admin", site: site, email: "admin@example.eu")
    physician = create(:user, role: "physician", site: site, email: "doc@example.eu")
    create(:user, role: "ward_nurse", site: site, email: "wardnurse@example.eu")
    other_site_admin = create(:user, role: "site_admin", site: create(:site), email: "otheradmin@example.eu")

    described_class.new.perform

    recipients = ActionMailer::Base.deliveries.map { |m| m.to.first }
    # Every site with site_admin/physician staff gets its own digest — the
    # other site's admin is a legitimate recipient too, just not a signal
    # that this site's ward_nurse wrongly got included.
    expect(recipients).to include(admin.email, physician.email, other_site_admin.email)
    expect(recipients).not_to include("wardnurse@example.eu")
  end

  it "includes the trailing-7-day pilot metrics in the email body" do
    admin = create(:user, role: "site_admin", site: site, email: "admin@example.eu")
    patient = create(:patient, site: site)
    episode = create(:episode, patient: patient)
    create(:flag, episode: episode, severity: "red", state: "resolved", breach: false)

    described_class.new.perform

    mail = ActionMailer::Base.deliveries.find { |m| m.to.first == admin.email }
    expect(mail.body.encoded).to include("RED-flag SLA compliance")
  end

  it "does nothing for a site with no site_admin/physician staff" do
    create(:user, role: "ward_nurse", site: site)

    expect { described_class.new.perform }.not_to(change { ActionMailer::Base.deliveries.count })
  end
end
