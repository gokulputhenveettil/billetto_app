require "test_helper"
require "erb"
require "yaml"
require "fugit"

class SidekiqConfigTest < ActiveSupport::TestCase
  test "schedules the Billetto importer every day at noon in Copenhagen" do
    config_path = Rails.root.join("config/sidekiq.yml")
    config = YAML.safe_load(
      ERB.new(config_path.read).result,
      permitted_classes: [ Symbol ],
      aliases: true
    )
    schedule = config.fetch(:scheduler).fetch(:schedule).fetch("import_billetto_events")
    cron = Fugit.parse_cron(schedule.fetch("cron"))

    assert_equal "Billetto::ImportEventsJob", schedule.fetch("class")
    assert_equal "Europe/Copenhagen", cron.zone
    assert_equal [ 12, 0 ], [ cron.hours.first, cron.minutes.first ]
  end
end
