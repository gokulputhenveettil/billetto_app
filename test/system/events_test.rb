require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  setup do
    Event.update_all(image_url: nil)
  end

  test "visits the events page" do
    visit root_url

    assert_selector "h1", text: "Upcoming Events"
    assert_selector ".vote-stats .upvotes"
    assert_selector ".vote-stats .downvotes"
    assert_no_selector ".vote-stats .total"
    assert_no_selector ".vote-stats .net"
  end

  test "loads more events as the user scrolls to the end of the list" do
    22.times do |index|
      Event.create!(
        billetto_id: "scroll-event-#{index}",
        title: "Scroll event #{index}",
        starts_at: index.days.from_now
      )
    end

    visit root_url
    assert_no_text "Scroll event 0"

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

    assert_text "Scroll event 0"
  end
end
