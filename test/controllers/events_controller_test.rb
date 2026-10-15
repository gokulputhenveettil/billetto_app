require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Event.update_all(image_url: nil)
  end

  test "lists events with the latest start time first" do
    later_event = Event.create!(
      billetto_id: "later-event",
      title: "Later event",
      starts_at: 2.days.from_now
    )
    earlier_event = Event.create!(
      billetto_id: "earlier-event",
      title: "Earlier event",
      starts_at: 1.day.from_now
    )

    get root_path

    assert_response :success
    assert_select ".event-card h2" do |headings|
      titles = headings.map(&:text)
      assert_operator titles.index(later_event.title), :<, titles.index(earlier_event.title)
    end
  end

  test "paginates the event list and provides the next page for scrolling" do
    22.times do |index|
      Event.create!(
        billetto_id: "paged-event-#{index}",
        title: "Paged event #{index}",
        starts_at: index.days.from_now
      )
    end

    get root_path

    assert_response :success
    assert_select ".event-card", EventsController::EVENTS_PER_PAGE
    assert_select ".events-load-more[href='/events?page=2']", text: "Load more events"

    get root_path(page: 2), headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :success
    assert_equal "", response.headers["X-Next-Page"]
    assert_select ".event-card", 4
  end

  test "disables like and dislike buttons for past events" do
    past_event = Event.create!(
      billetto_id: "past-event-voting-closed",
      title: "Past event",
      starts_at: 1.day.ago
    )
    controller = EventsController
    original_current_user = controller.instance_method(:current_user)
    original_user_signed_in = controller.instance_method(:user_signed_in?)
    controller.define_method(:current_user) { OpenStruct.new(id: "user-123") }
    controller.define_method(:user_signed_in?) { true }
    controller.send(:private, :current_user, :user_signed_in?)

    get root_path

    assert_response :success
    assert_select "form[action='#{event_votes_path(past_event, type: 'upvote')}'] button[disabled]"
    assert_select "form[action='#{event_votes_path(past_event, type: 'downvote')}'] button[disabled]"
  ensure
    controller.define_method(:current_user, original_current_user)
    controller.define_method(:user_signed_in?, original_user_signed_in)
    controller.send(:private, :current_user, :user_signed_in?)
  end
end
