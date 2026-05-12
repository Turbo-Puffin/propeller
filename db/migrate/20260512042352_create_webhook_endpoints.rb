class CreateWebhookEndpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_endpoints, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :url, null: false
      t.string :secret, null: false
      t.jsonb :event_types, default: [], null: false
      t.boolean :active, default: true, null: false
      t.datetime :last_success_at
      t.datetime :last_failure_at
      t.text :last_failure_message

      t.timestamps
    end

    add_index :webhook_endpoints, [ :account_id, :active ]
  end
end
