namespace :votes do
  desc "Rebuild current votes and event vote counts from Rails Event Store"
  task rebuild: :environment do
    projector = VoteCounterProjector.new
    Event.find_each do |event|
      projector.rebuild!(event.id)
    end
  end
end
