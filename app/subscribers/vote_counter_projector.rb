class VoteCounterProjector
  def call(event)
    event_id = event.data.fetch(:event_id)
    return unless vote_type_for(event)

    event_record = Event.find_by(id: event_id)
    return unless event_record

    event_record.with_lock do
      vote_counts = Vote.where(event_id: event_id).group(:vote_type).count
      event_record.update!(
        upvotes_count: vote_counts.fetch("upvote", 0),
        downvotes_count: vote_counts.fetch("downvote", 0)
      )
    end
  end

  private

  def vote_type_for(event)
    case event
    when EventUpvoted then "upvote"
    when EventDownvoted then "downvote"
    end
  end
end
