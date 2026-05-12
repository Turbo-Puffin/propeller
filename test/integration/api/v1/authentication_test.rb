require "test_helper"

class Api::V1::AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @api_key = create_api_key(account: @account)
  end

  test "returns 401 when Authorization header is missing" do
    get "/api/v1/contacts"
    assert_response :unauthorized
    assert_equal "missing_token", json_response.dig("error", "code")
  end

  test "returns 401 when Authorization header is not a Bearer token" do
    get "/api/v1/contacts", headers: { "Authorization" => "Basic abc" }
    assert_response :unauthorized
    assert_equal "missing_token", json_response.dig("error", "code")
  end

  test "returns 401 for a bogus Bearer token" do
    get "/api/v1/contacts", headers: { "Authorization" => "Bearer pk_live_nonsense_token_value" }
    assert_response :unauthorized
    assert_equal "invalid_token", json_response.dig("error", "code")
  end

  test "returns 401 for a revoked key" do
    @api_key.revoke!
    get "/api/v1/contacts", headers: bearer_headers(@api_key)
    assert_response :unauthorized
    assert_equal "invalid_token", json_response.dig("error", "code")
  end

  test "valid key grants access and stamps last_used_at" do
    get "/api/v1/contacts", headers: bearer_headers(@api_key)
    assert_response :success
    assert_not_nil @api_key.reload.last_used_at
  end
end
