class Contact < ApplicationRecord
  include Webhookable

  belongs_to :account
  has_many :contact_list_memberships, dependent: :destroy
  has_many :contact_lists, through: :contact_list_memberships
  has_many :campaign_sends, dependent: :destroy
  has_many :form_submissions, dependent: :nullify
  has_many :email_sequence_enrollments, dependent: :destroy

  attr_accessor :webhook_source

  enum :status, { active: 0, unsubscribed: 1, bounced: 2, complained: 3 }

  validates :email, presence: true,
            uniqueness: { scope: :account_id },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :subscribed, -> { where(status: :active) }

  webhook_event :create,  "contact.created", payload: -> { Webhooks::PayloadSerializer.contact(self, source: webhook_source) }
  webhook_event :update,  "contact.updated", payload: -> { Webhooks::PayloadSerializer.contact(self, source: webhook_source) }
  webhook_event :destroy, "contact.deleted", payload: -> { Webhooks::PayloadSerializer.contact(self, source: webhook_source) }
end
