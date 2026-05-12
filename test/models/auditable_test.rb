require "test_helper"

class AuditableTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @user    = create_user(account: @account)
  end

  test "writes a create event when a Contact is created" do
    contact = nil
    with_audit_context(account: @account, actor: @user, reason: "manual signup", request_ip: "1.2.3.4") do
      contact = @account.contacts.create!(email: "new@example.com")
    end

    event = @account.audit_events.where(action: "contact.created").last
    assert_equal contact.id, event.target_id
    assert_equal "Contact", event.target_type
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
    assert_equal "manual signup", event.reason
    assert_equal "1.2.3.4", event.request_ip
    assert_equal "new@example.com", event.metadata.dig("diff", "email")
  end

  test "writes an update event with from/to diff for relevant fields only" do
    contact = nil
    with_audit_context(account: @account, actor: @user) do
      contact = @account.contacts.create!(email: "old@example.com")
    end

    with_audit_context(account: @account, actor: @user) do
      contact.update!(email: "new@example.com", first_name: "Pat")
    end

    update_event = @account.audit_events.where(action: "contact.updated").last
    diff = update_event.metadata["diff"]
    assert_equal({ "from" => "old@example.com", "to" => "new@example.com" }, diff["email"])
    assert_equal({ "from" => nil, "to" => "Pat" }, diff["first_name"])
  end

  test "skips update event when no relevant fields change" do
    contact = nil
    with_audit_context(account: @account, actor: @user) do
      contact = @account.contacts.create!(email: "stable@example.com")
    end

    before = @account.audit_events.where(action: "contact.updated").count
    with_audit_context(account: @account, actor: @user) do
      contact.touch
    end
    assert_equal before, @account.audit_events.where(action: "contact.updated").count
  end

  test "writes a destroy event" do
    contact = nil
    with_audit_context(account: @account, actor: @user) do
      contact = @account.contacts.create!(email: "byebye@example.com")
    end

    with_audit_context(account: @account, actor: @user) do
      contact.destroy!
    end

    event = @account.audit_events.where(action: "contact.destroyed").last
    assert_equal contact.id, event.target_id
    assert_equal "byebye@example.com", event.metadata.dig("diff", "email")
  end

  test "uses configured action_prefix when overridden" do
    list = nil
    with_audit_context(account: @account, actor: @user) do
      list = @account.contact_lists.create!(name: "VIPs")
    end

    assert_equal 1, @account.audit_events.where(action: "contact_list.created").count
  end

  test "Campaign create writes campaign.created event" do
    campaign = nil
    with_audit_context(account: @account, actor: @user) do
      campaign = @account.campaigns.create!(name: "Spring launch")
    end

    event = @account.audit_events.where(action: "campaign.created").last
    assert_equal campaign.id, event.target_id
    assert_equal "Campaign", event.target_type
  end

  test "falls back to System actor when Current.actor is not set" do
    with_audit_context(account: @account, actor: nil) do
      @account.contacts.create!(email: "anon@example.com")
    end
    event = @account.audit_events.where(action: "contact.created").last
    assert_equal "System", event.actor_type
    assert_nil event.actor_id
  end
end
