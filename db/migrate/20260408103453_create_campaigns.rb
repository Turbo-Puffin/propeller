class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :subject
      t.string :from_name
      t.string :from_email
      t.text :body_html
      t.text :body_text
      t.integer :status, default: 0, null: false
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.integer :campaign_type, default: 0, null: false
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :campaigns, :status
    add_index :campaigns, :campaign_type
    add_index :campaigns, [ :account_id, :status ]
  end
end
