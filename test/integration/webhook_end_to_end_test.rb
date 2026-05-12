require "test_helper"

class WebhookEndToEndTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "create endpoint via API, trigger event, delivery is enqueued and POSTs a signed payload" do
    account = create_account
    user = create_user(account: account)
    post login_path, params: { email: user.email, password: "supersecret123" }

    post api_v1_webhook_endpoints_url,
         params: { url: "https://example.com/hooks", event_types: [ "contact.created" ] },
         as: :json
    assert_response :created
    secret = response.parsed_body["secret"]
    endpoint_id = response.parsed_body["id"]

    captured = nil
    fake_post = lambda do |_url, body, headers|
      captured = { body: body, headers: headers }
      response_double = Struct.new(:code, :body).new("200", "ok")
      response_double
    end

    assert_enqueued_with(job: DeliverWebhookJob) do
      Contact.create!(account: account, email: "lead@example.com")
    end

    with_http_client_stub(fake_post) do
      perform_enqueued_jobs(only: DeliverWebhookJob)
    end

    refute_nil captured, "the webhook should have been POSTed"
    expected_sig = Webhooks::Signer.sign(captured[:body], secret)
    assert_equal expected_sig, captured[:headers]["X-Propeller-Signature"]
    assert_equal "contact.created", captured[:headers]["X-Propeller-Event"]
    assert captured[:headers]["X-Propeller-Delivery-Id"].present?

    parsed = JSON.parse(captured[:body])
    assert_equal "contact.created", parsed["event"]
    assert_equal "lead@example.com", parsed["data"]["email"]

    endpoint = WebhookEndpoint.find(endpoint_id)
    assert endpoint.last_success_at.present?
    assert_equal "delivered", WebhookDelivery.last.status
  end
end
