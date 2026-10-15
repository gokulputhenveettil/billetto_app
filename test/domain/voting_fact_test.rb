require "test_helper"

class VotingFactTest < ActiveSupport::TestCase
  test "validates its schema and declares event and user streams" do
    fact = EventUpvoted.strict(
      data: {
        event_id: 42,
        user_id: "user-123",
        previous_vote_type: nil,
        voted_at: Time.current.iso8601
      }
    )

    assert_equal [ "Event$42", "User$user-123" ], fact.stream_names
    assert_raises(ArgumentError) { EventUpvoted.strict(data: { event_id: 42 }) }
  end
end
