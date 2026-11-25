class AddPostedAtToBankTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_transactions, :posted_at, :datetime
  end
end
