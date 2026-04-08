class CreateEmailSequenceEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :email_sequence_enrollments, id: :uuid do |t|
      t.references :email_sequence, null: false, foreign_key: true, type: :uuid
      t.references :contact, null: false, foreign_key: true, type: :uuid
      t.integer :current_step, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.datetime :enrolled_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :email_sequence_enrollments, [:email_sequence_id, :contact_id], unique: true, name: 'idx_email_seq_enrollments_unique'
    add_index :email_sequence_enrollments, :status
  end
end
