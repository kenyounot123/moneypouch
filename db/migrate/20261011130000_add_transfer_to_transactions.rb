class AddTransferToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :transfer, :boolean, default: false, null: false
    add_check_constraint :transactions, "NOT (transfer AND category_id IS NOT NULL)", name: "transfer_has_no_category"
  end
end
