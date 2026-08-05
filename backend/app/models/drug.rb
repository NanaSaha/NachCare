class Drug < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
