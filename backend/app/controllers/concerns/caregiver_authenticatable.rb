# Caregivers authenticate by device token, not Devise/JWT (Section 2:
# "activation-code exchange -> long-lived device token, custom, no password
# for MVP"). The token is a bearer credential looked up by digest, same
# spirit as the staff JWT but a different mechanism entirely — there is no
# Warden strategy for it.
module CaregiverAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_caregiver!
  end

  private

  def authenticate_caregiver!
    token = request.headers["Authorization"].to_s.sub(/\ABearer /, "")
    @current_caregiver = token.present? ? Caregiver.find_by(device_token_digest: Domain::Enrollment::Activator.device_token_digest(token)) : nil

    render json: { error: "unauthorized" }, status: :unauthorized unless @current_caregiver
  end

  def current_caregiver
    @current_caregiver
  end
end
