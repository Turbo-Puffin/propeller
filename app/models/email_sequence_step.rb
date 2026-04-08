class EmailSequenceStep < ApplicationRecord
  belongs_to :email_sequence

  validates :position, presence: true, uniqueness: { scope: :email_sequence_id }
  validates :delay_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :subject, presence: true
end
