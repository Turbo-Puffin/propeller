class ContactList < ApplicationRecord
  belongs_to :account
  has_many :contact_list_memberships, dependent: :destroy
  has_many :contacts, through: :contact_list_memberships

  validates :name, presence: true
end
