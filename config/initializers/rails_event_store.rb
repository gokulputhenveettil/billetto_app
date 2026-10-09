require "rails_event_store"
require "ruby_event_store"
require "ruby_event_store/active_record"
require "json"
require "aggregate_root"

Rails.configuration.to_prepare do
  Rails.configuration.event_store = client = RailsEventStore::Client.new(
    repository: RubyEventStore::ActiveRecord::EventRepository.new(
      serializer: JSON
    )
  )

  # Register subscribers (Read Model Projectors)
  client.subscribe(VoteCounterProjector.new, to: [ EventUpvoted, EventDownvoted ])
end
