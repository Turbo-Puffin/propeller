ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    self.use_transactional_tests = true

    include AuditTestHelpers
  end
end

class ActionDispatch::IntegrationTest
  include AuditTestHelpers
end
