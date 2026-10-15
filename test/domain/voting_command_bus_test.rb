require "test_helper"

class VotingCommandBusTest < ActiveSupport::TestCase
  test "wraps command execution in a transaction, instrumentation, and event metadata" do
    original_event_store = Rails.configuration.event_store
    metadata = {}
    event_store = Object.new
    event_store.define_singleton_method(:metadata) { metadata }
    event_store.define_singleton_method(:with_metadata) do |values, &block|
      previous_metadata = metadata.dup
      metadata.merge!(values)
      block.call
    ensure
      metadata.replace(previous_metadata)
    end
    Rails.configuration.event_store = event_store

    handled_command = nil
    execution_metadata = nil
    handler = Object.new
    handler.define_singleton_method(:call) do |command|
      raise "command must execute in a database transaction" unless ActiveRecord::Base.connection.transaction_open?

      handled_command = command
      execution_metadata = event_store.metadata.dup
    end
    command_bus = Arkency::CommandBus.new.register(Voting::CastVote, handler)
    command = Voting::CastVote.new(event_id: 1, user_id: "user-123", vote_type: "upvote")
    notification = nil
    subscriber = ActiveSupport::Notifications.subscribe("command.voting.cast_vote") do |*args|
      notification = ActiveSupport::Notifications::Event.new(*args)
    end

    Voting::CommandBus.new(command_bus).call(command)

    assert_same command, handled_command
    assert_equal command.message_id, execution_metadata[:correlation_id]
    assert_equal command.message_id, execution_metadata[:causation_id]
    assert_equal command.message_id, notification.payload[:command_id]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    Rails.configuration.event_store = original_event_store
  end
end
