class ContactList < ApplicationRecord
  include Auditable

  belongs_to :account
  has_many :contact_list_memberships, dependent: :destroy
  has_many :contacts, through: :contact_list_memberships

  validates :name, presence: true

  audit_actions :create, :update, :destroy,
                action_prefix: "contact_list",
                changed_fields: %i[name description]
end
