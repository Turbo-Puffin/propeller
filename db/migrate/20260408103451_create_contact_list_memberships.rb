class CreateContactListMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_list_memberships, id: :uuid do |t|
      t.references :contact, null: false, foreign_key: true, type: :uuid
      t.references :contact_list, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :contact_list_memberships, [:contact_id, :contact_list_id], unique: true, name: 'idx_contact_list_memberships_unique'
  end
end
