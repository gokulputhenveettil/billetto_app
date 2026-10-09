require "test_helper"

class Billetto::ImportEventsJobTest < ActiveJob::TestCase
  test "imports Billetto events when performed" do
    importer = Object.new
    importer.define_singleton_method(:import_events) { 3 }

    with_billetto_importer(importer) do
      assert_nothing_raised { Billetto::ImportEventsJob.new.perform }
    end
  end
end
