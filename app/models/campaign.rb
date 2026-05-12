class Campaign < ApplicationRecord
  include Webhookable

  belongs_to :account
  has_many :campaign_sends, dependent: :destroy

  enum :status, { draft: 0, scheduled: 1, sending: 2, sent: 3, paused: 4 }
  enum :campaign_type, { regular: 0, automated: 1, ab_test: 2 }

  validates :name, presence: true

  scope :active, -> { where(status: [ :scheduled, :sending ]) }

  webhook_event :create, "campaign.created", payload: -> { Webhooks::PayloadSerializer.campaign(self) }

  after_update_commit :fire_campaign_lifecycle_webhook

  private

  def fire_campaign_lifecycle_webhook
    return unless saved_change_to_status?

    event = case status
    when "scheduled" then "campaign.scheduled"
    when "paused" then "campaign.cancelled"
    end
    return if event.nil?

    Webhooks::Dispatcher.dispatch(
      account: account,
      event_type: event,
      data: Webhooks::PayloadSerializer.campaign(self)
    )
  end
end
