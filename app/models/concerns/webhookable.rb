module Webhookable
  extend ActiveSupport::Concern

  class_methods do
    # Declares which lifecycle events should be broadcast as webhooks for this
    # model. `:create`/`:update`/`:destroy` map to ActiveRecord callbacks; the
    # event_type is the dotted name sent on the wire.
    def webhook_event(callback, event_type, payload:)
      case callback
      when :create
        after_create_commit { fire_webhook(event_type, payload) }
      when :update
        after_update_commit { fire_webhook(event_type, payload) }
      when :destroy
        after_destroy_commit { fire_webhook(event_type, payload) }
      else
        raise ArgumentError, "Unsupported callback #{callback.inspect}"
      end
    end
  end

  private

  def fire_webhook(event_type, payload_builder)
    return unless respond_to?(:account) && account.present?

    data = instance_exec(&payload_builder)
    Webhooks::Dispatcher.dispatch(account: account, event_type: event_type, data: data)
  rescue StandardError => e
    Rails.logger.error("Webhook dispatch failed for #{event_type}: #{e.class}: #{e.message}")
  end
end
