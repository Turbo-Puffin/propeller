class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :key_prefix, null: false
      t.string :key_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_keys, :key_digest, unique: true
    add_index :api_keys, :key_prefix
  end
end
