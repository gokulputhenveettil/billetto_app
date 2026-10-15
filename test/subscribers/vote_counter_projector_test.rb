require "test_helper"

class VoteCounterProjectorTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
    @projector = VoteCounterProjector.new
  end

  test "counts the current vote and updates counts when it changes" do
    vote = Vote.create!(event: @event, user_id: "user-123", vote_type: "upvote")
    upvote_event = vote_event(EventUpvoted, vote.user_id)
    @projector.call(upvote_event)

    vote.update!(vote_type: "downvote")
    downvote_event = vote_event(EventDownvoted, vote.user_id)
    @projector.call(downvote_event)
    @projector.call(downvote_event)
    @projector.call(upvote_event)

    @event.reload
    assert_equal 0, @event.upvotes_count
    assert_equal 1, @event.downvotes_count
  end

  test "counts multiple users with different vote types" do
    Vote.create!(event: @event, user_id: "user-123", vote_type: "upvote")
    Vote.create!(event: @event, user_id: "user-456", vote_type: "downvote")

    @projector.call(vote_event(EventUpvoted, "user-123"))

    @event.reload
    assert_equal 1, @event.upvotes_count
    assert_equal 1, @event.downvotes_count
  end

  test "rebuilds current votes from the event stream" do
    Vote.create!(event: @event, user_id: "user-123", vote_type: "upvote")
    Vote.create!(event: @event, user_id: "stale-user", vote_type: "upvote")
    events = [
      vote_event(EventUpvoted, "user-123"),
      vote_event(EventDownvoted, "user-456"),
      vote_event(EventDownvoted, "user-123")
    ]
    stream_reader = Object.new
    stream_reader.define_singleton_method(:stream) { |_name| events }
    event_store = Object.new
    event_store.define_singleton_method(:read) { stream_reader }

    @projector.rebuild!(@event.id, event_store: event_store)

    assert_equal "downvote", Vote.find_by!(event: @event, user_id: "user-123").vote_type
    assert_equal "downvote", Vote.find_by!(event: @event, user_id: "user-456").vote_type
    assert_not Vote.exists?(event: @event, user_id: "stale-user")
    @event.reload
    assert_equal 0, @event.upvotes_count
    assert_equal 2, @event.downvotes_count
  end

  test "registers its handlers for both voting facts" do
    subscriptions = Voting.subscriptions

    assert_includes subscriptions.values.flatten, EventUpvoted
    assert_includes subscriptions.values.flatten, EventDownvoted
  end

  private

  def vote_event(event_class, user_id)
    event_class.strict(
      data: {
        event_id: @event.id,
        user_id: user_id,
        previous_vote_type: nil,
        voted_at: Time.current.iso8601
      }
    )
  end
end
