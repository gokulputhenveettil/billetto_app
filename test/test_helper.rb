ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def with_billetto_importer(importer)
      original_new = Billetto::EventImporter.method(:new)
      Billetto::EventImporter.define_singleton_method(:new) { importer }

      yield
    ensure
      Billetto::EventImporter.define_singleton_method(:new, original_new)
    end
  end
end
