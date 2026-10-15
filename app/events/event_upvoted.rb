class EventUpvoted < RubyEventStore::Event
  # Schema documentation:
  # data: {
  #   event_id: Integer,
  #   user_id: String,
  #   previous_vote_type: String or nil,
  #   voted_at: String (ISO8601)
  # }
end
