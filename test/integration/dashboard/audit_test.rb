require "test_helper"

module Dashboard
  class AuditTest < ActionDispatch::IntegrationTest
    setup do
      @account_a = create_account(name: "Alpha")
      @account_b = create_account(name: "Beta")
      @user_a    = create_user(account: @account_a)
      @user_b    = create_user(account: @account_b)

      AuditEvent.record!(account: @account_a, action: "contact.created", actor: @user_a, target: @user_a, metadata: { "diff" => { "email" => "a@a.co" }, "reason" => "alpha-1" })
      AuditEvent.record!(account: @account_a, action: "campaign.scheduled", actor: @user_a, metadata: { "reason" => "alpha-2" })
      AuditEvent.record!(account: @account_b, action: "contact.created", actor: @user_b, metadata: { "reason" => "beta-1" })
    end

    test "requires login" do
      get "/dashboard/audit"
      assert_redirected_to "/login"
    end

    test "lists events for the current account only" do
      login_as(@user_a)
      get "/dashboard/audit"
      assert_response :success
      assert_match "alpha-1", response.body
      assert_match "alpha-2", response.body
      refute_match "beta-1", response.body
    end

    test "filters by actor_type" do
      login_as(@user_a)
      AuditEvent.record!(account: @account_a, action: "system.tick", metadata: { "reason" => "alpha-system" })

      get "/dashboard/audit", params: { actor_type: "System" }
      assert_response :success
      assert_match "alpha-system", response.body
      refute_match "alpha-1", response.body
    end

    test "filters by event_action" do
      login_as(@user_a)
      get "/dashboard/audit", params: { event_action: "campaign.scheduled" }
      assert_response :success
      assert_match "alpha-2", response.body
      refute_match "alpha-1", response.body
    end

    test "exports CSV with only current account events" do
      login_as(@user_a)
      get "/dashboard/audit.csv"
      assert_response :success
      assert_equal "text/csv", response.media_type
      assert_match "alpha-1", response.body
      refute_match "beta-1", response.body
    end

    test "show renders detail for own event but 404s for another account's event" do
      foreign = @account_b.audit_events.first
      mine    = @account_a.audit_events.first

      login_as(@user_a)
      get "/dashboard/audit/#{mine.id}"
      assert_response :success
      assert_match mine.action, response.body

      get "/dashboard/audit/#{foreign.id}"
      assert_response :not_found
    end
  end
end
