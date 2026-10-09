require "test_helper"
require "rake"

class BillettoTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("billetto:import_events")
    Rake::Task["billetto:import_events"].reenable
  end

  test "prints the number of imported events" do
    importer = Object.new
    importer.define_singleton_method(:import_events) { 2 }

    output, error = capture_io do
      with_billetto_importer(importer) do
        Rake::Task["billetto:import_events"].invoke
      end
    end

    assert_equal "Successfully imported 2 events.\n", output
    assert_empty error
  end

  test "reports import failures and exits unsuccessfully" do
    importer = Object.new
    importer.define_singleton_method(:import_events) { raise "API unavailable" }

    error = assert_raises(SystemExit) do
      capture_io do
        with_billetto_importer(importer) do
          Rake::Task["billetto:import_events"].invoke
        end
      end
    end

    assert_equal 1, error.status
  end
end
