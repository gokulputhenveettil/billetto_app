class VoteCommandHandler
  def call(command)
    event = Event.find(command.event_id)

    event.with_lock do
      vote = Vote.find_or_initialize_by(event: event, user_id: command.user_id.to_s)
      previous_vote_type = vote.vote_type
      vote.update!(vote_type: command.vote_type)

      domain_event = vote_event_class(command.vote_type).new(
        data: {
          event_id: event.id,
          user_id: command.user_id,
          previous_vote_type: previous_vote_type,
          voted_at: Time.current.iso8601
        }
      )

      event_store = Rails.configuration.event_store
      event_store.publish(domain_event, stream_name: "Event$#{event.id}")
      event_store.link(domain_event.event_id, stream_name: "User$#{command.user_id}")
    end
  end

  private

  def vote_event_class(vote_type)
    case vote_type
    when "upvote" then EventUpvoted
    when "downvote" then EventDownvoted
    else raise ArgumentError, "Unsupported vote type: #{vote_type.inspect}"
    end
  end
end
