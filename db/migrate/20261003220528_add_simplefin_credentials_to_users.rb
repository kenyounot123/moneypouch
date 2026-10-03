class AddSimplefinCredentialsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :simplefin_setup_token, :string
    add_column :users, :simplefin_access_url, :string
  end
end
