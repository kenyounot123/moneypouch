class AddGetStartedHiddenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :get_started_hidden, :boolean, null: false, default: true
    change_column_default :users, :get_started_hidden, from: true, to: false
  end
end
