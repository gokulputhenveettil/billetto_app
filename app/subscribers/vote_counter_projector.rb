class VoteCounterProjector
  def self.subscriptions
    { new => [ EventUpvoted, EventDownvoted ] }
  end

  def call(event)
    return unless vote_type_for(event)

    event_id = data_value(event, :event_id)
    event_record = Event.find_by(id: event_id)
    return unless event_record

    event_record.with_lock { update_counts(event_record) }
  end

  def rebuild!(event_id, event_store: Rails.configuration.event_store)
    event_record = Event.find(event_id)

    event_record.with_lock do
      votes_by_user = {}
      event_store.read.stream("Event$#{event_id}").each do |event|
        vote_type = vote_type_for(event)
        next unless vote_type

        votes_by_user[data_value(event, :user_id).to_s] = vote_type
      end

      Vote.where(event_id: event_id).delete_all
      timestamp = Time.current
      Vote.insert_all!(
        votes_by_user.map do |user_id, vote_type|
          {
            event_id: event_record.id,
            user_id: user_id,
            vote_type: vote_type,
            created_at: timestamp,
            updated_at: timestamp
          }
        end
      ) if votes_by_user.any?
      update_counts(event_record)
    end
  end

  private

  def update_counts(event_record)
    vote_counts = Vote.where(event_id: event_record.id).group(:vote_type).count
    event_record.update!(
      upvotes_count: vote_counts.fetch("upvote", 0),
      downvotes_count: vote_counts.fetch("downvote", 0)
    )
  end

  def vote_type_for(event)
    case event
    when EventUpvoted then "upvote"
    when EventDownvoted then "downvote"
    end
  end

  def data_value(event, key)
    event.data.fetch(key) { event.data.fetch(key.to_s) }
  end
end
