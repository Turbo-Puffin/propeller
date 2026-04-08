class CreateFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :form_submissions, id: :uuid do |t|
      t.references :form, null: false, foreign_key: true, type: :uuid
      t.references :contact, null: true, foreign_key: true, type: :uuid
      t.jsonb :data, default: {}
      t.datetime :submitted_at
      t.string :ip_address

      t.timestamps
    end

    add_index :form_submissions, :submitted_at
  end
end
