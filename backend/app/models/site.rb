class Site < ApplicationRecord
  has_many :users, foreign_key: :site_ref, inverse_of: :site
  has_many :patients, foreign_key: :site_ref, inverse_of: :site
  has_many :risk_model_promotions, foreign_key: :site_ref, inverse_of: false

  validates :name, presence: true
  validates :timezone, presence: true

  # UC-21/UC-05: the shadow-vs-promoted gate. AI WATCH flags, the
  # population risk-trend column, and cadence proposals are all invisible
  # until this is true for the patient's site.
  def ai_watch_promoted?
    RiskModelPromotion.promoted_for?(self)
  end
end
