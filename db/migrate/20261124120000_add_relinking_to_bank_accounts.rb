class AddRelinkingToBankAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_accounts, :reported_at, :datetime
    add_column :bank_accounts, :missing_since, :datetime
    add_column :bank_accounts, :relinked_at, :datetime

    up_only { execute "UPDATE bank_accounts SET reported_at = updated_at" }
  end
end
