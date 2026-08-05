class AssistantConversation < ApplicationRecord
  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :assistant_conversations
  belongs_to :caregiver, foreign_key: :caregiver_ref, inverse_of: :assistant_conversations
  has_many :assistant_turns, foreign_key: :conversation_ref, inverse_of: :assistant_conversation, dependent: :destroy

  validates :language, presence: true
  validates :started_at, presence: true
end
