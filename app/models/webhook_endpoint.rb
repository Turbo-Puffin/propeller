class WebhookEndpoint < ApplicationRecord
  SUPPORTED_EVENTS = %w[
    contact.created
    contact.updated
    contact.deleted
    list.created
    list.updated
    segment.evaluated
    campaign.created
    campaign.scheduled
    campaign.cancelled
    template.created
    template.updated
    audit.event
    campaign.sending
    campaign.completed
    send.delivered
    send.opened
    send.clicked
    send.bounced
    send.complained
    webhook.test
  ].freeze

  belongs_to :account
  has_many :webhook_deliveries, dependent: :destroy

  validates :url, presence: true
  validates :secret, presence: true
  validate :url_must_be_http_or_https
  validate :event_types_must_be_supported

  before_validation :ensure_secret
  before_validation :normalize_event_types

  scope :listening_for, ->(event_type) {
    active.where("event_types @> ?", [ event_type ].to_json)
  }
  scope :active, -> { where(active: true) }

  def secret_preview
    return nil if secret.blank?
    "...#{secret.last(4)}"
  end

  def subscribed_to?(event_type)
    active? && event_types.include?(event_type.to_s)
  end

  def record_success!(at: Time.current)
    update_columns(last_success_at: at, last_failure_message: nil)
  end

  def record_failure!(message, at: Time.current)
    update_columns(last_failure_at: at, last_failure_message: message.to_s.truncate(1000))
  end

  def self.generate_secret
    "whsec_#{SecureRandom.urlsafe_base64(32)}"
  end

  private

  def ensure_secret
    self.secret ||= self.class.generate_secret
  end

  def normalize_event_types
    self.event_types = Array(event_types).map(&:to_s).uniq
  end

  def event_types_must_be_supported
    invalid = event_types - SUPPORTED_EVENTS
    return if invalid.empty?

    errors.add(:event_types, "contains unsupported events: #{invalid.join(', ')}")
  end

  def url_must_be_http_or_https
    return if url.blank?

    parsed = URI.parse(url.to_s)
    return if (parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)) && parsed.host.present?

    errors.add(:url, "must be a valid http or https URL")
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid http or https URL")
  end
end
