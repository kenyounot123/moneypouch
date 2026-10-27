class AddOriginToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :origin, :string
  end
end
