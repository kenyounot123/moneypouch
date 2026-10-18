class AddSeenVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :seen_version, :string, null: false, default: "0.7.0"
    change_column_default :users, :seen_version, from: "0.7.0", to: nil
  end
end
