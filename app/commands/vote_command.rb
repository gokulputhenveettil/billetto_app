class VoteCommand
  attr_reader :event_id, :user_id, :vote_type

  def initialize(event_id:, user_id:, vote_type:)
    @event_id = event_id
    @user_id = user_id
    @vote_type = vote_type
  end
end
