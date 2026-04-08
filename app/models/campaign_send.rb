class CampaignSend < ApplicationRecord
  belongs_to :campaign
  belongs_to :contact

  enum :status, { pending: 0, sent: 1, delivered: 2, opened: 3, clicked: 4, bounced: 5, complained: 6 }

  validates :contact_id, uniqueness: { scope: :campaign_id }

  scope :delivered, -> { where(status: [:delivered, :opened, :clicked]) }
end
