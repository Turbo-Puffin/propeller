class ContactListMembership < ApplicationRecord
  belongs_to :contact
  belongs_to :contact_list

  validates :contact_id, uniqueness: { scope: :contact_list_id }
end
