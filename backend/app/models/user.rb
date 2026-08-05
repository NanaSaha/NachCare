class User < ApplicationRecord
  # Provides the before_create jti-generation callback plus .jwt_revoked?/
  # .revoke_jwt used below via `jwt_revocation_strategy: self` — required,
  # not optional; without it jti is never populated (NOT NULL violation on
  # create) despite the devise() call looking complete on its own.
  include Devise::JWT::RevocationStrategies::JTIMatcher

  ROLES = %w[ward_nurse nurse physician site_admin sysadmin analyst].freeze

  # :two_factor_authenticatable replaces :database_authenticatable (never
  # load both — devise-two-factor's README calls this a security issue,
  # since Warden would let a user bypass OTP by hitting the plain
  # database-authenticatable strategy). It still allows password-only login
  # until otp_required_for_login is set true for that user.
  devise :two_factor_authenticatable, :recoverable, :trackable, :validatable,
    :jwt_authenticatable, jwt_revocation_strategy: self

  belongs_to :site, foreign_key: :site_ref, inverse_of: :users

  validates :role, inclusion: { in: ROLES }
end
