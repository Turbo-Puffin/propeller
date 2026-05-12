module Webhooks
  # Persists a webhook_delivery row for every active endpoint subscribed to an
  # event, then enqueues DeliverWebhookJob to POST the payload. Persist-first
  # so that a crash between enqueue and HTTP send is recoverable from the DB.
  class Dispatcher
    def self.dispatch(account:, event_type:, data:, occurred_at: Time.current)
      new(account: account, event_type: event_type, data: data, occurred_at: occurred_at).dispatch
    end

    def initialize(account:, event_type:, data:, occurred_at:)
      @account = account
      @event_type = event_type.to_s
      @data = data
      @occurred_at = occurred_at
    end

    def dispatch
      return [] if @account.nil?

      endpoints = @account.webhook_endpoints.listening_for(@event_type)
      endpoints.map { |endpoint| persist_and_enqueue(endpoint) }
    end

    private

    def persist_and_enqueue(endpoint)
      delivery = WebhookDelivery.create!(
        webhook_endpoint: endpoint,
        event_type: @event_type,
        payload: payload_envelope,
        status: "pending"
      )
      DeliverWebhookJob.perform_later(delivery.id)
      delivery
    end

    def payload_envelope
      {
        "event" => @event_type,
        "occurred_at" => @occurred_at.utc.iso8601,
        "data" => @data
      }
    end
  end
end
