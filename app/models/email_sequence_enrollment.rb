class EmailSequenceEnrollment < ApplicationRecord
  belongs_to :email_sequence
  belongs_to :contact

  enum :status, { active: 0, completed: 1, paused: 2, cancelled: 3 }

  validates :contact_id, uniqueness: { scope: :email_sequence_id }
end
