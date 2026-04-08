class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.integer :status, default: 0, null: false
      t.jsonb :metadata, default: {}
      t.datetime :subscribed_at
      t.datetime :unsubscribed_at

      t.timestamps
    end

    add_index :contacts, [:account_id, :email], unique: true
    add_index :contacts, :status
    add_index :contacts, :email
  end
end
