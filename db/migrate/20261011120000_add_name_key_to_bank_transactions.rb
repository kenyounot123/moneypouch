class AddNameKeyToBankTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_transactions, :name_key, :string
    change_column_null :bank_transactions, :name_key, false
    add_index :bank_transactions, [ :bank_account_id, :name_key ]
  end
end
