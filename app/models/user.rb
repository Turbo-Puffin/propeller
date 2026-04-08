class User < ApplicationRecord
  belongs_to :account

  has_secure_password

  enum :role, { member: 0, admin: 1, owner: 2 }

  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current)
  end
end
