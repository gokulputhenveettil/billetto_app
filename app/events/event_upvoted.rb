class EventUpvoted < Voting::Fact
  SCHEMA = {
    event_id: Integer,
    user_id: String,
    previous_vote_type: [ String, NilClass ],
    voted_at: String
  }.freeze
end
