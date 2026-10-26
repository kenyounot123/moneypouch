class AddRegistrationOpenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :registration_open, :boolean, null: false, default: false
  end
end
