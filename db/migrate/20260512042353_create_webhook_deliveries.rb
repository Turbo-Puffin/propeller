class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries, id: :uuid do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true, type: :uuid
      t.string :event_type, null: false
      t.jsonb :payload, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, default: 0, null: false
      t.integer :response_status
      t.datetime :delivered_at
      t.text :last_error_message

      t.timestamps
    end

    add_index :webhook_deliveries, [ :webhook_endpoint_id, :created_at ]
    add_index :webhook_deliveries, [ :status, :created_at ]
  end
end
