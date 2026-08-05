class ApplicationController < ActionController::API
  # ActionController::API doesn't include this by default; Devise's own
  # controllers (SessionsController#destroy -> respond_to_on_destroy) call
  # `respond_to` directly, not just the overridable `respond_with`.
  include ActionController::MimeResponds
  include Pundit::Authorization

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :otp_attempt ])
  end

  def render_forbidden
    render json: { error: "forbidden" }, status: :forbidden
  end
end
