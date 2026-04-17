class AddSourceToWaitlistEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :waitlist_entries, :source, :string
  end
end
