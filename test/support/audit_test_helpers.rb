module AuditTestHelpers
  def create_account(name: "Acme", subdomain: nil)
    suffix = SecureRandom.hex(4)
    Account.create!(name: name, subdomain: subdomain || "acme-#{suffix}", plan: :free, status: :active)
  end

  def create_user(account:, email: nil, role: :owner)
    User.create!(
      account: account,
      email: email || "user-#{SecureRandom.hex(4)}@example.com",
      name: "Test User",
      password: "supersecret123",
      role: role,
      confirmed_at: Time.current
    )
  end

  def login_as(user)
    post "/login", params: { email: user.email, password: "supersecret123" }
  end

  def with_audit_context(account:, actor: nil, reason: nil, request_ip: nil, user_agent: nil)
    Current.account     = account
    Current.actor       = actor
    Current.audit_reason = reason
    Current.request_ip  = request_ip
    Current.user_agent  = user_agent
    yield
  ensure
    Current.reset
  end
end
