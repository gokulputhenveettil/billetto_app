require "test_helper"

class Billetto::EventImporterTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def fetch_events(**options)
      @requests << options
      @responses.shift
    end
  end

  test "builds its API client from the Billetto API key environment variable" do
    with_billetto_api_keypair("test-api-keypair") do
      assert_instance_of Billetto::Client, Billetto::EventImporter.new.instance_variable_get(:@client)
    end
  end

  test "raises a clear error when the Billetto API key is not configured" do
    with_billetto_api_keypair(nil) do
      error = assert_raises(RuntimeError) { Billetto::EventImporter.new }

      assert_equal "Billetto API keypair is not configured", error.message
    end
  end

  test "imports event attributes and returns the number of imported events" do
    client = FakeClient.new(
      [
        {
          "data" => [
            {
              "id" => "billetto-event-123",
              "title" => "Concert",
              "description" => "Live music",
              "image_link" => "https://example.com/image.jpg",
              "url" => "https://billetto.dk/e/123",
              "startdate" => "2026-11-01T18:00:00Z",
              "enddate" => "2026-11-01T21:00:00Z",
              "organiser" => { "name" => "Billetto" },
              "location" => {
                "location_name" => "Venue",
                "address_line" => "Main Street 1",
                "city" => "Copenhagen",
                "postal_code" => "1000",
                "country" => "Denmark",
                "country_code" => "DK"
              },
              "categorization" => {
                "category" => "Music",
                "subcategory" => "Concerts"
              },
              "availability" => true
            }
          ],
          "has_more" => false
        }
      ]
    )

    imported_count = Billetto::EventImporter.new(client: client).import_events

    assert_equal 1, imported_count
    event = Event.find_by!(billetto_id: "billetto-event-123")
    assert_equal "Concert", event.title
    assert_equal "Live music", event.description
    assert_equal "https://example.com/image.jpg", event.image_url
    assert_equal "https://billetto.dk/e/123", event.event_url
    assert_equal Time.zone.parse("2026-11-01T18:00:00Z"), event.starts_at
    assert_equal Time.zone.parse("2026-11-01T21:00:00Z"), event.ends_at
    assert_equal "Billetto", event.organiser_name
    assert_equal "Venue", event.location_name
    assert_equal "Main Street 1", event.address
    assert_equal "Copenhagen", event.city
    assert_equal "1000", event.postal_code
    assert_equal "Denmark", event.country
    assert_equal "DK", event.country_code
    assert_equal "Music", event.category
    assert_equal "Concerts", event.subcategory
    assert event.available
    assert_equal "billetto-event-123", JSON.parse(event.raw_data).fetch("id")
    assert_not_nil event.last_synced_at
  end

  test "follows pagination links and returns the total imported count" do
    client = FakeClient.new(
      [
        {
          "data" => [ { "id" => "page-one", "title" => "First", "startdate" => "2026-11-01" } ],
          "has_more" => true,
          "next_url" => "https://billetto.dk/api/v3/public/events?page=2"
        },
        {
          "data" => [ { "id" => "page-two", "title" => "Second", "startdate" => "2026-11-02" } ],
          "has_more" => false
        }
      ]
    )

    imported_count = Billetto::EventImporter.new(client: client).import_events

    assert_equal 2, imported_count
    assert_equal [
      { limit: 100, next_url: nil },
      { limit: 100, next_url: "https://billetto.dk/api/v3/public/events?page=2" }
    ], client.requests
    assert Event.exists?(billetto_id: "page-one")
    assert Event.exists?(billetto_id: "page-two")
  end

  test "updates existing events and refreshes their last synced timestamp" do
    previous_sync = 2.days.ago
    Event.create!(
      billetto_id: "existing-event",
      title: "Old title",
      starts_at: Time.zone.parse("2026-11-01"),
      last_synced_at: previous_sync
    )
    client = FakeClient.new(
      [
        {
          "data" => [ { "id" => "existing-event", "title" => "Updated title", "startdate" => "2026-11-01" } ],
          "has_more" => false
        }
      ]
    )

    imported_count = Billetto::EventImporter.new(client: client).import_events

    assert_equal 1, imported_count
    assert_equal 1, Event.where(billetto_id: "existing-event").count
    event = Event.find_by!(billetto_id: "existing-event")
    assert_equal "Updated title", event.title
    assert_operator event.last_synced_at, :>, previous_sync
  end

  test "stops pagination when the API does not return a next URL" do
    client = FakeClient.new(
      [
        {
          "data" => [ { "id" => "page-one", "title" => "First", "startdate" => "2026-11-01" } ],
          "has_more" => true
        }
      ]
    )

    imported_count = Billetto::EventImporter.new(client: client).import_events

    assert_equal 1, imported_count
    assert_equal 1, client.requests.size
  end

  test "rejects events missing required fields" do
    client = FakeClient.new(
      [
        {
          "data" => [ { "id" => "missing-title", "startdate" => "2026-11-01" } ],
          "has_more" => false
        }
      ]
    )

    error = assert_raises(RuntimeError) do
      Billetto::EventImporter.new(client: client).import_events
    end

    assert_equal "Invalid event data. Missing: title", error.message
    assert_not Event.exists?(billetto_id: "missing-title")
  end

  private

  def with_billetto_api_keypair(value)
    original_value = ENV["BILLETTO_API_KEYPAIR"]
    value.nil? ? ENV.delete("BILLETTO_API_KEYPAIR") : ENV["BILLETTO_API_KEYPAIR"] = value

    yield
  ensure
    original_value.nil? ? ENV.delete("BILLETTO_API_KEYPAIR") : ENV["BILLETTO_API_KEYPAIR"] = original_value
  end
end
