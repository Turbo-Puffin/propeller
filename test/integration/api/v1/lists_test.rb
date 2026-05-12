require "test_helper"

class Api::V1::ListsTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @api_key = create_api_key(account: @account)
    @other_account = create_account(name: "Other")
    @other_list = @other_account.contact_lists.create!(name: "Other list")
  end

  test "POST /api/v1/lists creates a list" do
    post "/api/v1/lists",
      params: { list: { name: "VIPs" } }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :created
    assert_equal "VIPs", json_response.dig("data", "name")
  end

  test "POST /api/v1/lists 422 when name missing" do
    post "/api/v1/lists",
      params: { list: { name: "" } }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "GET /api/v1/lists lists this account's lists only" do
    @account.contact_lists.create!(name: "Mine")
    get "/api/v1/lists", headers: bearer_headers(@api_key)
    assert_response :success
    names = json_response["data"].map { |l| l["name"] }
    refute_includes names, @other_list.name
  end

  test "GET /api/v1/lists/:id 404 for another account's list" do
    get "/api/v1/lists/#{@other_list.id}", headers: bearer_headers(@api_key)
    assert_response :not_found
  end

  test "POST /api/v1/lists/:id/contacts adds a contact" do
    list = @account.contact_lists.create!(name: "VIPs")
    contact = @account.contacts.create!(email: "a@example.com")

    assert_difference -> { list.contact_list_memberships.count }, 1 do
      post "/api/v1/lists/#{list.id}/contacts",
        params: { contact_id: contact.id }.to_json,
        headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    end
    assert_response :created
  end

  test "POST /api/v1/lists/:id/contacts 404 when contact belongs to another account" do
    list = @account.contact_lists.create!(name: "VIPs")
    post "/api/v1/lists/#{list.id}/contacts",
      params: { contact_id: @other_account.contacts.create!(email: "n@example.com").id }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :not_found
  end

  test "DELETE /api/v1/lists/:id/contacts/:contact_id removes the membership" do
    list = @account.contact_lists.create!(name: "VIPs")
    contact = @account.contacts.create!(email: "a@example.com")
    list.contact_list_memberships.create!(contact: contact)

    assert_difference -> { list.contact_list_memberships.count }, -1 do
      delete "/api/v1/lists/#{list.id}/contacts/#{contact.id}", headers: bearer_headers(@api_key)
    end
    assert_response :no_content
  end
end
