class AddUsersToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_reference :transactions, :user, null: false, foreign_key: true
  end
end
