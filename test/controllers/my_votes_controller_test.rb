require "test_helper"

class MyVotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Event.update_all(image_url: nil)
  end

  test "requires authentication" do
    with_my_votes_authentication(signed_in: false) do
      get my_votes_path

      assert_redirected_to root_path
      assert_equal "Please sign in to vote.", flash[:alert]
    end
  end

  test "lists the signed-in user's upvoted and downvoted events with their vote type" do
    user = OpenStruct.new(id: "user-123")
    liked_event = create_event("liked-event", "Liked event", 2.days.from_now)
    disliked_event = create_event("disliked-event", "Disliked event", 1.day.from_now)
    create_event("other-event", "Other event", 3.days.from_now)
    Vote.create!(event: liked_event, user_id: user.id, vote_type: "upvote")
    Vote.create!(event: disliked_event, user_id: user.id, vote_type: "downvote")
    Vote.create!(event: liked_event, user_id: "someone-else", vote_type: "downvote")

    with_my_votes_authentication(signed_in: true, user: user) do
      get my_votes_path

      assert_response :success
      assert_select ".event-card h2", text: "Liked event"
      assert_select ".event-card h2", text: "Disliked event"
      assert_select ".event-card h2", count: 2
      assert_select ".event-user-vote", text: "Your vote: Liked"
      assert_select ".event-user-vote", text: "Your vote: Disliked"
      assert_select ".navbar-navigation .navbar-link[aria-current='page']", text: "My voted events"
    end
  end

  test "returns the next page of votes for scrolling" do
    user = OpenStruct.new(id: "user-123")
    21.times do |index|
      event = create_event("page-event-#{index}", "Page event #{index}", index.days.from_now)
      Vote.create!(event: event, user_id: user.id, vote_type: "upvote")
    end

    with_my_votes_authentication(signed_in: true, user: user) do
      get my_votes_path

      assert_select ".event-card", EventsController::EVENTS_PER_PAGE
      assert_select ".events-load-more[href='/my-votes?page=2']"

      get my_votes_path(page: 2), headers: { "X-Requested-With" => "XMLHttpRequest" }

      assert_response :success
      assert_equal "", response.headers["X-Next-Page"]
      assert_select ".event-card", 1
    end
  end

  private

  def create_event(billetto_id, title, starts_at)
    Event.create!(billetto_id: billetto_id, title: title, starts_at: starts_at)
  end

  def with_my_votes_authentication(signed_in:, user: nil)
    controller = MyVotesController
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
