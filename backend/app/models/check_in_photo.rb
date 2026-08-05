# ADR-0011: the `check_in_photos` table (Section 5) was created at M0 as
# a bare join row (check_in_ref, timestamps only — no blob columns of its
# own), clearly intended as the record ActiveStorage attaches to rather
# than a single column on `check_ins` directly. One `CheckInPhoto` row per
# attached photo/video, `has_one_attached :image` each, so a check-in can
# carry zero, one, or (in a future pass) several attachments without a
# schema change — the caregiver UI this phase ships only ever creates one.
class CheckInPhoto < ApplicationRecord
  MAX_BYTES = 25.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif video/mp4 video/quicktime video/webm].freeze

  belongs_to :check_in, foreign_key: :check_in_ref, inverse_of: :check_in_photos
  has_one_attached :image

  validate :image_attached
  validate :image_content_type_allowed
  validate :image_size_within_limit

  private

  def image_attached
    errors.add(:image, "must be attached") unless image.attached?
  end

  def image_content_type_allowed
    return unless image.attached?

    errors.add(:image, "must be an image or video file") unless ALLOWED_CONTENT_TYPES.include?(image.content_type)
  end

  def image_size_within_limit
    return unless image.attached?

    errors.add(:image, "is too large (max #{MAX_BYTES / 1.megabyte}MB)") if image.byte_size > MAX_BYTES
  end
end
