require "test_helper"

class DeliverWebhookJobTest < ActiveJob::TestCase
  FakeResponse = Struct.new(:code, :body) do
    def initialize(code:, body: "")
      super(code.to_s, body)
    end
  end

  setup do
    @account = create_account
    @endpoint = create_endpoint(account: @account, events: [ "webhook.test" ])
    @delivery = WebhookDelivery.create!(
      webhook_endpoint: @endpoint,
      event_type: "webhook.test",
      payload: { "event" => "webhook.test", "occurred_at" => Time.current.utc.iso8601, "data" => {} },
      status: "pending"
    )
  end

  test "marks delivery delivered on a 2xx" do
    with_http_client_stub(->(*) { FakeResponse.new(code: 200) }) do
      DeliverWebhookJob.perform_now(@delivery.id)
    end

    @delivery.reload
    assert_equal "delivered", @delivery.status
    assert_equal 200, @delivery.response_status
    assert_equal 1, @delivery.attempts
    assert @delivery.delivered_at.present?
    @endpoint.reload
    assert @endpoint.last_success_at.present?
  end

  test "marks delivery failed without retry on a 4xx" do
    with_http_client_stub(->(*) { FakeResponse.new(code: 422, body: "go away") }) do
      DeliverWebhookJob.perform_now(@delivery.id)
    end

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_match(/HTTP 422/, @delivery.last_error_message)
    @endpoint.reload
    assert @endpoint.last_failure_at.present?
  end

  test "raises RetryableDeliveryError on 5xx so ActiveJob retries" do
    error = assert_raises(DeliverWebhookJob::RetryableDeliveryError) do
      with_http_client_stub(->(*) { FakeResponse.new(code: 503, body: "down") }) do
        DeliverWebhookJob.new(@delivery.id).perform(@delivery.id)
      end
    end
    assert_match(/HTTP 503/, error.message)
    @delivery.reload
    assert_equal 1, @delivery.attempts
    assert_equal 503, @delivery.response_status
  end

  test "exhaustion handler marks delivery failed after MAX_ATTEMPTS" do
    error = DeliverWebhookJob::RetryableDeliveryError.new("HTTP 503", delivery_id: @delivery.id)
    job = DeliverWebhookJob.new(@delivery.id)

    DeliverWebhookJob.mark_exhausted(job, error)

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_match(/HTTP 503/, @delivery.last_error_message)
    @endpoint.reload
    assert @endpoint.last_failure_at.present?
  end

  test "retries on transport error" do
    error = assert_raises(DeliverWebhookJob::RetryableDeliveryError) do
      with_http_client_stub(->(*) { raise Errno::ECONNREFUSED, "connection refused" }) do
        DeliverWebhookJob.new(@delivery.id).perform(@delivery.id)
      end
    end
    assert_match(/connection refused/i, error.message)

    @delivery.reload
    assert_match(/Errno::ECONNREFUSED|connection refused/i, @delivery.last_error_message)
    assert_equal 1, @delivery.attempts
  end

  test "no-ops if endpoint inactive" do
    @endpoint.update!(active: false)
    DeliverWebhookJob.perform_now(@delivery.id)
    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_match(/Skipped: endpoint inactive/, @delivery.last_error_message)
  end

  test "sends payload signed with the endpoint secret" do
    captured = {}
    capture = lambda do |url, body, headers|
      captured[:url] = url
      captured[:body] = body
      captured[:headers] = headers
      FakeResponse.new(code: 200)
    end

    with_http_client_stub(capture) do
      DeliverWebhookJob.perform_now(@delivery.id)
    end

    expected_sig = Webhooks::Signer.sign(captured[:body], @endpoint.secret)
    assert_equal expected_sig, captured[:headers]["X-Propeller-Signature"]
    assert_equal "webhook.test", captured[:headers]["X-Propeller-Event"]
    assert_equal @delivery.id, captured[:headers]["X-Propeller-Delivery-Id"]
  end
end
