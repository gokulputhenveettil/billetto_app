require "test_helper"

class VoteCounterProjectorTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
    @projector = VoteCounterProjector.new
  end

  test "counts the current vote and updates counts when it changes" do
    vote = Vote.create!(event: @event, user_id: "user-123", vote_type: "upvote")
    upvote_event = EventUpvoted.new(data: { event_id: @event.id, user_id: vote.user_id })
    @projector.call(upvote_event)

    vote.update!(vote_type: "downvote")
    downvote_event = EventDownvoted.new(data: { event_id: @event.id, user_id: vote.user_id })
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

    @projector.call(EventUpvoted.new(data: { event_id: @event.id }))

    @event.reload
    assert_equal 1, @event.upvotes_count
    assert_equal 1, @event.downvotes_count
  end
end
