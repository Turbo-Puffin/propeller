class WebhookDelivery < ApplicationRecord
  STATUSES = %w[pending delivered failed].freeze
  MAX_ATTEMPTS = 5

  belongs_to :webhook_endpoint
  has_one :account, through: :webhook_endpoint

  validates :event_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :payload, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :delivered, -> { where(status: "delivered") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }

  def pending?
    status == "pending"
  end

  def delivered?
    status == "delivered"
  end

  def failed?
    status == "failed"
  end

  def mark_delivered!(response_status:, at: Time.current)
    update!(
      status: "delivered",
      delivered_at: at,
      response_status: response_status,
      last_error_message: nil
    )
  end

  def mark_failed!(message:, response_status: nil)
    update!(
      status: "failed",
      response_status: response_status,
      last_error_message: message.to_s.truncate(1000)
    )
  end

  def record_attempt!(message: nil, response_status: nil)
    update!(
      attempts: attempts + 1,
      response_status: response_status,
      last_error_message: message&.to_s&.truncate(1000)
    )
  end

  def replayable?
    failed?
  end
end
