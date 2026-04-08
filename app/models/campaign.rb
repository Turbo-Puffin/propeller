class Campaign < ApplicationRecord
  belongs_to :account
  has_many :campaign_sends, dependent: :destroy

  enum :status, { draft: 0, scheduled: 1, sending: 2, sent: 3, paused: 4 }
  enum :campaign_type, { regular: 0, automated: 1, ab_test: 2 }

  validates :name, presence: true

  scope :active, -> { where(status: [:scheduled, :sending]) }
end
