class Event < ApplicationRecord
    validates :billetto_id, presence: true, uniqueness: true
    validates :title, presence: true
    validates :starts_at, presence: true

    def total_votes
      upvotes_count + downvotes_count
    end

    def net_score
      upvotes_count - downvotes_count
    end
end
