require "json"

class DeliverWebhookJob < ApplicationJob
  queue_as :default

  class RetryableDeliveryError < StandardError
    attr_reader :delivery_id

    def initialize(message, delivery_id: nil)
      super(message)
      @delivery_id = delivery_id
    end
  end

  # Polynomial backoff: ~3s, 18s, 81s, 256s, 625s.
  retry_on RetryableDeliveryError,
           wait: ->(executions) { (executions**4 + 1) * 3 },
           attempts: WebhookDelivery::MAX_ATTEMPTS do |job, error|
    DeliverWebhookJob.mark_exhausted(job, error)
  end

  def self.mark_exhausted(job, error)
    delivery_id = error.respond_to?(:delivery_id) ? error.delivery_id : nil
    delivery_id ||= job&.arguments&.first
    delivery = WebhookDelivery.find_by(id: delivery_id)
    return if delivery.nil?

    delivery.mark_failed!(message: error.message)
    delivery.webhook_endpoint.record_failure!(error.message)
  end

  discard_on ActiveJob::DeserializationError

  def perform(delivery_id)
    delivery = WebhookDelivery.find_by(id: delivery_id)
    return if delivery.nil? || delivery.delivered?

    endpoint = delivery.webhook_endpoint
    return mark_skipped(delivery, "endpoint inactive") unless endpoint.active?

    body = JSON.generate(delivery.payload)
    signature = Webhooks::Signer.sign(body, endpoint.secret)

    response =
      begin
        Webhooks::HttpClient.post(endpoint.url, body, headers(delivery, signature))
      rescue StandardError => e
        message = "#{e.class}: #{e.message}"
        delivery.record_attempt!(message: message)
        raise RetryableDeliveryError.new(message, delivery_id: delivery.id)
      end

    handle_response(delivery, endpoint, response)
  end

  private

  def headers(delivery, signature)
    {
      "Content-Type" => "application/json",
      "User-Agent" => "Propeller-Webhooks/1.0",
      "X-Propeller-Signature" => signature,
      "X-Propeller-Event" => delivery.event_type,
      "X-Propeller-Delivery-Id" => delivery.id
    }
  end

  def handle_response(delivery, endpoint, response)
    code = response.code.to_i

    if code.between?(200, 299)
      delivery.record_attempt!(response_status: code)
      delivery.mark_delivered!(response_status: code)
      endpoint.record_success!
    elsif code.between?(400, 499)
      message = "HTTP #{code}: #{truncate_body(response.body)}"
      delivery.record_attempt!(message: message, response_status: code)
      delivery.mark_failed!(message: message, response_status: code)
      endpoint.record_failure!(message)
    else
      message = "HTTP #{code}: #{truncate_body(response.body)}"
      delivery.record_attempt!(message: message, response_status: code)
      raise RetryableDeliveryError.new(message, delivery_id: delivery.id)
    end
  end

  def mark_skipped(delivery, reason)
    delivery.mark_failed!(message: "Skipped: #{reason}")
  end

  def truncate_body(body)
    body.to_s.truncate(200)
  end
end
