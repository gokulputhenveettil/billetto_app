require "test_helper"

class VotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:one)
    @event.update!(starts_at: 2.days.from_now)
    @published = {}
    @event_store = Object.new
    published = @published
    metadata = {}

    @event_store.define_singleton_method(:with_request_metadata) { |_env, &block| block.call }
    @event_store.define_singleton_method(:metadata) { metadata }
    @event_store.define_singleton_method(:with_metadata) do |values, &block|
      previous_metadata = metadata.dup
      metadata.merge!(values)
      block.call
    ensure
      metadata.replace(previous_metadata)
    end

    @event_store.define_singleton_method(:publish) do |event, stream_name:|
      metadata.each { |key, value| event.metadata[key] ||= value }
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
    with_vote_authentication(signed_in: false) do
      post event_votes_path(@event, type: "upvote")

      assert_redirected_to root_path
      assert_equal "Please sign in to vote.", flash[:alert]
      assert_nil @published[:event]
    end
  end

  test "publishes an upvote event for authenticated users" do
    user = OpenStruct.new(id: "user-123")

    with_vote_authentication(signed_in: true, user: user) do
      post event_votes_path(@event, type: "upvote")

      assert_redirected_to root_path
      assert_equal "Vote recorded successfully.", flash[:notice]
      assert_instance_of EventUpvoted, @published[:event]
      assert_equal "Event$#{@event.id}", @published[:stream_name]
      assert_equal @event.id, @published[:event].data[:event_id]
      assert_equal user.id, @published[:event].data[:user_id]
      assert_nil @published[:event].data[:previous_vote_type]
      assert_equal @published[:event].stream_names, [ @published[:stream_name], @published[:linked_stream_name] ]
      assert @published[:event].correlation_id.present?
      assert_equal @published[:event].correlation_id, @published[:event].causation_id
      assert_equal "User$user-123", @published[:linked_stream_name]
      assert_equal @published[:event].event_id, @published[:linked_event_id]
      assert_equal "upvote", Vote.find_by!(event: @event, user_id: user.id).vote_type
    end
  end

  test "rejects invalid vote types" do
    user = OpenStruct.new(id: "user-123")

    with_vote_authentication(signed_in: true, user: user) do
      post event_votes_path(@event, type: "bogus")

      assert_redirected_to root_path
      assert_equal "Invalid vote type.", flash[:alert]
      assert_nil @published[:event]
    end
  end

  test "rejects votes for past events" do
    @event.update!(starts_at: 1.day.ago)
    user = OpenStruct.new(id: "user-123")

    with_vote_authentication(signed_in: true, user: user) do
      post event_votes_path(@event, type: "upvote")

      assert_redirected_to root_path
      assert_equal "Voting is closed for past events.", flash[:alert]
      assert_nil @published[:event]
      assert_not Vote.exists?(event: @event, user_id: user.id)
    end
  end

  test "publishes a downvote event for authenticated users" do
    user = OpenStruct.new(id: "user-456")

    with_vote_authentication(signed_in: true, user: user) do
      post event_votes_path(@event, type: "downvote")

      assert_redirected_to root_path
      assert_equal "Vote recorded successfully.", flash[:notice]
      assert_instance_of EventDownvoted, @published[:event]
      assert_equal "Event$#{@event.id}", @published[:stream_name]
      assert_equal @event.id, @published[:event].data[:event_id]
      assert_equal user.id, @published[:event].data[:user_id]
      assert_equal "User$user-456", @published[:linked_stream_name]
      assert_equal "downvote", Vote.find_by!(event: @event, user_id: user.id).vote_type
    end
  end

  test "updates the existing vote when a user changes their vote" do
    user = OpenStruct.new(id: "user-123")
    Vote.create!(event: @event, user_id: user.id, vote_type: "upvote")

    with_vote_authentication(signed_in: true, user: user) do
      post event_votes_path(@event, type: "downvote")

      assert_equal "upvote", @published[:event].data[:previous_vote_type]
      assert_equal "downvote", Vote.find_by!(event: @event, user_id: user.id).vote_type
      assert_equal 1, Vote.where(event: @event, user_id: user.id).count
    end
  end

  private

  def with_vote_authentication(signed_in:, user: nil)
    controller = VotesController
    original_current_user = controller.instance_method(:current_user)
    original_user_signed_in = controller.instance_method(:user_signed_in?)

    controller.define_method(:current_user) { user }
    controller.define_method(:user_signed_in?) { signed_in }
    controller.send(:private, :current_user, :user_signed_in?)

    yield
  ensure
    controller.define_method(:current_user, original_current_user)
    controller.define_method(:user_signed_in?, original_user_signed_in)
    controller.send(:private, :current_user, :user_signed_in?)
  end
end
