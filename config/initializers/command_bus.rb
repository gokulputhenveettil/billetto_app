require "arkency/command_bus"

Rails.application.config.to_prepare do
  command_bus = Arkency::CommandBus.new
  command_bus.register(
    Voting::CastVote,
    ->(command) { Voting::Service.new(event_store: Rails.configuration.event_store).call(command) }
  )

  Rails.configuration.command_bus = Voting::CommandBus.new(command_bus)
end
