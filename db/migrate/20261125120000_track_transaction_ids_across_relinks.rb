class TrackTransactionIdsAcrossRelinks < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_transactions, :posted_at, :datetime
    add_column :bank_transactions, :transacted_at, :datetime
    add_column :bank_transactions, :id_in_doubt, :boolean, default: false, null: false

    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE bank_transactions SET id_in_doubt = 1
          WHERE created_at <= (SELECT relinked_at FROM bank_accounts WHERE bank_accounts.id = bank_transactions.bank_account_id)
        SQL
      end
    end

    remove_column :bank_accounts, :relinked_at, :datetime
  end
end
