require "test_helper"

class Api::V1::SegmentsTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @api_key = create_api_key(account: @account)
    @list = @account.contact_lists.create!(name: "Main")

    @other_account = create_account(name: "Other")
    @other_segment = @other_account.segments.create!(
      name: "Other secret",
      rules: { "match" => "all", "rules" => [] }
    )
  end

  test "POST /api/v1/segments creates a segment with rules" do
    payload = {
      segment: {
        name: "VIPs",
        list_id: @list.id,
        rules: {
          match: "all",
          rules: [ { property: "email", op: "ends_with", value: "@example.com" } ]
        }
      }
    }
    post "/api/v1/segments",
      params: payload.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :created
    assert_equal "VIPs", json_response.dig("data", "name")
    assert_equal @list.id, json_response.dig("data", "contact_list_id")
    assert_includes json_response["data"].keys, "matching_count"
  end

  test "POST /api/v1/segments 422 when rules malformed" do
    payload = {
      segment: {
        name: "Bad",
        rules: { match: "all", rules: [ { property: "email", op: "unknown_op", value: "x" } ] }
      }
    }
    post "/api/v1/segments",
      params: payload.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "POST /api/v1/segments 404 when list belongs to another account" do
    payload = { segment: { name: "Cross", list_id: @other_account.contact_lists.create!(name: "X").id, rules: { match: "all", rules: [] } } }
    post "/api/v1/segments",
      params: payload.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :not_found
  end

  test "GET /api/v1/segments lists only this account's segments" do
    @account.segments.create!(name: "Mine", rules: { match: "all", rules: [] })
    get "/api/v1/segments", headers: bearer_headers(@api_key)
    assert_response :success
    names = json_response["data"].map { |s| s["name"] }
    assert_includes names, "Mine"
    refute_includes names, @other_segment.name
  end

  test "GET /api/v1/segments?list_id= filters by list" do
    @account.segments.create!(name: "ScopedToList", contact_list: @list, rules: { match: "all", rules: [] })
    @account.segments.create!(name: "Unscoped", rules: { match: "all", rules: [] })
    get "/api/v1/segments", params: { list_id: @list.id }, headers: bearer_headers(@api_key)
    assert_response :success
    names = json_response["data"].map { |s| s["name"] }
    assert_equal [ "ScopedToList" ], names
  end

  test "GET /api/v1/segments/:id returns matching_count" do
    @account.contacts.create!(email: "a@example.com")
    segment = @account.segments.create!(
      name: "WithEmail",
      rules: { "match" => "all", "rules" => [ { "property" => "email", "op" => "contains", "value" => "@example.com" } ] }
    )
    get "/api/v1/segments/#{segment.id}", headers: bearer_headers(@api_key)
    assert_response :success
    assert_equal 1, json_response.dig("data", "matching_count")
  end

  test "GET /api/v1/segments/:id 404 across accounts" do
    get "/api/v1/segments/#{@other_segment.id}", headers: bearer_headers(@api_key)
    assert_response :not_found
  end

  test "GET /api/v1/segments/:id/contacts returns filtered contacts" do
    @account.contacts.create!(email: "match@example.com", first_name: "Ada")
    @account.contacts.create!(email: "skip@example.com", first_name: "Bob")
    segment = @account.segments.create!(
      name: "Adas",
      rules: { "match" => "all", "rules" => [ { "property" => "first_name", "op" => "equals", "value" => "Ada" } ] }
    )
    get "/api/v1/segments/#{segment.id}/contacts", headers: bearer_headers(@api_key)
    assert_response :success
    emails = json_response["data"].map { |c| c["email"] }
    assert_equal [ "match@example.com" ], emails
  end

  test "PATCH /api/v1/segments/:id updates rules" do
    segment = @account.segments.create!(name: "X", rules: { match: "all", rules: [] })
    patch "/api/v1/segments/#{segment.id}",
      params: { segment: { name: "Renamed" } }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :success
    assert_equal "Renamed", segment.reload.name
  end

  test "DELETE /api/v1/segments/:id removes the segment" do
    segment = @account.segments.create!(name: "X", rules: { match: "all", rules: [] })
    assert_difference -> { @account.segments.count }, -1 do
      delete "/api/v1/segments/#{segment.id}", headers: bearer_headers(@api_key)
    end
    assert_response :no_content
  end

  test "requires API key" do
    get "/api/v1/segments"
    assert_response :unauthorized
  end
end
