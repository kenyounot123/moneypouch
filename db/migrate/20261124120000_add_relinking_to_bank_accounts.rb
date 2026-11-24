class AddRelinkingToBankAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_accounts, :missing_since, :datetime
    add_column :bank_accounts, :relinked_at, :datetime
  end
end
