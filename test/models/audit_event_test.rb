require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @user    = create_user(account: @account)
  end

  test "record! defaults actor to System when nothing provided" do
    event = AuditEvent.record!(account: @account, action: "system.boot")
    assert_equal "System", event.actor_type
    assert_nil event.actor_id
  end

  test "record! captures user actor polymorphically" do
    event = AuditEvent.record!(account: @account, action: "contact.created", actor: @user)
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
  end

  test "record! persists metadata, ip, and user agent" do
    event = AuditEvent.record!(
      account: @account,
      action: "contact.created",
      actor: @user,
      metadata: { "reason" => "manual import", "diff" => { "email" => { "from" => nil, "to" => "a@b.co" } } },
      request_ip: "10.0.0.1",
      user_agent: "RSpec"
    )
    assert_equal "manual import", event.reason
    assert_equal "10.0.0.1", event.request_ip
    assert_equal "RSpec", event.user_agent
  end

  test "actor_label is friendly for users, api keys, and system" do
    system_event = AuditEvent.record!(account: @account, action: "system.startup")
    user_event   = AuditEvent.record!(account: @account, action: "contact.created", actor: @user)

    assert_equal "System", system_event.actor_label
    assert_equal @user.email, user_event.actor_label
  end

  test "validates actor_type inclusion" do
    event = AuditEvent.new(account: @account, action: "x", actor_type: "Hacker")
    refute event.valid?
    assert_includes event.errors[:actor_type], "is not included in the list"
  end

  test "scope by_actor_type and by_action filter correctly" do
    AuditEvent.record!(account: @account, action: "contact.created", actor: @user)
    AuditEvent.record!(account: @account, action: "campaign.created", actor: @user)
    AuditEvent.record!(account: @account, action: "system.tick")

    assert_equal 2, @account.audit_events.by_actor_type("User").count
    assert_equal 1, @account.audit_events.by_action("system.tick").count
  end
end
