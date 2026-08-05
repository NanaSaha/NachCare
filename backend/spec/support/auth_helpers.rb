module AuthHelpers
  # Signs in via the real HTTP endpoint (not a Warden test-mode bypass) so
  # request specs exercise the same JWT issuance path a real client hits.
  def staff_auth_header(user, password: "correct horse battery staple")
    post "/api/v1/staff/sign_in", params: { user: { email: user.email, password: password } }, as: :json
    { "Authorization" => response.headers["Authorization"] }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
