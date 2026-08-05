class Caregiver < ApplicationRecord
  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :caregivers
  has_many :consents, foreign_key: :caregiver_ref, inverse_of: :caregiver
  has_many :notification_attempts, foreign_key: :caregiver_ref, inverse_of: :caregiver
  has_many :assistant_conversations, foreign_key: :caregiver_ref, inverse_of: :caregiver

  encrypts :contact

  validates :display_name, presence: true
  validates :relationship, presence: true
  validates :device_token_digest, uniqueness: true, allow_nil: true

  def activated?
    device_token_digest.present?
  end

  # `contact` is a single encrypted text column (Section 5) holding
  # {"phone" => ..., "email" => ...} as JSON — parsed/assigned as a hash so
  # callers never touch raw JSON.
  def contact_data
    return {} if contact.blank?

    JSON.parse(contact)
  rescue JSON::ParserError
    {}
  end

  def contact_data=(hash)
    self.contact = hash.to_json
  end

  def phone
    contact_data["phone"]
  end

  def email
    contact_data["email"]
  end
end
