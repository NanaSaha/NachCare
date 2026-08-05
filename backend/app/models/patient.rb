class Patient < ApplicationRecord
  NYHA_CLASSES = %w[I II III IV].freeze

  belongs_to :site, foreign_key: :site_ref, inverse_of: :patients
  has_many :episodes, foreign_key: :patient_ref, inverse_of: :patient

  validates :pseudonym_code, presence: true, uniqueness: true
  validates :initials, presence: true
  validates :birth_year, presence: true
  validates :nyha_class, inclusion: { in: NYHA_CLASSES }
end
