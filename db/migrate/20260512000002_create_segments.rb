class CreateSegments < ActiveRecord::Migration[8.1]
  def up
    create_table :segments, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.references :contact_list, null: true, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.jsonb :rules, null: false, default: { "match" => "all", "rules" => [] }

      t.timestamps
    end

    add_index :segments, [ :account_id, :name ]

    # Move any non-empty auto_segment_rules into the new segments table before dropping the column.
    execute <<~SQL
      INSERT INTO segments (id, account_id, contact_list_id, name, rules, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        account_id,
        id AS contact_list_id,
        name,
        auto_segment_rules,
        NOW(),
        NOW()
      FROM contact_lists
      WHERE auto_segment_rules IS NOT NULL
        AND auto_segment_rules <> '{}'::jsonb
    SQL

    remove_column :contact_lists, :auto_segment_rules
  end

  def down
    add_column :contact_lists, :auto_segment_rules, :jsonb, default: {}
    drop_table :segments
  end
end
