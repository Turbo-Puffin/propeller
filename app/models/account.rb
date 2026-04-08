class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :contact_lists, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :forms, dependent: :destroy
  has_many :email_sequences, dependent: :destroy

  enum :plan, { free: 0, starter: 1, pro: 2, enterprise: 3 }
  enum :status, { active: 0, suspended: 1, cancelled: 2 }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/i, message: "must be alphanumeric (hyphens allowed)" }
end
