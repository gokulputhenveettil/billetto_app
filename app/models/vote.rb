class Vote < ApplicationRecord
  belongs_to :event

  validates :user_id, presence: true
  validates :vote_type, inclusion: { in: %w[upvote downvote] }
  validates :user_id, uniqueness: { scope: :event_id }
end
