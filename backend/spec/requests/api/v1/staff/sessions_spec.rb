require "rails_helper"

RSpec.describe "Staff session auth (Devise + JWT)", type: :request do
  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  def sign_in!(email: user.email, pw: password, otp_attempt: nil)
    params = { user: { email: email, password: pw } }
    params[:user][:otp_attempt] = otp_attempt if otp_attempt
    post "/api/v1/staff/sign_in", params: params, as: :json
  end

  describe "POST /api/v1/staff/sign_in" do
    it "returns 200, a Bearer token, and the user's JSON on valid credentials" do
      sign_in!

      expect(response).to have_http_status(:ok)
      expect(response.headers["Authorization"]).to match(/\ABearer .+/)
      expect(response.parsed_body["user"]["email"]).to eq(user.email)
    end

    it "returns 401 and no token on an invalid password" do
      sign_in!(pw: "wrong password entirely")

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["Authorization"]).to be_nil
    end

    context "when the user has TOTP enabled" do
      let!(:user) do
        create(:user, password: password, password_confirmation: password).tap do |u|
          u.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
        end
      end

      it "rejects sign-in with password alone" do
        sign_in!

        expect(response).to have_http_status(:unauthorized)
      end

      it "accepts sign-in with a valid otp_attempt" do
        sign_in!(otp_attempt: user.current_otp)

        expect(response).to have_http_status(:ok)
        expect(response.headers["Authorization"]).to match(/\ABearer .+/)
      end

      it "rejects sign-in with an invalid otp_attempt" do
        sign_in!(otp_attempt: "000000")

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "authenticated requests" do
    it "GET /api/v1/staff/me succeeds with a valid Bearer token" do
      sign_in!
      token = response.headers["Authorization"]

      get "/api/v1/staff/me", headers: { "Authorization" => token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["email"]).to eq(user.email)
    end

    it "GET /api/v1/staff/me returns 401 with no token" do
      get "/api/v1/staff/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "GET /api/v1/staff/me returns 401 with a garbage token" do
      get "/api/v1/staff/me", headers: { "Authorization" => "Bearer not-a-real-token" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/staff/sign_out" do
    it "revokes the token so it can no longer authenticate" do
      sign_in!
      token = response.headers["Authorization"]

      delete "/api/v1/staff/sign_out", headers: { "Authorization" => token }
      expect(response).to have_http_status(:no_content)

      get "/api/v1/staff/me", headers: { "Authorization" => token }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
