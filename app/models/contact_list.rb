class ContactList < ApplicationRecord
  include Webhookable

  belongs_to :account
  has_many :contact_list_memberships, dependent: :destroy
  has_many :contacts, through: :contact_list_memberships

  validates :name, presence: true

  webhook_event :create, "list.created", payload: -> { Webhooks::PayloadSerializer.contact_list(self) }
  webhook_event :update, "list.updated", payload: -> { Webhooks::PayloadSerializer.contact_list(self) }
end
