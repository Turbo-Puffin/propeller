class WaitlistEntry < ApplicationRecord
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  before_save { self.email = email.downcase.strip }
end
