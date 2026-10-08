class RemoveSimplefinCredentialsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :simplefin_setup_token, :string
    remove_column :users, :simplefin_access_url, :string
  end
end
