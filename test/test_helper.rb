ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # parallelize(workers: :number_of_processors)

    self.use_transactional_tests = true
  end
end

class ActionDispatch::IntegrationTest
  include ApiTestHelpers

  def json_response
    JSON.parse(response.body)
  end

  def bearer_headers(api_key)
    { "Authorization" => "Bearer #{api_key.plaintext_key}" }
  end
end

class ActiveSupport::TestCase
  include ApiTestHelpers
end
