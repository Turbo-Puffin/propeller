require "test_helper"

class Api::V1::CampaignsTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @api_key = create_api_key(account: @account)
    @other_account = create_account(name: "Other")
    @other_campaign = @other_account.campaigns.create!(name: "Theirs")
  end

  test "POST /api/v1/campaigns creates a draft campaign" do
    post "/api/v1/campaigns",
      params: { campaign: { name: "Launch", subject: "Hi" } }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :created
    assert_equal "Launch", json_response.dig("data", "name")
    assert_equal "draft", json_response.dig("data", "status")
  end

  test "POST /api/v1/campaigns 422 when name missing" do
    post "/api/v1/campaigns",
      params: { campaign: { name: "" } }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "GET /api/v1/campaigns scopes to current account" do
    @account.campaigns.create!(name: "Mine")
    get "/api/v1/campaigns", headers: bearer_headers(@api_key)
    assert_response :success
    names = json_response["data"].map { |c| c["name"] }
    refute_includes names, @other_campaign.name
  end

  test "GET /api/v1/campaigns/:id 404 for another account's campaign" do
    get "/api/v1/campaigns/#{@other_campaign.id}", headers: bearer_headers(@api_key)
    assert_response :not_found
  end

  test "POST /api/v1/campaigns/:id/schedule transitions to scheduled" do
    campaign = @account.campaigns.create!(name: "Launch")
    scheduled_at = 2.hours.from_now.iso8601
    post "/api/v1/campaigns/#{campaign.id}/schedule",
      params: { scheduled_at: scheduled_at }.to_json,
      headers: bearer_headers(@api_key).merge("Content-Type" => "application/json")
    assert_response :success
    assert_equal "scheduled", campaign.reload.status
    assert_not_nil campaign.scheduled_at
  end

  test "POST /api/v1/campaigns/:id/schedule rejects already-sent campaigns" do
    campaign = @account.campaigns.create!(name: "Done", status: :sent)
    post "/api/v1/campaigns/#{campaign.id}/schedule",
      headers: bearer_headers(@api_key)
    assert_response :unprocessable_entity
    assert_equal "invalid_state", json_response.dig("error", "code")
  end

  test "POST /api/v1/campaigns/:id/cancel reverts a scheduled campaign to draft" do
    campaign = @account.campaigns.create!(name: "Soon", status: :scheduled, scheduled_at: 1.day.from_now)
    post "/api/v1/campaigns/#{campaign.id}/cancel", headers: bearer_headers(@api_key)
    assert_response :success
    assert_equal "draft", campaign.reload.status
    assert_nil campaign.scheduled_at
  end

  test "POST /api/v1/campaigns/:id/cancel 422 for a draft campaign" do
    campaign = @account.campaigns.create!(name: "Draft")
    post "/api/v1/campaigns/#{campaign.id}/cancel", headers: bearer_headers(@api_key)
    assert_response :unprocessable_entity
  end
end
