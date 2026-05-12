require "test_helper"

class WebhookEndpointTest < ActiveSupport::TestCase
  test "generates a secret on create" do
    account = create_account
    endpoint = WebhookEndpoint.create!(account: account, url: "https://example.com/hooks", event_types: [ "contact.created" ])
    assert endpoint.secret.present?
    assert endpoint.secret.start_with?("whsec_")
  end

  test "validates URL format" do
    account = create_account
    endpoint = WebhookEndpoint.new(account: account, url: "ftp://example.com", event_types: [])
    refute endpoint.valid?
    assert_includes endpoint.errors[:url].join, "valid http or https URL"
  end

  test "rejects unsupported event types" do
    account = create_account
    endpoint = WebhookEndpoint.new(account: account, url: "https://example.com", event_types: [ "bogus.event" ])
    refute endpoint.valid?
    assert_match(/unsupported events/, endpoint.errors[:event_types].join)
  end

  test "listening_for scope returns only active endpoints subscribed to event" do
    account = create_account
    listening = create_endpoint(account: account, events: [ "contact.created", "list.created" ])
    not_listening = create_endpoint(account: account, events: [ "list.created" ])
    inactive = create_endpoint(account: account, events: [ "contact.created" ], active: false)

    matches = account.webhook_endpoints.listening_for("contact.created").to_a
    assert_includes matches, listening
    refute_includes matches, not_listening
    refute_includes matches, inactive
  end

  test "secret_preview shows only the trailing characters" do
    endpoint = WebhookEndpoint.new(secret: "whsec_abcdefghij")
    assert_equal "...ghij", endpoint.secret_preview
  end
end
