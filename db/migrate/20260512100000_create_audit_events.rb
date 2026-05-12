class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :actor_type, null: false
      t.uuid :actor_id
      t.string :action, null: false
      t.string :target_type
      t.uuid :target_id
      t.jsonb :metadata, null: false, default: {}
      t.string :request_ip
      t.string :user_agent
      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :account_id, :created_at ]
    add_index :audit_events, [ :target_type, :target_id ]
    add_index :audit_events, :action
    add_index :audit_events, [ :actor_type, :actor_id ]
  end
end
