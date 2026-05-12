class Campaign < ApplicationRecord
  include Auditable

  belongs_to :account
  has_many :campaign_sends, dependent: :destroy

  enum :status, { draft: 0, scheduled: 1, sending: 2, sent: 3, paused: 4 }
  enum :campaign_type, { regular: 0, automated: 1, ab_test: 2 }

  validates :name, presence: true

  scope :active, -> { where(status: [ :scheduled, :sending ]) }

  audit_actions :create, :update, :destroy,
                changed_fields: %i[name status subject from_name from_email scheduled_at sent_at]
end
