module Auditable
  extend ActiveSupport::Concern

  class_methods do
    def audit_actions(*actions, changed_fields: nil, action_prefix: nil)
      class_attribute :audit_changed_fields, instance_writer: false, default: nil
      class_attribute :audit_action_prefix, instance_writer: false, default: nil

      self.audit_changed_fields = changed_fields&.map(&:to_s)
      self.audit_action_prefix = (action_prefix || model_name.element).to_s

      actions = actions.map(&:to_sym)

      after_create  :record_audit_create  if actions.include?(:create)
      after_update  :record_audit_update  if actions.include?(:update)
      after_destroy :record_audit_destroy if actions.include?(:destroy)
    end
  end

  private

  def record_audit_create
    write_audit_event!("#{audit_action_prefix}.created", diff: audit_attributes_for_create)
  end

  def record_audit_update
    changes = audit_relevant_changes
    return if changes.empty?

    write_audit_event!("#{audit_action_prefix}.updated", diff: changes)
  end

  def record_audit_destroy
    write_audit_event!("#{audit_action_prefix}.destroyed", diff: audit_attributes_for_destroy)
  end

  def write_audit_event!(action, diff:)
    account = audit_account
    return unless account

    metadata = { "diff" => diff }
    metadata["reason"] = Current.audit_reason if Current.audit_reason.present?

    AuditEvent.record!(
      account: account,
      action: action,
      actor: Current.actor || "System",
      target: self,
      metadata: metadata,
      request_ip: Current.request_ip,
      user_agent: Current.user_agent
    )
  end

  def audit_relevant_changes
    fields = audit_changed_fields || (saved_changes.keys - %w[id created_at updated_at])
    saved_changes.slice(*fields).transform_values { |(before, after)| { "from" => before, "to" => after } }
  end

  def audit_attributes_for_create
    fields = audit_changed_fields || (attributes.keys - %w[id created_at updated_at])
    attributes.slice(*fields)
  end

  def audit_attributes_for_destroy
    fields = audit_changed_fields || (attributes.keys - %w[id created_at updated_at])
    attributes.slice(*fields)
  end

  def audit_account
    return account if respond_to?(:account) && account.present?
    return Current.account if Current.account.present?

    nil
  end
end
