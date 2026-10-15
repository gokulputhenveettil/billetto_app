module Voting
  class Service
    def initialize(event_store:)
      @event_store = event_store
    end

    def call(command)
      event = Event.find(command.event_id)

      event.with_lock do
        raise EventClosed if event.starts_at <= Time.current

        vote = Vote.find_or_initialize_by(event: event, user_id: command.user_id)
        previous_vote_type = vote.vote_type
        vote.update!(vote_type: command.vote_type)

        domain_event = vote_event_class(command.vote_type).strict(
          data: {
            event_id: event.id,
            user_id: command.user_id,
            previous_vote_type: previous_vote_type,
            voted_at: Time.current.iso8601
          }
        )
        streams = domain_event.stream_names

        @event_store.publish(domain_event, stream_name: streams.first)
        streams.drop(1).each do |stream_name|
          @event_store.link(domain_event.event_id, stream_name: stream_name)
        end
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
end
