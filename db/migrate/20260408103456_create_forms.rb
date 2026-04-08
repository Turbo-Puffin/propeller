class CreateForms < ActiveRecord::Migration[8.1]
  def change
    create_table :forms, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :form_type, default: 0, null: false
      t.jsonb :settings, default: {}
      t.text :html_content
      t.text :success_message
      t.string :redirect_url
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :forms, [ :account_id, :status ]
    add_index :forms, :form_type
  end
end
