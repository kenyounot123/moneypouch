class AddSingleKeyShortcutsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :single_key_shortcuts, :boolean, null: false, default: true
  end
end
