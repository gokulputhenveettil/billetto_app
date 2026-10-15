require "arkency/command_bus"

Rails.application.config.to_prepare do
  command_bus = Arkency::CommandBus.new
  command_bus.register(VoteCommand, VoteCommandHandler.new)

  Rails.configuration.command_bus = command_bus
end
