require "rails_helper"

# ADR-0010: `TokenStore` (both cockpit frontend services that open a cable
# connection — FlagsLiveService and this phase's CareActivityLiveService)
# sends the *entire* Authorization header value it stores, `"Bearer <jwt>"`,
# as the `token` query param — not the bare JWT. Every cable connection was
# silently rejected as unauthorized before this fix, since
# `Warden::JWTAuth::TokenDecoder` can't parse a `Bearer `-prefixed string.
# This spec is the regression guard: it exercises the connection with the
# exact value shape the real frontend sends, not just a bare token.
RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }
  let(:token) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  it "connects when given a bare JWT" do
    connect "/cable", params: { token: token }
    expect(connection.current_user).to eq(user)
  end

  it "connects when given a Bearer-prefixed token, matching what the frontend TokenStore actually sends" do
    connect "/cable", params: { token: "Bearer #{token}" }
    expect(connection.current_user).to eq(user)
  end

  it "rejects when no token is given" do
    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects an invalid token" do
    expect { connect "/cable", params: { token: "not-a-real-jwt" } }.to have_rejected_connection
  end

  it "rejects a well-formed token for a jti that no longer matches the user (revoked/rotated)" do
    stale_token = token
    user.update!(jti: SecureRandom.uuid)
    expect { connect "/cable", params: { token: stale_token } }.to have_rejected_connection
  end
end
