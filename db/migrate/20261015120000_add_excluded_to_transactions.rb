class AddExcludedToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :excluded, :boolean, default: false, null: false
  end
end
