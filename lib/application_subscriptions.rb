module ApplicationSubscriptions
  def self.handlers
    Voting.subscriptions
  end
end
