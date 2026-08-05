require "rails_helper"

RSpec.describe "Api::V1::Sites", type: :request do
  let(:site_a) { create(:site) }
  let(:site_b) { create(:site) }
  let(:sysadmin) { create(:user, role: "sysadmin", site: site_a) }
  let(:site_admin_a) { create(:user, role: "site_admin", site: site_a) }
  let(:nurse_a) { create(:user, role: "nurse", site: site_a) }

  describe "GET /api/v1/sites" do
    it "returns 401 without auth" do
      get "/api/v1/sites"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns all sites for sysadmin" do
      site_a
      site_b
      get "/api/v1/sites", headers: staff_auth_header(sysadmin)
      expect(response.parsed_body.size).to be >= 2
    end

    it "scopes non-sysadmin staff to just their own site" do
      site_b
      get "/api/v1/sites", headers: staff_auth_header(nurse_a)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.map { |s| s["id"] }
      expect(ids).to eq([ site_a.id ])
    end
  end

  describe "GET /api/v1/sites/:id" do
    it "same-site staff can view their own site" do
      get "/api/v1/sites/#{site_a.id}", headers: staff_auth_header(nurse_a)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq(site_a.name)
    end

    it "staff at another site get 403" do
      other_site_user = create(:user, role: "nurse", site: site_b)
      get "/api/v1/sites/#{site_a.id}", headers: staff_auth_header(other_site_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/sites" do
    it "sysadmin can create a site" do
      post "/api/v1/sites", params: { site: { name: "New Site", timezone: "Europe/Berlin" } },
        headers: staff_auth_header(sysadmin), as: :json

      expect(response).to have_http_status(:created)
      expect(Site.exists?(name: "New Site")).to be true
    end

    it "site_admin cannot create a site" do
      post "/api/v1/sites", params: { site: { name: "New Site", timezone: "Europe/Berlin" } },
        headers: staff_auth_header(site_admin_a), as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "records an audit event on creation" do
      expect {
        post "/api/v1/sites", params: { site: { name: "Audited Site", timezone: "Europe/Berlin" } },
          headers: staff_auth_header(sysadmin), as: :json
      }.to change(AuditEvent, :count).by(1)

      expect(AuditEvent.last.action).to eq("site.created")
    end
  end

  describe "PATCH /api/v1/sites/:id" do
    it "site_admin can update their own site" do
      patch "/api/v1/sites/#{site_a.id}", params: { site: { name: "Renamed" } },
        headers: staff_auth_header(site_admin_a), as: :json

      expect(response).to have_http_status(:ok)
      expect(site_a.reload.name).to eq("Renamed")
    end

    it "a nurse cannot update a site" do
      patch "/api/v1/sites/#{site_a.id}", params: { site: { name: "Renamed" } },
        headers: staff_auth_header(nurse_a), as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
