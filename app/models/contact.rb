class Contact < ApplicationRecord
  belongs_to :account
  has_many :contact_list_memberships, dependent: :destroy
  has_many :contact_lists, through: :contact_list_memberships
  has_many :campaign_sends, dependent: :destroy
  has_many :form_submissions, dependent: :nullify
  has_many :email_sequence_enrollments, dependent: :destroy

  enum :status, { active: 0, unsubscribed: 1, bounced: 2, complained: 3 }

  validates :email, presence: true,
            uniqueness: { scope: :account_id },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :subscribed, -> { where(status: :active) }
end
