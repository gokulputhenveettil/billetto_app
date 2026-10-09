module Billetto
  class EventImporter
    def initialize(client: default_client)
      @client = client
    end

    def import_events
      imported = 0
      next_url = nil

      loop do
        response = @client.fetch_events(
          limit: 100,
          next_url: next_url
        )

        events = response.fetch("data", [])

        events.each do |event_data|
          import_event(event_data)
          imported += 1
        end

        break unless response["has_more"]

        next_url = response["next_url"]

        break if next_url.blank?
      end

      imported
    end

    private

    attr_reader :client

    def import_event(data)
      validate_event_data!(data)

      Event.upsert(
        {
          billetto_id: data["id"],
          title: data["title"],
          description: data["description"],
          image_url: data["image_link"],
          event_url: data["url"],
          starts_at: parse_time(data["startdate"]),
          ends_at: parse_time(data["enddate"]),
          organiser_name: data.dig("organiser", "name"),
          location_name: data.dig("location", "location_name"),
          address: data.dig("location", "address_line"),
          city: data.dig("location", "city"),
          postal_code: data.dig("location", "postal_code"),
          country: data.dig("location", "country"),
          country_code: data.dig("location", "country_code"),
          category: data.dig("categorization", "category"),
          subcategory: data.dig("categorization", "subcategory"),
          available: data["availability"] == true,
          raw_data: data.to_json,
          last_synced_at: Time.current,
          updated_at: Time.current
        },
        unique_by: :index_events_on_billetto_id
      )
    end

    def validate_event_data!(data)
      required_fields = %w[id title startdate]

      missing_fields = required_fields.select do |field|
        data[field].blank?
      end

      return if missing_fields.empty?

      raise "Invalid event data. Missing: #{missing_fields.join(', ')}"
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end

    def default_client
      api_keypair = ENV["BILLETTO_API_KEYPAIR"]
      raise "Billetto API keypair is not configured" if api_keypair.blank?

      Billetto::Client.new(api_keypair: api_keypair)
    end
  end
end
