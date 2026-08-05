class Message < ApplicationRecord
  SENDERS = %w[nurse caregiver system ai].freeze
  # ADR-0011: caregiver status-update media attachment (item #3). Reuses
  # ActiveStorage directly on Message (no join model needed, unlike
  # CheckInPhoto — there's exactly one attachment per message, not a
  # collection, so `has_one_attached` on the row itself is simplest).
  ALLOWED_MEDIA_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif video/mp4 video/quicktime video/webm].freeze
  MAX_MEDIA_BYTES = 25.megabytes

  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :messages

  has_one_attached :media

  validates :sender, inclusion: { in: SENDERS }
  # A caregiver status update may be media-only (no caption) — body_source
  # is only required when there's no attachment to carry the update.
  validates :body_source, presence: true, if: -> { !media.attached? }
  validate :media_content_type_allowed
  validate :media_size_within_limit

  private

  def media_content_type_allowed
    return unless media.attached?

    errors.add(:media, "must be an image or video file") unless ALLOWED_MEDIA_CONTENT_TYPES.include?(media.content_type)
  end

  def media_size_within_limit
    return unless media.attached?

    errors.add(:media, "is too large (max #{MAX_MEDIA_BYTES / 1.megabyte}MB)") if media.byte_size > MAX_MEDIA_BYTES
  end
end
