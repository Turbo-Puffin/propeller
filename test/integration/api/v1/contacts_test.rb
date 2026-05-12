require "test_helper"

class Api::V1::ContactsTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @api_key = create_api_key(account: @account)
    @other_account = create_account(name: "Other")
    @other_contact = @other_account.contacts.create!(email: "other@example.com")
  end

  test "POST /api/v1/contacts creates a contact" do
    assert_difference -> { @account.contacts.count }, 1 do
      post "/api/v1/contacts",
        params: { contact: { email: "new@example.com", first_name: "Ada" } }.to_json,
        headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    end
    assert_response :created
    assert_equal "new@example.com", json_response.dig("data", "email")
    assert_equal "Ada", json_response.dig("data", "first_name")
  end

  test "POST /api/v1/contacts returns 422 with field-level errors when invalid" do
    post "/api/v1/contacts",
      params: { contact: { email: "" } }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_response.dig("error", "code")
    assert json_response.dig("error", "fields", "email").is_a?(Array)
  end

  test "GET /api/v1/contacts lists only this account's contacts and paginates" do
    @account.contacts.create!(email: "a@example.com")
    @account.contacts.create!(email: "b@example.com")

    get "/api/v1/contacts", headers: bearer_headers(@api_key)
    assert_response :success
    emails = json_response["data"].map { |c| c["email"] }
    refute_includes emails, @other_contact.email
    assert_equal 2, json_response.dig("meta", "total")
  end

  test "per_page is capped at 100" do
    get "/api/v1/contacts", params: { per_page: 500 }, headers: bearer_headers(@api_key)
    assert_response :success
    assert_equal 100, json_response.dig("meta", "per_page")
  end

  test "GET /api/v1/contacts/:id returns the contact" do
    contact = @account.contacts.create!(email: "x@example.com")
    get "/api/v1/contacts/#{contact.id}", headers: bearer_headers(@api_key)
    assert_response :success
    assert_equal contact.id, json_response.dig("data", "id")
  end

  test "GET /api/v1/contacts/:id returns 404 for another account's contact (no info leak)" do
    get "/api/v1/contacts/#{@other_contact.id}", headers: bearer_headers(@api_key)
    assert_response :not_found
    assert_equal "not_found", json_response.dig("error", "code")
  end

  test "PATCH /api/v1/contacts/:id updates the contact" do
    contact = @account.contacts.create!(email: "y@example.com")
    patch "/api/v1/contacts/#{contact.id}",
      params: { contact: { first_name: "Updated" } }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :success
    assert_equal "Updated", contact.reload.first_name
  end

  test "DELETE /api/v1/contacts/:id destroys the contact" do
    contact = @account.contacts.create!(email: "z@example.com")
    assert_difference -> { @account.contacts.count }, -1 do
      delete "/api/v1/contacts/#{contact.id}", headers: bearer_headers(@api_key)
    end
    assert_response :no_content
  end

  test "401 without auth header" do
    get "/api/v1/contacts"
    assert_response :unauthorized
  end
end
