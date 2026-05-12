class CreateEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :email_templates, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :slug, null: false
      t.string :subject_template
      t.text :html_body, null: false
      t.text :plain_body, null: false
      t.jsonb :default_variables, default: {}, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :email_templates, [ :account_id, :slug ], unique: true
    add_index :email_templates, :status
  end
end
