class VoteCounterProjector
  def call(event)
    event_id = event.data.fetch(:event_id)
    event_record = Event.find_by(id: event_id)
    return unless event_record

    case event
    when EventUpvoted
      event_record.increment!(:upvotes_count)
    when EventDownvoted
      event_record.increment!(:downvotes_count)
    end
  end
end
