class CreateCampaignSends < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_sends, id: :uuid do |t|
      t.references :campaign, null: false, foreign_key: true, type: :uuid
      t.references :contact, null: false, foreign_key: true, type: :uuid
      t.integer :status, default: 0, null: false
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.datetime :bounced_at

      t.timestamps
    end

    add_index :campaign_sends, [:campaign_id, :contact_id], unique: true
    add_index :campaign_sends, :status
  end
end
