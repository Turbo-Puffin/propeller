class CreateEmailSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :email_sequences, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :trigger_type, default: 0, null: false

      t.timestamps
    end

    add_index :email_sequences, [:account_id, :status]
    add_index :email_sequences, :trigger_type
  end
end
