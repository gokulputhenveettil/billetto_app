require "securerandom"

module Voting
  class CastVote
    attr_reader :event_id, :user_id, :vote_type, :message_id, :correlation_id, :causation_id

    def initialize(event_id:, user_id:, vote_type:, message_id: SecureRandom.uuid)
      raise ArgumentError, "Unsupported vote type: #{vote_type.inspect}" unless %w[upvote downvote].include?(vote_type)

      @event_id = event_id
      @user_id = user_id.to_s
      @vote_type = vote_type
      @message_id = message_id
    end

    def correlate_with(message)
      @correlation_id = message.correlation_id || message.message_id
      @causation_id = message.message_id
      self
    end
  end
end
