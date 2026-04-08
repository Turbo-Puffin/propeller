class EmailSequence < ApplicationRecord
  belongs_to :account
  has_many :email_sequence_steps, -> { order(:position) }, dependent: :destroy
  has_many :email_sequence_enrollments, dependent: :destroy

  enum :status, { draft: 0, active: 1, paused: 2 }
  enum :trigger_type, { form_submission: 0, manual: 1, api: 2 }

  validates :name, presence: true
end
