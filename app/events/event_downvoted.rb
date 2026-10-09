class EventDownvoted < RubyEventStore::Event
  # Event triggered when a user downvotes an event.
  #
  # Attributes:
  # - event_id: The ID of the event being downvoted.
  # - user_id: The ID of the user who downvoted the event.
  # - voted_at: The timestamp when the downvote occurred.
  # Schema documentation:
  # data: {
  #   event_id: Integer,
  #   user_id: String,
  #   voted_at: String (ISO8601)
  # }
end
