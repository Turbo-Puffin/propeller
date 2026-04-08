class CreateContactLists < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_lists, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.jsonb :auto_segment_rules, default: {}

      t.timestamps
    end

    add_index :contact_lists, [ :account_id, :name ]
  end
end
