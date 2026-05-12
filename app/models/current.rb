class Current < ActiveSupport::CurrentAttributes
  attribute :account
  attribute :actor
  attribute :request_ip
  attribute :user_agent
  attribute :audit_reason
end
