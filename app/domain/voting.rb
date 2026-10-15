module Voting
  def self.subscriptions
    [ VoteCounterProjector.subscriptions ].reduce({}, :merge)
  end
end
