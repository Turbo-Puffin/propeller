class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.integer :plan, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :accounts, :subdomain, unique: true
    add_index :accounts, :plan
    add_index :accounts, :status
  end
end
