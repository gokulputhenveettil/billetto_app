module Voting
  class CommandBus
    def initialize(command_bus)
      @command_bus = command_bus
    end

    def call(command)
      ActiveRecord::Base.transaction do
        ActiveSupport::Notifications.instrument(
          "command.voting.cast_vote",
          command_id: command.message_id,
          command_class: command.class.name
        ) do
          RubyEventStore::CorrelatedCommands.new(
            Rails.configuration.event_store,
            @command_bus
          ).call(command)
        end
      end
    end
  end
end
