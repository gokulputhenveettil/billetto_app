namespace :billetto do
  desc "Import public events from Billetto"

  task import_events: :environment do
    count = Billetto::EventImporter.new.import_events

    puts "Successfully imported #{count} events."
  rescue StandardError => e
    warn "Billetto import failed: #{e.message}"
    exit 1
  end
end