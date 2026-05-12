class AuditEvent < ApplicationRecord
  ACTOR_TYPES = %w[User ApiKey System].freeze

  belongs_to :account
  belongs_to :actor, polymorphic: true, optional: true
  belongs_to :target, polymorphic: true, optional: true

  validates :actor_type, presence: true, inclusion: { in: ACTOR_TYPES }
  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :by_actor_type, ->(type) { where(actor_type: type) }
  scope :by_action, ->(action) { where(action: action) }
  scope :for_target, ->(target_type, target_id) { where(target_type: target_type, target_id: target_id) }
  scope :between, ->(from, to) { where(created_at: from..to) }

  def self.record!(account:, action:, actor: nil, target: nil, metadata: {}, request_ip: nil, user_agent: nil)
    attrs = {
      account: account,
      action: action,
      metadata: metadata || {},
      request_ip: request_ip,
      user_agent: user_agent
    }

    if actor.is_a?(String) && actor == "System"
      attrs[:actor_type] = "System"
    elsif actor
      attrs[:actor] = actor
    else
      attrs[:actor_type] = "System"
    end

    if target
      attrs[:target] = target
    end

    create!(attrs)
  end

  def actor_label
    case actor_type
    when "System" then "System"
    when "User"   then actor&.email || "user:#{actor_id}"
    when "ApiKey" then actor.respond_to?(:name) ? "API key (#{actor.name})" : "api_key:#{actor_id}"
    else "#{actor_type}:#{actor_id}"
    end
  end

  def reason
    metadata["reason"].presence
  end

  def diff
    metadata["diff"] || metadata[:diff] || {}
  end

  def summary
    parts = [ action ]
    parts << "(#{target_type} #{target_id.to_s.first(8)})" if target_type.present?
    parts << "reason: #{reason}" if reason
    parts.join(" ")
  end
end
