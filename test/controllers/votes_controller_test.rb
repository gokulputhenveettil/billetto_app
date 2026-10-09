require "test_helper"

class VotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:one)
    @published = {}
    @event_store = Object.new
    published = @published

    @event_store.define_singleton_method(:publish) do |event, stream_name:|
      published[:event] = event
      published[:stream_name] = stream_name
    end

    @event_store.define_singleton_method(:link) do |event_id, stream_name:|
      published[:linked_event_id] = event_id
      published[:linked_stream_name] = stream_name
    end

    Rails.configuration.event_store = @event_store
  end

  test "redirects unauthenticated users" do
    VotesController.any_instance.stubs(:user_signed_in?).returns(false)

    post event_votes_path(@event, type: "upvote")

    assert_redirected_to root_path
    assert_equal "Please sign in to vote.", flash[:alert]
    assert_nil @published[:event]
  end

  test "publishes an upvote event for authenticated users" do
    user = OpenStruct.new(id: "user-123")
    VotesController.any_instance.stubs(:current_user).returns(user)
    VotesController.any_instance.stubs(:user_signed_in?).returns(true)

    post event_votes_path(@event, type: "upvote")

    assert_redirected_to root_path
    assert_equal "Vote recorded successfully.", flash[:notice]
    assert_instance_of EventUpvoted, @published[:event]
    assert_equal "Event$#{@event.id}", @published[:stream_name]
    assert_equal @event.id, @published[:event].data[:event_id]
    assert_equal user.id, @published[:event].data[:user_id]
    assert_equal "User$user-123", @published[:linked_stream_name]
    assert_equal @published[:event].event_id, @published[:linked_event_id]
  end

  test "rejects invalid vote types" do
    VotesController.any_instance.stubs(:current_user).returns(OpenStruct.new(id: "user-123"))
    VotesController.any_instance.stubs(:user_signed_in?).returns(true)

    post event_votes_path(@event, type: "bogus")

    assert_redirected_to root_path
    assert_equal "Invalid vote type.", flash[:alert]
    assert_nil @published[:event]
  end

  test "publishes a downvote event for authenticated users" do
    user = OpenStruct.new(id: "user-456")
    VotesController.any_instance.stubs(:current_user).returns(user)
    VotesController.any_instance.stubs(:user_signed_in?).returns(true)

    post event_votes_path(@event, type: "downvote")

    assert_redirected_to root_path
    assert_equal "Vote recorded successfully.", flash[:notice]
    assert_instance_of EventDownvoted, @published[:event]
    assert_equal "Event$#{@event.id}", @published[:stream_name]
    assert_equal @event.id, @published[:event].data[:event_id]
    assert_equal user.id, @published[:event].data[:user_id]
    assert_equal "User$user-456", @published[:linked_stream_name]
  end
end
