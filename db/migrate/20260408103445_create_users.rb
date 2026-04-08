class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.integer :role, default: 0, null: false
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
  end
end
