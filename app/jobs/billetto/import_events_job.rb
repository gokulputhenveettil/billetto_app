module Billetto
  class ImportEventsJob
    include Sidekiq::Job

    def perform
      imported_count = EventImporter.new.import_events
      Rails.logger.info("Successfully imported #{imported_count} Billetto events.")
    end
  end
end
