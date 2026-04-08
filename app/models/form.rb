class Form < ApplicationRecord
  belongs_to :account
  has_many :form_submissions, dependent: :destroy

  enum :form_type, { embedded: 0, popup: 1, landing_page: 2 }
  enum :status, { active: 0, inactive: 1 }

  validates :name, presence: true
end
