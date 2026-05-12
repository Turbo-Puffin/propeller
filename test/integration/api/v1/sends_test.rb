require "test_helper"

class Api::V1::SendsTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @api_key = create_api_key(account: @account)
    @other_account = create_account(name: "Other")
    @campaign = @account.campaigns.create!(name: "Mine")
    @contact = @account.contacts.create!(email: "a@example.com")
    @send = CampaignSend.create!(campaign: @campaign, contact: @contact, status: :delivered)

    @other_campaign = @other_account.campaigns.create!(name: "Theirs")
    @other_contact = @other_account.contacts.create!(email: "x@other.example")
    @other_send = CampaignSend.create!(campaign: @other_campaign, contact: @other_contact, status: :sent)
  end

  test "GET /api/v1/sends returns only this account's sends" do
    get "/api/v1/sends", headers: bearer_headers(@api_key)
    assert_response :success
    ids = json_response["data"].map { |s| s["id"] }
    assert_includes ids, @send.id
    refute_includes ids, @other_send.id
  end

  test "GET /api/v1/sends?campaign_id= filters" do
    get "/api/v1/sends", params: { campaign_id: @campaign.id }, headers: bearer_headers(@api_key)
    assert_response :success
    assert_equal 1, json_response["data"].length
  end

  test "GET /api/v1/sends/:id returns the send" do
    get "/api/v1/sends/#{@send.id}", headers: bearer_headers(@api_key)
    assert_response :success
    assert_equal @send.id, json_response.dig("data", "id")
  end

  test "GET /api/v1/sends/:id 404 for another account's send" do
    get "/api/v1/sends/#{@other_send.id}", headers: bearer_headers(@api_key)
    assert_response :not_found
  end
end
