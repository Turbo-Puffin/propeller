require "test_helper"

class Api::V1::WebhookEndpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @user = create_user(account: @account)
    log_in!(@user)
  end

  test "rejects unauthenticated requests" do
    delete logout_path
    get api_v1_webhook_endpoints_url, as: :json
    assert_response :unauthorized
  end

  test "creates an endpoint and returns the secret exactly once" do
    assert_difference -> { WebhookEndpoint.count }, 1 do
      post api_v1_webhook_endpoints_url,
           params: { url: "https://example.com/hooks", event_types: [ "contact.created" ] },
           as: :json
    end
    assert_response :created
    body = response.parsed_body
    assert body["secret"].present?, "secret should be exposed on create"
    assert body["secret"].start_with?("whsec_")
    assert_equal [ "contact.created" ], body["event_types"]

    get api_v1_webhook_endpoint_url(body["id"]), as: :json
    refetched = response.parsed_body
    assert_nil refetched["secret"]
    assert refetched["secret_preview"].present?
  end

  test "lists endpoints scoped to the current account" do
    create_endpoint(account: @account, events: [ "contact.created" ])
    other_account = create_account
    create_endpoint(account: other_account, events: [ "contact.created" ])

    get api_v1_webhook_endpoints_url, as: :json
    assert_response :ok
    assert_equal 1, response.parsed_body.length
  end

  test "updates an endpoint" do
    endpoint = create_endpoint(account: @account)

    patch api_v1_webhook_endpoint_url(endpoint),
          params: { active: false, event_types: [ "list.created" ] },
          as: :json
    assert_response :ok
    endpoint.reload
    refute endpoint.active?
    assert_equal [ "list.created" ], endpoint.event_types
  end

  test "destroys an endpoint" do
    endpoint = create_endpoint(account: @account)
    assert_difference -> { WebhookEndpoint.count }, -1 do
      delete api_v1_webhook_endpoint_url(endpoint), as: :json
    end
    assert_response :no_content
  end

  test "deliveries action returns recent deliveries for the endpoint" do
    endpoint = create_endpoint(account: @account)
    WebhookDelivery.create!(webhook_endpoint: endpoint, event_type: "contact.created",
                            payload: { "event" => "contact.created", "data" => {} }, status: "delivered")

    get deliveries_api_v1_webhook_endpoint_url(endpoint), as: :json
    assert_response :ok
    assert_equal 1, response.parsed_body.length
    assert_equal "delivered", response.parsed_body.first["status"]
  end

  test "test_fire enqueues a webhook.test delivery" do
    create_endpoint(account: @account, events: [ "webhook.test" ])
    endpoint_for_test = create_endpoint(account: @account, events: [ "webhook.test", "contact.created" ])

    assert_difference -> { WebhookDelivery.count }, 2 do
      post test_fire_api_v1_webhook_endpoint_url(endpoint_for_test), as: :json
    end
    assert_response :accepted
  end

  test "endpoints in other accounts are not visible" do
    other_account = create_account
    other_endpoint = create_endpoint(account: other_account)

    get api_v1_webhook_endpoint_url(other_endpoint), as: :json
    assert_response :not_found
  end

  private

  def log_in!(user)
    post login_path, params: { email: user.email, password: "supersecret123" }
  end
end
