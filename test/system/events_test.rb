require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  setup do
    Event.update_all(image_url: nil)
  end

  test "visits the events page" do
    visit root_url

    assert_selector "h1", text: "Upcoming Events"
  end
end
