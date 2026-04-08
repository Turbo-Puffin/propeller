class CreateEmailSequenceSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :email_sequence_steps, id: :uuid do |t|
      t.references :email_sequence, null: false, foreign_key: true, type: :uuid
      t.integer :position, null: false
      t.integer :delay_hours, default: 0, null: false
      t.string :subject, null: false
      t.text :body_html
      t.text :body_text
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :email_sequence_steps, [ :email_sequence_id, :position ], unique: true, name: 'idx_email_sequence_steps_on_sequence_and_position'
  end
end
