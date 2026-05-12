ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Parallel workers can interleave HTTP-mocking; run sequentially.
    self.fixture_paths = []
    include WebhookTestHelpers
  end
end
