class EventUpvoted < RubyEventStore::Event
  # Schema documentation:
  # data: {
  #   event_id: Integer,
  #   user_id: String,
  #   voted_at: String (ISO8601)
  # }
end
