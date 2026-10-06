class AddKeptSpendingIndexToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_index :transactions, %i[ user_id occurred_on category_id amount_in_cents ],
      where: "discarded_at IS NULL", name: "index_transactions_on_user_id_and_occurred_on_kept"
  end
end
