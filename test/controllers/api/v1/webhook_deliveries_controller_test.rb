require "test_helper"

class Api::V1::WebhookDeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @user = create_user(account: @account)
    post login_path, params: { email: @user.email, password: "supersecret123" }

    @endpoint = create_endpoint(account: @account, events: [ "contact.created" ])
    @delivery = WebhookDelivery.create!(
      webhook_endpoint: @endpoint,
      event_type: "contact.created",
      payload: { "event" => "contact.created", "data" => {} },
      status: "failed",
      attempts: 5,
      last_error_message: "HTTP 503"
    )
  end

  test "replays a failed delivery" do
    assert_enqueued_with(job: DeliverWebhookJob, args: [ @delivery.id ]) do
      post replay_api_v1_webhook_delivery_url(@delivery), as: :json
    end
    assert_response :accepted
    @delivery.reload
    assert_equal "pending", @delivery.status
  end

  test "does not replay a delivered delivery" do
    @delivery.update!(status: "delivered")
    post replay_api_v1_webhook_delivery_url(@delivery), as: :json
    assert_response :unprocessable_entity
  end

  test "cannot replay another account's delivery" do
    other_account = create_account
    other_endpoint = create_endpoint(account: other_account)
    other_delivery = WebhookDelivery.create!(
      webhook_endpoint: other_endpoint,
      event_type: "contact.created",
      payload: { "event" => "contact.created", "data" => {} },
      status: "failed"
    )

    post replay_api_v1_webhook_delivery_url(other_delivery), as: :json
    assert_response :not_found
  end
end
