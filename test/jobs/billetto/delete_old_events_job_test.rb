require "test_helper"

class Billetto::DeleteOldEventsJobTest < ActiveJob::TestCase
  test "removes events older than the retention window" do
    old_event = Event.create!(
      billetto_id: "old-event-1",
      title: "Old Event",
      starts_at: 45.days.ago,
      description: "expired"
    )

    recent_event = Event.create!(
      billetto_id: "recent-event-1",
      title: "Recent Event",
      starts_at: 5.days.ago,
      description: "fresh"
    )

    deleted_count = Billetto::DeleteOldEventsJob.new.perform

    assert_equal 1, deleted_count
    assert_not Event.exists?(old_event.id)
    assert Event.exists?(recent_event.id)
  end
end
