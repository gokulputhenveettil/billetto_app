require "test_helper"

class EventsHelperTest < ActionView::TestCase
  test "allows secure Billetto event URLs" do
    assert_equal "https://www.billetto.dk/e/123", safe_billetto_event_url("https://www.billetto.dk/e/123")
  end

  test "rejects non-HTTPS and non-Billetto URLs" do
    assert_nil safe_billetto_event_url(nil)
    assert_nil safe_billetto_event_url("http://billetto.dk/e/123")
    assert_nil safe_billetto_event_url("https://example.com/e/123")
    assert_nil safe_billetto_event_url("https://billetto.dk.example.com/e/123")
    assert_nil safe_billetto_event_url("javascript:alert(1)")
  end
end
