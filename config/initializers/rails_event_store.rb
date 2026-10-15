require "rails_event_store"
require "ruby_event_store"
require "ruby_event_store/active_record"
require "json"
require "aggregate_root"
require_relative "../../lib/application_subscriptions"

Rails.configuration.to_prepare do
  Rails.configuration.event_store = client = RailsEventStore::Client.new(
    repository: RubyEventStore::ActiveRecord::EventRepository.new(
      serializer: JSON
    )
  )

  ApplicationSubscriptions.handlers.each do |handler, event_types|
    client.subscribe(handler, to: event_types)
  end
end
