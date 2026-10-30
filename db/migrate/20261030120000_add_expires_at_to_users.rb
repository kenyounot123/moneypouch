class AddExpiresAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :expires_at, :datetime
    add_index :users, :expires_at, where: "expires_at IS NOT NULL"
  end
end
